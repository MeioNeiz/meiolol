//! Squads (docs/your-games.md "Squads"): friends who each joined by the profile icon
//! check see the games they played together. A squad is its invite token (the link's
//! secret, in the page's fragment) and its members' PUUIDs; their games are their Your
//! games caches, so a squad keeps nothing else. Joining, leaving and starting one pass
//! the same icon check as an objection (fetch.zig squadCheck), in squad_checks

const std = @import("std");
const store = @import("store");
const game = @import("game.zig");

const Allocator = std.mem.Allocator;
const Db = store.Db;

pub const schema =
    \\-- token: the invite link's secret (16 random bytes, base64url). refreshed: when a
    \\-- read last queued the members' refreshes (unix s)
    \\CREATE TABLE IF NOT EXISTS squads (
    \\    id INTEGER PRIMARY KEY,
    \\    token TEXT UNIQUE NOT NULL,
    \\    name TEXT NOT NULL,
    \\    created INTEGER NOT NULL,
    \\    refreshed INTEGER NOT NULL DEFAULT 0
    \\);
    \\
    \\CREATE TABLE IF NOT EXISTS squad_members (
    \\    squad INTEGER NOT NULL,
    \\    puuid TEXT NOT NULL,
    \\    joined INTEGER NOT NULL,
    \\    PRIMARY KEY (squad, puuid)
    \\) WITHOUT ROWID;
    \\
    \\-- A start, join or leave waiting on the icon check, as `challenges`; `key` is the
    \\-- page's secret for it, so nobody else reads a new squad's token by Riot ID.
    \\-- squad: the squad joined or left, or once a start is done the new one
    \\CREATE TABLE IF NOT EXISTS squad_checks (
    \\    riot_id TEXT PRIMARY KEY,
    \\    key TEXT NOT NULL,
    \\    action TEXT NOT NULL,
    \\    squad INTEGER,
    \\    name TEXT,
    \\    puuid TEXT,
    \\    icon INTEGER,
    \\    expires INTEGER NOT NULL,
    \\    state TEXT NOT NULL
    \\) WITHOUT ROWID;
    \\
;

/// Fetcher job keys for a check: this prefix, then the lower case Riot ID
pub const check_prefix = "squad:";
pub const max_members = 10;
pub const max_name = 32;
/// A squad read queues its members' refreshes at most this often
pub const refresh_s = 30 * 60;
/// Newest first; older ones stay in the members' own Your games
pub const max_games = 50;

pub const Action = enum { create, join, leave };

pub const token_len = 22;
pub const Token = [token_len]u8;
const b64 = std.base64.url_safe_no_pad;

pub fn newToken(io: std.Io) !Token {
    var raw: [16]u8 = undefined;
    try io.randomSecure(&raw);
    var t: Token = undefined;
    _ = b64.Encoder.encode(&t, &raw);
    return t;
}

pub fn validToken(s: []const u8) bool {
    if (s.len != token_len) return false;
    for (s) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') return false;
    return true;
}

/// Trimmed; null when empty, too long, or holding control characters or bad UTF-8
pub fn cleanName(s: []const u8) ?[]const u8 {
    const t = std.mem.trim(u8, s, " \t");
    if (t.len == 0 or t.len > max_name or !std.unicode.utf8ValidateSlice(t)) return null;
    for (t) |c| if (c < 0x20 or c == 0x7f) return null;
    return t;
}

pub fn squadId(db: Db, token: []const u8) !?i64 {
    return db.scalar("SELECT id FROM squads WHERE token = ?", .{token});
}

/// What a passed check did
pub const Outcome = enum { done, full, gone };

