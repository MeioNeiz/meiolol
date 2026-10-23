//! The service's only Riot caller: one task working through the jobs table, oldest
//! first. Calls go through the crawler's proxy (riot/proxy.zig), which takes the
//! crawler's next free slot for each, so the key's limits are shared without either
//! side holding back. Fetches only a few new games per refresh; everything fetched is
//! cached by match id.

const std = @import("std");
const store = @import("store");
const riot = @import("../riot/root.zig");
const cache = @import("cache.zig");
const game = @import("game.zig");

const Allocator = std.mem.Allocator;
const Client = riot.client.Client;
const Limiter = riot.ratelimit.Limiter;
const endpoints = riot.endpoints;

const log = std.log.scoped(.api);

pub const Options = struct {
    /// Base URL of the crawler's proxy; null calls Riot with `key` (local testing)
    proxy: ?[]const u8 = null,
    key: []const u8 = "",
    /// Shared with the box (docs/your-games.md): the service writes forgotten.txt,
    /// every blocked PUUID; it imports box-forgotten.txt, the box's `meiolol forget`
    /// list. Null: no sync
    exchange_dir: ?[]const u8 = null,
};

/// New games fetched per refresh (~2 calls each); older ones on later refreshes
const max_new = 10;
/// How far back to list match ids
const since_days = 60;
/// Players nobody looked up for this long are deleted (docs/your-games.md)
const retention_days = 30;

/// Account lookups go to the nearest account-v1 cluster; any answers for any player
const account_route: endpoints.Region = .europe;

/// Summoner's Rift queues with lanes, one id list call each per refresh. Curves come
/// from solo games only; the page says so on other queues' charts. Not ARAM or Arena
/// (no lanes) and not the unfiltered list: it holds private ARAM Mayhem ids (403) that
/// would take the new-game slots on every refresh
const queues = [_]u16{ endpoints.ranked_solo, endpoints.ranked_flex, endpoints.normal_draft, endpoints.swiftplay };

