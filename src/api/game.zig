//! One player's games laid over the lane curves: per-game lane numbers and facts, the
//! weekly roll-up and per-matchup trend. Facts only, never advice (docs/concept.md);
//! the page words them.

const std = @import("std");
const core = @import("core");
const riot = @import("../riot/root.zig");
const curves_build = @import("../curves.zig");
const winchance = @import("../winchance.zig");
const statemodel = @import("../statemodel.zig");
const livestate = @import("../livestate.zig");
const Date = @import("../date.zig").Date;

const Allocator = std.mem.Allocator;
const Role = core.Role;
const curvesfile = core.curvesfile;
const timeline = riot.timeline;

/// What we keep of a match-v5 document: champions, positions and results; no names or
/// Riot IDs, PUUIDs only as `hashPuuid`. Index in `players` = slot (participant id - 1)
pub const Summary = struct {
    patch: []const u8,
    queue: i64,
    start_ms: i64,
    duration_s: i64,
    remake: bool,
    players: []const Player,

    pub const Player = struct {
        hash: []const u8,
        team: i64,
        position: []const u8,
        champion: u32,
        win: bool,
        kills: i64,
        deaths: i64,
        assists: i64,
    };

    pub fn slotOf(s: Summary, hash: []const u8) ?u8 {
        for (s.players, 0..) |p, i| if (std.mem.eql(u8, p.hash, hash)) return @intCast(i);
        return null;
    }
};

pub const hash_len = 32;

/// First 16 bytes of SHA-256, hex. Finds a looked-up player's slot in a cached match
/// without keeping the other nine PUUIDs in the clear
pub fn hashPuuid(out: *[hash_len]u8, puuid: []const u8) []const u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(puuid, &digest, .{});
    out.* = std.fmt.bytesToHex(digest[0..16], .lower);
    return out;
}

pub fn summarise(arena: Allocator, body: []const u8) !Summary {
    const doc = try riot.match.parse(arena, body);
    const info = doc.info;
    const players = try arena.alloc(Summary.Player, info.participants.len);
    for (info.participants, players) |p, *out| {
        const hash = try arena.create([hash_len]u8);
        out.* = .{
            .hash = hashPuuid(hash, p.puuid orelse ""),
            .team = p.teamId,
            .position = p.teamPosition orelse "",
            .champion = std.math.cast(u32, p.championId) orelse return error.BadMatch,
            .win = p.win,
            .kills = p.kills orelse 0,
            .deaths = p.deaths orelse 0,
            .assists = p.assists orelse 0,
        };
    }
    return .{
        .patch = riot.match.patchOf(info.gameVersion),
        .queue = info.queueId,
        .start_ms = info.gameStartTimestamp orelse info.gameCreation,
        .duration_s = riot.match.durationS(doc),
        .remake = riot.match.isRemake(doc),
        .players = players,
    };
}

/// One player's Riot ID from a match-v5 document, as at that game, with their PUUID for
/// the caller's blocked check. Index = slot
pub const Named = struct { puuid: ?[]const u8, riot_id: ?[]const u8 };

pub fn riotIds(arena: Allocator, body: []const u8) ![]const Named {
    const Doc = struct { info: struct { participants: []const struct {
        puuid: ?[]const u8 = null,
        riotIdGameName: ?[]const u8 = null,
        riotIdTagline: ?[]const u8 = null,
    } } };
    const doc = try std.json.parseFromSliceLeaky(Doc, arena, body, .{ .ignore_unknown_fields = true });
    const out = try arena.alloc(Named, doc.info.participants.len);
    for (doc.info.participants, out) |p, *o| {
        const name = p.riotIdGameName orelse "";
        const tag = p.riotIdTagline orelse "";
        o.* = .{
            .puuid = p.puuid,
            .riot_id = if (name.len == 0 or tag.len == 0) null else try arena.print("{s}#{s}", .{ name, tag }),
        };
    }
    return out;
}

/// Curves files by patch label ("16.20", or "16.19-16.20" for a range)
pub const CurveSet = struct {
    files: []const File = &.{},
    /// Sorted legendary item ids (ddragon.legendaries) for first-item timing; empty
    /// leaves it out
    legendaries: []const u32 = &.{},

    pub const File = struct { label: []const u8, curves: curvesfile.Curves };

    /// The file covering `patch`, preferring the narrowest; else the newest. The page
    /// shows which patch a curve came from
    pub fn forPatch(s: CurveSet, patch: []const u8) ?*const File {
        var best: ?*const File = null;
        var best_span: u32 = std.math.maxInt(u32);
        for (s.files) |*f| {
            const r = patchRange(f.label) orelse continue;
            const p = patchNum(patch) orelse continue;
            if (p < r[0] or p > r[1]) continue;
            if (r[1] - r[0] < best_span) {
                best = f;
                best_span = r[1] - r[0];
            }
        }
        if (best) |b| return b;
        for (s.files) |*f| {
            const r = patchRange(f.label) orelse continue;
            if (best == null or r[1] > patchRange(best.?.label).?[1]) best = f;
        }
        return best;
    }

    /// u16 parts: a patch from Riot's gameVersion can't overflow it
    fn patchNum(p: []const u8) ?u32 {
        const dot = std.mem.findScalar(u8, p, '.') orelse return null;
        const major = std.fmt.parseInt(u16, p[0..dot], 10) catch return null;
        const minor = std.fmt.parseInt(u16, p[dot + 1 ..], 10) catch return null;
        return @as(u32, major) * 100 + minor;
    }

    pub fn patchRange(label: []const u8) ?[2]u32 {
        if (std.mem.findScalar(u8, label, '-')) |dash| {
            return .{ patchNum(label[0..dash]) orelse return null, patchNum(label[dash + 1 ..]) orelse return null };
        }
        const p = patchNum(label) orelse return null;
        return .{ p, p };
    }
};

/// The player's visible solo queue tier (league-v4), never inferred MMR
pub const Rank = struct {
    tier: ?[]const u8 = null,
    division: ?[]const u8 = null,
    lp: ?i64 = null,

    pub fn bracket(r: Rank) curvesfile.Bracket {
        const t = r.tier orelse return .all;
        return .ofRank(curvesfile.tierRank(t) orelse return .all);
    }
};

/// Lane phase ends here: the curves' "wins lane" minute
const lane_end = curvesfile.lane_minute;
/// Minutes per stretch when looking for the biggest change against typical
const stretch_len = 3;
/// Smaller changes are noise, not a fact worth showing
const min_stretch_gold = 200;
/// Curve minutes with fewer games than this are not drawn (as on the matchup pages)
const min_minute_games = 10;

pub const Report = struct {
    games: []const Game,
    weeks: []const Week,
    matchups: []const Matchup,
};

