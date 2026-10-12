//! Analysis snapshots (docs/data-safety.md): replace PUUIDs and match ids with salted
//! hashes in place, blank names, drop forgotten players. Run off the box, where the salt
//! lives (~/.config/meiolol/snap-salt); the snapshot then goes to the gpu-box.
//!
//! Match ids are hashed too: with a real match id anyone holding a Riot key gets the ten
//! players back, which would undo the PUUID hashes. Hashed ids keep the platform prefix
//! ("EUW1_<53-bit number>") so platform parsing still works, and the numeric part is also
//! the raw JSON's gameId. A hashed PUUID is 16 hex chars; ranks keys become
//! schema.puuidKey(hashed PUUID), so existing joins work unchanged on the snapshot.

const std = @import("std");
const store = @import("store");
const forget = @import("../forget.zig");

const c = store.sqlite.c;
const Db = store.Db;
const Hmac = std.crypto.auth.hmac.sha2.HmacSha256;

pub const Salt = [32]u8;

pub fn puuid(salt: *const Salt, raw: []const u8) [16]u8 {
    var mac: [Hmac.mac_length]u8 = undefined;
    var h = Hmac.init(salt);
    h.update("puuid:");
    h.update(raw);
    h.final(&mac);
    return std.fmt.bytesToHex(mac[0..8], .lower);
}

pub fn gameNumber(salt: *const Salt, raw_id: []const u8) u64 {
    var mac: [Hmac.mac_length]u8 = undefined;
    var h = Hmac.init(salt);
    h.update("match:");
    h.update(raw_id);
    h.final(&mac);
    // Within JSON's exact integer range
    return std.mem.readInt(u64, mac[0..8], .little) >> 11;
}

/// "EUW1_7613000000" -> "EUW1_<hash>"; written into buf
pub fn matchId(salt: *const Salt, raw_id: []const u8, buf: []u8) ![]const u8 {
    const cut = std.mem.indexOfScalar(u8, raw_id, '_') orelse raw_id.len;
    return std.fmt.bufPrint(buf, "{s}_{d}", .{ raw_id[0..cut], gameNumber(salt, raw_id) });
}

/// One match-v5 summary: every PUUID in metadata.participants replaced wherever it
/// occurs, names and summoner ids blanked, matchId/gameId hashed, profile icons zeroed.
/// Byte-exact elsewhere (no JSON re-serialisation)
pub fn rewriteMatch(gpa: std.mem.Allocator, salt: *const Salt, json: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = try .initCapacity(gpa, json.len);
    errdefer out.deinit(gpa);
    out.appendSliceAssumeCapacity(json);

    const id = stringField(out.items, "matchId", 0) orelse return error.NoMatchId;
    var id_buf: [64]u8 = undefined;
    const raw_id = try gpa.dupe(u8, out.items[id.start..id.end]);
    defer gpa.free(raw_id);
    const new_id = try matchId(salt, raw_id, &id_buf);
    try replaceAt(gpa, &out, id.start, id.end, new_id);

    var puuids: std.ArrayList([]const u8) = .empty;
    defer {
        for (puuids.items) |p| gpa.free(p);
        puuids.deinit(gpa);
    }
    const list_key = "\"participants\":[";
    const list = std.mem.indexOf(u8, out.items, list_key) orelse return error.NoParticipants;
    var i = list + list_key.len;
    while (i < out.items.len and out.items[i] == '"') {
        const end = std.mem.indexOfScalarPos(u8, out.items, i + 1, '"') orelse return error.BadJson;
        try puuids.append(gpa, try gpa.dupe(u8, out.items[i + 1 .. end]));
        i = end + 1;
        if (i < out.items.len and out.items[i] == ',') i += 1;
    }
    for (puuids.items) |p| {
        const hashed = puuid(salt, p);
        var from: usize = 0;
        while (std.mem.indexOfPos(u8, out.items, from, p)) |at| {
            try replaceAt(gpa, &out, at, at + p.len, &hashed);
            from = at + hashed.len;
        }
    }

    for ([_][]const u8{ "riotIdGameName", "riotIdTagline", "summonerName", "summonerId" }) |key| {
        var from: usize = 0;
        while (stringField(out.items, key, from)) |f| {
            try replaceAt(gpa, &out, f.start, f.end, "");
            from = f.start;
        }
    }
    var num_buf: [24]u8 = undefined;
    const game = try std.fmt.bufPrint(&num_buf, "{d}", .{gameNumber(salt, raw_id)});
    try replaceNumbers(gpa, &out, "gameId", game);
    try replaceNumbers(gpa, &out, "profileIcon", "0");
    return out.toOwnedSlice(gpa);
}

const Span = struct { start: usize, end: usize };