/// After the icon check passed for `puuid`: start the squad (`check.squad` set to it),
/// join or leave. Leaving the last member deletes the squad
pub fn apply(db: Db, io: std.Io, riot_id: []const u8, puuid: []const u8, now: i64) !Outcome {
    var q = try db.prepare("SELECT action, squad, name FROM squad_checks WHERE riot_id = ?");
    defer q.deinit();
    try q.bind(.{riot_id});
    if (!try q.step()) return .gone;
    const r = q.row(struct { action: []const u8, squad: ?i64, name: ?[]const u8 });
    const action = std.meta.stringToEnum(Action, r.action) orelse return .gone;
    switch (action) {
        .create => {
            const token = try newToken(io);
            const id = try db.scalar(
                "INSERT INTO squads (token, name, created) VALUES (?, ?, ?) RETURNING id",
                .{ @as([]const u8, &token), r.name orelse "", now },
            ) orelse return error.NoSquad;
            try db.run("INSERT INTO squad_members VALUES (?, ?, ?)", .{ id, puuid, now });
            try db.run("UPDATE squad_checks SET squad = ? WHERE riot_id = ?", .{ id, riot_id });
        },
        .join => {
            const id = r.squad orelse return .gone;
            if (try db.scalar("SELECT 1 FROM squads WHERE id = ?", .{id}) == null) return .gone;
            if (try db.scalar("SELECT 1 FROM squad_members WHERE squad = ? AND puuid = ?", .{ id, puuid }) != null) return .done;
            const n = try db.scalar("SELECT count(*) FROM squad_members WHERE squad = ?", .{id}) orelse 0;
            if (n >= max_members) return .full;
            try db.run("INSERT INTO squad_members VALUES (?, ?, ?)", .{ id, puuid, now });
        },
        .leave => {
            const id = r.squad orelse return .gone;
            try db.run("DELETE FROM squad_members WHERE squad = ? AND puuid = ?", .{ id, puuid });
            try dropEmpty(db);
        },
    }
    return .done;
}

pub fn dropEmpty(db: Db) !void {
    try db.run("DELETE FROM squads WHERE id NOT IN (SELECT squad FROM squad_members)", .{});
}

/// One member's cached game
pub const Seen = struct {
    match_id: []const u8,
    slot: u8,
    summary: game.Summary,
};

pub const Seat = struct { member: u8, slot: u8 };

pub const Together = struct {
    summary: game.Summary,
    /// Members on one team, in member order
    seats: []const Seat,
};

/// Games with two or more members on the same team, newest first, remakes left out.
/// `by_member[i]`: member i's cached games. Members on both teams of a game: the side
/// with more members (blue on a tie)
pub fn together(arena: Allocator, by_member: []const []const Seen) ![]const Together {
    const Entry = struct { summary: game.Summary, seats: std.ArrayList(Seat) = .empty };
    var games: std.StringArrayHashMapUnmanaged(Entry) = .empty;
    for (by_member, 0..) |seen, m| for (seen) |s| {
        if (s.summary.remake or s.slot >= s.summary.players.len) continue;
        const e = try games.getOrPut(arena, s.match_id);
        if (!e.found_existing) e.value_ptr.* = .{ .summary = s.summary };
        try e.value_ptr.seats.append(arena, .{ .member = @intCast(m), .slot = s.slot });
    };
    var out: std.ArrayList(Together) = .empty;
    for (games.values()) |*e| {
        const players = e.summary.players;
        const first = players[e.seats.items[0].slot].team;
        var same: usize = 0;
        for (e.seats.items) |s| same += @intFromBool(players[s.slot].team == first);
        const other = e.seats.items.len - same;
        const team = if (same >= other) first else blk: {
            for (e.seats.items) |s| if (players[s.slot].team != first) break :blk players[s.slot].team;
            unreachable;
        };
        var seats: std.ArrayList(Seat) = .empty;
        for (e.seats.items) |s| if (players[s.slot].team == team) try seats.append(arena, s);
        if (seats.items.len < 2) continue;
        std.mem.sort(Seat, seats.items, {}, struct {
            fn f(_: void, a: Seat, b: Seat) bool {
                return a.member < b.member;
            }
        }.f);
        try out.append(arena, .{ .summary = e.summary, .seats = seats.items });
    }
    std.mem.sort(Together, out.items, {}, struct {
        fn f(_: void, a: Together, b: Together) bool {
            return a.summary.start_ms > b.summary.start_ms;
        }
    }.f);
    return out.items[0..@min(out.items.len, max_games)];
}

