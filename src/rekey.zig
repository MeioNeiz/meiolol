//! `meiolol rekey` for a new app's key (personal -> production): Riot encrypts PUUIDs per
//! app, so every stored PUUID changes. Crawl state is re-seeded from the ladders
//! (schema.rekey), but the erasure lists cannot be: `forgotten` on the box and `blocked`
//! in the Your games cache must follow each player, or they could be crawled again.
//! Riot ID by PUUID with the old key, then PUUID by Riot ID with the new one; the Riot ID
//! lives only between the two requests, never on disk or in logs. Runbook:
//! docs/data-safety.md, "Key switch".

const std = @import("std");
const store = @import("store");
const riot = @import("riot/root.zig");
const forget = @import("forget.zig");
const cache = @import("api/root.zig").cache;

const Db = store.Db;
const Client = riot.client.Client;

pub const Outcome = union(enum) {
    /// The new key's PUUID, allocated with the new client's allocator
    moved: []u8,
    /// Both keys give the same PUUID: Riot linked the apps' encryption
    same,
    /// No account under the old key (deleted), so no new PUUID will ever exist
    gone,
};

pub fn translate(old: *Client, new: *Client, puuid: []const u8) !Outcome {
    var path_buf: [256]u8 = undefined;
    const path = try std.mem.print(&path_buf, "/riot/account/v1/accounts/by-puuid/{s}", .{puuid});
    // Riot IDs are global: any account-v1 route answers
    const body = try old.get("europe", path, "account-v1.by-puuid") orelse return .gone;
    defer old.gpa.free(body);
    const parsed = try std.json.parseFromSlice(struct {
        gameName: ?[]const u8 = null,
        tagLine: ?[]const u8 = null,
    }, old.gpa, body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var id_buf: [128]u8 = undefined;
    const riot_id = try std.mem.print(&id_buf, "{s}#{s}", .{
        parsed.value.gameName orelse return error.NoRiotId,
        parsed.value.tagLine orelse return error.NoRiotId,
    });
    // Renamed between the two requests, the only way an account seen a moment ago is missing
    const found = try forget.resolveRiotId(new.gpa, new, riot_id) orelse return error.RiotIdNotFound;
    if (std.mem.eql(u8, found, puuid)) {
        new.gpa.free(found);
        return .same;
    }
    return .{ .moved = found };
}

/// Every listed PUUID translated, before anything is written
pub const Plan = struct {
    /// Old PUUID to new; null when the account is gone
    moves: std.StringHashMapUnmanaged(?[]const u8) = .empty,
    moved: usize = 0,
    same: usize = 0,
    gone: usize = 0,

    /// `puuids` from the erasure lists, `probes` from players: when the lists are empty a
    /// player still tells whether the keys share encryption, and is not carried over.
    /// error.MixedEncryption when some PUUIDs change and others don't (a list holding
    /// PUUIDs of both apps: stop and look)
    pub fn build(arena: std.mem.Allocator, old: *Client, new: *Client, puuids: []const []const u8, probes: []const []const u8) !Plan {
        var p: Plan = .{};
        for (puuids) |puuid| {
            const slot = try p.moves.getOrPut(arena, puuid);
            if (slot.found_existing) continue;
            slot.key_ptr.* = try arena.dupe(u8, puuid);
            slot.value_ptr.* = switch (try translate(old, new, puuid)) {
                .moved => |m| blk: {
                    defer new.gpa.free(m);
                    p.moved += 1;
                    break :blk try arena.dupe(u8, m);
                },
                .same => blk: {
                    p.same += 1;
                    break :blk slot.key_ptr.*;
                },
                .gone => blk: {
                    p.gone += 1;
                    break :blk null;
                },
            };
        }
        if (puuids.len == 0) for (probes) |puuid| switch (try translate(old, new, puuid)) {
            .moved => |m| {
                new.gpa.free(m);
                p.moved += 1;
                break;
            },
            .same => {
                p.same += 1;
                break;
            },
            .gone => {},
        };
        if (p.same > 0 and p.moved > 0) return error.MixedEncryption;
        return p;
    }

    /// The keys share encryption: PUUIDs stay, so there is nothing to rekey
    pub fn linked(p: Plan) bool {
        return p.same > 0;
    }
};

/// Crawler databases: `forgotten` carried over and crawl state cleared in one
/// transaction, so a failure leaves the old state whole and a rerun starts afresh
pub fn applyCrawl(gpa: std.mem.Allocator, db: Db, plan: *const Plan) !void {
    try forget.ensure(db);
    try db.begin();
    errdefer db.rollback();
    try carry(gpa, db, "forgotten", "forgotten_at", plan);
    try store.schema.rekeyRows(db);
    try db.commit();
    try store.schema.apply(db);
}

/// Your games cache (api.db): `blocked` carried over, cached players cleared
pub fn applyApi(gpa: std.mem.Allocator, db: Db, plan: *const Plan) !void {
    try db.begin();
    errdefer db.rollback();
    try carry(gpa, db, "blocked", "at", plan);
    try cache.clearForRekey(db);
    try db.commit();
}

/// Rewrites a (puuid, time) erasure list through the plan, keeping each entry's date.
/// error.ListChanged when it holds a PUUID the plan has not seen: something added one
/// during the translation (stop the crawler and loops first), so run again
fn carry(gpa: std.mem.Allocator, db: Db, comptime table: []const u8, comptime at: []const u8, plan: *const Plan) !void {
    const rows = try readList(gpa, db, "SELECT puuid FROM " ++ table);
    defer freeList(gpa, rows);
    for (rows) |old| {
        const new = plan.moves.get(old) orelse return error.ListChanged;
        if (new) |n| {
            if (std.mem.eql(u8, n, old)) continue;
            try db.run("INSERT OR IGNORE INTO " ++ table ++ " SELECT ?2, " ++ at ++
                " FROM " ++ table ++ " WHERE puuid = ?1", .{ old, n });
        }
        try db.run("DELETE FROM " ++ table ++ " WHERE puuid = ?", .{old});
    }
}

/// PUUIDs `sql` selects, each allocated with `gpa`
pub fn readList(gpa: std.mem.Allocator, db: Db, sql: []const u8) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    errdefer freeList(gpa, list.items);
    errdefer list.deinit(gpa);
    var s = try db.prepare(sql);
    defer s.deinit();
    while (try s.step()) try list.append(gpa, try gpa.dupe(u8, s.bytes(0)));
    return list.toOwnedSlice(gpa);
}

