//! Analysis snapshots (docs/data-safety.md): replace PUUIDs and match ids with salted
//! hashes, blank names, leave out forgotten players. Run off the box, where the salt
//! lives (~/.config/meiolol/snap-salt), into a new snapshot directory that then goes to
//! the gpu-box.
//!
//! Match ids are hashed too: with a real match id anyone holding a Riot key gets the ten
//! players back, which would undo the PUUID hashes. Hashed ids keep the platform prefix
//! ("EUW1_<53-bit number>") so platform parsing still works, and the numeric part is also
//! the raw JSON's gameId. A hashed PUUID is 16 hex chars; ranks keys become
//! schema.puuidKey(hashed PUUID), so existing joins work unchanged on the snapshot.

const std = @import("std");
const store = @import("store");

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
    const cut = std.mem.findScalar(u8, raw_id, '_') orelse raw_id.len;
    return std.mem.print(buf, "{s}_{d}", .{ raw_id[0..cut], gameNumber(salt, raw_id) });
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
    const list = std.mem.find(u8, out.items, list_key) orelse return error.NoParticipants;
    var i = list + list_key.len;
    while (i < out.items.len and out.items[i] == '"') {
        const end = std.mem.findScalarPos(u8, out.items, i + 1, '"') orelse return error.BadJson;
        try puuids.append(gpa, try gpa.dupe(u8, out.items[i + 1 .. end]));
        i = end + 1;
        if (i < out.items.len and out.items[i] == ',') i += 1;
    }
    for (puuids.items) |p| {
        const hashed = puuid(salt, p);
        var from: usize = 0;
        while (std.mem.findPos(u8, out.items, from, p)) |at| {
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
    const game = try std.mem.print(&num_buf, "{d}", .{gameNumber(salt, raw_id)});
    try replaceNumbers(gpa, &out, "gameId", game);
    try replaceNumbers(gpa, &out, "profileIcon", "0");
    return out.toOwnedSlice(gpa);
}

const Span = struct { start: usize, end: usize };

/// Contents of the next `"key":"..."` string at or after from (escapes skipped)
fn stringField(json: []const u8, key: []const u8, from: usize) ?Span {
    var pos = from;
    while (std.mem.findPos(u8, json, pos, key)) |k| {
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
    while (std.mem.findPos(u8, out.items, pos, key)) |k| {
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

/// SQL functions anon_puuid(text), anon_match(text), and for ranks keys old_key(puuid) =
/// puuidKey(puuid), anon_key(puuid) = puuidKey(hashed puuid); NULL stays NULL
fn registerFunctions(db: Db, salt: *const Salt) !void {
    const flags = c.SQLITE_UTF8 | c.SQLITE_DETERMINISTIC;
    if (c.sqlite3_create_function_v2(db.handle, "anon_puuid", 1, flags, @constCast(salt), sqlPuuid, null, null, null) != c.SQLITE_OK or
        c.sqlite3_create_function_v2(db.handle, "anon_match", 1, flags, @constCast(salt), sqlMatch, null, null, null) != c.SQLITE_OK or
        c.sqlite3_create_function_v2(db.handle, "anon_key", 1, flags, @constCast(salt), sqlAnonKey, null, null, null) != c.SQLITE_OK or
        c.sqlite3_create_function_v2(db.handle, "old_key", 1, flags, null, sqlOldKey, null, null, null) != c.SQLITE_OK)
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

fn sqlOldKey(ctx: ?*c.sqlite3_context, _: c_int, argv: [*c]?*c.sqlite3_value) callconv(.c) void {
    const raw = argText(argv) orelse return c.sqlite3_result_null(ctx);
    c.sqlite3_result_int64(ctx, store.schema.puuidKey(raw));
}

fn sqlAnonKey(ctx: ?*c.sqlite3_context, _: c_int, argv: [*c]?*c.sqlite3_value) callconv(.c) void {
    const raw = argText(argv) orelse return c.sqlite3_result_null(ctx);
    const h = puuid(ctxSalt(ctx), raw);
    c.sqlite3_result_int64(ctx, store.schema.puuidKey(&h));
}

fn sqlMatch(ctx: ?*c.sqlite3_context, _: c_int, argv: [*c]?*c.sqlite3_value) callconv(.c) void {
    const raw = argText(argv) orelse return c.sqlite3_result_null(ctx);
    var buf: [64]u8 = undefined;
    const id = matchId(ctxSalt(ctx), raw, &buf) catch return c.sqlite3_result_error(ctx, "match id", -1);
    resultText(ctx, id);
}

/// Writes an anonymised copy of the snapshot in src (meiolol.db, raw.db, timeline.db) to
/// dst, which must not exist. A copy, not an in-place UPDATE: rewriting the keys of
/// millions of rows in place is random I/O for hours, while sorted inserts into fresh
/// files are sequential and leave no old values in free pages
pub fn run(gpa: std.mem.Allocator, io: std.Io, src: []const u8, dst: []const u8, salt: *const Salt) !void {
    for ([_][]const u8{ src, dst }) |dir| {
        if (!std.mem.startsWith(u8, std.fs.path.basename(dir), "snap-")) return error.NotASnapshotDir;
    }
    try std.Io.Dir.cwd().createDir(io, dst, .default_dir);

    // Inputs attached read-only (URI mode=ro), outputs read-write, on one connection
    var handle: ?*c.sqlite3 = null;
    const flags = c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE | c.SQLITE_OPEN_URI;
    if (c.sqlite3_open_v2(":memory:", &handle, flags, null) != c.SQLITE_OK) return error.Sqlite;
    const db: Db = .{ .handle = handle.? };
    defer db.close();
    try db.exec("PRAGMA temp_store = FILE");
    try registerFunctions(db, salt);
    inline for (schemas) |s| {
        const in_path = try gpa.print("file:{s}/{s}?mode=ro", .{ src, s.file });
        defer gpa.free(in_path);
        try db.run("ATTACH DATABASE ? AS " ++ s.in, .{in_path});
        const out_path = try std.fs.path.join(gpa, &.{ dst, s.file });
        defer gpa.free(out_path);
        try db.run("ATTACH DATABASE ? AS " ++ s.out, .{out_path});
        try db.exec("PRAGMA " ++ s.out ++ ".journal_mode = OFF; PRAGMA " ++ s.out ++
            ".synchronous = OFF; PRAGMA " ++ s.in ++ ".cache_size = -200000");
    }
    if (try db.scalar("SELECT 1 FROM src_main.sqlite_master WHERE name = 'anon_meta'", .{}) != null)
        return error.AlreadyAnonymised;

    var forgotten: usize = 0;
    {
        var q = try db.prepare("SELECT puuid FROM src_main.forgotten");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) forgotten += 1;
    }
    // Their rows would need forget's erasure first; the box applies it before any
    // snapshot, so none should be left
    if (forgotten > 0 and try db.scalar(
        "SELECT 1 FROM src_main.participants WHERE puuid IN (SELECT puuid FROM src_main.forgotten) LIMIT 1",
        .{},
    ) != null) return error.ForgottenPlayerInSnapshot;

    try db.begin();
    errdefer db.rollback();
    inline for (schemas) |s| {
        var tables = try db.prepare("SELECT name, sql FROM " ++ s.in ++
            ".sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'");
        defer tables.deinit();
        try tables.bind(.{});
        while (try tables.step()) {
            const name = try gpa.dupe(u8, tables.bytes(0));
            defer gpa.free(name);
            try createLike(gpa, db, s.out, tables.bytes(1));
            if (std.mem.eql(u8, name, "forgotten") or std.mem.eql(u8, name, "timeline_docs")) continue;
            if (std.mem.eql(u8, name, "raw_docs")) {
                try copyRawDocs(gpa, db, salt);
                continue;
            }
            try copyTable(gpa, db, s.in, s.out, name);
            std.log.info("{s}.{s} copied", .{ s.out, name });
        }
    }
    inline for (schemas) |s| {
        var indexes = try db.prepare("SELECT sql FROM " ++ s.in ++
            ".sqlite_master WHERE type = 'index' AND sql IS NOT NULL");
        defer indexes.deinit();
        try indexes.bind(.{});
        while (try indexes.step()) try createLike(gpa, db, s.out, indexes.bytes(0));
    }
    try db.exec(
        \\CREATE TABLE out_main.anon_meta (anonymised_at INTEGER NOT NULL);
        \\INSERT INTO out_main.anon_meta VALUES (unixepoch());
    );
    try db.commit();
}

const Schema = struct { in: [:0]const u8, out: [:0]const u8, file: []const u8 };
const schemas = [_]Schema{
    .{ .in = "src_main", .out = "out_main", .file = "meiolol.db" },
    .{ .in = "src_raw", .out = "out_raw", .file = "raw.db" },
    .{ .in = "src_timeline", .out = "out_timeline", .file = "timeline.db" },
};

/// Runs a CREATE TABLE/INDEX statement against the output schema
fn createLike(gpa: std.mem.Allocator, db: Db, out: []const u8, sql: []const u8) !void {
    // "CREATE TABLE name" / "CREATE INDEX name" / "CREATE UNIQUE INDEX name": qualify name
    const kinds = [_][]const u8{ "CREATE TABLE ", "CREATE INDEX ", "CREATE UNIQUE INDEX " };
    for (kinds) |k| if (std.mem.startsWith(u8, sql, k)) {
        const stmt = try gpa.printSentinel("{s}{s}.{s}", .{ k, out, sql[k.len..] }, 0);
        defer gpa.free(stmt);
        return db.exec(stmt);
    };
    return error.UnexpectedSchemaSql;
}

/// Column expressions: PUUIDs and match ids hashed, ranks keys moved to the hashed
/// PUUID's key; ordered by primary key so inserts are sequential
fn copyTable(gpa: std.mem.Allocator, db: Db, in: []const u8, out: []const u8, name: []const u8) !void {
    var cols: std.ArrayList(u8) = .empty;
    defer cols.deinit(gpa);
    var order: std.ArrayList(u8) = .empty;
    defer order.deinit(gpa);
    var pks: [8]struct { pk: i64, pos: usize } = undefined;
    var n_pk: usize = 0;
    const keyed = std.mem.eql(u8, name, "ranks") or std.mem.eql(u8, name, "rank_history");
    {
        const sql = try gpa.print("SELECT name, pk FROM pragma_table_info('{s}', '{s}') ORDER BY cid", .{ name, in });
        defer gpa.free(sql);
        var q = try db.prepare(sql);
        defer q.deinit();
        try q.bind(.{});
        var i: usize = 0;
        while (try q.step()) : (i += 1) {
            const col = q.bytes(0);
            if (i > 0) try cols.appendSlice(gpa, ", ");
            if (std.mem.eql(u8, col, "puuid")) {
                try cols.appendSlice(gpa, "anon_puuid(t.puuid)");
            } else if (std.mem.eql(u8, col, "match_id")) {
                try cols.appendSlice(gpa, "anon_match(t.match_id)");
            } else if (keyed and std.mem.eql(u8, col, "key")) {
                try cols.appendSlice(gpa, "k.new");
            } else {
                try cols.print(gpa, "t.\"{s}\"", .{col});
            }
            if (q.int(1) > 0) {
                pks[n_pk] = .{ .pk = q.int(1), .pos = i + 1 };
                n_pk += 1;
            }
        }
    }
    std.mem.sort(@TypeOf(pks[0]), pks[0..n_pk], {}, struct {
        fn lt(_: void, a: @TypeOf(pks[0]), b: @TypeOf(pks[0])) bool {
            return a.pk < b.pk;
        }
    }.lt);
    for (pks[0..n_pk], 0..) |p, i| try order.print(gpa, "{s}{d}", .{ if (i > 0) ", " else "", p.pos });
    const join = if (keyed)
        \\ JOIN (SELECT old_key(puuid) AS old, anon_key(puuid) AS new FROM src_main.players
        \\       UNION SELECT old_key(puuid), anon_key(puuid) FROM src_main.participants
        \\       WHERE puuid IS NOT NULL) k ON k.old = t.key
    else
        "";
    const sql = try gpa.printSentinel("INSERT INTO {s}.\"{s}\" SELECT {s} FROM {s}.\"{s}\" t{s}{s}{s}", .{
        out,                                name,        cols.items, in, name, join,
        if (n_pk > 0) " ORDER BY " else "", order.items,
    }, 0);
    defer gpa.free(sql);
    try db.exec(sql);
}

fn copyRawDocs(gpa: std.mem.Allocator, db: Db, salt: *const Salt) !void {
    const window = try gpa.alloc(u8, store.raw.window_len);
    defer gpa.free(window);
    var sel = try db.prepare("SELECT source, key, fetched_at, body FROM src_raw.raw_docs");
    defer sel.deinit();
    var put = try db.prepare("INSERT INTO out_raw.raw_docs VALUES (?, anon_match(?), ?, ?)");
    defer put.deinit();
    try sel.bind(.{});
    var done: usize = 0;
    while (try sel.step()) {
        if (!std.mem.eql(u8, sel.bytes(0), "riot_match")) return error.UnknownRawSource;
        const json = try store.raw.decompress(gpa, sel.bytes(3));
        defer gpa.free(json);
        const anon = try rewriteMatch(gpa, salt, json);
        defer gpa.free(anon);
        const body = try store.raw.compressWith(gpa, window, anon);
        defer gpa.free(body);
        try put.exec(.{ "riot_match", sel.bytes(1), sel.int(2), store.Blob{ .bytes = body } });
        done += 1;
        if (done % 20000 == 0) std.log.info("raw summaries: {d}", .{done});
    }
    std.log.info("raw summaries rewritten: {d}", .{done});
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
        try testing.expect(std.mem.find(u8, out, gone) == null);
    }
    const p1 = puuid(&test_salt, "AAA-p1");
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, out, &p1));
    try testing.expect(std.mem.find(u8, out, "\"riotIdTagline\":\"\"") != null);
    try testing.expect(std.mem.find(u8, out, "\"kills\":3") != null);
    var buf: [64]u8 = undefined;
    const id = try matchId(&test_salt, "EUW1_123", &buf);
    try testing.expect(std.mem.startsWith(u8, id, "EUW1_"));
    try testing.expect(std.mem.find(u8, out, id) != null);
    try testing.expect(std.mem.find(u8, out, id[5..]) != null);
}
