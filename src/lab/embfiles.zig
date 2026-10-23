//! api.EmbeddingSource over a `meiolol-lab pretrain` output dir (`meiolol-lab --emb DIR`): of the
//! files emb-<block>-s<seed>.tsv, the one whose fit games equal the training set's, per
//! champion-role (own rows) and per role (champion 0 rows: the champion-roles without an
//! own row). Anything else fails, so a candidate never gets E learnt on a game it scores

const std = @import("std");
const api = @import("api");
const Io = std.Io;
const Allocator = std.mem.Allocator;

/// pretrain's blocks: dev-val, the 5 forward folds, and final (every non-test game, for
/// a test look)
const blocks = [_][]const u8{ "dev", "1", "2", "3", "4", "5", "final" };

pub const Dir = struct {
    io: Io,
    path: []const u8,

    pub fn source(d: *const Dir) api.EmbeddingSource {
        return .{ .ctx = d, .forFitFn = forFit };
    }
};

fn key(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

fn forFit(ctx: *const anyopaque, gpa: Allocator, t: *const api.Train, seed: u64) anyerror!api.Embeddings {
    const d: *const Dir = @ptrCast(@alignCast(ctx));
    var counts: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer counts.deinit(gpa);
    for (t.games) |g| for (g.teams) |team| for (team, 0..) |c, r| {
        (try counts.getOrPutValue(gpa, key(c, r), 0)).value_ptr.* += 1;
    };
    for (blocks) |b| {
        const path = try gpa.print("{s}/emb-{s}-s{d}.tsv", .{ d.path, b, seed });
        defer gpa.free(path);
        const text = Io.Dir.cwd().readFileAlloc(d.io, path, gpa, .limited(64 << 20)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer gpa.free(text);
        var e = try parse(gpa, text);
        if (try matches(gpa, &e, &counts)) {
            std.debug.print("embeddings: {s} ({d} games)\n", .{ path, t.games.len });
            return e;
        }
        e.deinit(gpa);
    }
    std.debug.print("embeddings: no emb-*-s{d}.tsv in {s} was learnt on these {d} games\n", .{ seed, d.path, t.games.len });
    return error.NoEmbeddingsForFitSet;
}

fn matches(gpa: Allocator, e: *const api.Embeddings, counts: *const std.AutoHashMapUnmanaged(u64, u32)) !bool {
    var own: std.AutoHashMapUnmanaged(u64, void) = .empty;
    defer own.deinit(gpa);
    var shared: [5]u64 = @splat(0);
    var shared_seen: [5]bool = @splat(false);
    for (e.rows) |r| {
        const role: usize = @backingInt(r.role);
        if (r.champion == 0) {
            shared[role] = r.games;
            shared_seen[role] = true;
            continue;
        }
        if ((counts.get(key(r.champion, role)) orelse 0) != r.games) return false;
        try own.put(gpa, key(r.champion, role), {});
    }
    var rest: [5]u64 = @splat(0);
    var it = counts.iterator();
    while (it.next()) |kv| if (!own.contains(kv.key_ptr.*)) {
        rest[kv.key_ptr.* & 7] += kv.value_ptr.*;
    };
    for (shared, shared_seen, rest) |s, seen, r| if (!seen or s != r) return false;
    return true;
}

/// champion, role, fit_games, e0..e{dim-1}
pub fn parse(gpa: Allocator, text: []const u8) !api.Embeddings {
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    const header = lines.next() orelse return error.EmbeddingsFile;
    const tabs = std.mem.count(u8, header, "\t");
    if (tabs < 3) return error.EmbeddingsFile;
    const dim: u32 = @intCast(tabs - 2);
    var rows: std.ArrayList(api.EmbeddingRow) = .empty;
    errdefer {
        for (rows.items) |r| gpa.free(r.e);
        rows.deinit(gpa);
    }
    while (lines.next()) |line| {
        var f = std.mem.tokenizeScalar(u8, line, '\t');
        const champion = try std.fmt.parseInt(u32, f.next() orelse return error.EmbeddingsFile, 10);
        const role = try std.fmt.parseInt(u3, f.next() orelse return error.EmbeddingsFile, 10);
        if (role >= 5) return error.EmbeddingsFile;
        const games = try std.fmt.parseInt(u32, f.next() orelse return error.EmbeddingsFile, 10);
        const e = try gpa.alloc(f32, dim);
        errdefer gpa.free(e);
        for (e) |*x| x.* = try std.fmt.parseFloat(f32, f.next() orelse return error.EmbeddingsFile);
        try rows.append(gpa, .{ .champion = champion, .role = @fromBackingInt(role), .games = games, .e = e });
    }
    return .{ .dim = dim, .rows = try rows.toOwnedSlice(gpa) };
}

const testing = std.testing;

test "the file learnt on these games is chosen; a file from other games fails" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    const cwd = Io.Dir.cwd();
    // Two games: champion 10+r and 20+r in role r on blue, 30+r and 40+r on red
    var games: [2]api.Game = undefined;
    for (&games, 0..) |*g, i| {
        g.* = .{ .start = @intCast(i), .patch = 1, .platform = 6, .teams = undefined, .ranks = @splat(@splat(null)), .exp = @splat(@splat(.{})) };
        for (0..5) |r| {
            g.teams[0][r] = @intCast(10 * (i + 1) + r);
            g.teams[1][r] = @intCast(30 + 10 * i + r);
        }
    }
    const t: api.Train = .{ .games = &games, .rows = &.{} };
    // Own rows for champions 10..14 (1 game each); the rest under the role's shared row
    var good: std.ArrayList(u8) = .empty;
    try good.appendSlice(arena, "champion\trole\tfit_games\te0\te1\n");
    for (0..5) |r| try good.print(arena, "0\t{d}\t3\t0.0\t0.0\n", .{r});
    for (0..5) |r| try good.print(arena, "{d}\t{d}\t1\t0.5\t-0.5\n", .{ 10 + r, r });
    // From one more game: champion 10 counted twice
    const bad = try std.mem.replaceOwned(u8, arena, good.items, "10\t0\t1\t", "10\t0\t2\t");
    try cwd.createDirPath(io, base);
    try cwd.writeFile(io, .{ .sub_path = try arena.print("{s}/emb-1-s1.tsv", .{base}), .data = bad });
    try cwd.writeFile(io, .{ .sub_path = try arena.print("{s}/emb-dev-s1.tsv", .{base}), .data = good.items });
    try cwd.writeFile(io, .{ .sub_path = try arena.print("{s}/emb-dev-s2.tsv", .{base}), .data = bad });

    const dir: Dir = .{ .io = io, .path = base };
    const src = dir.source();
    var e = try src.forFit(gpa, &t, 1);
    defer e.deinit(gpa);
    try testing.expectEqual(@as(u32, 2), e.dim);
    try testing.expectEqual(@as(usize, 10), e.rows.len);
    try testing.expectError(error.NoEmbeddingsForFitSet, src.forFit(gpa, &t, 2));
    try testing.expectError(error.NoEmbeddingsForFitSet, src.forFit(gpa, &.{ .games = games[0..1], .rows = &.{} }, 1));
}
