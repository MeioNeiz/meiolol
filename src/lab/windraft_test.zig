//! win-draft (src/lab/cand/win-draft) copies the shipped draft model, as a candidate
//! imports only std and api: same games in, same blue log-odds as score.draftTerms with
//! Options defaults. Fails when score.zig's model or defaults move without the copy

const std = @import("std");
const core = @import("core");
const api = @import("api");
const win_draft = @import("win_draft");

test "win-draft agrees with score.zig's defaults" {
    const gpa = std.testing.allocator;
    var prng: std.Random.DefaultPrng = .init(7);
    const rand = prng.random();

    var ids: [14]u32 = undefined;
    var champions: [ids.len]core.statsfile.Champion = undefined;
    for (&ids, &champions, 0..) |*id, *c, i| {
        id.* = @intCast(i + 1);
        c.* = .{ .id = id.*, .name = "c" };
    }
    var builder: core.statsfile.Builder = try .init(gpa, &champions);
    defer builder.deinit();

    const games = try gpa.alloc(api.Game, 4000);
    defer gpa.free(games);
    const rows = try gpa.alloc(api.Row, games.len);
    defer gpa.free(rows);
    for (games, rows, 0..) |*g, *row, i| {
        rand.shuffle(u32, &ids);
        const teams: [2][5]u32 = .{ ids[0..5].*, ids[5..10].* };
        // Low ids win more, so the terms aren't all near zero
        const edge = @as(f64, @floatFromInt(teams[1][0])) - @as(f64, @floatFromInt(teams[0][0]));
        const blue_won = rand.float(f64) < 0.5 + 0.02 * edge;
        builder.addGame(teams, if (blue_won) 0 else 1);
        g.* = .{
            .start = 0,
            .patch = 0,
            .platform = 0,
            .teams = teams,
            .ranks = @splat(@splat(null)),
            .exp = @splat(@splat(.{})),
        };
        var y: [api.outcome_count]f32 = @splat(std.math.nan(f32));
        y[api.outcomeIndex(.win)] = if (blue_won) 1 else 0;
        row.* = .{ .game = @intCast(i), .side = 0, .role = .top, .champion = teams[0][0], .rank = null, .exp = .{}, .y = y };
    }

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try builder.write(&aw.writer, "test");
    var stats: core.Stats = try .parse(gpa, aw.written());
    defer stats.deinit(gpa);

    var m = try win_draft.fit(gpa, &.{ .games = games, .rows = rows }, .{});
    defer win_draft.deinit(&m, gpa);

    const opts: core.Options = .{};
    // Training drafts, then unseen ones with an empty slot and a champion neither knows
    for (games[0..200]) |g| {
        const want = core.score.draftTerms(&stats, opts, g.teams).weighted(opts.weights);
        try std.testing.expectApproxEqAbs(want, win_draft.blueLogit(&m, g.teams), 1e-9);
    }
    for (0..200) |_| {
        rand.shuffle(u32, &ids);
        var teams: [2][5]u32 = .{ ids[0..5].*, ids[5..10].* };
        teams[rand.uintLessThan(usize, 2)][rand.uintLessThan(usize, 5)] = 0;
        teams[1][rand.uintLessThan(usize, 5)] = 99;
        const want = core.score.draftTerms(&stats, opts, teams).weighted(opts.weights);
        try std.testing.expectApproxEqAbs(want, win_draft.blueLogit(&m, teams), 1e-9);
    }
}
