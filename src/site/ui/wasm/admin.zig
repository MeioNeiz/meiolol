//! ui-admin.wasm: /admin/ (ui.adminpage.Page), server-rendered empty. Fetches admin.bin
//! (the box's snapshot, again each 5 min), api/live.bin (each minute) and /auth/me.bin;
//! accounts.bin once the Accounts tab shows. Polls only while the tab shows, catching up
//! when it comes back. Runs what the page's `want` asks: an action (its result from the
//! next live.bin), an account change, logout, copy. dom.fetch and dom.send keep one
//! callback: every request here answers in `done`, by its Call
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const ap = ui.adminpage;
const ad = ui.admindata;
const ac = ui.accountsdata;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

const Call = enum(i32) { snap, live, me, accounts, action, write, link, logout };

var page: ap.Page = .{};
var server: ap.Page = .{};
var island: ?*ui.island.Island(ap.Page, dom.Dom) = null;

/// A decoded answer and the bytes its slices point into, freed when the next lands
fn Held(comptime T: type) type {
    return struct {
        mem: ?std.heap.ArenaAllocator = null,
        bytes: []u8 = &.{},
        v: T = undefined,

        fn set(s: *@This(), b: []u8) ?*const T {
            var next: std.heap.ArenaAllocator = .init(gpa);
            const v = ui.data.decode(next.allocator(), T, b) catch {
                next.deinit();
                gpa.free(b);
                return null;
            };
            s.drop();
            s.* = .{ .mem = next, .bytes = b, .v = v };
            return &s.v;
        }

        fn drop(s: *@This()) void {
            if (s.mem) |*m| m.deinit();
            if (s.bytes.len > 0) gpa.free(s.bytes);
            s.* = .{};
        }
    };
}

var snap: Held(ad.Snapshot) = .{};
var live: Held(ad.Live) = .{};
var me: Held(ac.Me) = .{};
var accounts: Held(ac.Accounts) = .{};
var invite: Held(ac.Invite) = .{};

var in_flight: std.enums.EnumSet(Call) = .empty;
var snap_at: i64 = 0;
/// An action sent, until a live.bin fetched after its answer: which, the newest log line
/// of it before (the box's clock, not ours), answered
var acting: ?struct { act: ap.Act, before: i64, answered: bool = false } = null;
/// A live.bin was in flight when the action answered: its answer is from before
var again = false;
/// The last run's output, copied out of live.bin's bytes
var ran_out: []u8 = &.{};
/// What the link being made is for (Page.Link without its token)
var linking: ap.Link = .{ .token = "" };

const live_ms = 60_000;
const snap_s = 300;

export fn main() void {
    dom.start();
    island = dom.rt.add(ap.Page, &page, &server, ap.sel) catch return dom.dom.warn("admin: out of memory");
    dom.rt.changed = changed;
    get(.snap, "admin.bin");
    get(.live, "api/live.bin");
    get(.me, "/auth/me.bin");
    zjb.global("window").call("setInterval", .{ zjb.fnHandle("adminTick", &onTick), @as(i32, live_ms) }, void);
    zjb.global("document").call("addEventListener", .{ zjb.constString("visibilitychange"), zjb.fnHandle("adminShown", &onShown), @as(i32, 0) }, void);
}

fn now() i64 {
    return @intFromFloat(@divFloor(zjb.global("Date").call("now", .{}, f64), 1000));
}

fn render() void {
    page.now = now();
    if (island) |i| i.render();
}

fn get(c: Call, path: []const u8) void {
    if (in_flight.contains(c)) return;
    in_flight.insert(c);
    dom.fetch(path, @backingInt(c), done);
}

/// Only while the tab shows: a hidden one catches up when it comes back
fn onTick() callconv(.c) void {
    if (zjb.global("document").get("hidden", bool)) return;
    get(.live, "api/live.bin");
    if (now() - snap_at >= snap_s) get(.snap, "admin.bin");
}

fn onShown(e: zjb.Handle) callconv(.c) void {
    e.release();
    onTick();
}

/// The Accounts tab's list, once the role is known to manage them
fn needAccounts() void {
    if (page.tab == .accounts and page.accounts == null and page.can("manage_accounts")) get(.accounts, "/auth/accounts.bin");
}

fn changed() void {
    const w = page.want;
    page.want = .none;
    switch (w) {
        .none, .accounts => {},
        .refresh => {
            get(.snap, "admin.bin");
            get(.live, "api/live.bin");
            get(.me, "/auth/me.bin");
            if (page.accounts != null) get(.accounts, "/auth/accounts.bin");
        },
        .run => |a| run(a),
        .logout => dom.send("POST", "/auth/logout.bin", "", @backingInt(Call.logout), done),
        .invite => |i| if (page.accounts) |l| if (i < l.roles.len) {
            linking = .{ .role = i, .token = "" };
            write("/auth/invite.bin", ac.NewInvite, .{ .role = l.roles[i] }, .link);
        },
        .role => |x| if (page.accounts) |l| if (x[0] < l.accounts.len and x[1] < l.roles.len) {
            write("/auth/role.bin", ac.Manage, .{ .username = l.accounts[x[0]].username, .role = l.roles[x[1]] }, .write);
        },
        .disable => |row| if (page.accounts) |l| if (row < l.accounts.len) {
            const a = l.accounts[row];
            write("/auth/disable.bin", ac.Manage, .{ .username = a.username, .disabled = !a.disabled }, .write);
        },
        .reset => |row| if (page.accounts) |l| if (row < l.accounts.len) {
            linking = .{ .reset = row, .token = "" };
            write("/auth/reset.bin", ac.Manage, .{ .username = l.accounts[row].username }, .link);
        },
        .copy => if (page.link) |k| copy(k.token),
    }
    needAccounts();
    render();
}