pub const Fetcher = struct {
    gpa: Allocator,
    io: std.Io,
    db: store.Db,
    opts: Options,
    /// One client (and so one limiter, as Riot counts) per routing value
    clients: std.StringHashMapUnmanaged(*Route) = .empty,

    const Route = struct { client: Client, limiter: Limiter };

    pub fn deinit(f: *Fetcher) void {
        var it = f.clients.valueIterator();
        while (it.next()) |r| {
            r.*.client.deinit();
            r.*.limiter.deinit();
            f.gpa.destroy(r.*);
        }
        f.clients.deinit(f.gpa);
    }

    fn route(f: *Fetcher, name: []const u8) !*Client {
        const gop = try f.clients.getOrPut(f.gpa, name);
        if (!gop.found_existing) {
            const r = try f.gpa.create(Route);
            errdefer f.gpa.destroy(r);
            r.limiter = try .init(f.gpa, f.io);
            r.client = if (f.opts.proxy) |base| .initProxy(f.gpa, f.io, base) else .init(f.gpa, f.io, f.opts.key, &r.limiter);
            gop.value_ptr.* = r;
        }
        return &gop.value_ptr.*.client;
    }

    /// Runs until cancelled or Riot rejects the key
    pub fn run(f: *Fetcher) !void {
        var arena_state: std.heap.ArenaAllocator = .init(f.gpa);
        defer arena_state.deinit();
        var pruned: i64 = 0;
        while (true) {
            _ = arena_state.reset(.retain_capacity);
            const arena = arena_state.allocator();
            const now = f.seconds();
            if (now - pruned >= std.time.s_per_hour) {
                try cache.prune(f.db, now - retention_days * std.time.s_per_day, now);
                if (f.opts.exchange_dir) |dir| syncForgotten(f.gpa, f.io, f.db, dir, now) catch |err| {
                    log.warn("forgotten list sync: {t}", .{err});
                };
                pruned = now;
            }
            const key = try nextJob(arena, f.db) orelse {
                try f.io.sleep(.fromMilliseconds(500), .awake);
                continue;
            };
            f.job(arena, key) catch |err| switch (err) {
                error.KeyRejected, error.OutOfMemory, error.Canceled => return err,
                else => {
                    log.warn("job failed: {t}", .{err});
                    if (std.mem.startsWith(u8, key, verify_prefix)) {
                        // Back to waiting, so the player can press check again
                        try f.db.run(
                            \\UPDATE challenges SET state = CASE WHEN icon IS NULL THEN 'failed'
                            \\  ELSE 'mismatch' END WHERE riot_id = ?
                        , .{key[verify_prefix.len..]});
                    } else if (std.mem.findScalar(u8, key, '#') == null) {
                        try f.db.run("UPDATE players SET error = ? WHERE puuid = ?", .{ @errorName(err), key });
                    }
                },
            };
            try f.db.run("DELETE FROM jobs WHERE key = ?", .{key});
        }
    }

    fn job(f: *Fetcher, arena: Allocator, key: []const u8) !void {
        if (std.mem.startsWith(u8, key, verify_prefix)) return f.verify(arena, key[verify_prefix.len..]);
        const puuid = if (std.mem.findScalar(u8, key, '#') != null)
            try f.resolve(arena, key) orelse return
        else
            key;
        if (try f.blocked(puuid)) return;
        try f.refresh(arena, puuid, key);
    }

    fn blocked(f: *Fetcher, puuid: []const u8) !bool {
        return try f.db.scalar("SELECT 1 FROM blocked WHERE puuid = ?", .{puuid}) != null;
    }

    const Account = struct {
        puuid: []const u8,
        name: []const u8,
        tag: []const u8,
        platform: endpoints.Platform,
    };

    /// Riot ID -> account and platform; null when Riot has no such account
    fn account(f: *Fetcher, arena: Allocator, riot_id: []const u8) !?Account {
        const hash = std.mem.findScalar(u8, riot_id, '#').?;
        const body = try f.keep(arena, try endpoints.accountByRiotId(try f.route(@tagName(account_route)), account_route, riot_id[0..hash], riot_id[hash + 1 ..])) orelse
            return null;
        const a = try endpoints.parse(endpoints.Account, arena, body);
        const where = try f.keep(arena, try endpoints.activePlatform(try f.route(@tagName(account_route)), account_route, a.puuid)) orelse
            return error.NoActivePlatform;
        const active = try endpoints.parse(struct { region: []const u8 }, arena, where);
        return .{
            .puuid = a.puuid,
            .name = a.gameName orelse riot_id[0..hash],
            .tag = a.tagLine orelse riot_id[hash + 1 ..],
            .platform = endpoints.platformByHost(active.region) orelse return error.UnknownPlatform,
        };
    }

    /// Riot ID -> PUUID, adding the player; null when Riot has no such account or the
    /// player objected (the page then says so)
    fn resolve(f: *Fetcher, arena: Allocator, riot_id: []const u8) !?[]const u8 {
        const now = f.seconds();
        const a = try f.account(arena, riot_id) orelse {
            try f.db.run("INSERT OR REPLACE INTO accounts VALUES (?, NULL, ?)", .{ riot_id, now });
            return null;
        };
        try f.db.run("INSERT OR REPLACE INTO accounts VALUES (?, ?, ?)", .{ riot_id, a.puuid, now });
        if (try f.blocked(a.puuid)) return null;
        try f.db.run(
            \\INSERT INTO players (puuid, game_name, tag_line, platform) VALUES (?, ?, ?, ?)
            \\ON CONFLICT (puuid) DO UPDATE SET game_name = excluded.game_name,
            \\  tag_line = excluded.tag_line, platform = excluded.platform
        , .{ a.puuid, a.name, a.tag, a.platform.id });
        return a.puuid;
    }

    /// Objection: issue a starter icon (state pending) or check it (state checking);
    /// on a match, forget and block the player. Stores nothing about a player who
    /// never passes the check beyond the challenge row, which expires
    fn verify(f: *Fetcher, arena: Allocator, riot_id: []const u8) !void {
        const state, const icon = blk: {
            var q = try f.db.prepare("SELECT state, icon FROM challenges WHERE riot_id = ?");
            defer q.deinit();
            try q.bind(.{riot_id});
            if (!try q.step()) return;
            const r = q.row(struct { state: []const u8, icon: ?i64 });
            break :blk .{ try arena.dupe(u8, r.state), r.icon };
        };
        const a = try f.account(arena, riot_id) orelse {
            try f.db.run("UPDATE challenges SET state = 'not_found' WHERE riot_id = ?", .{riot_id});
            return;
        };
        const body = try f.keep(arena, try endpoints.summonerByPuuid(try f.route(a.platform.host), a.platform, a.puuid)) orelse
            return error.NoSummoner;
        const current = (try endpoints.parse(struct { profileIconId: i64 }, arena, body)).profileIconId;
        const now = f.seconds();
        if (std.mem.eql(u8, state, "pending")) {
            const wanted = pickIcon(f.io, current);
            try f.db.run(
                "UPDATE challenges SET puuid = ?, icon = ?, expires = ?, state = 'issued' WHERE riot_id = ?",
                .{ a.puuid, wanted, now + challenge_s, riot_id },
            );
        } else if (std.mem.eql(u8, state, "checking")) {
            if (icon != null and current == icon.?) {
                try cache.forget(f.db, a.puuid, now);
                try f.db.run("UPDATE challenges SET puuid = NULL, state = 'done' WHERE riot_id = ?", .{riot_id});
                if (f.opts.exchange_dir) |dir| syncForgotten(f.gpa, f.io, f.db, dir, now) catch |err| {
                    log.warn("forgotten list sync: {t}", .{err});
                };
                log.info("objection honoured: player forgotten and blocked", .{});
            } else {
                try f.db.run("UPDATE challenges SET state = 'mismatch' WHERE riot_id = ?", .{riot_id});
            }
        }
    }

    /// Rank and the newest games not yet cached for this player. Progress goes on the
    /// job row `job_key` (the Riot ID while the page polls by it)
    fn refresh(f: *Fetcher, arena: Allocator, puuid: []const u8, job_key: []const u8) !void {
        const platform = blk: {
            var q = try f.db.prepare("SELECT platform FROM players WHERE puuid = ?");
            defer q.deinit();
            try q.bind(.{puuid});
            if (!try q.step()) return error.UnknownPlayer;
            // Hosts are the platform ids in lower case
            break :blk endpoints.platformByHost(q.bytes(0)) orelse return error.UnknownPlatform;
        };
        const region = platform.region;

        var rank: game.Rank = .{};
        if (try f.keep(arena, try endpoints.leagueByPuuid(try f.route(platform.host), platform, puuid))) |body| {
            const entries = try endpoints.parse([]const endpoints.LeagueEntry, arena, body);
            for (entries) |e| if (std.mem.eql(u8, e.queueType orelse "", "RANKED_SOLO_5x5")) {
                rank = .{ .tier = e.tier, .division = e.rank, .lp = e.leaguePoints };
            };
        }
        try f.db.run("UPDATE players SET tier = ?, division = ?, lp = ? WHERE puuid = ?", .{ rank.tier, rank.division, rank.lp, puuid });

        const now = f.seconds();
        var ids: std.ArrayList([]const u8) = .empty;
        for (queues) |queue| {
            const body = try f.keep(arena, try endpoints.matchIds(try f.route(@tagName(region)), region, puuid, queue, now - since_days * std.time.s_per_day, now, 0)) orelse
                return error.NoMatchIds;
            try ids.appendSlice(arena, try endpoints.parse([]const []const u8, arena, body));
        }
        newestFirst(ids.items);

        var wanted: std.ArrayList([]const u8) = .empty;
        for (ids.items) |id| {
            if (wanted.items.len == max_new) break;
            const have = try f.db.scalar("SELECT 1 FROM player_games WHERE puuid = ? AND match_id = ?", .{ puuid, id });
            if (have == null) try wanted.append(arena, id);
        }
        // Games cached before Riot IDs were kept (20 Oct 2026) get them: one call each
        var unnamed: std.ArrayList([]const u8) = .empty;
        {
            var q = try f.db.prepare(
                \\SELECT match_id FROM player_games pg WHERE puuid = ? AND NOT EXISTS
                \\  (SELECT 1 FROM match_names n WHERE n.match_id = pg.match_id)
                \\ORDER BY start_ms DESC LIMIT ?
            );
            defer q.deinit();
            try q.bind(.{ puuid, max_new });
            while (try q.step()) try unnamed.append(arena, try arena.dupe(u8, q.bytes(0)));
        }
        const total = wanted.items.len + unnamed.items.len;
        try f.db.run("UPDATE jobs SET pending = ?, total = ? WHERE key = ?", .{ total, total, job_key });

        var hash_buf: [game.hash_len]u8 = undefined;
        const hash = game.hashPuuid(&hash_buf, puuid);
        for (wanted.items, 0..) |id, i| {
            f.addGame(arena, region, puuid, hash, id) catch |err| switch (err) {
                error.KeyRejected, error.OutOfMemory, error.Canceled => return err,
                else => log.warn("{s}: {t}", .{ id, err }),
            };
            try f.db.run("UPDATE jobs SET pending = ? WHERE key = ?", .{ total - i - 1, job_key });
        }
        for (unnamed.items, 0..) |id, i| {
            if (endpoints.match(try f.route(@tagName(region)), region, id)) |found| {
                if (try f.keep(arena, found)) |body| try f.storeNames(arena, id, body);
            } else |err| switch (err) {
                error.KeyRejected, error.OutOfMemory, error.Canceled => return err,
                else => log.warn("{s}: names {t}", .{ id, err }),
            }
            try f.db.run("UPDATE jobs SET pending = ? WHERE key = ?", .{ unnamed.items.len - i - 1, job_key });
        }
        try f.db.run("UPDATE players SET refreshed = ?, error = NULL WHERE puuid = ?", .{ f.seconds(), puuid });
    }

    fn addGame(f: *Fetcher, arena: Allocator, region: endpoints.Region, puuid: []const u8, hash: []const u8, id: []const u8) !void {
        const summary = try f.cachedSummary(arena, id) orelse
            try f.fetchMatch(arena, region, id) orelse return;
        const slot = summary.slotOf(hash) orelse return error.PlayerNotInMatch;
        try f.db.run("INSERT OR IGNORE INTO player_games VALUES (?, ?, ?, ?)", .{ puuid, id, summary.start_ms, slot });
    }

    /// Statements are finished before any write: a read left open pins a WAL snapshot,
    /// and upgrading it to a write after another connection wrote fails at once
    /// (SQLITE_BUSY, no busy timeout)
    fn cachedSummary(f: *Fetcher, arena: Allocator, id: []const u8) !?game.Summary {
        var q = try f.db.prepare("SELECT summary FROM matches WHERE match_id = ?");
        defer q.deinit();
        try q.bind(.{id});
        if (!try q.step()) return null;
        return try readSummary(arena, q.bytes(0));
    }

    fn fetchMatch(f: *Fetcher, arena: Allocator, region: endpoints.Region, id: []const u8) !?game.Summary {
        const body = try f.keep(arena, try endpoints.match(try f.route(@tagName(region)), region, id)) orelse return null;
        const summary = try game.summarise(arena, body);
        var packed_timeline: ?[]const u8 = null;
        if (!summary.remake) {
            if (try f.keep(arena, try endpoints.timeline(try f.route(@tagName(region)), region, id))) |raw| {
                const t = try riot.timeline.fromJson(arena, raw);
                const compact = try riot.timeline.encode(arena, t);
                packed_timeline = try store.raw.compress(arena, compact);
            }
        }
        const json = try std.json.Stringify.valueAlloc(arena, summary, .{});
        const packed_summary = try store.raw.compress(arena, json);
        try f.db.run("INSERT OR REPLACE INTO matches VALUES (?, ?, ?, ?)", .{
            id,
            f.seconds(),
            store.Blob{ .bytes = packed_summary },
            if (packed_timeline) |b| store.Blob{ .bytes = b } else null,
        });
        try f.storeNames(arena, id, body);
        return summary;
    }

    /// Each player's Riot ID as at the game, none for a blocked player
    fn storeNames(f: *Fetcher, arena: Allocator, id: []const u8, body: []const u8) !void {
        var hash_buf: [game.hash_len]u8 = undefined;
        for (try game.riotIds(arena, body), 0..) |n, slot| {
            const puuid = n.puuid orelse continue;
            const riot_id = n.riot_id orelse continue;
            if (try f.blocked(puuid)) continue;
            try f.db.run("INSERT OR REPLACE INTO match_names VALUES (?, ?, ?, ?)", .{ id, slot, game.hashPuuid(&hash_buf, puuid), riot_id });
        }
    }

    /// A Riot body moved into the job's arena: the client allocates with gpa, and parsed
    /// strings may point into the body
    fn keep(f: *Fetcher, arena: Allocator, got: ?[]u8) !?[]u8 {
        const body = got orelse return null;
        defer f.gpa.free(body);
        return try arena.dupe(u8, body);
    }

    fn seconds(f: *Fetcher) i64 {
        return std.Io.Clock.real.now(f.io).toSeconds();
    }
};

