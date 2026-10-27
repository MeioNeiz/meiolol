//! The home page (index.html): ui.homepage's islands from the example's games
//! (data/your/<role>.bin, site/yourgame.zig), today's Daily Draft, the patch's biggest
//! win rate moves and each role's most played. Not a stats page, so no region or period
//! switches

const std = @import("std");
const ui = @import("ui");
const core = @import("core");
const html = @import("html.zig");
const assets = @import("assets.zig");
const daily = @import("../daily.zig");
const patchday = @import("../patchday.zig");
const patch_page = @import("patch.zig");
const champion = @import("champion.zig");
const yourgame = @import("yourgame.zig");
const root = @import("root.zig");

const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Site = root.Site;
const Champ = root.Champ;
const Role = core.Role;
const hp = ui.homepage;
const gd = ui.gamedata;
const log = std.log.scoped(.site);

const your_dir = hp.your_dir;
/// Champions per role
const per_role = 5;
/// Patch moves each way
const per_way = 3;

pub fn writeIndex(site: *const Site, w: *Writer) !void {
    const a = site.arena;
    var p = try site.page(
        "meiolol: game review for League of Legends",
        "Look yourself up: every recent game reviewed like a chess game. Your team's win chance minute by minute, the moments that moved it, what each death cost, and your lane against the typical game at your rank. Free, no sign-up.",
        "index.html",
        .home,
    );
    p.counterparts = null;
    try html.head(w, p);
    const up = site.view.up();

    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    var look: ui.idlookup.IdLookup = .{ .to = try std.mem.concat(a, u8, &.{ up, "your.html" }) };
    const review: ui.N = if (try reviewOf(site, up)) |r| r.view(&h) else .none;
    var cards: std.ArrayList(ui.N) = .empty;
    if (try dailyOf(site, up)) |d| try cards.append(a, d.view(&h));
    if (try patchCard(site, &h, up)) |n| try cards.append(a, n);
    const champs: ui.N = if (try champsOf(site, up)) |c| c.view(&h) else .none;
    t.root = hp.page(&h, look.view(&h), review, cards.items, champs);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    try html.tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{
        .js = html.Link{ .root = up, .path = assets.home_js.path },
        .wasm = assets.home_wasm.path,
    });
    try html.foot(w, p);
}

comptime {
    std.debug.assert(std.mem.eql(u8, hp.game_page, yourgame.page_path));
}

/// Of the shared view's daily_files, those home reads (the example's games, the Daily
/// Draft puzzles), copied into `a`: every view's home shows them
pub fn files(a: Allocator, all: []const root.File) ![]const root.File {
    var out: std.ArrayList(root.File) = .empty;
    for (all) |f| if (std.mem.startsWith(u8, f.path, your_dir) or isPuzzle(f.path)) {
        try out.append(a, .{ .path = try a.dupe(u8, f.path), .data = try a.dupe(u8, f.data) });
    };
    return out.items;
}

/// daily/<n>.json, not its index or daily/<n>.bin
fn isPuzzle(path: []const u8) bool {
    return std.mem.startsWith(u8, path, "daily/") and std.mem.endsWith(u8, path, ".json") and !std.mem.endsWith(u8, path, "index.json");
}

/// Today's (UTC) puzzle number; daily.update makes a few days ahead
pub fn todayPuzzle(io: std.Io) u32 {
    const day: u32 = @intCast(@divFloor(std.Io.Clock.real.now(io).toSeconds(), std.time.s_per_day));
    return day - daily.first_day + 1;
}

/// The default role's newest game (the first data/your file); null without the example
fn reviewOf(site: *const Site, up: []const u8) !?*hp.HomeReview {
    const a = site.arena;
    var roles: [5]bool = @splat(false);
    var first: ?root.File = null;
    var default: ui.role.Role = .mid;
    for (site.daily_files) |f| {
        if (!std.mem.startsWith(u8, f.path, your_dir) or !std.mem.endsWith(u8, f.path, ".bin")) continue;
        const r = std.meta.stringToEnum(ui.role.Role, f.path[your_dir.len .. f.path.len - ".bin".len]) orelse continue;
        roles[@backingInt(r)] = true;
        if (first == null) {
            first = f;
            default = r;
        }
    }
    const f = first orelse return null;
    const d = try a.create(gd.Data);
    d.* = try ui.data.decode(a, gd.Data, f.data);
    if (d.games.len == 0) return null;
    const r = try a.create(hp.HomeReview);
    r.* = .{
        .s = try .init(a, d),
        .roles = roles,
        .shown = default,
        .want = default,
        .up = up,
        .default = default,
        .js = try std.mem.concat(a, u8, &.{ up, assets.homegame_js.path }),
        .wasm = assets.homegame_wasm.path,
    };
    r.s.src = try std.mem.concat(a, u8, &.{ up, f.path });
    r.s.stamp = gd.stamp(f.data);
    return r;
}

