//! Learn: the data behind the Learn page for new players (site/learn.zig). Champion
//! facts in plain terms (damage type, win rate by game length), how teams with one
//! damage type fare, and a pack of practice drafts graded easy to hard.
//!
//! Practice drafts are real ranked solo games anonymised as in src/daily.zig: champions,
//! bans, patch, a rank tier and game length only. The pack is remade each day from a
//! seed of the day, and leaves out games behind Daily Draft puzzles so none is spoiled,
//! and games with an off-role or rare pick (daily.usualPicks).
//! Options are explained, never marked as "the correct pick" (docs/concept.md).

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const daily = @import("daily.zig");

const Role = core.Role;
const Stats = core.Stats;
const Counts = core.statsfile.Counts;
const curvesfile = core.curvesfile;

const log = std.log.scoped(.learn);

/// Game length buckets: short below the first, long from the second (minutes)
pub const length_minutes = [_]u32{ 25, 32 };
pub const lengths = length_minutes.len + 1;
/// Team damage mix buckets by the team's average magic share: mostly physical below
/// the first, mostly magic from the second
pub const mix_bounds = [_]f64{ 0.3, 0.7 };
pub const mixes = mix_bounds.len + 1;
/// Newest games whose raw match JSON is read for the damage split; damage type barely
/// moves, so a sample does
const damage_sample = 3000;
/// Fewer sampled games than this and a champion's damage type is unknown
const min_damage_games = 10;
/// Practice drafts per role and difficulty
const per_cell = 16;
/// Games tried per cell; ~40% have only usual picks, and only those reach draftFor
const tries_per_cell = 320;

/// Graded on facts that do not depend on the draft model, whose pair terms are still
/// noise at a few thousand games: the team's damage mix (measured: one-sided teams win
/// less, `Facts.mix`) and, once there are enough games, the lane curve
pub const Difficulty = enum {
    /// The team leans on one damage type and exactly one option brings the other
    easy,
    /// The team leans on one damage type and two options bring the other
    medium,
    /// A balanced team: nothing in the draft separates the options clearly
    hard,
};

/// Damage type the hidden player's team lacks, judged from the four teammates
pub const Need = enum { magic, physical };
/// An option brings the needed type at this share or more, and lacks it at the other
const brings_share = 0.6;
const lacks_share = 0.3;
/// Easy drafts leave out options this far behind in lane at lane_minute (gold), when
/// the curve has enough games
const lane_behind_gold = -200;
const lane_min_games = 200;

pub const Options = struct {
    patches: []const []const u8,
    platforms: []const []const u8,
    /// Epoch day (UTC): seeds the practice pack
    today: u32,
    /// Daily Draft puzzles' directory, for the match ids to leave out
    daily_dir: ?[]const u8 = null,
};

pub const Champ = struct {
    /// Share of damage to champions that is magic, 0..1; null when too few sampled
    magic: ?f32 = null,
    /// Per role, games and wins by game length (length_minutes)
    length: [Role.count][lengths]Counts = @splat(@splat(.{ .games = 0, .wins = 0 })),
};

pub const Facts = struct {
    /// Indexed like the stats file
    champs: []Champ,
    /// Teams by damage mix (mix_bounds)
    mix: [mixes]Counts,
    damage_games: u32,
};

pub const LaneCurve = struct {
    games: u32,
    /// Median gold difference (this option minus the lane opponent) by minute
    gold: []const i16,
};

pub const Option = struct {
    id: u32,
    pp: f64,
    /// Games and wins on this champion in the hidden role
    games: u32,
    wins: u32,
    /// Percent of its damage to champions that is magic
    magic: ?u8,
    reasons: []const daily.Reason,
    /// Against the enemy in the same role; null without a lane curve for the pair
    lane: ?LaneCurve,
};

pub const Practice = struct {
    patch: []const u8,
    tier: ?[]const u8,
    teams: [2][5]u32,
    bans: [2][]const u32,
    hidden_team: u1,
    hidden_role: Role,
    difficulty: Difficulty,
    need: ?Need,
    /// In display order
    options: [4]Option,
    /// What happened in the real game: the champion in the hidden slot, and its side
    played: u32,
    won: bool,
    minutes: u32,
};

