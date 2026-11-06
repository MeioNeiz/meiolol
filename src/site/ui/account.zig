//! The account pages (docs/plan/accounts.md): log in, make an account (/signup: open, a
//! username and password; /signup#LINK: a sign-up link's email form), set up a login from an invite or reset link (/join#INVITE) and
//! the signed-in account (/account: who, a new password, its desktop apps, log out,
//! delete).
//! Island Account (ui-account.wasm) against /auth/NAME.bin (api/accounts.zig). A link's
//! token stays in the fragment, which browsers never send. What is typed stays in the
//! inputs: the wasm reads the form once it is sent, so autofill before the island counts
//! and no password sits in the state
const std = @import("std");
const tree = @import("tree.zig");
const button = @import("button.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const url = @import("url.zig");
const ac = @import("accountsdata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Account";
pub const scope = .{".c-account"};
pub const sel = "[data-island=account]";

pub const Kind = enum { login, signup, join, account };

const W = struct {
    const login = plain("Log in");
    const signup = plain("Make your account");
    const no_account = plain("No account?");
    const sign_up = plain("Sign up");
    const have_one = plain("Have one?");
    const no_email = plain("No email needed: we keep none.");
    const join = plain("Set up your login");
    const account = plain("Your account");
    const user = plain("Email or username");
    const email = plain("Email");
    const username = plain("Username");
    const pass = plain("Password");
    const current = plain("Current password");
    const new = plain("New password");
    const ten = plain("10 or more characters");
    const eight = plain("8 or more characters");
    const reset_hint = plain("Leave it empty if this link resets your password");
    const new_hint = plain("8 or more characters. Your other devices are signed out");
    const make = plain("Make account");
    const save = plain("Save");
    const change = plain("Change password");
    const change_h = plain("Change your password");
    const email_note = plain("Your email is only your login: nothing is sent to it.");
    const see = plain("See the");
    const privacy = plain("privacy policy");
    const no_link = plain("This page needs the link you were sent.");
    const down = plain("Can't reach the server. Try again in a moment.");
    const changed = plain("Password changed. Your other devices are signed out.");
    const loading = plain("Loading…");
    const as = plain("Logged in as");
    const apps = plain("Desktop apps");
    const apps_note = plain("Each copy of the meiolol app signed in to this account. Remove one to stop it updating.");
    const get = plain("Download the app");
    const get_note = plain("(Windows, a zip: open it and run meiolol-desktop.exe, which installs itself).");
    const no_apps = plain("None yet: sign in from the app.");
    const apps_down = plain("Can't load them right now.");
    const remove = plain("Remove");
    const out = plain("Log out");
    const out_here = plain("This browser");
    const out_all = plain("Everywhere");
    const out_note = plain("Everywhere includes your desktop apps.");
    const out_note_web = plain("Everywhere logs out every browser you use.");
    const del_h = plain("Delete your account");
    const del_note = plain("It goes at once, with its sign-ins and desktop apps. This can't be undone.");
    const del = plain("Delete account");
    const wait = phrase.Phrase("Too many tries: wait {n:int} min.");
    const failed = phrase.Phrase("Something went wrong ({n:int}).");
    const tester = plain("Draft tester");
    const admin = plain("Admin pages");
};

/// What a sent form or the account's loads came back with
pub const Say = enum { none, no_link, down, server, wait, failed, changed };

pub const Load = enum { loading, ok, down };

pub const Account = struct {
    kind: Kind,
    /// Sign-up through a link (its token in the fragment): the email form, else the open one
    linked: bool = false,
    busy: bool = false,
    say: Say = .none,
    /// Say.server's: the API's error, as a sentence
    server: url.Str(96) = .{},
    /// Say.wait's minutes, Say.failed's HTTP status
    n: u32 = 0,
    /// Keys the form: a new, empty one after a password change
    forms: u32 = 0,
    /// The account page's form last sent, whose answer `say` is
    sent: Sent = .form,
    /// The account page's: who, and its desktop apps
    me: ?ac.Me = null,
    me_at: Load = .loading,
    devices: []const ac.Device = &.{},
    devices_at: Load = .loading,
    /// For the wasm after an event
    want: Want = .none,

    const P = @This();

    pub const Sent = enum { form, delete };

    pub const Want = union(enum) { none, send, delete, revoke: i64, logout: bool };

    pub const Msg = union(enum) { submit, delete, revoke: u32, logout: bool };

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .submit, .delete => {
                ev.handled = true;
                if (p.busy) return;
                p.busy = true;
                p.say = .none;
                p.sent = if (m == .delete) .delete else .form;
                p.want = if (m == .delete) .delete else .send;
            },
            .revoke => |i| if (i < p.devices.len) {
                p.want = .{ .revoke = p.devices[i].id };
            },
            .logout => |all| p.want = .{ .logout = all },
        }
    }

    /// A sent form's answer: status 0 for none. True when it signed in (the page moves on)
    pub fn answered(p: *P, status: u16, body: []const u8) bool {
        p.busy = false;
        p.say = switch (status) {
            0 => .down,
            200 => if (p.kind == .account and p.sent == .form) .changed else return true,
            429 => .wait,
            else => if (errorOf(body)) |e| blk: {
                p.server.set(e);
                if (p.server.len > 0) p.server.buf[0] = std.ascii.toUpper(p.server.buf[0]);
                if (p.server.len < p.server.buf.len) {
                    p.server.buf[p.server.len] = '.';
                    p.server.len += 1;
                }
                break :blk .server;
            } else .failed,
        };
        p.n = if (status == 429) ((retryOf(body) orelse 60) + 59) / 60 else status;
        if (p.say == .changed) p.forms +%= 1;
        return false;
    }

    pub fn view(p: *P, h: *H) N {
        const at = .{ .class = "c-account", .data_island = "account", .data_kind = p.kind };
        const title = h.el(.h1, .{}, .{switch (p.kind) {
            .login => W.login,
            .signup => W.signup,
            .join => W.join,
            .account => W.account,
        }});
        return switch (p.kind) {
            .login => h.div(at, .{ title, p.form(h), h.p(.{ .class = "info" }, .{ W.no_account, " ", h.a(.{ .href = "/signup" }, .{W.sign_up}) }) }),
            .signup => h.div(at, .{
                title,
                p.form(h),
                h.p(.{ .class = "info" }, .{ if (p.linked) W.email_note else W.no_email, " ", W.see, " ", privacy(h), "." }),
                if (p.linked) null else h.p(.{ .class = "info" }, .{ W.have_one, " ", h.a(.{ .href = "/login" }, .{W.login}) }),
            }),
            .join => h.div(at, .{ title, p.form(h), h.p(.{ .class = "info" }, .{ W.see, " ", privacy(h), "." }) }),
            .account => blk: {
                const after = p.rest(h);
                break :blk h.div(at, .{ title, p.who(h), h.h2(.{}, .{W.change_h}), p.form(h), &after, p.deleteForm(h) });
            },
        };
    }

    fn form(p: *P, h: *H) N {
        const fields: [3]N = switch (p.kind) {
            .login => .{
                field(h, W.user, null, .{ .name = "username", .autocomplete = "username", .autocapitalize = "none", .spellcheck = "false", .required = true }),
                field(h, W.pass, null, .{ .name = "password", .type = "password", .autocomplete = "current-password", .required = true }),
                .none,
            },
            .signup => if (!p.linked) .{
                field(h, W.username, null, .{ .name = "username", .autocomplete = "username", .autocapitalize = "none", .spellcheck = "false", .minlength = "2", .maxlength = "64", .required = true }),
                field(h, W.pass, W.eight, .{ .name = "password", .type = "password", .autocomplete = "new-password", .minlength = "8", .required = true }),
                .none,
            } else .{
                field(h, W.email, null, .{ .name = "email", .type = "email", .autocomplete = "email", .autocapitalize = "none", .spellcheck = "false", .required = true }),
                field(h, W.pass, W.ten, .{ .name = "password", .type = "password", .autocomplete = "new-password", .placeholder = "iykyk", .minlength = "10", .required = true }),
                .none,
            },
            .join => .{
                field(h, W.username, W.reset_hint, .{ .name = "username", .autocomplete = "username", .autocapitalize = "none", .spellcheck = "false" }),
                field(h, W.pass, W.eight, .{ .name = "password", .type = "password", .autocomplete = "new-password", .minlength = "8", .required = true }),
                .none,
            },
            .account => .{
                // For password managers: whose password this is
                h.input(.{ .name = "username", .autocomplete = "username", .value = if (p.me) |m| m.username else "", .hidden = true }),
                field(h, W.current, null, .{ .name = "password", .type = "password", .autocomplete = "current-password", .required = true }),
                field(h, W.new, W.new_hint, .{ .name = "new", .type = "password", .autocomplete = "new-password", .minlength = "8", .required = true }),
            },
        };
        // A submit before the island starts: POST keeps the password out of the address,
        // and /auth/ refuses it without X-Meiolol-Action, its body unread
        const action = switch (p.kind) {
            .login => "/auth/login",
            .signup => "/auth/signup",
            .join => "/auth/join",
            .account => "/auth/password",
        };
        return h.el(.form, .{ .key = p.forms, .method = "post", .action = action, .on_submit = h.on(p, .submit) }, .{
            &fields,
            button.view(h, .{ .v = .primary, .submit = true, .disabled = p.busy }, .{switch (p.kind) {
                .login => W.login,
                .signup => W.make,
                .join => W.save,
                .account => W.change,
            }}),
            if (p.say == .none or p.sent != .form) null else h.p(.{ .class = "msg", .role = "alert", .data_ok = p.say == .changed }, .{p.line(h)}),
        });
    }

    /// Not for the owner, deleted only over ssh; the password again, as the API asks
    fn deleteForm(p: *P, h: *H) N {
        const m = p.me orelse return .none;
        if (tree.eql(m.role, "owner")) return .none;
        return h.div(.{ .class = "del" }, .{
            h.h2(.{}, .{W.del_h}),
            h.p(.{ .class = "info" }, .{W.del_note}),
            h.el(.form, .{ .class = "del", .method = "post", .action = "/auth/delete", .on_submit = h.on(p, .delete) }, .{
                h.input(.{ .name = "username", .autocomplete = "username", .value = m.username, .hidden = true }),
                field(h, W.pass, null, .{ .name = "password", .type = "password", .autocomplete = "current-password", .required = true }),
                button.view(h, .{ .submit = true, .disabled = p.busy }, .{W.del}),
                if (p.say == .none or p.sent != .delete) null else h.p(.{ .class = "msg", .role = "alert" }, .{p.line(h)}),
            }),
        });
    }

    fn line(p: *const P, h: *H) tree.Text {
        return switch (p.say) {
            .none => .{ .s = "" },
            .no_link => W.no_link,
            .down => W.down,
            .server => .{ .s = p.server.slice() },
            .wait => W.wait.with(h, .{ .n = p.n }),
            .failed => W.failed.with(h, .{ .n = p.n }),
            .changed => W.changed,
        };
    }

    /// The account page's line under the title: who, and the pages the role opens
    fn who(p: *const P, h: *H) N {
        const m = p.me orelse return h.p(.{ .class = "info" }, .{if (p.me_at == .down) W.down else W.loading});
        const links = [_]struct { []const u8, []const u8, tree.Text }{
            .{ "view_private", "/private/tester", W.tester },
            .{ "view_admin", "/admin", W.admin },
        };
        var kids: [links.len]N = @splat(.none);
        var n: usize = 0;
        for (links) |l| if (can(m, l[0])) {
            kids[n] = h.a(.{ .href = l[1] }, .{l[2]});
            n += 1;
        };
        return h.p(.{ .class = "who" }, .{ h.span(.{}, .{ W.as, " ", h.b(.{}, .{m.username}), h.fmt(" ({s})", .{m.role}) }), kids[0..n] });
    }

    /// The account page's after the password form
    fn rest(p: *P, h: *H) [7]N {
        const apps = if (p.me) |m| can(m, "download_private_app") else false;
        const list: N = switch (p.devices_at) {
            .loading => h.p(.{ .class = "info" }, .{W.loading}),
            .down => h.p(.{ .class = "info" }, .{W.apps_down}),
            .ok => if (p.devices.len == 0) h.p(.{ .class = "info" }, .{W.no_apps}) else blk: {
                const rows = h.mem.alloc(N, p.devices.len) catch {
                    h.oom = true;
                    return @splat(.none);
                };
                for (p.devices, rows, 0..) |d, *r, i| r.* = h.li(.{ .key = d.id }, .{
                    h.span(.{ .class = "app" }, .{d.name}),
                    h.span(.{ .class = "when" }, .{h.fmt("signed in {f}, last used {f}", .{ Day{ .s = d.created }, Day{ .s = d.last_used } })}),
                    button.view(h, .{ .s = .s, .on = h.on(p, .{ .revoke = @intCast(i) }) }, .{W.remove}),
                });
                break :blk h.el(.ul, .{ .class = "apps" }, .{rows});
            },
        };
        return .{
            if (apps) h.h2(.{}, .{W.apps}) else .none,
            if (apps) h.p(.{ .class = "info" }, .{ h.a(.{ .href = zip, .download = "" }, .{W.get}), " ", W.get_note, " ", W.apps_note }) else .none,
            if (apps) list else .none,
            h.h2(.{}, .{W.out}),
            h.div(.{ .class = "out" }, .{
                button.view(h, .{ .on = h.on(p, .{ .logout = false }) }, .{W.out_here}),
                button.view(h, .{ .on = h.on(p, .{ .logout = true }) }, .{W.out_all}),
            }),
            h.p(.{ .class = "info" }, .{if (apps) W.out_note else W.out_note_web}),
            h.p(.{ .class = "info" }, .{ W.see, " ", privacy(h), "." }),
        };
    }
};

