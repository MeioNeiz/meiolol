//! meiolol-shell.exe: the desktop app as a WebView2 window driven from Zig through its COM
//! API (docs/plan/ui/stack.md section 5). No C++, no Node; WebView2Loader.dll only as the
//! fallback (embedded). Pages are served from memory on https://meiolol.app/ and talk to
//! the shell through channel.zig. Beside today's dvui app (meiolol-desktop.exe) until the
//! app's screens are site components; then it takes over its name, install and updates.
//!   meiolol-shell.exe [--dir PATH] [--page P] [--demo] [--devtools] [--loader dll]
//!                     [--measure [--also P]... [--scale X]] [--self-test]
//! --dir serves a folder instead of the embedded pages; --demo pushes a made-up champ
//! select once a second; --measure runs measure.zig's script and closes; --self-test
//! starts the webview, waits for the first paint and exits 0 (else 1), writing
//! shell-selftest.txt. Both use their own webview data folder and skip single instance.
//! A log of each run: shell.log beside the exe.

const std = @import("std");
const builtin = @import("builtin");
pub const c = @import("c");
const build_options = @import("build_options");
const channel = @import("channel.zig");
const files = @import("files.zig");
const place = @import("place.zig");
const demo = @import("demo.zig");
const measure = @import("measure.zig");
const client = @import("client.zig");

pub const W = std.unicode.utf8ToUtf16LeStringLiteral;
pub const origin = "https://meiolol.app/";
const class_name = W("meiolol-shell");
const instance_mutex = W("Local\\meiolol-shell");
/// Microsoft's Evergreen bootstrapper page
const runtime_download = "https://go.microsoft.com/fwlink/p/?LinkId=2124703";
const loader_dll = @embedFile("wv2/WebView2Loader.dll");
/// The page's background from the first frame, so no white flash (tokens' --bg)
const background: c.COREWEBVIEW2_COLOR = .{ .A = 255, .R = 8, .G = 9, .B = 10 };

pub const Options = struct {
    dir: ?[]const u8 = null,
    page: []const u8 = files.start_page,
    demo: bool = false,
    devtools: bool = builtin.mode == .debug,
    loader: Loader = .internal,
    measure: bool = false,
    self_test: bool = false,
    /// Pages --measure loads after the first
    also: [8][]const u8 = undefined,
    n_also: usize = 0,
    /// --measure: the webview's rasterisation scale (1.5 renders as at 150%)
    scale: ?f64 = null,

    fn scripted(o: Options) bool {
        return o.measure or o.self_test;
    }
};
const Loader = enum { internal, dll };

// ---------------------------------------------------------------- COM plumbing

fn Ret(comptime T: type, comptime m: []const u8) type {
    const Vt = @typeInfo(@FieldType(T, "lpVtbl")).pointer.child;
    const F = @typeInfo(@typeInfo(@FieldType(Vt, m)).optional.child).pointer.child;
    return @typeInfo(F).@"fn".return_type.?;
}

/// obj->lpVtbl->m(obj, args...)
pub fn com(obj: anytype, comptime m: []const u8, args: anytype) Ret(@typeInfo(@TypeOf(obj)).pointer.child, m) {
    return @call(.auto, @field(obj.*.lpVtbl.*, m).?, .{obj} ++ args);
}

pub fn check(hr: c.HRESULT, what: []const u8) !void {
    if (hr < 0) {
        log("{s} failed: 0x{x}", .{ what, @as(u32, @bitCast(hr)) });
        return error.Com;
    }
}

pub fn guid(comptime s: []const u8) c.GUID {
    @setEvalBranchQuota(10_000);
    const p = std.fmt.parseInt;
    var g: c.GUID = .{
        .Data1 = p(u32, s[0..8], 16) catch unreachable,
        .Data2 = p(u16, s[9..13], 16) catch unreachable,
        .Data3 = p(u16, s[14..18], 16) catch unreachable,
        .Data4 = undefined,
    };
    g.Data4[0] = p(u8, s[19..21], 16) catch unreachable;
    g.Data4[1] = p(u8, s[21..23], 16) catch unreachable;
    for (0..6) |i| g.Data4[2 + i] = p(u8, s[24 + 2 * i ..][0..2], 16) catch unreachable;
    return g;
}

pub fn tryQi(obj: anytype, comptime iid: []const u8, comptime T: type) [*c]T {
    const id = comptime guid(iid);
    var p: [*c]T = null;
    if (com(obj, "QueryInterface", .{ &id, @as([*c]?*anyopaque, @ptrCast(&p)) }) < 0) return null;
    return p;
}

const iid_unknown = guid("00000000-0000-0000-c000-000000000046");

/// A static COM object for a one-method handler interface: the vtable is
/// QueryInterface, AddRef, Release, Invoke, as in every ICoreWebView2...Handler. Never
/// freed, so its count stays 1
pub const Handler = extern struct {
    vtbl: *const [4]*const anyopaque,
    iid: c.GUID,

    pub fn init(comptime iid: []const u8, comptime invoke: anytype) Handler {
        const S = struct {
            const vt = [4]*const anyopaque{ @ptrCast(&qi), @ptrCast(&addRef), @ptrCast(&addRef), @ptrCast(invoke) };
        };
        return .{ .vtbl = &S.vt, .iid = comptime guid(iid) };
    }
    pub fn as(h: *Handler, comptime T: type) [*c]T {
        return @ptrCast(h);
    }
    fn qi(this: *Handler, riid: *const c.GUID, out: *?*anyopaque) callconv(.c) c.HRESULT {
        if (std.meta.eql(riid.*, iid_unknown) or std.meta.eql(riid.*, this.iid)) {
            out.* = this;
            return 0;
        }
        out.* = null;
        return @bitCast(@as(u32, 0x80004002)); // E_NOINTERFACE
    }
    fn addRef(_: *Handler) callconv(.c) u32 {
        return 1;
    }
};

