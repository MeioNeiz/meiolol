//! Remove my data (docs/legal/lia.md "Objection"): anyone, for any Riot ID, proves it is
//! theirs by setting a profile icon, then the API removes it and never collects it again.
//! Island Forget (ui-forget.wasm, lazy at the Your games page's foot); /api/forget does the
//! Riot calls (api/root.zig forget) and answers a small JSON object, read by `answer`
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const button = @import("button.zig");
const idlookup = @import("idlookup.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Forget";
pub const scope = .{".c-forget"};
pub const sel = "[data-island=forget]";

/// While the API talks to Riot: ask again this often
pub const poll_ms = 2000;

const W = struct {
    pub const open = plain("Remove my data");
    pub const id = plain("Riot ID");
    pub const hint = plain("Name#TAG");
    pub const start = plain("Start");
    pub const check = plain("Check");
    pub const keep = plain("What we keep");
    pub const contacting = plain("Contacting Riot…");
    pub const checking = plain("Checking your icon with Riot…");
    pub const issued = phrase.Phrase("Set this profile icon on {id:text} in the League client before {at:time}, then press Check. You can change it back after.");
    pub const mismatch = phrase.Phrase("Riot doesn't show this icon on {id:text} yet; it can take a minute. Set it before {at:time}, then press Check.");
    pub const done = phrase.Phrase("Done: everything stored about {id:text} is deleted, and we won't fetch its games again.");
    pub const not_found = plain("No Riot account with that name and tag.");
    pub const expired = plain("That check expired. Start again for a new icon.");
    pub const down = plain("Couldn't reach the service. Try again, or email us (see Privacy).");
    pub const icon = plain("Profile icon to set");
};

pub const State = enum { none, pending, checking, issued, mismatch, done, not_found, expired };

/// /api/forget's answer: {"state":"issued","icon":7,"expires":1793050439}
pub const Answer = struct { state: State, icon: ?u32 = null, expires: i64 = 0 };

pub fn answer(json: []const u8) ?Answer {
    const s = field(json, "state") orelse return null;
    if (s.len < 2 or s[0] != '"') return null;
    const end = std.mem.findScalar(u8, s[1..], '"') orelse return null;
    return .{
        .state = std.meta.stringToEnum(State, s[1 .. 1 + end]) orelse return null,
        .icon = if (field(json, "icon")) |v| std.fmt.parseInt(u32, number(v), 10) catch null else null,
        .expires = if (field(json, "expires")) |v| std.fmt.parseInt(i64, number(v), 10) catch 0 else 0,
    };
}

/// What follows `"key":`
fn field(json: []const u8, comptime key: []const u8) ?[]const u8 {
    const k = "\"" ++ key ++ "\":";
    const at = std.mem.find(u8, json, k) orelse return null;
    return json[at + k.len ..];
}

fn number(s: []const u8) []const u8 {
    var n: usize = 0;
    while (n < s.len and std.ascii.isDigit(s[n])) n += 1;
    return s[0..n];
}

pub const Forget = struct {
    open: bool = false,
    /// The box's text
    q: idlookup.Id = .{},
    /// The Riot ID being removed
    id: idlookup.Id = .{},
    at: At = .idle,
    icon: ?u32 = null,
    /// Unix seconds
    expires: i64 = 0,
    /// For the wasm after an event: POST, &check=1 too for `check`
    want: Want = .none,
    /// Each start's: a late answer for an older one is dropped
    gen: u32 = 0,
    /// Data Dragon's version, for the icon
    ddragon: []const u8 = "",
    /// Minutes east of UTC, for the expiry; the server's: UTC
    tz_min: i32 = 0,
    /// ui-forget's loader and wasm, for dom.lazyLoad
    js: []const u8 = "",
    wasm: []const u8 = "",

    const P = @This();

    pub const At = enum { idle, waiting, issued, mismatch, done, not_found, expired, down };
    pub const Want = enum { none, start, check };

    pub const Msg = union(enum) { open, input, key, start, check };

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .open => p.open = ev.opened(),
            .input => p.q.set(ev.text),
            .key => if (std.mem.eql(u8, ev.text, "Enter")) {
                ev.handled = true;
                p.begin();
            },
            .start => p.begin(),
            .check => if (p.at == .issued or p.at == .mismatch) {
                p.at = .waiting;
                p.want = .check;
            },
        }
    }

    fn begin(p: *P) void {
        const q = std.mem.trim(u8, p.q.slice(), " \t");
        if (!valid(q)) return;
        p.id.set(q);
        p.icon = null;
        p.gen +%= 1;
        p.at = .waiting;
        p.want = .start;
    }

    /// An answer (null: the fetch failed); true while the API is still at it (ask again)
    pub fn answered(p: *P, a: ?Answer) bool {
        const x = a orelse {
            p.at = .down;
            return false;
        };
        if (x.icon) |i| p.icon = i;
        if (x.expires != 0) p.expires = x.expires;
        p.at = switch (x.state) {
            .pending, .checking => return true,
            .issued => .issued,
            .mismatch => .mismatch,
            .done => .done,
            .not_found => .not_found,
            .expired, .none => .expired,
        };
        return false;
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "c-forget",
            .data_island = "forget",
            .data_js = if (p.js.len > 0) p.js else null,
            .data_wasm = if (p.wasm.len > 0) p.wasm else null,
            .data_ddragon = if (p.ddragon.len > 0) p.ddragon else null,
        }, .{
            h.el(.details, .{ .open = p.open, .on_toggle = h.on(p, .open) }, .{
                h.el(.summary, .{}, .{W.open}),
                p.body(h),
            }),
        });
    }

    fn body(p: *P, h: *H) N {
        const waiting = p.at == .waiting;
        const icon = (p.at == .issued or p.at == .mismatch) and p.icon != null and p.ddragon.len > 0;
        return h.div(.{ .class = "body" }, .{
            h.a(.{ .href = "/privacy" }, .{W.keep}),
            if (p.at == .issued or p.at == .mismatch or p.at == .done) null else h.div(.{ .class = "box" }, .{
                h.input(.{
                    .type = "text",
                    .placeholder = W.hint,
                    .aria_label = W.id,
                    .autocomplete = "off",
                    .spellcheck = "false",
                    .value = p.q.slice(),
                    .on_input = h.on(p, .input),
                    .on_keydown = h.on(p, .key),
                }),
                button.view(h, .{ .v = .primary, .s = .s, .disabled = waiting or !valid(std.mem.trim(u8, p.q.slice(), " \t")), .on = h.on(p, .start) }, .{W.start}),
            }),
            if (icon) h.el(.img, .{
                .src = h.fmt("https://ddragon.leagueoflegends.com/cdn/{s}/img/profileicon/{d}.png", .{ p.ddragon, p.icon.? }),
                .alt = W.icon,
                .width = "64",
                .height = "64",
            }, .{}) else null,
            h.p(.{ .role = "status" }, .{p.line(h)}),
            if (p.at == .issued or p.at == .mismatch) button.view(h, .{ .v = .primary, .s = .s, .on = h.on(p, .check) }, .{W.check}) else null,
        });
    }

    fn line(p: *const P, h: *H) ?tree.Text {
        const id = p.id.slice();
        // The local time as hours:minutes, through the time kind's minutes:seconds
        const at: i64 = @divFloor(@mod(p.expires + @as(i64, p.tz_min) * 60, std.time.s_per_day), 60);
        return switch (p.at) {
            .idle => null,
            .waiting => if (p.icon != null) W.checking else W.contacting,
            .issued => W.issued.with(h, .{ .id = id, .at = at }),
            .mismatch => W.mismatch.with(h, .{ .id = id, .at = at }),
            .done => W.done.with(h, .{ .id = id }),
            .not_found => W.not_found,
            .expired => W.expired,
            .down => W.down,
        };
    }
};

