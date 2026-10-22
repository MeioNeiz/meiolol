//! Views partials (data/partials, docs/architecture.md "Views partials"): compact copies of
//! what `site --views` reads from the database, kept between writes so a write reads
//! only what changed since the last one.
//!
//! - days/<unix day>.bin: every ranked solo game (queue 420, no remake) started that UTC
//!   day, as the views' tallies read it (stats, bans, filters, pool, spread, learning):
//!   the match row, its participant rows by slot (PUUID as a 128-bit hash) and bans in
//!   key order. Other matches are listed by id only. Per-game, not per-day sums: the
//!   30-day window starts mid-day, a player's main and learning's game numbers need
//!   each player's games, and filters' file order follows match ids, so only the games
//!   themselves merge exactly. Smaller than the sums anyway (a stats builder is 12 MB)
//! - mastery.bin: each mastery row's contribution to the pool tally (main, one-trick,
//!   champions also played) and its fetch time, for one champion list
//! - learning.bin: learning.zig's points bin of each player and champion with a game after
//!   the player's mastery fetch, by the row's rowid and fetch time (a refetch's REPLACE
//!   gives a new rowid), so a write decodes only rows new since
//!
//! A refresh diffs (match_id, rowid) of every match and (match_id, rowid) of every
//! timeline against the files and reads only the matches new, replaced (INSERT OR
//! REPLACE gives a new rowid) or with a new timeline (its gold columns), so a game
//! arriving late for an old day re-opens that day's file. What changes rows in place
//! is handled apart: forget (scrub, and the forgotten list at each refresh), PUUIDs
//! blanked at 24 months (days near the cutoff read again), and rebuild, rekey and
//! restore, which drop the whole directory. Any change to this file's source or types
//! starts the files again (key).

const std = @import("std");
const store = @import("store");
const flat = @import("site/flat.zig");
const riot_mastery = @import("riot/mastery.zig");
const core = @import("core");
const pool = @import("pool.zig");
const learning = @import("learning.zig");
const stats = @import("stats.zig");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.partials);

const ranked_solo = 420;
const day_ms = std.time.ms_per_day;
/// The crawler blanks PUUIDs of matches older than this (riot/writer.zig)
const blank_days = 730;

/// String codes index Store.strings from 1; 0 is NULL
pub const Code = u16;

/// A PUUID's 128-bit hash (key): players told apart without keeping the PUUID
pub const Key = struct {
    lo: u64,
    hi: u64,

    pub fn eql(a: Key, b: Key) bool {
        return a.lo == b.lo and a.hi == b.hi;
    }

    pub fn lessThan(a: Key, b: Key) bool {
        return if (a.hi != b.hi) a.hi < b.hi else a.lo < b.lo;
    }
};

pub const Player = struct {
    slot: i8,
    team: i16,
    champion: i32,
    position: Code,
    tier: Code,
    win: bool,
    /// key(puuid); null when blank
    puuid: ?Key,
    gold14: ?i32,
    /// gold15 IS NOT NULL: a frame after minute 14
    gold15: bool,
};

pub const Ban = struct { team: i16, champion: i32 };

/// Store.sliceMasks: each slice's platform and patch bits by string code
pub const SliceMasks = struct {
    slices: []const stats.Slice,
    platform: []u32,
    patch: []u32,

    /// Bit i set when slices[i] counts `g`
    pub fn of(m: SliceMasks, g: *const Game) u32 {
        const in = m.platform[g.platform] & m.patch[g.patch];
        return if (in == 0) 0 else in & stats.Slice.sinceMask(m.slices, g.start);
    }

    pub fn deinit(m: *SliceMasks, gpa: Allocator) void {
        gpa.free(m.platform);
        gpa.free(m.patch);
    }
};

pub const Game = struct {
    id: []const u8,
    rowid: i64,
    /// Its rowid in timeline.timelines, 0 for none
    timeline: i64,
    /// game_start, Unix ms
    start: i64,
    duration_s: i64,
    winning_team: ?i64,
    platform: Code,
    patch: Code,
    players: []const Player,
    bans: []const Ban,
};

/// A match that is not a ranked solo game: known, so it is not read again. Queue,
/// platform and patch for patches(), which counts remakes too
const Other = struct { id: []const u8, rowid: i64, start: i64, queue: i32, platform: Code, patch: Code };

const DayFile = struct {
    day: i64,
    strings: []const []const u8,
    games: []const Game,
    others: []const Other,
};

const State = struct { days: []const i64 };

const Contribution = struct {
    key: Key,
    rowid: i64,
    platform: Code,
    /// Champion id; 0: the player does not count (too few points, no known champion)
    main: u16,
    one_trick: bool,
    others: []const u16,
    fetched_at: i64,
};

const MasteryFile = struct {
    /// masteryKey and the champion list it was made for
    champs_key: u64,
    strings: []const []const u8,
    entries: []const Contribution,
};

const Cached = struct { rowid: i64, fetched_at: i64, champion: u16, bin: u8 };

const LearningFile = struct {
    /// learningKey
    key: u64,
    entries: []const Cached,
};

const magic = "MEIOPAR1";

/// Hashes the files' types and this source: another binary's files are read again
pub fn formatKey() u64 {
    var h: std.hash.Wyhash = .init(1);
    inline for (.{ DayFile, State, MasteryFile, LearningFile }) |T| h.update(std.mem.asBytes(&flat.fingerprint(T)));
    h.update(@embedFile("partials.zig"));
    return h.final();
}

/// Contributions also follow pool's rule and the blob format
fn masteryKey(st: *const core.Stats) u64 {
    var h: std.hash.Wyhash = .init(formatKey());
    h.update(@embedFile("pool.zig"));
    h.update(@embedFile("riot/mastery.zig"));
    h.update(std.mem.sliceAsBytes(st.ids));
    return h.final();
}

/// Bins follow learning's edges and the blob format
fn learningKey() u64 {
    var h: std.hash.Wyhash = .init(formatKey());
    h.update(@embedFile("learning.zig"));
    h.update(@embedFile("riot/mastery.zig"));
    return h.final();
}

