//! patch.html in every view: the current patch against the one before (src/patchday.zig)
//! in the view's region, whole patches whatever its period, with what Riot changed
//! (src/patchnotes.zig). The ui.patchpage island, its data in the view's data/patch.bin.
//! The 30-day views also have patches/<cur>-<prev>.html, one per older pair
//! (Site.older), win rates only

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const root = @import("root.zig");
const html = root.html;
const assets = @import("assets.zig");
const matchup = @import("matchup.zig");
const patchday = @import("../patchday.zig");
const patchnotes = @import("../patchnotes.zig");
const builds = @import("../builds.zig");

const Writer = std.Io.Writer;
const Site = root.Site;
const tpl = html.tpl;
const pp = ui.patchpage;
const PatchDay = patchday.PatchDay;
const Rate = patchday.Rate;
const Role = core.Role;

pub const path = "patch.html";

/// The island's data file, in each view's directory
pub const data_path = "data/patch.bin";

/// A row's matchup moves: every one that moved clearly, then its biggest others up to this
const max_moves = 3;
/// A changed item's or rune's champions
const max_users = 3;

comptime {
    for (Role.all, 0..) |r, i| std.debug.assert(std.mem.eql(u8, r.label(), pp.Role.slugs[i]));
    std.debug.assert(pp.pair_games == (patchday.Options{}).min_pair_games);
    std.debug.assert(pp.role_games == (patchday.Options{}).min_role_games);
    std.debug.assert(pp.z == (patchday.Options{}).z);
    // change() and line() map by name, so equal counts mean the same fields both ways
    std.debug.assert(std.enums.values(patchnotes.Dir).len == std.enums.values(ui.changeline.Dir).len);
    std.debug.assert(std.enums.values(patchnotes.Status).len == std.enums.values(pp.Status).len);
}

/// A pair's page: the newest (patch.html) or one of Site.older's
const Pair = struct {
    pd: *const PatchDay,
    notes: ?*const patchnotes.Notes,
    /// Site.older's index; null: the newest
    older: ?usize = null,
};

fn newest(site: *const Site) ?Pair {
    return .{ .pd = if (site.patchday) |*pd| pd else return null, .notes = site.notes };
}

fn olderPair(site: *const Site, i: usize) Pair {
    return .{ .pd = &site.older[i].pd, .notes = site.older[i].notes, .older = i };
}

/// "patches/16.20-16.19.html"
fn pairPath(a: std.mem.Allocator, pair: [2][]const u8) ![]const u8 {
    return a.print("patches/{s}-{s}.html", .{ pair[0], pair[1] });
}

fn dataPath(site: *const Site, pair: Pair) ![]const u8 {
    if (pair.older == null) return data_path;
    return site.arena.print("data/patch-{s}-{s}.bin", .{ pair.pd.cur_patch, pair.pd.prev_patch });
}

fn pagePath(site: *const Site, pair: Pair) ![]const u8 {
    if (pair.older == null) return path;
    return pairPath(site.arena, .{ pair.pd.cur_patch, pair.pd.prev_patch });
}

/// The older pairs' pages, from the options: a core static build loads no patch days
pub fn paths(site: *const Site, list: *std.ArrayList([]const u8)) !void {
    if (site.view.period != .days30) return;
    for (site.opts.older_pairs) |pair| try list.append(site.arena, try pairPath(site.arena, pair));
}

/// patches/<cur>-<prev>.html (`name` without either); false when it isn't one of
/// Site.older's
pub fn writeOlder(site: *const Site, w: *Writer, name: []const u8) !bool {
    for (site.older, 0..) |o, i| {
        if (!named(o.pd.cur_patch, o.pd.prev_patch, name)) continue;
        try writePair(site, w, olderPair(site, i));
        return true;
    }
    return false;
}

/// Whether `name` is "<cur>-<prev>"
fn named(cur: []const u8, prev: []const u8, name: []const u8) bool {
    if (name.len != cur.len + 1 + prev.len) return false;
    return std.mem.startsWith(u8, name, cur) and name[cur.len] == '-' and std.mem.endsWith(u8, name, prev);
}

test named {
    try std.testing.expect(named("16.20", "16.19", "16.20-16.19"));
    try std.testing.expect(!named("16.20", "16.19", "16.20-16.1"));
    try std.testing.expect(!named("16.2", "16.19", "16.20-16.19"));
    try std.testing.expect(!named("16.20", "16.19", "16.20_16.19"));
    try std.testing.expect(!named("16.20", "16.19", ""));
}