/// Contents of the next `"key":"..."` string at or after from (escapes skipped)
fn stringField(json: []const u8, key: []const u8, from: usize) ?Span {
    var pos = from;
    while (std.mem.indexOfPos(u8, json, pos, key)) |k| {
        pos = k + key.len;
        if (k == 0 or json[k - 1] != '"') continue;
        const rest = json[pos..];
        if (!std.mem.startsWith(u8, rest, "\":\"")) continue;
        const start = pos + 3;
        var j = start;
        while (j < json.len and json[j] != '"') : (j += 1) {
            if (json[j] == '\\') j += 1;
        }
        return .{ .start = start, .end = @min(j, json.len) };
    }
    return null;
}

fn replaceNumbers(gpa: std.mem.Allocator, out: *std.ArrayList(u8), key: []const u8, value: []const u8) !void {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, out.items, pos, key)) |k| {
        pos = k + key.len;
        if (k == 0 or out.items[k - 1] != '"') continue;
        if (!std.mem.startsWith(u8, out.items[pos..], "\":")) continue;
        const start = pos + 2;
        var end = start;
        while (end < out.items.len and (std.ascii.isDigit(out.items[end]) or out.items[end] == '-')) end += 1;
        if (end == start) continue;
        try replaceAt(gpa, out, start, end, value);
        pos = start + value.len;
    }
}

fn replaceAt(gpa: std.mem.Allocator, out: *std.ArrayList(u8), start: usize, end: usize, with: []const u8) !void {
    try out.replaceRange(gpa, start, end - start, with);
}

/// SQL functions anon_puuid(text) and anon_match(text); NULL stays NULL
fn registerFunctions(db: Db, salt: *const Salt) !void {
    const flags = c.SQLITE_UTF8 | c.SQLITE_DETERMINISTIC;
    if (c.sqlite3_create_function_v2(db.handle, "anon_puuid", 1, flags, @constCast(salt), sqlPuuid, null, null, null) != c.SQLITE_OK or
        c.sqlite3_create_function_v2(db.handle, "anon_match", 1, flags, @constCast(salt), sqlMatch, null, null, null) != c.SQLITE_OK)
        return error.Sqlite;
}

fn argText(argv: [*c]?*c.sqlite3_value) ?[]const u8 {
    const v = argv[0];
    if (c.sqlite3_value_type(v) == c.SQLITE_NULL) return null;
    const p: [*]const u8 = c.sqlite3_value_text(v) orelse return "";
    return p[0..@intCast(c.sqlite3_value_bytes(v))];
}

fn ctxSalt(ctx: ?*c.sqlite3_context) *const Salt {
    return @ptrCast(@alignCast(c.sqlite3_user_data(ctx)));
}

/// A copy sqlite frees: SQLITE_TRANSIENT does not translate (a misaligned fn pointer)
fn resultText(ctx: ?*c.sqlite3_context, text: []const u8) void {
    const p: [*]u8 = @ptrCast(c.sqlite3_malloc(@intCast(text.len)) orelse return c.sqlite3_result_error_nomem(ctx));
    @memcpy(p[0..text.len], text);
    c.sqlite3_result_text(ctx, p, @intCast(text.len), c.sqlite3_free);
}

fn sqlPuuid(ctx: ?*c.sqlite3_context, _: c_int, argv: [*c]?*c.sqlite3_value) callconv(.c) void {
    const raw = argText(argv) orelse return c.sqlite3_result_null(ctx);
    const h = puuid(ctxSalt(ctx), raw);
    resultText(ctx, &h);
}

fn sqlMatch(ctx: ?*c.sqlite3_context, _: c_int, argv: [*c]?*c.sqlite3_value) callconv(.c) void {
    const raw = argText(argv) orelse return c.sqlite3_result_null(ctx);
    var buf: [64]u8 = undefined;
    const id = matchId(ctxSalt(ctx), raw, &buf) catch return c.sqlite3_result_error(ctx, "match id", -1);
    resultText(ctx, id);
}