pub const File = daily.File;

pub const Learn = struct {
    facts: Facts,
    files: []File,
};

pub fn build(
    arena: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    st: *const Stats,
    curves: ?*const curvesfile.Curves,
    opts: Options,
) !Learn {
    const facts = try champFacts(arena, db, st, opts);
    var files: std.ArrayList(File) = .empty;
    try files.append(arena, .{ .path = "learn/champs.json", .data = try champsJson(arena, st, facts) });
    const pack = try practice(arena, io, db, st, facts, curves, opts);
    try files.append(arena, .{
        .path = "learn/practice.json",
        .data = try std.json.Stringify.valueAlloc(arena, pack, .{}),
    });
    log.info("{d} practice drafts, damage split from {d} games", .{ pack.len, facts.damage_games });
    return .{ .facts = facts, .files = try files.toOwnedSlice(arena) };
}

fn patchWhere(arena: std.mem.Allocator, opts: Options) ![2][]const u8 {
    return .{
        try std.json.Stringify.valueAlloc(arena, opts.patches, .{}),
        try std.json.Stringify.valueAlloc(arena, opts.platforms, .{}),
    };
}

pub fn lengthBucket(minutes: u32) usize {
    var b: usize = 0;
    while (b < length_minutes.len and minutes >= length_minutes[b]) b += 1;
    return b;
}

pub fn mixBucket(magic: f64) usize {
    var b: usize = 0;
    while (b < mix_bounds.len and magic >= mix_bounds[b]) b += 1;
    return b;
}

fn champFacts(arena: std.mem.Allocator, db: store.Db, st: *const Stats, opts: Options) !Facts {
    const champs = try arena.alloc(Champ, st.n);
    @memset(champs, .{});
    const patch_json, const platform_json = try patchWhere(arena, opts);
    {
        var q = try db.prepare(
            \\SELECT p.champion_id, p.position, p.win, m.duration_s
            \\FROM matches m JOIN participants p USING (match_id)
            \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
            \\  AND m.platform IN (SELECT value FROM json_each(?))
            \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
        );
        defer q.deinit();
        try q.bind(.{ patch_json, stats.ranked_solo, platform_json });
        while (try q.step()) {
            const p = q.row(struct {
                champion: u32,
                position: []const u8,
                win: bool,
                duration_s: i64,
            });
            const c = st.index(p.champion) orelse continue;
            const r = Role.fromLcu(p.position) orelse continue;
            const minutes: u32 = @intCast(@divFloor(@max(0, p.duration_s), 60));
            const n = &champs[c].length[@backingInt(r)][lengthBucket(minutes)];
            n.games += 1;
            if (p.win) n.wins += 1;
        }
    }

    const damage_games = try damageSplit(arena, db, st, opts, champs);

    var mix: [mixes]Counts = @splat(.{ .games = 0, .wins = 0 });
    {
        var q = try db.prepare(
            \\SELECT p.match_id, p.team_id, p.champion_id, p.win
            \\FROM matches m JOIN participants p USING (match_id)
            \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
            \\  AND m.platform IN (SELECT value FROM json_each(?))
            \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
            \\ORDER BY p.match_id, p.team_id
        );
        defer q.deinit();
        try q.bind(.{ patch_json, stats.ranked_solo, platform_json });
        var team_key: std.ArrayList(u8) = .empty;
        var team_id: i64 = 0;
        var sum: f64 = 0;
        var known: u32 = 0;
        var members: u32 = 0;
        var won = false;
        while (true) {
            const more = try q.step();
            const p = if (more) q.row(struct {
                match_id: []const u8,
                team: i64,
                champion: u32,
                win: bool,
            }) else undefined;
            const same = more and team_id == p.team and std.mem.eql(u8, team_key.items, p.match_id);
            if (!same and members > 0) {
                // Only full teams with every damage type known
                if (members == 5 and known == 5) {
                    const n = &mix[mixBucket(sum / 5)];
                    n.games += 1;
                    if (won) n.wins += 1;
                }
                sum = 0;
                known = 0;
                members = 0;
            }
            if (!more) break;
            if (!same) {
                team_key.clearRetainingCapacity();
                try team_key.appendSlice(arena, p.match_id);
                team_id = p.team;
                won = p.win;
            }
            members += 1;
            const c = st.index(p.champion) orelse continue;
            const m = champs[c].magic orelse continue;
            sum += m;
            known += 1;
        }
    }
    return .{ .champs = champs, .mix = mix, .damage_games = damage_games };
}