/// Both lists are complete, one PUUID per line: idempotent on either side, so a missed
/// sync only delays. Imports first, so the written list includes the box's
pub fn syncForgotten(gpa: Allocator, io: std.Io, db: store.Db, dir_path: []const u8, now: i64) !void {
    const dir = std.Io.Dir.cwd();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const theirs = try std.mem.print(&path_buf, "{s}/box-forgotten.txt", .{dir_path});
    if (dir.readFileAlloc(io, theirs, gpa, .limited(64 << 20))) |text| {
        defer gpa.free(text);
        var added: usize = 0;
        var lines = std.mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            const puuid = std.mem.trim(u8, line, " \t");
            // PUUIDs only: never contain '#', so comments and Riot IDs are skipped
            if (puuid.len == 0 or std.mem.findScalar(u8, puuid, '#') != null) continue;
            if (try db.scalar("SELECT 1 FROM blocked WHERE puuid = ?", .{puuid}) != null) continue;
            try cache.forget(db, puuid, now);
            added += 1;
        }
        if (added > 0) log.info("blocked {d} PUUIDs forgotten on the box", .{added});
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    var q = try db.prepare("SELECT puuid FROM blocked ORDER BY puuid");
    defer q.deinit();
    while (try q.step()) try aw.writer.print("{s}\n", .{q.bytes(0)});
    const ours = try std.mem.print(&path_buf, "{s}/forgotten.txt", .{dir_path});
    var file = try dir.createFileAtomic(io, ours, .{ .replace = true });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, aw.written());
    try file.replace(io);
}

