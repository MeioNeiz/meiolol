//! Daily Draft: one real ranked solo draft a day, the same for everyone. One slot is
//! hidden behind four options (which was played?), then the guess is the winner. The
//! hidden slot is the pick the rest of the draft explains best (`hideBestFit`). The
//! reveal is what happened and what this patch's numbers say about it, never "the
//! correct pick" (docs/concept.md).
//!
//! Anonymised: puzzles carry no Riot IDs, PUUIDs, match ids or game dates, only
//! champions, bans, patch, a rank tier, game length and team totals. Each puzzle is made
//! once and kept in DIR/daily/<n>.json (public content), its numbers refreshed while its
//! patch is current; DIR/daily/used.txt lists the match ids behind them so none repeats,
//! and is never published.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const Date = @import("date.zig").Date;

const Role = core.Role;
const Stats = core.Stats;
const score = core.score;
const curvesfile = core.curvesfile;

const log = std.log.scoped(.daily);

/// Puzzle #1 is 11 October 2026 (UTC); the number is the day after that
pub const first_day = 20737;
/// Shorter games are mostly early surrenders: little to explain
const min_duration_s = 15 * 60;
/// Each of the ten picks must be this share of its role's games: off-role and rare picks
/// leave every lane row with too few games to say anything. ~37% of games pass (16.20)
const min_role_share = 0.01;
const tries = 64;

pub const Options = struct {
    /// Where puzzles and used.txt live (DIR/daily)
    dir: []const u8,
    patches: []const []const u8,
    platforms: []const []const u8,
    /// Epoch day (UTC) of today
    today: u32,
    /// Puzzles made in advance, so a viewer whose date is ahead of UTC finds theirs
    ahead: u32 = 2,
};

pub const Reason = struct {
    kind: score.Reason.Kind,
    id: u32,
    role: Role,
    pp: f64,
    games: u32,
};

pub const Option = struct {
    id: u32,
    /// Win chance points this champion adds over an average one, in this draft
    pp: f64,
    /// Games on this champion in the hidden role
    games: u32,
    reasons: []const Reason,
};

pub const HiddenBy = enum {
    /// Puzzles made before `hideBestFit`
    random,
    fit,
};

pub const Lane = struct {
    /// Blue's side, percentage points beyond the two champions' own ratings
    pp: f64,
    games: u32,
};

pub const Puzzle = struct {
    n: u32,
    /// The puzzle's day, not the game's
    date: []const u8,
    patch: []const u8,
    /// Median visible rank of the players whose rank we know; null when few are known
    tier: ?[]const u8,
    /// Games behind the numbers
    games: u32,
    /// [blue, red], indexed by role
    teams: [2][5]u32,
    bans: [2][]const u32,
    /// 0 blue, 1 red
    hidden_team: u1,
    hidden_role: Role,
    hidden_by: HiddenBy = .random,
    played: u32,
    /// In display order; one of them is `played`
    options: [4]Option,
    winner: u1,
    minutes: u32,
    kills: [2]u32,
    gold: [2]u32,
    /// Blue's win chance by this patch's numbers, 0..1
    blue_win: f64,
    /// Same-role matchups, indexed by role
    lanes: [5]Lane,
};

pub const File = struct { path: []const u8, data: []const u8 };