pub const Game = struct {
    start_ms: i64,
    /// Riot queue id: 420 solo/duo, 440 flex, 400 draft, 480 Swiftplay
    queue: i64,
    patch: []const u8,
    duration_s: i64,
    remake: bool,
    win: bool,
    role: ?[]const u8,
    champion: u32,
    opponent: ?u32,
    kills: i64,
    deaths: i64,
    assists: i64,
    lane: ?LaneReport,
    /// Your team's chance to win at each minute's frame, percent; index 0 is the start.
    /// Empty without a timeline
    /// u16, not u8: std.json writes a u8 slice as a string
    win_chance: []const u16 = &.{},
    turning: ?Turn = null,
    death_costs: []const Death = &.{},
    /// Fights and objectives you were in, in time order
    moments: []const Moment = &.{},
    /// First blood, tower, dragon and Baron of the game, whoever took them
    firsts: []const First = &.{},
    /// The minute you earned most gold
    best_minute: ?BestMinute = null,
    /// Everyone in the game by slot, with their Riot ID as at the game where the
    /// service has it (the example has none)
    players: []const Seat = &.{},
};

pub const Seat = struct {
    riot_id: ?[]const u8,
    team: i64,
    role: ?[]const u8,
    champion: u32,
    kills: i64,
    deaths: i64,
    assists: i64,
    you: bool,
};

/// A fight (champion kills close in time and place, one of them yours: a kill, an
/// assist or your death) or an objective you took part in or one in your lane
pub const Moment = struct {
    kind: enum { fight, objective },
    t_s: u32,
    end_s: u32,
    /// "top", "mid", "bot", "river", "your jungle", "enemy jungle", "your base",
    /// "enemy base"
    where: []const u8,
    /// Champions of each team that died in the fight
    kills: u32 = 0,
    deaths: u32 = 0,
    /// Enemy champions you killed or helped kill
    your_kills: []const u32 = &.{},
    died: bool = false,
    /// Champion that killed you; null for a turret, minion or monster
    killer: ?u32 = null,
    /// Kill gold (bounty and shutdown) to your team minus to the enemy
    gold: i32 = 0,
    /// Objective moments: what was taken ("Voidgrub x3"), by your team or not, and
    /// whether you took part
    objective: ?[]const u8 = null,
    ours: bool = false,
    with_you: bool = false,
    /// Objectives each team took from the start to `death_window_ms` after the end
    taken: []const []const u8 = &.{},
    lost: []const []const u8 = &.{},
    /// Your team's win chance at the frames before and after, percent
    before: ?u16 = null,
    after: ?u16 = null,
};

pub const First = struct {
    what: []const u8,
    t_s: u32,
    ours: bool,
    /// You got it, helped or (first blood) died
    you: bool,
    died: bool = false,
};

pub const BestMinute = struct {
    /// Between frames minute - 1 and minute
    minute: u8,
    gold: i32,
    kills: u32,
    deaths: u32,
    taken: []const []const u8,
};

/// Kills further apart in time or place are separate fights (map units, about 15k a
/// side)
const fight_gap_ms = 15_000;
const fight_range = 3000;

/// The minute your team's win chance moved most
pub const Turn = struct {
    /// Between frames minute - 1 and minute
    minute: u8,
    from: u16,
    to: u16,
    /// Champion kills that minute by your team and of your team
    kills: u32,
    deaths: u32,
    /// Kills you took part in and your deaths that minute
    your_kills: u32,
    your_deaths: u32,
    /// Objectives your team and the enemy team took that minute
    taken: []const []const u8,
    lost: []const []const u8,
};

/// One of your deaths and what followed
pub const Death = struct {
    t_s: u32,
    /// Champion that got the kill; null for a turret, minion or monster
    killer: ?u32,
    assists: u32,
    /// Bounty and shutdown gold the enemy got for it
    gold: u32,
    /// Objectives the enemy team took in the next `death_window_ms`
    lost: []const []const u8,
    /// Your team's win chance at the frames before and after, percent
    before: ?u16,
    after: ?u16,
};

const death_window_ms = 60_000;
const plates_fall_ms = 14 * 60_000;

pub const LaneReport = struct {
    /// Minute i + 1, you minus your lane opponent
    gold: []const i16,
    xp: []const i16,
    cs: []const i16,
    /// Your own CS (lane + jungle) at 10 min
    cs10: ?i32,
    /// Seconds to level 6, yours and theirs; null when not reached
    level6: [2]?u16,
    /// Seconds to the first finished legendary item, yours and theirs
    first_item: [2]?u16,
    /// Before lane_end: your deaths, and kills you took part in
    lane_deaths: u32,
    lane_kills: u32,
    curve: ?CurveReport,
    /// Biggest fall and rise over `stretch_len` minutes in the lane phase, measured
    /// against the typical median when there is a curve, else against an even lane
    fall: ?Stretch,
    rise: ?Stretch,
};

pub const CurveReport = struct {
    patch: []const u8,
    bracket: []const u8,
    /// True when your tier's bracket was too thin and all ranks are shown instead
    pooled: bool,
    games: u32,
    /// Per minute: games still going, then [p25, p50, p75] from your side
    n: []const u32,
    gold: []const [3]i16,
    xp: []const [3]i16,
    cs: []const [3]i16,
    /// Typical seconds to level 6 and to the first legendary item, yours and theirs;
    /// null when unknown
    level6: [2]?u16,
    first_item: [2]?u16,
};

pub const Stretch = struct {
    from: u8,
    to: u8,
    /// Gold change against the reference over the stretch
    change: i32,
    against: []const u8,
    deaths: u32,
    kills: u32,
};

pub const Week = struct {
    /// Monday, "2026-10-05"
    start: []const u8,
    games: u32,
    wins: u32,
    /// Games with a lane opponent that reached lane_end
    lane_games: u32,
    /// Mean gold difference at lane_end
    gold14: ?i32,
    /// Mean of (your gold difference - typical median) at lane_end, over lane games with
    /// a curve
    vs_typical14: ?i32,
    curve_games: u32,
};

pub const Matchup = struct {
    role: []const u8,
    champion: u32,
    opponent: u32,
    games: u32,
    wins: u32,
    /// Oldest first
    points: []const Point,

    pub const Point = struct { start_ms: i64, gold10: ?i16, vs_typical10: ?i32 };
};

pub const Input = struct {
    summary: Summary,
    slot: u8,
    /// Compact timeline (decoded); null when Riot had none
    timeline: ?timeline.Timeline,
    /// Match id prefix ("EUW1") for the win chance's platform term; "" unknown
    platform: []const u8 = "",
    /// By slot, null unknown; empty when none are known
    riot_ids: []const ?[]const u8 = &.{},
};