var env_handler: Handler = .init("4e8a3389-c9d8-4bd2-b6b5-124fee6cc14d", &envCreated);
var ctrl_handler: Handler = .init("6c4819f3-c9b7-4260-8127-c9f5bde7f68c", &controllerCreated);
var msg_handler: Handler = .init("57213f19-00e6-49fa-8e07-898ea01ecbd2", &messageReceived);
pub var res_handler: Handler = .init("ab00b74c-15f1-4646-80e8-e76341d25d71", &resourceRequested);
var nav_handler: Handler = .init("9adbe429-f36d-432b-9ddc-f8881fbd76e3", &navigationStarting);
var newwin_handler: Handler = .init("d4c185fe-c81c-4989-97af-2d3fa7ab5651", &newWindowRequested);
var failed_handler: Handler = .init("79e0aea4-990b-42d9-aa1d-0fcc2e5bc7f1", &processFailed);

// ---------------------------------------------------------------- state

pub var opt: Options = .{};
pub var hwnd: c.HWND = null;
pub var env: [*c]c.ICoreWebView2Environment = null;
pub var controller: [*c]c.ICoreWebView2Controller = null;
pub var webview: [*c]c.ICoreWebView2 = null;
var exe_dir: [260]u16 = undefined;
var exe_dir_len: usize = 0;
var log_file: c.HANDLE = null;
var created_100ns: u64 = 0;
var loader: Loader = .internal;
var runtime_version: [32]u8 = undefined;
var runtime_version_len: usize = 0;
/// The window's restored frame, kept current while it moves (saved on close)
var normal_rect: place.Rect = undefined;
var first_paint: ?f64 = null;
var pushing = false;
var seq: u32 = 0;
/// What the page was last told of the League client
var sent_client: ?client.Client = null;
pub var t_window: f64 = 0;
pub var t_env: f64 = 0;
pub var t_ctrl: f64 = 0;

// ---------------------------------------------------------------- small helpers

pub fn ft64(ft: c.FILETIME) u64 {
    return @as(u64, ft.dwHighDateTime) << 32 | ft.dwLowDateTime;
}

/// Milliseconds since this process was created (the OS's own clock for it)
pub fn nowMs() f64 {
    var ft: c.FILETIME = undefined;
    c.GetSystemTimePreciseAsFileTime(&ft);
    return @as(f64, @floatFromInt(ft64(ft) - created_100ns)) / 10_000.0;
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const head = std.mem.print(&buf, "{d:9.1} ", .{nowMs()}) catch return;
    const body = std.mem.print(buf[head.len..], fmt ++ "\r\n", args) catch return;
    var n: c.DWORD = 0;
    if (log_file != null) _ = c.WriteFile(log_file, &buf, @intCast(head.len + body.len), &n, null);
}

/// exe_dir ++ "\\" ++ name, NUL-terminated, in buf
pub fn besideExe(buf: []u16, name: []const u8) [*:0]const u16 {
    @memcpy(buf[0..exe_dir_len], exe_dir[0..exe_dir_len]);
    buf[exe_dir_len] = '\\';
    const n = std.unicode.utf8ToUtf16Le(buf[exe_dir_len + 1 .. buf.len - 1], name) catch 0;
    buf[exe_dir_len + 1 + n] = 0;
    return @ptrCast(buf.ptr);
}

pub fn toWide(buf: []u16, s: []const u8) [*:0]const u16 {
    const n = std.unicode.utf8ToUtf16Le(buf[0 .. buf.len - 1], s) catch 0;
    buf[n] = 0;
    return @ptrCast(buf.ptr);
}

/// A COM string as UTF-8 in buf; null if it doesn't fit
fn fromWide(buf: []u8, s: c.LPWSTR) ?[]const u8 {
    const len = std.mem.indexOfSentinel(u16, 0, @ptrCast(s));
    if (len > buf.len / 3) return null;
    const n = std.unicode.utf16LeToUtf8(buf, @as([*]const u16, @ptrCast(s))[0..len]) catch return null;
    return buf[0..n];
}

pub fn writeFile(path: [*:0]const u16, bytes: []const u8) bool {
    const f = c.CreateFileW(path, c.GENERIC_WRITE, 0, null, c.CREATE_ALWAYS, c.FILE_ATTRIBUTE_NORMAL, null);
    if (f == c.INVALID_HANDLE_VALUE) return false;
    defer _ = c.CloseHandle(f);
    var n: c.DWORD = 0;
    return c.WriteFile(f, bytes.ptr, @intCast(bytes.len), &n, null) != 0 and n == bytes.len;
}

/// The whole file, from the page allocator (free with it); null if missing or > limit
fn readFile(path: [*:0]const u16, limit: usize) ?[]u8 {
    const f = c.CreateFileW(path, c.GENERIC_READ, c.FILE_SHARE_READ, null, c.OPEN_EXISTING, c.FILE_ATTRIBUTE_NORMAL, null);
    if (f == c.INVALID_HANDLE_VALUE) return null;
    defer _ = c.CloseHandle(f);
    var size: c.LARGE_INTEGER = undefined;
    if (c.GetFileSizeEx(f, &size) == 0 or size.QuadPart > limit) return null;
    const buf = std.heap.page_allocator.alloc(u8, @intCast(size.QuadPart)) catch return null;
    var n: c.DWORD = 0;
    if (c.ReadFile(f, buf.ptr, @intCast(buf.len), &n, null) == 0 or n != buf.len) {
        std.heap.page_allocator.free(buf);
        return null;
    }
    return buf;
}