pub fn freeList(gpa: std.mem.Allocator, list: []const []const u8) void {
    for (list) |p| gpa.free(p);
    gpa.free(list);
}

const testing = std.testing;

/// Two fake apps' account-v1, old (encryption 0) and new (1)
const Keys = struct {
    fakes: [2]riot.fake.Fake,
    clients: [2]Client,
    /// Unused: fakes answer before the limiter
    limiter: riot.ratelimit.Limiter,

    fn init(k: *Keys, new_encryption: u8) !void {
        k.limiter = try .init(testing.allocator, testing.io);
        for (&k.fakes, &k.clients, [2]u8{ 0, new_encryption }) |*f, *c, e| {
            f.* = try .init(testing.allocator, testing.io, 0);
            f.encryption = e;
            c.* = .init(testing.allocator, testing.io, "fake", &k.limiter);
            c.fake = f;
        }
    }

    fn deinit(k: *Keys) void {
        for (&k.fakes, &k.clients) |*f, *c| {
            c.deinit();
            f.deinit(testing.allocator);
        }
        k.limiter.deinit();
    }
};

test "translate goes through the Riot ID" {
    var k: Keys = undefined;
    try k.init(1);
    defer k.deinit();
    const out = try translate(&k.clients[0], &k.clients[1], "acct0.Some_One.EUW");
    defer testing.allocator.free(out.moved);
    try testing.expectEqualStrings("acct1.Some_One.EUW", out.moved);
    try testing.expectEqual(Outcome.gone, try translate(&k.clients[0], &k.clients[1], "acct0.gone.EUW"));
    // Already rekeyed: the old key cannot read the new app's PUUIDs
    try testing.expectError(error.UnexpectedStatus, translate(&k.clients[0], &k.clients[1], "acct1.Some_One.EUW"));
}

