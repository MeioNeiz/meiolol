//! Testers' applications for the desktop app (ui.applydata): api.db's applications
//! table behind /api/apply (anyone) and /api/applications.bin (manage_accounts; root.zig
//! checks). Approving only marks a row: Jacob makes the private login and sends it
//! himself. No IP, PUUID or Riot call; retention in `prune`, erasure in `forgetRiotId`
//! and the admin's Delete (docs/data-safety.md)
//!
//!   POST /api/apply                            a ui.applydata.New; {"ok":true}
//!   GET  /api/applications.bin                 a ui.applydata.List
//!   POST /api/applications.bin?id=N&set=S      S a ui.applydata.Set; the List again
const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const cache = @import("cache.zig");
const param = @import("root.zig").param;

const Allocator = std.mem.Allocator;
const Status = std.http.Status;
const ad = ui.applydata;

pub const schema =
    \\-- Testers' applications (applications.zig): ui.applydata.Application; riot_key is
    \\-- cache.riotIdKey's, for erasure; decided 0 while open
    \\CREATE TABLE IF NOT EXISTS applications (
    \\    id INTEGER PRIMARY KEY,
    \\    created INTEGER NOT NULL,
    \\    decided INTEGER NOT NULL,
    \\    riot_id TEXT NOT NULL,
    \\    riot_key TEXT NOT NULL,
    \\    contact TEXT NOT NULL,
    \\    role INTEGER NOT NULL,
    \\    rank INTEGER NOT NULL,
    \\    why TEXT NOT NULL,
    \\    status INTEGER NOT NULL
    \\);
    \\CREATE INDEX IF NOT EXISTS applications_key ON applications (riot_key);
    \\
;

/// Kept at once; more are refused (507) until some are decided and pruned
pub const max_kept = 1000;
/// New rows a day, everyone together: bounds a script nginx's per-IP limit lets through
pub const max_day = 50;
/// A New with every field at its cap fits, under nginx's 1k for /api/
pub const max_body = 1024;
/// Retention (privacy page "Testing the desktop app"): decided rows, open ones
pub const keep_decided_days = 30;
pub const keep_open_days = 180;

pub const Reply = struct { status: Status, body: []const u8, binary: bool = false };

/// A form's application. The same Riot ID and contact again updates that row (a second
/// try, a fix); anything else is a new row, so nobody can rewrite another's
pub fn apply(arena: Allocator, db: store.Db, body: []const u8, now: i64) !Reply {
    const n = ui.data.decode(arena, ad.New, body) catch return failed(arena, .bad_request, "expected a ui.applydata.New");
    if (ad.check(n)) |why| return failed(arena, .bad_request, why);
    const riot_id = std.mem.trim(u8, n.riot_id, " ");
    const contact = if (ad.contactKind(n.contact).? == .discord and n.contact[0] == '@') n.contact[1..] else n.contact;
    const why = std.mem.trim(u8, n.why, " \t");
    const key = riotKey(arena, riot_id) orelse return failed(arena, .bad_request, "Riot ID: Name#TAG, as the League client shows it.");
    try db.run("UPDATE applications SET riot_id = ?, role = ?, rank = ?, why = ? WHERE riot_key = ? AND lower(contact) = lower(?)", .{
        riot_id, @backingInt(n.role), @backingInt(n.rank), why, key, contact,
    });
    if (db.changes() == 0) {
        if ((try db.scalar("SELECT count(*) FROM applications WHERE created > ?", .{now - std.time.s_per_day}) orelse 0) >= max_day)
            return failed(arena, .too_many_requests, "Too many applications today: try tomorrow.");
        if ((try db.scalar("SELECT count(*) FROM applications", .{}) orelse 0) >= max_kept)
            return failed(arena, .insufficient_storage, "Not taking applications right now.");
        try db.run("INSERT INTO applications VALUES (NULL, ?, 0, ?, ?, ?, ?, ?, ?, 0)", .{
            now, riot_id, key, contact, @backingInt(n.role), @backingInt(n.rank), why,
        });
    }
    return .{ .status = .ok, .body = "{\"ok\":true}" };
}