pub fn key(puuid: []const u8) Key {
    return .{ .lo = std.hash.Wyhash.hash(0, puuid), .hi = std.hash.Wyhash.hash(0x9e3779b97f4a7c15, puuid) };
}

/// A file writeIn wrote, decoded into `arena`; null when missing, of another format or
/// unreadable
fn readIn(io: std.Io, gpa: Allocator, arena: Allocator, comptime T: type, file: []const u8) !?T {
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, file, gpa, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer gpa.free(bytes);
    var r: std.Io.Reader = .fixed(bytes);
    const head = r.takeArray(magic.len) catch return null;
    if (!std.mem.eql(u8, head, magic)) return null;
    if ((r.takeInt(u64, .little) catch return null) != formatKey()) return null;
    const value = flat.read(T, &r, arena) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return null,
    };
    if (r.bufferedLen() != 0) return null;
    return value;
}

fn writeIn(io: std.Io, file: []const u8, value: anytype) !void {
    var f = try std.Io.Dir.cwd().createFileAtomic(io, file, .{ .make_path = true, .replace = true });
    defer f.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = f.file.writer(io, &buf);
    const w = &fw.interface;
    try w.writeAll(magic);
    try w.writeInt(u64, formatKey(), .little);
    try flat.write(w, value);
    try w.flush();
    try f.replace(io);
}

pub fn dirIn(arena: Allocator, data_dir: []const u8) ![]const u8 {
    return std.fs.path.join(arena, &.{ data_dir, "partials" });
}

