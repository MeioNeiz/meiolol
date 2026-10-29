//! Daily Draft's page (docs/plan/ui/daily.md, mock round 4): the board with the last pick
//! hidden and the pick panel (six ChoiceCards, Lock in), then "Who won?", then the reveal:
//! the result line and the board grown, its seats selectable. ui-daily.wasm; answers in
//! localStorage "meiolol.daily.v1" through the page's code (`saved`, `restore`). The
//! selected seat's review and On paper are ui.dailyseat, an island of their own beside
//! this one (`layout`)
const std = @import("std");
const tree = @import("tree.zig");
const dd = @import("dailydata.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const button = @import("button.zig");
const card = @import("card.zig");
const choice = @import("choice.zig");
const draftboard = @import("draftboard.zig");
const draftflow = @import("draftflow.zig");
const puzzle = @import("puzzle.zig");
const dailyseat = @import("dailyseat.zig");
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "DailyPage";
pub const scope = .{ ".c-dailyw", ".c-daily" };
pub const sel = "[data-island=daily]";

pub const Phase = enum { pick, winner, done };

pub const Page = struct {
    p: *const dd.Puzzle,
    /// The option chosen, not locked in (index into p.options)
    choice: ?u8 = null,
    /// The option locked in; null after a reveal when daily.js saved the answer
    guess: ?u8 = null,
    winner: ?dd.Side = null,
    /// Pick and winner right, once both are answered
    marks: ?[2]bool = null,
    hint: bool = false,
    /// The selected seat after the reveal: side * 5 + role
    seat: u8,
    /// Set when the answers changed: the page's code saves them
    dirty: bool = false,
    /// The server's render: the puzzle as ui.data, base64, for the island
    bin: []const u8 = "",

    pub const Msg = union(enum) { choose: u8, lock, winner: dd.Side, seat: u8, hint, key };

    pub fn init(_: std.mem.Allocator, p: *const dd.Puzzle) Page {
        return .{ .p = p, .seat = hiddenSeat(p) };
    }

    pub fn phase(s: *const Page) Phase {
        if (s.marks != null) return .done;
        return if (s.guess != null) .winner else .pick;
    }

    fn lock(s: *Page) void {
        if (s.phase() != .pick) return;
        s.guess = s.choice orelse return;
        s.dirty = true;
    }

    fn answer(s: *Page, w: dd.Side) void {
        if (s.phase() != .winner) return;
        const g = s.guess orelse return;
        s.winner = w;
        s.marks = .{ s.p.options[g] == dd.played(s.p), w == s.p.result.winner };
        s.dirty = true;
    }

    pub fn update(s: *Page, m: Msg, ev: *tree.Event) void {
        const was = s.phase();
        s.apply(m, ev);
        // The panel that had focus is gone: focus the next one's question, or the result
        const now = s.phase();
        if (now != was) ev.after = .{ .op = .focus, .ref = if (now == .done) "res" else "q" };
    }

    fn apply(s: *Page, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .choose => |i| if (s.phase() == .pick and i < s.p.options.len) {
                s.choice = i;
            },
            .lock => s.lock(),
            .winner => |w| s.answer(w),
            .seat => |x| if (s.phase() == .done and x < 10) {
                s.seat = x;
            },
            .hint => if (s.phase() == .pick and !s.hint) {
                s.hint = true;
                s.dirty = true;
            },
            .key => s.key(ev),
        }
    }

    /// 1-6 choose and focus Lock in, so Enter locks in (Enter itself stays the focused
    /// button's: on a card it chooses that card); then 1 and 2 answer blue and red
    fn key(s: *Page, ev: *tree.Event) void {
        const t = ev.text;
        const digit: u8 = if (t.len == 1 and t[0] >= '1' and t[0] <= '9') t[0] - '1' else return;
        switch (s.phase()) {
            .pick => {
                if (digit >= s.p.options.len) return;
                s.choice = digit;
                ev.after = .{ .op = .focus, .ref = "lock" };
            },
            .winner => {
                if (digit > 1) return;
                s.answer(if (digit == 0) .blue else .red);
            },
            .done => return,
        }
        ev.handled = true;
    }

    /// The answers for localStorage: the option locked in, the side, the marks
    pub fn saved(s: *const Page) Saved {
        return .{ .opt = s.guess, .side = s.winner, .marks = s.marks, .hint = s.hint };
    }

    /// The answers saved for this puzzle, from localStorage's whole value
    pub fn restore(s: *Page, json: []const u8) void {
        const x = read(json, s.p.n) orelse return;
        const opt = if (x.opt) |o| (if (o < s.p.options.len) o else null) else null;
        if (x.marks) |m| {
            s.guess = opt;
            s.choice = opt;
            s.winner = x.side;
            s.marks = m;
        } else if (opt) |o| {
            s.guess = o;
            s.choice = o;
        }
        s.hint = x.hint;
    }

    pub fn view(s: *Page, h: *H) N {
        const ph = s.phase();
        return h.div(.{
            .class = "c-daily",
            .data_island = "daily",
            .data_bin = if (s.bin.len > 0) s.bin else null,
            .data_phase = ph,
            // ui-dailyseat.wasm's (dailyseat.Seat.read)
            .data_seat = if (ph == .done) s.seat else null,
            .data_guess = if (ph == .done) s.guess else null,
            .on_keydown = h.on(s, .key),
        }, .{
            h.div(.{ .key = 1, .class = "left" }, .{card.view(h, .{ .label = W.draft }, &.{ if (ph == .done) s.result(h) else .none, s.board(h) })}),
            switch (ph) {
                .pick => s.pickPanel(h),
                .winner => s.winnerPanel(h),
                .done => null,
            },
        });
    }

    fn champOf(s: *const Page, i: u16) champ.Champ {
        return s.p.champs[i];
    }

    /// The answer shown in the hidden seat before the reveal: locked in, else chosen
    fn shownAnswer(s: *const Page) ?champ.Champ {
        const i = s.guess orelse s.choice orelse return null;
        return s.champOf(s.p.options[i]);
    }

    fn board(s: *Page, h: *H) N {
        const p = s.p;
        const done = s.phase() == .done;
        var most: u32 = 1;
        for (p.seats) |side| for (side) |x| {
            most = @max(most, x.damage);
        };
        var lanes: [5]draftboard.Lane = undefined;
        var on: [5][2]?tree.Handler = undefined;
        for (&lanes, &on, 0..) |*l, *o, r| {
            const asked = r == @backingInt(p.hidden_role) and !done;
            l.* = .{ .role = role.Role.all[r], .win = p.lanes[r], .ask = asked };
            inline for (.{ &l.us, &l.them }, 0..) |seat, t| {
                const x = p.seats[t][r];
                const hidden = asked and t == @backingInt(p.hidden_side);
                const pick = pickOf(p, t, x.champ);
                seat.* = .{
                    .champ = if (hidden) null else s.champOf(x.champ),
                    .hidden = r == @backingInt(p.hidden_role) and t == @backingInt(p.hidden_side),
                    .preview = if (hidden) s.shownAnswer() else null,
                    .pick = pick,
                    .sub = if (done) .{ .s = "" } else if (hidden) (if (pick) |n| W.pick_n.with(h, .{ .n = n }) else .{ .s = "" }) else dmgWord(x.dmg),
                    .game = if (!done) null else .{
                        .kda = .{ .k = x.kills, .d = x.deaths, .a = x.assists },
                        .cs = x.cs,
                        .gold = x.gold,
                        .dmg = x.damage,
                        .dmg_of = most,
                        .rated = if (x.rank) |n| n else null,
                        .star = x.rank == 1,
                    },
                    .sel = done and s.seat == 5 * t + r,
                };
                o[t] = if (done) h.on(s, .{ .seat = @intCast(5 * t + r) }) else null;
            }
        }
        const nt = p.turns.len;
        const turns = h.mem.alloc(draftflow.Turn, nt) catch {
            h.oom = true;
            return .none;
        };
        for (turns, p.turns, 0..) |*x, t, i| {
            const open = i == nt - 1 and !done;
            x.* = .{
                .champ = if (open) null else if (t.champ) |c| s.champOf(c) else null,
                .side = if (t.side == .blue) .us else .them,
                .open = open,
                .preview = if (open) s.shownAnswer() else null,
            };
        }
        const b: draftboard.Board = .{
            .v = .full,
            .lanes = &lanes,
            .won = if (!done) null else if (p.result.winner == .blue) .us else .them,
            .mix = s.mix(),
            .bans_us = if (nt == 0) s.champList(h, p.bans[0]) else &.{},
            .bans_them = if (nt == 0) s.champList(h, p.bans[1]) else &.{},
        };
        return h.div(.{ .class = "bd" }, .{
            draftboard.fullOn(h, b, &on),
            if (nt > 0) draftflow.view(h, turns) else null,
        });
    }

    /// Each side's damage mix by its champions' kinds, a fifth a seat; the hidden seat
    /// and seats without a kind unknown. Null when no seat has a kind
    fn mix(s: *const Page) ?[2]draftboard.Mix {
        const p = s.p;
        var any = false;
        for (p.seats) |side| for (side) |x| {
            any = any or x.dmg != null;
        };
        if (!any) return null;
        var out: [2]draftboard.Mix = .{ .{ .phys = 0, .magic = 0 }, .{ .phys = 0, .magic = 0 } };
        for (p.seats, &out, 0..) |side, *m, t| for (side, 0..) |x, r| {
            const hid = s.phase() != .done and t == @backingInt(p.hidden_side) and r == @backingInt(p.hidden_role);
            const d = if (hid) null else x.dmg;
            switch (d orelse {
                m.unknown += 0.2;
                continue;
            }) {
                .ad => m.phys += 0.2,
                .ap => m.magic += 0.2,
                .mixed => {
                    m.phys += 0.1;
                    m.magic += 0.1;
                },
            }
        };
        return out;
    }

    fn champList(s: *const Page, h: *H, ids: []const u16) []const champ.Champ {
        const out = h.mem.alloc(champ.Champ, ids.len) catch {
            h.oom = true;
            return &.{};
        };
        for (out, ids) |*c, i| c.* = s.champOf(i);
        return out;
    }

    /// The question as a PuzzleCard (Learn's); its setup is the board beside it, so no
    /// stage band
    fn pickPanel(s: *Page, h: *H) N {
        const p = s.p;
        const cs = h.mem.alloc(choice.Choice, p.options.len) catch {
            h.oom = true;
            return .none;
        };
        for (cs, p.options, 0..) |*c, o, i| c.* = .{
            .champ = s.champOf(o),
            .chosen = s.choice != null and s.choice.? == i,
            .on = h.on(s, .{ .choose = @as(u8, @intCast(i)) }),
        };
        const ask = W.ask.with(h, .{ .side = sideWord(p.hidden_side).s });
        return puzzle.view(h, .{
            .stage = .none,
            .label = ask,
            .q = h.span(.{}, .{ask}),
            .answer = choice.view(h, .{ .label = ask }, cs),
            .games = if (p.ranged) |r| h.span(.{ .class = "hints" }, .{
                h.span(.{ .class = "lab" }, .{W.hint}),
                if (s.hint)
                    badge.view(h, .accent, .{if (r) W.ranged else W.melee})
                else
                    button.view(h, .{ .s = .s, .on = h.on(s, .hint) }, .{W.range}),
            }) else null,
            .action = button.view(h, .{ .v = .primary, .disabled = s.choice == null, .on = h.on(s, .lock), .ref = "lock" }, .{W.lock}),
        });
    }

    fn winnerPanel(s: *Page, h: *H) N {
        const p = s.p;
        var sides: [2][]champ.Champ = undefined;
        for (&sides, 0..) |*side, t| {
            side.* = h.mem.alloc(champ.Champ, 5) catch {
                h.oom = true;
                return .none;
            };
            for (side.*, 0..) |*c, r| {
                const hid = t == @backingInt(p.hidden_side) and r == @backingInt(p.hidden_role);
                c.* = if (hid) s.shownAnswer() orelse .{ .name = "?", .src = "" } else s.champOf(p.seats[t][r].champ);
            }
        }
        return puzzle.view(h, .{
            .stage = .none,
            .label = W.who_won,
            .q = h.span(.{ .tabindex = @as(i8, -1), .data_ref = "q" }, .{W.who_won}),
            .answer = choice.view(h, .{ .label = W.who_won }, &.{
                .{ .label = W.blue, .side = .us, .icons = sides[0], .on = h.on(s, .{ .winner = .blue }) },
                .{ .label = W.red, .side = .them, .icons = sides[1], .on = h.on(s, .{ .winner = .red }) },
            }),
            // A card commits it
            .action = .none,
        });
    }

    fn result(s: *Page, h: *H) N {
        const r = s.p.result;
        const m = s.marks orelse return .none;
        return h.div(.{ .class = "res", .tabindex = @as(i8, -1), .data_ref = "res" }, .{
            // A hint costs the clean tick
            badge.view(h, if (!m[0]) .nerf else if (s.hint) .neutral else .buff, .{ if (m[0]) "✓ " else "✕ ", if (s.hint) W.pick_hint else W.pick }),
            badge.view(h, if (m[1]) .buff else .nerf, .{ if (m[1]) "✓ " else "✕ ", W.winner }),
            h.span(.{ .class = "gl" }, .{
                h.b(.{ .data_side = sideOf(r.winner) }, .{W.won.with(h, .{ .side = sideWord(r.winner).s, .t = r.secs })}),
                pair(h, W.kills, r.kills[0], r.kills[1]),
                pair(h, W.gold, r.gold[0], r.gold[1]),
                if (r.towers) |x| pair(h, W.towers, x[0], x[1]) else null,
                if (r.dragons) |x| pair(h, W.dragons, x[0], x[1]) else null,
                if (r.barons) |x| pair(h, W.barons, x[0], x[1]) else null,
            }),
        });
    }
};