pub fn writePage(site: *const Site, w: *Writer) !void {
    const pair = newest(site) orelse {
        const pg = try site.page("Patch changes | meiolol", "How champions and lane matchups changed from the previous patch.", path, .patch);
        try html.head(w, pg);
        try tpl.render(w, "<h1>Patch changes</h1>\n<p>No earlier patch in the data yet to compare with.</p>\n", .{});
        return html.foot(w, pg);
    };
    try writePair(site, w, pair);
}

fn writePair(site: *const Site, w: *Writer, pair: Pair) !void {
    const a = site.arena;
    const pd = pair.pd;
    const page_path = try pagePath(site, pair);
    var pg = try site.page(
        try a.print("Patch {s} vs {s}: what changed | meiolol", .{ pd.cur_patch, pd.prev_patch }),
        try a.print("What Riot changed in patch {s}, next to how each champion's and lane matchup's win rate moved from {s}, with the games behind each.", .{ pd.cur_patch, pd.prev_patch }),
        page_path,
        .patch,
    );
    pg.rank_off = "This page counts every game we crawl (Plat+)";
    // A pair's page is the 30-day views' only, its numbers the same in either period
    if (pair.older != null) if (pg.counterparts) |*c| for (html.View.all) |v| {
        if (v.period == .patch) c[v.index()] = c[(html.View{ .region = v.region, .period = .days30 }).index()];
    };
    try html.head(w, pg);
    const d = try a.create(pp.Data);
    d.* = try data(site, pair);
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, pp.Data, d.*, &bytes);
    const to_root = try site.toRoot(page_path);
    const base = try std.mem.concat(a, u8, &.{ to_root, site.view.up() });
    var p: pp.Page = .init(d, try pp.prepare(a, d, base));
    p.base = base;
    p.src = try std.mem.concat(a, u8, &.{ to_root, try dataPath(site, pair) });
    p.stamp = pp.stamp(bytes.items);
    var tree: ui.Tree = .{};
    var h: ui.H = .init(a, &tree);
    tree.root = p.view(&h);
    if (h.oom) return error.OutOfMemory;
    try root.roleIcons(w);
    try ui.html.write(&tree, tree.root, w);
    try tpl.render(w, "\n<script src=\"{js}\" data-wasm=\"{wasm}\" defer></script>\n", .{
        .js = html.Link{ .root = to_root, .up = site.view.up(), .path = assets.patch_js.path },
        .wasm = assets.patch_wasm.path,
    });
    try html.foot(w, pg);
}

/// data/patch.bin, and each older pair's
pub fn dataFiles(site: *const Site, files: *std.ArrayList(root.File)) !void {
    const first = newest(site) orelse return;
    for (0..site.older.len + 1) |k| {
        const pair = if (k == 0) first else olderPair(site, k - 1);
        var out: std.ArrayList(u8) = .empty;
        try ui.data.encode(site.arena, pp.Data, try data(site, pair), &out);
        try files.append(site.arena, .{ .path = try dataPath(site, pair), .data = out.items });
    }
}

/// From the page to the region's 30-day view's `rest` ("patch.html", a pair's page)
fn navHref(site: *const Site, page_path: []const u8, rest: []const u8) ![]const u8 {
    const region: html.View = .{ .region = site.view.region, .period = .days30 };
    return std.mem.concat(site.arena, u8, &.{ try site.toRoot(page_path), site.view.up(), region.dir(), rest });
}

/// Where ‹ or › goes: an Options.older_pairs index, or the newest pair (patch.html)
const Step = union(enum) { newest, pair: usize };

/// ‹ and › from the newest pair's page (`at` null) or older pair `at`'s, of `n`
fn steps(n: usize, at: ?usize) [2]?Step {
    const next = if (at) |i| i + 1 else 0;
    const older: ?Step = if (next < n) .{ .pair = next } else null;
    const i = at orelse return .{ older, null };
    return .{ older, if (i == 0) .newest else .{ .pair = i - 1 } };
}

test steps {
    const T = [2]?Step;
    try std.testing.expectEqual(T{ null, null }, steps(0, null));
    try std.testing.expectEqual(T{ .{ .pair = 0 }, null }, steps(2, null));
    try std.testing.expectEqual(T{ .{ .pair = 1 }, .newest }, steps(2, 0));
    try std.testing.expectEqual(T{ null, .{ .pair = 0 } }, steps(2, 1));
    try std.testing.expectEqual(T{ null, .newest }, steps(1, 0));
}