/// `games` newest first
pub fn report(arena: Allocator, games: []const Input, rank: Rank, set: CurveSet) !Report {
    var out: std.ArrayList(Game) = .empty;
    for (games) |in| try out.append(arena, try analyse(arena, in, rank, set));
    return .{
        .games = out.items,
        .weeks = try weeks(arena, out.items),
        .matchups = try matchups(arena, out.items),
    };
}

pub fn analyse(arena: Allocator, in: Input, rank: Rank, set: CurveSet) !Game {
    const s = in.summary;
    const me = s.players[in.slot];
    const role = Role.fromLcu(me.position);
    var g: Game = .{
        .start_ms = s.start_ms,
        .queue = s.queue,
        .patch = s.patch,
        .duration_s = s.duration_s,
        .remake = s.remake,
        .win = me.win,
        .role = if (role) |r| r.label() else null,
        .champion = me.champion,
        .opponent = null,
        .kills = me.kills,
        .deaths = me.deaths,
        .assists = me.assists,
        .lane = null,
        .players = try seats(arena, s, in.slot, in.riot_ids),
    };
    if (!s.remake) if (in.timeline) |t| try wholeGame(arena, s, in.slot, t, in.platform, set.legendaries, &g);
    const r = role orelse return g;
    const opp_slot = for (s.players, 0..) |p, i| {
        if (p.team != me.team and std.mem.eql(u8, p.position, me.position)) break i;
    } else return g;
    g.opponent = s.players[opp_slot].champion;
    if (s.remake) return g;
    const t = in.timeline orelse return g;
    const my_id = in.slot + 1;
    const opp_id: u8 = @intCast(opp_slot + 1);
    if (@max(my_id, opp_id) > t.participants) return g;

    // Blue as a, as the curves are built; flip to my side after
    const blue = me.team == 100;
    var game: curves_build.Game = .{ .ids = @splat(@splat(0)), .champions = @splat(@splat(0)), .bracket = rank.bracket() };
    const ri = @backingInt(r);
    game.ids[0][ri] = if (blue) my_id else opp_id;
    game.ids[1][ri] = if (blue) opp_id else my_id;
    game.champions[0][ri] = if (blue) me.champion else g.opponent.?;
    game.champions[1][ri] = if (blue) g.opponent.? else me.champion;
    const blue_won = me.win == blue;
    const l = curves_build.lane(t, game, r, blue_won, set.legendaries);
    const sign: i16 = if (blue) 1 else -1;

    var lr: LaneReport = .{
        .gold = try mine(arena, l.gold[0..l.minutes], sign),
        .xp = try mine(arena, l.xp[0..l.minutes], sign),
        .cs = try mine(arena, l.cs[0..l.minutes], sign),
        .cs10 = null,
        .level6 = .{ nonZero(if (blue) l.level6_a else l.level6_b), nonZero(if (blue) l.level6_b else l.level6_a) },
        .first_item = .{ nonZero(if (blue) l.first_item_a else l.first_item_b), nonZero(if (blue) l.first_item_b else l.first_item_a) },
        .lane_deaths = 0,
        .lane_kills = 0,
        .curve = null,
        .fall = null,
        .rise = null,
    };
    if (t.frames.len >= 12) {
        const f = t.frames[10];
        lr.cs10 = f.get(my_id, .minions) + f.get(my_id, .jungle_minions);
    }
    lr.lane_deaths = countDeaths(t, my_id, 0, lane_end);
    lr.lane_kills = countKills(t, my_id, 0, lane_end);
    if (set.forPatch(s.patch)) |file| lr.curve = try curveReport(arena, file, r, rank.bracket(), me.champion, g.opponent.?);
    lr.fall = stretch(t, my_id, lr.gold, lr.curve, .fall);
    lr.rise = stretch(t, my_id, lr.gold, lr.curve, .rise);
    g.lane = lr;
    return g;
}

fn seats(arena: Allocator, s: Summary, slot: u8, riot_ids: []const ?[]const u8) ![]const Seat {
    const out = try arena.alloc(Seat, s.players.len);
    for (s.players, out, 0..) |p, *o, i| o.* = .{
        .riot_id = if (i < riot_ids.len) riot_ids[i] else null,
        .team = p.team,
        .role = if (Role.fromLcu(p.position)) |r| r.label() else null,
        .champion = p.champion,
        .kills = p.kills,
        .deaths = p.deaths,
        .assists = p.assists,
        .you = i == slot,
    };
    return out;
}

/// Blue's win chance by minute from 0: statemodel (state, items, timers and champions)
/// when each side has its five roles, else winchance (team gold and objectives)
fn blueChances(arena: Allocator, s: Summary, t: timeline.Timeline, platform: []const u8, legendaries: []const u32) ![]const f64 {
    if (t.participants == 10 and s.players.len == 10) seats: {
        var teams: [10]i64 = undefined;
        var positions: [10][]const u8 = undefined;
        var champions: [10]u32 = undefined;
        for (s.players, &teams, &positions) |p, *team, *pos| {
            team.* = p.team;
            pos.* = p.position;
        }
        const seat_of = statemodel.Game.seats(teams, positions) orelse break :seats;
        for (s.players, seat_of) |p, seat| champions[seat] = p.champion;
        return statemodel.chances(arena, statemodel.shipped(), .{
            .t = t,
            .seat_of = seat_of,
            .champions = champions,
            .platform = platform,
            .items = .sorted(&legendaries),
        });
    }
    var out: std.ArrayList(f64) = .empty;
    var m: u8 = 0;
    while (m < 255) : (m += 1) try out.append(arena, winchance.blue(t, m) orelse break);
    return out.items;
}