pub fn hiddenSeat(p: *const dd.Puzzle) u8 {
    return 5 * @as(u8, @backingInt(p.hidden_side)) + @as(u8, @backingInt(p.hidden_role));
}

/// The seat's champion's pick number in the draft (1-10); null without the order
pub fn pickOf(p: *const dd.Puzzle, t: usize, c: u16) ?u8 {
    var n: u8 = 0;
    for (p.turns, 0..) |x, i| {
        if (i < 6 or (i >= 12 and i < 16)) continue;
        n += 1;
        if (x.champ == c and @backingInt(x.side) == t) return n;
    }
    return null;
}

fn pair(h: *H, label: tree.Text, b: anytype, r: anytype) N {
    return h.span(.{ .class = "pr" }, .{
        h.span(.{ .class = "k" }, .{label}),
        " ",
        h.b(.{ .data_side = draftboard.Side.us }, .{phrase.num(h, if (@TypeOf(b) == u32) .kilo else .int, b)}),
        " v ",
        h.b(.{ .data_side = draftboard.Side.them }, .{phrase.num(h, if (@TypeOf(r) == u32) .kilo else .int, r)}),
    });
}

pub fn sideOf(s: dd.Side) draftboard.Side {
    return if (s == .blue) .us else .them;
}

pub fn sideWord(s: dd.Side) tree.Text {
    return if (s == .blue) W.blue else W.red;
}