fn navigate(page: []const u8) void {
    var url: [256]u8 = undefined;
    var wide: [256]u16 = undefined;
    const u = std.mem.print(&url, origin ++ "{s}", .{page}) catch return;
    check(com(webview, "Navigate", .{toWide(&wide, u)}), "Navigate") catch {};
}

pub fn navigateTo(page: []const u8) void {
    navigate(page);
}

fn message(text: []const u8, style: c.UINT) c_int {
    var wide: [1024]u16 = undefined;
    return c.MessageBoxW(hwnd, toWide(&wide, text), W("meiolol"), style);
}

fn openExternal(url: []const u8) void {
    if (!channel.openable(url)) {
        log("not opening {s}", .{url[0..@min(url.len, 120)]});
        return;
    }
    var wide: [1024]u16 = undefined;
    _ = c.ShellExecuteW(null, W("open"), toWide(&wide, url), null, null, c.SW_SHOWNORMAL);
}

// ---------------------------------------------------------------- the runtime

/// The Evergreen runtime's EmbeddedBrowserWebView.dll, as Microsoft's loader finds it:
/// the EdgeUpdate client state per machine, then per user. Its version goes to the log
fn findRuntime(out: []u16) ?[*:0]const u16 {
    const state = W("SOFTWARE\\Microsoft\\EdgeUpdate\\ClientState\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}");
    const clients_key = W("SOFTWARE\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}");
    for ([_]usize{ hklm, hkcu }) |root| {
        var ver: [64]u16 = undefined;
        if (regString(root, clients_key, W("pv"), &ver)) |v| {
            const n = std.unicode.utf16LeToUtf8(&runtime_version, v) catch 0;
            runtime_version_len = n;
        }
        const dir = regString(root, state, W("EBWebView"), out[0 .. out.len - 64]) orelse continue;
        const tail = W("\\EBWebView\\x64\\EmbeddedBrowserWebView.dll");
        @memcpy(out[dir.len..][0..tail.len], tail);
        out[dir.len + tail.len] = 0;
        const path: [*:0]const u16 = @ptrCast(out.ptr);
        if (c.GetFileAttributesW(path) != c.INVALID_FILE_ATTRIBUTES) return path;
    }
    return null;
}

/// A REG_SZ value without its terminator; HKLM through the 32-bit view, where
/// EdgeUpdate writes
fn regString(root: usize, sub: [*:0]const u16, name: [*:0]const u16, out: []u16) ?[]const u16 {
    var key: usize = 0;
    const sam: u32 = @intCast(c.KEY_READ | @as(c_long, if (root == hklm) c.KEY_WOW64_32KEY else 0));
    if (RegOpenKeyExW(root, sub, 0, sam, &key) != 0) return null;
    defer _ = RegCloseKey(key);
    var size: u32 = @intCast(out.len * 2);
    if (RegQueryValueExW(key, name, null, null, @ptrCast(out.ptr), &size) != 0) return null;
    var n: usize = size / 2;
    while (n > 0 and out[n - 1] == 0) n -= 1;
    return if (n == 0) null else out[0..n];
}

fn hasRuntime() bool {
    var path: [600]u16 = undefined;
    const v = runtime_version[0..runtime_version_len];
    return findRuntime(&path) != null or (v.len > 0 and !std.mem.eql(u8, v, "0.0.0.0"));
}

fn userDataFolder(buf: []u16) [*:0]const u16 {
    return besideExe(buf, if (opt.scripted()) "webview-test" else "webview");
}

/// What WebView2Loader.dll does, minus the dll: call the runtime's
/// EmbeddedBrowserWebView.dll directly (webview/webview's route). Undocumented, so
/// anything wrong falls back to the dll
fn createInternal() !void {
    var path: [600]u16 = undefined;
    const dll_path = findRuntime(&path) orelse return error.NoRuntimeDll;
    const dll = c.LoadLibraryW(dll_path) orelse return error.LoadRuntime;
    const Create = *const fn (c.BOOL, c_int, ?[*:0]const u16, ?*anyopaque, *Handler) callconv(.c) c.HRESULT;
    const create: Create = @ptrCast(c.GetProcAddress(dll, "CreateWebViewEnvironmentWithOptionsInternal") orelse
        return error.NoEntryPoint);
    var data: [400]u16 = undefined;
    try check(create(1, 0, userDataFolder(&data), null, &env_handler), "internal loader");
}

/// Microsoft's loader, written from the exe into the data folder when it isn't there or
/// differs (one exe to ship and update)
fn createWithDll() !void {
    loader = .dll;
    var data: [400]u16 = undefined;
    var path: [400]u16 = undefined;
    _ = c.CreateDirectoryW(userDataFolder(&data), null);
    const dll_path = besideExe(&path, if (opt.scripted()) "webview-test\\WebView2Loader.dll" else "webview\\WebView2Loader.dll");
    const same = if (readFile(dll_path, loader_dll.len)) |have| blk: {
        defer std.heap.page_allocator.free(have);
        break :blk std.mem.eql(u8, have, loader_dll);
    } else false;
    if (!same and !writeFile(dll_path, loader_dll)) return error.WriteLoader;
    const dll = c.LoadLibraryExW(dll_path, null, c.LOAD_WITH_ALTERED_SEARCH_PATH) orelse return error.LoadLoader;
    const Create = *const fn (?[*:0]const u16, ?[*:0]const u16, ?*anyopaque, *Handler) callconv(.c) c.HRESULT;
    const create: Create = @ptrCast(c.GetProcAddress(dll, "CreateCoreWebView2EnvironmentWithOptions") orelse
        return error.NoEntryPoint);
    try check(create(null, userDataFolder(&data), null, &env_handler), "WebView2Loader.dll");
}