/// PatchHead's ‹ ›: Options.older_pairs' pages, the newest pair's at patch.html
fn nav(site: *const Site, pair: Pair) ![2]?ui.patchhead.Pair {
    const pairs = site.opts.older_pairs;
    const page_path = try pagePath(site, pair);
    var out: [2]?ui.patchhead.Pair = .{ null, null };
    for (steps(pairs.len, pair.older), &out) |step, *o| o.* = switch (step orelse continue) {
        .newest => if (site.patchday) |pd| .{
            .cur = pd.cur_patch,
            .prev = pd.prev_patch,
            .href = try navHref(site, page_path, path),
        } else null,
        .pair => |k| .{
            .cur = pairs[k][0],
            .prev = pairs[k][1],
            .href = try navHref(site, page_path, try pairPath(site.arena, pairs[k])),
        },
    };
    return out;
}

fn data(site: *const Site, pair: Pair) !pp.Data {
    const a = site.arena;
    const pd = pair.pd;
    const o = pd.opts;
    const champs = try a.alloc(pp.Champ, site.champs.len);
    for (champs, site.champs) |*c, ch| c.* = .{ .name = ch.name, .key = ch.key, .slug = ch.slug };

    var changes: std.ArrayList(pp.Change) = .empty;
    // By champs index: its Change's
    const changed = try a.alloc(?u16, site.champs.len);
    @memset(changed, null);
    if (pair.notes) |n| {
        for (n.champions) |c| {
            const i = index(site, c.id) orelse continue;
            changed[i] = @intCast(changes.items.len);
            try changes.append(a, try change(a, c, i));
        }
    }

    var rows: std.ArrayList(pp.Row) = .empty;
    for (pd.champions) |m| try addRow(site, pd, &rows, m, changed);
    // A champion Riot changed with too few games yet for a role: its main one
    for (pd.thin) |m| {
        const i = index(site, m.id) orelse continue;
        if (changed[i] != null) try addRow(site, pd, &rows, m, changed);
    }
    std.mem.sort(pp.Row, rows.items, {}, struct {
        fn f(_: void, x: pp.Row, y: pp.Row) bool {
            return points(x.prev, x.cur) > points(y.prev, y.cur);
        }
    }.f);

    const older, const newer = try nav(site, pair);
    var d: pp.Data = .{
        .cur_patch = pd.cur_patch,
        .prev_patch = pd.prev_patch,
        .older = older,
        .newer = newer,
        .finished = pair.older != null,
        .games = pd.cur_games,
        .min_games = o.min_role_games,
        .lane_minute = core.curvesfile.lane_minute,
        .ddragon = site.ddragon_version,
        .patch_dir = (html.View{ .region = site.view.region, .period = .patch }).dir(),
        .notes = try patchnotes.officialUrl(a, pd.cur_patch) orelse "",
        .riot = pair.notes != null,
        .champs = champs,
        .changes = changes.items,
        .rows = rows.items,
    };
    try riot(site, &d, pair);
    return d;
}

fn addRow(site: *const Site, pd: *const PatchDay, rows: *std.ArrayList(pp.Row), m: patchday.ChampionMove, changed: []const ?u16) !void {
    const o = pd.opts;
    const i = index(site, m.id) orelse return;
    const lane: ?pp.Lane = if (m.ahead) |x| (if (x.prev.games > 0 and x.cur.games > 0) .{
        .prev = count(x.prev),
        .cur = count(x.cur),
        .clear = x.clear(o.min_role_games, o.z),
    } else null) else null;
    try rows.append(site.arena, .{
        .champ = i,
        .role = role(m.role),
        .prev = count(m.win.prev),
        .cur = count(m.win.cur),
        .clear = m.win.clear(o.min_role_games, o.z),
        .lane = lane,
        .change = changed[i],
        .moves = try moves(site, pd, m.id, m.role),
    });
}