fn dmgWord(d: ?dd.Dmg) tree.Text {
    return switch (d orelse return .{ .s = "" }) {
        .ad => W.ad,
        .ap => W.ap,
        .mixed => W.mixed,
    };
}

/// One puzzle's answers in localStorage "meiolol.daily.v1": an object keyed by n, each
/// entry flat, {"opt":2,"side":1,"hint":1,"marks":"10","on":"2026-10-27"}; done = marks set (Home
/// reads them). daily.js's entries name the champion ("pick") instead of the option
pub const Saved = struct {
    opt: ?u8 = null,
    side: ?dd.Side = null,
    marks: ?[2]bool = null,
    hint: bool = false,
};

/// Puzzle `n`'s entry in the stored object, braces included
fn entry(json: []const u8, n: u32) ?[]const u8 {
    var buf: [14]u8 = undefined;
    const k = keyOf(&buf, n);
    const at = std.mem.find(u8, json, k) orelse return null;
    const start = at + k.len - 1;
    const end = std.mem.findScalarPos(u8, json, start, '}') orelse return null;
    return json[start .. end + 1];
}

/// `"n":{`, by hand: std.fmt's print paths cost ui-daily.wasm bytes it lacks
fn keyOf(buf: *[14]u8, n: u32) []const u8 {
    var i: usize = buf.len - 3;
    buf[i..][0..3].* = "\":{".*;
    var x = n;
    while (true) {
        i -= 1;
        buf[i] = '0' + @as(u8, @intCast(x % 10));
        x /= 10;
        if (x == 0) break;
    }
    i -= 1;
    buf[i] = '"';
    return buf[i..];
}