fn startEnvironment() !void {
    if (opt.loader == .internal) {
        loader = .internal;
        if (createInternal()) return else |e| log("internal loader: {t}; trying WebView2Loader.dll", .{e});
    }
    try createWithDll();
}

/// No runtime (Windows 10 without Edge's runtime, or removed): say so and offer the
/// bootstrapper, which installs it per user without admin rights
fn noRuntime() void {
    log("no WebView2 runtime", .{});
    if (opt.scripted()) return;
    const yes = 6;
    if (message("meiolol needs Microsoft Edge WebView2 Runtime, which this PC doesn't have. " ++
        "Microsoft's installer takes about a minute.\n\nOpen the download page?", c.MB_YESNO | c.MB_ICONINFORMATION) == yes)
        openExternal(runtime_download);
}

fn failStart(comptime what: []const u8, hr: c.HRESULT) void {
    log(what ++ ": 0x{x}", .{@as(u32, @bitCast(hr))});
    if (opt.scripted()) {
        finishSelfTest(false, what);
        return;
    }
    var buf: [300]u8 = undefined;
    _ = message(std.mem.print(&buf, "meiolol couldn't start its window (" ++ what ++ ", 0x{x}). " ++
        "Restarting the PC usually fixes this; details in shell.log.", .{@as(u32, @bitCast(hr))}) catch what, c.MB_ICONERROR);
    _ = c.DestroyWindow(hwnd);
}

// ---------------------------------------------------------------- WebView2 set-up

fn envCreated(_: *Handler, hr: c.HRESULT, e: [*c]c.ICoreWebView2Environment) callconv(.c) c.HRESULT {
    t_env = nowMs();
    if (hr < 0 or e == null) {
        if (loader == .internal) {
            log("internal loader: environment 0x{x}; trying WebView2Loader.dll", .{@as(u32, @bitCast(hr))});
            createWithDll() catch failStart("WebView2Loader.dll", hr);
        } else failStart("environment", hr);
        return 0;
    }
    env = e;
    _ = com(env, "AddRef", .{});
    log("environment ready ({t} loader, runtime {s})", .{ loader, runtime_version[0..runtime_version_len] });
    check(com(env, "CreateCoreWebView2Controller", .{ hwnd, ctrl_handler.as(c.ICoreWebView2CreateCoreWebView2ControllerCompletedHandler) }), "CreateController") catch
        failStart("controller", -1);
    return 0;
}

fn controllerCreated(_: *Handler, hr: c.HRESULT, ctrl: [*c]c.ICoreWebView2Controller) callconv(.c) c.HRESULT {
    t_ctrl = nowMs();
    if (hr < 0 or ctrl == null) {
        failStart("controller", hr);
        return 0;
    }
    controller = ctrl;
    _ = com(controller, "AddRef", .{});
    check(com(controller, "get_CoreWebView2", .{&webview}), "get_CoreWebView2") catch {
        failStart("webview", -1);
        return 0;
    };
    log("controller ready", .{});
    setUp(controller, webview);
    if (opt.scale) |s| if (tryQi(controller, "f9614724-5d2b-41dc-aef7-73d62b51543b", c.ICoreWebView2Controller3)) |c3| {
        _ = com(c3, "put_ShouldDetectMonitorScaleChanges", .{@as(c.BOOL, 0)});
        _ = com(c3, "put_RasterizationScale", .{s});
        _ = com(c3, "Release", .{});
    };
    var token: c.EventRegistrationToken = undefined;
    _ = com(webview, "add_WebMessageReceived", .{ msg_handler.as(c.ICoreWebView2WebMessageReceivedEventHandler), &token });
    _ = com(webview, "add_ProcessFailed", .{ failed_handler.as(c.ICoreWebView2ProcessFailedEventHandler), &token });
    resize();
    navigate(opt.page);
    return 0;
}