/// Name#TAG: something either side of one #
fn valid(id: []const u8) bool {
    const at = std.mem.findScalar(u8, id, '#') orelse return false;
    return at > 0 and at + 1 < id.len and std.mem.findScalar(u8, id[at + 1 ..], '#') == null;
}

pub const css =
    \\@layer components {
    \\  .c-forget { display: grid; gap: var(--sp-2); padding: var(--sp-4) 0; }
    \\  .c-forget summary { width: max-content; color: var(--t2); font-size: var(--fs-s); cursor: pointer; }
    \\  .c-forget .body { display: grid; justify-items: start; gap: var(--sp-2); max-width: 32rem; padding-top: var(--sp-2); }
    \\  .c-forget .box { display: flex; gap: var(--sp-1); width: 100%; }
    \\  .c-forget input { flex: 1; min-width: 0; }
    \\  .c-forget img { border-radius: var(--r-s); }
    \\  .c-forget p { margin: 0; color: var(--t2); }
    \\  .c-forget p:empty { display: none; }
    \\}
    \\
;

fn demo(at: Forget.At) Forget {
    var p: Forget = .{ .open = true, .at = at, .icon = 7, .expires = 1_793_050_439, .ddragon = "16.21.1" };
    p.q.set("MeioNeiz#EUW");
    p.id.set("MeioNeiz#EUW");
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = .{
        .{ "closed", Forget{} },
        .{ "open", Forget{ .open = true } },
        .{ "contacting Riot", demo(.waiting) },
        .{ "icon issued", demo(.issued) },
        .{ "icon not set yet", demo(.mismatch) },
        .{ "done", demo(.done) },
        .{ "not found", demo(.not_found) },
        .{ "expired", demo(.expired) },
        .{ "service down", demo(.down) },
    };
    inline for (states) |s| {
        // The view's strings point into it, and the page is written after this returns
        const p = h.mem.create(Forget) catch {
            h.oom = true;
            return;
        };
        p.* = s[1];
        g.add(s[0], p.view(h));
    }
}