const RawMatch = struct {
    info: struct {
        participants: []const struct {
            championId: u32 = 0,
            magicDamageDealtToChampions: i64 = 0,
            physicalDamageDealtToChampions: i64 = 0,
            trueDamageDealtToChampions: i64 = 0,
        } = &.{},
    },
};

/// Magic share of each champion's damage to champions, from the raw match JSON of the
/// newest games on the chosen patches. Returns the games read.
fn damageSplit(
    arena: std.mem.Allocator,
    db: store.Db,
    st: *const Stats,
    opts: Options,
    champs: []Champ,
) !u32 {
    const patch_json, const platform_json = try patchWhere(arena, opts);
    var q = try db.prepare(
        \\SELECT body FROM raw.raw_docs WHERE source = 'riot_match' AND key IN (
        \\  SELECT match_id FROM matches
        \\  WHERE patch IN (SELECT value FROM json_each(?)) AND queue_id = ?
        \\    AND platform IN (SELECT value FROM json_each(?)) AND remake = 0
        \\  ORDER BY game_start DESC LIMIT ?)
    );
    defer q.deinit();
    try q.bind(.{ patch_json, stats.ranked_solo, platform_json, damage_sample });
    const Sum = struct { magic: f64 = 0, all: f64 = 0, games: u32 = 0 };
    const sums = try arena.alloc(Sum, st.n);
    @memset(sums, .{});
    var doc_arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer doc_arena.deinit();
    var games: u32 = 0;
    while (try q.step()) {
        _ = doc_arena.reset(.retain_capacity);
        const a = doc_arena.allocator();
        const json = store.raw.decompress(a, q.bytes(0)) catch continue;
        const doc = std.json.parseFromSliceLeaky(RawMatch, a, json, .{
            .ignore_unknown_fields = true,
        }) catch continue;
        games += 1;
        for (doc.info.participants) |p| {
            const c = st.index(p.championId) orelse continue;
            const magic: f64 = @floatFromInt(@max(0, p.magicDamageDealtToChampions));
            const other: f64 = @floatFromInt(@max(0, p.physicalDamageDealtToChampions) +
                @max(0, p.trueDamageDealtToChampions));
            sums[c].magic += magic;
            sums[c].all += magic + other;
            sums[c].games += 1;
        }
    }
    for (sums, champs) |s, *ch| {
        if (s.games >= min_damage_games and s.all > 0) ch.magic = @floatCast(s.magic / s.all);
    }
    return games;
}

/// {"lengths":[25,32],"mix":[[games,wins],...],"champions":[{"id","magic","length":
/// [[g,w,g,w,g,w] per role]}]}
fn champsJson(arena: std.mem.Allocator, st: *const Stats, facts: Facts) ![]const u8 {
    var aw: std.Io.Writer.Allocating = .init(arena);
    const w = &aw.writer;
    try w.writeAll("{\"lengths\":");
    try std.json.Stringify.value(length_minutes, .{}, w);
    try w.writeAll(",\"mix_bounds\":");
    try std.json.Stringify.value(mix_bounds, .{}, w);
    try w.writeAll(",\"mix\":[");
    for (facts.mix, 0..) |m, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("[{d},{d}]", .{ m.games, m.wins });
    }
    try w.writeAll("],\"champions\":[");
    for (facts.champs, 0..) |ch, c| {
        if (c > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"magic\":", .{st.ids[c]});
        if (ch.magic) |m| try w.print("{d:.2}", .{m}) else try w.writeAll("null");
        try w.writeAll(",\"length\":[");
        for (ch.length, 0..) |per_role, r| {
            if (r > 0) try w.writeByte(',');
            try w.writeByte('[');
            for (per_role, 0..) |n, b| {
                if (b > 0) try w.writeByte(',');
                try w.print("{d},{d}", .{ n.games, n.wins });
            }
            try w.writeByte(']');
        }
        try w.writeAll("]}");
    }
    try w.writeAll("]}\n");
    return aw.written();
}

