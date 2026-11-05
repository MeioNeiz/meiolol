//! Day cubes (data/cubes, docs/plan/estimates.md E7): what curves and builds take from
//! each game's participants and timeline, decoded once into days/<unix day>.bin, so a
//! view (any window, platform, patch or rank) is a pass over its days' files instead of
//! every timeline again. Per game, not per-cell sums: a day's matchup cells hold about
//! two lanes each (estimates.md E7), so sums would be bigger, and records keep
//! percentiles and medians exact.
//!
//! A day is built again when its ranked solo games change: their count and the sums of
//! their match and timeline rowids (a late game, a REPLACE, a new timeline); only its
//! games whose rowids changed are decoded again, the rest kept from its file. Fixed when
//! built: the experienced flags (mastery then, not at each view) and the item data (Data
//! Dragon's for the game's patch). Any change to this file, curves.zig, builds.zig or the
//! record types starts the files again (formatKey). Derived, never backed up, safe to
//! delete; no player keys, so forget has nothing to scrub.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const flat = @import("site/flat.zig");
const timeline = @import("riot/timeline.zig");
const digest = @import("riot/digest.zig");
const ddragon = @import("ddragon.zig");
const curves = @import("curves.zig");
const builds = @import("builds.zig");
const stats = @import("stats.zig");

const Allocator = std.mem.Allocator;
const Role = core.Role;
const Lane = core.curvesfile.Lane;
const log = std.log.scoped(.cubes);
const day_ms = std.time.ms_per_day;

/// Index into DayFile.strings
pub const Code = u16;

pub const Game = struct {
    /// game_start, Unix ms
    start: i64,
    /// matches.rowid and the timeline's rowid (0 without one): an update keeps the game
    /// while both hold
    rowid: i64,
    source: i64,
    platform: Code,
    patch: Code,
    /// curves.gameHash of the match id
    hash: u32,
    curves: Curves,
    /// By role, blue's laner as a; when curves is .lanes
    lanes: []const Lane,
    /// The timeline decoded: seats carry picks
    timeline: bool,
    seats: []const builds.Seat,
};

pub const Curves = enum(u8) {
    /// No timeline: not one of curves' games
    none,
    /// One of curves' skipped: the timeline did not decode or a position was unfilled
    skipped,
    lanes,
};

/// A day's ranked solo games in the database: a file is current while these match
pub const Sig = extern struct { games: i64 = 0, rowids: i64 = 0, timelines: i64 = 0 };

pub const Day = struct {
    day: i64,
    strings: []const []const u8,
    games: []const Game,

    pub fn string(d: Day, code: Code) []const u8 {
        return d.strings[code];
    }
};

const magic = "MEIOCUB1";

/// Hashes the record types and the sources that fill them
pub fn formatKey() u64 {
    var h: std.hash.Wyhash = .init(2);
    h.update(std.mem.asBytes(&flat.fingerprint(Day)));
    h.update(@embedFile("cubes.zig"));
    h.update(@embedFile("curves.zig"));
    h.update(@embedFile("builds.zig"));
    return h.final();
}

/// Item data for a game's patch (Data Dragon). An error fails the refresh rather than
/// fix a day without picks and first items
pub const Items = struct {
    ctx: *anyopaque,
    get: *const fn (ctx: *anyopaque, patch: []const u8) anyerror!*const ddragon.BuildData,
};

pub fn dirIn(arena: Allocator, data_dir: []const u8) ![]const u8 {
    return std.fs.path.join(arena, &.{ data_dir, "cubes" });
}

