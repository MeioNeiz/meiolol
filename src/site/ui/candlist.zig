//! CandidateList: ranked champions for one seat, the core of "select an option to see
//! why". A row: rank, icon, name, the model's star, the played (or locked) one marked,
//! the team's win chance with it and the gap to the reference row, up to three reason
//! chips; pressing a row opens its ReasonBreakdown under it (the owner keeps which, two
//! at most). Chips sit under the name in a narrow panel (Daily's seat panel), inline in
//! a wide one (draft tester), a Pick button after them when the owner fills the seat
//! from the list. Words mode (the public app: product rules, why.md): no
//! numbers, reasons as words with a direction
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const champ = @import("champ.zig");
const chip = @import("chip.zig");
const badge = @import("badge.zig");
const button = @import("button.zig");
const reasons = @import("reasons.zig");
const role = @import("role.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "CandidateList";
pub const scope = .{".c-cand"};

pub const Mode = reasons.Mode;

pub const Reason = struct {
    /// "into Yuumi"
    text: tree.Text,
    /// Points it gives the row's team (points mode shows them, words the direction)
    pp: f32,
    /// Drawn in place of the words, which move to the chip's title and a screen reader:
    /// the other champion in its team's ring (champ.view 20 px), or the role (strength)
    pic: ?N = null,
};

pub const Row = struct {
    champ: champ.Champ,
    /// 1 = the model's first; null hides the number
    rank: ?u32 = null,
    /// The model's pick
    star: bool = false,
    /// The reference row: played, or locked in
    ref: bool = false,
    /// The team's win chance with it, %
    win: ?f32 = null,
    /// Points against the reference row; null on that row
    vs: ?f32 = null,
    reasons: []const Reason = &.{},
    /// A neutral Badge after the reasons ("harder to pick up")
    tag: ?tree.Text = null,
    /// Rows left out above this one (the played pick far down the list)
    gap: bool = false,
    open: bool = false,
    /// What opens under the row, in the list's mode
    detail: ?reasons.Breakdown = null,
    /// The button's name when it opens a detail ("Why Gnar"); null: the champion's name
    label: ?tree.Text = null,
    /// Page-unique id of the open detail, for aria-controls; "" for none
    id: []const u8 = "",
    on: ?tree.Handler = null,
    /// The app's click (ui/practice.zig Act); "" for none
    act: []const u8 = "",
    /// Puts the champion in the seat (withPick only); null: no Pick button
    pick: ?tree.Handler = null,
    /// The Pick button's name ("Pick Gnar")
    pick_label: ?tree.Text = null,
};

pub const Base = struct {
    /// "Average top"
    label: tree.Text,
    win: f32,
};

pub const List = struct {
    rows: []const Row,
    mode: Mode = .points,
    /// Column heads, points mode: "Red's win chance", "with", "vs played"
    head: ?[3]tree.Text = null,
    /// The reference row's badge
    ref_label: tree.Text = W.played,
    /// A pinned first row: the role's average
    base: ?Base = null,
};

pub fn view(h: *H, l: List) N {
    return viewOf(h, l, false);
}

/// With the rows' Pick buttons: a separate instance, so a page without them (Daily, at
/// its wasm budget) carries none of their code
pub fn withPick(h: *H, l: List) N {
    return viewOf(h, l, true);
}

fn viewOf(h: *H, l: List, comptime pick: bool) N {
    var rows = h.list();
    for (l.rows, 0..) |r, i| {
        if (r.gap) rows.add(h.div(.{ .key = 3 * i + 1, .class = "gap", .aria_hidden = true }, .{"⋯"}));
        rows.add(row(h, l, r, 3 * i + 2, pick));
    }
    return h.div(.{ .class = "c-cand", .data_v = if (l.mode == .points) null else l.mode }, .{
        if (l.head) |hd| h.div(.{ .class = "hd" }, .{
            h.span(.{ .class = "nm" }, .{hd[0]}),
            h.span(.{ .class = "v" }, .{hd[1]}),
            h.span(.{ .class = "d" }, .{hd[2]}),
        }) else null,
        if (l.base) |b| h.div(.{ .class = "r base" }, .{
            h.span(.{ .class = "rk" }, .{}),
            h.span(.{ .class = "nm" }, .{b.label}),
            if (l.mode == .points) h.span(.{ .class = "v" }, .{phrase.num(h, .rate, b.win)}) else null,
            if (l.mode == .points) h.span(.{ .class = "d" }, .{}) else null,
        }) else null,
        rows.done(),
    });
}

fn row(h: *H, l: List, r: Row, key: usize, comptime pick: bool) N {
    var chips = h.list();
    for (r.reasons[0..@min(3, r.reasons.len)]) |x| {
        const v = if (l.mode == .points)
            h.b(.{ .style = h.vars(.{ .c = fmt.Step.of(x.pp, fmt.win_cuts) }) }, .{phrase.num(h, .points, x.pp)})
        else
            reasons.arrow(h, x.pp);
        chips.add(chip.view(h, .{ .v = .reason, .title = if (x.pic != null) x.text.s else null }, .{
            x.pic orelse h.text(x.text.s),
            if (x.pic != null) h.span(.{ .class = "sr" }, .{x.text}) else h.text(" "),
            v,
        }));
    }
    const pressable = r.on != null or r.act.len > 0;
    // Only the name is the button (a short label); its ::after stretches over the row
    const who = .{ champ.view(h, r.champ, .{ .named = false }), h.b(.{}, .{r.champ.name}) };
    const head = h.div(.{ .key = 0, .class = "r", .data_ref = r.ref }, .{
        h.span(.{ .class = "rk" }, .{if (r.rank) |n| phrase.num(h, .int, n) else null}),
        h.span(.{ .class = "nm" }, .{
            if (pressable) h.button(.{
                .class = "pk",
                .type = "button",
                .aria_label = r.label,
                .aria_expanded = if (r.detail != null or r.open) r.open else null,
                .aria_controls = if (r.open and r.detail != null and r.id.len > 0) r.id else null,
                .on_click = r.on,
                .data_act = if (r.act.len > 0) r.act else null,
            }, who) else h.span(.{ .class = "pk" }, who),
            if (r.star) h.span(.{ .class = "star", .role = "img", .aria_label = W.star }, .{"★"}) else null,
            if (r.ref) badge.view(h, .accent, .{l.ref_label}) else null,
        }),
        if (l.mode == .points) h.span(.{ .class = "v" }, .{if (r.win) |w| phrase.num(h, .rate, w) else null}) else null,
        if (l.mode == .points) h.span(.{
            .class = "d",
            .style = if (r.vs) |d| h.vars(.{ .c = fmt.Step.of(d, fmt.win_cuts) }) else null,
        }, .{if (r.vs) |d| phrase.num(h, .points, d) else null}) else null,
        if (r.reasons.len > 0 or r.tag != null or (pick and r.pick != null)) h.span(.{ .class = "why" }, .{
            chips.done(),
            if (r.tag) |t| badge.view(h, .neutral, .{t}) else null,
            goButton(h, r, pick),
        }) else null,
    });
    const det: ?N = if (r.open) if (r.detail) |d| h.div(.{
        .key = 1,
        .class = "det",
        .id = if (r.id.len > 0) r.id else null,
    }, .{reasons.view(h, d, l.mode)}) else null else null;
    return h.div(.{ .key = key, .class = "row" }, .{ head, det });
}

fn goButton(h: *H, r: Row, comptime pick: bool) ?N {
    if (!pick) return null;
    const hd = r.pick orelse return null;
    return h.span(.{ .class = "go" }, .{button.view(h, .{ .v = .quiet, .s = .s, .label = r.pick_label, .on = hd }, .{W.pick})});
}

const W = struct {
    const played = plain("played");
    const star = plain("The model's pick");
    const pick = plain("Pick");
};

pub const css =
    \\@layer components {
    \\  .c-cand .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
    \\  .c-cand { container-type: inline-size; display: grid; min-width: 0; font-variant-numeric: tabular-nums; }
    \\  .c-cand .hd { display: grid; grid-template-columns: 22px minmax(0, 1fr) 56px 48px;
    \\    column-gap: var(--sp-2); align-items: center; padding: 0 var(--sp-2); }
    \\  .c-cand .r { position: relative; box-sizing: border-box; display: grid; grid-template-columns: 22px minmax(0, 1fr) 56px 48px;
    \\    column-gap: var(--sp-2); row-gap: 2px; align-items: center; min-height: 38px; padding: 4px var(--sp-2);
    \\    border-bottom: 1px solid var(--line); width: 100%; }
    \\  .c-cand .pk { all: unset; display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-cand button.pk { cursor: pointer; }
    \\  .c-cand button.pk::after { content: ""; position: absolute; inset: 0; }
    \\  .c-cand .r:has(button.pk:hover), .c-cand .r:has([aria-expanded="true"]) { background: var(--panel-2); }
    \\  .c-cand .r:has(button.pk:focus-visible) { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-cand .r[data-ref] { box-shadow: inset 2px 0 0 var(--accent); }
    \\  .c-cand .hd { min-height: 28px; font-size: var(--fs-xs); color: var(--faint); border-bottom: 1px solid var(--line); }
    \\  .c-cand .rk { color: var(--faint); font-size: var(--fs-s); text-align: right; }
    \\  .c-cand .nm { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; white-space: nowrap; }
    \\  .c-cand .pk > b { font-weight: var(--w-m); overflow: hidden; text-overflow: ellipsis; }
    \\  .c-cand .star { color: var(--turn); }
    \\  .c-cand .v { text-align: right; font-weight: var(--w-b); }
    \\  .c-cand .d { text-align: right; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--c, var(--faint)); }
    \\  .c-cand .hd .v, .c-cand .hd .d { font-weight: var(--w-r); color: var(--faint); font-size: var(--fs-xs); }
    \\  .c-cand .why { grid-column: 2 / -1; display: flex; gap: 4px; flex-wrap: wrap; padding-left: 32px; }
    \\  .c-cand .why b { color: var(--c); font-weight: var(--w-b); }
    \\  .c-cand .go { margin-left: auto; position: relative; z-index: 1; }
    \\  .c-cand .why b[data-dir="up"] { color: var(--hi2); }
    \\  .c-cand .why b[data-dir="down"] { color: var(--lo2); }
    \\  .c-cand .base { color: var(--muted); }
    \\  .c-cand .base .v { font-weight: var(--w-r); }
    \\  .c-cand .det { padding: 0 var(--sp-2) var(--sp-1) 38px; background: var(--panel-2); border-bottom: 1px solid var(--line); }
    \\  .c-cand .gap { text-align: center; color: var(--faint); font-size: var(--fs-xs); padding: 2px 0;
    \\    border-bottom: 1px solid var(--line); }
    \\  .c-cand[data-v="words"] .r { grid-template-columns: 22px minmax(0, 1fr); }
    \\  @container (min-width: 640px) {
    \\    .c-cand .r, .c-cand .hd { grid-template-columns: 22px minmax(140px, 200px) 64px 56px minmax(0, 1fr); }
    \\    .c-cand[data-v="words"] .r { grid-template-columns: 22px minmax(140px, 200px) minmax(0, 1fr); }
    \\    .c-cand .why { grid-column: auto; grid-row: 1; grid-column-end: -1; padding-left: var(--sp-2); }
    \\  }
    \\  @container (max-width: 340px) {
    \\    .c-cand .why { padding-left: 0; }
    \\    .c-cand .det { padding-left: var(--sp-2); }
    \\  }
    \\}
    \\
;

const demo = champ.demo;

/// The gallery's Pick buttons' target
const Owner = struct {
    pub const Msg = enum { pick };
    pub fn update(_: *Owner, _: Msg, _: *tree.Event) void {}
};

/// Daily #11's red top: the model's five and the played Jayce third
pub const sample_rows = [_]Row{
    .{ .champ = demo("Gnar", "Gnar"), .rank = 1, .star = true, .win = 49.9, .vs = 1.0, .reasons = &.{
        .{ .text = plain("into K'Sante"), .pp = 1.2 },
        .{ .text = plain("strong top"), .pp = 0.4 },
    } },
    .{ .champ = demo("Ambessa", "Ambessa"), .rank = 2, .win = 49.4, .vs = 0.5, .reasons = &.{
        .{ .text = plain("with Vi"), .pp = 0.6 },
    } },
    .{ .champ = demo("Jayce", "Jayce"), .rank = 3, .ref = true, .win = 48.9, .detail = reasons.sample, .reasons = &.{
        .{ .text = plain("into K'Sante"), .pp = 0.9 },
        .{ .text = plain("strong top"), .pp = 0.6 },
        .{ .text = plain("into Viktor"), .pp = -0.4 },
    } },
    .{ .champ = demo("Renekton", "Renekton"), .rank = 4, .win = 48.4, .vs = -0.5 },
    .{ .champ = demo("Jax", "Jax"), .rank = 5, .win = 48.1, .vs = -0.8, .reasons = &.{
        .{ .text = plain("weak top"), .pp = -0.7 },
    } },
};

const words_rows = [_]Row{
    .{ .champ = demo("Jinx", "Jinx"), .reasons = &.{
        .{ .text = plain("strong bot"), .pp = 1.2 },
        .{ .text = plain("into Yuumi"), .pp = -0.8 },
    } },
    .{ .champ = demo("Caitlyn", "Caitlyn"), .ref = true },
    .{ .champ = demo("Ezreal", "Ezreal"), .reasons = &.{.{ .text = plain("with Lulu"), .pp = 0.5 }} },
    .{ .champ = demo("Ashe", "Ashe") },
};

fn sample(h: *H, g: *Gallery, open: bool) List {
    const rows = h.mem.dupe(Row, &sample_rows) catch {
        h.oom = true;
        return .{ .rows = &.{} };
    };
    for (rows) |*r| r.act = "x";
    rows[2].open = open;
    // Daily's reasons as pictures, blue (us) ringing the enemy
    const pics = h.mem.dupe(Reason, rows[2].reasons) catch {
        h.oom = true;
        return .{ .rows = &.{} };
    };
    const px: champ.Px = .@"20";
    pics[0].pic = champ.view(h, demo("K'Sante", "KSante"), .{ .px = px, .side = .us, .named = false });
    pics[1].pic = role.view(h, .top, .{ .s = .s, .named = false });
    pics[2].pic = champ.view(h, demo("Viktor", "Viktor"), .{ .px = px, .side = .us, .named = false });
    rows[2].reasons = pics;
    rows[2].label = plain("Why Jayce");
    rows[2].id = g.id("cand-why");
    if (rows[2].detail) |*d| d.tip_id = g.id("cand-rest");
    return .{ .rows = rows, .head = .{ plain("Red's win chance"), plain("with"), plain("vs played") } };
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("seat panel, played row open", view(h, sample(h, g, true)));
    var gap = sample(h, g, false);
    gap.base = .{ .label = plain("Average top"), .win = 47.5 };
    if (gap.rows.len != sample_rows.len) return;
    const rows = h.mem.alloc(Row, gap.rows.len) catch {
        h.oom = true;
        return;
    };
    for (rows, [_]usize{ 0, 1, 3, 4, 2 }) |*r, i| r.* = gap.rows[i];
    rows[4].rank = 10;
    rows[4].gap = true;
    const owner = h.mem.create(Owner) catch {
        h.oom = true;
        return;
    };
    for (rows[0..4]) |*r| {
        r.pick = h.on(owner, .pick);
        r.pick_label = plain("Pick it");
    }
    gap.rows = rows;
    g.addFill("average pinned, played far down, Pick", withPick(h, gap));
    g.addFill("words, public app", view(h, .{ .mode = .words, .ref_label = plain("locked in"), .rows = &words_rows }));
}

const testing = std.testing;

fn render(a: std.mem.Allocator, l: List) ![]const u8 {
    const html = @import("html.zig");
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var out: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, view(&h, l), &out.writer);
    return out.written();
}

test "rows: empty, one, three chips at most, no rank, a gap; buttons only when pressable" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const count = std.mem.count;
    var s = try render(a, .{ .rows = &.{} });
    try testing.expectEqual(0, count(u8, s, "class=\"row\""));

    const four = [_]Reason{
        .{ .text = plain("a"), .pp = 1 },  .{ .text = plain("b"), .pp = 1 },
        .{ .text = plain("c"), .pp = -1 }, .{ .text = plain("d"), .pp = 1 },
    };
    s = try render(a, .{ .rows = &.{.{ .champ = demo("Jax", "Jax"), .reasons = &four, .gap = true }} });
    try testing.expectEqual(1, count(u8, s, "class=\"row\""));
    try testing.expectEqual(3, count(u8, s, "c-chip"));
    try testing.expectEqual(1, count(u8, s, "class=\"gap\""));
    try testing.expectEqual(0, count(u8, s, "<button"));
    try testing.expect(std.mem.find(u8, s, "<span class=\"rk\"></span>") != null);
}