fn practice(
    arena: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    st: *const Stats,
    facts: Facts,
    curves: ?*const curvesfile.Curves,
    opts: Options,
) ![]Practice {
    var used: std.ArrayList(u8) = .empty;
    if (opts.daily_dir) |d| {
        if (std.Io.Dir.cwd().openDir(io, d, .{})) |dir_| {
            var dir = dir_;
            defer dir.close(io);
            used = try daily.readUsed(arena, io, dir);
        } else |_| {}
    }
    const patch_json, const platform_json = try patchWhere(arena, opts);
    const where =
        \\FROM matches
        \\WHERE patch IN (SELECT value FROM json_each(?)) AND queue_id = ?
        \\  AND platform IN (SELECT value FROM json_each(?))
        \\  AND remake = 0 AND winning_team IS NOT NULL AND duration_s >= 900
    ;
    // Once, not a query per try: OFFSET walks the rows before it every time
    var ids: std.ArrayList([]const u8) = .empty;
    {
        var q = try db.prepare("SELECT match_id " ++ where ++ " ORDER BY match_id");
        defer q.deinit();
        try q.bind(.{ patch_json, stats.ranked_solo, platform_json });
        while (try q.step()) try ids.append(arena, try arena.dupe(u8, q.bytes(0)));
    }
    if (ids.items.len == 0) return &.{};

    var prng: std.Random.DefaultPrng = .init(std.hash.Wyhash.hash(opts.today, "learn"));
    const rand = prng.random();
    var pack: std.ArrayList(Practice) = .empty;
    for (Role.all) |role| {
        for (std.enums.values(Difficulty)) |want| {
            var made: usize = 0;
            var tries: usize = 0;
            while (made < per_cell and tries < tries_per_cell) : (tries += 1) {
                const match_id = ids.items[@intCast(rand.uintLessThan(u64, ids.items.len))];
                if (daily.isUsed(used.items, match_id)) continue;
                const p = try daily.load(arena, db, st, match_id, rand) orelse continue;
                if (!daily.usualPicks(st, p.teams)) continue;
                const drill = try draftFor(arena, st, facts, curves, p, role, want, rand) orelse continue;
                try pack.append(arena, drill);
                try used.appendSlice(arena, match_id);
                try used.append(arena, '\n');
                made += 1;
            }
            if (made < per_cell) log.info("{t} {t}: {d} practice drafts", .{ role, want, made });
        }
    }
    rand.shuffle(Practice, pack.items);
    return pack.items;
}

/// Candidates for the options: champions the recommender lists for the hidden slot,
/// which keeps them plausible picks for the role (played there, not already taken)
const candidates_len = 48;
/// An option must be one of the role's usual champions: at least this share of its games
/// in the role, and this many
const option_role_share = 0.3;
const option_min_games = 15;

