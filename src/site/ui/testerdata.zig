//! The Draft tester's models (docs/plan/ui/draft-tester.md) as ui.wasm reads them:
//! draft-model.bin, the draft-model.json export (draftfile.ModelFile) encoded with
//! data.zig. Scored by core's draftscore, the code the box and the lab score with, so the
//! page's numbers are the model's
const std = @import("std");
const ds = @import("core").draftscore;
const data = @import("data.zig");

pub const n_role = ds.n_role;

/// Where the model came from and how it scored on held-out games
pub const Meta = struct {
    name: []const u8,
    run: []const u8,
    snapshot: []const u8,
    /// yyyy-mm-dd
    newest_game: []const u8,
    training_games: u32,
    /// The play shares' patch and its games; the training games' first and last patch
    patch: []const u8,
    patch_games: u32,
    oldest_patch: []const u8,
    newest_patch: []const u8,
    platform: []const u8,
    dev: Dev,
};

pub const Dev = struct {
    games: u32,
    log_loss: f64,
    baseline_log_loss: f64,
    accuracy: f64,
    auc: f64,
};

pub const Champion = struct { id: u32, name: []const u8 };

/// A champion-role with training games, or play on the share patch
pub const Cell = struct {
    champion: u32,
    role: u8,
    games: u32,
    patch_share: f64,
};

pub const Model = struct {
    meta: Meta,
    /// The candidate list's floor: games in the role
    min_games: u32,
    /// By name
    champions: []const Champion,
    cells: []const Cell,
    /// One intercept: the file's platform
    params: ds.Params,
    /// The exporter's own scores of a few drafts (draft-ref.json): the page checks itself
    refs: []const Ref,

    pub fn encode(m: Model, a: std.mem.Allocator, out: *std.ArrayList(u8)) !void {
        try data.encode(a, Model, m, out);
    }

    pub fn decode(a: std.mem.Allocator, bytes: []const u8) data.Error!Model {
        return data.decode(a, Model, bytes);
    }

    /// The scorer, its role averages from the cells' play shares as the export's
    pub fn scorer(m: *const Model, a: std.mem.Allocator) !ds.Scorer {
        var shares: Shares = .{};
        try shares.map.ensureTotalCapacity(a, @intCast(m.cells.len));
        for (m.cells) |c| shares.map.putAssumeCapacity(ds.termKey(c.champion, c.role), c.patch_share);
        return ds.Scorer.init(a, m.params, 0, &shares);
    }

    /// The largest gap between the scorer and the exporter on the reference drafts
    pub fn check(m: *const Model, sc: *const ds.Scorer) Check {
        var worst: f64 = 0;
        for (m.refs) |r| {
            const c = sc.blue(r.teams);
            // Written so a NaN gap (a NaN parameter) counts as the worst, not as none
            for ([_]f64{ c.p - r.blue.p, c.lo - r.blue.lo, c.hi - r.blue.hi }) |d| {
                if (!(@abs(d) <= worst)) worst = if (std.math.isNan(d)) std.math.inf(f64) else @abs(d);
            }
        }
        return .{ .drafts = @intCast(m.refs.len), .worst = worst };
    }

    pub fn name(m: *const Model, id: u32) []const u8 {
        for (m.champions) |c| if (c.id == id) return c.name;
        return "?";
    }
};

pub const Ref = struct {
    label: []const u8,
    /// By side (0 blue) and role; 0 empty
    teams: [2][n_role]u32,
    blue: ds.Chance,
};

pub const Check = struct {
    drafts: u32,
    worst: f64,

    /// draftfile.RefFile's tolerance
    pub fn ok(c: Check) bool {
        return c.drafts > 0 and c.worst <= 1e-9;
    }
};

const Shares = struct {
    map: std.AutoHashMapUnmanaged(u64, f64) = .empty,

    pub fn patchShare(s: *const Shares, champion: u32, role: usize) f64 {
        return s.map.get(ds.termKey(champion, role)) orelse 0;
    }
};

const testing = std.testing;