/// Today's Daily Draft puzzle, else the newest before it; null without one
fn dailyOf(site: *const Site, up: []const u8) !?*hp.HomeDaily {
    const a = site.arena;
    const today = todayPuzzle(site.io);
    var newest: ?struct { n: u32, data: []const u8 } = null;
    for (site.daily_files) |f| {
        if (!isPuzzle(f.path)) continue;
        const n = std.fmt.parseInt(u32, f.path["daily/".len .. f.path.len - ".json".len], 10) catch continue;
        if (n > today) continue;
        if (newest) |b| if (n <= b.n) continue;
        newest = .{ .n = n, .data = f.data };
    }
    const f = newest orelse return null;
    const pz = std.json.parseFromSliceLeaky(daily.Puzzle, a, f.data, .{ .ignore_unknown_fields = true }) catch |err| {
        log.warn("home: puzzle {d}: {t}", .{ f.n, err });
        return null;
    };
    const d = try a.create(hp.Daily);
    d.* = .{ .n = pz.n, .href = try std.mem.concat(a, u8, &.{ up, "daily.html" }) };
    for (0..2) |side| for (0..5) |i| {
        const hidden = side == pz.hidden_team and i == @backingInt(pz.hidden_role);
        d.teams[side][i] = if (hidden) null else try champOf(site, pz.teams[side][i]);
    };
    const x = try a.create(hp.HomeDaily);
    x.* = .{ .data = d, .bin = try bin(a, hp.Daily, d.*) };
    return x;
}

fn champOf(site: *const Site, id: u32) !?ui.champ.Champ {
    for (site.champs) |ch| if (ch.id == id) return .{ .name = ch.name, .src = try site.icon(ch) };
    return null;
}

/// The biggest clear win rate moves since the last patch, up then down
fn patchCard(site: *const Site, h: *ui.H, up: []const u8) !?ui.N {
    const a = site.arena;
    const pd = site.patchday orelse return null;
    const moves = try biggest(a, pd.champions, pd.opts);
    if (moves.len == 0) return null;
    var rows: std.ArrayList(ui.today.Change) = .empty;
    for (moves) |m| {
        const ch = for (site.champs) |c| {
            if (c.id == m.id) break c;
        } else continue;
        const g = m.win.range(1.96);
        try rows.append(a, .{
            .champ = .{ .name = ch.name, .src = try site.icon(ch) },
            .role = champion.uiRole(m.role),
            .href = try champHref(site, up, ch, m.role),
            .from = @floatCast(100 * patchday.Rate.share(m.win.prev)),
            .to = @floatCast(100 * patchday.Rate.share(m.win.cur)),
            .ci = @floatCast((g[1] - g[0]) / 2),
        });
    }
    return ui.today.view(h, .{
        .title = .{ .s = try a.print("Patch {s}", .{pd.cur_patch}) },
        .count = .{ .s = try a.print("vs {s}", .{pd.prev_patch}) },
        .action = ui.plain("All changes"),
        .href = try std.mem.concat(a, u8, &.{ up, "patch/", patch_page.path }),
    }, null, ui.today.changes(h, rows.items));
}

/// The clear moves, the per_way biggest up then the per_way biggest down
fn biggest(a: Allocator, moves: []const patchday.ChampionMove, o: patchday.Options) ![]patchday.ChampionMove {
    var ups: std.ArrayList(patchday.ChampionMove) = .empty;
    var downs: std.ArrayList(patchday.ChampionMove) = .empty;
    for (moves) |m| if (m.win.clear(o.min_role_games, o.z)) {
        try (if (m.win.z > 0) &ups else &downs).append(a, m);
    };
    const by = struct {
        fn f(_: void, x: patchday.ChampionMove, y: patchday.ChampionMove) bool {
            return @abs(x.win.delta()) > @abs(y.win.delta());
        }
    }.f;
    std.mem.sort(patchday.ChampionMove, ups.items, {}, by);
    std.mem.sort(patchday.ChampionMove, downs.items, {}, by);
    return std.mem.concat(a, patchday.ChampionMove, &.{ ups.items[0..@min(per_way, ups.items.len)], downs.items[0..@min(per_way, downs.items.len)] });
}

