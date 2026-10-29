//! ui-account.wasm: the account pages (ui.account.Account), loaded by their own script
//! tag. Sends the form to /auth/KIND.bin, read from the form itself once sent; a sign-in
//! goes on to ?next= or the role's page. The account page fetches /auth/me.bin and
//! devices.bin (signed out: to the login page), removes an app, logs out
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const Held = @import("held.zig").Held;
const acct = ui.account;
const ac = ui.accountsdata;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

const Call = enum(i32) { send, me, devices, revoke, logout };

var page: acct.Account = .{ .kind = .login };
var server: acct.Account = .{ .kind = .login };
var island: ?*ui.island.Island(acct.Account, dom.Dom) = null;

var me: Held(ac.Me) = .{};
var devices: Held(ac.Devices) = .{};

const login_again = "/login?next=/account";

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(acct.sel)}, zjb.Handle);
    if (root == .null) return;
    const kind = std.meta.stringToEnum(acct.Kind, dom.attrOf(root, "data-kind")) orelse .login;
    root.release();
    server = .{ .kind = kind };
    page = server;
    island = dom.rt.add(acct.Account, &page, &server, acct.sel) catch return dom.dom.warn("account: out of memory");
    dom.rt.changed = changed;
    switch (kind) {
        .login => {},
        .signup, .join => if (token().len == 0) {
            page.say = .no_link;
            render();
        },
        .account => {
            get(.me, "/auth/me.bin");
            get(.devices, "/auth/devices.bin");
        },
    }
}

fn render() void {
    if (island) |i| i.render();
}

fn get(c: Call, path: []const u8) void {
    dom.ask("GET", path, null, @backingInt(c), done);
}

/// The link's token: the fragment without its #
fn token() []const u8 {
    const S = struct {
        var buf: [128]u8 = undefined;
    };
    const h = location("hash", &S.buf);
    return if (h.len > 1) h[1..] else "";
}

fn location(comptime part: []const u8, buf: []u8) []const u8 {
    const v = zjb.global("location").get(part, zjb.Handle);
    defer v.release();
    return v.readString(buf) catch "";
}

fn go(path: []const u8) void {
    const s = zjb.string(path);
    defer s.release();
    zjb.global("location").call("assign", .{s}, void);
}

fn changed() void {
    const w = page.want;
    page.want = .none;
    switch (w) {
        .none => {},
        .send => send(),
        .revoke => |id| post("/auth/revoke.bin", ac.Revoke, .{ .id = id }, .revoke),
        .logout => |all| dom.ask("POST", if (all) "/auth/logout.bin?all=1" else "/auth/logout.bin", "", @backingInt(Call.logout), done),
    }
}

fn post(path: []const u8, comptime T: type, v: T, c: Call) void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var body: std.ArrayList(u8) = .empty;
    defer @memset(body.items, 0);
    ui.data.encode(arena.allocator(), T, v, &body) catch return;
    dom.ask("POST", path, body.items, @backingInt(c), done);
}

/// The form's fields as the browser has them (typed or autofilled)
const Form = struct {
    data: zjb.Handle,
    bufs: [3][512]u8 = undefined,
    used: usize = 0,

    fn get(f: *Form, comptime field: []const u8) []const u8 {
        const v = f.data.call("get", .{zjb.constString(field)}, zjb.Handle);
        defer v.release();
        if (v == .null) return "";
        defer f.used += 1;
        return v.readString(&f.bufs[f.used]) catch "";
    }

    fn trimmed(f: *Form, comptime field: []const u8) []const u8 {
        return std.mem.trim(u8, f.get(field), " \t");
    }
};

fn send() void {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(acct.sel ++ " form")}, zjb.Handle);
    defer el.release();
    var f: Form = .{ .data = zjb.global("FormData").new(.{el}) };
    defer {
        // The typed passwords out of wasm memory
        for (&f.bufs) |*b| @memset(b, 0);
        f.data.release();
    }
    switch (page.kind) {
        .login => post("/auth/login.bin", ac.Login, .{ .username = f.trimmed("username"), .password = f.get("password") }, .send),
        .signup => post("/auth/signup.bin", ac.Signup, .{ .link = token(), .email = f.trimmed("email"), .password = f.get("password") }, .send),
        .join => post("/auth/join.bin", ac.Join, .{ .invite = token(), .username = f.trimmed("username"), .password = f.get("password") }, .send),
        .account => post("/auth/password.bin", ac.Password, .{ .password = f.get("password"), .new = f.get("new") }, .send),
    }
}

fn done(ctx: i32, status: u16, bytes: ?[]u8) void {
    const c = std.enums.fromInt(Call, ctx) orelse return;
    var none: [0]u8 = .{};
    const b = bytes orelse &none;
    var kept = false;
    defer if (!kept and b.len > 0) gpa.free(b);
    if (status == 401 and page.kind == .account) return go(login_again);
    switch (c) {
        .send => {
            if (page.answered(status, b)) {
                kept = true;
                var q: [512]u8 = undefined;
                const m = me.set(b) orelse return go("/");
                return go(acct.next(location("search", &q), m.*));
            }
        },
        .me => if (status == 200) {
            kept = true;
            page.me = if (me.set(b)) |m| m.* else null;
            page.me_at = if (page.me == null) .down else .ok;
        } else {
            page.me_at = .down;
        },
        .devices => if (status == 200) {
            kept = true;
            if (devices.set(b)) |d| {
                page.devices = d.devices;
                page.devices_at = .ok;
            } else page.devices_at = .down;
        } else {
            page.devices_at = .down;
        },
        .revoke => get(.devices, "/auth/devices.bin"),
        .logout => return go("/login"),
    }
    render();
}