/// A practice draft from game `game` with `role` hidden, when it can be built as `want`
fn draftFor(
    arena: std.mem.Allocator,
    st: *const Stats,
    facts: Facts,
    curves: ?*const curvesfile.Curves,
    game: daily.Puzzle,
    role: Role,
    want: Difficulty,
    rand: std.Random,
) !?Practice {
    var p = game;
    p.hidden_role = role;
    p.played = p.teams[p.hidden_team][@backingInt(role)];
    const need = teamNeed(st, facts, p) orelse return null;
    if ((need.need == null) != (want == .hard)) return null;
    const enemy = p.teams[1 - p.hidden_team][@backingInt(role)];

    var draft = try daily.hiddenDraft(arena, p);
    var top: [candidates_len]core.Suggestion = undefined;
    const ranked = core.recommend(st, draft, .{ .min_games = daily.minGames(st) }, &top);
    var brings: std.ArrayList(u32) = .empty;
    var lacks: std.ArrayList(u32) = .empty;
    var any: std.ArrayList(u32) = .empty;
    for (ranked) |s| {
        const c = st.index(s.champion).?;
        const games = st.champRole(role, c).games;
        if (games < option_min_games or
            @as(f64, @floatFromInt(games)) < option_role_share * @as(f64, @floatFromInt(st.champGames(c))))
            continue;
        const m = facts.champs[c].magic orelse continue;
        try any.append(arena, s.champion);
        const n = need.need orelse continue;
        const share = if (n == .magic) m else 1 - m;
        if (share >= brings_share) {
            if (want == .easy and laneBehind(curves, role, s.champion, enemy)) continue;
            try brings.append(arena, s.champion);
        } else if (share <= lacks_share) try lacks.append(arena, s.champion);
    }

    var ids: [4]u32 = undefined;
    const n_bring: usize = switch (want) {
        .easy => 1,
        .medium => 2,
        .hard => 0,
    };
    if (want == .hard) {
        // Near the top of the list, so no option is an obvious outlier either
        if (any.items.len < 4) return null;
        pickDistinct(any.items[0..@min(any.items.len, 8)], &ids, rand);
    } else {
        if (brings.items.len < n_bring or lacks.items.len < 4 - n_bring) return null;
        pickDistinct(brings.items, ids[0..n_bring], rand);
        pickDistinct(lacks.items, ids[n_bring..], rand);
    }
    rand.shuffle(u32, &ids);

    draft.pool = &ids;
    var four: [4]core.Suggestion = undefined;
    const scored = core.recommend(st, draft, .{ .min_games = 0 }, &four);
    if (scored.len != 4) return null;
    var options: [4]Option = undefined;
    for (ids, &options) |id, *o| {
        const s = for (scored) |s| {
            if (s.champion == id) break s;
        } else return null;
        const reasons = try arena.alloc(daily.Reason, s.n_reasons);
        for (s.reasons(), reasons) |r, *dst| dst.* = .{
            .kind = r.kind,
            .id = r.champion,
            .role = r.role,
            .pp = daily.round1(r.pp),
            .games = r.games,
        };
        const c = st.index(id).?;
        o.* = .{
            .id = id,
            .pp = daily.round1(s.pp),
            .games = s.games,
            .wins = st.champRole(role, c).wins,
            .magic = if (facts.champs[c].magic) |m| @intFromFloat(@round(m * 100)) else null,
            .reasons = reasons,
            .lane = if (curves) |cv| try laneCurve(arena, cv, role, id, enemy) else null,
        };
    }
    return .{
        .patch = p.patch,
        .tier = p.tier,
        .teams = p.teams,
        .bans = p.bans,
        .hidden_team = p.hidden_team,
        .hidden_role = role,
        .difficulty = want,
        .need = need.need,
        .options = options,
        .played = p.played,
        .won = p.winner == p.hidden_team,
        .minutes = p.minutes,
    };
}

/// The damage type the four teammates lack, by their average magic share; null need
/// for a balanced team. Null when a teammate's damage type is unknown.
fn teamNeed(st: *const Stats, facts: Facts, p: daily.Puzzle) ?struct { need: ?Need } {
    var sum: f64 = 0;
    for (Role.all) |r| {
        if (r == p.hidden_role) continue;
        const c = st.index(p.teams[p.hidden_team][@backingInt(r)]) orelse return null;
        sum += facts.champs[c].magic orelse return null;
    }
    return .{ .need = switch (mixBucket(sum / 4)) {
        0 => .magic,
        mixes - 1 => .physical,
        else => null,
    } };
}

