//! The lab agent's candidate interface (docs/lab-agent.md). A candidate is a module,
//! src/lab/cand/<campaign>/root.zig, that can import only std and this file. It fits on
//! the training games the harness hands it, then predicts one query at a time; a query
//! never carries an outcome, and carries other players' ranks only in post-game and
//! internal scope, their experience only in internal. Ranks are as of the day before the
//! game (rows.zig fillRankStart): every scope sees pre-game data only.
//!
//! A candidate declares:
//!   pub const scope: api.Scope
//!   pub const Model: type
//!   pub fn fit(gpa: std.mem.Allocator, train: *const api.Train, opts: api.Options) !Model
//!   pub fn predict(m: *const Model, q: *const api.Query) api.Prediction
//!   pub fn deinit(m: *Model, gpa: std.mem.Allocator) void
//! and optionally `pub const seeded = true` (the harness then averages 3 seeds),
//! `pub const after_game_rank = true` (rank_after below: dev runs only),
//! `pub const needs_stats = true` (fit refuses a training set whose Row.stats are all
//! NaN, so a missing SNAP/seat_stats.tsv fails instead of fitting without them),
//! `pub const needs_embeddings = true` (fit refuses to start without Options.embeddings)
//! and
//!   pub fn effects(m: *const Model, arena: std.mem.Allocator, target: Outcome) ![]const Effects
//! (what the fitted terms say about the game, in the target's units; the harness writes
//! each table to the run dir as effects-<name>.tsv)

const std = @import("std");

/// docs/model.md "Shared protocol": win is 0/1 for the row's team, the rest per player
pub const Outcome = enum { win, gold14, lanediff14, cs10, deaths15, first_item };
pub const outcome_count = @typeInfo(Outcome).@"enum".field_names.len;

/// Riot teamPosition order, as core.Role
pub const Role = enum(u3) { top, jungle, middle, bottom, utility };

/// docs/production-key.md: in champ select a model may use champions, roles, the user's
/// own rank and experience, and aggregate facts. Other players' ranks only post-game.
/// internal: Jacob's draft predictor, research only, never the site or app; sees
/// everyone's rank and experience
pub const Scope = enum { champ_select, post_game, internal };

/// A player's ranked solo games in our data that ended before this game started, on
/// this champion and on any. Only what was crawled: 0 can mean "not in our data"
pub const Experience = struct {
    champ_games: u16 = 0,
    champ_wins: u16 = 0,
    games: u16 = 0,
    wins: u16 = 0,
    /// Means over those games, 0 when none: (kills + assists) / max(deaths, 1) over
    /// `games`; lane gold diff at 14 and deaths before 15 over the perf_games of them
    /// that reached 15:00
    kda: f32 = 0,
    perf_games: u16 = 0,
    lanediff14: f32 = 0,
    deaths15: f32 = 0,
};

pub const Game = struct {
    /// Unix ms
    start: i64,
    patch: u32,
    platform: u8,
    /// Champion ids by side (0 blue) and role
    teams: [2][5]u32,
    /// Training covariates only; never in a champ-select query
    ranks: [2][5]?u8,
    /// Training covariates only; in a query in internal scope only
    exp: [2][5]Experience,
};

pub const Row = struct {
    /// Index into Train.games
    game: u32,
    side: u1,
    role: Role,
    champion: u32,
    /// Higher is better: 0 Iron IV .. 39 Challenger I; the ladder rank on a day before the
    /// game's; null unranked or unknown (rank history begins 2026-10-12)
    rank: ?u8,
    /// The rank looked up after the game, which knows recent results: only for a
    /// candidate declaring after_game_rank, in dev runs (a leak diagnostic), else null
    rank_after: ?u8 = null,
    exp: Experience,
    /// NaN when unknown (no timeline to minute 15, no completed item)
    y: [outcome_count]f32,
    /// What the player did this game (SeatStat): training rows only, never in a Query, so
    /// a candidate may average them into champion profiles but never see a scored game's
    stats: [seat_stat_count]f32 = @splat(std.math.nan(f32)),
};