/// The check's answer for the page: as /api/forget's, plus the new squad's token once
/// a start is done. `key` must match the check's, else state none
pub fn checkJson(arena: Allocator, db: Db, riot_id: []const u8, key: []const u8, now: i64) ![]const u8 {
    var q = try db.prepare(
        \\SELECT c.key, c.state, c.icon, c.expires, c.action, s.token
        \\FROM squad_checks c LEFT JOIN squads s ON s.id = c.squad WHERE c.riot_id = ?
    );
    defer q.deinit();
    try q.bind(.{riot_id});
    if (!try q.step()) return "{\"state\":\"none\"}";
    const r = q.row(struct { key: []const u8, state: []const u8, icon: ?i64, expires: i64, action: []const u8, token: ?[]const u8 });
    if (!std.crypto.timing_safe.eql([token_len]u8, keyBytes(r.key), keyBytes(key))) return "{\"state\":\"none\"}";
    const settled = !std.mem.eql(u8, r.state, "pending") and !std.mem.eql(u8, r.state, "issued") and
        !std.mem.eql(u8, r.state, "checking") and !std.mem.eql(u8, r.state, "mismatch");
    const expired = r.expires <= now and !settled;
    const done = std.mem.eql(u8, r.state, "done");
    return std.json.Stringify.valueAlloc(arena, .{
        .state = if (expired) "expired" else r.state,
        .icon = r.icon,
        .expires = r.expires,
        .s = if (done and std.mem.eql(u8, r.action, "create")) r.token else null,
    }, .{ .emit_null_optional_fields = false });
}

fn keyBytes(s: []const u8) [token_len]u8 {
    var b: [token_len]u8 = @splat(0);
    if (s.len == token_len) @memcpy(&b, s);
    return b;
}

pub const Start = union(enum) {
    /// The check's key, for the page to send back
    started: Token,
    bad: []const u8,
    /// The queue is full
    busy,
    /// A check is waiting on the icon or Riot: the page's key still holds
    waiting,
};

/// POST: a new check for `riot_id` (replacing any other), or with `check` the icon
/// check of the one waiting. `room`: the fetcher queue has room for one more job
pub fn post(db: Db, io: std.Io, riot_id: []const u8, action: ?Action, token: ?[]const u8, name: ?[]const u8, key: ?[]const u8, check: bool, room: bool, challenge_s: i64) !Start {
    const now = std.Io.Clock.real.now(io).toSeconds();
    var buf: [128]u8 = undefined;
    const job = try std.fmt.bufPrint(&buf, "{s}{s}", .{ check_prefix, riot_id });
    if (check) {
        var q = try db.prepare("SELECT key, state, expires FROM squad_checks WHERE riot_id = ?");
        defer q.deinit();
        try q.bind(.{riot_id});
        if (!try q.step()) return .{ .bad = "no check started" };
        const r = q.row(struct { key: []const u8, state: []const u8, expires: i64 });
        if (!std.crypto.timing_safe.eql([token_len]u8, keyBytes(r.key), keyBytes(key orelse ""))) return .{ .bad = "no check started" };
        const waiting = std.mem.eql(u8, r.state, "issued") or std.mem.eql(u8, r.state, "mismatch");
        if (!waiting or r.expires <= now) return .waiting;
        if (!room) return .busy;
        try db.run("UPDATE squad_checks SET state = 'checking' WHERE riot_id = ?", .{riot_id});
        try db.run("INSERT OR REPLACE INTO jobs (key, requested) VALUES (?, 0)", .{job});
        return .waiting;
    }
    const a = action orelse return .{ .bad = "expected &do=create, join or leave" };
    var squad: ?i64 = null;
    var clean: ?[]const u8 = null;
    switch (a) {
        .create => clean = cleanName(name orelse "") orelse return .{ .bad = "a squad name of 1 to 32 characters" },
        .join, .leave => {
            const t = token orelse return .{ .bad = "expected &s=invite" };
            squad = try squadId(db, t) orelse return .{ .bad = "no such squad" };
        },
    }
    if (!room) return .busy;
    const k = try newToken(io);
    try db.run(
        "INSERT OR REPLACE INTO squad_checks VALUES (?, ?, ?, ?, ?, NULL, NULL, ?, 'pending')",
        .{ riot_id, @as([]const u8, &k), @tagName(a), squad, clean, now + challenge_s },
    );
    try db.run("INSERT OR REPLACE INTO jobs (key, requested) VALUES (?, 0)", .{job});
    return .{ .started = k };
}