/// A field's raw value in a flat entry: up to the next comma or brace
fn field(e: []const u8, comptime f: []const u8) ?[]const u8 {
    const k = "\"" ++ f ++ "\":";
    const at = std.mem.find(u8, e, k) orelse return null;
    const v = e[at + k.len ..];
    return v[0 .. std.mem.findAny(u8, v, ",}") orelse v.len];
}

pub fn read(json: []const u8, n: u32) ?Saved {
    const e = entry(json, n) orelse return null;
    var s: Saved = .{};
    // An option's index: one digit, as there are never ten
    if (field(e, "opt")) |v| s.opt = if (v.len == 1 and v[0] >= '0' and v[0] <= '9') v[0] - '0' else null;
    if (field(e, "side")) |v| s.side = if (std.mem.eql(u8, v, "0")) .blue else if (std.mem.eql(u8, v, "1")) .red else null;
    if (field(e, "marks")) |v| if (v.len == 4 and v[0] == '"' and v[3] == '"' and bit(v[1]) and bit(v[2])) {
        s.marks = .{ v[1] == '1', v[2] == '1' };
    };
    if (field(e, "hint")) |v| s.hint = std.mem.eql(u8, v, "1");
    return s;
}

/// The viewer's date puzzle `n` was finished on ("2026-10-27"), for days in a row
pub fn finishedOn(json: []const u8, n: u32) ?[]const u8 {
    const v = field(entry(json, n) orelse return null, "on") orelse return null;
    if (v.len != 12 or v[0] != '"' or v[11] != '"') return null;
    return v[1..11];
}