test syncForgotten {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const len = try tmp.dir.realPath(io, &buf);
    const path = buf[0..len];
    try tmp.dir.writeFile(io, .{ .sub_path = "box-forgotten.txt", .data = "boxer\n# comment\n\nSome One#EUW\nours\n" });

    const db = try cache.open(":memory:");
    defer db.close();
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform) VALUES ('boxer','A','1','EUW1')", .{});
    try db.run("INSERT INTO blocked VALUES ('ours', 0)", .{});
    try syncForgotten(gpa, io, db, path, 100);
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM players", .{}));
    const out = try tmp.dir.readFileAlloc(io, "forgotten.txt", gpa, .limited(1024));
    defer gpa.free(out);
    try std.testing.expectEqualStrings("boxer\nours\n", out);
}

/// Job keys for objections: this prefix, then the lower case Riot ID
pub const verify_prefix = "verify:";
/// Time to change the icon once it is shown
pub const challenge_s = 15 * 60;
/// Profile icons 0-28: the starter icons every account owns
const starter_icons = 29;

/// A random starter icon other than `current`
fn pickIcon(io: std.Io, current: i64) i64 {
    var b: [1]u8 = undefined;
    io.random(&b);
    const offset: i64 = 1 + b[0] % (starter_icons - 1);
    // Not a starter icon now: any starter differs from it
    const from = if (current >= 0 and current < starter_icons) current else 0;
    return @mod(from + offset, starter_icons);
}