/// Win chance, turning minute and death cost: the whole game, not only the lane
fn wholeGame(arena: Allocator, s: Summary, slot: u8, t: timeline.Timeline, platform: []const u8, legendaries: []const u32, g: *Game) !void {
    if (t.participants != s.players.len) return;
    const team = s.players[slot].team;
    const me: u8 = slot + 1;
    var chance: std.ArrayList(u16) = .empty;
    for (try blueChances(arena, s, t, platform, legendaries)) |p| {
        const mine_p = if (team == 100) p else 1 - p;
        try chance.append(arena, @round(100 * mine_p));
    }
    g.win_chance = chance.items;

    var best: ?u8 = null;
    for (1..chance.items.len) |i| {
        const change = @abs(@as(i32, chance.items[i]) - chance.items[i - 1]);
        if (best == null or change > @abs(@as(i32, chance.items[best.?]) - chance.items[best.? - 1])) best = @intCast(i);
    }
    if (best) |b| {
        var turn: Turn = .{
            .minute = b,
            .from = chance.items[b - 1],
            .to = chance.items[b],
            .kills = 0,
            .deaths = 0,
            .your_kills = 0,
            .your_deaths = 0,
            .taken = &.{},
            .lost = &.{},
        };
        const from_ms = @as(i64, b - 1) * 60_000;
        for (t.events) |e| if (e.t_ms >= from_ms and e.t_ms < from_ms + 60_000) switch (e.data) {
            .champion_kill => |k| {
                if (k.victim == 0 or k.victim > s.players.len) continue;
                const theirs = s.players[k.victim - 1].team != team;
                if (theirs) turn.kills += 1 else turn.deaths += 1;
                if (k.victim == me) turn.your_deaths += 1;
                if (involved(me, k.killer, k.assists)) turn.your_kills += 1;
            },
            else => {},
        };
        turn.taken = try objectivesBy(arena, t, team, from_ms, from_ms + 60_000, true);
        turn.lost = try objectivesBy(arena, t, team, from_ms, from_ms + 60_000, false);
        g.turning = turn;
    }

    var deaths: std.ArrayList(Death) = .empty;
    for (t.events) |e| switch (e.data) {
        .champion_kill => |k| if (k.victim == me) {
            const minute: usize = @intCast(@divFloor(e.t_ms, 60_000));
            try deaths.append(arena, .{
                .t_s = @intCast(@divFloor(e.t_ms, 1000)),
                .killer = if (k.killer >= 1 and k.killer <= s.players.len) s.players[k.killer - 1].champion else null,
                .assists = @intCast(k.assists.len),
                .gold = k.bounty + k.shutdown,
                .lost = try objectivesBy(arena, t, team, e.t_ms, e.t_ms + death_window_ms, false),
                .before = if (minute < chance.items.len) chance.items[minute] else null,
                .after = if (minute + 1 < chance.items.len) chance.items[minute + 1] else null,
            });
        },
        else => {},
    };
    g.death_costs = deaths.items;
    g.moments = try yourMoments(arena, s, slot, t, chance.items);
    g.firsts = try firsts(arena, s, slot, t);
    g.best_minute = try bestMinute(arena, s, slot, t);
}

const Fight = struct {
    first: usize,
    last_ms: i64,
    x: i32,
    y: i32,
    mine: bool,
    kills: std.ArrayList(usize) = .empty,
};

fn involved(me: u8, killer: u8, assists: []const u8) bool {
    return killer == me or std.mem.findScalar(u8, assists, me) != null;
}

fn yourMoments(arena: Allocator, s: Summary, slot: u8, t: timeline.Timeline, chance: []const u16) ![]const Moment {
    const team = s.players[slot].team;
    const me: u8 = slot + 1;
    const blue = team == 100;
    var fights: std.ArrayList(Fight) = .empty;
    for (t.events, 0..) |e, i| switch (e.data) {
        .champion_kill => |k| {
            if (k.victim == 0 or k.victim > s.players.len) continue;
            const yours = k.victim == me or involved(me, k.killer, k.assists);
            const open = for (fights.items) |*f| {
                if (e.t_ms - f.last_ms > fight_gap_ms) continue;
                const dx: i64 = k.x - f.x;
                const dy: i64 = k.y - f.y;
                if (dx * dx + dy * dy <= fight_range * fight_range) break f;
            } else null;
            const f = open orelse blk: {
                try fights.append(arena, .{ .first = i, .last_ms = e.t_ms, .x = k.x, .y = k.y, .mine = false });
                break :blk &fights.items[fights.items.len - 1];
            };
            f.last_ms = e.t_ms;
            f.mine = f.mine or yours;
            try f.kills.append(arena, i);
        },
        else => {},
    };

    var out: std.ArrayList(Moment) = .empty;
    for (fights.items) |f| {
        if (!f.mine) continue;
        const start_ms = t.events[f.first].t_ms;
        var m: Moment = .{ .kind = .fight, .t_s = seconds(start_ms), .end_s = seconds(f.last_ms), .where = "" };
        var mine_k: std.ArrayList(u32) = .empty;
        var at_me: ?timeline.Event = null;
        for (f.kills.items) |i| {
            const k = t.events[i].data.champion_kill;
            const gold: i32 = @intCast(k.bounty + k.shutdown);
            if (s.players[k.victim - 1].team != team) {
                m.kills += 1;
                m.gold += gold;
                if (involved(me, k.killer, k.assists)) {
                    try mine_k.append(arena, s.players[k.victim - 1].champion);
                    at_me = at_me orelse t.events[i];
                }
            } else {
                m.deaths += 1;
                m.gold -= gold;
                if (k.victim == me) {
                    m.died = true;
                    m.killer = if (k.killer >= 1 and k.killer <= s.players.len) s.players[k.killer - 1].champion else null;
                    at_me = at_me orelse t.events[i];
                }
            }
        }
        m.your_kills = mine_k.items;
        const pos = (at_me orelse t.events[f.first]).data.champion_kill;
        m.where = area(pos.x, pos.y, blue);
        m.taken = try objectivesBy(arena, t, team, start_ms, f.last_ms + death_window_ms, true);
        m.lost = try objectivesBy(arena, t, team, start_ms, f.last_ms + death_window_ms, false);
        m.before, m.after = around(chance, start_ms, f.last_ms);
        try out.append(arena, m);
    }

    const fight_moments = out.items.len;
    const lane = laneOf(s.players[slot].position);
    for (t.events) |e| {
        const label: []const u8, const taker: i64, const with_you: bool, const where: []const u8 = switch (e.data) {
            .building_kill => |b| blk: {
                const near = lane.len > 0 and std.mem.eql(u8, b.lane, lane);
                const you = involved(me, b.killer, b.assists);
                if (!near and !you) continue;
                break :blk .{ try buildingLabel(arena, b.building, b.lane, b.tower), 300 - @as(i64, b.team), you, laneWhere(b.lane, b.team == team) };
            },
            .elite_monster => |em| blk: {
                const name = monsterLabel(em.monster, em.subtype) orelse continue;
                const you = involved(me, em.killer, em.assists);
                const big = std.mem.eql(u8, name, "Baron") or std.mem.eql(u8, name, "Elder dragon") or std.mem.eql(u8, name, "Atakhan");
                if (!you and !big) continue;
                break :blk .{ name, @as(i64, em.team), you, "river" };
            },
            else => continue,
        };
        if (taker != 100 and taker != 200) continue;
        const ours = taker == team;
        // Taken during or right after one of your fights: that fight's outcome
        const covered = for (out.items[0..fight_moments]) |f| {
            const end_ms = @as(i64, f.end_s) * 1000 + death_window_ms;
            if (e.t_ms >= @as(i64, f.t_s) * 1000 and e.t_ms < end_ms) break true;
        } else false;
        if (covered) continue;
        if (out.items.len > fight_moments) {
            // Voidgrubs a few seconds apart are one moment
            const last = &out.items[out.items.len - 1];
            if (last.ours == ours and e.t_ms - @as(i64, last.end_s) * 1000 < death_window_ms and std.mem.startsWith(u8, last.objective.?, label)) {
                const n = if (std.mem.find(u8, last.objective.?, " x")) |x| try std.fmt.parseInt(u32, last.objective.?[x + 2 ..], 10) else 1;
                last.objective = try arena.print("{s} x{d}", .{ label, n + 1 });
                last.end_s = seconds(e.t_ms);
                last.with_you = last.with_you or with_you;
                last.after = around(chance, e.t_ms, e.t_ms)[1];
                continue;
            }
        }
        var m: Moment = .{ .kind = .objective, .t_s = seconds(e.t_ms), .end_s = seconds(e.t_ms), .where = where, .objective = label, .ours = ours, .with_you = with_you };
        m.before, m.after = around(chance, e.t_ms, e.t_ms);
        try out.append(arena, m);
    }
    std.mem.sort(Moment, out.items, {}, struct {
        fn earlier(_: void, a: Moment, b: Moment) bool {
            return a.t_s < b.t_s;
        }
    }.earlier);
    return out.items;
}

