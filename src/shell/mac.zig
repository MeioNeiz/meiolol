//! The shell on the Mac, for the dev loop: a WKWebView window from Zig through the
//! Objective-C runtime (no Objective-C source, no Xcode project), serving the same files
//! (meiolol://app/...) with the same bridge behind a small chrome.webview shim and the
//! same channel. Window place kept by AppKit (frame autosave).
//!   zig build shell-mac -- [--dir PATH] [--page P] [--demo] [--seconds N] [--dump DIR]
//!   [--practice]

const std = @import("std");
const channel = @import("channel.zig");
const files = @import("files.zig");
const screens = @import("screens.zig");
const demo = @import("demo.zig");
const client = @import("client.zig");
const practice = @import("practice.zig");

const Id = ?*anyopaque;
const Sel = ?*anyopaque;
const Class = ?*anyopaque;

extern "objc" fn objc_getClass(name: [*:0]const u8) Class;
extern "objc" fn sel_registerName(name: [*:0]const u8) Sel;
extern "objc" fn objc_msgSend() void;
extern "objc" fn objc_allocateClassPair(super: Class, name: [*:0]const u8, extra: usize) Class;
extern "objc" fn objc_registerClassPair(cls: Class) void;
extern "objc" fn class_addMethod(cls: Class, sel: Sel, imp: *const anyopaque, types: [*:0]const u8) bool;
extern "objc" fn class_addProtocol(cls: Class, proto: ?*anyopaque) bool;
extern "objc" fn objc_getProtocol(name: [*:0]const u8) ?*anyopaque;

fn cls(name: [*:0]const u8) Id {
    return objc_getClass(name);
}

/// [obj sel:args...], the argument types taken from `args`
fn msg(comptime R: type, obj: Id, sel: [*:0]const u8, args: anytype) R {
    const types = .{ Id, Sel } ++ @typeInfo(@TypeOf(args)).@"struct".field_types[0..].*;
    const attrs: [types.len]std.lang.Type.Fn.ParamAttributes = @splat(.{});
    const F = @Fn(&types, &attrs, R, .{ .@"callconv" = .c });
    const f: *const F = @ptrCast(&objc_msgSend);
    return @call(.auto, f, .{ obj, sel_registerName(sel) } ++ args);
}

fn nsString(s: [*:0]const u8) Id {
    return msg(Id, cls("NSString"), "stringWithUTF8String:", .{s});
}

const Rect = extern struct { x: f64, y: f64, w: f64, h: f64 };

/// What WebView2 gives pages (window.chrome.webview), over WebKit's message handler
const shim =
    \\(() => {
    \\  const ls = [];
    \\  window.chrome = window.chrome || {};
    \\  window.chrome.webview = {
    \\    postMessage: (m) => window.webkit.messageHandlers.meiolol.postMessage(m),
    \\    addEventListener: (t, f) => { if (t === 'message') ls.push(f); },
    \\  };
    \\  window.__meiololPush = (d) => ls.forEach((f) => f({ data: d }));
    \\})();
    \\
;

var io: std.Io = undefined;
var gpa: std.mem.Allocator = undefined;
var dir: ?[]const u8 = null;
var webview: Id = null;
var seq: u32 = 0;
var ticks: u32 = 0;
var seconds: u32 = 0;
var pushing = false;
var push_demo = false;
/// --dump DIR: no window, the page's changes into DIR
var dump: ?[]const u8 = null;
/// --practice: with --dump, practice on with a random draft once the stats are in
var practise = false;
/// What the page was last told of the League client
var sent_client: ?client.Client = null;
var t0: std.Io.Timestamp = undefined;

fn nowMs() f64 {
    const ns = t0.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return @as(f64, @floatFromInt(ns)) / 1e6;
}

/// WKURLSchemeHandler: meiolol://app/<path> from the embedded files or --dir
fn startTask(_: Id, _: Sel, _: Id, task: Id) callconv(.c) void {
    const url = msg(Id, msg(Id, task, "request", .{}), "URL", .{});
    const raw = std.mem.span(msg([*:0]const u8, msg(Id, url, "path", .{}), "UTF8String", .{}));
    const path = files.clean(raw);
    var owned: ?[]u8 = null;
    defer if (owned) |o| gpa.free(o);
    const body: []const u8 = if (path) |p| (if (dir) |d| blk: {
        const full = std.fs.path.join(gpa, &.{ d, p }) catch break :blk null;
        defer gpa.free(full);
        owned = std.Io.Dir.cwd().readFileAlloc(io, full, gpa, .limited(64 << 20)) catch null;
        break :blk owned;
    } else screens.get(p) orelse files.get(p) orelse blk: {
        owned = screens.icon(gpa, p);
        break :blk owned;
    }) orelse "not found" else "not found";
    var mime: [64]u8 = undefined;
    const m = std.mem.printSentinel(&mime, "{s}", .{files.mime(path orelse "")}, 0) catch unreachable;
    const resp = msg(Id, msg(Id, cls("NSURLResponse"), "alloc", .{}), "initWithURL:MIMEType:expectedContentLength:textEncodingName:", .{ url, nsString(m.ptr), @as(isize, @intCast(body.len)), @as(Id, null) });
    msg(void, task, "didReceiveResponse:", .{resp});
    // Copied: an owned body is freed on return
    const data = msg(Id, cls("NSData"), "dataWithBytes:length:", .{ @as(*const anyopaque, body.ptr), body.len });
    msg(void, task, "didReceiveData:", .{data});
    msg(void, task, "didFinish", .{});
}
fn stopTask(_: Id, _: Sel, _: Id, _: Id) callconv(.c) void {}