test cleanName {
    try std.testing.expectEqualStrings("Duo night", cleanName("  Duo night ").?);
    try std.testing.expect(cleanName("   ") == null);
    try std.testing.expect(cleanName("a\nb") == null);
    try std.testing.expect(cleanName("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx") == null);
    try std.testing.expect(cleanName("\xff") == null);
}

test validToken {
    const t = try newToken(std.testing.io);
    try std.testing.expect(validToken(&t));
    try std.testing.expect(!validToken("short"));
    try std.testing.expect(!validToken("aaaaaaaaaaaaaaaaaaaa/a"));
}

fn testPlayer(team: i64, win: bool) game.Summary.Player {
    return .{ .hash = "", .team = team, .position = "TOP", .champion = 1, .win = win, .kills = 0, .deaths = 0, .assists = 0 };
}

test "together: two members on one team count, opposite teams and remakes don't" {
    var a: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer a.deinit();
    const arena = a.allocator();
    var players: [10]game.Summary.Player = undefined;
    for (&players, 0..) |*p, i| p.* = testPlayer(if (i < 5) 100 else 200, i < 5);
    const s = struct {
        fn sum(ps: []const game.Summary.Player, start: i64, remake: bool) game.Summary {
            return .{ .patch = "16.21", .queue = 420, .start_ms = start, .duration_s = 1800, .remake = remake, .players = ps };
        }
    }.sum;
    const m0 = [_]Seen{
        .{ .match_id = "M1", .slot = 0, .summary = s(&players, 1, false) },
        .{ .match_id = "M2", .slot = 0, .summary = s(&players, 2, false) },
        .{ .match_id = "M3", .slot = 1, .summary = s(&players, 3, true) },
        .{ .match_id = "M4", .slot = 2, .summary = s(&players, 4, false) },
    };
    const m1 = [_]Seen{
        .{ .match_id = "M1", .slot = 3, .summary = s(&players, 1, false) },
        .{ .match_id = "M2", .slot = 7, .summary = s(&players, 2, false) },
        .{ .match_id = "M3", .slot = 2, .summary = s(&players, 3, true) },
        .{ .match_id = "M4", .slot = 6, .summary = s(&players, 4, false) },
    };
    const m2 = [_]Seen{
        .{ .match_id = "M4", .slot = 8, .summary = s(&players, 4, false) },
    };
    const got = try together(arena, &.{ &m0, &m1, &m2 });
    try std.testing.expectEqual(2, got.len);
    // Newest first; in M4 members 1 and 2 are red, member 0 blue: the bigger side
    try std.testing.expectEqual(4, got[0].summary.start_ms);
    try std.testing.expectEqualSlices(Seat, &.{ .{ .member = 1, .slot = 6 }, .{ .member = 2, .slot = 8 } }, got[0].seats);
    try std.testing.expectEqual(1, got[1].summary.start_ms);
    try std.testing.expectEqualSlices(Seat, &.{ .{ .member = 0, .slot = 0 }, .{ .member = 1, .slot = 3 } }, got[1].seats);
}