/// What every webview of the app gets (the main one, measure.zig's panel): background,
/// settings, the bridge, pages from memory, no way off our origin
pub fn setUp(ctrl: [*c]c.ICoreWebView2Controller, wv: [*c]c.ICoreWebView2) void {
    if (tryQi(ctrl, "c979903e-d4ca-4228-92eb-47ee3fa96eab", c.ICoreWebView2Controller2)) |c2| {
        _ = com(c2, "put_DefaultBackgroundColor", .{background});
        _ = com(c2, "Release", .{});
    }
    var settings: [*c]c.ICoreWebView2Settings = null;
    if (com(wv, "get_Settings", .{&settings}) >= 0) {
        const dev: c.BOOL = @intFromBool(opt.devtools);
        _ = com(settings, "put_AreDevToolsEnabled", .{dev});
        _ = com(settings, "put_AreDefaultContextMenusEnabled", .{dev});
        _ = com(settings, "put_IsStatusBarEnabled", .{@as(c.BOOL, 0)});
        // F5, Ctrl+F, Ctrl+P and the like: a browser's, not the app's
        if (tryQi(settings, "fdb5ab74-af33-4854-84f0-0a631deb5eba", c.ICoreWebView2Settings3)) |s3| {
            _ = com(s3, "put_AreBrowserAcceleratorKeysEnabled", .{dev});
            _ = com(s3, "Release", .{});
        }
        if (tryQi(settings, "cb56846c-4168-4d53-b04f-03b6d6796ff2", c.ICoreWebView2Settings4)) |s4| {
            _ = com(s4, "put_IsPasswordAutosaveEnabled", .{@as(c.BOOL, 0)});
            _ = com(s4, "put_IsGeneralAutofillEnabled", .{@as(c.BOOL, 0)});
            _ = com(s4, "Release", .{});
        }
        _ = com(settings, "Release", .{});
    }
    var wide: [4096]u16 = undefined;
    _ = com(wv, "AddScriptToExecuteOnDocumentCreated", .{ toWide(&wide, files.bridge_js), null });
    var token: c.EventRegistrationToken = undefined;
    _ = com(wv, "AddWebResourceRequestedFilter", .{ W(origin ++ "*"), c.COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL });
    _ = com(wv, "add_WebResourceRequested", .{ res_handler.as(c.ICoreWebView2WebResourceRequestedEventHandler), &token });
    _ = com(wv, "add_NavigationStarting", .{ nav_handler.as(c.ICoreWebView2NavigationStartingEventHandler), &token });
    _ = com(wv, "add_NewWindowRequested", .{ newwin_handler.as(c.ICoreWebView2NewWindowRequestedEventHandler), &token });
}

/// Low trims the GPU and renderer processes once, when set (at 150%: 348 to 175 MB), and
/// costs the next draw about 10 ms; it is no cap, so pages grow back while it stays low.
/// Microsoft's advice and ours: low while the app is inactive, normal while in use
pub fn setMemoryLow(wv: [*c]c.ICoreWebView2, low: bool) void {
    const w19 = tryQi(wv, "6921f954-79b0-437f-a997-c85811897c68", c.ICoreWebView2_19) orelse return;
    const level: c.COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL = if (low) c.COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_LOW else c.COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_NORMAL;
    _ = com(w19, "put_MemoryUsageTargetLevel", .{level});
    _ = com(w19, "Release", .{});
}

fn resize() void {
    if (controller == null) return;
    var r: c.RECT = undefined;
    _ = c.GetClientRect(hwnd, &r);
    _ = com(controller, "put_Bounds", .{r});
}

/// Our origin stays in the app; a link elsewhere opens in the browser, if allowed
fn navigationStarting(_: *Handler, _: [*c]c.ICoreWebView2, args: [*c]c.ICoreWebView2NavigationStartingEventArgs) callconv(.c) c.HRESULT {
    var uri: c.LPWSTR = null;
    if (com(args, "get_Uri", .{&uri}) < 0) return 0;
    defer c.CoTaskMemFree(uri);
    var buf: [2048]u8 = undefined;
    const u = fromWide(&buf, uri) orelse "";
    if (std.mem.startsWith(u8, u, origin)) return 0;
    _ = com(args, "put_Cancel", .{@as(c.BOOL, 1)});
    openExternal(u);
    return 0;
}

fn newWindowRequested(_: *Handler, _: [*c]c.ICoreWebView2, args: [*c]c.ICoreWebView2NewWindowRequestedEventArgs) callconv(.c) c.HRESULT {
    _ = com(args, "put_Handled", .{@as(c.BOOL, 1)});
    var uri: c.LPWSTR = null;
    if (com(args, "get_Uri", .{&uri}) < 0) return 0;
    defer c.CoTaskMemFree(uri);
    var buf: [2048]u8 = undefined;
    openExternal(fromWide(&buf, uri) orelse "");
    return 0;
}

/// A renderer that died or hangs gets a reload; a dead browser process takes the
/// controller with it, so the environment starts again
fn processFailed(_: *Handler, _: [*c]c.ICoreWebView2, args: [*c]c.ICoreWebView2ProcessFailedEventArgs) callconv(.c) c.HRESULT {
    var kind: c.COREWEBVIEW2_PROCESS_FAILED_KIND = 0;
    _ = com(args, "get_ProcessFailedKind", .{&kind});
    log("process failed, kind {d}", .{kind});
    switch (kind) {
        c.COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED,
        c.COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE,
        => _ = com(webview, "Reload", .{}),
        c.COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED => {
            _ = com(webview, "Release", .{});
            _ = com(controller, "Close", .{});
            _ = com(controller, "Release", .{});
            _ = com(env, "Release", .{});
            webview = null;
            controller = null;
            env = null;
            startEnvironment() catch |e| log("restart: {t}", .{e});
        },
        else => {},
    }
    return 0;
}

// ---------------------------------------------------------------- serving files