/// After rebuild, rekey or restore: rows changed in place, so every file goes, under
/// the lock (a views write running finishes first, rather than write after this)
pub fn drop(gpa: Allocator, io: std.Io, dir: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    cwd.access(io, dir, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    const s = try Store.openLocked(gpa, io, dir);
    defer s.deinit();
    const days = try s.path("days", .{});
    defer gpa.free(days);
    try cwd.deleteTree(io, days);
    for ([_][]const u8{ "state.bin", "mastery.bin", "learning.bin" }) |name| {
        const file = try s.path("{s}", .{name});
        defer gpa.free(file);
        cwd.deleteFile(io, file) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
    }
}

pub const Options = struct {
    /// Unix ms, for the 24-month PUUID cutoff
    now_ms: i64,
    /// More matches to read than this: whole-table scans instead of lookups
    bulk_after: usize = 50_000,
};

const Day = struct {
    games: std.ArrayList(Game) = .empty,
    others: std.ArrayList(Other) = .empty,
    dirty: bool = false,
};

pub const Counts = struct {
    games: usize = 0,
    read: usize = 0,
    dropped: usize = 0,
    days_written: usize = 0,
    bulk: bool = false,
    mastery: usize = 0,
    mastery_read: usize = 0,
    /// Players and champions with a game after the player's mastery fetch, and the
    /// mastery rows decoded for them
    learning: usize = 0,
    learning_read: usize = 0,
};

/// A player and a champion they played
pub const Pair = struct { key: Key, champion: u16 };

/// The mastery row's fetch time and the champion's points bin then
pub const PairBin = struct { fetched_at: i64, bin: u8 };

/// The games and mastery contributions, held under the directory's lock until deinit
pub const Store = struct {
    gpa: Allocator,
    io: std.Io,
    arena_state: std.heap.ArenaAllocator,
    dir: []const u8,
    lock: std.Io.File,
    strings: std.StringArrayHashMapUnmanaged(void) = .empty,
    days: std.AutoArrayHashMapUnmanaged(i64, Day) = .empty,
    /// Every game, by match id: after refresh
    sorted: []const *const Game = &.{},
    /// After masteryTallies, in gpa
    learning: ?std.AutoHashMapUnmanaged(Pair, PairBin) = null,
    counts: Counts = .{},

    /// Opens (or starts) `dir`, waiting for its lock, and brings it up to date with db
    pub fn open(gpa: Allocator, io: std.Io, db: store.Db, dir: []const u8, opts: Options) !*Store {
        const s = try openLocked(gpa, io, dir);
        errdefer s.deinit();
        try s.loadDays();
        try s.refresh(db, opts);
        try s.save();
        try s.sort();
        return s;
    }

    fn openLocked(gpa: Allocator, io: std.Io, dir: []const u8) !*Store {
        const cwd = std.Io.Dir.cwd();
        const days_dir = try std.fs.path.join(gpa, &.{ dir, "days" });
        defer gpa.free(days_dir);
        try cwd.createDirPath(io, days_dir);
        const lock_path = try std.fs.path.join(gpa, &.{ dir, "lock" });
        defer gpa.free(lock_path);
        const lock = try cwd.createFile(io, lock_path, .{ .lock = .exclusive, .truncate = false });
        errdefer lock.close(io);
        const s = try gpa.create(Store);
        s.* = .{ .gpa = gpa, .io = io, .arena_state = .init(gpa), .dir = undefined, .lock = lock };
        s.dir = try s.arena().dupe(u8, dir);
        return s;
    }

    pub fn deinit(s: *Store) void {
        if (s.learning) |*l| l.deinit(s.gpa);
        s.lock.close(s.io);
        s.arena_state.deinit();
        s.gpa.destroy(s);
    }

    fn arena(s: *Store) Allocator {
        return s.arena_state.allocator();
    }

    pub fn string(s: *const Store, code: Code) ?[]const u8 {
        return if (code == 0) null else s.strings.keys()[code - 1];
    }

    /// Code of `text` (null: 0), added when new
    fn intern(s: *Store, text: ?[]const u8) !Code {
        const t = text orelse return 0;
        const gop = try s.strings.getOrPut(s.arena(), t);
        if (!gop.found_existing) gop.key_ptr.* = try s.arena().dupe(u8, t);
        return std.math.cast(Code, gop.index + 1) orelse error.TooManyStrings;
    }

    /// By code: whether the string is one of `names`; caller frees
    pub fn codesIn(s: *const Store, gpa: Allocator, names: []const []const u8) ![]bool {
        const in = try gpa.alloc(bool, s.strings.count() + 1);
        @memset(in, false);
        for (s.strings.keys(), 1..) |k, code| {
            for (names) |n| if (std.mem.eql(u8, n, k)) {
                in[code] = true;
            };
        }
        return in;
    }

    /// By code: stats.setsWith of the string as a platform; caller frees
    pub fn setMasks(s: *const Store, gpa: Allocator, sets: []const []const []const u8) ![]u32 {
        const masks = try gpa.alloc(u32, s.strings.count() + 1);
        masks[0] = 0;
        for (s.strings.keys(), masks[1..]) |name, *m| m.* = stats.setsWith(sets, name);
        return masks;
    }

    /// stats.Slice.of for this store's games; free with SliceMasks.deinit
    pub fn sliceMasks(s: *const Store, gpa: Allocator, slices: []const stats.Slice) !SliceMasks {
        const platform = try gpa.alloc(u32, s.strings.count() + 1);
        errdefer gpa.free(platform);
        const patch = try gpa.alloc(u32, s.strings.count() + 1);
        platform[0] = 0;
        patch[0] = stats.Slice.patchMask(slices, "");
        for (s.strings.keys(), platform[1..], patch[1..]) |name, *pl, *pa| {
            pl.* = stats.Slice.platformMask(slices, name);
            pa.* = stats.Slice.patchMask(slices, name);
        }
        return .{ .slices = slices, .platform = platform, .patch = patch };
    }

    fn path(s: *Store, comptime fmt: []const u8, args: anytype) ![]const u8 {
        return std.fmt.allocPrint(s.gpa, "{s}/" ++ fmt, .{s.dir} ++ args);
    }

    fn readFile(s: *Store, comptime T: type, file: []const u8) !?T {
        return readIn(s.io, s.gpa, s.arena(), T, file);
    }

    fn writeFile(s: *Store, file: []const u8, value: anytype) !void {
        try writeIn(s.io, file, value);
    }

    /// Every day file the state lists; one unreadable or of another format is read
    /// again from the database (its matches are unknown)
    fn loadDays(s: *Store) !void {
        const state_path = try s.path("state.bin", .{});
        defer s.gpa.free(state_path);
        const state = try s.readFile(State, state_path) orelse return;
        for (state.days) |d| {
            const file = try s.path("days/{d}.bin", .{d});
            defer s.gpa.free(file);
            const df = try s.readFile(DayFile, file) orelse continue;
            if (df.day != d) continue;
            const day = s.dayFrom(df) catch |err| switch (err) {
                error.Corrupt => {
                    log.warn("{s}: bad string code, read again", .{file});
                    continue;
                },
                else => return err,
            };
            try s.days.put(s.arena(), d, day);
        }
    }

    fn dayFrom(s: *Store, df: DayFile) !Day {
        const codes = try s.gpa.alloc(Code, df.strings.len + 1);
        defer s.gpa.free(codes);
        codes[0] = 0;
        for (df.strings, codes[1..]) |t, *c| c.* = try s.intern(t);
        const map = struct {
            fn f(cs: []const Code, c: Code) !Code {
                return if (c < cs.len) cs[c] else error.Corrupt;
            }
        }.f;
        var day: Day = .{};
        try day.games.ensureTotalCapacity(s.arena(), df.games.len);
        for (df.games) |g| {
            var copy = g;
            copy.platform = try map(codes, g.platform);
            copy.patch = try map(codes, g.patch);
            const players = try s.arena().dupe(Player, g.players);
            for (players) |*p| {
                p.position = try map(codes, p.position);
                p.tier = try map(codes, p.tier);
            }
            copy.players = players;
            day.games.appendAssumeCapacity(copy);
        }
        try day.others.ensureTotalCapacity(s.arena(), df.others.len);
        for (df.others) |o| {
            var copy = o;
            copy.platform = try map(codes, o.platform);
            copy.patch = try map(codes, o.patch);
            day.others.appendAssumeCapacity(copy);
        }
        return day;
    }

    fn save(s: *Store) !void {
        var keep: std.ArrayList(i64) = .empty;
        defer keep.deinit(s.gpa);
        const strings = s.strings.keys();
        var it = s.days.iterator();
        while (it.next()) |e| {
            const d = e.key_ptr.*;
            const day = e.value_ptr;
            const file = try s.path("days/{d}.bin", .{d});
            defer s.gpa.free(file);
            if (day.games.items.len == 0 and day.others.items.len == 0) {
                std.Io.Dir.cwd().deleteFile(s.io, file) catch |err| switch (err) {
                    error.FileNotFound => {},
                    else => return err,
                };
                continue;
            }
            try keep.append(s.gpa, d);
            if (!day.dirty) continue;
            try s.writeFile(file, DayFile{ .day = d, .strings = strings, .games = day.games.items, .others = day.others.items });
            day.dirty = false;
            s.counts.days_written += 1;
        }
        std.mem.sort(i64, keep.items, {}, std.sort.asc(i64));
        const state_path = try s.path("state.bin", .{});
        defer s.gpa.free(state_path);
        try s.writeFile(state_path, State{ .days = keep.items });
    }

    fn sort(s: *Store) !void {
        var all: std.ArrayList(*const Game) = .empty;
        for (s.days.values()) |*day| {
            for (day.games.items) |*g| try all.append(s.arena(), g);
        }
        std.mem.sort(*const Game, all.items, {}, struct {
            fn f(_: void, a: *const Game, b: *const Game) bool {
                return std.mem.lessThan(u8, a.id, b.id);
            }
        }.f);
        s.sorted = all.items;
        s.counts.games = all.items.len;
    }

    fn dayOf(s: *Store, start: i64) !*Day {
        const gop = try s.days.getOrPut(s.arena(), @divFloor(start, day_ms));
        if (!gop.found_existing) gop.value_ptr.* = .{};
        return gop.value_ptr;
    }

    /// One read transaction: what the files lack or hold stale comes from db
    fn refresh(s: *Store, db: store.Db, opts: Options) !void {
        try db.exec("BEGIN");
        defer db.exec("COMMIT") catch {};
        // Timelines first: their gold lands on participants in the same commit, but
        // attached files' snapshots start at each one's first read, so a timeline seen
        // here always has its gold in main's later snapshot
        var timelines: std.StringHashMapUnmanaged(i64) = .empty;
        defer timelines.deinit(s.gpa);
        var tl_ids: std.heap.ArenaAllocator = .init(s.gpa);
        defer tl_ids.deinit();
        {
            var q = try db.prepare("SELECT match_id, rowid FROM timeline.timelines");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) {
                const r = q.row(struct { id: []const u8, rowid: i64 });
                try timelines.put(s.gpa, try tl_ids.allocator().dupe(u8, r.id), r.rowid);
            }
        }

        const Known = struct { rowid: i64, timeline: i64, game: bool };
        var known: std.StringHashMapUnmanaged(Known) = .empty;
        defer known.deinit(s.gpa);
        for (s.days.values()) |day| {
            for (day.games.items) |g| try known.put(s.gpa, g.id, .{ .rowid = g.rowid, .timeline = g.timeline, .game = true });
            for (day.others.items) |o| try known.put(s.gpa, o.id, .{ .rowid = o.rowid, .timeline = 0, .game = false });
        }

        // Matches to read: new, replaced, or with another timeline; and every match the
        // files hold that is gone or read again (by id)
        var fetch: std.StringArrayHashMapUnmanaged(i64) = .empty;
        defer fetch.deinit(s.gpa);
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        defer seen.deinit(s.gpa);
        var ids: std.heap.ArenaAllocator = .init(s.gpa);
        defer ids.deinit();
        var found: usize = 0;
        {
            var q = try db.prepare("SELECT match_id, rowid FROM matches");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) {
                const r = q.row(struct { id: []const u8, rowid: i64 });
                const tl = timelines.get(r.id) orelse 0;
                if (known.get(r.id)) |k| {
                    found += 1;
                    if (k.rowid == r.rowid and (!k.game or k.timeline == tl)) {
                        try seen.put(s.gpa, try ids.allocator().dupe(u8, r.id), {});
                        continue;
                    }
                }
                try fetch.put(s.gpa, try ids.allocator().dupe(u8, r.id), r.rowid);
            }
        }
        s.counts.dropped = known.count() - found;

        // PUUIDs blanked at 24 months: days around the cutoff read again each time (the
        // crawler blanks them in chunks), older ones keep none
        const cutoff = opts.now_ms - blank_days * day_ms;
        for (s.days.keys(), s.days.values()) |d, *day| {
            const lo = d * day_ms;
            const hi = lo + day_ms;
            if (hi > cutoff - 3 * day_ms and lo < cutoff + day_ms) {
                for (day.games.items) |g| {
                    if (seen.fetchRemove(g.id) != null) try fetch.put(s.gpa, g.id, g.rowid);
                }
            } else if (hi <= cutoff - 3 * day_ms) {
                for (day.games.items) |g| for (g.players) |p| if (p.puuid != null) {
                    day.dirty = true;
                };
                if (day.dirty) for (day.games.items) |*g| {
                    const players = try s.arena().dupe(Player, g.players);
                    for (players) |*p| p.puuid = null;
                    g.players = players;
                };
            }
        }

        // Out: the gone and the ones read again
        for (s.days.values()) |*day| {
            var w: usize = 0;
            for (day.games.items) |g| {
                if (seen.contains(g.id)) {
                    day.games.items[w] = g;
                    w += 1;
                }
            }
            if (w != day.games.items.len) day.dirty = true;
            day.games.shrinkRetainingCapacity(w);
            w = 0;
            for (day.others.items) |o| {
                if (seen.contains(o.id)) {
                    day.others.items[w] = o;
                    w += 1;
                }
            }
            if (w != day.others.items.len) day.dirty = true;
            day.others.shrinkRetainingCapacity(w);
        }

        try s.scrubForgotten(db);

        s.counts.read = fetch.count();
        if (fetch.count() == 0) return;
        const sorted_ids = try s.gpa.dupe([]const u8, fetch.keys());
        defer s.gpa.free(sorted_ids);
        std.mem.sort([]const u8, sorted_ids, {}, struct {
            fn f(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.f);
        if (fetch.count() > opts.bulk_after) {
            s.counts.bulk = true;
            try s.readBulk(db, sorted_ids, &timelines);
        } else try s.readEach(db, sorted_ids, &timelines);
    }

    /// Blank every PUUID on the forgotten list (a forget the files missed)
    fn scrubForgotten(s: *Store, db: store.Db) !void {
        var gone: std.AutoHashMapUnmanaged(Key, void) = .empty;
        defer gone.deinit(s.gpa);
        var q = try db.prepare("SELECT puuid FROM forgotten");
        defer q.deinit();
        try q.bind(.{});
        while (try q.step()) try gone.put(s.gpa, key(q.row(struct { p: []const u8 }).p), {});
        if (gone.count() > 0) _ = try s.blank(&gone);
    }

    /// Players whose key is in `gone` blanked; how many rows
    fn blank(s: *Store, gone: *const std.AutoHashMapUnmanaged(Key, void)) !usize {
        var n: usize = 0;
        for (s.days.values()) |*day| for (day.games.items) |*g| {
            var hit = false;
            for (g.players) |p| {
                if (p.puuid) |k| hit = hit or gone.contains(k);
            }
            if (!hit) continue;
            const players = try s.arena().dupe(Player, g.players);
            for (players) |*p| if (p.puuid) |k| if (gone.contains(k)) {
                p.puuid = null;
                n += 1;
            };
            g.players = players;
            day.dirty = true;
        };
        return n;
    }

    const MatchRow = struct {
        rowid: i64,
        platform: []const u8,
        queue_id: i64,
        patch: []const u8,
        game_start: i64,
        duration_s: i64,
        winning_team: ?i64,
        remake: i64,
    };

    const PlayerRow = struct {
        slot: i64,
        team: i64,
        puuid: ?[]const u8,
        champion: i64,
        position: ?[]const u8,
        win: bool,
        tier: ?[]const u8,
        gold14: ?i64,
        gold15: bool,
    };

    const player_cols = "slot, team_id, puuid, champion_id, position, win, tier, gold14, gold15 IS NOT NULL";

    fn player(s: *Store, r: PlayerRow) !Player {
        return .{
            .slot = std.math.cast(i8, r.slot) orelse return error.Unrepresentable,
            .team = std.math.cast(i16, r.team) orelse return error.Unrepresentable,
            .champion = std.math.cast(i32, r.champion) orelse return error.Unrepresentable,
            .position = try s.intern(r.position),
            .tier = try s.intern(r.tier),
            .win = r.win,
            .puuid = if (r.puuid) |p| key(p) else null,
            .gold14 = if (r.gold14) |g| std.math.cast(i32, g) orelse return error.Unrepresentable else null,
            .gold15 = r.gold15,
        };
    }

    fn ban(team: i64, champion: i64) !Ban {
        return .{
            .team = std.math.cast(i16, team) orelse return error.Unrepresentable,
            .champion = std.math.cast(i32, champion) orelse return error.Unrepresentable,
        };
    }

    fn addMatch(s: *Store, id: []const u8, m: MatchRow, timeline: i64, players: []const Player, bans: []const Ban) !void {
        const day = try s.dayOf(m.game_start);
        day.dirty = true;
        const own = try s.arena().dupe(u8, id);
        if (m.queue_id != ranked_solo or m.remake != 0) {
            try day.others.append(s.arena(), .{
                .id = own,
                .rowid = m.rowid,
                .start = m.game_start,
                .queue = std.math.cast(i32, m.queue_id) orelse return error.Unrepresentable,
                .platform = try s.intern(m.platform),
                .patch = try s.intern(m.patch),
            });
            return;
        }
        try day.games.append(s.arena(), .{
            .id = own,
            .rowid = m.rowid,
            .timeline = timeline,
            .start = m.game_start,
            .duration_s = m.duration_s,
            .winning_team = m.winning_team,
            .platform = try s.intern(m.platform),
            .patch = try s.intern(m.patch),
            .players = try s.arena().dupe(Player, players),
            .bans = try s.arena().dupe(Ban, bans),
        });
    }

    /// A few matches: each by primary key
    fn readEach(s: *Store, db: store.Db, ids: []const []const u8, timelines: *const std.StringHashMapUnmanaged(i64)) !void {
        var mq = try db.prepare("SELECT rowid, platform, queue_id, patch, game_start, duration_s, winning_team, remake FROM matches WHERE match_id = ?");
        defer mq.deinit();
        var pq = try db.prepare("SELECT " ++ player_cols ++ " FROM participants WHERE match_id = ? ORDER BY slot");
        defer pq.deinit();
        var bq = try db.prepare("SELECT team_id, champion_id FROM bans WHERE match_id = ? ORDER BY team_id, pick_turn");
        defer bq.deinit();
        var players: std.ArrayList(Player) = .empty;
        defer players.deinit(s.gpa);
        var bans: std.ArrayList(Ban) = .empty;
        defer bans.deinit(s.gpa);
        for (ids) |id| {
            try mq.bind(.{id});
            const m = if (try mq.step()) mq.row(MatchRow) else {
                mq.reset();
                continue;
            };
            players.clearRetainingCapacity();
            bans.clearRetainingCapacity();
            const ranked = m.queue_id == ranked_solo and m.remake == 0;
            if (ranked) {
                try pq.bind(.{id});
                while (try pq.step()) try players.append(s.gpa, try s.player(pq.row(PlayerRow)));
                pq.reset();
                try bq.bind(.{id});
                while (try bq.step()) {
                    const r = bq.row(struct { team: i64, champion: i64 });
                    try bans.append(s.gpa, try ban(r.team, r.champion));
                }
                bq.reset();
            }
            // Strings in m are the statement's: copied by intern and addMatch
            try s.addMatch(id, m, timelines.get(id) orelse 0, players.items, bans.items);
            mq.reset();
        }
    }

    /// Many matches (the first refresh): whole tables in key order, merged by id
    fn readBulk(s: *Store, db: store.Db, ids: []const []const u8, timelines: *const std.StringHashMapUnmanaged(i64)) !void {
        const Pending = struct { m: MatchRow, players: std.ArrayList(Player) = .empty, bans: std.ArrayList(Ban) = .empty };
        var work: std.heap.ArenaAllocator = .init(s.gpa);
        defer work.deinit();
        const wa = work.allocator();
        const pending = try wa.alloc(?Pending, ids.len);
        @memset(pending, null);
        var index: std.StringHashMapUnmanaged(usize) = .empty;
        defer index.deinit(s.gpa);
        for (ids, 0..) |id, i| try index.put(s.gpa, id, i);
        {
            var q = try db.prepare("SELECT match_id, rowid, platform, queue_id, patch, game_start, duration_s, winning_team, remake FROM matches");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) {
                const r = q.row(struct {
                    id: []const u8,
                    rowid: i64,
                    platform: []const u8,
                    queue_id: i64,
                    patch: []const u8,
                    game_start: i64,
                    duration_s: i64,
                    winning_team: ?i64,
                    remake: i64,
                });
                const i = index.get(r.id) orelse continue;
                pending[i] = .{ .m = .{
                    .rowid = r.rowid,
                    .platform = try wa.dupe(u8, r.platform),
                    .queue_id = r.queue_id,
                    .patch = try wa.dupe(u8, r.patch),
                    .game_start = r.game_start,
                    .duration_s = r.duration_s,
                    .winning_team = r.winning_team,
                    .remake = r.remake,
                } };
            }
        }
        {
            var q = try db.prepare("SELECT match_id, " ++ player_cols ++ " FROM participants ORDER BY match_id, slot");
            defer q.deinit();
            try q.bind(.{});
            var at: usize = 0;
            while (try q.step()) {
                const id = q.bytes(0);
                while (at < ids.len and std.mem.lessThan(u8, ids[at], id)) at += 1;
                if (at == ids.len) break;
                if (!std.mem.eql(u8, ids[at], id)) continue;
                const p = &(pending[at] orelse continue);
                if (p.m.queue_id != ranked_solo or p.m.remake != 0) continue;
                const r = q.row(struct {
                    id: []const u8,
                    slot: i64,
                    team: i64,
                    puuid: ?[]const u8,
                    champion: i64,
                    position: ?[]const u8,
                    win: bool,
                    tier: ?[]const u8,
                    gold14: ?i64,
                    gold15: bool,
                });
                try p.players.append(wa, try s.player(.{
                    .slot = r.slot,
                    .team = r.team,
                    .puuid = r.puuid,
                    .champion = r.champion,
                    .position = r.position,
                    .win = r.win,
                    .tier = r.tier,
                    .gold14 = r.gold14,
                    .gold15 = r.gold15,
                }));
            }
        }
        {
            var q = try db.prepare("SELECT match_id, team_id, champion_id FROM bans ORDER BY match_id, team_id, pick_turn");
            defer q.deinit();
            try q.bind(.{});
            var at: usize = 0;
            while (try q.step()) {
                const r = q.row(struct { id: []const u8, team: i64, champion: i64 });
                while (at < ids.len and std.mem.lessThan(u8, ids[at], r.id)) at += 1;
                if (at == ids.len) break;
                if (!std.mem.eql(u8, ids[at], r.id)) continue;
                const p = &(pending[at] orelse continue);
                if (p.m.queue_id != ranked_solo or p.m.remake != 0) continue;
                try p.bans.append(wa, try ban(r.team, r.champion));
            }
        }
        for (ids, pending) |id, *p| {
            const got = &(p.* orelse continue);
            try s.addMatch(id, got.m, timelines.get(id) orelse 0, got.players.items, got.bans.items);
        }
    }

    /// The pool tally's mastery source for `st`'s champions: contributions kept in
    /// mastery.bin, rows new or replaced since read from db, those gone dropped. Runs
    /// beside readers of the games (filters), so it touches nothing of the store's
    /// but the file
    pub fn masteryTallies(s: *Store, db: store.Db, st: *const core.Stats, sets: []const []const []const u8, out: []pool.Tally) !void {
        const gpa = s.gpa;
        var work: std.heap.ArenaAllocator = .init(gpa);
        defer work.deinit();
        const wa = work.allocator();
        var strings: std.StringArrayHashMapUnmanaged(void) = .empty;
        const internIn = struct {
            fn f(a: Allocator, map: *std.StringArrayHashMapUnmanaged(void), text: ?[]const u8) !Code {
                const t = text orelse return 0;
                const gop = try map.getOrPut(a, t);
                if (!gop.found_existing) gop.key_ptr.* = try a.dupe(u8, t);
                return std.math.cast(Code, gop.index + 1) orelse error.TooManyStrings;
            }
        }.f;
        const champs_key = masteryKey(st);
        const file = try s.path("mastery.bin", .{});
        defer gpa.free(file);
        var old: []const Contribution = &.{};
        if (try readIn(s.io, gpa, wa, MasteryFile, file)) |m| if (m.champs_key == champs_key) {
            const codes = try wa.alloc(Code, m.strings.len + 1);
            codes[0] = 0;
            for (m.strings, codes[1..]) |t, *c| c.* = try internIn(wa, &strings, t);
            const copy = try wa.dupe(Contribution, m.entries);
            for (copy) |*e| e.platform = if (e.platform < codes.len) codes[e.platform] else return error.Corrupt;
            old = copy;
        };

        try db.exec("BEGIN");
        defer db.exec("COMMIT") catch {};
        const Row = struct { key: Key, rowid: i64 };
        var rows: std.ArrayList(Row) = .empty;
        defer rows.deinit(gpa);
        {
            var q = try db.prepare("SELECT puuid, rowid FROM mastery");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) {
                const r = q.row(struct { puuid: []const u8, rowid: i64 });
                try rows.append(gpa, .{ .key = key(r.puuid), .rowid = r.rowid });
            }
        }
        std.mem.sort(Row, rows.items, {}, struct {
            fn f(_: void, a: Row, b: Row) bool {
                return a.key.lessThan(b.key);
            }
        }.f);
        // old is in key order (written so)
        const entries = try wa.alloc(Contribution, rows.items.len);
        var missing: std.ArrayList(usize) = .empty;
        defer missing.deinit(gpa);
        var at: usize = 0;
        for (rows.items, entries, 0..) |r, *e, i| {
            while (at < old.len and old[at].key.lessThan(r.key)) at += 1;
            if (at < old.len and old[at].key.eql(r.key) and old[at].rowid == r.rowid) {
                e.* = old[at];
            } else {
                try missing.append(gpa, i);
                e.* = .{ .key = r.key, .rowid = r.rowid, .platform = 0, .main = 0, .one_trick = false, .others = &.{}, .fetched_at = 0 };
            }
        }
        s.counts.mastery = entries.len;
        s.counts.mastery_read = missing.items.len;
        // By rowid: the table's order, so the reads walk it once
        std.mem.sort(usize, missing.items, entries, struct {
            fn f(e: []const Contribution, a: usize, b: usize) bool {
                return e[a].rowid < e[b].rowid;
            }
        }.f);
        {
            var q = try db.prepare("SELECT data, fetched_at, platform FROM mastery WHERE rowid = ?");
            defer q.deinit();
            var scratch: std.heap.ArenaAllocator = .init(gpa);
            defer scratch.deinit();
            var plays: std.ArrayList(pool.Play) = .empty;
            defer plays.deinit(gpa);
            for (missing.items) |i| {
                const e = &entries[i];
                try q.bind(.{e.rowid});
                defer q.reset();
                if (!try q.step()) continue;
                _ = scratch.reset(.retain_capacity);
                const r = q.row(struct { data: []const u8, fetched_at: i64, platform: ?[]const u8 });
                e.platform = try internIn(wa, &strings, r.platform);
                e.fetched_at = r.fetched_at;
                plays.clearRetainingCapacity();
                if (!try pool.masteryPlays(scratch.allocator(), gpa, r.data, r.fetched_at, &plays)) continue;
                const c = pool.contribution(st, plays.items, .mastery) orelse continue;
                e.main = std.math.cast(u16, c.main) orelse return error.Unrepresentable;
                e.one_trick = c.one_trick;
                var others: std.ArrayList(u16) = .empty;
                for (plays.items) |p| if (c.plays(st, p)) {
                    try others.append(wa, std.math.cast(u16, p.champion) orelse return error.Unrepresentable);
                };
                e.others = others.items;
            }
        }
        try writeIn(s.io, file, MasteryFile{ .champs_key = champs_key, .strings = strings.keys(), .entries = entries });
        try s.learningBins(db, st, entries);

        const masks = try wa.alloc(u32, strings.count() + 1);
        masks[0] = 0;
        for (strings.keys(), masks[1..]) |name, *m| m.* = stats.setsWith(sets, name);
        for (entries) |e| {
            if (e.main == 0) continue;
            const mask = masks[e.platform];
            if (mask == 0) continue;
            for (out, 0..) |*t, i| {
                if (mask & (@as(u32, 1) << @intCast(i)) == 0) continue;
                t.addContribution(st, e.main, e.one_trick, e.others);
            }
        }
    }

    /// learning.zig's points bin for each player and champion of a game after the
    /// player's mastery fetch (`rows`: masteryTallies' contributions, in key order), into
    /// s.learning: from learning.bin when the row's rowid and fetch time match, the rest
    /// decoded from db
    fn learningBins(s: *Store, db: store.Db, st: *const core.Stats, rows: []const Contribution) !void {
        const gpa = s.gpa;
        var work: std.heap.ArenaAllocator = .init(gpa);
        defer work.deinit();
        const wa = work.allocator();
        const Need = struct { row: u32, champion: u16, bin: u8 = unknown };
        var needs: std.ArrayList(Need) = .empty;
        for (s.sorted) |g| for (g.players) |p| {
            const k = p.puuid orelse continue;
            const row = findRow(rows, k) orelse continue;
            if (rows[row].fetched_at == 0 or !learning.after(rows[row].fetched_at, g.start)) continue;
            const champion = std.math.cast(u16, p.champion) orelse continue;
            if (st.index(champion) == null) continue;
            try needs.append(wa, .{ .row = @intCast(row), .champion = champion });
        };
        std.mem.sort(Need, needs.items, {}, struct {
            fn f(_: void, a: Need, b: Need) bool {
                return if (a.row != b.row) a.row < b.row else a.champion < b.champion;
            }
        }.f);
        var n: usize = 0;
        for (needs.items) |x| {
            if (n > 0 and needs.items[n - 1].row == x.row and needs.items[n - 1].champion == x.champion) continue;
            needs.items[n] = x;
            n += 1;
        }
        const pairs = needs.items[0..n];

        const file = try s.path("learning.bin", .{});
        defer gpa.free(file);
        const CacheKey = struct { rowid: i64, fetched_at: i64, champion: u16 };
        var cached: std.AutoHashMapUnmanaged(CacheKey, u8) = .empty;
        if (try readIn(s.io, gpa, wa, LearningFile, file)) |f| if (f.key == learningKey()) {
            for (f.entries) |e| try cached.put(wa, .{ .rowid = e.rowid, .fetched_at = e.fetched_at, .champion = e.champion }, e.bin);
        };
        for (pairs) |*x| {
            const r = rows[x.row];
            x.bin = cached.get(.{ .rowid = r.rowid, .fetched_at = r.fetched_at, .champion = x.champion }) orelse unknown;
        }

        // Rows with a pair still unknown, in rowid order: the table's, so the reads walk it once
        var missing: std.ArrayList(u32) = .empty;
        for (pairs) |x| {
            if (x.bin != unknown) continue;
            if (missing.items.len > 0 and missing.items[missing.items.len - 1] == x.row) continue;
            try missing.append(wa, x.row);
        }
        std.mem.sort(u32, missing.items, rows, struct {
            fn f(r: []const Contribution, a: u32, b: u32) bool {
                return r[a].rowid < r[b].rowid;
            }
        }.f);
        s.counts.learning = pairs.len;
        s.counts.learning_read = missing.items.len;
        {
            var q = try db.prepare("SELECT data, fetched_at FROM mastery WHERE rowid = ?");
            defer q.deinit();
            var scratch: std.heap.ArenaAllocator = .init(gpa);
            defer scratch.deinit();
            for (missing.items) |row| {
                try q.bind(.{rows[row].rowid});
                defer q.reset();
                if (!try q.step()) continue;
                _ = scratch.reset(.retain_capacity);
                const r = q.row(struct { data: []const u8, fetched_at: i64 });
                if (r.fetched_at != rows[row].fetched_at) continue;
                const entries = riot_mastery.decode(scratch.allocator(), r.data, r.fetched_at) catch continue;
                // pairs is in row order: this row's are together
                var lo: usize = 0;
                var hi: usize = pairs.len;
                while (lo < hi) {
                    const mid = lo + (hi - lo) / 2;
                    if (pairs[mid].row < row) lo = mid + 1 else hi = mid;
                }
                while (lo < pairs.len and pairs[lo].row == row) : (lo += 1) {
                    pairs[lo].bin = @intCast(learning.binIn(entries, pairs[lo].champion));
                }
            }
        }

        var keep: std.ArrayList(Cached) = .empty;
        var out: std.AutoHashMapUnmanaged(Pair, PairBin) = .empty;
        errdefer out.deinit(gpa);
        try out.ensureTotalCapacity(gpa, @intCast(pairs.len));
        for (pairs) |x| {
            if (x.bin == unknown) continue;
            const r = rows[x.row];
            try keep.append(wa, .{ .rowid = r.rowid, .fetched_at = r.fetched_at, .champion = x.champion, .bin = x.bin });
            out.putAssumeCapacity(.{ .key = r.key, .champion = x.champion }, .{ .fetched_at = r.fetched_at, .bin = x.bin });
        }
        try writeIn(s.io, file, LearningFile{ .key = learningKey(), .entries = keep.items });
        if (s.learning) |*l| l.deinit(gpa);
        s.learning = out;
    }

    const unknown = std.math.maxInt(u8);

    fn findRow(rows: []const Contribution, k: Key) ?usize {
        var lo: usize = 0;
        var hi: usize = rows.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (rows[mid].key.lessThan(k)) lo = mid + 1 else hi = mid;
        }
        return if (lo < rows.len and rows[lo].key.eql(k)) lo else null;
    }

    /// Into `banned`, games each champion was banned in (once a game) on `patches` and
    /// `platforms` from `since_ms`, remakes out and games without a winner in (as the
    /// site's champion list counts them)
    pub fn bansIn(s: *const Store, a: Allocator, banned: *std.AutoHashMapUnmanaged(u32, u32), patches_in: []const []const u8, platforms: []const []const u8, since_ms: i64) !void {
        const patch_on = try s.codesIn(a, patches_in);
        const platform_on = try s.codesIn(a, platforms);
        for (s.sorted) |g| {
            if (!patch_on[g.patch] or !platform_on[g.platform] or g.start < since_ms) continue;
            for (g.bans, 0..) |b, i| {
                const champion = std.math.cast(u32, b.champion) orelse return error.Unrepresentable;
                const twice = for (g.bans[0..i]) |o| {
                    if (o.champion == b.champion) break true;
                } else false;
                if (twice) continue;
                (try banned.getOrPutValue(a, champion, 0)).value_ptr.* += 1;
            }
        }
    }

    /// stats.patches from the files: patches with ranked solo games (remakes too) on
    /// `platforms`, newest first; in `gpa`
    pub fn patches(s: *const Store, gpa: Allocator, platforms: []const []const u8) ![][]const u8 {
        const on = try s.codesIn(gpa, platforms);
        defer gpa.free(on);
        const have = try gpa.alloc(bool, s.strings.count() + 1);
        defer gpa.free(have);
        @memset(have, false);
        for (s.days.values()) |day| {
            for (day.games.items) |g| {
                if (on[g.platform]) have[g.patch] = true;
            }
            for (day.others.items) |o| {
                if (o.queue == ranked_solo and on[o.platform]) have[o.patch] = true;
            }
        }
        var list: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (list.items) |p| gpa.free(p);
            list.deinit(gpa);
        }
        for (have[1..], 1..) |h, code| {
            if (h) try list.append(gpa, try gpa.dupe(u8, s.string(@intCast(code)).?));
        }
        // As SQLite's DISTINCT walks the patch index: text order, then stats' sort
        std.mem.sort([]const u8, list.items, {}, struct {
            fn f(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.f);
        stats.sortPatches(list.items);
        return list.toOwnedSlice(gpa);
    }
};

