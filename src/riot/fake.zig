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
    match: Template,
    timeline: Template,
    /// The timeline's pieces point into it
    timeline_json: []u8,
    mastery_json: []u8,
    /// Which app's key this stands for: account-v1 PUUIDs differ per app (rekey.zig)
    encryption: u8 = 0,
    /// Paths containing this get Riot's JSON 403 (error.KeyRejected); "" every path, a
    /// rejected key
    refuse: ?[]const u8 = null,
    /// Every account's profile icon (summoner-v4), for the icon checks
    icon: i64 = 1,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, latency_ms: u32) !Fake {
        var match: Template = try .init(gpa, @embedFile("testdata/match.json"), "NA1_5321429660");
        errdefer match.deinit(gpa);
        const timeline_json = try raw.decompress(gpa, @embedFile("testdata/timeline.json.gz"));
        errdefer gpa.free(timeline_json);
        var timeline: Template = try .init(gpa, timeline_json, "EUW1_8009933221");
        errdefer timeline.deinit(gpa);
        return .{
            .io = io,
            .latency_ms = latency_ms,
            .match = match,
            .timeline = timeline,
            .timeline_json = timeline_json,
            .mastery_json = try raw.decompress(gpa, @embedFile("testdata/mastery.json.gz")),
        };
    }

    pub fn deinit(f: *Fake, gpa: std.mem.Allocator) void {
        f.match.deinit(gpa);
        f.timeline.deinit(gpa);
        gpa.free(f.timeline_json);
        gpa.free(f.mastery_json);
    }

    /// As Client.get: body (caller frees) or null for 404
    pub fn get(f: *const Fake, gpa: std.mem.Allocator, route: []const u8, path: []const u8) !?[]u8 {
        try f.io.sleep(.fromMilliseconds(f.latency_ms), .awake);
        if (f.refuse) |r| if (std.mem.find(u8, path, r) != null) return error.KeyRejected;
        if (std.mem.startsWith(u8, path, "/lol/league-exp/v4/entries/")) return try ladder(gpa, route, path);
        if (std.mem.startsWith(u8, path, "/lol/champion-mastery/")) return try gpa.dupe(u8, f.mastery_json);
        if (std.mem.startsWith(u8, path, "/riot/account/v1/accounts/")) return try f.account(gpa, path);
        if (std.mem.startsWith(u8, path, "/riot/account/v1/region/by-game/lol/by-puuid/")) return try gpa.dupe(u8, "{\"game\":\"lol\",\"region\":\"euw1\"}");
        if (std.mem.startsWith(u8, path, "/lol/summoner/v4/summoners/by-puuid/")) return try gpa.print("{{\"profileIconId\":{d}}}", .{f.icon});
        const by_puuid = "/lol/match/v5/matches/by-puuid/";
        if (std.mem.startsWith(u8, path, by_puuid)) return try matchIds(gpa, route, path[by_puuid.len..]);
        const matches = "/lol/match/v5/matches/";
        if (!std.mem.startsWith(u8, path, matches)) return null;
        const rest = path[matches.len..];
        if (std.mem.endsWith(u8, rest, "/timeline")) return try f.timeline.fill(gpa, rest[0 .. rest.len - "/timeline".len]);
        return try f.match.fill(gpa, rest);
    }

    /// Account PUUIDs are "acct<encryption>.<name>.<tag>", so any key can turn them into
    /// a Riot ID and back. Other PUUIDs (crawled, real) are encryption 0's, with a Riot ID
    /// made from their hash. Names starting "gone" have no account
    fn account(f: *const Fake, gpa: std.mem.Allocator, path: []const u8) !?[]u8 {
        var name_buf: [64]u8 = undefined;
        var name: []const u8 = undefined;
        var tag: []const u8 = undefined;
        const by_puuid = "/riot/account/v1/accounts/by-puuid/";
        const by_riot_id = "/riot/account/v1/accounts/by-riot-id/";
        if (std.mem.startsWith(u8, path, by_puuid)) {
            const puuid = path[by_puuid.len..];
            if (std.mem.startsWith(u8, puuid, "acct")) {
                // Riot answers 400 to a PUUID another app's key encrypted
                if (puuid.len < 5 or puuid[4] != '0' + f.encryption) return error.UnexpectedStatus;
                var parts = std.mem.splitScalar(u8, puuid, '.');
                _ = parts.next();
                name = parts.next() orelse return error.UnexpectedStatus;
                tag = parts.next() orelse return error.UnexpectedStatus;
            } else {
                if (f.encryption != 0) return error.UnexpectedStatus;
                name = try std.mem.print(&name_buf, "p{x:0>16}", .{std.hash.Wyhash.hash(0, puuid)});
                tag = "OLD";
            }
        } else if (std.mem.startsWith(u8, path, by_riot_id)) {
            const rest = path[by_riot_id.len..];
            const slash = std.mem.findScalar(u8, rest, '/') orelse return null;
            const encoded = rest[0..slash];
            if (encoded.len > name_buf.len) return null;
            @memcpy(name_buf[0..encoded.len], encoded);
            name = std.Uri.percentDecodeInPlace(name_buf[0..encoded.len]);
            tag = rest[slash + 1 ..];
        } else return null;
        if (std.mem.startsWith(u8, name, "gone")) return null;
        return try gpa.print(
            \\{{"puuid":"acct{d}.{s}.{s}","gameName":"{s}","tagLine":"{s}"}}
        , .{ f.encryption, name, tag, name, tag });
    }
};