/// Deletes every day file, for when games change without their rowids (rebuild, restore)
pub fn drop(gpa: Allocator, io: std.Io, dir: []const u8) !void {
    std.Io.Dir.cwd().access(io, dir, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    const s = try Store.open(gpa, io, dir);
    defer s.deinit();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    try std.Io.Dir.cwd().deleteTree(io, try std.fmt.bufPrint(&buf, "{s}/days", .{dir}));
}

/// Days kept older than the run's own window: the site's 30 days. The web loop's
/// previous-patch curves reach back ~27 days on two-week patches; after a longer patch
/// that run builds its older days again
pub const keep_days = 30;

pub const Counts = struct {
    /// Days from the refresh's first on, with games
    days: usize = 0,
    built: usize = 0,
    /// Games decoded from the database; the rest of a built day's were kept from its file
    games_built: usize = 0,
    dropped: usize = 0,
    /// Days read as they were, their files younger than Store.settle_ms: changed, or in
    /// the run up to today, not asked
    young: usize = 0,
    /// Bytes of the files built
    bytes: u64 = 0,
};

/// The day files, held under the directory's lock until deinit
pub const Store = struct {
    gpa: Allocator,
    io: std.Io,
    dir: []const u8,
    lock: std.Io.File,
    counts: Counts = .{},
    /// A changed day whose file is younger than this is read as it is: for a reader of
    /// many days that a few late games don't move (lockrows, curves --site), as each day
    /// built again costs ~40 s and the crawler adds games to the last two weeks' days
    /// all the time
    settle_ms: i64 = 0,
    /// The newest days (today 1) built whenever they change, settle_ms or not: on a
    /// patch's first day today's games are all of its curves
    fresh_days: i64 = 0,
    /// A changed day with more games new or changed than this is built afresh: one by one
    /// they are cold random reads (~4-30 ms each on the box) against ~40 s for a whole
    /// 100k-game day read ahead
    afresh_after: usize = 4000,

    /// Opens (or starts) `dir`, waiting for its lock
    pub fn open(gpa: Allocator, io: std.Io, dir: []const u8) !*Store {
        const cwd = std.Io.Dir.cwd();
        const days_dir = try std.fs.path.join(gpa, &.{ dir, "days" });
        defer gpa.free(days_dir);
        try cwd.createDirPath(io, days_dir);
        const lock_path = try std.fs.path.join(gpa, &.{ dir, "lock" });
        defer gpa.free(lock_path);
        const lock = try cwd.createFile(io, lock_path, .{ .lock = .exclusive, .truncate = false });
        errdefer lock.close(io);
        const s = try gpa.create(Store);
        errdefer gpa.destroy(s);
        s.* = .{ .gpa = gpa, .io = io, .dir = try gpa.dupe(u8, dir), .lock = lock };
        return s;
    }

    pub fn deinit(s: *Store) void {
        s.lock.close(s.io);
        s.gpa.free(s.dir);
        s.gpa.destroy(s);
    }

    fn dayPath(s: *const Store, buf: []u8, day: i64) ![]const u8 {
        return std.fmt.bufPrint(buf, "{s}/days/{d}.bin", .{ s.dir, day });
    }

    /// Builds every day from `from_ms`'s on whose games changed since its file was made,
    /// and drops files of days with no games left, or older than keep_days and from_ms
    pub fn refresh(s: *Store, db: store.Db, from_ms: i64, items: Items) !Counts {
        const gpa = s.gpa;
        s.counts = .{};
        const first = @divFloor(from_ms, day_ms);
        const now_ms = std.Io.Clock.real.now(s.io).toMilliseconds();
        const today = @divFloor(now_ms, day_ms);
        const drop_before = @min(first, today - keep_days);
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        // The run of young files up to the fresh days is read as it is, unasked: daySigs
        // reads a page of matches per game, ~2 min over 30 days on the box
        const fresh_from = @max(first, today + 1 - s.fresh_days);
        var young_from = fresh_from;
        while (young_from > first) : (young_from -= 1) {
            const have = try readSig(s.io, try s.dayPath(&buf, young_from - 1)) orelse break;
            if (now_ms - have.made_ms >= s.settle_ms) break;
        }
        const tail: usize = @intCast(fresh_from - young_from);
        var sigs = try daySigs(gpa, db, first * day_ms, if (tail == 0) std.math.maxInt(i64) else young_from * day_ms);
        defer sigs.deinit(gpa);
        if (tail > 0) {
            var fresh = try daySigs(gpa, db, fresh_from * day_ms, std.math.maxInt(i64));
            defer fresh.deinit(gpa);
            var f = fresh.iterator();
            while (f.next()) |e| try sigs.put(gpa, e.key_ptr.*, e.value_ptr.*);
        }
        s.counts.days = sigs.count() + tail;
        s.counts.young = tail;
        var experienced: ?curves.Experienced = null;
        defer if (experienced) |*e| e.deinit(gpa);
        var arena_state: std.heap.ArenaAllocator = .init(gpa);
        defer arena_state.deinit();
        var it = sigs.iterator();
        while (it.next()) |e| {
            const day = e.key_ptr.*;
            const path = try s.dayPath(&buf, day);
            if (try readSig(s.io, path)) |have| {
                if (std.meta.eql(have.sig, e.value_ptr.*)) continue;
                if (day < fresh_from and now_ms - have.made_ms < s.settle_ms) {
                    s.counts.young += 1;
                    continue;
                }
            }
            _ = arena_state.reset(.retain_capacity);
            const arena = arena_state.allocator();
            const old = try s.read(gpa, arena, day);
            const listed = if (old != null) try listDay(db, arena, day) else &.{};
            const afresh = old == null or try changedOf(gpa, old.?, listed) > s.afresh_after;
            // Lazy while only late games are decoded; a whole day's are too many lookups
            if (afresh and (experienced == null or experienced.?.looked != null)) {
                if (experienced) |*x| x.deinit(gpa);
                experienced = null;
                experienced = try .load(gpa, db);
            } else if (experienced == null) experienced = try .lazy(db);
            const r = try buildDay(gpa, s.io, db, day, &experienced.?, items, path, if (afresh) null else .{ .day = old.?, .listed = listed }, arena);
            s.counts.built += 1;
            s.counts.games_built += r.decoded;
            s.counts.bytes += r.bytes;
        }
        // Days no run reads, or whose games went
        var dir = try std.Io.Dir.cwd().openDir(s.io, try std.fmt.bufPrint(&buf, "{s}/days", .{s.dir}), .{ .iterate = true });
        defer dir.close(s.io);
        var stale: std.ArrayList(i64) = .empty;
        defer stale.deinit(gpa);
        var files = dir.iterate();
        while (try files.next(s.io)) |f| {
            const stem = std.mem.cutSuffix(u8, f.name, ".bin") orelse continue;
            const day = std.fmt.parseInt(i64, stem, 10) catch continue;
            if (day < drop_before or (day >= first and (day < young_from or day >= fresh_from) and !sigs.contains(day))) try stale.append(gpa, day);
        }
        for (stale.items) |day| {
            try std.Io.Dir.cwd().deleteFile(s.io, try s.dayPath(&buf, day));
            s.counts.dropped += 1;
        }
        return s.counts;
    }

    /// Days with a file from `from_ms`'s on, oldest first
    pub fn days(s: *const Store, gpa: Allocator, from_ms: i64) ![]i64 {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        var dir = try std.Io.Dir.cwd().openDir(s.io, try std.fmt.bufPrint(&buf, "{s}/days", .{s.dir}), .{ .iterate = true });
        defer dir.close(s.io);
        var out: std.ArrayList(i64) = .empty;
        errdefer out.deinit(gpa);
        var files = dir.iterate();
        while (try files.next(s.io)) |f| {
            const stem = std.mem.cutSuffix(u8, f.name, ".bin") orelse continue;
            const day = std.fmt.parseInt(i64, stem, 10) catch continue;
            if (day >= @divFloor(from_ms, day_ms)) try out.append(gpa, day);
        }
        std.mem.sort(i64, out.items, {}, std.sort.asc(i64));
        return out.toOwnedSlice(gpa);
    }

    /// The day's games, in `arena`; null without a current file
    pub fn read(s: *const Store, gpa: Allocator, arena: Allocator, day: i64) !?Day {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        var f = std.Io.Dir.cwd().openFile(s.io, try s.dayPath(&buf, day), .{}) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
        defer f.close(s.io);
        const file_buf = try gpa.alloc(u8, 1 << 20);
        defer gpa.free(file_buf);
        var fr = f.reader(s.io, file_buf);
        var head: [header_len]u8 = undefined;
        fr.interface.readSliceAll(&head) catch return null;
        _ = headerEnd(&head) orelse return null;
        const window = try gpa.alloc(u8, std.compress.flate.max_window_len);
        defer gpa.free(window);
        var d: std.compress.flate.Decompress = .init(&fr.interface, .gzip, window);
        const day_value = flat.read(Day, &d.reader, arena) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return null,
        };
        if ((d.reader.discardRemaining() catch return null) != 0) return null;
        return day_value;
    }
};