/// `id`'s matchups in `r` with enough games on both patches, from its side: those whose
/// win rate or gold lead moved clearly, then the biggest other win rate moves up to
/// max_moves; biggest first within each
fn moves(site: *const Site, pd: *const PatchDay, id: u32, r: Role) ![]const pp.Move {
    const a = site.arena;
    const o = pd.opts;
    const me = matchup.champ(site, id) orelse return &.{};
    var all: std.ArrayList(pp.Move) = .empty;
    for (pd.matchups) |m| {
        if (m.role != r or (m.a != id and m.b != id)) continue;
        const x = pd.matchup(r, id, if (m.a == id) m.b else m.a).?;
        const clear = x.win.clear(o.min_pair_games, o.z);
        if (!x.win.enough(o.min_pair_games) and x.gold == null) continue;
        const them = matchup.champ(site, x.b) orelse continue;
        try all.append(a, .{
            .them = index(site, x.b) orelse continue,
            .prev = count(x.win.prev),
            .cur = count(x.win.cur),
            .clear = clear,
            .gold = if (x.gold) |g| .{ .minute = g.minute, .prev = g.prev, .cur = g.cur, .games = g.cur_n } else null,
            .path = try matchup.path(a, r, me, them),
        });
    }
    std.mem.sort(pp.Move, all.items, {}, struct {
        fn f(_: void, x: pp.Move, y: pp.Move) bool {
            const mx = x.clear or x.gold != null;
            const my = y.clear or y.gold != null;
            if (mx != my) return mx;
            return @abs(points(x.prev, x.cur)) > @abs(points(y.prev, y.cur));
        }
    }.f);
    var n: usize = 0;
    while (n < all.items.len and (all.items[n].clear or all.items[n].gold != null)) n += 1;
    return all.items[0..@min(all.items.len, @max(n, max_moves))];
}

fn points(a: pp.Count, b: pp.Count) f64 {
    const s = struct {
        fn f(c: pp.Count) f64 {
            return @as(f64, @floatFromInt(c[1])) / @as(f64, @floatFromInt(@max(c[0], 1)));
        }
    }.f;
    return s(b) - s(a);
}

/// The champion's place in site.champs (pp.Data.champs)
fn index(site: *const Site, id: u32) ?u16 {
    const c = site.stats.index(id) orelse return null;
    return @intCast(site.by_c[c] orelse return null);
}

fn role(r: Role) pp.Role {
    return @fromBackingInt(@as(u8, @backingInt(r)));
}

fn count(c: core.curvesfile.Counts) pp.Count {
    return .{ c.games, c.wins };
}

fn change(a: std.mem.Allocator, c: patchnotes.Change, id: u32) !pp.Change {
    const lines = try a.alloc(ui.changeline.Line, c.lines.len);
    for (lines, c.lines) |*l, x| l.* = try line(a, x);
    return .{
        .id = id,
        .name = c.name,
        .status = switch (c.status) {
            inline else => |s| @field(pp.Status, @tagName(s)),
        },
        .tone = switch (c.dir()) {
            .buff => .buff,
            .nerf => .nerf,
            else => .adjusted,
        },
        .slots = try c.slots(a),
        .lines = lines,
    };
}

/// The items and runes Riot changed, each with who uses it most in this patch view's
/// builds file (the newest pair's only: the builds are the current patch's)
fn riot(site: *const Site, d: *pp.Data, pair: Pair) !void {
    const n = pair.notes orelse return;
    const a = site.arena;
    const view_builds = site.view_builds[(html.View{ .region = site.view.region, .period = .patch }).index()];
    const f = if (pair.older != null) null else if (view_builds) |*b| b else null;
    const champs = try a.alloc(?u16, if (f) |b| b.builds.len else 0);
    if (f) |b| for (champs, b.builds) |*c, x| {
        c.* = index(site, x.champion);
    };
    const items = try a.alloc(pp.Kit, n.items.len);
    for (items, n.items) |*k, c| k.* = .{
        .change = try change(a, c, c.id),
        // A gone item has no image in the new version: art's placeholder
        .icon = if (c.status == .gone) "" else try a.print("https://ddragon.leagueoflegends.com/cdn/{s}/img/item/{d}.png", .{ d.ddragon, c.id }),
        .users = if (f) |b| try users(a, d, b, champs, c.id, false) else &.{},
    };
    const runes = try a.alloc(pp.Kit, n.runes.len);
    for (runes, n.runes) |*k, c| k.* = .{
        .change = try change(a, c, c.id),
        .icon = if (c.icon.len > 0) try a.print("https://ddragon.leagueoflegends.com/cdn/img/{s}", .{c.icon}) else "",
        .users = if (f) |b| try users(a, d, b, champs, c.id, true) else &.{},
    };
    d.items = items;
    d.runes = runes;
}