fn puuidOf(buf: *[78]u8, seed: u64) []const u8 {
    var rng: std.Random.DefaultPrng = .init(seed);
    const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
    for (buf) |*ch| ch.* = alphabet[rng.random().uintLessThan(usize, alphabet.len)];
    return buf;
}

fn ladder(gpa: std.mem.Allocator, host: []const u8, path: []const u8) ![]u8 {
    const page = std.fmt.parseInt(u32, path[std.mem.findScalarLast(u8, path, '=').? + 1 ..], 10) catch 1;
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
    const puuid = rest[0 .. std.mem.findScalar(u8, rest, '/') orelse rest.len];
    // The fixture is a solo game; other queues have none
    if (std.mem.find(u8, rest, "&start=0&") == null or std.mem.find(u8, rest, "queue=420&") == null) return gpa.dupe(u8, "[]");
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

/// A fixture cut once at its quoted match id and "puuid-0".."puuid-9": a replace pass
/// per hole for every answer took ~13 s of each refresh test in Debug
const Template = struct {
    /// Fixture text around the holes: one more than holes
    pieces: []const []const u8,
    /// The slot whose PUUID fills each hole; null for the match id
    holes: []const ?u8,

    fn init(gpa: std.mem.Allocator, fixture: []const u8, fixture_id: []const u8) !Template {
        var pieces: std.ArrayList([]const u8) = .empty;
        defer pieces.deinit(gpa);
        var holes: std.ArrayList(?u8) = .empty;
        defer holes.deinit(gpa);
        var start: usize = 0;
        var i: usize = 0;
        while (std.mem.findScalarPos(u8, fixture, i, '"')) |quote| {
            const in = fixture[quote + 1 ..];
            const hole: ?u8, const len: usize = if (std.mem.startsWith(u8, in, fixture_id) and
                std.mem.startsWith(u8, in[fixture_id.len..], "\""))
                .{ null, fixture_id.len }
            else if (in.len >= 8 and std.mem.startsWith(u8, in, "puuid-") and
                std.ascii.isDigit(in[6]) and in[7] == '"')
                .{ in[6] - '0', 7 }
            else {
                i = quote + 1;
                continue;
            };
            try pieces.append(gpa, fixture[start .. quote + 1]);
            try holes.append(gpa, hole);
            start = quote + 1 + len;
            i = start + 1;
        }
        try pieces.append(gpa, fixture[start..]);
        const owned_holes = try holes.toOwnedSlice(gpa);
        errdefer gpa.free(owned_holes);
        return .{ .pieces = try pieces.toOwnedSlice(gpa), .holes = owned_holes };
    }

    fn deinit(t: *Template, gpa: std.mem.Allocator) void {
        gpa.free(t.pieces);
        gpa.free(t.holes);
    }

    /// The fixture with match id `id` and real-looking PUUIDs drawn from it
    fn fill(t: *const Template, gpa: std.mem.Allocator, id: []const u8) ![]u8 {
        var puuids: [10][78]u8 = undefined;
        for (&puuids, 0..) |*buf, slot| _ = puuidOf(buf, std.hash.Wyhash.hash(slot, id) % player_pool);
        var len = t.pieces[t.holes.len].len;
        for (t.pieces[0..t.holes.len], t.holes) |piece, hole| len += piece.len + if (hole) |_| 78 else id.len;
        const out = try gpa.alloc(u8, len);
        var w: std.Io.Writer = .fixed(out);
        for (t.pieces[0..t.holes.len], t.holes) |piece, hole| {
            w.writeAll(piece) catch unreachable;
            w.writeAll(if (hole) |slot| &puuids[slot] else id) catch unreachable;
        }
        w.writeAll(t.pieces[t.holes.len]) catch unreachable;
        return out;
    }
};

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

test "fixtures filled as replacing the id and each \"puuid-N\" in turn" {
    const gpa = std.testing.allocator;
    var f: Fake = try .init(gpa, std.testing.io, 0);
    defer f.deinit(gpa);
    // The timeline's "puuid-10" is no hole, as before
    try std.testing.expectEqual(19, f.timeline.holes.len);
    const id = "EUW1_42";
    const got = try f.match.fill(gpa, id);
    defer gpa.free(got);
    var want = try std.mem.replaceOwned(u8, gpa, @embedFile("testdata/match.json"), "NA1_5321429660", id);
    defer gpa.free(want);
    for (0..10) |slot| {
        var from_buf: [16]u8 = undefined;
        var puuid_buf: [78]u8 = undefined;
        var to_buf: [80]u8 = undefined;
        const from = try std.mem.print(&from_buf, "\"puuid-{d}\"", .{slot});
        const to = try std.mem.print(&to_buf, "\"{s}\"", .{puuidOf(&puuid_buf, std.hash.Wyhash.hash(slot, id) % player_pool)});
        const next = try std.mem.replaceOwned(u8, gpa, want, from, to);
        gpa.free(want);
        want = next;
    }
    try std.testing.expectEqualStrings(want, got);

    // The timeline is too big to replace in Debug each run: no match id, quoted or not,
    // or "puuid-N" left instead. Its numeric gameId stays, as it always did
    const filled = try f.timeline.fill(gpa, id);
    defer gpa.free(filled);
    try std.testing.expect(std.mem.find(u8, filled, "EUW1_8009933221") == null);
    for (0..10) |slot| {
        var buf: [16]u8 = undefined;
        try std.testing.expect(std.mem.find(u8, filled, try std.mem.print(&buf, "\"puuid-{d}\"", .{slot})) == null);
    }
}