/// GET: every application, newest first; POST: one changed or deleted, then the same
pub fn admin(arena: Allocator, db: store.Db, post: bool, query: []const u8, now: i64) !Reply {
    if (post) {
        const id_s = try param(arena, query, "id") orelse return failed(arena, .bad_request, "expected ?id=N&set=S");
        const id = std.fmt.parseInt(u32, id_s, 10) catch return failed(arena, .bad_request, "expected ?id=N&set=S");
        const set = std.meta.stringToEnum(ad.Set, try param(arena, query, "set") orelse "") orelse
            return failed(arena, .bad_request, "expected set=open|approved|declined|delete");
        switch (set) {
            .delete => try db.run("DELETE FROM applications WHERE id = ?", .{id}),
            inline else => |s| {
                const status = @field(ad.Status, @tagName(s));
                try db.run("UPDATE applications SET status = ?, decided = ? WHERE id = ?", .{ @backingInt(status), if (status == .open) 0 else now, id });
            },
        }
        if (db.changes() == 0) return failed(arena, .not_found, "no such application");
    }
    var q = try db.prepare("SELECT id, created, decided, riot_id, contact, role, rank, why, status FROM applications ORDER BY id DESC LIMIT ?");
    defer q.deinit();
    try q.bind(.{max_kept + 1});
    var out: std.ArrayList(ad.Application) = .empty;
    var more = false;
    while (try q.step()) {
        if (out.items.len == max_kept) {
            more = true;
            break;
        }
        const r = q.row(struct { id: i64, created: i64, decided: i64, riot_id: []const u8, contact: []const u8, role: i64, rank: i64, why: []const u8, status: i64 });
        try out.append(arena, .{
            .id = std.math.cast(u32, r.id) orelse return error.BadApplication,
            .created = r.created,
            .decided = r.decided,
            .riot_id = try arena.dupe(u8, r.riot_id),
            .contact = try arena.dupe(u8, r.contact),
            .role = std.enums.fromInt(ad.Role, r.role) orelse return error.BadApplication,
            .rank = std.enums.fromInt(ad.Rank, r.rank) orelse return error.BadApplication,
            .why = try arena.dupe(u8, r.why),
            .status = std.enums.fromInt(ad.Status, r.status) orelse return error.BadApplication,
        });
    }
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ad.List, .{ .applications = out.items, .more = more }, &bytes);
    return .{ .status = .ok, .body = bytes.items, .binary = true };
}

/// Retention: decided ones `keep_decided_days` after the decision, open ones
/// `keep_open_days` after they came. Caller may hold a transaction
pub fn prune(db: store.Db, now: i64) !void {
    try db.run("DELETE FROM applications WHERE (status != 0 AND decided < ?) OR (status = 0 AND created < ?)", .{
        now - keep_decided_days * std.time.s_per_day, now - keep_open_days * std.time.s_per_day,
    });
}

/// Erasure for one Riot ID (`riot_key`: cache.riotIdKey's), whatever its contact
pub fn forgetRiotId(db: store.Db, riot_key: []const u8) !void {
    try db.run("DELETE FROM applications WHERE riot_key = ?", .{riot_key});
}

/// cache.riotIdKey of a checked Name#TAG
pub fn riotKey(arena: Allocator, riot_id: []const u8) ?[]const u8 {
    const at = std.mem.findScalarLast(u8, riot_id, '#') orelse return null;
    const buf = arena.alloc(u8, riot_id.len) catch return null;
    return cache.riotIdKey(buf, riot_id[0..at], riot_id[at + 1 ..]);
}

fn failed(arena: Allocator, status: Status, message: []const u8) !Reply {
    return .{ .status = status, .body = try std.json.Stringify.valueAlloc(arena, .{ .@"error" = message }, .{}) };
}

const testing = std.testing;

fn encoded(arena: Allocator, n: ad.New) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ad.New, n, &out);
    return out.items;
}

fn listed(arena: Allocator, db: store.Db) !ad.List {
    const r = try admin(arena, db, false, "", 0);
    try testing.expectEqual(Status.ok, r.status);
    return ui.data.decode(arena, ad.List, r.body);
}