/// Clearly behind the lane opponent at lane_minute, by a curve with enough games
fn laneBehind(curves: ?*const curvesfile.Curves, role: Role, me: u32, them: u32) bool {
    const c = curves orelse return false;
    const v = c.get(role, .all, me, them) orelse return false;
    if (v.games() < lane_min_games) return false;
    return v.minute(curvesfile.lane_minute - 1).gold.p50 <= lane_behind_gold;
}

fn pickDistinct(from: []const u32, out: []u32, rand: std.Random) void {
    var idx: [candidates_len]usize = undefined;
    for (idx[0..from.len], 0..) |*x, i| x.* = i;
    rand.shuffle(usize, idx[0..from.len]);
    for (out, idx[0..out.len]) |*o, i| o.* = from[i];
}

/// Minutes with fewer games still going are cut off
const min_minute_games = 10;

fn laneCurve(
    arena: std.mem.Allocator,
    c: *const curvesfile.Curves,
    role: Role,
    me: u32,
    them: u32,
) !?LaneCurve {
    const v = c.get(role, .all, me, them) orelse return null;
    var gold: std.ArrayList(i16) = .empty;
    for (0..v.minutes()) |i| {
        const m = v.minute(i);
        if (m.n < min_minute_games) break;
        try gold.append(arena, m.gold.p50);
    }
    if (gold.items.len < 2) return null;
    return .{ .games = v.games(), .gold = gold.items };
}

const testing = std.testing;

/// 400 games among 40 champions, 8 per role (ids 8r+1..8r+8); odd ids deal magic
/// damage, even ones physical. Blue wins when its champions' ids sum higher, and odd
/// games are short.
fn testDb() !store.Db {
    const gpa = testing.allocator;
    const db = try store.schema.memory();
    errdefer db.close();
    for (1..41) |id| try db.run("INSERT INTO champions VALUES (?,?,?,'','v')", .{ id, "k", "n" });
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    var prng: std.Random.DefaultPrng = .init(7);
    const rand = prng.random();
    var buf: [32]u8 = undefined;
    for (0..400) |g| {
        const id = try std.mem.print(&buf, "EUW1_{d}", .{g});
        var teams: [2][5]u32 = undefined;
        var sums: [2]u32 = .{ 0, 0 };
        for (&teams, &sums) |*t, *sum| for (t, 0..) |*c, r| {
            c.* = @intCast(8 * r + 1 + rand.uintLessThan(u32, 8));
            sum.* += c.*;
        };
        // Same champion on both sides is impossible in ranked
        for (0..5) |r| if (teams[1][r] == teams[0][r]) {
            teams[1][r] = @intCast(8 * r + 1 + (teams[0][r] - 8 * r) % 8);
        };
        const blue_won = sums[0] >= sums[1];
        try db.run("INSERT INTO matches VALUES (?,'t','EUW1',420,'16.20','',?,?,?,0)", .{
            id, @as(i64, @intCast(g)), @as(i64, if (g % 2 == 1) 1200 else 2100), @as(i64, if (blue_won) 100 else 200),
        });
        var doc: std.Io.Writer.Allocating = .init(gpa);
        defer doc.deinit();
        try doc.writer.writeAll("{\"info\":{\"participants\":[");
        for (0..10) |slot| {
            const side = slot / 5;
            const c = teams[side][slot % 5];
            const won = (side == 0) == blue_won;
            try db.run(
                \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position,
                \\  win, kills, gold) VALUES (?,?,?,'p',?,?,?,1,1000)
            , .{ id, slot, @as(i64, if (side == 0) 100 else 200), c, positions[slot % 5], @intFromBool(won) });
            const magic: u32 = if (c % 2 == 1) 9000 else 500;
            if (slot > 0) try doc.writer.writeByte(',');
            try doc.writer.print(
                "{{\"championId\":{d},\"magicDamageDealtToChampions\":{d},\"physicalDamageDealtToChampions\":{d},\"trueDamageDealtToChampions\":0}}",
                .{ c, magic, 10000 - magic },
            );
        }
        try doc.writer.writeAll("]}}");
        const body = try store.raw.compress(gpa, doc.written());
        defer gpa.free(body);
        try db.run("INSERT INTO raw.raw_docs VALUES ('riot_match',?,0,?)", .{ id, store.Blob{ .bytes = body } });
        try db.run("INSERT INTO bans VALUES (?,100,1,?)", .{ id, @as(i64, @intCast(1 + g % 40)) });
    }
    try db.run("INSERT INTO players (puuid, tier, source) VALUES ('p','GOLD','t')", .{});
    return db;
}