fn resourceRequested(_: *Handler, _: [*c]c.ICoreWebView2, args: [*c]c.ICoreWebView2WebResourceRequestedEventArgs) callconv(.c) c.HRESULT {
    var req: [*c]c.ICoreWebView2WebResourceRequest = null;
    if (com(args, "get_Request", .{&req}) < 0) return 0;
    defer _ = com(req, "Release", .{});
    var uri: c.LPWSTR = null;
    if (com(req, "get_Uri", .{&uri}) < 0) return 0;
    defer c.CoTaskMemFree(uri);
    var buf: [1024]u8 = undefined;
    const u = fromWide(&buf, uri) orelse return 0;
    if (!std.mem.startsWith(u8, u, origin)) return 0;
    const path = files.clean(u[origin.len - 1 ..]);

    var owned: ?[]u8 = null;
    defer if (owned) |o| std.heap.page_allocator.free(o);
    const body: ?[]const u8 = if (path) |p| (if (opt.dir) |d| blk: {
        var full: [600]u8 = undefined;
        var wide: [600]u16 = undefined;
        const f = std.mem.print(&full, "{s}\\{s}", .{ d, p }) catch break :blk null;
        std.mem.replaceScalar(u8, f, '/', '\\');
        owned = readFile(toWide(&wide, f), 64 << 20);
        break :blk owned;
    } else files.get(p)) else null;
    measure.served(if (body) |b| b.len else 0);

    var headers: [128]u8 = undefined;
    const h = std.mem.print(&headers, "Content-Type: {s}{s}", .{
        files.mime(path orelse ""),
        if (path != null and files.immutable(path.?)) "\r\nCache-Control: max-age=31536000, immutable" else "",
    }) catch return 0;
    var wide_headers: [128]u16 = undefined;
    const data = body orelse "not found";
    const stream = c.SHCreateMemStream(data.ptr, @intCast(data.len));
    defer _ = com(stream, "Release", .{});
    var resp: [*c]c.ICoreWebView2WebResourceResponse = null;
    const status: c_int = if (body != null) 200 else 404;
    if (com(env, "CreateWebResourceResponse", .{ stream, status, if (body != null) W("OK") else W("Not Found"), toWide(&wide_headers, h), &resp }) >= 0) {
        _ = com(args, "put_Response", .{resp});
        _ = com(resp, "Release", .{});
    }
    return 0;
}

// ---------------------------------------------------------------- the channel

pub fn send(m: channel.ToPage) void {
    if (webview == null) return;
    var json: [8192]u8 = undefined;
    var w: std.Io.Writer = .fixed(&json);
    channel.write(&w, m) catch {
        log("message to page too long: {t}", .{m});
        return;
    };
    var wide: [8192]u16 = undefined;
    _ = com(webview, "PostWebMessageAsJson", .{toWide(&wide, w.buffered())});
}

fn messageReceived(_: *Handler, _: [*c]c.ICoreWebView2, args: [*c]c.ICoreWebView2WebMessageReceivedEventArgs) callconv(.c) c.HRESULT {
    var buf: [channel.max_from_page * 3]u8 = undefined;
    var src: c.LPWSTR = null;
    if (com(args, "get_Source", .{&src}) < 0) return 0;
    defer c.CoTaskMemFree(src);
    if (!std.mem.startsWith(u8, fromWide(&buf, src) orelse "", origin)) return 0;
    var s: c.LPWSTR = null;
    if (com(args, "TryGetWebMessageAsString", .{&s}) < 0) return 0;
    defer c.CoTaskMemFree(s);
    const text = fromWide(&buf, s) orelse return 0;
    var mem: [2 * channel.max_from_page]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&mem);
    const m = channel.read(fba.allocator(), text) catch |e| {
        log("page message ignored ({t}): {s}", .{ e, text[0..@min(text.len, 80)] });
        return 0;
    };
    switch (m) {
        .painted => |p| painted(p.page),
        .drawn => |n| measure.drawn(n),
        .open => |url| openExternal(url),
    }
    return 0;
}

fn painted(page: []const u8) void {
    const t = nowMs();
    log("painted {s}", .{page});
    send(.{ .hello = .{ .release = build_options.desktop_version, .public = build_options.public, .os = "windows" } });
    sent_client = client.current();
    send(.{ .status = .{ .client = sent_client.? } });
    if (first_paint == null) {
        first_paint = t;
        if (opt.self_test) return finishSelfTest(true, "painted");
        // --measure starts and stops the pushes itself
        if (opt.demo and !opt.measure) pushing = true;
    }
    if (opt.measure) measure.painted(page, t);
}

pub fn setPushing(on: bool) void {
    pushing = on;
}

fn tick() void {
    const now = client.current();
    if (sent_client != null and now != sent_client.?) {
        sent_client = now;
        log("client: {t}", .{now});
        send(.{ .status = .{ .client = now } });
    }
    if (pushing) {
        seq += 1;
        measure.pushed(seq);
        send(demo.champSelect(seq));
    }
    if (opt.measure) measure.tick();
}

fn finishSelfTest(ok: bool, what: []const u8) void {
    var buf: [256]u8 = undefined;
    const line = std.mem.print(&buf, "{s} {s} loader={t} runtime={s} paint_ms={d:.0}\r\n", .{
        if (ok) "ok" else "fail", what, loader, runtime_version[0..runtime_version_len], first_paint orelse 0,
    }) catch "fail\r\n";
    var path: [400]u16 = undefined;
    _ = writeFile(besideExe(&path, "shell-selftest.txt"), line);
    log("self-test: {s}", .{line[0 .. line.len - 2]});
    exit_code = if (ok) 0 else 1;
    _ = c.DestroyWindow(hwnd);
}

// ---------------------------------------------------------------- window

const timer_tick = 1;
const timer_watchdog = 2;
var exit_code: u8 = 0;

