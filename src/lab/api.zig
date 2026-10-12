//! The lab agent's candidate interface (docs/lab-agent.md). A candidate is a module,
//! src/lab/cand/<campaign>/root.zig, that can import only std and this file. It fits on
//! the training games the harness hands it, then predicts one query at a time; a query
//! never carries an outcome, and carries other players' ranks only in post-game scope.
//!
//! A candidate declares:
//!   pub const scope: api.Scope
//!   pub const Model: type
//!   pub fn fit(gpa: std.mem.Allocator, train: *const api.Train, opts: api.Options) !Model
//!   pub fn predict(m: *const Model, q: *const api.Query) api.Prediction
//!   pub fn deinit(m: *Model, gpa: std.mem.Allocator) void
//! and optionally `pub const seeded = true` (the harness then averages 3 seeds)

const std = @import("std");

/// docs/model.md "Shared protocol": win is 0/1 for the row's team, the rest per player
pub const Outcome = enum { win, gold14, lanediff14, cs10, deaths15, first_item };
pub const outcome_count = @typeInfo(Outcome).@"enum".field_names.len;

/// Riot teamPosition order, as core.Role
pub const Role = enum(u3) { top, jungle, middle, bottom, utility };

/// docs/production-key.md: in champ select a model may use champions, roles, the user's
/// own rank and experience, and aggregate facts. Other players' ranks only post-game
pub const Scope = enum { champ_select, post_game };

pub const Game = struct {
    /// Unix ms
    start: i64,
    patch: u32,
    platform: u8,
    /// Champion ids by side (0 blue) and role
    teams: [2][5]u32,
    /// Training covariates only; never in a champ-select query
    ranks: [2][5]?u8,
};

pub const Row = struct {
    /// Index into Train.games
    game: u32,
    side: u1,
    role: Role,
    champion: u32,
    /// Higher is better: 0 Iron IV .. 39 Challenger I; null unranked
    rank: ?u8,
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
    /// Everyone's ranks: post_game scope only, null in champ_select
    ranks: ?[2][5]?u8,
};

pub const Options = struct {
    seed: u64 = 1,
};

/// Per outcome; win is the chance the user's team wins. NaN means "no opinion": the
/// harness scores the champion-role baseline there
pub const Prediction = [outcome_count]f32;

pub const no_opinion: Prediction = @splat(std.math.nan(f32));

pub fn outcomeIndex(o: Outcome) usize {
    return @backingInt(o);
}

pub fn outcomeAt(k: usize) Outcome {
    return @fromBackingInt(@as(@typeInfo(Outcome).@"enum".tag_type, @intCast(k)));
}