const testing = std.testing;

test answer {
    const a = answer("{\"state\":\"issued\",\"icon\":7,\"expires\":1793050439}").?;
    try testing.expectEqual(.issued, a.state);
    try testing.expectEqual(7, a.icon.?);
    try testing.expectEqual(1793050439, a.expires);
    const n = answer("{\"state\":\"pending\",\"icon\":null,\"expires\":5}").?;
    try testing.expectEqual(null, n.icon);
    try testing.expectEqual(.none, answer("{\"state\":\"none\"}").?.state);
    try testing.expectEqual(null, answer("{\"error\":\"busy\"}"));
    try testing.expectEqual(null, answer("{\"state\":\"odd\"}"));
}

test "start, the icon, check, done; a failed fetch says so" {
    var p: Forget = .{};
    var ev: tree.Event = .{ .kind = .click };
    p.update(.start, &ev);
    try testing.expectEqual(.none, p.want);
    p.q.set(" A#1 ");
    p.update(.start, &ev);
    try testing.expectEqual(.start, p.want);
    try testing.expectEqualStrings("A#1", p.id.slice());
    try testing.expect(p.answered(.{ .state = .pending }));
    try testing.expect(!p.answered(.{ .state = .issued, .icon = 7, .expires = 100 }));
    try testing.expectEqual(.issued, p.at);
    p.want = .none;
    p.update(.check, &ev);
    try testing.expectEqual(.check, p.want);
    try testing.expect(p.answered(.{ .state = .checking }));
    try testing.expect(!p.answered(.{ .state = .done }));
    try testing.expectEqual(.done, p.at);
    try testing.expect(!p.answered(null));
    try testing.expectEqual(.down, p.at);
}

test valid {
    try testing.expect(valid("A#1"));
    try testing.expect(!valid("A1"));
    try testing.expect(!valid("#1"));
    try testing.expect(!valid("A#"));
    try testing.expect(!valid("A#1#2"));
}