fn seconds(t_ms: i64) u32 {
    return @intCast(@divFloor(@max(t_ms, 0), 1000));
}

/// Win chance at the frame before `from_ms` and the one after `to_ms`
fn around(chance: []const u16, from_ms: i64, to_ms: i64) struct { ?u16, ?u16 } {
    const a: usize = @intCast(@divFloor(@max(from_ms, 0), 60_000));
    const b: usize = @as(usize, @intCast(@divFloor(@max(to_ms, 0), 60_000))) + 1;
    return .{ if (a < chance.len) chance[a] else null, if (b < chance.len) chance[b] else if (chance.len > 0) chance[chance.len - 1] else null };
}

fn laneOf(position: []const u8) []const u8 {
    const eql = std.mem.eql;
    if (eql(u8, position, "TOP")) return "TOP_LANE";
    if (eql(u8, position, "MIDDLE")) return "MID_LANE";
    if (eql(u8, position, "BOTTOM") or eql(u8, position, "UTILITY")) return "BOT_LANE";
    return "";
}

fn laneWhere(lane: []const u8, own_building: bool) []const u8 {
    const eql = std.mem.eql;
    if (eql(u8, lane, "TOP_LANE")) return "top";
    if (eql(u8, lane, "MID_LANE")) return "mid";
    if (eql(u8, lane, "BOT_LANE")) return "bot";
    return if (own_building) "your base" else "enemy base";
}

/// Rough Summoner's Rift areas: blue's base at (0, 0), red's at the far corner, top
/// lane up the left and along the top, bot along the bottom and up the right, mid on
/// the diagonal, the river across it
fn area(x: i32, y: i32, blue: bool) []const u8 {
    const in_blue_base = x < 4500 and y < 4500;
    const in_red_base = x > 10400 and y > 10400;
    if (in_blue_base or in_red_base) return if (in_blue_base == blue) "your base" else "enemy base";
    if (x < 2200 or y > 12600 or (x < 4000 and y > 10900)) return "top";
    if (y < 2200 or x > 12600 or (x > 10900 and y < 4000)) return "bot";
    if (@abs(x - y) < 1300) return "mid";
    if (@abs(x + y - 14800) < 1200) return "river";
    return if ((x + y < 14800) == blue) "your jungle" else "enemy jungle";
}

fn firsts(arena: Allocator, s: Summary, slot: u8, t: timeline.Timeline) ![]const First {
    const team = s.players[slot].team;
    const me: u8 = slot + 1;
    var out: std.ArrayList(First) = .empty;
    var seen: [4]bool = @splat(false);
    for (t.events) |e| {
        const which: usize, const f: First = switch (e.data) {
            .champion_kill => |k| blk: {
                if (k.victim == 0 or k.victim > s.players.len) continue;
                const ours = s.players[k.victim - 1].team != team;
                break :blk .{ 0, .{ .what = "First blood", .t_s = seconds(e.t_ms), .ours = ours, .you = k.victim == me or involved(me, k.killer, k.assists), .died = k.victim == me } };
            },
            .building_kill => |b| blk: {
                if (!std.mem.eql(u8, b.building, "TOWER_BUILDING")) continue;
                break :blk .{ 1, .{ .what = "First tower", .t_s = seconds(e.t_ms), .ours = b.team != team, .you = involved(me, b.killer, b.assists) } };
            },
            .elite_monster => |em| blk: {
                if (em.team != 100 and em.team != 200) continue;
                const i: usize, const what: []const u8 = if (std.mem.eql(u8, em.monster, "DRAGON")) .{ 2, "First dragon" } else if (std.mem.eql(u8, em.monster, "BARON_NASHOR")) .{ 3, "First Baron" } else continue;
                break :blk .{ i, .{ .what = what, .t_s = seconds(e.t_ms), .ours = em.team == team, .you = involved(me, em.killer, em.assists) } };
            },
            else => continue,
        };
        if (seen[which]) continue;
        seen[which] = true;
        try out.append(arena, f);
    }
    return out.items;
}

fn bestMinute(arena: Allocator, s: Summary, slot: u8, t: timeline.Timeline) !?BestMinute {
    const me: u8 = slot + 1;
    var best: ?BestMinute = null;
    for (1..t.frames.len) |m| {
        const gold = t.frames[m].get(me, .total_gold) - t.frames[m - 1].get(me, .total_gold);
        if (best == null or gold > best.?.gold) best = .{ .minute = @intCast(m), .gold = gold, .kills = 0, .deaths = 0, .taken = &.{} };
    }
    var b = best orelse return null;
    const from_ms = @as(i64, b.minute - 1) * 60_000;
    b.kills = countKills(t, me, b.minute - 1, b.minute);
    b.deaths = countDeaths(t, me, b.minute - 1, b.minute);
    b.taken = try objectivesBy(arena, t, s.players[slot].team, from_ms, from_ms + 60_000, true);
    return b;
}