/// The champion roles with the biggest share of players using item or rune `id`, among
/// those with the page's games. `champs`: each of f.builds' champion as a Data.champs
/// index
fn users(a: std.mem.Allocator, d: *const pp.Data, f: *const builds.File, champs: []const ?u16, id: u32, rune: bool) ![]const pp.User {
    var all: std.ArrayList(pp.User) = .empty;
    for (f.builds, champs) |b, champ| {
        if (b.games < d.min_games) continue;
        const sh = (if (rune) runeShare(b, id) else itemShare(b, id)) orelse continue;
        const c = champ orelse continue;
        const r = role(b.role);
        const row: ?u16 = for (d.rows, 0..) |x, i| {
            if (x.champ == c and x.role == r) break @intCast(i);
        } else null;
        try all.append(a, .{ .champ = c, .role = r, .share = @floatCast(sh), .row = row });
    }
    std.mem.sort(pp.User, all.items, {}, struct {
        fn more(_: void, x: pp.User, y: pp.User) bool {
            return x.share > y.share;
        }
    }.more);
    return all.items[0..@min(all.items.len, max_users)];
}

/// Of `b`'s players, those with `item` as boots, in their start or in their first three
/// finished items. A file keeps only the commonest starts and first threes, so it is a
/// floor where the builds vary
fn itemShare(b: builds.File.Build, item: u32) ?f64 {
    var best: ?f64 = null;
    for ([_]builds.Kind{ .boots, .start, .core3 }) |k| {
        const rows = b.get(k) orelse continue;
        var with: u64 = 0;
        for (rows.options) |o| {
            if (std.mem.findScalar(u32, o.v, item) != null) with += o.games;
        }
        if (with == 0) continue;
        best = @max(best orelse 0, @as(f64, @floatFromInt(with)) / @as(f64, @floatFromInt(@max(rows.games, 1))));
    }
    return best;
}

/// Of `b`'s players, those with `rune` on their page
fn runeShare(b: builds.File.Build, rune: u32) ?f64 {
    const rows = b.get(.rune) orelse return null;
    for (rows.options) |o| if (o.v.len > 0 and o.v[0] == rune) {
        return @as(f64, @floatFromInt(o.games)) / @as(f64, @floatFromInt(@max(rows.games, 1)));
    };
    return null;
}

/// ChangeLine's: the slot's key, and what it is ("Decimate cooldown"; a stat's name; the
/// spell's name when its words changed or Data Dragon lost its numbers; "" for a text
/// hunk)
fn line(a: std.mem.Allocator, l: patchnotes.Line) !ui.changeline.Line {
    const key: []const u8 = switch (l.slot) {
        .p => "P",
        .q => "Q",
        .w => "W",
        .e => "E",
        .r => "R",
        .stats, .gold, .text => "",
    };
    const words = l.dir == .text or l.dir == .blanked;
    const label = if (words)
        (if (l.spell.len > 0) l.spell else l.field)
    else if (l.field.len > 0 and l.spell.len > 0)
        try std.mem.concat(a, u8, &.{ l.spell, " ", try lowerFirst(a, l.field) })
    else
        l.field;
    return .{
        .key = key,
        .label = label,
        .before = l.before,
        .old = l.old,
        .new = l.new,
        .after = l.after,
        .dir = switch (l.dir) {
            inline else => |x| @field(ui.changeline.Dir, @tagName(x)),
        },
    };
}

/// "Cooldown" "cooldown"; "AD ratio" and "W on hit damage" kept
fn lowerFirst(a: std.mem.Allocator, s: []const u8) ![]const u8 {
    if (s.len < 2 or !std.ascii.isLower(s[1])) return s;
    const out = try a.dupe(u8, s);
    out[0] = std.ascii.toLower(out[0]);
    return out;
}

test "lowerFirst: short words as they are" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    for ([_][2][]const u8{ .{ "", "" }, .{ "A", "A" }, .{ "AD ratio", "AD ratio" }, .{ "Base damage", "base damage" } }) |c| {
        try std.testing.expectEqualStrings(c[1], try lowerFirst(a, c[0]));
    }
}

