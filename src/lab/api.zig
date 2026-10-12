//! The lab agent's candidate interface (docs/lab-agent.md). A candidate is a module,
//! src/lab/cand/<campaign>/root.zig, that can import only std and this file. It fits on
//! the training games the harness hands it, then predicts one query at a time; a query
//! never carries an outcome, and carries other players' ranks only in post-game and
//! internal scope, their experience only in internal.
//!
//! A candidate declares:
//!   pub const scope: api.Scope
//!   pub const Model: type
//!   pub fn fit(gpa: std.mem.Allocator, train: *const api.Train, opts: api.Options) !Model
//!   pub fn predict(m: *const Model, q: *const api.Query) api.Prediction
//!   pub fn deinit(m: *Model, gpa: std.mem.Allocator) void
//! and optionally `pub const seeded = true` (the harness then averages 3 seeds) and
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
    /// Higher is better: 0 Iron IV .. 39 Challenger I; null unranked
    rank: ?u8,
    exp: Experience,
    /// NaN when unknown (no timeline to minute 15, no completed item)
    y: [outcome_count]f32,
};

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
    /// The user's own rank
    rank: ?u8,
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