/// Objectives taken in [from_ms, to_ms) by `team` (`ours`) or by the other team, as
/// labels; repeats folded into "Turret plate x3"
fn objectivesBy(arena: Allocator, t: timeline.Timeline, team: i64, from_ms: i64, to_ms: i64, ours: bool) ![]const []const u8 {
    var labels: std.ArrayList([]const u8) = .empty;
    var counts: std.ArrayList(u32) = .empty;
    for (t.events) |e| {
        if (e.t_ms < from_ms) continue;
        if (e.t_ms >= to_ms) break;
        const taker: i64, const label: []const u8 = switch (e.data) {
            // team owns the building or plate: the other team took it
            .building_kill => |b| .{ 300 - @as(i64, b.team), try buildingLabel(arena, b.building, b.lane, b.tower) },
            // Plates fall at 14:00; Riot still sends plate events after, several when a
            // tower dies, worth nothing then
            .turret_plate => |p| if (e.t_ms < plates_fall_ms) .{ 300 - @as(i64, p.team), "Turret plate" } else continue,
            .elite_monster => |em| .{ em.team, monsterLabel(em.monster, em.subtype) orelse continue },
            else => continue,
        };
        // Only a side's own takes: a monster with no killing team (300, 0) is nobody's
        if (taker != 100 and taker != 200) continue;
        if ((taker == team) != ours) continue;
        for (labels.items, counts.items) |l, *n| {
            if (std.mem.eql(u8, l, label)) {
                n.* += 1;
                break;
            }
        } else {
            try labels.append(arena, label);
            try counts.append(arena, 1);
        }
    }
    for (labels.items, counts.items) |*l, n| if (n > 1) {
        l.* = try arena.print("{s} x{d}", .{ l.*, n });
    };
    return labels.items;
}

fn buildingLabel(arena: Allocator, building: []const u8, lane: []const u8, tower: []const u8) ![]const u8 {
    const where: []const u8 = if (std.mem.eql(u8, lane, "TOP_LANE")) "Top" else if (std.mem.eql(u8, lane, "MID_LANE")) "Mid" else if (std.mem.eql(u8, lane, "BOT_LANE")) "Bot" else "Base";
    if (std.mem.eql(u8, building, "INHIBITOR_BUILDING")) return arena.print("{s} inhibitor", .{where});
    const which: []const u8 = if (std.mem.eql(u8, tower, "OUTER_TURRET")) "outer" else if (std.mem.eql(u8, tower, "INNER_TURRET")) "inner" else if (std.mem.eql(u8, tower, "BASE_TURRET")) "base" else if (std.mem.eql(u8, tower, "NEXUS_TURRET")) return "Nexus tower" else "";
    return arena.print("{s} {s} tower", .{ where, which });
}

fn monsterLabel(monster: []const u8, subtype: []const u8) ?[]const u8 {
    const eql = std.mem.eql;
    if (eql(u8, monster, "BARON_NASHOR")) return "Baron";
    if (eql(u8, monster, "RIFTHERALD")) return "Rift Herald";
    if (eql(u8, monster, "HORDE")) return "Voidgrub";
    if (eql(u8, monster, "ATAKHAN")) return "Atakhan";
    if (!eql(u8, monster, "DRAGON")) return null;
    const dragons = [_][2][]const u8{
        .{ "FIRE_DRAGON", "Infernal dragon" },   .{ "WATER_DRAGON", "Ocean dragon" },
        .{ "EARTH_DRAGON", "Mountain dragon" },  .{ "AIR_DRAGON", "Cloud dragon" },
        .{ "HEXTECH_DRAGON", "Hextech dragon" }, .{ "CHEMTECH_DRAGON", "Chemtech dragon" },
        .{ "ELDER_DRAGON", "Elder dragon" },
    };
    for (dragons) |d| if (eql(u8, subtype, d[0])) return d[1];
    return "Dragon";
}

fn mine(arena: Allocator, diffs: []const i16, sign: i16) ![]i16 {
    const out = try arena.alloc(i16, diffs.len);
    for (diffs, out) |d, *o| o.* = d * sign;
    return out;
}

fn nonZero(v: u16) ?u16 {
    return if (v == 0) null else v;
}

fn curveReport(arena: Allocator, file: *const CurveSet.File, r: Role, bracket: curvesfile.Bracket, me: u32, them: u32) !?CurveReport {
    var pooled = false;
    const v = file.curves.get(r, bracket, me, them) orelse blk: {
        if (bracket == .all) return null;
        pooled = true;
        break :blk file.curves.get(r, .all, me, them) orelse return null;
    };
    const m = v.minutes();
    const n = try arena.alloc(u32, m);
    const gold = try arena.alloc([3]i16, m);
    const xp = try arena.alloc([3]i16, m);
    const cs = try arena.alloc([3]i16, m);
    for (0..m) |i| {
        const mi = v.minute(i);
        n[i] = mi.n;
        gold[i] = .{ mi.gold.p25, mi.gold.p50, mi.gold.p75 };
        xp[i] = .{ mi.xp.p25, mi.xp.p50, mi.xp.p75 };
        cs[i] = .{ mi.cs.p25, mi.cs.p50, mi.cs.p75 };
    }
    const l6 = v.level6();
    const fi = v.firstItem();
    return .{
        .patch = file.label,
        .bracket = (if (pooled) curvesfile.Bracket.all else bracket).label(),
        .pooled = pooled,
        .games = v.games(),
        .n = n,
        .gold = gold,
        .xp = xp,
        .cs = cs,
        .level6 = .{ nonZero(l6[0]), nonZero(l6[1]) },
        .first_item = .{ nonZero(fi[0]), nonZero(fi[1]) },
    };
}

/// Typical median gold difference at minute `m` (1-based); 0 at minute 0
fn typical(c: CurveReport, m: usize) ?i32 {
    if (m == 0) return 0;
    if (m > c.n.len or c.n[m - 1] < min_minute_games) return null;
    return c.gold[m - 1][1];
}

/// Gold difference against the reference at minute `m` (1-based); 0 at minute 0
fn against(gold: []const i16, curve: ?CurveReport, m: usize) ?i32 {
    if (m == 0) return 0;
    if (m > gold.len) return null;
    const ref = if (curve) |c| typical(c, m) orelse return null else 0;
    return @as(i32, gold[m - 1]) - ref;
}

fn stretch(t: timeline.Timeline, me: u8, gold: []const i16, curve: ?CurveReport, which: enum { fall, rise }) ?Stretch {
    var best: ?Stretch = null;
    var to: usize = stretch_len;
    while (to <= @min(lane_end, gold.len)) : (to += 1) {
        const from = to - stretch_len;
        const a = against(gold, curve, from) orelse continue;
        const b = against(gold, curve, to) orelse continue;
        const change = b - a;
        const better = if (best) |cur| (if (which == .fall) change < cur.change else change > cur.change) else true;
        if (!better) continue;
        best = .{
            .from = @intCast(from),
            .to = @intCast(to),
            .change = change,
            .against = if (curve != null) "typical" else "even",
            .deaths = countDeaths(t, me, from, to),
            .kills = countKills(t, me, from, to),
        };
    }
    const s = best orelse return null;
    const big = if (which == .fall) s.change <= -min_stretch_gold else s.change >= min_stretch_gold;
    return if (big) s else null;
}

/// Deaths of `p` in [from, to) minutes
fn countDeaths(t: timeline.Timeline, p: u8, from: usize, to: usize) u32 {
    var n: u32 = 0;
    for (t.events) |e| switch (e.data) {
        .champion_kill => |k| if (k.victim == p and inMinutes(e.t_ms, from, to)) {
            n += 1;
        },
        else => {},
    };
    return n;
}