test "apply: start, join, a full squad, leave; the last to leave deletes it" {
    const db = try Db.open(":memory:");
    defer db.close();
    try db.exec("CREATE TABLE jobs (key TEXT PRIMARY KEY, requested INTEGER NOT NULL, pending INTEGER, total INTEGER);\n" ++ schema);
    const io = std.testing.io;
    const started = try post(db, io, "a#1", .create, null, " Duo ", null, false, true, 900);
    try std.testing.expect(started == .started);
    try std.testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM jobs WHERE key = 'squad:a#1' AND requested = 0", .{}));
    try std.testing.expectEqual(Outcome.done, try apply(db, io, "a#1", "pa", 10));
    const id = (try db.scalar("SELECT squad FROM squad_checks WHERE riot_id = 'a#1'", .{})).?;
    var tq = try db.prepare("SELECT token, name FROM squads WHERE id = ?");
    defer tq.deinit();
    try tq.bind(.{id});
    try std.testing.expect(try tq.step());
    const sq = tq.row(struct { token: []const u8, name: []const u8 });
    try std.testing.expectEqualStrings("Duo", sq.name);
    const token = try std.testing.allocator.dupe(u8, sq.token);
    defer std.testing.allocator.free(token);
    try std.testing.expect(validToken(token));

    var i: usize = 1;
    while (i < max_members) : (i += 1) {
        var buf: [16]u8 = undefined;
        const rid = try std.fmt.bufPrint(&buf, "p{d}#1", .{i});
        _ = try post(db, io, rid, .join, token, null, null, false, true, 900);
        try std.testing.expectEqual(Outcome.done, try apply(db, io, rid, rid, 10));
    }
    _ = try post(db, io, "late#1", .join, token, null, null, false, true, 900);
    try std.testing.expectEqual(Outcome.full, try apply(db, io, "late#1", "late", 10));
    // Joining again is a no-op, not full
    _ = try post(db, io, "a#1", .join, token, null, null, false, true, 900);
    try std.testing.expectEqual(Outcome.done, try apply(db, io, "a#1", "pa", 10));

    try std.testing.expect((try post(db, io, "x#1", .join, "nosuchsquadxxxxxxxxxxx", null, null, false, true, 900)) == .bad);
    try std.testing.expect((try post(db, io, "x#1", .create, null, "", null, false, true, 900)) == .bad);
    try std.testing.expect((try post(db, io, "x#1", .create, null, "ok", null, false, false, 900)) == .busy);

    try db.run("DELETE FROM squad_members WHERE puuid != 'pa'", .{});
    _ = try post(db, io, "a#1", .leave, token, null, null, false, true, 900);
    try std.testing.expectEqual(Outcome.done, try apply(db, io, "a#1", "pa", 10));
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM squads", .{}));
}

test "checkJson: the new squad's token only with the check's key" {
    var a: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer a.deinit();
    const arena = a.allocator();
    const db = try Db.open(":memory:");
    defer db.close();
    try db.exec("CREATE TABLE jobs (key TEXT PRIMARY KEY, requested INTEGER NOT NULL, pending INTEGER, total INTEGER);\n" ++ schema);
    const io = std.testing.io;
    const k = (try post(db, io, "a#1", .create, null, "Duo", null, false, true, 900)).started;
    _ = try apply(db, io, "a#1", "pa", 10);
    try db.run("UPDATE squad_checks SET state = 'done'", .{});
    const token = try arena.dupe(u8, (try squadToken(arena, db)).?);
    const mine = try checkJson(arena, db, "a#1", &k, 20);
    try std.testing.expect(std.mem.find(u8, mine, token) != null);
    try std.testing.expect(std.mem.find(u8, mine, "\"state\":\"done\"") != null);
    const theirs = try checkJson(arena, db, "a#1", "wrongkeywrongkeywrongk", 20);
    try std.testing.expectEqualStrings("{\"state\":\"none\"}", theirs);
    try std.testing.expectEqualStrings("{\"state\":\"none\"}", try checkJson(arena, db, "a#1", "", 20));
}

fn squadToken(arena: Allocator, db: Db) !?[]const u8 {
    var q = try db.prepare("SELECT token FROM squads");
    defer q.deinit();
    if (!try q.step()) return null;
    return try arena.dupe(u8, q.bytes(0));
}