fn field(h: *H, label: tree.Text, hint: ?tree.Text, attrs: anytype) N {
    return h.label(.{}, .{
        h.span(.{ .class = "name" }, .{label}),
        h.input(attrs),
        if (hint) |x| h.span(.{ .class = "hint" }, .{x}) else null,
    });
}

/// The private edition's zip (hosting.md "Desktop app files"): download_private_app logins
pub const zip = "/private/desktop/meiolol-desktop.zip";

fn privacy(h: *H) N {
    return h.a(.{ .href = "/privacy#accounts" }, .{W.privacy});
}

pub fn can(m: ac.Me, cap: []const u8) bool {
    for (m.can) |c| if (tree.eql(c, cap)) return true;
    return false;
}

/// Unix seconds as "3 Oct 2026"
const Day = struct {
    s: i64,

    pub fn format(d: Day, w: *std.Io.Writer) std.Io.Writer.Error!void {
        const c = fmt.civil(@intCast(@divFloor(d.s, std.time.s_per_day)));
        try fmt.write(w, .int, c.day);
        try w.writeByte(' ');
        try w.writeAll(fmt.months_short[c.month - 1]);
        try w.writeByte(' ');
        try fmt.write(w, .int, c.year);
    }
};

/// Where a sign-in goes: back to `next` from the query (nginx's ?next=, a path on this
/// site only), else the most the role opens
pub fn next(query: []const u8, m: ac.Me) []const u8 {
    var it = std.mem.tokenizeScalar(u8, if (query.len > 0 and query[0] == '?') query[1..] else query, '&');
    while (it.next()) |kv| {
        if (!tree.startsWith(kv, "next=")) continue;
        const v = kv["next=".len..];
        if (v.len > 0 and v[0] == '/' and !tree.startsWith(v, "//") and std.mem.findScalar(u8, v, '\\') == null) return v;
    }
    return if (can(m, "view_admin")) "/admin" else if (can(m, "view_private")) "/private" else "/";
}