const header_len = magic.len + 8 + @sizeOf(Sig);

/// Where the compressed body starts, or null for another format
fn headerEnd(bytes: []const u8) ?usize {
    if (bytes.len < header_len or !std.mem.eql(u8, bytes[0..magic.len], magic)) return null;
    if (std.mem.readInt(u64, bytes[magic.len..][0..8], .little) != formatKey()) return null;
    return header_len;
}

/// The Sig a current file was built for and when; null when missing or of another format
fn readSig(io: std.Io, path: []const u8) !?struct { sig: Sig, made_ms: i64 } {
    var f = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer f.close(io);
    var head: [header_len]u8 = undefined;
    var r = f.reader(io, &.{});
    r.interface.readSliceAll(&head) catch return null;
    _ = headerEnd(&head) orelse return null;
    var sig: Sig = undefined;
    @memcpy(std.mem.asBytes(&sig), head[magic.len + 8 ..]);
    return .{ .sig = sig, .made_ms = (try f.stat(io)).mtime.toMilliseconds() };
}

/// The games curves and builds both count: ranked solo, no remake, a winner
const where_games =
    \\  AND m.queue_id = 420 AND m.remake = 0 AND m.winning_team IS NOT NULL
;

/// One UTC day's ranked solo games, bound to its start and end in ms
const day_where = "WHERE m.game_start >= ?1 AND m.game_start < ?2\n" ++ where_games;