fn bit(c: u8) bool {
    return c == '0' or c == '1';
}

/// The stored object with puzzle `n`'s entry set to `s`, finished on `on` (the viewer's
/// date, for days in a row) when it has marks; other entries kept as they are
pub fn write(a: std.mem.Allocator, json: []const u8, n: u32, s: Saved, on: []const u8) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(a);
    defer aw.deinit();
    const w = &aw.writer;
    var buf: [14]u8 = undefined;
    const k = keyOf(&buf, n);
    const old = entry(json, n);
    const body = std.mem.trim(u8, json, " \n\t");
    const whole = body.len >= 2 and body[0] == '{' and body[body.len - 1] == '}';
    if (old) |e| {
        const at = @intFromPtr(e.ptr) - @intFromPtr(json.ptr);
        try w.writeAll(json[0 .. at - (k.len - 1)]);
    } else if (whole) {
        const inner = std.mem.trimEnd(u8, body[0 .. body.len - 1], " \n\t");
        try w.writeAll(inner);
        if (inner.len > 1) try w.writeByte(',');
    } else try w.writeByte('{');
    try w.writeAll(k);
    var sep: []const u8 = "";
    if (s.opt) |o| {
        try w.writeAll("\"opt\":");
        try w.writeByte('0' + o);
        sep = ",";
    }
    if (s.side) |x| {
        try w.writeAll(sep);
        try w.writeAll(if (x == .blue) "\"side\":0" else "\"side\":1");
        sep = ",";
    }
    if (s.hint) {
        try w.writeAll(sep);
        try w.writeAll("\"hint\":1");
        sep = ",";
    }
    if (s.marks) |m| {
        try w.writeAll(sep);
        try w.writeAll("\"marks\":\"");
        try w.writeByte(if (m[0]) '1' else '0');
        try w.writeByte(if (m[1]) '1' else '0');
        try w.writeAll("\",\"on\":\"");
        try w.writeAll(on);
        try w.writeByte('"');
    }
    try w.writeByte('}');
    if (old) |e| {
        const end = @intFromPtr(e.ptr) - @intFromPtr(json.ptr) + e.len;
        try w.writeAll(json[end..]);
    } else try w.writeByte('}');
    return aw.toOwnedSlice();
}