test "line: labels and keys" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const q = try line(a, .{ .slot = .q, .spell = "Decimate", .field = "Cooldown", .old = "9", .new = "8", .dir = .buff });
    try std.testing.expectEqualStrings("Q", q.key);
    try std.testing.expectEqualStrings("Decimate cooldown", q.label);
    const ratio = try line(a, .{ .slot = .q, .spell = "Piercing Arrow", .field = "AD ratio", .old = "120%", .new = "136%", .dir = .buff });
    try std.testing.expectEqualStrings("Piercing Arrow AD ratio", ratio.label);
    const hp = try line(a, .{ .slot = .stats, .field = "Health", .old = "630", .new = "610", .dir = .nerf });
    try std.testing.expectEqualStrings("Health", hp.label);
    const lost = try line(a, .{ .slot = .q, .spell = "Piercing Arrow", .field = "Numbers", .dir = .blanked });
    try std.testing.expectEqualStrings("Piercing Arrow", lost.label);
    const hunk = try line(a, .{ .slot = .p, .spell = "Hemorrhage", .before = "Bleeds for", .old = "5", .new = "4", .dir = .adjusted });
    try std.testing.expectEqualStrings("", hunk.label);
    try std.testing.expectEqualStrings("P", hunk.key);
}

test "itemShare and runeShare: of every player with boots, a first three, runes" {
    const b: builds.File.Build = .{ .champion = 122, .role = .top, .games = 1000, .wins = 500, .kinds = &.{
        .{ .kind = .boots, .games = 900, .wins = 450, .options = &.{ .{ .v = &.{3047}, .games = 450, .wins = 230 }, .{ .v = &.{3111}, .games = 300, .wins = 150 } } },
        .{ .kind = .core3, .games = 800, .wins = 400, .options = &.{ .{ .v = &.{ 6630, 3053, 3071 }, .games = 300, .wins = 160 }, .{ .v = &.{ 6630, 3071, 3065 }, .games = 100, .wins = 50 }, .{ .v = &.{ 3078, 3053, 3065 }, .games = 100, .wins = 50 } } },
        .{ .kind = .rune, .games = 1000, .wins = 500, .options = &.{.{ .v = &.{8010}, .games = 700, .wins = 360 }} },
    } };
    try std.testing.expectEqual(@as(?f64, 0.5), itemShare(b, 3047));
    try std.testing.expectEqual(@as(?f64, 0.5), itemShare(b, 6630));
    try std.testing.expectEqual(@as(?f64, 0.5), itemShare(b, 3071));
    try std.testing.expectEqual(@as(?f64, null), itemShare(b, 1054));
    try std.testing.expectEqual(@as(?f64, 0.7), runeShare(b, 8010));
    try std.testing.expectEqual(@as(?f64, null), runeShare(b, 8005));
}

test "users: by share, top max_users, enough games, a row only for a listed role" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const T = struct {
        fn build(comptime champion: u32, comptime r: Role, comptime games: u32, comptime with: u32) builds.File.Build {
            return .{ .champion = champion, .role = r, .games = games, .wins = games / 2, .kinds = &.{
                .{ .kind = .core3, .games = games, .wins = games / 2, .options = &.{.{ .v = &.{ 3031, 3006 }, .games = with, .wins = with / 2 }} },
            } };
        }
    };
    // demo's rows: champ 1 bottom is row 1, champ 4 bottom row 5; champ 0 plays top only
    const f: builds.File = .{
        .label = "16.21",
        .min_tier = "PLATINUM",
        .games = 0,
        .timelines = 0,
        .items = &.{},
        .runes = &.{},
        .spells = &.{},
        .builds = &.{
            T.build(10, .bottom, 1000, 500),
            T.build(20, .bottom, 500, 100),
            T.build(30, .jungle, 400, 300),
            // Not a champion of the page
            T.build(40, .top, 2000, 2000),
            // Under min_games
            T.build(50, .bottom, 200, 180),
            // Fourth by share
            T.build(60, .middle, 900, 90),
        },
    };
    const champs = [_]?u16{ 1, 4, 0, null, 3, 2 };
    const got = try users(a, &pp.demo, &f, &champs, 3031, false);
    try std.testing.expectEqualDeep(&[_]pp.User{
        .{ .champ = 0, .role = .jungle, .share = 0.75, .row = null },
        .{ .champ = 1, .role = .bottom, .share = 0.5, .row = 1 },
        .{ .champ = 4, .role = .bottom, .share = 0.2, .row = 5 },
    }, got);
    try std.testing.expectEqual(0, (try users(a, &pp.demo, &f, &champs, 1001, false)).len);
}