/// Makes any missing puzzle up to today + ahead, then returns the site files: every
/// puzzle up to that day as daily/<n>.json and daily/index.json listing them. A puzzle
/// on a patch still in `opts.patches` gets its numbers from `st` (see `refresh`).
/// Allocates in `arena`.
pub fn update(
    arena: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    st: *const Stats,
    opts: Options,
) ![]File {
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, opts.dir);
    var dir = try cwd.openDir(io, opts.dir, .{});
    defer dir.close(io);

    var used = try readUsed(arena, io, dir);
    var files: std.ArrayList(File) = .empty;
    var index: std.Io.Writer.Allocating = .init(arena);
    try index.writer.writeAll("[");
    const last = opts.today + opts.ahead;
    var day: u32 = first_day;
    while (day <= last) : (day += 1) {
        const n = day - first_day + 1;
        const name = try arena.print("{d}.json", .{n});
        const read = dir.readFileAlloc(io, name, arena, .limited(1 << 20));
        const read_data = read catch |err| switch (err) {
            error.FileNotFound => if (day < opts.today) continue else blk: {
                const made = try make(arena, db, st, opts, n, day, &used) orelse {
                    log.warn("no draft for puzzle #{d}", .{n});
                    continue;
                };
                try dir.writeFile(io, .{ .sub_path = "used.txt", .data = used.items });
                try dir.writeFile(io, .{ .sub_path = name, .data = made });
                log.info("puzzle #{d} made", .{n});
                break :blk made;
            },
            else => return err,
        };
        const data = try refresh(arena, io, dir, st, opts, name, read_data);
        const path = try arena.print("daily/{s}", .{name});
        try files.append(arena, .{ .path = path, .data = data });
        if (index.writer.end > 1) try index.writer.writeByte(',');
        try index.writer.print("{{\"n\":{d},\"date\":\"{f}\"}}", .{ n, Date.fromDay(day) });
    }
    try index.writer.writeAll("]\n");
    try files.append(arena, .{ .path = "daily/index.json", .data = index.written() });
    return files.toOwnedSlice(arena);
}

/// A puzzle made early in a patch would keep that day's thin numbers (a few thousand games,
/// every lane "more data needed"), so while its patch is current its numbers follow
/// `st` and are saved back; once the patch is gone the last ones stay. Only the numbers
/// change: champions, the four options, the hidden slot and the winner (the answers
/// archive results were marked against) are the game's. Kept as made when it does not
/// parse or `st` cannot score it.
fn refresh(
    arena: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    st: *const Stats,
    opts: Options,
    name: []const u8,
    data: []const u8,
) ![]const u8 {
    var p = std.json.parseFromSliceLeaky(Puzzle, arena, data, .{}) catch |err| {
        log.info("{s} kept as made: {t}", .{ name, err });
        return data;
    };
    for (opts.patches) |patch| {
        if (std.mem.eql(u8, patch, p.patch)) break;
    } else return data;
    var ids: [4]u32 = undefined;
    for (p.options, &ids) |o, *id| id.* = o.id;
    if (!try numbers(arena, st, &p, ids)) return data;
    const fresh = try std.json.Stringify.valueAlloc(arena, p, .{});
    if (std.mem.eql(u8, fresh, data)) return data;
    // The web loop and the renderer both build the shared view: never a half-written file
    var tag: [8]u8 = undefined;
    io.random(&tag);
    const tmp = try arena.print("{s}.{x}.tmp", .{ name, &tag });
    try dir.writeFile(io, .{ .sub_path = tmp, .data = fresh });
    try dir.rename(tmp, dir, name, io);
    return fresh;
}

/// Newline-separated match ids, newest last
pub fn readUsed(arena: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) !std.ArrayList(u8) {
    const read = dir.readFileAlloc(io, "used.txt", arena, .limited(64 << 20));
    const text = read catch |err| switch (err) {
        error.FileNotFound => "",
        else => return err,
    };
    var list: std.ArrayList(u8) = .empty;
    try list.appendSlice(arena, text);
    return list;
}

pub fn isUsed(used: []const u8, match_id: []const u8) bool {
    var it = std.mem.tokenizeScalar(u8, used, '\n');
    while (it.next()) |id| if (std.mem.eql(u8, id, match_id)) return true;
    return false;
}

