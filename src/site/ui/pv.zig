//! Pv: the private numbers on public champion and matchup pages (app.md "Private site"),
//! the shipped draft model's win chances, which the public pages never show
//! (production-key.md "Product rules"). ui-pv.wasm draws it for admin logins only, from
//! ui.pvdata files under /private/: one row of figures under the head, the model's
//! chance beside the games' win rate the head shows, then the matchup brief's champion; on
//! a matchup page, the pair
const std = @import("std");
const tree = @import("tree.zig");
const badge = @import("badge.zig");
const phrase = @import("phrase.zig");
const pd = @import("pvdata.zig");
const Role = @import("role.zig").Role;
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "Pv";
pub const scope = .{".c-pv"};
pub const sel = ".c-pv";

const W = struct {
    pub const tag = plain("Private");
    pub const about = plain("Private, for admin logins only: the shipped draft model's estimate (every region and patch, refitted daily) of the team's win chance, every other pick its role's average, beside the games' win rate for the filters shown. The public site never shows it.");
    pub const model = plain("Model");
    pub const games = plain("Games");
    pub const alone = plain("Alone");
    pub const range = Phrase("{lo:dec}-{hi:dec}");
    pub const with = Phrase("With {c:text}");
    pub const against = Phrase("Vs {c:text}");
    pub const together = Phrase("{n:count} together");
    pub const pair = Phrase("{a:text} vs {b:text}");
    pub const each = Phrase("{a:text} {pa:rate}");
    pub const each_b = Phrase(" · {b:text} {pb:rate}");
};

pub const Line = union(enum) {
    alone: struct { role: Role, win: [3]f32 },
    pair: struct { ally: bool, name: []const u8, role: Role, p: f32, games: u32, alone: f32 },
    matchup: struct { a: []const u8, b: []const u8, role: Role, p: f32, a_alone: f32, b_alone: ?f32 },
};

/// The matchup brief's champion: its name, and its role and side from "Top opponent" or
/// "Mid ally"
pub const Brief = struct { name: []const u8, role: Role, ally: bool };

pub fn brief(champ: []const u8, rel: []const u8) ?Brief {
    var it = std.mem.tokenizeScalar(u8, rel, ' ');
    const word = it.next() orelse return null;
    const side = it.next() orelse return null;
    const r = for (Role.all) |r| {
        if (std.mem.eql(u8, r.label().s, word)) break r;
    } else return null;
    const ally = if (std.mem.startsWith(u8, side, "ally")) true else if (std.mem.startsWith(u8, side, "opponent")) false else return null;
    if (champ.len == 0) return null;
    return .{ .name = champ, .role = r, .ally = ally };
}

/// A champion page's lines: the role's own, then the brief's champion beside it
pub fn champion(s: *const pd.Slice, r: Role, b: ?Brief, out: *[2]Line) []const Line {
    const l = s.line(r) orelse return out[0..0];
    out[0] = .{ .alone = .{ .role = r, .win = l.win } };
    const x = b orelse return out[0..1];
    const id = s.idOf(x.name) orelse return out[0..1];
    const p = pd.find(if (x.ally) l.with else l.vs, x.role, id) orelse return out[0..1];
    out[1] = .{ .pair = .{ .ally = x.ally, .name = x.name, .role = x.role, .p = p.p, .games = p.games, .alone = l.win[0] } };
    return out[0..2];
}

/// A matchup page's line: `a` against `vs` in `r`, `b` its slice when it came
pub fn matchup(a: *const pd.Slice, b: ?*const pd.Slice, r: Role, vs: u32) ?Line {
    const l = a.line(r) orelse return null;
    const p = pd.find(l.vs, r, vs) orelse return null;
    const b_name = a.nameOf(vs) orelse return null;
    const b_alone = if (b) |s| if (s.line(r)) |x| x.win[0] else null else null;
    return .{ .matchup = .{ .a = a.name, .b = b_name, .role = r, .p = p.p, .a_alone = l.win[0], .b_alone = b_alone } };
}

fn rate(p: f32) f32 {
    return 100 * p;
}

