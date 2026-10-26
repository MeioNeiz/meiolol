//! SignIn: the app's sign-in to meio.lol (the poller's device.zig does the request). The
//! form is the screen on a first start with no data yet, else a line under it that opens
//! the form. Both editions. What's typed stays in Form until sent; the password input is
//! a new node after each try, so the DOM keeps no password either
const std = @import("std");
const tree = @import("tree.zig");
const button = @import("button.zig");
const url = @import("url.zig");
const toshell = @import("toshell.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "SignIn";
pub const scope = .{".c-signin"};

/// The shell's, from the poller
pub const SignIn = struct {
    /// No data yet: the form is the screen
    full: bool = false,
    busy: bool = false,
    /// Why the last try or update check failed; "" for none
    message: []const u8 = "",
};

/// The island's: what's typed, and whether the line was opened
pub const Form = struct {
    open: bool = false,
    user: url.Str(64) = .{},
    pass: url.Str(255) = .{},
    /// Keys the password input
    tries: u32 = 0,

    pub const Msg = enum { open, user, pass, key, submit };

    pub fn update(f: *Form, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .open => {
                f.open = true;
                ev.after = .{ .op = .focus, .ref = "user" };
            },
            .user => f.user.set(ev.text),
            .pass => f.pass.set(ev.text),
            .key => if (std.mem.eql(u8, ev.text, "Enter")) f.submit(),
            .submit => f.submit(),
        }
    }

    fn submit(f: *Form) void {
        const user = std.mem.trim(u8, f.user.slice(), " ");
        if (user.len == 0 or f.pass.len == 0) return;
        toshell.send(.{ .signin = .{ .username = user, .password = f.pass.slice() } });
        @memset(&f.pass.buf, 0);
        f.pass.len = 0;
        f.tries +%= 1;
    }
};

pub fn view(h: *H, s: SignIn, f: *Form) N {
    if (!s.full and !f.open) return h.div(.{ .class = "c-signin line" }, .{
        if (s.message.len > 0) h.span(.{}, .{s.message}) else h.span(.{}, .{W.line}),
        button.view(h, .{ .s = .s, .on = h.on(f, .open) }, .{W.sign_in}),
    });
    const ready = !s.busy and f.user.len > 0 and f.pass.len > 0;
    return h.div(.{ .class = "c-signin", .data_full = s.full }, .{
        h.el(.h2, .{}, .{W.title}),
        h.p(.{}, .{W.why}),
        h.input(.{
            .value = f.user.slice(),
            .placeholder = W.user,
            .aria_label = W.user,
            .autocomplete = "username",
            .data_ref = "user",
            .on_input = h.on(f, .user),
            .on_keydown = h.on(f, .key),
        }),
        h.input(.{
            .key = f.tries +% 1,
            .type = "password",
            .placeholder = W.pass,
            .aria_label = W.pass,
            .autocomplete = "current-password",
            .on_input = h.on(f, .pass),
            .on_keydown = h.on(f, .key),
        }),
        button.view(h, .{ .v = .primary, .disabled = !ready, .on = h.on(f, .submit) }, .{if (s.busy) W.busy else W.sign_in}),
        if (s.message.len > 0 and !s.busy) h.p(.{ .class = "fail" }, .{s.message}) else null,
    });
}

const W = struct {
    const line = plain("Sign in to keep the statistics and the app current.");
    const sign_in = plain("Sign in");
    const busy = plain("Signing in…");
    const title = plain("Sign in to meio.lol");
    const why = plain("With the account you were invited to. The app keeps a sign-in of its own, which you can remove on your account page at meio.lol.");
    const user = plain("Username or email");
    const pass = plain("Password");
};

pub const css =
    \\@layer components {
    \\  .c-signin { display: flex; flex-direction: column; gap: var(--sp-2); width: 100%; max-width: 360px; }
    \\  .c-signin[data-full] { align-self: center; padding-top: var(--sp-6); }
    \\  .c-signin h2 { margin: 0; font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-signin p { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-signin .fail { color: var(--turn); }
    \\  .c-signin > .c-btn { align-self: flex-start; }
    \\  .c-signin.line { flex-direction: row; align-items: center; max-width: none; color: var(--muted); font-size: var(--fs-s); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, SignIn, Form }{
        .{ "line under the content", .{}, .{} },
        .{ "first start, no data", .{ .full = true }, .{} },
        .{ "signing in", .{ .full = true, .busy = true }, .{ .user = demoUser() } },
        .{ "refused", .{ .full = true, .message = "Wrong username or password." }, .{ .user = demoUser() } },
    };
    for (states) |s| {
        const f = h.mem.create(Form) catch return;
        f.* = s[2];
        g.add(s[0], view(h, s[1], f));
    }
}

fn demoUser() url.Str(64) {
    var u: url.Str(64) = .{};
    u.set("ann");
    return u;
}

const testing = std.testing;

var sent: []const u8 = "";
var sent_buf: [512]u8 = undefined;

fn record(o: toshell.Out) void {
    var w: std.Io.Writer = .fixed(&sent_buf);
    toshell.json(o, &w) catch unreachable;
    sent = w.buffered();
}

test "on the fake DOM: the line opens the form, Enter sends, the password input is new after" {
    const island = @import("island.zig");
    const Fake = @import("fakedom.zig").Fake;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const old = toshell.send;
    defer toshell.send = old;
    toshell.send = record;
    sent = "";
    var fake: Fake = .{ .a = a };
    var rt: island.Runtime(Fake) = .init(a, &fake);
    const Page = struct {
        s: SignIn = .{},
        f: Form = .{},
        pub const Msg = union(enum) { none };
        pub fn update(_: *@This(), _: Msg, _: *tree.Event) void {}
        pub fn view(p: *@This(), hh: *H) N {
            return hh.div(.{}, .{form(hh, p.s, &p.f)});
        }
    };
    var server: Page = .{};
    var state = server;
    const t = try a.create(tree.Tree);
    t.* = .{};
    var h: H = .init(a, t);
    t.root = server.view(&h);
    fake.server = t;
    const i = try rt.add(Page, &state, &server, "#signin");
    var cur = i.current();
    _ = rt.event(0, .{ .kind = .click, .target = cur.node(cur.find(cur.root, "class", "c-btn").?).dom });
    try testing.expect(state.f.open);
    cur = i.current();
    const user = cur.node(cur.find(cur.root, "data-ref", "user").?).dom;
    const pass = cur.node(cur.find(cur.root, "type", "password").?).dom;
    _ = rt.event(0, .{ .kind = .input, .target = user, .text = " ann " });
    _ = rt.event(0, .{ .kind = .keydown, .target = user, .text = "Enter" });
    try testing.expectEqualStrings("", sent);
    _ = rt.event(0, .{ .kind = .input, .target = pass, .text = "hunter2" });
    const creates = fake.creates;
    const forgotten = fake.forgotten;
    _ = rt.event(0, .{ .kind = .keydown, .target = pass, .text = "Enter" });
    try testing.expectEqualStrings("{\"signin\":{\"username\":\"ann\",\"password\":\"hunter2\"}}", sent);
    try testing.expectEqual(@as(u8, 0), state.f.pass.len);
    try testing.expectEqual(creates + 1, fake.creates);
    try testing.expectEqual(forgotten + 1, fake.forgotten);
    try testing.expectEqual(@as(u32, 0), fake.warnings);
}

const form = view;
