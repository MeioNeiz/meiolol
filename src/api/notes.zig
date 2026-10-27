//! Notes on the live site (ui.notesdata, the notes island): api.db's notes table behind
//! /api/notes, for logins with take_notes (root.zig checks), and the dev server's local
//! file (serve.zig), the same handler without a login.
//!
//!   GET   /api/notes?path=P        open and fixed notes for P and every "everywhere" one
//!   GET   /api/notes?all=1[&status=open|fixed|kept|done|any]  every note, default open
//!   POST  /api/notes               a ui.notesdata.New; the stored Note
//!   PATCH /api/notes?id=N          a ui.notesdata.Change; the stored Note
//!
//! Bodies and 200s are ui.data binary; errors JSON
const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const param = @import("root.zig").param;

const Allocator = std.mem.Allocator;
const Status = std.http.Status;
const nd = ui.notesdata;

pub const schema =
    \\-- Notes on the live site (notes.zig): ui.notesdata.Note; scope 0 page, 1 everywhere;
    \\-- kind 0 page, 1 component, 2 island; theme 0 light, 1 dark; status nd.Status
    \\CREATE TABLE IF NOT EXISTS notes (
    \\    id INTEGER PRIMARY KEY,
    \\    created INTEGER NOT NULL,
    \\    updated INTEGER NOT NULL,
    \\    author TEXT NOT NULL,
    \\    path TEXT NOT NULL,
    \\    hash TEXT NOT NULL,
    \\    scope INTEGER NOT NULL,
    \\    kind INTEGER NOT NULL,
    \\    name TEXT NOT NULL,
    \\    nth INTEGER NOT NULL,
    \\    steps TEXT NOT NULL,
    \\    snippet TEXT NOT NULL,
    \\    vw INTEGER NOT NULL,
    \\    vh INTEGER NOT NULL,
    \\    theme INTEGER NOT NULL,
    \\    text TEXT NOT NULL,
    \\    status INTEGER NOT NULL,
    \\    reply TEXT NOT NULL
    \\);
    \\CREATE INDEX IF NOT EXISTS notes_path ON notes (status, path);
    \\CREATE INDEX IF NOT EXISTS notes_scope ON notes (status, scope);
    \\-- Paths as nd.canonical keeps them (rows from before it: /index.html, /matchup/index.html)
    \\UPDATE notes SET path = substr(path, 1, length(path) - 10) WHERE path LIKE '%/index.html';
    \\
;

/// Notes kept; more are refused (507) until some are deleted by hand
pub const max_notes = 5000;
/// Open and fixed notes one page's GET returns, newest first
pub const max_page = 200;
/// A New with every field at its cap fits (about 7.4 KB)
pub const max_body = 12 * 1024;

pub const Reply = struct { status: Status, body: []const u8, binary: bool = false };

pub const Method = enum { GET, POST, PATCH };

pub fn handle(arena: Allocator, db: store.Db, method: Method, query: []const u8, body: []const u8, author: []const u8, now: i64) !Reply {
    return switch (method) {
        .GET => list(arena, db, query),
        .POST => add(arena, db, body, author, now),
        .PATCH => change(arena, db, query, body, now),
    };
}

fn list(arena: Allocator, db: store.Db, query: []const u8) !Reply {
    if (try param(arena, query, "all")) |_| {
        const s = try param(arena, query, "status") orelse "open";
        const status: ?nd.Status = if (std.mem.eql(u8, s, "any")) null else std.meta.stringToEnum(nd.Status, s) orelse
            return try failed(arena, .bad_request, "expected status=open|fixed|kept|done|any");
        if (status) |v| return found(arena, db, "WHERE status = ?", .{@backingInt(v)}, max_notes);
        return found(arena, db, "", .{}, max_notes);
    }
    const path = nd.canonical(try param(arena, query, "path") orelse return try failed(arena, .bad_request, "expected ?path= or ?all=1"));
    if (path.len > nd.max_path) return try failed(arena, .bad_request, "path too long");
    return found(arena, db, "WHERE status IN (?, ?) AND (path = ? OR scope = 1)", .{ @backingInt(nd.Status.open), @backingInt(nd.Status.fixed), path }, max_page);
}

const columns = "id, created, updated, author, path, hash, scope, kind, name, nth, steps, snippet, vw, vh, theme, text, status, reply";

const Row = struct {
    id: i64,
    created: i64,
    updated: i64,
    author: []const u8,
    path: []const u8,
    hash: []const u8,
    scope: i64,
    kind: i64,
    name: []const u8,
    nth: i64,
    steps: []const u8,
    snippet: []const u8,
    vw: i64,
    vh: i64,
    theme: i64,
    text: []const u8,
    status: i64,
    reply: []const u8,
};