comptime {
    std.debug.assert(stats.ranked_solo == 420);
}

fn daySigs(gpa: Allocator, db: store.Db, from_ms: i64, to_ms: i64) !std.AutoArrayHashMapUnmanaged(i64, Sig) {
    var q = try db.prepare(
        \\SELECT m.game_start / 86400000, count(*), sum(m.rowid), coalesce(sum(t.rowid), 0)
        \\FROM matches m LEFT JOIN timeline.timelines t USING (match_id)
        \\WHERE m.game_start >= ? AND m.game_start < ?
    ++ where_games ++
        \\
        \\GROUP BY 1 ORDER BY 1
    );
    defer q.deinit();
    try q.bind(.{ from_ms, to_ms });
    var out: std.AutoArrayHashMapUnmanaged(i64, Sig) = .empty;
    errdefer out.deinit(gpa);
    while (try q.step()) {
        const r = q.row(struct { day: i64, games: i64, rowids: i64, timelines: i64 });
        try out.put(gpa, r.day, .{ .games = r.games, .rowids = r.rowids, .timelines = r.timelines });
    }
    return out;
}

/// participants columns a seat reads: team_id and puuid for curves, then builds'
const ParticipantRow = blk: {
    const b = @typeInfo(builds.ParticipantRow).@"struct";
    const names = [_][]const u8{ "team_id", "puuid" } ++ b.field_names;
    const types = [_]type{ i64, ?[]const u8 } ++ b.field_types;
    break :blk @Struct(.auto, null, names, types, &@splat(.{}));
};

fn buildsRow(r: ParticipantRow) builds.ParticipantRow {
    var out: builds.ParticipantRow = undefined;
    inline for (@typeInfo(builds.ParticipantRow).@"struct".field_names) |name| @field(out, name) = @field(r, name);
    return out;
}

/// matches columns a game is decoded from, with its timeline's rowid and digest
const game_columns =
    \\SELECT m.match_id, m.rowid, m.winning_team, m.platform, m.patch, m.game_start,
    \\  t.rowid, d.data
    \\FROM matches m LEFT JOIN timeline.timelines t USING (match_id)
    \\LEFT JOIN timeline.digests d ON d.source = t.rowid AND d.match_id = m.match_id
    \\
;

const MatchRow = struct {
    match_id: []const u8,
    rowid: i64,
    winner: i64,
    platform: []const u8,
    patch: []const u8,
    start: i64,
    source: ?i64,
    digest: ?[]const u8,
};