fn wndProc(h: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.c) c.LRESULT {
    switch (msg) {
        c.WM_SIZE => {
            if (controller != null) _ = com(controller, "put_IsVisible", .{@as(c.BOOL, @intFromBool(wp != c.SIZE_MINIMIZED))});
            if (wp == c.SIZE_RESTORED) keepNormalRect();
            resize();
        },
        c.WM_MOVE => {
            keepNormalRect();
            if (controller != null) _ = com(controller, "NotifyParentWindowPositionChanged", .{});
        },
        c.WM_ACTIVATEAPP => if (webview != null) setMemoryLow(webview, wp == 0),
        c.WM_SETFOCUS => if (controller != null) {
            _ = com(controller, "MoveFocus", .{c.COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC});
        },
        c.WM_GETMINMAXINFO => {
            const mm: *c.MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lp)));
            const dpi: i32 = @intCast(c.GetDpiForWindow(h));
            mm.ptMinTrackSize = .{ .x = @divTrunc(place.min_w * dpi, 96), .y = @divTrunc(place.min_h * dpi, 96) };
        },
        c.WM_DPICHANGED => {
            const r: *const c.RECT = @ptrFromInt(@as(usize, @bitCast(lp)));
            _ = c.SetWindowPos(h, null, r.left, r.top, r.right - r.left, r.bottom - r.top, c.SWP_NOZORDER | c.SWP_NOACTIVATE);
        },
        c.WM_TIMER => if (wp == timer_watchdog) {
            log("watchdog: closing", .{});
            if (opt.self_test) finishSelfTest(false, "timeout") else measure.finish();
        } else tick(),
        c.WM_CLOSE => {
            if (!opt.scripted()) savePlace();
            _ = c.DestroyWindow(h);
        },
        c.WM_DESTROY => {
            client.stop();
            if (controller != null) _ = com(controller, "Close", .{});
            c.PostQuitMessage(0);
        },
        else => return c.DefWindowProcW(h, msg, wp, lp),
    }
    return 0;
}

fn keepNormalRect() void {
    if (c.IsIconic(hwnd) != 0 or c.IsZoomed(hwnd) != 0) return;
    var r: c.RECT = undefined;
    if (c.GetWindowRect(hwnd, &r) == 0) return;
    normal_rect = .{ .x = r.left, .y = r.top, .w = r.right - r.left, .h = r.bottom - r.top };
}

fn savePlace() void {
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    place.format(&w, .{ .rect = normal_rect, .maximised = c.IsZoomed(hwnd) != 0 }) catch return;
    var path: [400]u16 = undefined;
    _ = writeFile(besideExe(&path, "window.txt"), w.buffered());
}

/// Last time's place, fitted to the screen nearest it; else 1120 x 720 at this screen's
/// scale, centred on the primary screen
fn initialPlace() place.Saved {
    var path: [400]u16 = undefined;
    const saved: ?place.Saved = if (opt.scripted()) null else if (readFile(besideExe(&path, "window.txt"), 256)) |text| blk: {
        defer std.heap.page_allocator.free(text);
        break :blk place.parse(text);
    } else null;
    const scale = @as(f64, @floatFromInt(c.GetDpiForSystem())) / 96.0;
    const w: i32 = @intFromFloat(1120 * scale);
    const h: i32 = @intFromFloat(720 * scale);
    const s = saved orelse place.Saved{ .rect = .{ .x = 0, .y = 0, .w = w, .h = h }, .maximised = false };
    const r: c.RECT = .{ .left = s.rect.x, .top = s.rect.y, .right = s.rect.x + s.rect.w, .bottom = s.rect.y + s.rect.h };
    const monitor = if (saved != null) c.MonitorFromRect(&r, c.MONITOR_DEFAULTTONEAREST) else c.MonitorFromWindow(null, c.MONITOR_DEFAULTTOPRIMARY);
    var mi: c.MONITORINFO = undefined;
    mi.cbSize = @sizeOf(c.MONITORINFO);
    if (c.GetMonitorInfoW(monitor, &mi) == 0) return s;
    const work: place.Rect = .{ .x = mi.rcWork.left, .y = mi.rcWork.top, .w = mi.rcWork.right - mi.rcWork.left, .h = mi.rcWork.bottom - mi.rcWork.top };
    var fitted = place.fit(s.rect, work);
    if (saved == null) {
        fitted.x = work.x + @divTrunc(work.w - fitted.w, 2);
        fitted.y = work.y + @divTrunc(work.h - fitted.h, 2);
    }
    return .{ .rect = fitted, .maximised = s.maximised };
}

/// Starting it again brings the open window forward instead
fn alreadyOpen() bool {
    _ = c.CreateMutexW(null, 0, instance_mutex);
    if (c.GetLastError() != c.ERROR_ALREADY_EXISTS) return false;
    if (c.FindWindowW(class_name, null)) |open| {
        if (c.IsIconic(open) != 0) _ = c.ShowWindow(open, c.SW_RESTORE);
        _ = c.SetForegroundWindow(open);
    }
    return true;
}

fn parseArgs(args: []const [:0]const u8) !void {
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        const next = if (i + 1 < args.len) args[i + 1] else "";
        if (std.mem.eql(u8, a, "--dir")) {
            opt.dir = next;
            i += 1;
        } else if (std.mem.eql(u8, a, "--page")) {
            opt.page = files.clean(next) orelse return error.BadPage;
            i += 1;
        } else if (std.mem.eql(u8, a, "--also")) {
            if (opt.n_also == opt.also.len) return error.TooManyPages;
            opt.also[opt.n_also] = files.clean(next) orelse return error.BadPage;
            opt.n_also += 1;
            i += 1;
        } else if (std.mem.eql(u8, a, "--scale")) {
            opt.scale = try std.fmt.parseFloat(f64, next);
            i += 1;
        } else if (std.mem.eql(u8, a, "--loader")) {
            opt.loader = std.meta.stringToEnum(Loader, next) orelse return error.BadLoader;
            i += 1;
        } else if (std.mem.eql(u8, a, "--demo")) {
            opt.demo = true;
        } else if (std.mem.eql(u8, a, "--devtools")) {
            opt.devtools = true;
        } else if (std.mem.eql(u8, a, "--measure")) {
            opt.measure = true;
        } else if (std.mem.eql(u8, a, "--self-test")) {
            opt.self_test = true;
        } else return error.UnknownArgument;
    }
}