test "model: encode, decode and score as the parameters say" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const terms = [_]ds.Term{
        .{ .champion = 1, .role = 0, .games = 500, .b = 0.2, .sd = 0.1 },
        .{ .champion = 2, .role = 0, .games = 500, .b = -0.1, .sd = 0.1 },
    };
    const groups = [_]ds.PairGroup{.{ .name = "top", .kind = "matchup", .r = 0, .q = 0, .sd = 0.1, .fitted = 1, .shipped = 1 }};
    const cells = [_]ds.PairCell{.{ .group = 0, .a = 1, .b = 2, .theta = 0.05, .games = 300 }};
    const m: Model = .{
        .meta = .{ .name = "test", .run = "r", .snapshot = "s", .newest_game = "2026-10-26", .training_games = 1000, .patch = "16.21", .patch_games = 500, .oldest_patch = "16.20", .newest_patch = "16.21", .platform = "EUW1", .dev = .{ .games = 100, .log_loss = 0.68, .baseline_log_loss = 0.69, .accuracy = 0.55, .auc = 0.57 } },
        .min_games = 100,
        .champions = &.{ .{ .id = 1, .name = "Aatrox" }, .{ .id = 2, .name = "Darius" } },
        .cells = &.{ .{ .champion = 1, .role = 0, .games = 500, .patch_share = 0.75 }, .{ .champion = 2, .role = 0, .games = 500, .patch_share = 0.25 } },
        .params = .{ .kind = "ratings", .dim = 0, .intercept = &.{0.01}, .w = @splat(0), .z = @splat(0), .terms = &terms, .pairs = .{ .min_games = 100, .groups = &groups, .cells = &cells } },
        .refs = &.{.{ .label = "top only", .teams = .{ .{ 1, 0, 0, 0, 0 }, .{ 2, 0, 0, 0, 0 } }, .blue = .{ .p = 0.5, .lo = 0.5, .hi = 0.5 } }},
    };
    var out: std.ArrayList(u8) = .empty;
    try m.encode(a, &out);
    const back = try Model.decode(a, out.items);
    try testing.expectEqualStrings("Darius", back.name(2));
    const sc = try back.scorer(a);
    // The made-up reference is off: the check says so
    try testing.expect(!back.check(&sc).ok());
    var teams: [2][n_role]u32 = @splat(@splat(0));
    teams[0][0] = 1;
    teams[1][0] = 2;
    // 0.01 + 0.2 - (-0.1) + the matchup cell 0.05 (blue has the lower id)
    // The intercept is an f32, as exported
    try testing.expectApproxEqAbs(1 / (1 + @exp(@as(f64, -0.36))), sc.blue(teams).p, 1e-8);
    // An empty slot: the role's share-weighted average, 0.75 * 0.2 + 0.25 * -0.1 = 0.125
    teams[1][0] = 0;
    try testing.expectApproxEqAbs(1 / (1 + @exp(@as(f64, -(0.01 + 0.2 - 0.125)))), sc.blue(teams).p, 1e-9);
}

test "model: a cut file, a bad term and a NaN parameter are refused" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // sd 0: the reference's range is its chance
    const terms = [_]ds.Term{.{ .champion = 1, .role = 0, .games = 500, .b = 0.2, .sd = 0 }};
    var m: Model = .{
        .meta = .{ .name = "t", .run = "r", .snapshot = "s", .newest_game = "2026-10-26", .training_games = 1, .patch = "16.21", .patch_games = 1, .oldest_patch = "16.21", .newest_patch = "16.21", .platform = "EUW1", .dev = .{ .games = 1, .log_loss = 0.69, .baseline_log_loss = 0.69, .accuracy = 0.5, .auc = 0.5 } },
        .min_games = 100,
        .champions = &.{.{ .id = 1, .name = "Aatrox" }},
        .cells = &.{.{ .champion = 1, .role = 0, .games = 500, .patch_share = 1 }},
        .params = .{ .kind = "ratings", .dim = 0, .intercept = &.{0}, .w = @splat(0), .z = @splat(0), .terms = &terms },
        .refs = &.{.{ .label = "top", .teams = .{ .{ 1, 0, 0, 0, 0 }, .{ 0, 0, 0, 0, 0 } }, .blue = .{ .p = 0.5, .lo = 0.5, .hi = 0.5 } }},
    };
    var out: std.ArrayList(u8) = .empty;
    try m.encode(a, &out);
    try testing.expectError(error.Truncated, Model.decode(a, out.items[0 .. out.items.len - 3]));
    // Blue's only champion over the average of itself: 0, as the reference says
    try testing.expect(m.check(&try m.scorer(a)).ok());
    m.params.temperature = std.math.nan(f64);
    try testing.expect(!m.check(&try m.scorer(a)).ok());
    m.params.temperature = 1;
    const bad = [_]ds.Term{.{ .champion = 1, .role = 5, .games = 500, .b = 0.2, .sd = 0.1 }};
    m.params.terms = &bad;
    try testing.expectError(error.BadTerm, m.scorer(a));
}