/// Puzzle JSON for day `day` from a random unused game, recording its match id in
/// `used`. Null when no candidate works.
fn make(
    arena: std.mem.Allocator,
    db: store.Db,
    st: *const Stats,
    opts: Options,
    n: u32,
    day: u32,
    used: *std.ArrayList(u8),
) !?[]const u8 {
    const patch_json = try std.json.Stringify.valueAlloc(arena, opts.patches, .{});
    const platform_json = try std.json.Stringify.valueAlloc(arena, opts.platforms, .{});
    const where =
        \\FROM matches
        \\WHERE patch IN (SELECT value FROM json_each(?)) AND queue_id = ?
        \\  AND platform IN (SELECT value FROM json_each(?))
        \\  AND remake = 0 AND winning_team IS NOT NULL AND duration_s >= ?
    ;
    const total = try db.scalar("SELECT count(*) " ++ where, .{
        patch_json, stats.ranked_solo, platform_json, min_duration_s,
    }) orelse 0;
    if (total == 0) return null;

    var q = try db.prepare("SELECT match_id " ++ where ++ " ORDER BY match_id LIMIT 1 OFFSET ?");
    defer q.deinit();
    const seed = std.hash.Wyhash.hash(n, std.mem.asBytes(&used.items.len));
    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();
    for (0..tries) |_| {
        const offset = rand.uintLessThan(u64, @intCast(total));
        try q.bind(.{
            patch_json, stats.ranked_solo, platform_json, min_duration_s, offset,
        });
        if (!try q.step()) continue;
        const match_id = try arena.dupe(u8, q.bytes(0));
        if (isUsed(used.items, match_id)) continue;
        var puzzle = try load(arena, db, st, match_id, rand) orelse continue;
        if (!usualPicks(st, puzzle.teams)) continue;
        puzzle.n = n;
        puzzle.date = try arena.print("{f}", .{Date.fromDay(day)});
        try used.appendSlice(arena, match_id);
        try used.append(arena, '\n');
        return try std.json.Stringify.valueAlloc(arena, puzzle, .{});
    }
    return null;
}

fn usualPicks(st: *const Stats, teams: [2][5]u32) bool {
    const games: f64 = @floatFromInt(st.games);
    for (teams) |team| for (Role.all) |r| {
        const c = st.index(team[@backingInt(r)]).?;
        const role_games: f64 = @floatFromInt(st.champRole(r, c).games);
        if (role_games < min_role_share * games) return false;
    };
    return true;
}

/// Null when the game is unusable: a position missing or doubled, a champion the
/// model file lacks, or too few champions to fill the four options
pub fn load(
    arena: std.mem.Allocator,
    db: store.Db,
    st: *const Stats,
    match_id: []const u8,
    rand: std.Random,
) !?Puzzle {
    var p: Puzzle = undefined;
    {
        var q = try db.prepare(
            "SELECT patch, winning_team, duration_s FROM matches WHERE match_id = ?",
        );
        defer q.deinit();
        try q.bind(.{match_id});
        if (!try q.step()) return null;
        const m = q.row(struct { patch: []const u8, winning_team: i64, duration_s: i64 });
        p.patch = try arena.dupe(u8, m.patch);
        p.winner = if (m.winning_team == 100) 0 else 1;
        p.minutes = @intCast(@divFloor(m.duration_s + 30, 60));
    }
    {
        var seen: [2][5]bool = @splat(@splat(false));
        p.kills = .{ 0, 0 };
        p.gold = .{ 0, 0 };
        var q = try db.prepare(
            \\SELECT team_id, position, champion_id, kills, gold
            \\FROM participants WHERE match_id = ?
        );
        defer q.deinit();
        try q.bind(.{match_id});
        var rows: usize = 0;
        while (try q.step()) : (rows += 1) {
            const pa = q.row(struct {
                team_id: i64,
                position: []const u8,
                champion_id: u32,
                kills: ?i64,
                gold: ?i64,
            });
            const t: u1 = if (pa.team_id == 100) 0 else 1;
            const r = Role.fromLcu(pa.position) orelse return null;
            if (seen[t][@backingInt(r)] or st.index(pa.champion_id) == null) return null;
            seen[t][@backingInt(r)] = true;
            p.teams[t][@backingInt(r)] = pa.champion_id;
            p.kills[t] += @intCast(@max(0, pa.kills orelse 0));
            p.gold[t] += @intCast(@max(0, pa.gold orelse 0));
        }
        if (rows != 10) return null;
        // Exact totals would help find the game elsewhere; the reveal shows 0.1k anyway
        for (&p.gold) |*g| g.* = (g.* + 50) / 100 * 100;
    }
    {
        var bans: [2]std.ArrayList(u32) = .{ .empty, .empty };
        var q = try db.prepare(
            \\SELECT team_id, champion_id FROM bans
            \\WHERE match_id = ? AND champion_id > 0 ORDER BY team_id, pick_turn
        );
        defer q.deinit();
        try q.bind(.{match_id});
        while (try q.step()) {
            const b = q.row(struct { team_id: i64, champion_id: u32 });
            try bans[if (b.team_id == 100) 0 else 1].append(arena, b.champion_id);
        }
        p.bans = .{ bans[0].items, bans[1].items };
    }
    p.tier = try medianTier(db, match_id);

    if (!try hideBestFit(arena, st, &p)) return null;
    p.played = p.teams[p.hidden_team][@backingInt(p.hidden_role)];
    const ids = (try options(arena, st, p, rand)) orelse return null;
    if (!try numbers(arena, st, &p, ids)) return null;
    return p;
}