test "open: the detail under its row, controlled by its button; closed or without one, none" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const find = std.mem.find;
    var r: Row = .{ .champ = demo("Jayce", "Jayce"), .act = "x", .detail = reasons.sample, .label = plain("Why Jayce"), .id = "why-1" };
    var s = try render(a, .{ .rows = &.{r} });
    try testing.expect(find(u8, s, "aria-expanded=\"false\"") != null);
    try testing.expect(find(u8, s, "aria-controls") == null);
    try testing.expect(find(u8, s, "c-wf") == null);
    r.open = true;
    s = try render(a, .{ .rows = &.{r} });
    try testing.expect(find(u8, s, "aria-expanded=\"true\"") != null);
    try testing.expect(find(u8, s, "aria-controls=\"why-1\"") != null);
    try testing.expect(find(u8, s, "id=\"why-1\"") != null);
    try testing.expect(find(u8, s, "aria-label=\"Why Jayce\"") != null);
    r.detail = null;
    s = try render(a, .{ .rows = &.{r} });
    try testing.expect(find(u8, s, "c-wf") == null);
    try testing.expect(find(u8, s, "aria-expanded=\"true\"") != null);
    try testing.expect(find(u8, s, "aria-controls") == null);
}

test "words: no numbers anywhere, the pinned base and an open detail included" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var rows = sample_rows;
    rows[2].open = true;
    rows[2].act = "x";
    const s = try render(a, .{ .rows = &rows, .mode = .words, .base = .{ .label = plain("Average top"), .win = 47.5 } });
    try testing.expectEqual(0, std.mem.count(u8, s, "%"));
    try testing.expect(std.mem.find(u8, s, "+0.") == null);
    try testing.expect(std.mem.find(u8, s, "data-v=\"words\"") != null);
    try testing.expect(std.mem.find(u8, s, "aria-label=\"helps\"") != null);
}