/// Per player per game, raw values from the raw summary (SNAP/seat_stats.tsv,
/// `meiolol-lab seat-stats`); NaN when unknown. Damage to and from champions only.
/// From Data Dragon of the game's patch: armor_end, mr_end = two parts summed: the
/// champion's base + growth at level 15, plus the flat armour/MR of the items held at the
/// end of the game; ability resists (Rammus W, Malphite's passive) not included, though
/// builds mostly reflect them. attack_range the champion's base range. heal is Riot's
/// totalHeal, which includes heal_allies (totalHealsOnTeammates)
pub const SeatStat = enum {
    minutes,
    dmg_phys,
    dmg_magic,
    dmg_true,
    taken_phys,
    taken_magic,
    taken_true,
    mitigated,
    cc_time,
    immobilisations,
    heal,
    heal_allies,
    shield_allies,
    dmg_buildings,
    armor_end,
    mr_end,
    attack_range,
};
pub const seat_stat_count = @typeInfo(SeatStat).@"enum".field_names.len;

/// Every visible game older than the scored ones; rows of a game are adjacent
pub const Train = struct {
    games: []const Game,
    rows: []const Row,
};

/// One player in one game, as champ select knows it
pub const Query = struct {
    start: i64,
    patch: u32,
    platform: u8,
    side: u1,
    role: Role,
    champion: u32,
    /// The user's own rank, as Row.rank
    rank: ?u8,
    /// As Row.rank_after
    rank_after: ?u8 = null,
    /// Champion ids by side (0 blue) and role, the user included
    teams: [2][5]u32,
    /// Everyone's ranks: post_game and internal scope, null in champ_select
    ranks: ?[2][5]?u8,
    /// The user's own
    exp: Experience,
    /// Everyone's: internal scope only, null otherwise
    exps: ?[2][5]Experience,
};

pub const Options = struct {
    seed: u64 = 1,
    /// `meiolol-lab --emb DIR`: champion-role embeddings for a fit set, for a candidate declaring
    /// needs_embeddings; null otherwise
    embeddings: ?*const EmbeddingSource = null,
};

/// One champion-role's vector; champion 0 is the role's shared vector for champion-roles
/// the file has no own row for
pub const EmbeddingRow = struct {
    champion: u32,
    role: Role,
    /// Fit games of the set E was learnt on
    games: u32,
    e: []const f32,
};

pub const Embeddings = struct {
    dim: u32,
    rows: []const EmbeddingRow,

    pub fn deinit(e: *Embeddings, gpa: std.mem.Allocator) void {
        for (e.rows) |r| gpa.free(r.e);
        gpa.free(e.rows);
    }
};

/// The harness reads `meiolol-lab pretrain`'s files and returns the one learnt on exactly
/// this training set's games (per champion-role counts equal), else
/// error.NoEmbeddingsForFitSet: E never saw a game the candidate scores, and the candidate
/// does no IO. Any subset a candidate fits on (its own folds) can ask too
pub const EmbeddingSource = struct {
    ctx: *const anyopaque,
    forFitFn: *const fn (ctx: *const anyopaque, gpa: std.mem.Allocator, t: *const Train, seed: u64) anyerror!Embeddings,

    pub fn forFit(s: *const EmbeddingSource, gpa: std.mem.Allocator, t: *const Train, seed: u64) !Embeddings {
        return s.forFitFn(s.ctx, gpa, t, seed);
    }
};

/// Per outcome; win is the chance the user's team wins. NaN means "no opinion": the
/// harness scores the champion-role baseline there
pub const Prediction = [outcome_count]f32;

/// One level of a fitted term: "#<champion id>" in a label becomes the champion's name
pub const Effect = struct {
    label: []const u8,
    effect: f64,
    /// 95% half-width
    ci: f64,
    /// Training games behind it
    n: u32,
};

/// A term's effect table, e.g. own rank tier, or the top and bottom lane matchups
pub const Effects = struct {
    /// File stem: a-z 0-9 _ -
    name: []const u8,
    title: []const u8,
    /// gold, CS, deaths, min, win pp
    unit: []const u8,
    /// What a higher effect means, e.g. "more gold at 14 than the matchup average"
    higher: []const u8,
    rows: []const Effect,
};

pub const no_opinion: Prediction = @splat(std.math.nan(f32));

pub fn outcomeIndex(o: Outcome) usize {
    return @backingInt(o);
}

pub fn outcomeAt(k: usize) Outcome {
    return @fromBackingInt(@as(@typeInfo(Outcome).@"enum".tag_type, @intCast(k)));
}