/// Notes matching `where`, newest first, at most `cap`
fn found(arena: Allocator, db: store.Db, comptime where: []const u8, args: anytype, cap: usize) !Reply {
    var q = try db.prepare("SELECT " ++ columns ++ " FROM notes " ++ where ++ " ORDER BY id DESC LIMIT ?");
    defer q.deinit();
    try q.bind(args ++ .{cap + 1});
    var notes: std.ArrayList(nd.Note) = .empty;
    var more = false;
    while (try q.step()) {
        if (notes.items.len == cap) {
            more = true;
            break;
        }
        try notes.append(arena, try noteOf(arena, q.row(Row)));
    }
    return binary(arena, nd.List, .{ .notes = notes.items, .more = more });
}

/// A row as a Note, strings copied to `arena` (a row's are valid until the next step)
fn noteOf(arena: Allocator, r: Row) !nd.Note {
    const bad = error.BadNote;
    return .{
        .id = std.math.cast(u32, r.id) orelse return bad,
        .created = r.created,
        .updated = r.updated,
        .author = try arena.dupe(u8, r.author),
        .path = try arena.dupe(u8, r.path),
        .hash = try arena.dupe(u8, r.hash),
        .scope = std.enums.fromInt(nd.Scope, r.scope) orelse return bad,
        .target = .{
            .kind = std.enums.fromInt(nd.Target.Kind, r.kind) orelse return bad,
            .name = try arena.dupe(u8, r.name),
            .nth = std.math.cast(u16, r.nth) orelse return bad,
            .steps = try arena.dupe(u8, r.steps),
            .snippet = try arena.dupe(u8, r.snippet),
        },
        .vw = std.math.cast(u16, r.vw) orelse return bad,
        .vh = std.math.cast(u16, r.vh) orelse return bad,
        .theme = std.enums.fromInt(nd.Theme, r.theme) orelse return bad,
        .text = try arena.dupe(u8, r.text),
        .status = std.enums.fromInt(nd.Status, r.status) orelse return bad,
        .reply = try arena.dupe(u8, r.reply),
    };
}

fn add(arena: Allocator, db: store.Db, body: []const u8, author: []const u8, now: i64) !Reply {
    const n = ui.data.decode(arena, nd.New, body) catch return try failed(arena, .bad_request, "expected a ui.notesdata.New");
    if (nd.check(n)) |why| return try failed(arena, .bad_request, why);
    if ((try db.scalar("SELECT count(*) FROM notes", .{}) orelse 0) >= max_notes) return try failed(arena, .insufficient_storage, "too many notes");
    const t = n.target;
    try db.run("INSERT INTO notes (" ++ columns ++ ") VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, '')", .{
        now,       now,  author, nd.canonical(n.path), n.hash, @backingInt(n.scope), @backingInt(t.kind), t.name, t.nth, t.steps,
        t.snippet, n.vw, n.vh,   @backingInt(n.theme), n.text,
    });
    const id = try db.scalar("SELECT last_insert_rowid()", .{}) orelse return error.BadNote;
    return one(arena, db, id);
}

fn change(arena: Allocator, db: store.Db, query: []const u8, body: []const u8, now: i64) !Reply {
    const id_s = try param(arena, query, "id") orelse return try failed(arena, .bad_request, "expected ?id=N");
    const id = std.fmt.parseInt(u32, id_s, 10) catch return try failed(arena, .bad_request, "expected ?id=N");
    const c = ui.data.decode(arena, nd.Change, body) catch return try failed(arena, .bad_request, "expected a ui.notesdata.Change");
    if (nd.checkChange(c)) |why| return try failed(arena, .bad_request, why);
    const status: ?i64 = if (c.status) |s| @backingInt(s) else null;
    try db.run("UPDATE notes SET status = coalesce(?, status), reply = coalesce(?, reply), updated = ? WHERE id = ?", .{ status, c.reply, now, id });
    if (db.changes() == 0) return try failed(arena, .not_found, "no such note");
    return one(arena, db, id);
}

fn one(arena: Allocator, db: store.Db, id: i64) !Reply {
    var q = try db.prepare("SELECT " ++ columns ++ " FROM notes WHERE id = ?");
    defer q.deinit();
    try q.bind(.{id});
    if (!try q.step()) return try failed(arena, .not_found, "no such note");
    return binary(arena, nd.Note, try noteOf(arena, q.row(Row)));
}

fn binary(arena: Allocator, comptime T: type, v: T) !Reply {
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, T, v, &out);
    return .{ .status = .ok, .body = out.items, .binary = true };
}

fn failed(arena: Allocator, status: Status, message: []const u8) !Reply {
    return .{ .status = status, .body = try std.json.Stringify.valueAlloc(arena, .{ .@"error" = message }, .{}) };
}