/// WKScriptMessageHandler: page to shell
fn received(_: Id, _: Sel, _: Id, message: Id) callconv(.c) void {
    const body = msg(Id, message, "body", .{});
    const text = std.mem.span(msg([*:0]const u8, body, "UTF8String", .{}));
    var mem: [2 * channel.max_from_page]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&mem);
    const m = channel.read(fba.allocator(), text) catch {
        // Not its text: it could be the sign-in's
        std.debug.print("page message ignored ({d} bytes)\n", .{text.len});
        return;
    };
    switch (m) {
        .painted => |p| {
            std.debug.print("{d:8.1} ms painted {s}\n", .{ nowMs(), p.page });
            send(.{ .hello = .{ .release = 0, .public = false, .os = "macos" } });
            sent_client = client.current();
            send(.{ .status = .{ .client = sent_client.? } });
            if (push_demo) pushing = true;
        },
        .drawn => {},
        .open => |url| if (channel.openable(url)) {
            var buf: [1024]u8 = undefined;
            const z = std.mem.printSentinel(&buf, "{s}", .{url}, 0) catch return;
            const ws = msg(Id, cls("NSWorkspace"), "sharedWorkspace", .{});
            _ = msg(bool, ws, "openURL:", .{msg(Id, cls("NSURL"), "URLWithString:", .{nsString(z.ptr)})});
        },
        .signin => |x| client.signIn(x.username, x.password),
        .mastery => |on| client.mastery(on),
        .practice => |p| if (!@import("build_options").public) {
            _ = practice.edit(p, @intFromFloat(nowMs() * 1000));
        },
    }
}

fn send(m: channel.ToPage) void {
    var json: [8192]u8 = undefined;
    var w: std.Io.Writer = .fixed(&json);
    w.writeAll("window.__meiololPush(") catch return;
    channel.write(&w, m) catch return;
    w.writeAll(");\x00") catch return;
    msg(void, webview, "evaluateJavaScript:completionHandler:", .{ nsString(@ptrCast(w.buffered().ptr)), @as(?*anyopaque, null) });
}

/// NSTimer, once a second
fn tick(_: Id, _: Sel, _: Id) callconv(.c) void {
    ticks += 1;
    if (seconds > 0 and ticks >= seconds) {
        msg(void, msg(Id, cls("NSApplication"), "sharedApplication", .{}), "terminate:", .{@as(Id, null)});
        return;
    }
    if (screens.refresh(gpa, true)) |n| send(.{ .app = n });
    const now = client.current();
    if (sent_client != null and now != sent_client.?) {
        sent_client = now;
        std.debug.print("{d:8.1} ms client: {t}\n", .{ nowMs(), now });
        send(.{ .status = .{ .client = now } });
    }
    if (!pushing) return;
    seq += 1;
    send(demo.champSelect(seq));
}

fn lastWindowClosed(_: Id, _: Sel, _: Id) callconv(.c) bool {
    return true;
}

fn newClass(name: [*:0]const u8, proto: ?[*:0]const u8, methods: anytype) Id {
    const c = objc_allocateClassPair(cls("NSObject"), name, 0);
    if (proto) |p| _ = class_addProtocol(c, objc_getProtocol(p));
    inline for (methods) |m| _ = class_addMethod(c, sel_registerName(m[0]), @ptrCast(m[1]), m[2]);
    objc_registerClassPair(c);
    return msg(Id, msg(Id, c, "alloc", .{}), "init", .{});
}

fn noWake() void {}