const W = struct {
    const draft = plain("The draft");
    const ad = plain("AD");
    const ap = plain("AP");
    const mixed = plain("AD and AP");
    const blue = plain("Blue");
    const red = plain("Red");
    const pick_n = Phrase("pick {n:int}");
    const ask = Phrase("{side:text}'s last pick?");
    const lock = plain("Lock in");
    const hint = plain("Hint");
    const range = plain("Range");
    const ranged = plain("Ranged");
    const melee = plain("Melee");
    const who_won = plain("Who won?");
    const pick = plain("Pick");
    const pick_hint = plain("Pick, with a hint");
    const winner = plain("Winner");
    const won = Phrase("{side:text} won · {t:time}");
    const kills = plain("kills");
    const gold = plain("gold");
    const towers = plain("towers");
    const dragons = plain("dragons");
    const barons = plain("barons");
};

pub const css =
    \\@layer components {
    \\  .c-dailyw { container: daily / inline-size; scroll-margin-top: calc(var(--header) + var(--sp-3)); }
    \\  .c-dailyw > .cols { display: grid; grid-template-columns: minmax(0, 1fr) 420px; gap: var(--sp-3); align-items: start; }
    \\  .c-dailyw > .cols:has(> [data-phase="done"]) { grid-template-columns: minmax(0, 1fr) 380px; grid-template-rows: auto 1fr; }
    \\  .c-daily { display: contents; }
    \\  .c-daily > .left { grid-column: 1; grid-row: 1; min-width: 0; }
    \\  .c-daily > .c-card { grid-column: 2; grid-row: 1; }
    \\  .c-daily .bd { display: grid; gap: var(--sp-3); }
    \\  .c-daily :is(.c-puzzle .q, .res) { scroll-margin: calc(var(--header) + var(--sp-3)) 0 var(--sp-3); }
    \\  .c-daily [tabindex="-1"]:focus { outline: none; }
    \\  .c-daily .c-puzzle > .stage:empty, .c-daily[data-phase="winner"] .c-puzzle > .foot { display: none; }
    \\  .c-daily .hints { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-daily .hints .lab { font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--faint); text-transform: uppercase; letter-spacing: 0.06em; }
    \\  .c-daily .res { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2); padding-bottom: var(--sp-3);
    \\    margin-bottom: var(--sp-3); border-bottom: 1px solid var(--line); }
    \\  .c-daily .gl { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-3); margin-left: auto; font-size: var(--fs-s);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-daily .gl [data-side="us"] { color: var(--us); }
    \\  .c-daily .gl [data-side="them"] { color: var(--them); }
    \\  .c-daily .pr { white-space: nowrap; color: var(--faint); }
    \\  .c-daily .pr .k { color: var(--muted); }
    \\  @container daily (max-width: 1000px) {
    \\    .c-dailyw > .cols { grid-template-columns: minmax(0, 1fr); }
    \\    .c-daily > .c-card { grid-column: 1; grid-row: auto; }
    \\  }
    \\  @container daily (max-width: 1400px) {
    \\    .c-dailyw > .cols:has(> [data-phase="done"]) { grid-template-columns: minmax(0, 1fr); grid-template-rows: none; }
    \\  }
    \\  @container daily (max-width: 760px) {
    \\    .c-daily:not([data-phase="done"]) > .c-card { position: sticky; bottom: 0; z-index: 2; box-shadow: var(--shadow-pop); }
    \\    .c-daily .gl { margin-left: 0; }
    \\  }
    \\}
    \\
