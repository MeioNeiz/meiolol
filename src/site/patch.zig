//! patch.html in every view: the current patch against the one before (src/patchday.zig)
//! in the view's region, whole patches whatever its period, with what Riot changed
//! (src/patchnotes.zig). The ui.patchpage island, its data in the view's data/patch.bin

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
const MatchupMove = patchday.MatchupMove;
const Rate = patchday.Rate;
const Role = core.Role;

pub const path = "patch.html";

/// The island's data file, in each view's directory
pub const data_path = "data/patch.bin";

/// A row's matchup moves in its detail
const max_moves = 3;
/// A changed item's or rune's champions
const max_users = 3;

comptime {
    for (Role.all, 0..) |r, i| std.debug.assert(std.mem.eql(u8, r.label(), pp.Role.slugs[i]));
    std.debug.assert(pp.pair_games == (patchday.Options{}).min_pair_games);
    std.debug.assert(pp.z == (patchday.Options{}).z);
    // change() and line() map by name, so equal counts mean the same fields both ways
    std.debug.assert(std.enums.values(patchnotes.Dir).len == std.enums.values(ui.changeline.Dir).len);
    std.debug.assert(std.enums.values(patchnotes.Status).len == std.enums.values(pp.Status).len);
}

pub fn writePage(site: *const Site, w: *Writer) !void {
    const a = site.arena;
    const pd = site.patchday orelse {
        const pg = try site.page("Patch changes | meiolol", "How champions and lane matchups changed from the previous patch.", path, .patch);
        try html.head(w, pg);
        try tpl.render(w, "<h1>Patch changes</h1>\n<p>No earlier patch in the data yet to compare with.</p>\n", .{});
        return html.foot(w, pg);
    };
    const pg = try site.page(
        try a.print("Patch {s} vs {s}: what changed | meiolol", .{ pd.cur_patch, pd.prev_patch }),
        try a.print("What Riot changed in patch {s}, next to how each champion's and lane matchup's win rate moved from {s}, with the games behind each.", .{ pd.cur_patch, pd.prev_patch }),
        path,
        .patch,
    );
    try html.head(w, pg);
    const d = try a.create(pp.Data);
    d.* = try data(site, &pd);
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, pp.Data, d.*, &bytes);
    const to_root = try site.toRoot(path);
    const base = try std.mem.concat(a, u8, &.{ to_root, site.view.up() });
    var p: pp.Page = .init(d, try pp.prepare(a, d, base));
    p.base = base;
    p.src = try std.mem.concat(a, u8, &.{ to_root, data_path });
    p.stamp = pp.stamp(bytes.items);
    var tree: ui.Tree = .{};
    var h: ui.H = .init(a, &tree);
    tree.root = p.view(&h);
    if (h.oom) return error.OutOfMemory;
    try root.roleIcons(w);
    try ui.html.write(&tree, tree.root, w);
    if (pp.riotView(&h, d, try riot(site, d), base)) |n| try ui.html.write(&tree, n, w);
    if (h.oom) return error.OutOfMemory;
    try tpl.render(w, "\n<script src=\"{js}\" data-wasm=\"{wasm}\" defer></script>\n", .{
        .js = html.Link{ .root = to_root, .up = site.view.up(), .path = assets.patch_js.path },
        .wasm = assets.patch_wasm.path,
    });
    try html.foot(w, pg);
}

/// data/patch.bin; null without a patch day
pub fn dataFile(site: *const Site) !?[]const u8 {
    const pd = site.patchday orelse return null;
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(site.arena, pp.Data, try data(site, &pd), &out);
    return out.items;
}

