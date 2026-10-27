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
const daily_page = @import("daily.zig");
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
/// Draft puzzles and their page data), copied into `a`: every view's home shows them
pub fn files(a: Allocator, all: []const root.File) ![]const root.File {
    var out: std.ArrayList(root.File) = .empty;
    for (all) |f| if (std.mem.startsWith(u8, f.path, your_dir) or isPuzzle(f.path)) {
        try out.append(a, .{ .path = try a.dupe(u8, f.path), .data = try a.dupe(u8, f.data) });
    };
    return out.items;
}

/// daily/<n>.json or daily/<n>.bin, not the index
fn isPuzzle(path: []const u8) bool {
    if (!std.mem.startsWith(u8, path, "daily/") or std.mem.endsWith(u8, path, "index.json")) return false;
    return std.mem.endsWith(u8, path, ".json") or std.mem.endsWith(u8, path, ".bin");
}

fn reviewOf(site: *const Site, up: []const u8) !?*hp.HomeReview {
    return reviewFor(site.arena, site.daily_files, up);
}

/// The default role's newest game (the first data/your/<role>.bin); null without the
/// example or games
fn reviewFor(a: Allocator, all: []const root.File, up: []const u8) !?*hp.HomeReview {
    var roles: [5]bool = @splat(false);
    var first: ?root.File = null;
    var default: ui.role.Role = .mid;
    for (all) |f| {
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
    d.* = ui.data.decode(a, gd.Data, f.data) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            log.warn("home: {s}: {t}", .{ f.path, err });
            return null;
        },
    };
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

fn dailyOf(site: *const Site, up: []const u8) !?*hp.HomeDaily {
    return dailyFor(site.arena, site.daily_files, daily_page.todayNumber(site.io), up, site, champOf);
}

/// The Daily page's puzzle (daily_page.pick) on or before puzzle `today`; null without one
fn dailyFor(
    a: Allocator,
    all: []const root.File,
    today: u32,
    up: []const u8,
    ctx: anytype,
    champ: fn (@TypeOf(ctx), u32) anyerror!?ui.champ.Champ,
) !?*hp.HomeDaily {
    const got = try daily_page.pick(a, all, today) orelse return null;
    const json = got.json orelse return null;
    const pz = std.json.parseFromSliceLeaky(daily.Puzzle, a, json, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            // dailydata.files says so too
            log.info("home: puzzle {d}: {t}", .{ got.n, err });
            return null;
        },
    };
    const d = try a.create(hp.Daily);
    d.* = .{ .n = pz.n, .href = try std.mem.concat(a, u8, &.{ up, "daily.html" }) };
    for (0..2) |side| for (0..5) |i| {
        const hidden = side == pz.hidden_team and i == @backingInt(pz.hidden_role);
        d.teams[side][i] = if (hidden) null else try champ(ctx, pz.teams[side][i]);
    };
    const x = try a.create(hp.HomeDaily);
    x.* = .{ .data = d, .bin = try bin(a, hp.Daily, d.*) };
    return x;
}

fn champOf(site: *const Site, id: u32) anyerror!?ui.champ.Champ {
    for (site.champs) |ch| if (ch.id == id) return .{ .name = ch.name, .src = try site.icon(ch) };
    return null;
}

/// The biggest clear win rate moves since the last patch, up then down; the link alone
/// without them (the box's core build loads no patch day); null on a patch's first day
fn patchCard(site: *const Site, h: *ui.H, up: []const u8) !?ui.N {
    const a = site.arena;
    const pd = site.patchday orelse {
        const prev = site.opts.prev_patch orelse return null;
        return ui.today.view(h, try patchHead(a, up, site.patch, prev), null, .none);
    };
    const moves = try biggest(a, pd.champions, pd.opts);
    const head = try patchHead(a, up, pd.cur_patch, pd.prev_patch);
    if (moves.len == 0) return ui.today.view(h, head, null, .none);
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
    return ui.today.view(h, head, null, ui.today.changes(h, rows.items));
}