test "applications: store, update by Riot ID and contact, decide, delete" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const db = try cache.open(":memory:");
    defer db.close();
    const n: ad.New = .{ .riot_id = " Meio Neiz#EUW ", .contact = "@meio_neiz", .role = .mid, .rank = .gold, .why = " I play every day " };
    try testing.expectEqual(Status.ok, (try apply(a, db, try encoded(a, n), 100)).status);
    var again = n;
    again.riot_id = "meio neiz#euw";
    again.contact = "MEIO_NEIZ";
    again.why = "Fixed my line";
    try testing.expectEqual(Status.ok, (try apply(a, db, try encoded(a, again), 200)).status);
    // Someone else's contact: a row of its own, the first untouched
    var other = n;
    other.contact = "x@y.zz";
    other.why = "Not me";
    try testing.expectEqual(Status.ok, (try apply(a, db, try encoded(a, other), 300)).status);
    const l = try listed(a, db);
    try testing.expectEqual(2, l.applications.len);
    const first = l.applications[1];
    try testing.expectEqualStrings("meio neiz#euw", first.riot_id);
    try testing.expectEqualStrings("meio_neiz", first.contact);
    try testing.expectEqualStrings("Fixed my line", first.why);
    try testing.expectEqual(100, first.created);
    try testing.expectEqual(ad.Rank.gold, first.rank);

    const r = try admin(a, db, true, "id=1&set=approved", 400);
    const after = try ui.data.decode(a, ad.List, r.body);
    try testing.expectEqual(ad.Status.approved, after.applications[1].status);
    try testing.expectEqual(400, after.applications[1].decided);
    try testing.expectEqual(Status.not_found, (try admin(a, db, true, "id=9&set=declined", 0)).status);
    try testing.expectEqual(Status.bad_request, (try admin(a, db, true, "id=1&set=maybe", 0)).status);
    _ = try admin(a, db, true, "id=2&set=delete", 0);
    try testing.expectEqual(1, (try listed(a, db)).applications.len);

    try forgetRiotId(db, (riotKey(a, "Meio Neiz#EUW")).?);
    try testing.expectEqual(0, (try listed(a, db)).applications.len);
}

test "applications: refuses bad bodies, stops at its caps, prunes" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const db = try cache.open(":memory:");
    defer db.close();
    const ok: ad.New = .{ .riot_id = "A#1", .contact = "a@b.cd", .why = "x" };
    var bad = ok;
    bad.contact = "no pe";
    try testing.expectEqual(Status.bad_request, (try apply(a, db, try encoded(a, bad), 1)).status);
    try testing.expectEqual(Status.bad_request, (try apply(a, db, "junk", 1)).status);
    const day = std.time.s_per_day;
    for (0..max_day) |i| {
        var n = ok;
        n.contact = try a.print("p{d}@b.cd", .{i});
        try testing.expectEqual(Status.ok, (try apply(a, db, try encoded(a, n), 10 * day)).status);
    }
    try testing.expectEqual(Status.too_many_requests, (try apply(a, db, try encoded(a, ok), 10 * day)).status);
    // The next day takes more
    try testing.expectEqual(Status.ok, (try apply(a, db, try encoded(a, ok), 11 * day + 1)).status);
    try db.run("UPDATE applications SET status = 1, decided = ? WHERE id <= 10", .{10 * day});
    try prune(db, (10 + keep_decided_days) * day + 1);
    try testing.expectEqual(max_day + 1 - 10, try db.scalar("SELECT count(*) FROM applications", .{}));
    try prune(db, (11 + keep_open_days) * day + 2);
    try testing.expectEqual(0, try db.scalar("SELECT count(*) FROM applications", .{}));

    try db.run("WITH RECURSIVE c(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM c WHERE i < ?) INSERT INTO applications SELECT NULL, 0, 0, 'A#1', 'a#1', 'c' || i, 0, 0, 'x', 0 FROM c", .{max_kept});
    try testing.expectEqual(Status.insufficient_storage, (try apply(a, db, try encoded(a, ok), 20 * day)).status);
}

test "applications: a New at every cap fits max_body" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const n: ad.New = .{
        .riot_id = @as([32]u8, @splat('a')) ++ "#" ++ @as([8]u8, @splat('b')),
        .contact = @as([ad.max_contact - 6]u8, @splat('c')) ++ "@d.com",
        .role = .support,
        .rank = .challenger,
        .why = &@as([ad.max_why]u8, @splat('w')),
    };
    try testing.expectEqual(null, ad.check(n));
    try testing.expect((try encoded(a, n)).len <= max_body);
}