test "riot ids: none kept for a blocked player, a later erasure drops the rest" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const db = try cache.open(":memory:");
    defer db.close();
    var f: Fetcher = .{ .gpa = std.testing.allocator, .io = std.testing.io, .db = db, .opts = .{} };
    defer f.deinit();
    try db.run("INSERT INTO blocked VALUES ('puuid-2', 0)", .{});
    try f.storeNames(arena_state.allocator(), "EUW1_1", @embedFile("../riot/testdata/match.json"));
    try std.testing.expectEqual(@as(?i64, 9), try db.scalar("SELECT count(*) FROM match_names", .{}));
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM match_names WHERE slot = 2", .{}));
    try std.testing.expectEqual(@as(?i64, 1), try db.scalar("SELECT count(*) FROM match_names WHERE riot_id = 'player3#player3'", .{}));
    try cache.forget(db, "puuid-3", 1);
    try std.testing.expectEqual(@as(?i64, 0), try db.scalar("SELECT count(*) FROM match_names WHERE riot_id = 'player3#player3'", .{}));
}

test "a refresh frees every Riot body it fetched" {
    const gpa = std.testing.allocator;
    const saved = std.testing.log_level;
    defer std.testing.log_level = saved;
    // The fake's players are new PUUIDs, so the game warns PlayerNotInMatch
    std.testing.log_level = .err;
    var fake: riot.fake.Fake = try .init(gpa, std.testing.io, 0);
    defer fake.deinit(gpa);
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const db = try cache.open(":memory:");
    defer db.close();
    var f: Fetcher = .{ .gpa = gpa, .io = std.testing.io, .db = db, .opts = .{} };
    defer f.deinit();
    for ([_][]const u8{ "europe", "euw1" }) |name| (try f.route(name)).fake = &fake;
    try db.run("INSERT INTO players (puuid, game_name, tag_line, platform) VALUES ('p', 'A', '1', 'EUW1')", .{});
    try f.refresh(arena_state.allocator(), "p", "p");
    try std.testing.expectEqual(@as(?i64, max_new), try db.scalar("SELECT count(*) FROM matches WHERE timeline IS NOT NULL", .{}));
}

