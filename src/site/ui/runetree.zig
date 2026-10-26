//! RuneTree: every rune players took, laid out as in game (trees side by side, keystones
//! on top, then the stat shards), each with its pick share (bar and %), win rate and
//! games; the figures' names said once. Win rates are coloured against their row's (a
//! row is one choice), none under bp.rate_games, faded under bp.solid_games. The top rune
//! pages sit above as cards; the chosen one lights its runes. In a narrow container the
//! trees fold to the chosen page's (Every tree opens the rest). Tap a rune: its name and
//! figures in the readout line. An island part: a host embeds it and re-renders on its
//! events
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const art = @import("art.zig");
const phrase = @import("phrase.zig");
const button = @import("button.zig");
const bp = @import("buildpanel.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "RuneTree";
pub const scope = .{".c-runes"};

pub const Rune = struct { id: u32, art: art.Art, games: u32, wins: u32 };

pub const Tree = struct {
    id: u32,
    art: art.Art,
    /// Top down, keystones first; runes left to right
    rows: []const []const Rune,
};

pub const Page = struct {
    /// As the builds file's .runes value: primary tree, keystone, 3 runes, secondary
    /// tree, 2 runes
    v: [8]u32,
    keystone: art.Art,
    /// The secondary tree's icon
    second: art.Art,
    games: u32,
    wins: u32,
};

pub const Data = struct {
    /// The trees worth showing, most played first
    trees: []const Tree,
    /// Offense, flex, defense: ids repeat across rows, so a shard is (row, id)
    shards: []const []const Rune = &.{},
    /// Players with a rune page: the shares' whole
    games: u32,
    wins: u32,
    /// Most played first
    pages: []const Page = &.{},
    /// The most played shard of each row, lit with any page
    top_shards: [3]u32 = @splat(0),
};

const W = struct {
    pub const pick = plain("pick");
    pub const won = plain("won");
    pub const games = plain("games");
    pub const shards = plain("Shards");
    pub const every = plain("Every tree");
    pub const chosen = plain("Chosen page");
    pub const rune_games = phrase.Phrase("{n:count} games");
};

/// Which rune: tree index (shards: 15), row, column
const Pos = packed struct(u16) { col: u4, row: u4, tree: u4, _: u4 = 0 };
const shard_tree = 15;

pub const RuneTree = struct {
    data: *const Data,
    /// The page whose runes are lit (an index into data.pages)
    page: ?u8 = 0,
    /// Every tree, when folded to the chosen page's
    all: bool = false,
    /// The rune in the readout
    rune: ?Pos = null,
    /// Unique on the page
    id: []const u8 = "runes",

    pub const Msg = union(enum) { page: u8, all, rune: u16 };

    pub fn update(t: *RuneTree, m: Msg, ev: *tree.Event) void {
        _ = ev;
        switch (m) {
            .page => |i| t.page = if (t.page == i) null else i,
            .all => t.all = !t.all,
            .rune => |p| {
                const pos: Pos = @bitCast(p);
                t.rune = if (t.rune != null and @as(u16, @bitCast(t.rune.?)) == p) null else pos;
            },
        }
    }

    fn chosen(t: *const RuneTree) ?Page {
        const i = t.page orelse return null;
        return if (i < t.data.pages.len) t.data.pages[i] else null;
    }

    fn lit(t: *const RuneTree, id: u32) bool {
        const v = (t.chosen() orelse return false).v;
        return std.mem.findScalar(u32, v[1..5], id) != null or std.mem.findScalar(u32, v[6..8], id) != null;
    }

    fn treeLit(t: *const RuneTree, id: u32) bool {
        const v = (t.chosen() orelse return true).v;
        return v[0] == id or v[5] == id;
    }

    pub fn view(t: *RuneTree, h: *H) N {
        const d = t.data;
        var pages = h.list();
        for (d.pages, 0..) |p, i| pages.add(t.pageCard(h, p, @intCast(i)));
        var trees = h.list();
        for (d.trees, 0..) |tr, ti| {
            var rows = h.list();
            for (tr.rows, 0..) |row, ri| rows.add(t.runeRow(h, row, .{ .tree = @intCast(ti), .row = @intCast(ri), .col = 0 }, ri == 0, false));
            trees.add(h.div(.{ .class = "tree", .key = tr.id, .data_unlit = !t.treeLit(tr.id) }, .{
                h.el(.h4, .{}, .{ art.view(h, tr.art, .{ .k = .rune, .px = .@"16", .named = false }), tr.art.name }),
                rows.done(),
            }));
        }
        if (d.shards.len > 0) {
            var rows = h.list();
            for (d.shards, 0..) |row, ri| rows.add(t.runeRow(h, row, .{ .tree = shard_tree, .row = @intCast(ri), .col = 0 }, false, true));
            trees.add(h.div(.{ .class = "tree", .key = "shards", .data_v = "shards" }, .{ h.el(.h4, .{}, .{W.shards}), rows.done() }));
        }
        const folded = t.chosen() != null and !t.all;
        return h.div(.{ .class = "c-runes", .data_fold = folded }, .{
            h.div(.{ .class = "top" }, .{
                if (d.pages.len > 0) h.div(.{ .class = "pages" }, .{pages.done()}) else null,
                t.readout(h),
            }),
            h.div(.{ .class = "trees" }, .{trees.done()}),
            if (t.chosen() != null) button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(t, .all) }, .{if (t.all) W.chosen else W.every}) else null,
        });
    }

    fn pageCard(t: *RuneTree, h: *H, p: Page, i: u8) N {
        const share = 100 * @as(f64, @floatFromInt(p.games)) / @as(f64, @floatFromInt(@max(t.data.games, 1)));
        return h.div(.{ .class = "page", .key = i, .data_state = if (p.games < bp.solid_games) "thin" else null }, .{
            h.button(.{
                .type = "button",
                .class = "ks",
                .aria_pressed = t.page == i,
                .aria_label = h.fmt("{s}, {s}", .{ p.keystone.name, p.second.name }),
                .on_click = h.on(t, .{ .page = i }),
            }, .{
                art.view(h, p.keystone, .{ .k = .rune, .px = .@"28", .named = false }),
                art.view(h, p.second, .{ .k = .rune, .px = .@"16", .named = false }),
            }),
            h.span(.{ .class = "fig" }, .{ bp.win(h, p.games, p.wins, bp.rate(t.data.games, t.data.wins)), ci(h, p.games, p.wins) }),
            h.span(.{ .class = "g" }, .{ bp.shortCount(h, p.games), " · ", bp.pickText(h, share) }),
        });
    }

    fn runeRow(t: *RuneTree, h: *H, row: []const Rune, first: Pos, ks: bool, shard: bool) N {
        var games: u32 = 0;
        var wins: u32 = 0;
        for (row) |r| {
            games += r.games;
            wins += r.wins;
        }
        const ref = bp.rate(games, wins);
        var cells = h.list();
        for (row, 0..) |r, c| {
            var pos = first;
            pos.col = @intCast(c);
            const on = if (shard) t.chosen() != null and first.row < 3 and t.data.top_shards[first.row] == r.id else t.lit(r.id);
            cells.add(t.runeCell(h, r, pos, ref, on, ks, shard));
        }
        return h.div(.{ .class = "row", .data_v = if (ks) "ks" else null, .style = h.vars(.{ .n = row.len }) }, .{cells.done()});
    }

    fn runeCell(t: *RuneTree, h: *H, r: Rune, pos: Pos, ref: f64, on: bool, ks: bool, shard: bool) N {
        const share = 100 * @as(f64, @floatFromInt(r.games)) / @as(f64, @floatFromInt(@max(t.data.games, 1)));
        const px: art.Px = if (ks) .@"36" else if (shard) .@"20" else .@"28";
        const tapped = if (t.rune) |x| @as(u16, @bitCast(x)) == @as(u16, @bitCast(pos)) else false;
        const kids = .{
            art.view(h, r.art, .{ .k = .rune, .px = px }),
            h.span(.{ .class = "sh" }, .{h.el(.i, .{ .style = h.vars(.{ .w = @min(share, 100) }) }, .{})}),
            if (r.games > 0) h.span(.{ .class = "pk" }, .{bp.pickText(h, share)}) else null,
            if (r.games > 0) bp.win(h, r.games, r.wins, ref) else null,
            if (r.games > 0) h.span(.{ .class = "g" }, .{bp.shortCount(h, r.games)}) else null,
        };
        const share_attr: ?[]const u8 = if (share >= 50) "hi" else if (share >= 10) "mid" else null;
        const state: ?[]const u8 = if (tapped) "sel" else if (on) "lit" else null;
        if (r.games == 0) return h.span(.{ .class = "rune", .key = r.id, .data_state = state }, kids);
        return h.button(.{
            .type = "button",
            .class = "rune",
            .key = r.id,
            .data_share = share_attr,
            .data_state = state,
            .data_thin = r.games < bp.solid_games,
            .on_click = h.on(t, .{ .rune = @bitCast(pos) }),
        }, kids);
    }

    /// The chosen rune's name and figures, else the figures' names once
    fn readout(t: *RuneTree, h: *H) N {
        const pos = t.rune orelse return h.div(.{ .class = "key", .aria_hidden = true }, .{
            h.span(.{ .class = "pk" }, .{W.pick}),
            h.span(.{ .class = "w" }, .{W.won}),
            h.span(.{ .class = "g" }, .{W.games}),
        });
        const r = t.at(pos) orelse return h.div(.{ .class = "key" }, .{});
        const share = 100 * @as(f64, @floatFromInt(r.games)) / @as(f64, @floatFromInt(@max(t.data.games, 1)));
        return h.div(.{ .class = "key", .data_v = "rune", .aria_live = "polite" }, .{
            h.b(.{}, .{r.art.name}),
            h.span(.{ .class = "pk" }, .{ bp.pickText(h, share), " ", W.pick }),
            h.span(.{}, .{ bp.win(h, r.games, r.wins, t.rowRate(pos)), " ", W.won }),
            h.span(.{ .class = "g" }, .{W.rune_games.with(h, .{ .n = r.games })}),
        });
    }

    fn rowOf(t: *const RuneTree, pos: Pos) ?[]const Rune {
        const rows = if (pos.tree == shard_tree) t.data.shards else if (pos.tree < t.data.trees.len) t.data.trees[pos.tree].rows else return null;
        return if (pos.row < rows.len) rows[pos.row] else null;
    }

    fn at(t: *const RuneTree, pos: Pos) ?Rune {
        const row = t.rowOf(pos) orelse return null;
        return if (pos.col < row.len) row[pos.col] else null;
    }

    fn rowRate(t: *const RuneTree, pos: Pos) f64 {
        var games: u32 = 0;
        var wins: u32 = 0;
        for (t.rowOf(pos) orelse &.{}) |r| {
            games += r.games;
            wins += r.wins;
        }
        return bp.rate(games, wins);
    }
};