/// Anonymise the snapshot in dir (meiolol.db with raw.db and timeline.db) in place
pub fn run(gpa: std.mem.Allocator, dir: []const u8, salt: *const Salt) !void {
    // In place and irreversible: never on a live data dir
    if (!std.mem.startsWith(u8, std.fs.path.basename(dir), "snap-")) return error.NotASnapshotDir;
    const db = try store.schema.connect(gpa, dir);
    defer db.close();
    try db.exec("PRAGMA secure_delete = ON");
    if (try db.scalar("SELECT 1 FROM sqlite_master WHERE name = 'anon_meta'", .{}) != null)
        return error.AlreadyAnonymised;
    try registerFunctions(db, salt);

    const forgotten = try forget.reapply(gpa, db, 0);
    std.log.info("forgotten players re-erased: {d} rows", .{forgotten.total()});

    try db.begin();
    errdefer db.rollback();
    try db.exec("DELETE FROM forgotten; DELETE FROM raw.timeline_docs");

    // ranks keys are puuidKey(PUUID); map old to puuidKey(hashed PUUID)
    try db.exec("CREATE TEMP TABLE keymap (old INTEGER PRIMARY KEY, new INTEGER NOT NULL)");
    {
        var ins = try db.prepare("INSERT OR IGNORE INTO keymap VALUES (?, ?)");
        defer ins.deinit();
        var s = try db.prepare(
            \\SELECT puuid FROM players UNION
            \\SELECT puuid FROM participants WHERE puuid IS NOT NULL
        );
        defer s.deinit();
        try s.bind(.{});
        while (try s.step()) {
            const p = s.bytes(0);
            const h = puuid(salt, p);
            try ins.exec(.{ store.schema.puuidKey(p), store.schema.puuidKey(&h) });
        }
    }
    inline for (.{ "ranks", "rank_history" }) |t| {
        try db.exec("CREATE TEMP TABLE moved AS SELECT k.new AS nk, t.* FROM " ++ t ++
            " t JOIN keymap k ON k.old = t.key");
        try db.exec("ALTER TABLE moved DROP COLUMN key; DELETE FROM " ++ t ++
            "; INSERT INTO " ++ t ++ " SELECT * FROM moved; DROP TABLE moved");
    }
    try db.exec(
        \\UPDATE participants SET puuid = anon_puuid(puuid), match_id = anon_match(match_id);
        \\UPDATE players SET puuid = anon_puuid(puuid);
        \\UPDATE mastery SET puuid = anon_puuid(puuid);
        \\UPDATE matches SET match_id = anon_match(match_id);
        \\UPDATE bans SET match_id = anon_match(match_id);
        \\UPDATE match_queue SET match_id = anon_match(match_id);
        \\UPDATE timeline_queue SET match_id = anon_match(match_id);
        \\UPDATE draft_backfill SET match_id = anon_match(match_id);
        \\UPDATE timeline.timelines SET match_id = anon_match(match_id);
    );

    const window = try gpa.alloc(u8, store.raw.window_len);
    defer gpa.free(window);
    var done: usize = 0;
    {
        var sel = try db.prepare("SELECT key, body FROM raw.raw_docs WHERE source = 'riot_match'");
        defer sel.deinit();
        var put = try db.prepare("INSERT INTO raw.raw_docs SELECT 'anon', anon_match(?1), fetched_at, ?2 " ++
            "FROM raw.raw_docs WHERE source = 'riot_match' AND key = ?1");
        defer put.deinit();
        try sel.bind(.{});
        while (try sel.step()) {
            const key = try gpa.dupe(u8, sel.bytes(0));
            defer gpa.free(key);
            const json = try store.raw.decompress(gpa, sel.bytes(1));
            defer gpa.free(json);
            const anon = try rewriteMatch(gpa, salt, json);
            defer gpa.free(anon);
            const body = try store.raw.compressWith(gpa, window, anon);
            defer gpa.free(body);
            try put.exec(.{ key, store.Blob{ .bytes = body } });
            done += 1;
            if (done % 20000 == 0) std.log.info("raw summaries: {d}", .{done});
        }
    }
    try db.exec(
        \\DELETE FROM raw.raw_docs WHERE source <> 'anon';
        \\UPDATE raw.raw_docs SET source = 'riot_match';
        \\CREATE TABLE anon_meta (anonymised_at INTEGER NOT NULL);
        \\INSERT INTO anon_meta VALUES (unixepoch());
    );
    try db.commit();
    std.log.info("raw summaries rewritten: {d}; vacuuming", .{done});
    // Freed pages still hold the old ids until rewritten
    try db.exec("VACUUM main; VACUUM raw; VACUUM timeline");
}

const testing = std.testing;
const test_salt: Salt = @splat(7);

test "rewriteMatch hashes ids, blanks names, keeps the rest" {
    const json =
        \\{"metadata":{"matchId":"EUW1_123","participants":["AAA-p1","BBB_p2"]},
        \\"info":{"gameId":123,"participants":[{"puuid":"AAA-p1","riotIdGameName":"Na\"me",
        \\"riotIdTagline":"EUW","summonerId":"s1","profileIcon":4075,"kills":3},
        \\{"puuid":"BBB_p2","summonerName":"","profileIcon":12,"kills":0}]}}
    ;
    const out = try rewriteMatch(testing.allocator, &test_salt, json);
    defer testing.allocator.free(out);
    for ([_][]const u8{ "AAA-p1", "BBB_p2", "EUW1_123", "Na\\\"me", "s1", "4075", "\"gameId\":123," }) |gone| {
        try testing.expect(std.mem.indexOf(u8, out, gone) == null);
    }
    const p1 = puuid(&test_salt, "AAA-p1");
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, out, &p1));
    try testing.expect(std.mem.indexOf(u8, out, "\"riotIdTagline\":\"\"") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"kills\":3") != null);
    var buf: [64]u8 = undefined;
    const id = try matchId(&test_salt, "EUW1_123", &buf);
    try testing.expect(std.mem.startsWith(u8, id, "EUW1_"));
    try testing.expect(std.mem.indexOf(u8, out, id) != null);
    try testing.expect(std.mem.indexOf(u8, out, id[5..]) != null);
}