fn testDb() !store.Db {
    const db = try store.Db.open(":memory:");
    errdefer db.close();
    try db.exec(schema);
    return db;
}

fn encoded(arena: Allocator, comptime T: type, v: T) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, T, v, &out);
    return out.items;
}

fn decoded(arena: Allocator, comptime T: type, r: Reply) !T {
    try std.testing.expectEqual(Status.ok, r.status);
    return ui.data.decode(arena, T, r.body);
}

/// `n` rows as `add` writes them, open, on `path`
fn fill(db: store.Db, n: usize, path: []const u8) !void {
    try db.run("WITH RECURSIVE c(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM c WHERE i < ?) INSERT INTO notes (" ++ columns ++
        ") SELECT NULL, i, i, 'a', ?, '', 0, 0, '', 0, '', '', 0, 0, 0, 'x', 0, '' FROM c", .{ n, path });
}

test "notes: a page gets its own open notes and every everywhere one; done ones leave" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const db = try testDb();
    defer db.close();
    const row: nd.Target = .{ .kind = .component, .name = "c-tierrow", .nth = 2, .steps = "div:0>span:1", .snippet = "Ahri 52.3%" };
    const news = [_]nd.New{
        .{ .path = "/tier/", .hash = "?role=mid", .target = row, .vw = 390, .vh = 844, .theme = .dark, .text = "Row too tall" },
        .{ .path = "/champion/ahri", .scope = .everywhere, .target = row, .text = "Every tier row: tighter" },
        .{ .path = "/champion/ahri", .text = "Whole page: slow" },
    };
    for (news, 1..) |n, i| {
        const got = try decoded(a, nd.Note, try handle(a, db, .POST, "", try encoded(a, nd.New, n), "jacob", 100 + @as(i64, @intCast(i))));
        try std.testing.expectEqual(@as(u32, @intCast(i)), got.id);
        try std.testing.expectEqualStrings("jacob", got.author);
        try std.testing.expectEqual(nd.Status.open, got.status);
        try std.testing.expectEqualStrings(n.text, got.text);
        try std.testing.expectEqualDeep(n.target, got.target);
    }
    const tier = try decoded(a, nd.List, try handle(a, db, .GET, "path=%2Ftier%2F", "", "", 0));
    try std.testing.expectEqual(2, tier.notes.len);
    try std.testing.expectEqual(2, tier.notes[0].id);
    try std.testing.expectEqual(1, tier.notes[1].id);
    try std.testing.expectEqual(nd.Theme.dark, tier.notes[1].theme);
    try std.testing.expectEqual(390, tier.notes[1].vw);
    try std.testing.expectEqualStrings("?role=mid", tier.notes[1].hash);
    try std.testing.expect(!tier.more);

    const done = try decoded(a, nd.Note, try handle(a, db, .PATCH, "id=1", try encoded(a, nd.Change, .{ .status = .done, .reply = "1a2b3c4d" }), "", 200));
    try std.testing.expectEqual(nd.Status.done, done.status);
    try std.testing.expectEqualStrings("1a2b3c4d", done.reply);
    try std.testing.expectEqual(200, done.updated);
    try std.testing.expectEqual(101, done.created);
    // A reply alone keeps the status
    const replied = try decoded(a, nd.Note, try handle(a, db, .PATCH, "id=1", try encoded(a, nd.Change, .{ .reply = "and 5e6f" }), "", 201));
    try std.testing.expectEqual(nd.Status.done, replied.status);
    try std.testing.expectEqual(1, (try decoded(a, nd.List, try handle(a, db, .GET, "path=/tier/", "", "", 0))).notes.len);
    // A fixed note keeps its pin for Jacob's check; a kept one leaves
    _ = try decoded(a, nd.Note, try handle(a, db, .PATCH, "id=2", try encoded(a, nd.Change, .{ .status = .fixed, .reply = "9f8e7d6c" }), "", 202));
    try std.testing.expectEqual(1, (try decoded(a, nd.List, try handle(a, db, .GET, "path=/tier/", "", "", 0))).notes.len);
    try std.testing.expectEqual(1, (try decoded(a, nd.List, try handle(a, db, .GET, "all=1&status=fixed", "", "", 0))).notes.len);
    _ = try decoded(a, nd.Note, try handle(a, db, .PATCH, "id=2", try encoded(a, nd.Change, .{ .status = .kept, .reply = "fine as is" }), "", 203));
    try std.testing.expectEqual(0, (try decoded(a, nd.List, try handle(a, db, .GET, "path=/tier/", "", "", 0))).notes.len);

    try std.testing.expectEqual(1, (try decoded(a, nd.List, try handle(a, db, .GET, "all=1", "", "", 0))).notes.len);
    try std.testing.expectEqual(1, (try decoded(a, nd.List, try handle(a, db, .GET, "all=1&status=done", "", "", 0))).notes.len);
    try std.testing.expectEqual(3, (try decoded(a, nd.List, try handle(a, db, .GET, "all=1&status=any", "", "", 0))).notes.len);
}