;

/// The page as daily.zig writes it: this island and ui.dailyseat's, side by side
pub fn layout(h: *H, page: N, seat: N) N {
    return h.div(.{ .class = "c-dailyw" }, .{h.div(.{ .class = "cols" }, .{ page, seat })});
}

pub fn gallery(g: *@import("gallery.zig").Gallery) void {
    const h = g.h;
    if (shown(h, &dd.sample, null, null, null)) |p| g.addFill("first visit: red's last pick asked", both(h, p, .{ null, null }));
    if (shown(h, &pro, 1, null, null)) |p| {
        p.hint = true;
        g.addFill("pro draft, one chosen, the range hint used", both(h, p, .{ null, null }));
    }
    if (shown(h, &pro, 1, 1, null)) |p| g.addFill("locked in: who won?", both(h, p, .{ null, null }));
    if (shown(h, &pro, 1, 1, .red)) |p| g.addFill("revealed: wrong pick, wrong winner, the played pick's reasons open", both(h, p, .{ 5, null }));
}

/// A page on `p` with option `c` chosen, `locked` in and `w` answered
pub fn shown(h: *H, p: *const dd.Puzzle, c: ?u8, locked: ?u8, w: ?dd.Side) ?*Page {
    const s = h.mem.create(Page) catch {
        h.oom = true;
        return null;
    };
    s.* = .init(h.mem, p);
    s.choice = c;
    if (locked != null) s.lock();
    if (w) |x| s.answer(x);
    return s;
}

/// `s` in the layout with the seat review its answers give, rows `open`
pub fn both(h: *H, s: *Page, open: [2]?u16) N {
    const x = h.mem.create(dailyseat.Seat) catch {
        h.oom = true;
        return .none;
    };
    x.* = .{ .p = s.p, .seat = s.seat, .guess = s.guess, .done = s.phase() == .done, .open = open };
    return layout(h, s.view(h), x.view(h));
}

/// The sample with its pro draft, six options and a range hint
pub const pro = blk: {
    var p = dd.sample;
    p.turns = &dd.pro_turns;
    p.options = &.{ 5, 11, 10, 9, 7, 8 };
    p.ranged = false;
    break :blk p;
};

const testing = std.testing;

test "choose, lock in, then the winner: marks, the saved answers, the seat panel" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: Page = .init(a, &pro);
    var ev: tree.Event = .{ .kind = .click };
    s.update(.lock, &ev);
    try testing.expectEqual(Phase.pick, s.phase());
    ev = .{ .kind = .keydown, .text = "2" };
    s.update(.key, &ev);
    try testing.expect(ev.handled);
    try testing.expectEqual(@as(?u8, 1), s.choice);
    try testing.expectEqualStrings("lock", ev.after.?.ref);
    s.update(.{ .choose = 0 }, &ev);
    ev = .{ .kind = .keydown, .text = "Enter" };
    s.update(.key, &ev);
    try testing.expect(!ev.handled);
    try testing.expectEqual(Phase.pick, s.phase());
    s.update(.lock, &ev);
    try testing.expectEqual(Phase.winner, s.phase());
    try testing.expect(s.dirty);
    s.update(.{ .choose = 3 }, &ev);
    try testing.expectEqual(@as(?u8, 0), s.guess);
    ev = .{ .kind = .keydown, .text = "2" };
    s.update(.key, &ev);
    try testing.expectEqual(Phase.done, s.phase());
    try testing.expectEqual([2]bool{ true, false }, s.marks.?);
    try testing.expectEqual(@as(u8, 5), s.seat);
    s.update(.{ .seat = 2 }, &ev);
    try testing.expectEqual(@as(u8, 2), s.seat);

    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    t.root = s.view(&h);
    try testing.expect(!h.oom);
    const out = try render(a, &t);
    try testing.expect(std.mem.find(u8, out, "data-phase=\"done\"") != null);
    try testing.expect(std.mem.find(u8, out, "Red won") == null);
    try testing.expect(std.mem.find(u8, out, "Blue won") != null);
}