/// Hides the slot whose champion its allies and enemies explain best, not its own strength
/// in the role (meta picks would make the guess "the strongest champion"). Fit: its ally
/// and enemy points plus a quarter of its points in the draft, so a pick weak this patch
/// with one good matchup does not win. Few pairs clear chance alone (static/daily.js), so
/// it takes the points as they are. False when no slot scores
fn hideBestFit(arena: std.mem.Allocator, st: *const Stats, p: *Puzzle) !bool {
    const Fit = struct { team: u1, role: Role, fit: f64 };
    var best: ?Fit = null;
    for ([_]u1{ 0, 1 }) |t| for (Role.all) |r| {
        p.hidden_team = t;
        p.hidden_role = r;
        var draft = try hiddenDraft(arena, p.*);
        const pool = [1]u32{p.teams[t][@backingInt(r)]};
        draft.pool = &pool;
        var out: [1]core.Suggestion = undefined;
        const scored = core.recommend(st, draft, .{ .min_games = 0 }, &out);
        if (scored.len != 1) continue;
        var fit: Fit = .{ .team = t, .role = r, .fit = scored[0].pp / 4 };
        for (scored[0].reasons()) |reason| {
            if (reason.kind != .base) fit.fit += reason.pp;
        }
        if (best) |b| if (fit.fit <= b.fit) continue;
        best = fit;
    };
    const b = best orelse return false;
    p.hidden_team = b.team;
    p.hidden_role = b.role;
    p.hidden_by = .fit;
    return true;
}

/// Fills what `st` says about the draft: games, the options (`ids`, in this order),
/// blue's win chance and the lanes. False when `st` cannot score one of the champions.
fn numbers(arena: std.mem.Allocator, st: *const Stats, p: *Puzzle, ids: [4]u32) !bool {
    for (p.teams) |team| for (team) |id| if (st.index(id) == null) return false;
    var draft = try hiddenDraft(arena, p.*);
    draft.pool = &ids;
    // Scored together with no game minimum, so the played champion always appears
    var four: [4]core.Suggestion = undefined;
    const scored = core.recommend(st, draft, .{ .min_games = 0 }, &four);
    if (scored.len != 4) return false;
    for (ids, &p.options) |id, *o| {
        const s = for (scored) |s| {
            if (s.champion == id) break s;
        } else return false;
        const reasons = try arena.alloc(Reason, s.n_reasons);
        for (s.reasons(), reasons) |r, *dst| dst.* = .{
            .kind = r.kind,
            .id = r.champion,
            .role = r.role,
            .pp = round1(r.pp),
            .games = r.games,
        };
        o.* = .{ .id = id, .pp = round1(s.pp), .games = s.games, .reasons = reasons };
    }
    p.games = st.games;
    p.blue_win = blueWin(st, p.teams);
    for (Role.all) |r| {
        const blue = st.index(p.teams[0][@backingInt(r)]).?;
        const red = st.index(p.teams[1][@backingInt(r)]).?;
        p.lanes[@backingInt(r)] = .{
            .pp = round1(score.matchupPp(st, .{}, r, blue, r, red)),
            .games = st.enemy(r, r, blue, red).games,
        };
    }
    return true;
}

/// From the rank snapshot stored with the match: players is emptied on a rekey
fn medianTier(db: store.Db, match_id: []const u8) !?[]const u8 {
    var q = try db.prepare(
        "SELECT tier FROM participants WHERE match_id = ? AND tier IS NOT NULL",
    );
    defer q.deinit();
    try q.bind(.{match_id});
    var ranks: [10]usize = undefined;
    var len: usize = 0;
    while (try q.step() and len < ranks.len) {
        ranks[len] = curvesfile.tierRank(q.bytes(0)) orelse continue;
        len += 1;
    }
    return curvesfile.tiers[curvesfile.medianRank(ranks[0..len]) orelse return null];
}