test "rekey carries forgotten over and clears crawl state" {
    var k: Keys = undefined;
    try k.init(1);
    defer k.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const db = try store.schema.memory();
    defer db.close();
    try forget.ensure(db);
    try db.exec(
        \\INSERT INTO forgotten VALUES ('acct0.A.EUW', 5), ('acct0.gone.EUW', 6);
        \\INSERT INTO players (puuid, source) VALUES ('acct0.B.EUW', 'ladder');
        \\INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, win)
        \\    VALUES ('EUW1_1', 0, 100, 'acct0.B.EUW', 1, 1);
    );
    const listed = try readList(testing.allocator, db, "SELECT puuid FROM forgotten");
    defer freeList(testing.allocator, listed);
    const plan = try Plan.build(arena.allocator(), &k.clients[0], &k.clients[1], listed, &.{});
    try testing.expectEqual(@as(usize, 1), plan.moved);
    try testing.expectEqual(@as(usize, 1), plan.gone);
    try testing.expect(!plan.linked());

    // Added during the translation: refused, nothing written
    try db.run("INSERT INTO forgotten VALUES ('acct0.C.EUW', 7)", .{});
    try testing.expectError(error.ListChanged, applyCrawl(testing.allocator, db, &plan));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM players", .{}));
    try db.run("DELETE FROM forgotten WHERE puuid = 'acct0.C.EUW'", .{});

    try applyCrawl(testing.allocator, db, &plan);
    try testing.expectEqual(@as(?i64, 5), try db.scalar("SELECT forgotten_at FROM forgotten WHERE puuid = 'acct1.A.EUW'", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM forgotten", .{}));
    try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM players", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM participants WHERE puuid IS NULL", .{}));
}

test "rekey carries blocked over in the Your games cache" {
    var k: Keys = undefined;
    try k.init(1);
    defer k.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const db = try cache.open(":memory:");
    defer db.close();
    try db.exec(
        \\INSERT INTO blocked VALUES ('acct0.A.EUW', 5);
        \\INSERT INTO players (puuid, game_name, tag_line, platform) VALUES ('acct0.B.EUW', 'B', 'EUW', 'EUW1');
        \\INSERT INTO accounts VALUES ('b#euw', 'acct0.B.EUW', 1);
        \\INSERT INTO jobs (key, requested) VALUES ('acct0.B.EUW', 1), ('c#euw', 1);
    );
    const plan = try Plan.build(arena.allocator(), &k.clients[0], &k.clients[1], &.{"acct0.A.EUW"}, &.{});
    try applyApi(testing.allocator, db, &plan);
    try testing.expectEqual(@as(?i64, 5), try db.scalar("SELECT at FROM blocked WHERE puuid = 'acct1.A.EUW'", .{}));
    try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM players", .{}));
    try testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM accounts", .{}));
    try testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM jobs WHERE key = 'c#euw'", .{}));
}

test "linked encryption: nothing to rekey; a mixed list stops" {
    var k: Keys = undefined;
    try k.init(0);
    defer k.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expect((try Plan.build(a, &k.clients[0], &k.clients[1], &.{"acct0.A.EUW"}, &.{})).linked());
    // Empty lists: a player answers instead
    try testing.expect((try Plan.build(a, &k.clients[0], &k.clients[1], &.{}, &.{ "acct0.gone.X", "acct0.B.EUW" })).linked());
    // A crawled (non-account) PUUID moves even with encryption 0 here, beside one that stays
    try testing.expectError(error.MixedEncryption, Plan.build(a, &k.clients[0], &k.clients[1], &.{ "acct0.A.EUW", "realpuuid" }, &.{}));
}