test "before the reveal no page text names the played pick" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // Jayce (5) is played: out of the options and the draft's other turns
    var p = pro;
    p.options = &.{ 11, 10 };
    var turns = dd.pro_turns;
    for (turns[0..19]) |*x| if (x.champ == 5) {
        x.champ = null;
    };
    p.turns = &turns;
    for ([_]?u8{ null, 0 }) |locked| {
        var s: Page = .init(a, &p);
        s.choice = locked;
        s.lock();
        var t: tree.Tree = .{};
        var h: H = .init(a, &t);
        t.root = s.view(&h);
        try testing.expect(std.mem.find(u8, try render(a, &t), "Jayce") == null);
    }
}

fn render(a: std.mem.Allocator, t: *const tree.Tree) ![]const u8 {
    var w: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(t, t.root, &w.writer);
    return w.written();
}

test "answers saved and restored; other entries and daily.js's kept" {
    const a = testing.allocator;
    const old = "{\"7\":{\"pick\":266,\"side\":0,\"on\":\"2026-10-17\",\"marks\":\"10\",\"sent\":true}}";
    const one = try write(a, old, 11, .{ .opt = 2 }, "2026-10-27");
    defer a.free(one);
    try testing.expectEqualStrings("{\"7\":{\"pick\":266,\"side\":0,\"on\":\"2026-10-17\",\"marks\":\"10\",\"sent\":true},\"11\":{\"opt\":2}}", one);
    const two = try write(a, one, 11, .{ .opt = 2, .side = .red, .marks = .{ false, true } }, "2026-10-27");
    defer a.free(two);
    try testing.expectEqualStrings("{\"7\":{\"pick\":266,\"side\":0,\"on\":\"2026-10-17\",\"marks\":\"10\",\"sent\":true},\"11\":{\"opt\":2,\"side\":1,\"marks\":\"01\",\"on\":\"2026-10-27\"}}", two);
    for ([_][]const u8{ "", "null", "{}", "[1]" }) |bad| {
        const x = try write(a, bad, 3, .{ .opt = 0 }, "");
        defer a.free(x);
        try testing.expectEqualStrings("{\"3\":{\"opt\":0}}", x);
    }

    var s: Page = .init(a, &pro);
    s.restore(two);
    try testing.expectEqual(Phase.done, s.phase());
    try testing.expectEqual(@as(?u8, 2), s.guess);
    try testing.expectEqual(@as(?dd.Side, .red), s.winner);
    // daily.js's: done, the option unknown
    var p7 = pro;
    p7.n = 7;
    var s7: Page = .init(a, &p7);
    s7.restore(two);
    try testing.expectEqual(Phase.done, s7.phase());
    try testing.expectEqual(@as(?u8, null), s7.guess);
    var arena: std.heap.ArenaAllocator = .init(a);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    t.root = s7.view(&h);
    try testing.expect(!h.oom);
    // Locked in, not answered; an option past the puzzle's ignored
    var s3: Page = .init(a, &pro);
    s3.restore("{\"11\":{\"opt\":4}}");
    try testing.expectEqual(Phase.winner, s3.phase());
    var s4: Page = .init(a, &pro);
    s4.restore("{\"11\":{\"opt\":9}}");
    try testing.expectEqual(Phase.pick, s4.phase());
}