/// One day's file being made: games decoded from the database or kept from the old file
const DayBuilder = struct {
    gpa: Allocator,
    arena: Allocator,
    db: store.Db,
    experienced: *curves.Experienced,
    items: Items,
    strings: std.StringArrayHashMapUnmanaged(void) = .empty,
    games: std.ArrayList(Game) = .empty,
    sig: Sig = .{},
    decoded: usize = 0,
    players: store.Stmt,
    source: digest.Source,
    game_state: std.heap.ArenaAllocator,

    fn init(gpa: Allocator, arena: Allocator, db: store.Db, experienced: *curves.Experienced, items: Items) !DayBuilder {
        var players = try db.prepare("SELECT team_id, puuid, " ++ builds.participant_columns ++ " FROM participants WHERE match_id = ?");
        errdefer players.deinit();
        return .{
            .gpa = gpa,
            .arena = arena,
            .db = db,
            .experienced = experienced,
            .items = items,
            .players = players,
            .source = try .init(db),
            .game_state = .init(gpa),
        };
    }

    fn deinit(b: *DayBuilder) void {
        b.players.deinit();
        b.source.deinit();
        b.game_state.deinit();
    }

    fn count(b: *DayBuilder, rowid: i64, source: i64) void {
        b.sig.games += 1;
        b.sig.rowids += rowid;
        b.sig.timelines += source;
    }

    /// An old file's game, its codes moved to this file's strings
    fn keep(b: *DayBuilder, old: Day, g: Game) !void {
        b.count(g.rowid, g.source);
        var k = g;
        k.platform = try intern(b.arena, &b.strings, old.string(g.platform));
        k.patch = try intern(b.arena, &b.strings, old.string(g.patch));
        try b.games.append(b.arena, k);
    }

    fn decode(b: *DayBuilder, m: MatchRow) !void {
        b.count(m.rowid, m.source orelse 0);
        b.decoded += 1;
        _ = b.game_state.reset(.retain_capacity);
        const d = try b.items.get(b.items.ctx, m.patch);
        const t: ?timeline.Timeline = if (m.source) |src| b.source.get(b.game_state.allocator(), src, m.digest) catch |err| blk: {
            log.warn("{s}: {t}", .{ m.match_id, err });
            break :blk null;
        } else null;
        var all: [timeline.max_participants]builds.Picks = undefined;
        if (t) |tl| builds.picks(tl, d, all[0..tl.participants]);
        const have_picks = t != null;

        var seats: [timeline.max_participants]builds.Seat = undefined;
        var blue: [timeline.max_participants]bool = undefined;
        var lane_seats: [10]curves.Seat = undefined;
        var n: usize = 0;
        var n_lane: usize = 0;
        var lane_rows_ok = true;
        try b.players.bind(.{m.match_id});
        while (try b.players.step()) {
            const row = b.players.row(ParticipantRow);
            const r = buildsRow(row);
            if (n_lane == lane_seats.len) lane_rows_ok = false else {
                if (row.puuid) |id| try b.experienced.need(b.gpa, b.db, id);
                lane_seats[n_lane] = curves.seatOf(.{
                    .slot = @intCast(r.slot),
                    .team = row.team_id,
                    .position = r.position,
                    .champion = r.champion_id,
                    .tier = r.tier,
                    .puuid = row.puuid,
                }, b.experienced);
                n_lane += 1;
            }
            const role = Role.fromLcu(r.position) orelse continue;
            if (n == seats.len) continue;
            const k: ?builds.Picks = if (have_picks and r.slot < timeline.max_participants) all[r.slot] else null;
            seats[n] = .{ .p = builds.playerOf(r, role), .k = k, .rank = builds.rankOf(r.tier) };
            blue[n] = r.slot < 5;
            n += 1;
        }
        builds.setOpponents(seats[0..n], blue[0..n]);

        var g: Game = .{
            .start = m.start,
            .rowid = m.rowid,
            .source = m.source orelse 0,
            .platform = try intern(b.arena, &b.strings, m.platform),
            .patch = try intern(b.arena, &b.strings, m.patch),
            .hash = curves.gameHash(m.match_id),
            .curves = .none,
            .lanes = &.{},
            .timeline = have_picks,
            .seats = try b.arena.dupe(builds.Seat, seats[0..n]),
        };
        if (t) |tl| {
            const lg = if (lane_rows_ok) curves.gameOf(lane_seats[0..n_lane]) else null;
            if (lg) |game| {
                const lanes = try b.arena.alloc(Lane, Role.count);
                for (Role.all, lanes) |r, *l| l.* = curves.lane(tl, game, r, m.winner == 100, d.legendary);
                g.lanes = lanes;
                g.curves = .lanes;
            } else g.curves = .skipped;
        } else if (m.source != null) g.curves = .skipped;
        try b.games.append(b.arena, g);
    }
};

/// A day's games as the database has them now, for comparing with its file
const Listed = struct { match_id: []const u8, rowid: i64, source: i64 };

/// Read whole before any is decoded: a statement open across the decode holds one read
/// snapshot, and the WAL can't checkpoint past it (5 Nov: 17 min, then a 187 s checkpoint
/// stalled the crawler's commits)
fn listDay(db: store.Db, arena: Allocator, day: i64) ![]const Listed {
    var list = try db.prepare(
        \\SELECT m.match_id, m.rowid, coalesce(t.rowid, 0)
        \\FROM matches m LEFT JOIN timeline.timelines t USING (match_id)
        \\
    ++ day_where);
    defer list.deinit();
    try list.bind(.{ day * day_ms, (day + 1) * day_ms });
    var out: std.ArrayList(Listed) = .empty;
    while (try list.step()) {
        const r = list.row(Listed);
        try out.append(arena, .{ .match_id = try arena.dupe(u8, r.match_id), .rowid = r.rowid, .source = r.source });
    }
    return out.items;
}