fn run(a: ap.Act) void {
    acting = .{ .act = a, .before = newest(a) orelse std.math.minInt(i64) };
    var buf: [48]u8 = undefined;
    const path = std.fmt.bufPrint(&buf, "api/action/{s}", .{a.path()}) catch return;
    dom.send("POST", path, "", @backingInt(Call.action), done);
}

fn write(path: []const u8, comptime T: type, v: T, c: Call) void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var body: std.ArrayList(u8) = .empty;
    ui.data.encode(arena.allocator(), T, v, &body) catch return;
    dom.send("POST", path, body.items, @backingInt(c), done);
}

fn copy(token: []const u8) void {
    var buf: [160]u8 = undefined;
    const link = std.fmt.bufPrint(&buf, ap.join_link, .{token}) catch return;
    const clip = zjb.global("navigator").get("clipboard", zjb.Handle);
    defer clip.release();
    if (!zjb.global("window").call("Boolean", .{clip}, bool)) return;
    const s = zjb.string(link);
    defer s.release();
    const p = clip.call("writeText", .{s}, zjb.Handle);
    defer p.release();
    p.call("then", .{ zjb.fnHandle("adminCopied", &onCopied), zjb.fnHandle("adminNoCopy", &onNoCopy) }, zjb.Handle).release();
}

fn onCopied() callconv(.c) void {
    page.copied = true;
    render();
}

/// No clipboard access: the link stays in its box to copy by hand
fn onNoCopy(e: zjb.Handle) callconv(.c) void {
    e.release();
}

fn done(ctx: i32, bytes: ?[]u8) void {
    const c = std.enums.fromInt(Call, ctx) orelse return;
    in_flight.remove(c);
    defer render();
    switch (c) {
        .snap => {
            const b = bytes orelse {
                page.snap_failed = page.snap == null;
                return;
            };
            page.snap = snap.set(b) orelse page.snap;
            page.snap_failed = page.snap == null;
            snap_at = now();
        },
        .live => {
            defer if (again) {
                again = false;
                get(.live, "api/live.bin");
            } else settle();
            const b = bytes orelse {
                page.live_down = true;
                return;
            };
            const l = live.set(b) orelse {
                page.live_down = true;
                return;
            };
            page.live = l;
            page.live_at = now();
            page.live_down = false;
        },
        .me => {
            const b = bytes orelse return;
            page.me = me.set(b) orelse page.me;
            needAccounts();
        },
        .accounts => {
            const b = bytes orelse {
                page.acct_failed = true;
                return;
            };
            page.accounts = accounts.set(b) orelse page.accounts;
            page.pending = null;
        },
        .action => {
            if (bytes) |b| gpa.free(b);
            if (acting) |*x| x.answered = true;
            if (in_flight.contains(.live)) again = true else get(.live, "api/live.bin");
        },
        .write, .link => {
            page.acct_failed = bytes == null;
            const b = bytes orelse return;
            if (c == .link) {
                const v = invite.set(b) orelse {
                    page.acct_failed = true;
                    return;
                };
                linking.token = v.invite;
                page.link = linking;
                page.copied = false;
            } else gpa.free(b);
            get(.accounts, "/auth/accounts.bin");
        },
        .logout => {
            if (bytes) |b| gpa.free(b);
            zjb.global("location").call("assign", .{zjb.constString("/login")}, void);
        },
    }
}

/// The newest log line of `a` in live.bin
fn newest(a: ap.Act) ?i64 {
    const l = page.live orelse return null;
    var t: ?i64 = null;
    for (l.actions) |x| if (std.mem.eql(u8, x.name, a.path())) {
        t = x.time;
    };
    return t;
}

/// An action's result from its log line in the live.bin after its answer; failed when
/// that live.bin failed or has no new line
fn settle() void {
    const a = acting orelse return;
    if (!a.answered) return;
    acting = null;
    page.running = null;
    var line: ?ad.Action = null;
    if (page.live) |l| if (!page.live_down) for (l.actions) |x| {
        if (x.time > a.before and std.mem.eql(u8, x.name, a.act.path())) line = x;
    };
    const x = line orelse {
        page.ran = .{ .act = a.act, .ok = false, .output = "" };
        return;
    };
    if (ran_out.len > 0) gpa.free(ran_out);
    ran_out = gpa.dupe(u8, x.output) catch &.{};
    page.ran = .{ .act = a.act, .ok = std.mem.eql(u8, x.result, "ok"), .output = ran_out };
}