fn data(site: *const Site, pd: *const PatchDay) !pp.Data {
    const a = site.arena;
    const o = pd.opts;
    const champs = try a.alloc(pp.Champ, site.champs.len);
    for (champs, site.champs) |*c, ch| c.* = .{ .name = ch.name, .key = ch.key, .slug = ch.slug };

    var changes: std.ArrayList(pp.Change) = .empty;
    // By champs index: its Change's
    const changed = try a.alloc(?u16, site.champs.len);
    @memset(changed, null);
    if (site.notes) |n| {
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

    var mus: std.ArrayList(pp.Matchup) = .empty;
    for (pd.matchups) |m| {
        const win_clear = m.win.clear(o.min_pair_games, o.z);
        if (m.gold == null and !win_clear) continue;
        const up = if (win_clear) m.win.z > 0 else m.gold.?.cur > m.gold.?.prev;
        const x = if (up) m else pd.matchup(m.role, m.b, m.a).?;
        const ca = matchup.champ(site, x.a) orelse continue;
        const cb = matchup.champ(site, x.b) orelse continue;
        try mus.append(a, .{
            .role = role(x.role),
            .a = index(site, x.a).?,
            .b = index(site, x.b).?,
            .prev = count(x.win.prev),
            .cur = count(x.win.cur),
            .clear = win_clear,
            .gold = if (x.gold) |g| .{ .minute = g.minute, .prev = g.prev, .cur = g.cur, .games = g.cur_n } else null,
            .path = try matchup.path(a, x.role, ca, cb),
        });
    }
    std.mem.sort(pp.Matchup, mus.items, {}, struct {
        fn f(_: void, x: pp.Matchup, y: pp.Matchup) bool {
            return points(x.prev, x.cur) > points(y.prev, y.cur);
        }
    }.f);

    return .{
        .cur_patch = pd.cur_patch,
        .prev_patch = pd.prev_patch,
        .games = pd.cur_games,
        .min_games = o.min_role_games,
        .lane_minute = core.curvesfile.lane_minute,
        .ddragon = site.ddragon_version,
        .patch_dir = (html.View{ .region = site.view.region, .period = .patch }).dir(),
        .notes = try patchnotes.officialUrl(a, pd.cur_patch) orelse "",
        .riot = site.notes != null,
        .champs = champs,
        .changes = changes.items,
        .rows = rows.items,
        .matchups = mus.items,
    };
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

/// `id`'s biggest win rate moves in `r` among matchups with enough games on both
/// patches, from its side
fn moves(site: *const Site, pd: *const PatchDay, id: u32, r: Role) ![]const pp.Move {
    const o = pd.opts;
    var best: [max_moves]?MatchupMove = @splat(null);
    for (pd.matchups) |m| {
        if (m.role != r or (m.a != id and m.b != id)) continue;
        if (!m.win.enough(o.min_pair_games)) continue;
        const x = pd.matchup(r, id, if (m.a == id) m.b else m.a).?;
        const by = @abs(x.win.delta());
        var at: usize = best.len;
        while (at > 0) : (at -= 1) {
            const y = best[at - 1] orelse continue;
            if (@abs(y.win.delta()) >= by) break;
        }
        if (at == best.len) continue;
        var k = best.len - 1;
        while (k > at) : (k -= 1) best[k] = best[k - 1];
        best[at] = x;
    }
    var out: std.ArrayList(pp.Move) = .empty;
    for (best) |x| if (x) |m| {
        const them = index(site, m.b) orelse continue;
        try out.append(site.arena, .{ .them = them, .prev = count(m.win.prev), .cur = count(m.win.cur), .clear = m.win.clear(o.min_pair_games, o.z) });
    };
    return out.items;
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
/// builds file
fn riot(site: *const Site, d: *const pp.Data) !pp.Riot {
    const n = site.notes orelse return .{ .items = &.{}, .runes = &.{} };
    const a = site.arena;
    const f = &site.view_builds[(html.View{ .region = site.view.region, .period = .patch }).index()];
    const items = try a.alloc(pp.Kit, n.items.len);
    for (items, n.items) |*k, c| k.* = .{
        .change = try change(a, c, c.id),
        .icon = try a.print("https://ddragon.leagueoflegends.com/cdn/{s}/img/item/{d}.png", .{ d.ddragon, c.id }),
        .users = if (f.*) |*b| try users(site, d, b, c.id, false) else &.{},
    };
    const runes = try a.alloc(pp.Kit, n.runes.len);
    for (runes, n.runes) |*k, c| k.* = .{
        .change = try change(a, c, c.id),
        .icon = if (c.icon.len > 0) try a.print("https://ddragon.leagueoflegends.com/cdn/img/{s}", .{c.icon}) else "",
        .users = if (f.*) |*b| try users(site, d, b, c.id, true) else &.{},
    };
    return .{ .items = items, .runes = runes };
}

/// The champion roles with the biggest share of players using item or rune `id`, among
/// those with the page's games
fn users(site: *const Site, d: *const pp.Data, f: *const builds.File, id: u32, rune: bool) ![]const pp.User {
    var all: std.ArrayList(pp.User) = .empty;
    for (f.builds) |b| {
        if (b.games < d.min_games) continue;
        const sh = (if (rune) runeShare(b, id) else itemShare(b, id)) orelse continue;
        const c = index(site, b.champion) orelse continue;
        const r = role(b.role);
        const row: ?u16 = for (d.rows, 0..) |x, i| {
            if (x.champ == c and x.role == r) break @intCast(i);
        } else null;
        try all.append(site.arena, .{ .champ = c, .role = r, .share = @floatCast(sh), .row = row });
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
        try std.mem.concat(a, u8, &.{ l.spell, " ", try std.ascii.allocLowerString(a, l.field) })
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

test "line: labels and keys" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const q = try line(a, .{ .slot = .q, .spell = "Decimate", .field = "Cooldown", .old = "9", .new = "8", .dir = .buff });
    try std.testing.expectEqualStrings("Q", q.key);
    try std.testing.expectEqualStrings("Decimate cooldown", q.label);
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