/// `meiolol forget`: the players' keys blanked in every day file and their mastery
/// contributions dropped, under the lock (a views write running finishes first). A
/// missing directory has nothing to scrub
pub fn forget(gpa: Allocator, io: std.Io, dir: []const u8, puuids: []const []const u8) !usize {
    std.Io.Dir.cwd().access(io, dir, .{}) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    const s = try Store.openLocked(gpa, io, dir);
    defer s.deinit();
    try s.loadDays();
    var gone: std.AutoHashMapUnmanaged(Key, void) = .empty;
    defer gone.deinit(gpa);
    for (puuids) |p| try gone.put(gpa, key(p), {});
    var n = try s.blank(&gone);
    try s.save();
    const file = try s.path("mastery.bin", .{});
    defer gpa.free(file);
    if (try s.readFile(MasteryFile, file)) |m| {
        var kept: std.ArrayList(Contribution) = .empty;
        for (m.entries) |e| {
            if (gone.contains(e.key)) {
                n += 1;
            } else try kept.append(s.arena(), e);
        }
        if (kept.items.len != m.entries.len) {
            try s.writeFile(file, MasteryFile{ .champs_key = m.champs_key, .strings = m.strings, .entries = kept.items });
        }
    }
    return n;
}

/// Rows of the files that hold `puuid`'s key (day files' players, mastery entries):
/// forget's check
pub fn mentions(gpa: Allocator, io: std.Io, dir: []const u8, puuid: []const u8) !usize {
    const s = try Store.openLocked(gpa, io, dir);
    defer s.deinit();
    try s.loadDays();
    const k = key(puuid);
    var n: usize = 0;
    for (s.days.values()) |day| for (day.games.items) |g| for (g.players) |p| {
        if (p.puuid) |q| n += @intFromBool(q.eql(k));
    };
    const file = try s.path("mastery.bin", .{});
    defer gpa.free(file);
    if (try s.readFile(MasteryFile, file)) |m| for (m.entries) |e| {
        n += @intFromBool(e.key.eql(k));
    };
    return n;
}

/// One line per game, strings spelt out: stores compared whatever their string codes
pub fn dump(s: *const Store, w: *std.Io.Writer) !void {
    for (s.sorted) |g| {
        try w.print("{s} {d} {d} {d} {d} {?d} {?s} {?s}\n", .{ g.id, g.rowid, g.timeline, g.start, g.duration_s, g.winning_team, s.string(g.platform), s.string(g.patch) });
        for (g.players) |p| try w.print(" {d} {d} {d} {?s} {?s} {} {?x} {?x} {?d} {}\n", .{
            p.slot,                          p.team,                          p.champion, s.string(p.position), s.string(p.tier), p.win,
            if (p.puuid) |k| k.lo else null, if (p.puuid) |k| k.hi else null, p.gold14,   p.gold15,
        });
        for (g.bans) |b| try w.print(" ban {d} {d}\n", .{ b.team, b.champion });
    }
}

const testing = std.testing;

test key {
    try testing.expect(!key("a").eql(key("b")));
    try testing.expect(key("puuid-1").eql(key("puuid-1")));
}