/// Same minimum as the site's draft helper: 0.3% of games, between 5 and 200
pub fn minGames(st: *const Stats) u32 {
    const share: u32 = @intFromFloat(@round(@as(f64, @floatFromInt(st.games)) * 0.003));
    return std.math.clamp(share, 5, 200);
}

/// The hidden team's view: me in the hidden role, my four teammates, five known enemies
pub fn hiddenDraft(arena: std.mem.Allocator, p: Puzzle) !core.Draft {
    var allies: std.ArrayList(core.Pick) = .empty;
    var enemies: std.ArrayList(core.Pick) = .empty;
    for (Role.all) |r| {
        const mine = p.teams[p.hidden_team][@backingInt(r)];
        const theirs = p.teams[1 - p.hidden_team][@backingInt(r)];
        if (r != p.hidden_role) try allies.append(arena, .{ .champion = mine, .role = r });
        try enemies.append(arena, .{ .champion = theirs, .role = r });
    }
    const bans = try std.mem.concat(arena, u32, &p.bans);
    return .{
        .role = p.hidden_role,
        .allies = allies.items,
        .enemies = enemies.items,
        .bans = bans,
    };
}

/// The played champion and three others from the 20 the numbers rate highest in this
/// draft, shuffled. Picking among the top keeps them plausible, so the guess is about
/// the draft rather than spotting the odd one out.
fn options(arena: std.mem.Allocator, st: *const Stats, p: Puzzle, rand: std.Random) !?[4]u32 {
    const draft = try hiddenDraft(arena, p);
    var top: [20]core.Suggestion = undefined;
    const ranked = core.recommend(st, draft, .{ .min_games = minGames(st) }, &top);
    var others: std.ArrayList(u32) = .empty;
    for (ranked) |s| if (s.champion != p.played) try others.append(arena, s.champion);
    if (others.items.len < 3) return null;
    rand.shuffle(u32, others.items);
    var ids: [4]u32 = .{ p.played, others.items[0], others.items[1], others.items[2] };
    rand.shuffle(u32, &ids);
    return ids;
}

/// Blue's win chance with every slot known: blue's top laner as "me", the rest as
/// allies and enemies
fn blueWin(st: *const Stats, teams: [2][5]u32) f64 {
    var allies: [4]core.Pick = undefined;
    var enemies: [5]core.Pick = undefined;
    for (Role.all[1..], &allies) |r, *a| {
        a.* = .{ .champion = teams[0][@backingInt(r)], .role = r };
    }
    for (Role.all, &enemies) |r, *e| {
        e.* = .{ .champion = teams[1][@backingInt(r)], .role = r };
    }
    var out: [1]core.Suggestion = undefined;
    const s = core.recommend(st, .{
        .role = .top,
        .allies = &allies,
        .enemies = &enemies,
        .pool = &.{teams[0][0]},
    }, .{ .min_games = 0 }, &out);
    return if (s.len == 1) @round(s[0].win * 1000) / 1000 else 0.5;
}

pub fn round1(x: f64) f64 {
    return @round(x * 10) / 10;
}

const testing = std.testing;

/// 30 games between five groups of five champions (group k plays ids 5k+1..5k+5,
/// TOP..UTILITY): blue is group g % 5, red the next one
fn testDb() !store.Db {
    const db = try store.schema.memory();
    errdefer db.close();
    for (1..26) |id| try db.run("INSERT INTO champions VALUES (?,?,?,'','v')", .{ id, "k", "n" });
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    var buf: [32]u8 = undefined;
    for (0..30) |g| {
        const id = try std.mem.print(&buf, "EUW1_{d}", .{g});
        try db.run("INSERT INTO matches VALUES (?,'t','EUW1',420,'16.20','',0,1800,?,0)", .{
            id, @as(i64, if (g % 3 == 0) 200 else 100),
        });
        for (0..10) |slot| {
            const team: i64 = if (slot < 5) 100 else 200;
            const base = 1 + 5 * ((g + slot / 5) % 5);
            try db.run(
                \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position,
                \\  win, kills, gold, tier) VALUES (?,?,?,?,?,?,0,?,1000,'GOLD')
            , .{ id, slot, team, "p", base + slot % 5, positions[slot % 5], slot });
        }
        try db.run("INSERT INTO bans VALUES (?,100,1,9)", .{id});
    }
    return db;
}