/// Kills `p` took part in (killer or assist) in [from, to) minutes
fn countKills(t: timeline.Timeline, p: u8, from: usize, to: usize) u32 {
    var n: u32 = 0;
    for (t.events) |e| switch (e.data) {
        .champion_kill => |k| if (inMinutes(e.t_ms, from, to) and
            involved(p, k.killer, k.assists))
        {
            n += 1;
        },
        else => {},
    };
    return n;
}

fn inMinutes(t_ms: i64, from: usize, to: usize) bool {
    return t_ms >= @as(i64, @intCast(from)) * 60_000 and t_ms < @as(i64, @intCast(to)) * 60_000;
}

/// Monday of the game's week (UTC), "2026-10-05"
fn weekStart(buf: *[10]u8, start_ms: i64) []const u8 {
    const day = @divFloor(start_ms, std.time.ms_per_day);
    // 1 January 1970 was a Thursday
    const monday = day - @mod(day + 3, 7);
    return std.mem.print(buf, "{f}", .{Date.fromDay(monday)}) catch unreachable;
}

fn atMinute(gold: []const i16, m: usize) ?i16 {
    return if (m <= gold.len and m > 0) gold[m - 1] else null;
}

fn weeks(arena: Allocator, games: []const Game) ![]Week {
    var out: std.ArrayList(Week) = .empty;
    var sums: std.ArrayList([2]i64) = .empty;
    for (games) |g| {
        if (g.remake) continue;
        var buf: [10]u8 = undefined;
        const start = weekStart(&buf, g.start_ms);
        const i = for (out.items, 0..) |w, i| {
            if (std.mem.eql(u8, w.start, start)) break i;
        } else blk: {
            try out.append(arena, .{
                .start = try arena.dupe(u8, start),
                .games = 0,
                .wins = 0,
                .lane_games = 0,
                .gold14 = null,
                .vs_typical14 = null,
                .curve_games = 0,
            });
            try sums.append(arena, .{ 0, 0 });
            break :blk out.items.len - 1;
        };
        const w = &out.items[i];
        w.games += 1;
        w.wins += @intFromBool(g.win);
        const l = g.lane orelse continue;
        const gold = atMinute(l.gold, lane_end) orelse continue;
        w.lane_games += 1;
        sums.items[i][0] += gold;
        const c = l.curve orelse continue;
        const ref = typical(c, lane_end) orelse continue;
        w.curve_games += 1;
        sums.items[i][1] += gold - ref;
    }
    for (out.items, sums.items) |*w, s| {
        if (w.lane_games > 0) w.gold14 = @intCast(@divTrunc(s[0], w.lane_games));
        if (w.curve_games > 0) w.vs_typical14 = @intCast(@divTrunc(s[1], w.curve_games));
    }
    return out.items;
}

fn matchups(arena: Allocator, games: []const Game) ![]Matchup {
    var out: std.ArrayList(Matchup) = .empty;
    var points: std.ArrayList(std.ArrayList(Matchup.Point)) = .empty;
    // Oldest first, so each matchup's points are in time order
    var i = games.len;
    while (i > 0) {
        i -= 1;
        const g = games[i];
        if (g.remake) continue;
        const role = g.role orelse continue;
        const opp = g.opponent orelse continue;
        const at = for (out.items, 0..) |m, j| {
            if (m.champion == g.champion and m.opponent == opp and std.mem.eql(u8, m.role, role)) break j;
        } else blk: {
            try out.append(arena, .{ .role = role, .champion = g.champion, .opponent = opp, .games = 0, .wins = 0, .points = &.{} });
            try points.append(arena, .empty);
            break :blk out.items.len - 1;
        };
        out.items[at].games += 1;
        out.items[at].wins += @intFromBool(g.win);
        var p: Matchup.Point = .{ .start_ms = g.start_ms, .gold10 = null, .vs_typical10 = null };
        if (g.lane) |l| {
            p.gold10 = atMinute(l.gold, 10);
            if (l.curve) |c| if (p.gold10) |gold| if (typical(c, 10)) |ref| {
                p.vs_typical10 = gold - ref;
            };
        }
        try points.items[at].append(arena, p);
    }
    for (out.items, points.items) |*m, p| m.points = p.items;
    std.mem.sort(Matchup, out.items, {}, struct {
        fn more(_: void, a: Matchup, b: Matchup) bool {
            return a.games > b.games;
        }
    }.more);
    return out.items;
}

const testing = std.testing;

test {
    _ = statemodel;
}

test "riot ids by slot, seats name only those known" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const body = @embedFile("../riot/testdata/match.json");
    const named = try riotIds(arena, body);
    try testing.expectEqual(@as(usize, 10), named.len);
    try testing.expectEqualStrings("player1#player1", named[1].riot_id.?);
    try testing.expectEqualStrings("puuid-1", named[1].puuid.?);

    const s = try summarise(arena, body);
    const ids = [_]?[]const u8{ "A#1", null };
    const players = try seats(arena, s, 1, &ids);
    try testing.expectEqualStrings("A#1", players[0].riot_id.?);
    try testing.expect(players[1].riot_id == null and players[1].you and !players[0].you);
    try testing.expect(players[9].riot_id == null);
    try testing.expectEqual(s.players[9].champion, players[9].champion);

    const odd = try std.mem.replaceOwned(u8, arena, body, "\"championId\":122", "\"championId\":-1");
    try testing.expectError(error.BadMatch, summarise(arena, odd));
}

test weekStart {
    var buf: [10]u8 = undefined;
    // Sunday 11 October 2026 12:00 UTC -> Monday 5 October
    try testing.expectEqualStrings("2026-10-05", weekStart(&buf, 1791720000000));
    // Monday 5 October 2026 00:00 UTC
    try testing.expectEqualStrings("2026-10-05", weekStart(&buf, 1791158400000));
}

test "curve set picks the covering file, else the newest" {
    const set: CurveSet = .{ .files = &.{
        .{ .label = "16.19-16.20", .curves = undefined },
        .{ .label = "16.20", .curves = undefined },
        .{ .label = "16.18", .curves = undefined },
    } };
    try testing.expectEqualStrings("16.20", set.forPatch("16.20").?.label);
    try testing.expectEqualStrings("16.19-16.20", set.forPatch("16.19").?.label);
    try testing.expectEqualStrings("16.18", set.forPatch("16.18").?.label);
    try testing.expectEqualStrings("16.19-16.20", set.forPatch("16.21").?.label);
    try testing.expectEqualStrings("16.19-16.20", set.forPatch("99999999.1").?.label);
    try testing.expect((CurveSet{}).forPatch("16.20") == null);
}