fn oldIndex(gpa: Allocator, old: Day) !std.AutoHashMapUnmanaged(i64, u32) {
    var have: std.AutoHashMapUnmanaged(i64, u32) = .empty;
    try have.ensureTotalCapacity(gpa, @intCast(old.games.len));
    for (old.games, 0..) |g, i| have.putAssumeCapacity(g.rowid, @intCast(i));
    return have;
}

/// Games in `listed` new or changed since `old` was built
fn changedOf(gpa: Allocator, old: Day, listed: []const Listed) !usize {
    var have = try oldIndex(gpa, old);
    defer have.deinit(gpa);
    var n: usize = 0;
    for (listed) |r| {
        const i = have.get(r.rowid) orelse {
            n += 1;
            continue;
        };
        if (old.games[i].source != r.source) n += 1;
    }
    return n;
}

/// Builds a day's file. With `old` (its current file, and the day's games listed since),
/// decodes only the games new or changed since: timelines arrive up to 9 days late
/// (ops.md)
fn buildDay(
    gpa: Allocator,
    io: std.Io,
    db: store.Db,
    day: i64,
    experienced: *curves.Experienced,
    items: Items,
    path: []const u8,
    old: ?struct { day: Day, listed: []const Listed },
    arena: Allocator,
) !struct { games: usize, decoded: usize, bytes: u64 } {
    var b: DayBuilder = try .init(gpa, arena, db, experienced, items);
    defer b.deinit();
    const args = .{ day * day_ms, (day + 1) * day_ms };
    if (old) |x| {
        const o = x.day;
        var have = try oldIndex(gpa, o);
        defer have.deinit(gpa);
        var one = try db.prepare(game_columns ++ "WHERE m.match_id = ?");
        defer one.deinit();
        for (x.listed) |r| {
            if (have.get(r.rowid)) |i| if (o.games[i].source == r.source) {
                try b.keep(o, o.games[i]);
                continue;
            };
            try one.bind(.{r.match_id});
            if (!try one.step()) return error.GameGone;
            try b.decode(one.row(MatchRow));
            one.reset();
        }
    } else {
        var q = try db.prepare(game_columns ++ day_where);
        defer q.deinit();
        try q.bind(args);
        const ahead: *store.Ahead = try .start(gpa, io, db, .{
            .list = "SELECT m.match_id, t.rowid FROM matches m LEFT JOIN timeline.timelines t USING (match_id)\n" ++ day_where,
            .reads = &.{ digest.read_ahead, "SELECT slot FROM participants WHERE match_id = ?1" },
        }, args);
        defer ahead.stop();
        while (try q.step()) {
            ahead.next();
            try b.decode(q.row(MatchRow));
        }
    }

    const value: Day = .{ .day = day, .strings = b.strings.keys(), .games = b.games.items };
    var f = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer f.deinit(io);
    const file_buf = try gpa.alloc(u8, 1 << 20);
    defer gpa.free(file_buf);
    var fw = f.file.writer(io, file_buf);
    const w = &fw.interface;
    try w.writeAll(magic);
    try w.writeInt(u64, formatKey(), .little);
    try w.writeAll(std.mem.asBytes(&b.sig));
    const window = try gpa.alloc(u8, store.raw.window_len);
    defer gpa.free(window);
    var c = try std.compress.flate.Compress.init(w, window, .gzip, .default);
    try flat.write(&c.writer, value);
    try c.finish();
    try w.flush();
    const bytes = fw.logicalPos();
    try f.replace(io);
    log.info("day {d}: {d} games, {d} decoded, {d} B", .{ day, b.games.items.len, b.decoded, bytes });
    return .{ .games = b.games.items.len, .decoded = b.decoded, .bytes = bytes };
}

fn intern(a: Allocator, map: *std.StringArrayHashMapUnmanaged(void), text: []const u8) !Code {
    const gop = try map.getOrPut(a, text);
    if (!gop.found_existing) gop.key_ptr.* = try a.dupe(u8, text);
    return std.math.cast(Code, gop.index) orelse error.TooManyStrings;
}