test "notes: refuses bad requests and bodies, and stops at its caps" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const db = try testDb();
    defer db.close();
    const ok = try encoded(a, nd.New, .{ .path = "/a", .text = "x" });
    const bad_new = try encoded(a, nd.New, .{ .path = "/a", .text = "" });
    const change_ok = try encoded(a, nd.Change, .{ .status = .done });
    const long_path: [nd.max_path]u8 = @splat('a');
    const cases = [_]struct { Method, []const u8, []const u8, Status }{
        .{ .GET, "", "", .bad_request },
        .{ .GET, "all=1&status=old", "", .bad_request },
        .{ .GET, try a.print("path=/{s}", .{&long_path}), "", .bad_request },
        .{ .POST, "", "", .bad_request },
        .{ .POST, "", ok[0 .. ok.len - 1], .bad_request },
        .{ .POST, "", change_ok, .bad_request },
        .{ .POST, "", bad_new, .bad_request },
        .{ .PATCH, "", change_ok, .bad_request },
        .{ .PATCH, "id=x", change_ok, .bad_request },
        .{ .PATCH, "id=1", change_ok, .not_found },
        .{ .PATCH, "id=1", ok, .bad_request },
        .{ .PATCH, "id=1", try encoded(a, nd.Change, .{}), .bad_request },
    };
    for (cases) |c| {
        const r = try handle(a, db, c[0], c[1], c[2], "jacob", 1);
        try std.testing.expectEqual(c[3], r.status);
        try std.testing.expect(!r.binary);
        try std.testing.expectStringStartsWith(r.body, "{\"error\":\"");
    }
    try std.testing.expectEqual(0, try db.scalar("SELECT count(*) FROM notes", .{}));

    try fill(db, max_page + 1, "/a");
    const page = try decoded(a, nd.List, try handle(a, db, .GET, "path=/a", "", "", 0));
    try std.testing.expectEqual(max_page, page.notes.len);
    try std.testing.expect(page.more);
    try std.testing.expectEqual(max_page + 1, page.notes[0].id);

    try fill(db, max_notes - max_page - 1, "/b");
    try std.testing.expectEqual(Status.insufficient_storage, (try handle(a, db, .POST, "", ok, "jacob", 1)).status);
    const all = try decoded(a, nd.List, try handle(a, db, .GET, "all=1", "", "", 0));
    try std.testing.expectEqual(max_notes, all.notes.len);
    try std.testing.expect(!all.more);
}

test "notes: a damaged row is an error, never a bad value" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const db = try testDb();
    defer db.close();
    try fill(db, 1, "/a");
    try db.run("UPDATE notes SET theme = 7", .{});
    try std.testing.expectError(error.BadNote, handle(a, db, .GET, "path=/a", "", "", 0));
}

test "notes: a New with every field at its cap fits max_body" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var steps: std.ArrayList(u8) = .empty;
    for (0..nd.max_steps) |i| try steps.print(a, "{s}abcdefghijklmnop:999", .{if (i > 0) ">" else ""});
    var path: std.ArrayList(u8) = .empty;
    try path.append(a, '/');
    try path.appendNTimes(a, 'a', nd.max_path - 1);
    const n: nd.New = .{
        .path = path.items,
        .hash = "#" ++ @as([nd.max_hash - 1]u8, @splat('a')),
        .scope = .everywhere,
        .target = .{
            .kind = .component,
            .name = "c-" ++ @as([nd.max_name - 2]u8, @splat('a')),
            .nth = std.math.maxInt(u16),
            .steps = steps.items,
            .snippet = &@as([nd.max_snippet]u8, @splat('a')),
        },
        .text = &@as([nd.max_text]u8, @splat('a')),
    };
    try std.testing.expectEqual(null, nd.check(n));
    try std.testing.expect((try encoded(a, nd.New, n)).len <= max_body);
}

test "notes: / and /index.html are one page, rows from before moved too" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const db = try testDb();
    defer db.close();
    try fill(db, 1, "/matchup/index.html");
    try db.exec(schema);
    try std.testing.expectEqual(1, (try decoded(a, nd.List, try handle(a, db, .GET, "path=/matchup/", "", "", 0))).notes.len);
    const got = try decoded(a, nd.Note, try handle(a, db, .POST, "", try encoded(a, nd.New, .{ .path = "/index.html", .text = "x" }), "jacob", 1));
    try std.testing.expectEqualStrings("/", got.path);
    try std.testing.expectEqual(1, (try decoded(a, nd.List, try handle(a, db, .GET, "path=/index.html", "", "", 0))).notes.len);
}