pub fn main(init: std.process.Init) u8 {
    run(init) catch |e| {
        log("error: {t}", .{e});
        if (!opt.scripted()) {
            var buf: [200]u8 = undefined;
            _ = message(std.mem.print(&buf, "meiolol couldn't start: {t}", .{e}) catch "meiolol couldn't start", c.MB_ICONERROR);
        }
        exit_code = 1;
    };
    log("exit {d}", .{exit_code});
    if (log_file != null) _ = c.CloseHandle(log_file);
    return exit_code;
}

fn run(init: std.process.Init) !void {
    var cr: c.FILETIME = undefined;
    var ex: c.FILETIME = undefined;
    var k: c.FILETIME = undefined;
    var u: c.FILETIME = undefined;
    _ = c.GetProcessTimes(c.GetCurrentProcess(), &cr, &ex, &k, &u);
    created_100ns = ft64(cr);

    exe_dir_len = c.GetModuleFileNameW(null, &exe_dir, exe_dir.len);
    while (exe_dir_len > 0 and exe_dir[exe_dir_len - 1] != '\\') exe_dir_len -= 1;
    if (exe_dir_len > 0) exe_dir_len -= 1;
    try parseArgs(try init.minimal.args.toSlice(init.arena.allocator()));
    var path: [400]u16 = undefined;
    log_file = c.CreateFileW(besideExe(&path, "shell.log"), c.GENERIC_WRITE, c.FILE_SHARE_READ, null, c.CREATE_ALWAYS, c.FILE_ATTRIBUTE_NORMAL, null);
    log("start, release {d}, {s}", .{ build_options.desktop_version, if (build_options.public) "public" else "private" });

    if (!opt.scripted() and alreadyOpen()) return;
    // PER_MONITOR_AWARE_V2: sharp text at 150%, and WM_DPICHANGED between screens
    _ = c.SetProcessDpiAwarenessContext(@ptrFromInt(@as(usize, @bitCast(@as(isize, -4)))));
    try check(c.CoInitializeEx(null, c.COINIT_APARTMENTTHREADED), "CoInitializeEx");
    if (!hasRuntime()) {
        noRuntime();
        if (opt.self_test) finishSelfTest(false, "no-runtime");
        return error.NoWebView2Runtime;
    }

    const inst = c.GetModuleHandleW(null);
    const wc: c.WNDCLASSEXW = .{
        .cbSize = @sizeOf(c.WNDCLASSEXW),
        .style = 0,
        .lpfnWndProc = &wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = inst,
        .hIcon = LoadIconW(inst, 1), // meiolol.rc
        .hCursor = c.LoadCursorW(null, @ptrFromInt(32512)),
        .hbrBackground = c.CreateSolidBrush(0x000a0908),
        .lpszMenuName = null,
        .lpszClassName = class_name,
        .hIconSm = null,
    };
    if (c.RegisterClassExW(&wc) == 0) return error.RegisterClass;
    const at = initialPlace();
    normal_rect = at.rect;
    hwnd = c.CreateWindowExW(0, class_name, W("meiolol"), c.WS_OVERLAPPEDWINDOW, at.rect.x, at.rect.y, at.rect.w, at.rect.h, null, null, inst, null);
    if (hwnd == null) return error.CreateWindow;
    // Scripted runs open on Jacob's screen: don't take the keyboard from him
    _ = c.ShowWindow(hwnd, if (opt.scripted()) c.SW_SHOWNOACTIVATE else if (at.maximised) c.SW_SHOWMAXIMIZED else c.SW_SHOWNORMAL);
    _ = c.UpdateWindow(hwnd);
    t_window = nowMs();

    _ = c.SetTimer(hwnd, timer_tick, 1000, null);
    if (opt.self_test) _ = c.SetTimer(hwnd, timer_watchdog, 30_000, null);
    if (opt.measure) _ = c.SetTimer(hwnd, timer_watchdog, measure.watchdog_ms, null);
    if (opt.measure) measure.start();
    if (!opt.self_test) client.start(init.gpa, init.io, init.environ_map.get("MEIOLOL_LOCKFILE")) catch |e|
        log("client poller: {t}", .{e});
    try startEnvironment();

    var msg: c.MSG = undefined;
    while (c.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = c.TranslateMessage(&msg);
        _ = c.DispatchMessageW(&msg);
    }
}

// The roots are pseudo-handles (0x80000002), misaligned for translate-c's HKEY pointer type
const hklm: usize = 0x80000002;
const hkcu: usize = 0x80000001;
extern "advapi32" fn RegOpenKeyExW(key: usize, sub: [*:0]const u16, opts: u32, sam: u32, out: *usize) callconv(.winapi) i32;
extern "advapi32" fn RegQueryValueExW(key: usize, name: [*:0]const u16, reserved: ?*u32, kind: ?*u32, data: [*]u8, size: *u32) callconv(.winapi) i32;
extern "advapi32" fn RegCloseKey(key: usize) callconv(.winapi) i32;
// Resource ids are odd pointers (MAKEINTRESOURCE), misaligned for translate-c's LPCWSTR
extern "user32" fn LoadIconW(inst: c.HINSTANCE, id: usize) callconv(.winapi) c.HICON;