/// The first game start a view of `patches` (empty: any) from `since_ms` on needs
fn firstStart(db: store.Db, since_ms: i64, patches: []const []const u8) !i64 {
    if (patches.len == 0) return since_ms;
    var first: i64 = std.math.maxInt(i64);
    for (patches) |p| {
        var q = try db.prepare("SELECT min(game_start) FROM matches WHERE patch = ?");
        defer q.deinit();
        try q.bind(.{p});
        if (try q.step()) if (q.row(struct { start: ?i64 }).start) |start| {
            first = @min(first, start);
        };
    }
    return @max(since_ms, first);
}

/// Curves files, builders[i] for specs[i], from one pass over their days (made current
/// first). Caller owns the builders, also on error
pub fn curvesOf(
    s: *Store,
    db: store.Db,
    items: Items,
    specs: []const curves.Spec,
    builders: []core.curvesfile.Builder,
    summaries: []curves.Summary,
) !Counts {
    var from: i64 = std.math.maxInt(i64);
    for (specs) |spec| from = @min(from, try firstStart(db, spec.since_ms, spec.chosen));
    const n = try s.refresh(db, from, items);
    try curvesFrom(s, from, specs, builders, summaries);
    return n;
}

/// Builds files, out[i] for sets[i], from one pass over their days (made current first);
/// `d` names what the files hold. Caller owns `out`
pub fn buildsOf(
    s: *Store,
    db: store.Db,
    items: Items,
    d: *const ddragon.BuildData,
    o: builds.Options,
    sets: []const builds.Set,
    out: []builds.Builder,
) !Counts {
    var from: i64 = std.math.maxInt(i64);
    for (sets) |set| from = @min(from, try firstStart(db, set.slice.since_ms, set.slice.patches));
    const n = try s.refresh(db, from, items);
    try buildsFrom(s, from, d, o, sets, out);
    return n;
}

/// Curves from the day files from `from_ms`'s day on
fn curvesFrom(
    s: *const Store,
    from_ms: i64,
    specs: []const curves.Spec,
    builders: []core.curvesfile.Builder,
    summaries: []curves.Summary,
) !void {
    const gpa = s.gpa;
    @memset(summaries, .{ .games = 0, .skipped = 0 });
    const ds = try s.days(gpa, from_ms);
    defer gpa.free(ds);
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    for (ds) |day| {
        _ = arena_state.reset(.retain_capacity);
        const d = try s.read(gpa, arena_state.allocator(), day) orelse return error.StaleCube;
        for (d.games) |g| {
            if (g.curves == .none) continue;
            for (specs, builders, summaries) |spec, *b, *sum| {
                if (!spec.takes(d.string(g.patch), g.start, d.string(g.platform))) continue;
                if (g.curves == .skipped) {
                    sum.skipped += 1;
                    continue;
                }
                for (g.lanes) |l| try b.addLaneOf(l, g.hash);
                b.addGame();
                sum.games += 1;
            }
        }
    }
}

/// Builds from the day files from `from_ms`'s day on. Caller owns `out`
fn buildsFrom(
    s: *const Store,
    from_ms: i64,
    d: *const ddragon.BuildData,
    o: builds.Options,
    sets: []const builds.Set,
    out: []builds.Builder,
) !void {
    const gpa = s.gpa;
    std.debug.assert(sets.len == out.len and sets.len <= builds.max_sets);
    var slices: [builds.max_sets]stats.Slice = undefined;
    for (sets, slices[0..sets.len]) |set, *sl| sl.* = set.slice;
    var floors: [builds.max_sets]?usize = undefined;
    try builds.setFloors(o, sets, floors[0..sets.len]);
    try builds.initSets(gpa, o, sets, out);
    errdefer for (out) |*b| b.deinit();
    const ds = try s.days(gpa, from_ms);
    defer gpa.free(ds);
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    for (ds) |day| {
        _ = arena_state.reset(.retain_capacity);
        const dy = try s.read(gpa, arena_state.allocator(), day) orelse return error.StaleCube;
        for (dy.games) |g| {
            const mask = stats.Slice.of(slices[0..sets.len], dy.string(g.platform), g.start, dy.string(g.patch));
            if (mask == 0) continue;
            try builds.addSeats(out, mask, floors[0..sets.len], g.seats, g.timeline, d);
        }
    }
}