pub fn main(init: std.process.Init) !void {
    io = init.io;
    gpa = init.gpa;
    t0 = std.Io.Clock.awake.now(io);
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var page: []const u8 = files.start_page;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        const next = if (i + 1 < args.len) args[i + 1] else "";
        if (std.mem.eql(u8, a, "--seconds")) {
            seconds = try std.fmt.parseInt(u32, next, 10);
            i += 1;
        } else if (std.mem.eql(u8, a, "--dir")) {
            dir = next;
            i += 1;
        } else if (std.mem.eql(u8, a, "--page")) {
            page = files.clean(next) orelse return error.BadPage;
            i += 1;
        } else if (std.mem.eql(u8, a, "--dump")) {
            dump = next;
            i += 1;
        } else if (std.mem.eql(u8, a, "--practice")) {
            practise = true;
        } else if (std.mem.eql(u8, a, "--demo")) {
            push_demo = true;
        } else return error.UnknownArgument;
    }

    // The 1 s tick sends what changed
    try client.start(init, init.environ_map.get("MEIOLOL_LOCKFILE"), noWake);
    if (dump) |d| {
        // No window: each change of the page into its own folder until --seconds
        for (0..if (seconds > 0) seconds else 30) |_| {
            if (practise and practice.edit(.{ .on = true }, 0)) _ = practice.edit(.random, 7);
            if (screens.refresh(gpa, true)) |n| {
                try screens.dump(io, gpa, d);
                std.debug.print("{d:8.1} ms page {d}: {t}\n", .{ nowMs(), n, client.current() });
            }
            std.Io.sleep(io, .fromSeconds(1), .awake) catch {};
        }
        screens.deinit();
        client.stop();
        return;
    }
    _ = screens.refresh(gpa, true);
    const app = msg(Id, cls("NSApplication"), "sharedApplication", .{});
    msg(void, app, "setActivationPolicy:", .{@as(isize, 0)});
    const delegate = newClass("MeiololAppDelegate", null, .{
        .{ "applicationShouldTerminateAfterLastWindowClosed:", &lastWindowClosed, "c@:@" },
    });
    msg(void, app, "setDelegate:", .{delegate});

    const frame: Rect = .{ .x = 120, .y = 120, .w = 1120, .h = 720 };
    const win = msg(Id, msg(Id, cls("NSWindow"), "alloc", .{}), "initWithContentRect:styleMask:backing:defer:", .{ frame, @as(usize, 15), @as(usize, 2), false });
    msg(void, win, "setTitle:", .{nsString("meiolol")});
    msg(void, win, "setReleasedWhenClosed:", .{false});
    _ = msg(bool, win, "setFrameAutosaveName:", .{nsString("meiolol-shell")});

    const cfg = msg(Id, msg(Id, cls("WKWebViewConfiguration"), "alloc", .{}), "init", .{});
    const scheme = newClass("MeiololSchemeHandler", "WKURLSchemeHandler", .{
        .{ "webView:startURLSchemeTask:", &startTask, "v@:@@" },
        .{ "webView:stopURLSchemeTask:", &stopTask, "v@:@@" },
    });
    msg(void, cfg, "setURLSchemeHandler:forURLScheme:", .{ scheme, nsString("meiolol") });
    const ucc = msg(Id, cfg, "userContentController", .{});
    const handler = newClass("MeiololMessageHandler", "WKScriptMessageHandler", .{
        .{ "userContentController:didReceiveScriptMessage:", &received, "v@:@@" },
    });
    msg(void, ucc, "addScriptMessageHandler:name:", .{ handler, nsString("meiolol") });
    const script = shim ++ files.bridge_js;
    const user_script = msg(Id, msg(Id, cls("WKUserScript"), "alloc", .{}), "initWithSource:injectionTime:forMainFrameOnly:", .{ nsString(script), @as(isize, 0), true });
    msg(void, ucc, "addUserScript:", .{user_script});

    webview = msg(Id, msg(Id, cls("WKWebView"), "alloc", .{}), "initWithFrame:configuration:", .{ frame, cfg });
    msg(void, win, "setContentView:", .{webview});
    var url_buf: [256]u8 = undefined;
    const url = try std.mem.printSentinel(&url_buf, "meiolol://app/{s}", .{page}, 0);
    const ns_url = msg(Id, cls("NSURL"), "URLWithString:", .{nsString(url.ptr)});
    msg(void, webview, "loadRequest:", .{msg(Id, cls("NSURLRequest"), "requestWithURL:", .{ns_url})});

    msg(void, win, "makeKeyAndOrderFront:", .{@as(Id, null)});
    msg(void, app, "activateIgnoringOtherApps:", .{true});
    const timer_target = newClass("MeiololTimer", null, .{.{ "tick:", &tick, "v@:@" }});
    _ = msg(Id, cls("NSTimer"), "scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:", .{ @as(f64, 1.0), timer_target, sel_registerName("tick:"), @as(Id, null), true });
    std.debug.print("{d:8.1} ms window shown\n", .{nowMs()});
    msg(void, app, "run", .{});
}