test pickIcon {
    for (0..200) |_| {
        const icon = pickIcon(std.testing.io, 7);
        try std.testing.expect(icon != 7 and icon >= 0 and icon < starter_icons);
    }
    const any = pickIcon(std.testing.io, 5000);
    try std.testing.expect(any >= 0 and any < starter_icons);
}

/// Match ids from several lists, newest first: within a platform, ids count up
fn newestFirst(ids: [][]const u8) void {
    std.mem.sort([]const u8, ids, {}, struct {
        fn newer(_: void, a: []const u8, b: []const u8) bool {
            return number(a) > number(b);
        }
        fn number(id: []const u8) u64 {
            const sep = std.mem.findScalarLast(u8, id, '_') orelse return 0;
            return std.fmt.parseInt(u64, id[sep + 1 ..], 10) catch 0;
        }
    }.newer);
}

test newestFirst {
    var ids = [_][]const u8{ "EUW1_7000000002", "EUW1_7000000010", "EUW1_999", "EUW1_7000000005" };
    newestFirst(&ids);
    try std.testing.expectEqualDeep([_][]const u8{ "EUW1_7000000010", "EUW1_7000000005", "EUW1_7000000002", "EUW1_999" }, ids);
}

pub fn readSummary(arena: Allocator, blob: []const u8) !game.Summary {
    const json = try store.raw.decompress(arena, blob);
    return std.json.parseFromSliceLeaky(game.Summary, arena, json, .{ .ignore_unknown_fields = true });
}

pub fn readTimeline(arena: Allocator, blob: []const u8) !riot.timeline.Timeline {
    return riot.timeline.decode(arena, try store.raw.decompress(arena, blob));
}

fn nextJob(arena: Allocator, db: store.Db) !?[]const u8 {
    var q = try db.prepare("SELECT key FROM jobs ORDER BY requested, key LIMIT 1");
    defer q.deinit();
    if (!try q.step()) return null;
    return try arena.dupe(u8, q.bytes(0));
}