/// `games`: the head's win rate as it shows it ("46.2%"), when the page has one
pub fn view(h: *H, lines: []const Line, games: ?[]const u8) N {
    var l = h.list();
    l.add(h.span(.{ .class = "tag", .title = W.about }, .{badge.view(h, .accent, .{W.tag})}));
    for (lines) |x| switch (x) {
        .alone => |v| {
            l.add(cell(h, W.model, phrase.num(h, .rate, rate(v.win[0])), W.range.with(h, .{ .lo = rate(v.win[1]), .hi = rate(v.win[2]) })));
            if (games) |g| l.add(cell(h, W.games, phrase.num(h, .text, g), null));
        },
        .pair => |v| l.add(cell(
            h,
            if (v.ally) W.with.with(h, .{ .c = v.name }) else W.against.with(h, .{ .c = v.name }),
            phrase.num(h, .rate, rate(v.p)),
            W.together.with(h, .{ .n = v.games }),
        )),
        .matchup => |v| {
            l.add(cell(h, W.model, phrase.num(h, .rate, rate(v.p)), W.pair.with(h, .{ .a = v.a, .b = v.b })));
            if (games) |g| l.add(cell(h, W.games, phrase.num(h, .text, g), null));
            l.add(h.span(.{ .class = "f" }, .{
                h.span(.{ .class = "l" }, .{W.alone}),
                h.small(.{}, .{
                    W.each.with(h, .{ .a = v.a, .pa = rate(v.a_alone) }),
                    if (v.b_alone) |pb| W.each_b.with(h, .{ .b = v.b, .pb = rate(pb) }) else null,
                }),
            }));
        },
    };
    return h.div(.{ .class = "c-pv" }, .{l.done()});
}

fn cell(h: *H, label: tree.Text, value: tree.Text, ctx: ?tree.Text) N {
    return h.span(.{ .class = "f" }, .{
        h.span(.{ .class = "l" }, .{label}),
        h.b(.{}, .{value}),
        if (ctx) |c| h.small(.{}, .{c}) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-pv { display: flex; flex-wrap: wrap; align-items: baseline; gap: var(--sp-1) var(--sp-5);
    \\    padding: 0 var(--card-px); margin-bottom: var(--sp-2); font-variant-numeric: tabular-nums; }
    \\  .c-pv > .tag { cursor: help; }
    \\  .c-pv > .f { display: inline-flex; align-items: baseline; gap: var(--sp-2); white-space: nowrap; }
    \\  .c-pv .l { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-pv b { color: var(--accent); font-weight: var(--w-b); }
    \\  .c-pv small { font-size: var(--fs-xs); color: var(--faint); }
    \\}
    \\
;

const demo_lines = [_]Line{
    .{ .alone = .{ .role = .mid, .win = .{ 0.512, 0.503, 0.521 } } },
    .{ .pair = .{ .ally = false, .name = "Zed", .role = .mid, .p = 0.497, .games = 8068, .alone = 0.512 } },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("champion page, with the brief's opponent", view(h, &demo_lines, "49.1%"));
    g.add("champion page, no brief, no head rate", view(h, demo_lines[0..1], null));
    g.add("matchup page", view(h, &.{.{ .matchup = .{ .a = "Ahri", .b = "Zed", .role = .mid, .p = 0.497, .a_alone = 0.512, .b_alone = 0.505 } }}, "48.6%"));
}

const testing = std.testing;

const demo: pd.Slice = .{
    .id = 103,
    .name = "Ahri",
    .names = &.{ .{ .id = 238, .name = "Zed" }, .{ .id = 412, .name = "Thresh" } },
    .roles = &.{.{
        .role = .mid,
        .games = 20_000,
        .win = .{ 0.512, 0.503, 0.521 },
        .vs = &.{.{ .role = .mid, .champion = 238, .p = 0.497, .games = 8068 }},
        .with = &.{.{ .role = .support, .champion = 412, .p = 0.523, .games = 900 }},
    }},
};

test brief {
    try testing.expectEqualDeep(Brief{ .name = "Zed", .role = .mid, .ally = false }, brief("Zed", "Mid opponent").?);
    try testing.expectEqualDeep(Brief{ .name = "Thresh", .role = .support, .ally = true }, brief("Thresh", "Support ally · few games").?);
    try testing.expectEqual(null, brief("Zed", "Most played"));
    try testing.expectEqual(null, brief("", "Mid opponent"));
}

test "champion: the role's line, then the brief's champion in its list" {
    var out: [2]Line = undefined;
    try testing.expectEqual(0, champion(&demo, .top, null, &out).len);
    const opp = champion(&demo, .mid, brief("Zed", "Mid opponent"), &out);
    try testing.expectEqual(2, opp.len);
    try testing.expectEqual(0.497, opp[1].pair.p);
    try testing.expect(!opp[1].pair.ally);
    try testing.expectEqual(0.523, champion(&demo, .mid, brief("Thresh", "Support ally"), &out)[1].pair.p);
    // Zed as an ally has no cell: the role's line alone
    try testing.expectEqual(1, champion(&demo, .mid, brief("Zed", "Mid ally"), &out).len);
}

test "view: the matchup line, and without the other's slice" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const line = matchup(&demo, null, .mid, 238).?;
    try testing.expectEqual(null, matchup(&demo, null, .mid, 412));
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, view(&h, &.{line}, "48.6%"), &out.writer);
    const html = out.written();
    try testing.expect(std.mem.find(u8, html, "<b>49.7%</b><small>Ahri vs Zed</small>") != null);
    try testing.expect(std.mem.find(u8, html, "<b>48.6%</b>") != null);
    try testing.expect(std.mem.find(u8, html, "<small>Ahri 51.2%</small>") != null);
}