/// "±1.0": a 95% range, faint, beside a page's rate
fn ci(h: *H, games: u32, wins: u32) ?N {
    if (games < bp.rate_games) return null;
    const n: f64 = @floatFromInt(games);
    const p = @as(f64, @floatFromInt(wins)) / n;
    return h.span(.{ .class = "ci" }, .{ "±", phrase.num(h, .dec, 196 * @sqrt(p * (1 - p) / n)) });
}

pub const css =
    \\@layer components {
    \\  .c-runes { container-type: inline-size; display: flex; flex-direction: column; gap: var(--sp-3); min-width: 0; }
    \\  .c-runes > .top { display: flex; align-items: flex-end; justify-content: space-between; gap: var(--sp-2) var(--sp-3); flex-wrap: wrap; }
    \\  .c-runes .pages { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
    \\  .c-runes .page { position: relative; display: grid; grid-template-columns: auto auto; gap: 0 var(--sp-2);
    \\    align-items: center; padding: 5px 10px 5px 8px; border: 1px solid var(--line); border-radius: var(--r-m);
    \\    font-size: var(--fs-s); font-variant-numeric: tabular-nums; }
    \\  .c-runes .page:hover { background: var(--panel-2); }
    \\  .c-runes .page:has(> .ks[aria-pressed="true"]) { border-color: var(--sel-line); background: var(--accent-bg); }
    \\  .c-runes .page > .ks { all: unset; display: flex; align-items: center; gap: 2px; grid-row: span 2; cursor: pointer; }
    \\  .c-runes .page > .ks::after { content: ""; position: absolute; inset: 0; border-radius: inherit; }
    \\  .c-runes .page > .ks:focus-visible::after { outline: 2px solid var(--focus); }
    \\  .c-runes .page > .fig { display: flex; align-items: baseline; gap: 3px; }
    \\  .c-runes .page .w { font-weight: var(--w-b); color: var(--c, var(--faint)); }
    \\  .c-runes .page .ci, .c-runes .page > .g { color: var(--faint); font-size: var(--fs-xs); }
    \\  .c-runes .page[data-state="thin"] > .fig { opacity: 0.55; }
    \\  .c-runes .key { display: flex; align-items: baseline; gap: var(--sp-2); font-size: var(--fs-xs); color: var(--faint);
    \\    font-variant-numeric: tabular-nums; min-height: 18px; }
    \\  .c-runes .key > .pk { color: var(--muted); }
    \\  .c-runes .key > .w { color: var(--t2); font-weight: var(--w-b); font-size: var(--fs-s); }
    \\  .c-runes .key[data-v="rune"] { font-size: var(--fs-s); color: var(--t2); }
    \\  .c-runes .key[data-v="rune"] > b { color: var(--text); font-weight: var(--w-m); }
    \\  .c-runes .key[data-v="rune"] .w { font-weight: var(--w-b); color: var(--c, var(--faint)); }
    \\  .c-runes .trees { display: grid; grid-template-columns: repeat(auto-fill, minmax(132px, 1fr)); gap: var(--sp-3); }
    \\  .c-runes .tree { min-width: 0; }
    \\  .c-runes .tree > h4 { display: flex; align-items: center; gap: 6px; height: 20px; margin: 0 0 4px;
    \\    font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-runes .row { display: grid; grid-template-columns: repeat(var(--n, 3), minmax(0, 1fr)); gap: 2px;
    \\    padding: 3px 0; border-top: 1px solid var(--line); }
    \\  .c-runes .row:first-of-type { border-top: 0; }
    \\  .c-runes .rune { all: unset; box-sizing: border-box; display: flex; flex-direction: column; align-items: center;
    \\    gap: 1px; padding: 3px 0; border-radius: 6px; min-width: 0; font-variant-numeric: tabular-nums; text-align: center; }
    \\  .c-runes button.rune { cursor: pointer; }
    \\  .c-runes button.rune:hover { background: var(--panel-2); }
    \\  .c-runes button.rune:focus-visible { outline: 2px solid var(--focus); }
    \\  .c-runes .rune > .c-art { opacity: 0.35; filter: grayscale(1); }
    \\  .c-runes .rune[data-share="mid"] > .c-art { opacity: 0.7; filter: none; }
    \\  .c-runes .rune[data-share="hi"] > .c-art, .c-runes .rune[data-state] > .c-art { opacity: 1; filter: none; }
    \\  .c-runes .rune[data-state="lit"] { background: var(--accent-bg); box-shadow: inset 0 0 0 1px var(--sel-line); }
    \\  .c-runes .rune[data-state="sel"] { background: var(--panel-3); box-shadow: inset 0 0 0 1px var(--line-2); }
    \\  .c-runes .rune > .sh { width: 100%; max-width: 40px; height: 3px; margin-top: 2px; border-radius: 2px; background: var(--bar-track); }
    \\  .c-runes .rune > .sh > i { display: block; height: 100%; width: calc(var(--w) * 1%); border-radius: 2px; background: var(--bar-hi); }
    \\  .c-runes .rune > .pk { font-size: var(--fs-xs); color: var(--muted); line-height: 1.2; }
    \\  .c-runes .rune > .w { font-size: var(--fs-s); font-weight: var(--w-m); line-height: 1.2; color: var(--c, var(--faint)); }
    \\  .c-runes .rune > .g { font-size: var(--fs-xs); color: var(--faint); line-height: 1.1; }
    \\  .c-runes .rune[data-thin] > .pk, .c-runes .rune[data-thin] > .w { opacity: 0.55; }
    \\  .c-runes > .c-btn { display: none; align-self: flex-start; }
    \\  @container (max-width: 540px) {
    \\    .c-runes .trees { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    \\    .c-runes[data-fold] .tree[data-unlit] { display: none; }
    \\    .c-runes > .c-btn { display: inline-flex; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const demo = @import("build_demo.zig");
    const states = [_]struct { []const u8, RuneTree }{
        .{ "first page lit; folds to its trees when narrow", .{ .data = &demo.runes } },
        .{ "second page chosen, a rune tapped", .{ .data = &demo.runes, .page = 1, .rune = .{ .tree = 0, .row = 0, .col = 3 } } },
        .{ "no page chosen: every tree", .{ .data = &demo.runes, .page = null } },
    };
    for (states) |s| {
        const t = h.mem.create(RuneTree) catch {
            h.oom = true;
            return;
        };
        t.* = s[1];
        g.addFill(s[0], t.view(h));
    }
}