fn testSummary(arena: Allocator) !Summary {
    const players = try arena.alloc(Summary.Player, 10);
    for (players, 0..) |*p, i| p.* = .{
        .hash = "",
        .team = if (i < 5) 100 else 200,
        .position = Role.positions[i % 5],
        .champion = @intCast(i + 1),
        .win = i < 5,
        .kills = 0,
        .deaths = 0,
        .assists = 0,
    };
    return .{ .patch = "16.20", .queue = 420, .start_ms = 1791720000000, .duration_s = 1800, .remake = false, .players = players };
}

test "win chance: statemodel with every role, winchance without" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const raw = try @import("store").raw.decompress(arena, @embedFile("../riot/testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, raw);
    const s = try testSummary(arena);
    const full = try blueChances(arena, s, t, "EUW1", &.{});
    try testing.expect(full[0] > 0 and full[0] < 1 and full[0] != 0.5);
    try testing.expect(full.len > lane_end);
    const players = try arena.dupe(Summary.Player, s.players);
    players[3].position = "";
    var partial = s;
    partial.players = players;
    const old = try blueChances(arena, partial, t, "EUW1", &.{});
    try testing.expectEqual(full.len, old.len);
    for (old, 0..) |p, m| try testing.expectEqual(winchance.blue(t, @intCast(m)).?, p);
    try testing.expect(full[10] != old[10]);
}

test "a real timeline from both sides, with and without a curve" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const raw = try @import("store").raw.decompress(arena, @embedFile("../riot/testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, raw);
    const s = try testSummary(arena);

    const blue = try analyse(arena, .{ .summary = s, .slot = 0, .timeline = t }, .{}, .{});
    const red = try analyse(arena, .{ .summary = s, .slot = 5, .timeline = t }, .{ .tier = "GOLD" }, .{});
    try testing.expectEqualStrings("top", blue.role.?);
    try testing.expectEqual(@as(?u32, 6), blue.opponent);
    const bl = blue.lane.?;
    const rl = red.lane.?;
    try testing.expect(bl.gold.len >= lane_end);
    for (bl.gold, rl.gold) |b, r| try testing.expectEqual(b, -r);
    try testing.expectEqual(bl.level6[0], rl.level6[1]);
    try testing.expect(bl.cs10.? > 0);
    try testing.expect(bl.curve == null);
    // Against an even lane, the fall and rise mirror each other
    if (bl.fall) |f| try testing.expectEqual(f.change, -rl.rise.?.change);

    // A curve of this very game: nothing differs from typical
    var b: curvesfile.Builder = .{ .gpa = testing.allocator };
    defer b.deinit();
    var g: curves_build.Game = .{ .ids = @splat(@splat(0)), .champions = @splat(@splat(0)), .bracket = .mid };
    g.ids = .{ .{ 1, 2, 3, 4, 5 }, .{ 6, 7, 8, 9, 10 } };
    g.champions = .{ .{ 1, 2, 3, 4, 5 }, .{ 6, 7, 8, 9, 10 } };
    try b.addLane(curves_build.lane(t, g, .top, true, &.{}));
    b.addGame();
    var aw: std.Io.Writer.Allocating = .init(arena);
    try b.write(&aw.writer, "16.20", 1);
    const set: CurveSet = .{ .files = &.{.{ .label = "16.20", .curves = try .parse(arena, aw.written()) }} };

    const with = try analyse(arena, .{ .summary = s, .slot = 5, .timeline = t }, .{ .tier = "GOLD" }, set);
    const c = with.lane.?.curve.?;
    try testing.expectEqualStrings("Gold to Emerald", c.bracket);
    try testing.expect(!c.pooled);
    try testing.expectEqual(@as(u32, 1), c.games);
    // One game: below min_minute_games, so no stretch is measured against it
    try testing.expect(with.lane.?.fall == null and with.lane.?.rise == null);
    for (rl.gold[0..lane_end], c.gold[0..lane_end]) |mine_gold, q| try testing.expectEqual(mine_gold, q[1]);

    // Whole game: win chance from both sides adds up, deaths match the lane count
    try testing.expect(blue.win_chance.len > lane_end);
    for (blue.win_chance, red.win_chance) |b_pct, r_pct| try testing.expect(@abs(@as(i32, b_pct) + r_pct - 100) <= 1);
    // 0:00 is the champions alone, not a flat 50
    try testing.expect(blue.win_chance[0] > 0 and blue.win_chance[0] < 100);
    const json = try std.json.Stringify.valueAlloc(arena, blue, .{});
    const start = try arena.print("\"win_chance\":[{d},", .{blue.win_chance[0]});
    try testing.expect(std.mem.find(u8, json, start) != null);
    const turn = blue.turning.?;
    try testing.expectEqual(turn.minute, red.turning.?.minute);
    try testing.expectEqual(turn.taken.len, red.turning.?.lost.len);
    var early: u32 = 0;
    for (blue.death_costs) |d| early += @intFromBool(d.t_s < lane_end * 60);
    try testing.expectEqual(bl.lane_deaths, early);
    for (blue.death_costs) |d| try testing.expect(d.killer == null or d.killer.? > 5);

    // Your moments: in time order, each fight with you in it; firsts are the same events
    // from both sides
    try testing.expect(blue.moments.len > 0);
    var your_deaths: u32 = 0;
    for (blue.moments, 0..) |m, i| {
        if (i > 0) try testing.expect(m.t_s >= blue.moments[i - 1].t_s);
        try testing.expect(m.end_s >= m.t_s and m.where.len > 0);
        if (m.kind == .fight) try testing.expect(m.kills + m.deaths > 0 and (m.died or m.your_kills.len > 0));
        your_deaths += @intFromBool(m.died);
    }
    try testing.expectEqual(blue.death_costs.len, your_deaths);
    try testing.expectEqual(blue.firsts.len, red.firsts.len);
    for (blue.firsts, red.firsts) |a, z| {
        try testing.expectEqualStrings(a.what, z.what);
        try testing.expect(a.ours != z.ours);
    }
    try testing.expect(blue.best_minute.?.gold > 0);

    const unranked = try analyse(arena, .{ .summary = s, .slot = 5, .timeline = t }, .{}, set);
    try testing.expectEqualStrings("All games", unranked.lane.?.curve.?.bracket);

    const r = try report(arena, &.{ .{ .summary = s, .slot = 0, .timeline = t }, .{ .summary = s, .slot = 0, .timeline = null } }, .{}, .{});
    try testing.expectEqual(@as(usize, 1), r.weeks.len);
    try testing.expectEqual(@as(u32, 2), r.weeks[0].games);
    try testing.expectEqual(@as(u32, 1), r.weeks[0].lane_games);
    try testing.expectEqual(@as(usize, 1), r.matchups.len);
    try testing.expectEqual(@as(usize, 2), r.matchups[0].points.len);
}