/// The browser's private-login mark (localStorage "login", site/shell.zig admin_link):
/// stored at sign-in, so the header's private links show from the first page after it
pub fn loginMark(m: ac.Me) []const u8 {
    return if (can(m, "view_admin")) "admin" else if (can(m, "view_private")) "tester" else "";
}

/// An error answer's {"error":"..."}: its messages hold nothing JSON escapes
fn errorOf(body: []const u8) ?[]const u8 {
    const k = "\"error\":\"";
    const at = tree.find(body, k) orelse return null;
    const s = body[at + k.len ..];
    return s[0 .. std.mem.findScalar(u8, s, '"') orelse return null];
}

fn retryOf(body: []const u8) ?u32 {
    const k = "\"retry_s\":";
    const at = tree.find(body, k) orelse return null;
    const s = body[at + k.len ..];
    var n: usize = 0;
    while (n < s.len and std.ascii.isDigit(s[n])) n += 1;
    return std.fmt.parseInt(u32, s[0..n], 10) catch null;
}

pub const css =
    \\@layer components {
    \\  .c-account { display: grid; gap: var(--sp-3); max-width: 28rem; }
    \\  .c-account h1 { margin: 0; font-size: var(--fs-xl); line-height: var(--lh-tight); }
    \\  .c-account h2 { margin: var(--sp-4) 0 0; font-size: var(--fs-l); }
    \\  .c-account p { margin: 0; }
    \\  .c-account .info { color: var(--t2); }
    \\  .c-account form { display: grid; gap: var(--sp-3); }
    \\  .c-account label { display: grid; gap: var(--sp-1); }
    \\  .c-account .name { font-weight: var(--w-m); }
    \\  .c-account .hint { color: var(--muted); font-size: var(--fs-s); }
    \\  .c-account form > .c-btn { justify-self: start; }
    \\  .c-account .msg { padding: var(--sp-2) var(--sp-3); border-radius: var(--r-s); background: var(--ctl-bg); color: var(--turn); }
    \\  .c-account .msg[data-ok] { color: var(--t2); }
    \\  .c-account .who { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-3); color: var(--t2); }
    \\  .c-account .who b { color: var(--text); }
    \\  .c-account .apps { display: grid; gap: var(--sp-2); margin: 0; padding: 0; list-style: none; }
    \\  .c-account .apps li { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-1) var(--sp-3); }
    \\  .c-account .app { font-weight: var(--w-m); }
    \\  .c-account .when { flex: 1; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-account .out { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
    \\  .c-account .del { display: grid; gap: var(--sp-3); }
    \\}
    \\
;

pub const Demo = struct {
    pub const me: ac.Me = .{ .username = "ann", .role = "admin", .can = &.{ "view_private", "download_private_app", "view_admin", "manage_accounts" } };
    pub const devices = [_]ac.Device{
        .{ .id = 1, .name = "Ann's PC", .created = 1_790_000_000, .last_used = 1_793_200_000 },
        .{ .id = 2, .name = "Laptop", .created = 1_792_000_000, .last_used = 1_792_100_000 },
    };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    var refused: Account = .{ .kind = .login };
    _ = refused.answered(401, "{\"error\":\"wrong username or password\"}");
    var taken: Account = .{ .kind = .signup };
    _ = taken.answered(409, "{\"error\":\"that username is taken\"}");
    var refusedDel: Account = .{ .kind = .account, .me = .{ .username = "player", .role = "public", .can = &.{} }, .me_at = .ok, .devices_at = .ok, .sent = .delete };
    _ = refusedDel.answered(403, "{\"error\":\"wrong password\"}");
    var waiting: Account = .{ .kind = .login };
    _ = waiting.answered(429, "{\"error\":\"too many tries\",\"retry_s\":300}");
    const states = [_]struct { []const u8, Account }{
        .{ "log in", .{ .kind = .login } },
        .{ "log in: sending", .{ .kind = .login, .busy = true } },
        .{ "log in: refused", refused },
        .{ "log in: too many tries", waiting },
        .{ "log in: server down", .{ .kind = .login, .say = .down } },
        .{ "sign up", .{ .kind = .signup } },
        .{ "sign up: name taken", taken },
        .{ "sign-up link", .{ .kind = .signup, .linked = true } },
        .{ "invite without its link", .{ .kind = .join, .say = .no_link } },
        .{ "account: loading", .{ .kind = .account } },
        .{ "account: down", .{ .kind = .account, .me_at = .down, .devices_at = .down } },
        .{ "account: no apps", .{ .kind = .account, .me = .{ .username = "pal", .role = "private", .can = &.{ "view_private", "download_private_app" } }, .me_at = .ok, .devices_at = .ok } },
        .{ "account: public", .{ .kind = .account, .me = .{ .username = "player", .role = "public", .can = &.{} }, .me_at = .ok, .devices_at = .ok } },
        .{ "account: delete refused", refusedDel },
        .{ "account: password changed", .{ .kind = .account, .me = Demo.me, .me_at = .ok, .devices = &Demo.devices, .devices_at = .ok, .say = .changed } },
    };
    for (states) |s| {
        // The view's handlers point into it, and the page is written after this returns
        const p = h.mem.create(Account) catch {
            h.oom = true;
            return;
        };
        p.* = s[1];
        g.add(s[0], p.view(h));
    }
}

const testing = std.testing;

test next {
    const admin: ac.Me = .{ .username = "a", .role = "admin", .can = &.{ "view_private", "view_admin" } };
    const public: ac.Me = .{ .username = "p", .role = "public", .can = &.{} };
    try testing.expectEqualStrings("/admin/meionotes", next("?next=/admin/meionotes", admin));
    try testing.expectEqualStrings("/admin", next("?x=1", admin));
    try testing.expectEqualStrings("/", next("", public));
    try testing.expectEqualStrings("/private", next("", .{ .username = "f", .role = "private", .can = &.{"view_private"} }));
    for ([_][]const u8{ "?next=//evil.example", "?next=https://evil.example", "?next=/\\evil.example", "?next=" }) |q| {
        try testing.expectEqualStrings("/", next(q, public));
    }
}

test loginMark {
    try testing.expectEqualStrings("admin", loginMark(.{ .username = "a", .role = "admin", .can = &.{ "view_private", "view_admin" } }));
    try testing.expectEqualStrings("tester", loginMark(.{ .username = "f", .role = "private", .can = &.{"view_private"} }));
    try testing.expectEqualStrings("", loginMark(.{ .username = "p", .role = "public", .can = &.{} }));
}

test "answers: signed in, the API's error as a sentence, too many tries in minutes" {
    var p: Account = .{ .kind = .login };
    var ev: tree.Event = .{ .kind = .submit };
    p.update(.submit, &ev);
    try testing.expect(ev.handled and p.busy and p.want == .send);
    p.want = .none;
    p.update(.submit, &ev);
    try testing.expectEqual(.none, p.want);
    try testing.expect(p.answered(200, ""));
    try testing.expect(!p.answered(401, "{\"error\":\"wrong username or password\"}"));
    try testing.expectEqualStrings("Wrong username or password.", p.server.slice());
    try testing.expect(!p.busy);
    _ = p.answered(429, "{\"error\":\"too many tries\",\"retry_s\":61}");
    try testing.expectEqual(.wait, p.say);
    try testing.expectEqual(2, p.n);
    _ = p.answered(502, "<html>");
    try testing.expectEqual(.failed, p.say);
    try testing.expectEqual(502, p.n);
    _ = p.answered(0, "");
    try testing.expectEqual(.down, p.say);

    var a: Account = .{ .kind = .account };
    try testing.expect(!a.answered(200, ""));
    try testing.expectEqual(.changed, a.say);
    try testing.expectEqual(1, a.forms);
}

test "the form's fields by kind, and a removed app by its id" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const want = [_]struct { Kind, bool, []const []const u8 }{
        .{ .login, false, &.{ "name=\"username\"", "autocomplete=\"current-password\"", "href=\"/signup\"" } },
        .{ .signup, false, &.{ "name=\"username\"", "minlength=\"8\"", "href=\"/privacy#accounts\"", "href=\"/login\"" } },
        .{ .signup, true, &.{ "name=\"email\"", "minlength=\"10\"", "href=\"/privacy#accounts\"" } },
        .{ .join, false, &.{ "name=\"username\"", "minlength=\"8\"" } },
        .{ .account, false, &.{ "name=\"new\"", "autocomplete=\"new-password\"", "Loading" } },
    };
    for (want) |w| {
        var t: tree.Tree = .{};
        var h: H = .init(a, &t);
        var p: Account = .{ .kind = w[0], .linked = w[1] };
        var out: std.Io.Writer.Allocating = .init(a);
        try @import("html.zig").write(&t, p.view(&h), &out.writer);
        try testing.expect(!h.oom);
        try testing.expect(tree.find(out.written(), "<form method=\"post\" action=\"/auth/") != null);
        for (w[2]) |s| if (tree.find(out.written(), s) == null) {
            std.debug.print("{t}: no {s}\n", .{ w[0], s });
            return error.TestUnexpectedResult;
        };
    }
    var p: Account = .{ .kind = .account, .devices = &Demo.devices, .devices_at = .ok };
    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .revoke = 1 }, &ev);
    try testing.expectEqual(@as(i64, 2), p.want.revoke);
    p.want = .none;
    p.update(.{ .revoke = 2 }, &ev);
    try testing.expectEqual(.none, p.want);
}

test Day {
    var buf: [16]u8 = undefined;
    try testing.expectEqualStrings("3 Oct 2026", try std.fmt.bufPrint(&buf, "{f}", .{Day{ .s = 1791000000 }}));
}