test "puzzles are made once, anonymised and published" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;

    const db = try testDb();
    defer db.close();
    var built = try stats.build(gpa, db, &.{"16.20"}, &.{"EUW1"});
    defer built.builder.deinit();
    var model: std.Io.Writer.Allocating = .init(arena);
    try built.builder.write(&model.writer, "16.20");
    var st: Stats = try .parse(arena, model.written());

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try arena.print(".zig-cache/tmp/{s}/daily", .{&tmp.sub_path});
    const opts: Options = .{
        .dir = dir,
        .patches = &.{"16.20"},
        .platforms = &.{"EUW1"},
        .today = first_day + 3,
        .ahead = 1,
    };
    const files = try update(arena, io, db, &st, opts);
    // Days before today are never made late: only today and tomorrow, plus the index
    try testing.expectEqual(3, files.len);
    try testing.expectEqualStrings("daily/4.json", files[0].path);
    try testing.expectEqualStrings("daily/index.json", files[2].path);
    try testing.expectEqualStrings(
        "[{\"n\":4,\"date\":\"2026-10-14\"},{\"n\":5,\"date\":\"2026-10-15\"}]\n",
        files[2].data,
    );
    try testing.expect(std.mem.indexOf(u8, files[0].data, "EUW1_") == null);
    try testing.expect(std.mem.indexOf(u8, files[0].data, "\"p\"") == null);

    const p = try std.json.parseFromSliceLeaky(Puzzle, arena, files[0].data, .{});
    try testing.expectEqual(4, p.n);
    try testing.expectEqualStrings("GOLD", p.tier.?);
    try testing.expectEqual(30, p.games);
    try testing.expectEqual(30, p.minutes);
    try testing.expectEqual(35, p.kills[1]);
    try testing.expectEqual(5000, p.gold[0]);
    try testing.expectEqualSlices(u32, &.{9}, p.bans[0]);
    var found = false;
    for (p.options) |o| found = found or o.id == p.played;
    try testing.expect(found);
    try testing.expectEqual(p.played, p.teams[p.hidden_team][@backingInt(p.hidden_role)]);
    try testing.expectEqual(.fit, p.hidden_by);

    // Kept, not remade; a new game for each new day, never one already used
    var next = opts;
    next.today += 1;
    next.ahead = 2;
    const again = try update(arena, io, db, &st, next);
    try testing.expectEqualStrings(files[0].data, again[0].data);
    try testing.expectEqualStrings(files[1].data, again[1].data);
    try testing.expectEqual(5, again.len);
    const used_path = try arena.print("{s}/used.txt", .{dir});
    const used = try std.Io.Dir.cwd().readFileAlloc(io, used_path, arena, .unlimited);
    try testing.expectEqual(4, std.mem.count(u8, used, "\n"));

    // Numbers frozen thin on an early day follow the patch's stats; the answers stay.
    // A puzzle on a patch no longer in the stats keeps what it has.
    var thin = p;
    thin.games = 7;
    thin.lanes = @splat(.{ .pp = 0, .games = 1 });
    const four = try arena.print("{s}/4.json", .{dir});
    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = four,
        .data = try std.json.Stringify.valueAlloc(arena, thin, .{}),
    });
    var old = try std.json.parseFromSliceLeaky(Puzzle, arena, again[1].data, .{});
    old.patch = "16.19";
    old.games = 7;
    const old_data = try std.json.Stringify.valueAlloc(arena, old, .{});
    const five = try arena.print("{s}/5.json", .{dir});
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = five, .data = old_data });
    const third = try update(arena, io, db, &st, next);
    try testing.expectEqualStrings(files[0].data, third[0].data);
    try testing.expectEqualStrings(old_data, third[1].data);
    const saved = try std.Io.Dir.cwd().readFileAlloc(io, four, arena, .unlimited);
    try testing.expectEqualStrings(files[0].data, saved);

    // A top laner never seen in jungle makes the game unusable
    try testing.expect(usualPicks(&st, p.teams));
    var swapped = p.teams;
    std.mem.swap(u32, &swapped[0][0], &swapped[0][1]);
    try testing.expect(!usualPicks(&st, swapped));
}