test "facts and practice drafts" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const db = try testDb();
    defer db.close();
    var built = try stats.build(gpa, db, &.{"16.20"}, &.{"EUW1"});
    defer built.builder.deinit();
    var model: std.Io.Writer.Allocating = .init(arena);
    try built.builder.write(&model.writer, "16.20");
    var st: Stats = try .parse(arena, model.written());

    const l = try build(arena, testing.io, db, &st, null, .{
        .patches = &.{"16.20"},
        .platforms = &.{"EUW1"},
        .today = 20740,
    });
    try testing.expectEqual(400, l.facts.damage_games);
    const magic = l.facts.champs[st.index(1).?].magic.?;
    try testing.expectApproxEqAbs(0.9, magic, 0.001);
    try testing.expectApproxEqAbs(0.05, l.facts.champs[st.index(2).?].magic.?, 0.001);
    // Every game is 20 or 35 minutes, so the middle bucket is empty
    var short: u32 = 0;
    var long: u32 = 0;
    for (l.facts.champs) |ch| for (ch.length) |per_role| {
        short += per_role[0].games;
        try testing.expectEqual(0, per_role[1].games);
        long += per_role[2].games;
    };
    try testing.expectEqual(2000, short);
    try testing.expectEqual(2000, long);
    var teams: u32 = 0;
    for (l.facts.mix) |m| teams += m.games;
    try testing.expectEqual(800, teams);

    try testing.expectEqualStrings("learn/practice.json", l.files[1].path);
    const json = l.files[1].data;
    try testing.expect(std.mem.indexOf(u8, json, "EUW1_") == null);
    try testing.expect(std.mem.indexOf(u8, json, "\"p\"") == null);
    const pack = try std.json.parseFromSliceLeaky([]Practice, arena, json, .{});
    try testing.expect(pack.len > 0);
    var seen: [3]usize = @splat(0);
    for (pack) |p| {
        seen[@backingInt(p.difficulty)] += 1;
        var bring: usize = 0;
        for (p.options, 0..) |o, i| {
            for (p.options[i + 1 ..]) |other| try testing.expect(other.id != o.id);
            // The champion really played in the hidden slot may be one of them
            for (p.teams, 0..) |t, side| for (t, 0..) |c, r| {
                if (side == p.hidden_team and r == @backingInt(p.hidden_role)) continue;
                try testing.expect(c != o.id);
            };
            const m = o.magic.?;
            if (p.need) |n| {
                if ((n == .magic and m >= 60) or (n == .physical and m <= 40)) bring += 1;
            }
        }
        switch (p.difficulty) {
            .easy => try testing.expectEqual(1, bring),
            .medium => try testing.expectEqual(2, bring),
            .hard => try testing.expect(p.need == null),
        }
        try testing.expectEqual(p.played, p.teams[p.hidden_team][@backingInt(p.hidden_role)]);
        try testing.expect(daily.usualPicks(&st, p.teams));
    }
    for (seen) |n| try testing.expect(n > 0);
}

test "buckets" {
    try testing.expectEqual(0, lengthBucket(24));
    try testing.expectEqual(1, lengthBucket(25));
    try testing.expectEqual(2, lengthBucket(40));
    try testing.expectEqual(0, mixBucket(0.1));
    try testing.expectEqual(1, mixBucket(0.5));
    try testing.expectEqual(2, mixBucket(0.7));
}