fn patchHead(a: Allocator, up: []const u8, cur: []const u8, prev: []const u8) !ui.today.Head {
    return .{
        .title = .{ .s = try a.print("Patch {s}", .{cur}) },
        .count = .{ .s = try a.print("vs {s}", .{prev}) },
        .action = ui.plain("All changes"),
        .href = try std.mem.concat(a, u8, &.{ up, "patch/", patch_page.path }),
    };
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
    const counts = try a.alloc(u32, site.champs.len);
    for (Role.all, &d.roles) |r, *out| {
        for (site.champs, counts) |ch, *n| n.* = site.stats.champRole(r, ch.c).games;
        var picks: std.ArrayList(hp.Champs.Pick) = .empty;
        for (mostPlayed(counts)) |b| {
            const ch = site.champs[b orelse break];
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

/// Indexes of the per_role largest counts, largest first, the earlier on a tie; none
/// with no games
fn mostPlayed(counts: []const u32) [per_role]?usize {
    var best: [per_role]?usize = @splat(null);
    var games: [per_role]u32 = @splat(0);
    for (counts, 0..) |n, k| {
        var i: usize = per_role;
        while (i > 0 and n > games[i - 1]) i -= 1;
        if (i == per_role) continue;
        std.mem.copyBackwards(?usize, best[i + 1 ..], best[i .. per_role - 1]);
        std.mem.copyBackwards(u32, games[i + 1 ..], games[i .. per_role - 1]);
        best[i] = k;
        games[i] = n;
    }
    return best;
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

test "home's files: the example's and the puzzles with their page data, not the index" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const all = [_]root.File{
        .{ .path = "data/your/mid.bin", .data = "m" },
        .{ .path = "daily/index.json", .data = "[]" },
        .{ .path = "daily/7.json", .data = "{}" },
        .{ .path = "daily/7.bin", .data = "b" },
        .{ .path = "learn/1.json", .data = "{}" },
        .{ .path = "data/stats.bin", .data = "s" },
    };
    const got = try files(arena.allocator(), &all);
    try std.testing.expectEqual(3, got.len);
    try std.testing.expectEqualStrings("data/your/mid.bin", got[0].path);
    try std.testing.expectEqualStrings("daily/7.json", got[1].path);
    try std.testing.expectEqualStrings("daily/7.bin", got[2].path);
}

test "the Daily card: the newest puzzle up to today, the hidden seat empty" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const names = struct {
        fn f(_: void, id: u32) anyerror!?ui.champ.Champ {
            const all = [_][]const u8{ "", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J" };
            return if (id < all.len) .{ .name = all[id], .src = "" } else null;
        }
    }.f;
    var p: daily.Puzzle = .{
        .n = 7,
        .date = "2026-10-17",
        .patch = "16.20",
        .tier = null,
        .games = 1000,
        .teams = .{ .{ 1, 2, 3, 4, 5 }, .{ 6, 7, 8, 99, 10 } },
        .bans = .{ &.{}, &.{} },
        .hidden_team = 1,
        .hidden_role = .middle,
        .played = 8,
        .options = &.{},
        .winner = 0,
        .minutes = 31,
        .kills = .{ 20, 12 },
        .gold = .{ 60000, 52000 },
        .lanes = @splat(.{ .pp = 0, .games = 0 }),
    };
    const seven = try std.json.Stringify.valueAlloc(a, p, .{});
    p.n = 9;
    const all = [_]root.File{
        .{ .path = "daily/7.json", .data = seven },
        .{ .path = "daily/8.json", .data = "{\"n\":" },
        .{ .path = "daily/9.json", .data = try std.json.Stringify.valueAlloc(a, p, .{}) },
    };
    const d = (try dailyFor(a, &all, 7, "../", {}, names)).?.data;
    try std.testing.expectEqual(7, d.n);
    try std.testing.expectEqualStrings("../daily.html", d.href);
    try std.testing.expectEqualStrings("A", d.teams[0][0].?.name);
    try std.testing.expectEqualStrings("J", d.teams[1][4].?.name);
    // Red's mid hidden; an id the site doesn't know empty too
    try std.testing.expectEqual(null, d.teams[1][2]);
    try std.testing.expectEqual(null, d.teams[1][3]);
    // Today's (8) unreadable: no card
    try std.testing.expectEqual(null, try dailyFor(a, &all, 8, "", {}, names));
    try std.testing.expectEqual(9, (try dailyFor(a, &all, 30, "", {}, names)).?.data.n);
    try std.testing.expectEqual(null, try dailyFor(a, &all, 6, "", {}, names));
}

test "the example's game: none without a role file or games" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var empty: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, gd.Data, .{ .champs = &.{}, .games = &.{} }, &empty);
    const list = [_]root.File{.{ .path = your_dir ++ "list.bin", .data = "x" }};
    try std.testing.expectEqual(null, try reviewFor(a, &list, ""));
    const none = [_]root.File{ list[0], .{ .path = your_dir ++ "top.bin", .data = empty.items } };
    try std.testing.expectEqual(null, try reviewFor(a, &none, ""));
}

test "most played: largest first, the earlier on a tie, none without games" {
    try std.testing.expectEqual([per_role]?usize{ 2, 0, 3, 5, 1 }, mostPlayed(&.{ 50, 10, 90, 50, 0, 20, 5 }));
    try std.testing.expectEqual([per_role]?usize{ 1, null, null, null, null }, mostPlayed(&.{ 0, 3, 0 }));
    try std.testing.expectEqual([per_role]?usize{ null, null, null, null, null }, mostPlayed(&.{}));
}
