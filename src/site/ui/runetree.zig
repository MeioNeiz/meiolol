//! RuneTree: every rune players took, laid out as in game (trees side by side, keystones
//! on top, then the stat shards), each with its pick share (bar and %), win rate and
//! games, unnamed (a tapped rune's readout names them). Win rates are coloured against their row's (a
//! row is one choice), each with its range, faded when wide (bp.win). The top rune
//! pages sit above as cards; the chosen one lights its runes and the trees fold to its
//! two and the shards, at every width (Every tree opens the rest). A page whose keystone
//! the host has builds for (locks) locks on tap, and the host shows the rest of the build
//! for that keystone; a second tap unlocks. With the champion page's lock set (`set`) a
//! page card locks its keystone and a rune tap locks the rune (shard) too. Tap a rune: its name and
//! figures in the readout line. On a matchup's, ▲▼ after a share the matchup moved from
//! the champion's usual. An island part: a host embeds it and re-renders on its
//! events
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const art = @import("art.zig");
const phrase = @import("phrase.zig");
const button = @import("button.zig");
const bp = @import("buildpanel.zig");
const lockbar = @import("lockbar.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "RuneTree";
pub const scope = .{".c-runes"};

pub const Rune = struct {
    id: u32,
    art: art.Art,
    games: u32,
    wins: u32,
    /// A matchup's: the champion's usual share of it, %, when the matchup moved it (▲▼)
    usual: ?u8 = null,
};

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
    pub const shards = plain("Shards");
    pub const every = plain("Every tree");
    pub const chosen = plain("Chosen page");
    pub const rune_games = phrase.Phrase("{n:count} games");
    pub const usually = phrase.Phrase("usually {p:pct}");
    pub const more = plain("▲");
    pub const less = plain("▼");
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
    /// Keystones the host has the rest of the build for: their pages lock on tap
    locks: []const u32 = &.{},
    /// The chosen page is locked (its keystone in locks)
    lock: bool = false,
    /// The champion page's lock set: pages and runes lock through it, `locks` unused
    set: ?*lockbar.Set = null,
    /// The rune in the readout
    rune: ?Pos = null,
    /// Unique on the page
    id: []const u8 = "runes",

    pub const Msg = union(enum) { page: u8, all, rune: u16 };

    pub fn update(t: *RuneTree, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .page => |i| {
                if (t.set) |s| {
                    if (i >= t.data.pages.len) return;
                    var buf: [lockbar.value_max]u8 = undefined;
                    s.toggle(.keystone, lockbar.text(&buf, &.{t.data.pages[i].v[1]}));
                    t.page = i;
                    ev.push = true;
                    ev.keep = true;
                } else if (i < t.data.pages.len and t.lockable(t.data.pages[i].v[1])) {
                    t.lock = !(t.page == i and t.lock);
                    t.page = i;
                    ev.push = true;
                } else {
                    t.page = if (t.page == i) null else i;
                    if (t.lock) ev.push = true;
                    t.lock = false;
                }
            },
            .all => t.all = !t.all,
            .rune => |p| {
                const pos: Pos = @bitCast(p);
                t.rune = if (t.rune != null and @as(u16, @bitCast(t.rune.?)) == p) null else pos;
                const s = t.set orelse return;
                const r = t.at(pos) orelse return;
                var buf: [lockbar.value_max]u8 = undefined;
                const l = lockOf(pos, r.id, &buf);
                s.toggle(l.kind, l.v);
                ev.push = true;
                ev.keep = true;
            },
        }
    }

    const Lock = struct { kind: lockbar.Kind, v: []const u8 };

    /// A rune's lock: a keystone's is the keystone, a shard's its row and id
    fn lockOf(pos: Pos, id: u32, buf: []u8) Lock {
        if (pos.tree == shard_tree) return .{ .kind = .shard, .v = lockbar.text(buf, &.{ pos.row, id }) };
        return .{ .kind = if (pos.row == 0) .keystone else .rune, .v = lockbar.text(buf, &.{id}) };
    }

    fn lockedAt(t: *const RuneTree, pos: Pos, id: u32) bool {
        const s = t.set orelse return false;
        var buf: [lockbar.value_max]u8 = undefined;
        const l = lockOf(pos, id, &buf);
        return s.has(l.kind, l.v);
    }

    fn lockable(t: *const RuneTree, keystone: u32) bool {
        return std.mem.findScalar(u32, t.locks, keystone) != null;
    }

    /// The locked page's keystone
    pub fn locked(t: *const RuneTree) ?u32 {
        return if (t.lockedPage()) |p| p.v[1] else null;
    }

    pub fn lockedPage(t: *const RuneTree) ?Page {
        return if (t.lock) t.chosen() else null;
    }

    /// Locks the page with `keystone` (most played first), or unlocks on null or none
    pub fn lockOn(t: *RuneTree, keystone: ?u32) void {
        t.lock = false;
        const k = keystone orelse return;
        if (!t.lockable(k)) return;
        for (t.data.pages, 0..) |p, i| if (p.v[1] == k) {
            t.page = @intCast(i);
            t.lock = true;
            return;
        };
    }

    /// `o`'s state on new data (a lock's answer): the page with the same runes, else the
    /// same two trees, else the first; Every tree; the tapped rune by its id (a rune is in
    /// one tree; a shard's id repeats across rows, so its row stays)
    pub fn keep(t: *RuneTree, o: *const RuneTree) void {
        t.all = o.all;
        t.page = if (o.chosen()) |c| t.like(c.v) else null;
        t.rune = null;
        const pos = o.rune orelse return;
        const r = o.at(pos) orelse return;
        if (pos.tree == shard_tree) {
            if (pos.row < t.data.shards.len) t.rune = find(t.data.shards[pos.row..][0..1], r.id, shard_tree, pos.row);
            return;
        }
        for (t.data.trees, 0..) |tr, ti| if (find(tr.rows, r.id, @intCast(ti), 0)) |x| {
            t.rune = x;
        };
    }

    fn like(t: *const RuneTree, v: [8]u32) ?u8 {
        pages: for (t.data.pages, 0..) |p, i| {
            for (p.v, v) |x, y| if (x != y) continue :pages;
            return @intCast(i);
        }
        for (t.data.pages, 0..) |p, i| if (p.v[0] == v[0] and p.v[5] == v[5]) return @intCast(i);
        return if (t.data.pages.len > 0) 0 else null;
    }

    fn find(rows: []const []const Rune, id: u32, tr: u4, first_row: usize) ?Pos {
        for (rows, first_row..) |row, ri| for (row, 0..) |r, c| if (r.id == id) {
            return .{ .tree = tr, .row = @intCast(ri), .col = @intCast(c) };
        };
        return null;
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
        // The chosen page's trees first, primary then secondary: a lock's answer with
        // other trees most played doesn't swap the columns
        var order: [16]u8 = undefined;
        const n = t.treeOrder(&order);
        for (order[0..n]) |ti| {
            const tr = d.trees[ti];
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

    fn treeOrder(t: *const RuneTree, out: *[16]u8) usize {
        const d = t.data;
        var n: usize = 0;
        const v = if (t.chosen()) |c| c.v else null;
        if (v) |x| for ([2]u32{ x[0], x[5] }) |id| for (d.trees, 0..) |tr, ti| if (tr.id == id and n < out.len) {
            out[n] = @intCast(ti);
            n += 1;
        };
        for (d.trees, 0..) |tr, ti| {
            if (v) |x| if (tr.id == x[0] or tr.id == x[5]) continue;
            if (n == out.len) break;
            out[n] = @intCast(ti);
            n += 1;
        }
        return n;
    }

    fn pageCard(t: *RuneTree, h: *H, p: Page, i: u8) N {
        const share = 100 * @as(f64, @floatFromInt(p.games)) / @as(f64, @floatFromInt(@max(t.data.games, 1)));
        const on = if (t.set != null) t.lockedAt(.{ .tree = 0, .row = 0, .col = 0 }, p.v[1]) else t.lock and t.page == i;
        return h.div(.{ .class = "page", .key = i, .data_lock = on }, .{
            h.button(.{
                .type = "button",
                .class = "ks",
                .aria_pressed = t.page == i,
                .aria_label = h.cat(&.{ p.keystone.name, ", ", p.second.name }),
                .on_click = h.on(t, .{ .page = i }),
            }, .{
                art.view(h, p.keystone, .{ .k = .rune, .px = .@"28", .named = false }),
                art.view(h, p.second, .{ .k = .rune, .px = .@"16", .named = false }),
            }),
            h.span(.{ .class = "fig" }, .{bp.win(h, p.games, p.wins, bp.rate(t.data.games, t.data.wins))}),
            h.span(.{ .class = "g" }, .{ bp.shortCount(h, p.games), " · ", bp.pickText(h, share) }),
            if (t.set != null or t.lockable(p.v[1])) lockbar.mark(h, on) else null,
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
        const lock_on = t.lockedAt(pos, r.id);
        const kids = .{
            if (t.set != null and r.games > 0) lockbar.mark(h, lock_on) else null,
            art.view(h, r.art, .{ .k = .rune, .px = px }),
            h.span(.{ .class = "sh" }, .{h.el(.i, .{ .style = h.vars(.{ .w = @min(share, 100) }) }, .{})}),
            if (r.games > 0 or r.usual != null) h.span(.{ .class = "pk" }, .{ bp.pickText(h, share), t.moved(h, r, share) }) else null,
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
            .data_lock = lock_on,
            .on_click = h.on(t, .{ .rune = @bitCast(pos) }),
        }, kids);
    }

    /// The chosen rune's name and figures, else the figures' names once, as a caption
    /// in their order under a rune (spaced words with one bold read as tabs)
    fn readout(t: *RuneTree, h: *H) N {
        const pos = t.rune orelse return h.div(.{ .class = "read" }, .{});
        const r = t.at(pos) orelse return h.div(.{ .class = "read" }, .{});
        const share = 100 * @as(f64, @floatFromInt(r.games)) / @as(f64, @floatFromInt(@max(t.data.games, 1)));
        return h.div(.{ .class = "read", .data_v = "rune", .aria_live = "polite" }, .{
            h.b(.{}, .{r.art.name}),
            h.span(.{ .class = "pk" }, .{ bp.pickText(h, share), " ", W.pick, t.moved(h, r, share) }),
            if (r.usual) |u| h.span(.{ .class = "pk" }, .{W.usually.with(h, .{ .p = u })}) else null,
            h.span(.{}, .{ bp.win(h, r.games, r.wins, t.rowRate(pos)), " ", W.won }),
            h.span(.{ .class = "g" }, .{W.rune_games.with(h, .{ .n = r.games })}),
        });
    }

    /// ▲ or ▼ after a pick share the matchup moved from the usual; the readout says how
    fn moved(_: *const RuneTree, h: *H, r: Rune, share: f64) N {
        const u = r.usual orelse return .none;
        return h.span(.{ .class = "mv", .aria_hidden = true }, .{if (share > @as(f64, @floatFromInt(u))) W.more else W.less});
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

pub const css =
    \\@layer components {
    \\  .c-runes { container-type: inline-size; display: flex; flex-direction: column; gap: var(--sp-3); min-width: 0; }
    \\  .c-runes > .top { display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-2); }
    \\  .c-runes .pages { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
    \\  .c-runes .page { position: relative; display: grid; grid-template-columns: auto auto; gap: 0 var(--sp-2);
    \\    align-items: center; padding: 6px 12px 6px 8px; border: 1px solid var(--line); border-radius: var(--r-m);
    \\    font-size: var(--fs-m); font-variant-numeric: tabular-nums; }
    \\  .c-runes .page > .ks > .c-art:first-child { --sz: 34px; }
    \\  .c-runes .page > .ks > .c-art + .c-art { --sz: 18px; }
    \\  .c-runes .page:hover { background: var(--panel-2); }
    \\  .c-runes .page:has(> .ks[aria-pressed="true"]) { border-color: var(--sel-line); background: var(--accent-bg); }
    \\  .c-runes .page[data-lock] { border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); }
    \\  .c-runes .page:hover > .c-lockmark { opacity: 1; }
    \\  .c-runes .page > .ks { all: unset; display: flex; align-items: center; gap: 2px; grid-row: span 2; cursor: pointer; }
    \\  .c-runes .page > .ks::after { content: ""; position: absolute; inset: 0; border-radius: inherit; }
    \\  .c-runes .page > .ks:focus-visible::after { outline: 2px solid var(--focus); }
    \\  .c-runes .page > .fig { display: flex; align-items: baseline; gap: 3px; }
    \\  .c-runes .c-rate > .v { font-weight: var(--w-b); }
    \\  .c-runes .page > .g { color: var(--faint); font-size: var(--fs-s); }
    \\  .c-runes .read { display: flex; align-items: baseline; gap: var(--sp-2); font-size: var(--fs-s); color: var(--faint);
    \\    font-variant-numeric: tabular-nums; min-height: 18px; }
    \\  .c-runes .read[data-v="rune"] { font-size: var(--fs-m); color: var(--t2); }
    \\  .c-runes .read[data-v="rune"] > b { color: var(--text); font-weight: var(--w-m); }
    \\  .c-runes .trees { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: var(--sp-3); }
    \\  .c-runes .tree { min-width: 0; }
    \\  .c-runes .tree > h4 { display: flex; align-items: center; gap: 6px; height: 20px; margin: 0 0 4px;
    \\    font-size: var(--fs-m); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-runes .row { display: grid; grid-template-columns: repeat(var(--n, 3), minmax(0, 1fr)); gap: 2px;
    \\    padding: 3px 0; border-top: 1px solid var(--line); }
    \\  .c-runes .row:first-of-type { border-top: 0; }
    \\  .c-runes .rune { all: unset; position: relative; box-sizing: border-box; display: flex; flex-direction: column; align-items: center;
    \\    gap: 1px; padding: 3px 0; border-radius: 6px; min-width: 0; font-variant-numeric: tabular-nums; text-align: center; }
    \\  .c-runes button.rune { cursor: pointer; }
    \\  .c-runes button.rune:hover { background: var(--panel-2); }
    \\  .c-runes button.rune:focus-visible { outline: 2px solid var(--focus); }
    \\  .c-runes .rune > .c-art { --sz: 32px; opacity: 0.35; filter: grayscale(1); }
    \\  .c-runes .row[data-v="ks"] .rune > .c-art { --sz: 38px; }
    \\  .c-runes .tree[data-v="shards"] .rune > .c-art { --sz: 24px; }
    \\  .c-runes .rune[data-share="mid"] > .c-art { opacity: 0.7; filter: none; }
    \\  .c-runes .rune[data-share="hi"] > .c-art, .c-runes .rune[data-state] > .c-art { opacity: 1; filter: none; }
    \\  .c-runes .rune[data-state="lit"] { background: var(--accent-bg); box-shadow: inset 0 0 0 1px var(--sel-line); }
    \\  .c-runes .rune[data-state="sel"] { background: var(--panel-3); }
    \\  .c-runes .rune[data-lock] { box-shadow: inset 0 0 0 2px var(--accent); }
    \\  .c-runes button.rune:hover > .c-lockmark { opacity: 1; }
    \\  .c-runes .rune > .sh { width: 100%; max-width: 40px; height: 3px; margin-top: 2px; border-radius: 2px; background: var(--bar-track); }
    \\  .c-runes .rune > .sh > i { display: block; height: 100%; width: calc(var(--w) * 1%); border-radius: 2px; background: var(--bar-hi); }
    \\  .c-runes .rune > .pk { font-size: var(--fs-s); color: var(--muted); line-height: 1.25; }
    \\  .c-runes .mv { margin-left: 2px; color: var(--t2); }
    \\  .c-runes .rune > .c-rate { font-size: var(--fs-m); line-height: 1.25; }
    \\  .c-runes .rune > .g { font-size: var(--fs-s); color: var(--faint); line-height: 1.2; }
    \\  .c-runes > .c-btn { align-self: flex-start; }
    \\  @container (min-width: 680px) {
    \\    .c-runes .trees { gap: var(--sp-4); }
    \\    .c-runes .rune > .c-art { --sz: 36px; }
    \\    .c-runes .row[data-v="ks"] .rune > .c-art { --sz: 44px; }
    \\    .c-runes .tree[data-v="shards"] .rune > .c-art { --sz: 28px; }
    \\    .c-runes .rune > .pk { font-size: var(--fs-m); }
    \\    .c-runes .rune > .c-rate { font-size: var(--fs-l); }
    \\    .c-runes .rune > .g { font-size: var(--fs-m); }
    \\    .c-runes .tree > h4 { font-size: var(--fs-l); height: 24px; }
    \\  }
    \\  .c-runes[data-fold] .trees { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    \\  .c-runes[data-fold] .tree[data-unlit] { display: none; }
    \\  @container (max-width: 540px) {
    \\    .c-runes .trees, .c-runes[data-fold] .trees { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const demo = @import("build_demo.zig");
    const states = [_]struct { []const u8, RuneTree }{
        .{ "first page lit: its two trees and the shards", .{ .data = &demo.runes } },
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
    const vs = matchup(h, &demo.runes) catch {
        h.oom = true;
        return;
    };
    const t = h.mem.create(RuneTree) catch {
        h.oom = true;
        return;
    };
    t.* = .{ .data = vs, .rune = .{ .tree = 0, .row = 0, .col = 0 } };
    g.addFill("a matchup's: keystones moved from the usual, one tapped", t.view(h));
    const set = h.mem.create(lockbar.Set) catch {
        h.oom = true;
        return;
    };
    set.* = .{};
    set.toggle(.keystone, "8010");
    set.toggle(.rune, "8299");
    const lk = h.mem.create(RuneTree) catch {
        h.oom = true;
        return;
    };
    lk.* = .{ .data = &demo.runes, .page = 1, .set = set };
    g.addFill("champion page locks: Conqueror and Last Stand locked (the mark), the rest lock on tap", lk.view(h));
}

/// `d` with its first tree's first two keystones moved: one taken far more, one less
fn matchup(h: *H, d: *const Data) !*const Data {
    const trees = try h.mem.dupe(Tree, d.trees);
    const rows = try h.mem.dupe([]const Rune, trees[0].rows);
    const ks = try h.mem.dupe(Rune, rows[0]);
    ks[0].usual = 12;
    if (ks.len > 1) ks[1].usual = 70;
    rows[0] = ks;
    trees[0].rows = rows;
    const out = try h.mem.create(Data);
    out.* = d.*;
    out.trees = trees;
    return out;
}