fn champHref(site: *const Site, up: []const u8, ch: Champ, r: Role) ![]const u8 {
    return site.arena.print("{s}#role={s}", .{ try site.champHref(ch, up), r.label() });
}

/// Each role's most played in the view, with the change since the last patch
fn champsOf(site: *const Site, up: []const u8) !?*hp.HomeChamps {
    const a = site.arena;
    if (site.games == 0) return null;
    const d = try a.create(hp.Champs);
    var champs: std.ArrayList(ui.champ.Champ) = .empty;
    d.* = .{ .champs = &.{}, .games = site.games, .roles = @splat(&.{}) };
    for (Role.all, &d.roles) |r, *out| {
        var best: [per_role]?Champ = @splat(null);
        var games: [per_role]u32 = @splat(0);
        for (site.champs) |ch| {
            const n = site.stats.champRole(r, ch.c).games;
            var i: usize = per_role;
            while (i > 0 and n > games[i - 1]) i -= 1;
            if (i == per_role) continue;
            std.mem.copyBackwards(?Champ, best[i + 1 ..], best[i .. per_role - 1]);
            std.mem.copyBackwards(u32, games[i + 1 ..], games[i .. per_role - 1]);
            best[i] = ch;
            games[i] = n;
        }
        var picks: std.ArrayList(hp.Champs.Pick) = .empty;
        for (best) |b| {
            const ch = b orelse break;
            const cr = site.stats.champRole(r, ch.c);
            try picks.append(a, .{
                .champ = @intCast(champs.items.len),
                .href = try champHref(site, up, ch, r),
                .games = cr.games,
                .wins = cr.wins,
                .share = @floatCast(100 * @as(f64, @floatFromInt(cr.games)) / @as(f64, @floatFromInt(site.games))),
                .d = changeOf(site, ch.id, r),
            });
            try champs.append(a, .{ .name = ch.name, .src = try site.icon(ch) });
        }
        out.* = picks.items;
    }
    d.champs = champs.items;
    const x = try a.create(hp.HomeChamps);
    x.* = .{ .data = d, .bin = try bin(a, hp.Champs, d.*) };
    return x;
}

/// The win rate change since the last patch; null when either patch has too few games
fn changeOf(site: *const Site, id: u32, r: Role) ?f32 {
    const pd = if (site.patchday) |*pd| pd else return null;
    const m = pd.champion(id, r) orelse return null;
    return if (m.win.enough(pd.opts.min_role_games)) @floatCast(m.win.delta()) else null;
}

/// `v` as ui.data, base64: an island root's data-bin
fn bin(a: Allocator, comptime T: type, v: T) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, T, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
}

test "the patch card: clear moves only, biggest first, up to per_way each way" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const o: patchday.Options = .{ .min_role_games = 100 };
    const mv = struct {
        fn f(id: u32, prev: u32, cur: u32, games: u32) patchday.ChampionMove {
            return .{ .id = id, .role = .top, .win = .of(.{ .wins = prev, .games = games }, .{ .wins = cur, .games = games }) };
        }
    }.f;
    const moves = [_]patchday.ChampionMove{
        mv(1, 500, 560, 1000), // +6, fourth up: cut
        mv(2, 500, 600, 1000), // +10
        mv(3, 500, 503, 1000), // not clear
        mv(4, 50, 90, 99), // too few games
        mv(5, 500, 580, 1000), // +8
        mv(6, 500, 570, 1000), // +7
        mv(7, 500, 420, 1000), // -8
    };
    const got = try biggest(arena.allocator(), &moves, o);
    var ids: [4]u32 = undefined;
    for (got, 0..) |m, i| ids[i] = m.id;
    try std.testing.expectEqualSlices(u32, &.{ 2, 5, 6, 7 }, ids[0..got.len]);
}
