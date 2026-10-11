//! Canned Riot API answers for `meiolol crawl --fake-api MS`: the crawler's write path
//! under load with no network or rate limits (deploy/bench-crawl.sh). Fixtures from
//! testdata with fresh match ids and PUUIDs, so every match is new rows.

const std = @import("std");
const raw = @import("store").raw;

/// Distinct PUUIDs participants are drawn from: some repeat, as on the real ladder
const player_pool = 2_000_000;
/// Ladder pages per division with entries; the next one is empty
const ladder_pages = 2;
const matches_per_player = 20;

pub const Fake = struct {
    io: std.Io,
    latency_ms: u32,
    match_json: []const u8,
    timeline_json: []u8,
    mastery_json: []u8,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, latency_ms: u32) !Fake {
        return .{
            .io = io,
            .latency_ms = latency_ms,
            .match_json = @embedFile("testdata/match.json"),
            .timeline_json = try raw.decompress(gpa, @embedFile("testdata/timeline.json.gz")),
            .mastery_json = try raw.decompress(gpa, @embedFile("testdata/mastery.json.gz")),
        };
    }

    pub fn deinit(f: *Fake, gpa: std.mem.Allocator) void {
        gpa.free(f.timeline_json);
        gpa.free(f.mastery_json);
    }

    /// As Client.get: body (caller frees) or null for 404
    pub fn get(f: *const Fake, gpa: std.mem.Allocator, route: []const u8, path: []const u8) !?[]u8 {
        try f.io.sleep(.fromMilliseconds(f.latency_ms), .awake);
        if (std.mem.startsWith(u8, path, "/lol/league-exp/v4/entries/")) return try ladder(gpa, route, path);
        if (std.mem.startsWith(u8, path, "/lol/champion-mastery/")) return try gpa.dupe(u8, f.mastery_json);
        const by_puuid = "/lol/match/v5/matches/by-puuid/";
        if (std.mem.startsWith(u8, path, by_puuid)) return try matchIds(gpa, route, path[by_puuid.len..]);
        const matches = "/lol/match/v5/matches/";
        if (!std.mem.startsWith(u8, path, matches)) return null;
        const rest = path[matches.len..];
        if (std.mem.endsWith(u8, rest, "/timeline")) {
            return try withIds(gpa, f.timeline_json, "EUW1_8009933221", rest[0 .. rest.len - "/timeline".len]);
        }
        return try withIds(gpa, f.match_json, "NA1_5321429660", rest);
    }
};

fn puuidOf(buf: *[78]u8, seed: u64) []const u8 {
    var rng: std.Random.DefaultPrng = .init(seed);
    const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
    for (buf) |*ch| ch.* = alphabet[rng.random().uintLessThan(usize, alphabet.len)];
    return buf;
}

fn ladder(gpa: std.mem.Allocator, host: []const u8, path: []const u8) ![]u8 {
    const page = std.fmt.parseInt(u32, path[std.mem.lastIndexOfScalar(u8, path, '=').? + 1 ..], 10) catch 1;
    var out: std.Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();
    try out.writer.writeByte('[');
    if (page <= ladder_pages) {
        for (0..205) |i| {
            var buf: [78]u8 = undefined;
            const seed = std.hash.Wyhash.hash(i, path) ^ std.hash.Wyhash.hash(0, host);
            if (i > 0) try out.writer.writeByte(',');
            try out.writer.print(
                \\{{"puuid":"{s}","tier":"GOLD","rank":"II","leaguePoints":40,"wins":30,"losses":28}}
            , .{puuidOf(&buf, seed % player_pool)});
        }
    }
    try out.writer.writeByte(']');
    return out.toOwnedSlice();
}

fn matchIds(gpa: std.mem.Allocator, region: []const u8, rest: []const u8) ![]u8 {
    const puuid = rest[0 .. std.mem.indexOfScalar(u8, rest, '/') orelse rest.len];
    if (std.mem.indexOf(u8, rest, "&start=0&") == null) return gpa.dupe(u8, "[]");
    const platform = if (std.mem.eql(u8, region, "europe")) "EUW1" else if (std.mem.eql(u8, region, "asia"))
        "KR"
    else if (std.mem.eql(u8, region, "sea")) "OC1" else "NA1";
    var out: std.Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();
    try out.writer.writeByte('[');
    for (0..matches_per_player) |k| {
        if (k > 0) try out.writer.writeByte(',');
        try out.writer.print("\"{s}_{d}\"", .{ platform, std.hash.Wyhash.hash(k, puuid) % 10_000_000_000 });
    }
    try out.writer.writeByte(']');
    return out.toOwnedSlice();
}

/// The fixture with its match id replaced and "puuid-0".."puuid-9" made real-looking
fn withIds(gpa: std.mem.Allocator, fixture: []const u8, fixture_id: []const u8, id: []const u8) ![]u8 {
    var body = try std.mem.replaceOwned(u8, gpa, fixture, fixture_id, id);
    for (0..10) |slot| {
        var from_buf: [16]u8 = undefined;
        const from = try std.fmt.bufPrint(&from_buf, "\"puuid-{d}\"", .{slot});
        var puuid_buf: [78]u8 = undefined;
        var to_buf: [80]u8 = undefined;
        const seed = std.hash.Wyhash.hash(slot, id) % player_pool;
        const to = try std.fmt.bufPrint(&to_buf, "\"{s}\"", .{puuidOf(&puuid_buf, seed)});
        const next = try std.mem.replaceOwned(u8, gpa, body, from, to);
        gpa.free(body);
        body = next;
    }
    return body;
}

test "fake match parses with the requested id" {
    const gpa = std.testing.allocator;
    var f: Fake = try .init(gpa, std.testing.io, 0);
    defer f.deinit(gpa);
    const body = (try f.get(gpa, "europe", "/lol/match/v5/matches/EUW1_42")).?;
    defer gpa.free(body);
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const doc = try @import("match.zig").parse(arena.allocator(), body);
    try std.testing.expectEqualStrings("EUW1_42", doc.metadata.matchId);
    try std.testing.expectEqual(@as(usize, 78), doc.info.participants[0].puuid.?.len);
}
