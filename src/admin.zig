//! `meiolol admin`: private ops page (crawl rates, storage growth, ingest mix, queues,
//! model accuracy, site uploads) as one static page plus admin.js, which draws the
//! charts. The box rebuilds it every 15 min with the site (deploy/web-loop.sh); nginx
//! serves it at /admin/ behind the /api/ basic auth. Aggregates only: no PUUIDs, Riot
//! IDs or match ids (log messages are normalised before they are counted).

const std = @import("std");
const store = @import("store");
const date = @import("date.zig");
const ep = @import("riot/endpoints.zig");
const Limiter = @import("riot/ratelimit.zig").Limiter;

const Io = std.Io;
const Region = ep.Region;
const regions = std.enums.values(Region);

pub const Options = struct {
    out_dir: []const u8,
    data_dir: []const u8,
    /// The crawler's log, read from its last `log_tail` bytes
    crawl_log: []const u8,
    /// Days of crawl and upload history shown
    days: u32 = 7,
    now_s: i64,
    /// `df -B1 --output=size,used,avail` of the data disk, as the web loop passes it
    disk: ?[3]u64 = null,
    /// deploy/health.sh output: one problem per line, empty when all is well
    health: ?[]const u8 = null,
    /// Default: backups beside the data directory (ml/meiolol/backups on the box,
    /// MEIOLOL_BACKUPS there)
    backups_dir: ?[]const u8 = null,
    /// The crawler's arguments (deploy/box.sh start); default: crawl.args beside the
    /// data directory
    crawl_args: ?[]const u8 = null,
};

const log_tail = 32 << 20;
const bucket_s = 600;
/// Ladder of the ingest mix: the newest draft rows, by insertion
const draft_tail = 1_000_000;
/// TSV lines of history kept on the page: 30 days at one per 15 min
const history_lines = 2880;
const eval_report_max = 256 << 10;

/// Crawl log lines that are not report lines, by what they say
const Kind = enum { rate_limit, riot_server, db_busy, network, other };

const Bucket = struct {
    /// Seconds of crawler reports in this bucket; 0 = not running
    covered: u32 = 0,
    /// Per region: matches, timelines, match id calls, requests
    m: [regions.len]u32 = @splat(0),
    t: [regions.len]u32 = @splat(0),
    ids: [regions.len]u32 = @splat(0),
    req: [regions.len]u32 = @splat(0),
    ladder: u32 = 0,
    mastery: u32 = 0,
    platform_req: u32 = 0,
    jobs: u32 = 0,
    commits: u32 = 0,
    pages_written: u64 = 0,
    pages_read: u64 = 0,
    queued_max: u32 = 0,
    warnings: [std.enums.values(Kind).len]u32 = @splat(0),
};

/// One crawler report line's cumulative counters
const Report = struct {
    m: [regions.len]u64 = @splat(0),
    t: [regions.len]u64 = @splat(0),
    ids: [regions.len]u64 = @splat(0),
    req: [regions.len]u64 = @splat(0),
    ladder: u64 = 0,
    mastery: u64 = 0,
    platform_req: u64 = 0,
    jobs: u64 = 0,
    commits: u64 = 0,
    queued: u64 = 0,
    pages_written: u64 = 0,
    pages_read: u64 = 0,
};

const Message = struct { text: []const u8, kind: Kind, count: u32, last: i64 };

const Crawl = struct {
    start: i64,
    step: u32 = bucket_s,
    regions: []const Region = regions,
    kinds: []const Kind = std.enums.values(Kind),
    buckets: []Bucket,
    /// Crawler starts in the window
    restarts: []const i64,
    /// Normalised warnings of the last day, most frequent first
    messages: []const Message,
    /// Last report line's time
    last_report: ?i64,
};

pub fn generate(gpa: std.mem.Allocator, io: Io, db: store.Db, o: Options) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cwd = Io.Dir.cwd();

    const counts = try tableCounts(arena, db);
    const files = try fileSizes(arena, io, o.data_dir);
    const history_path = try std.fs.path.join(arena, &.{ o.data_dir, "admin-history.tsv" });
    try appendHistory(io, history_path, o, counts, files);

    const window_start = o.now_s - @as(i64, o.days) * 86400;
    var key_problems: std.ArrayList(KeyProblem) = .empty;
    const crawl = try crawlSeries(arena, io, o.crawl_log, window_start, o.now_s, bucket_s, log_tail, &key_problems);
    const kp = key_problems.items;
    const page = .{
        .now = o.now_s,
        .days = o.days,
        .health = o.health,
        .disk = o.disk,
        .platforms = ep.platforms,
        .files = files,
        .counts = counts,
        .queues = .{
            .match = try groups(arena, db, "SELECT status, count(*) FROM match_queue GROUP BY 1 ORDER BY 2 DESC"),
            .timeline = try groups(arena, db, "SELECT region || ' ' || status, count(*) FROM timeline_queue GROUP BY 1 ORDER BY 1"),
        },
        .players = try groups(arena, db, "SELECT coalesce(region, '?'), count(*) FROM players GROUP BY 1 ORDER BY 2 DESC"),
        .ladder = try ladderTiers(arena, db),
        .by_patch = try groups(arena, db, "SELECT patch, count(*) FROM matches GROUP BY 1 ORDER BY 1 DESC LIMIT 8"),
        .drafts = try draftMix(arena, db),
        .crawl = crawl,
        .history = try tail(arena, io, history_path, history_lines),
        .eval = try tail(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "eval-history.tsv" }), 400),
        .uploads = try uploads(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "web.log" }), window_start),
        .deploys = try tail(arena, io, "DEPLOYED", 15),
        .logs = .{
            .health = try tail(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "health.log" }), 12),
            .backup = try tail(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "backup.log" }), 6),
            .builds = try tail(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "builds.log" }), 6),
        },
        .eval_report = try readHead(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "eval-latest.md" }), eval_report_max),
        .storage = try storage(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "storage.tsv" })),
        .backups = try backups(arena, io, o.backups_dir orelse try std.fs.path.join(arena, &.{ o.data_dir, "..", "backups" })),
        .riot = .{
            .app_limit = Limiter.app_default,
            // None seeded: the limiter learns them from Riot's headers
            .method_limits = struct {}{},
            .crawl_args = std.mem.trim(u8, try readHead(arena, io, o.crawl_args orelse
                try std.fs.path.join(arena, &.{ o.data_dir, "..", "crawl.args" }), 4096) orelse "", " \n"),
            .key_problems = kp[kp.len -| 50..],
        },
    };
    const json = try std.json.Stringify.valueAlloc(arena, page, .{});
    // Inside <script>: "</" would end it early
    const safe = try std.mem.replaceOwned(u8, arena, json, "</", "<\\/");

    var out: Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try w.writeAll(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="robots" content="noindex">
        \\<title>meiolol admin</title>
        \\<link rel="stylesheet" href="admin.css">
        \\</head>
        \\<body>
        \\<main id="app"><p>Loading…</p></main>
        \\<script id="data" type="application/json">
    );
    try w.writeAll(safe);
    try w.writeAll(
        \\</script>
        \\<script src="admin.js"></script>
        \\</body>
        \\</html>
        \\
    );
    try cwd.createDirPath(io, o.out_dir);
    var dir = try cwd.openDir(io, o.out_dir, .{});
    defer dir.close(io);
    try writeGz(gpa, io, dir, "index.html", out.written());
    // The same data for the page to poll between rebuilds
    try writeGz(gpa, io, dir, "data.json", json);
    try writeGz(gpa, io, dir, "admin.js", @embedFile("site/static/admin.js"));
    try writeGz(gpa, io, dir, "admin.css", @embedFile("site/static/admin.css"));
}

/// Also `path`.gz, as the site's pages (nginx gzip_static)
fn writeGz(gpa: std.mem.Allocator, io: Io, dir: Io.Dir, path: []const u8, data: []const u8) !void {
    try dir.writeFile(io, .{ .sub_path = path, .data = data });
    const gz = try store.raw.compress(gpa, data);
    defer gpa.free(gz);
    var buf: [64]u8 = undefined;
    try dir.writeFile(io, .{ .sub_path = try std.mem.print(&buf, "{s}.gz", .{path}), .data = gz });
}

const Count = struct { name: []const u8, rows: i64 };

/// As `meiolol status`; a few seconds on the box, mostly players
const tables = [_][]const u8{
    "players",        "ranks",              "ladder_pages", "match_queue",
    "matches",        "participants",       "bans",         "mastery",
    "timeline_queue", "timeline.timelines", "raw.raw_docs", "raw.timeline_docs",
    "drafts",         "draft_backfill",     "forgotten",
};

fn tableCounts(arena: std.mem.Allocator, db: store.Db) ![]Count {
    const out = try arena.alloc(Count, tables.len);
    inline for (tables, out) |t, *c| {
        c.* = .{ .name = t, .rows = try db.scalar("SELECT count(*) FROM " ++ t, .{}) orelse 0 };
    }
    return out;
}

fn count(counts: []const Count, name: []const u8) i64 {
    for (counts) |c| if (std.mem.eql(u8, c.name, name)) return c.rows;
    return 0;
}

const FileSize = struct { name: []const u8, bytes: u64 };

/// Each database with its WAL
fn fileSizes(arena: std.mem.Allocator, io: Io, data_dir: []const u8) ![]FileSize {
    const names = [_][]const u8{ "meiolol.db", "timeline.db", "raw.db" };
    const out = try arena.alloc(FileSize, names.len);
    for (names, out) |n, *f| {
        f.* = .{ .name = n, .bytes = 0 };
        for ([_][]const u8{ "", "-wal" }) |suffix| {
            const path = try arena.print("{s}/{s}{s}", .{ data_dir, n, suffix });
            const st = Io.Dir.cwd().statFile(io, path, .{}) catch continue;
            f.bytes += st.size;
        }
    }
    return out;
}

const history_header = "time\tmeiolol_db\ttimeline_db\traw_db\tdisk_used\tdisk_size\tplayers\tranks" ++
    "\tmatches\ttimelines\tdrafts\tmatch_queue\ttimeline_queue\tmastery\n";

fn appendHistory(io: Io, path: []const u8, o: Options, counts: []const Count, files: []const FileSize) !void {
    var file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = false });
    defer file.close(io);
    const len = try file.length(io);
    var buf: [1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.seekTo(len);
    const w = &fw.interface;
    if (len == 0) try w.writeAll(history_header);
    try w.print("{d}", .{o.now_s});
    for (files) |f| try w.print("\t{d}", .{f.bytes});
    if (o.disk) |d| try w.print("\t{d}\t{d}", .{ d[1], d[0] }) else try w.writeAll("\t\t");
    for ([_][]const u8{ "players", "ranks", "matches", "timeline.timelines", "drafts", "match_queue", "timeline_queue", "mastery" }) |t| {
        try w.print("\t{d}", .{count(counts, t)});
    }
    try w.writeAll("\n");
    try w.flush();
}

const Group = struct { key: []const u8, n: i64 };

fn groups(arena: std.mem.Allocator, db: store.Db, sql: []const u8) ![]Group {
    var q = try db.prepare(sql);
    defer q.deinit();
    var out: std.ArrayList(Group) = .empty;
    while (try q.step()) {
        const r = q.row(Group);
        try out.append(arena, .{ .key = try arena.dupe(u8, r.key), .n = r.n });
    }
    return out.items;
}

/// Ranked players on the ladder, by tier (ranks: every player a ladder page showed)
fn ladderTiers(arena: std.mem.Allocator, db: store.Db) ![]Group {
    var q = try db.prepare("SELECT rank / 4, count(*) FROM ranks GROUP BY 1 ORDER BY 1");
    defer q.deinit();
    var out: std.ArrayList(Group) = .empty;
    while (try q.step()) {
        const g = q.row(struct { tier: i64, n: i64 });
        const r = store.schema.unpackRank(g.tier * 4) orelse continue;
        try out.append(arena, .{ .key = r.tier, .n = g.n });
    }
    return out.items;
}

const DraftMix = struct {
    rows: u64 = 0,
    /// First and last unix day among them
    days: []const DayRow = &.{},
    platforms: []const Group = &.{},
    patches: []const Group = &.{},
    /// schema.tiers order, then unknown
    tiers: [store.schema.tiers.len + 1]u64 = @splat(0),
    blue_wins: u64 = 0,
    /// Game length histogram, 5-minute bins from 0 (last: 60+)
    minutes: [13]u64 = @splat(0),
};
const DayRow = struct { day: i64, region: [regions.len]u64 };

/// Complete ranked games (drafts rows) of the newest `draft_tail` stored: by game day
/// and region, platform, patch, rank, side and length
fn draftMix(arena: std.mem.Allocator, db: store.Db) !DraftMix {
    var q = try db.prepare(
        \\SELECT day, platform, patch, rank, blue_win, minutes FROM drafts
        \\WHERE id > (SELECT coalesce(max(id), 0) FROM drafts) - ?
    );
    defer q.deinit();
    try q.bind(.{@as(i64, draft_tail)});
    var mix: DraftMix = .{};
    var days: std.AutoArrayHashMapUnmanaged(i64, [regions.len]u64) = .empty;
    var platforms: std.StringArrayHashMapUnmanaged(i64) = .empty;
    var patches: std.StringArrayHashMapUnmanaged(i64) = .empty;
    while (try q.step()) {
        const row = q.row(struct {
            day: i64,
            platform: []const u8,
            patch: []const u8,
            rank: ?i64,
            blue_win: u64,
            minutes: ?i64,
        });
        mix.rows += 1;
        const p = try platforms.getOrPut(arena, row.platform);
        if (!p.found_existing) {
            p.key_ptr.* = try arena.dupe(u8, row.platform);
            p.value_ptr.* = 0;
        }
        p.value_ptr.* += 1;
        const pt = try patches.getOrPut(arena, row.patch);
        if (!pt.found_existing) {
            pt.key_ptr.* = try arena.dupe(u8, row.patch);
            pt.value_ptr.* = 0;
        }
        pt.value_ptr.* += 1;
        if (ep.platform(row.platform)) |pl| {
            const d = try days.getOrPut(arena, row.day);
            if (!d.found_existing) d.value_ptr.* = @splat(0);
            d.value_ptr[@backingInt(pl.region)] += 1;
        }
        const tier: usize = if (row.rank) |r| @min(@as(usize, @intCast(@max(r, 0))) / 4, store.schema.tiers.len) else store.schema.tiers.len;
        mix.tiers[tier] += 1;
        mix.blue_wins += row.blue_win;
        if (row.minutes) |m| mix.minutes[@min(@as(usize, @intCast(@max(m, 0))) / 5, mix.minutes.len - 1)] += 1;
    }
    const day_rows = try arena.alloc(DayRow, days.count());
    for (days.keys(), days.values(), day_rows) |d, v, *r| r.* = .{ .day = d, .region = v };
    std.mem.sort(DayRow, day_rows, {}, struct {
        fn lt(_: void, a: DayRow, b: DayRow) bool {
            return a.day < b.day;
        }
    }.lt);
    mix.days = day_rows;
    mix.platforms = try sorted(arena, platforms);
    mix.patches = try sorted(arena, patches);
    return mix;
}

fn sorted(arena: std.mem.Allocator, m: std.StringArrayHashMapUnmanaged(i64)) ![]Group {
    const out = try arena.alloc(Group, m.count());
    for (m.keys(), m.values(), out) |k, v, *g| g.* = .{ .key = k, .n = v };
    std.mem.sort(Group, out, {}, struct {
        fn gt(_: void, a: Group, b: Group) bool {
            return a.n > b.n;
        }
    }.gt);
    return out;
}

/// The last `n` lines of a text file, "" when it is missing
fn tail(arena: std.mem.Allocator, io: Io, path: []const u8, n: usize) ![]const u8 {
    const text = try readTail(arena, io, path, 4 << 20);
    var lines: usize = 0;
    var i = std.mem.trimEnd(u8, text, "\n").len;
    while (i > 0) : (i -= 1) {
        if (text[i - 1] == '\n') {
            lines += 1;
            if (lines == n) break;
        }
    }
    if (i > 0 and isTsv(text)) {
        const header = text[0 .. std.mem.indexOfScalar(u8, text, '\n').? + 1];
        return std.mem.concat(arena, u8, &.{ header, text[i..] });
    }
    return text[i..];
}

/// The TSVs this page reads start with a header naming their time column
fn isTsv(text: []const u8) bool {
    return std.mem.startsWith(u8, text, "time\t") or std.mem.startsWith(u8, text, "date\t");
}

/// Up to the last `max` bytes, from the start of a line; the whole file when smaller
fn readTail(arena: std.mem.Allocator, io: Io, path: []const u8, max: u64) ![]const u8 {
    var file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return "",
        else => return err,
    };
    defer file.close(io);
    const len = try file.length(io);
    const from = len -| max;
    const buf = try arena.alloc(u8, @intCast(len - from));
    const got = try file.readPositionalAll(io, buf, from);
    var text = buf[0..got];
    if (from > 0) {
        // A large TSV: its header from the start
        var head: [512]u8 = undefined;
        const h = try file.readPositionalAll(io, &head, 0);
        const nl = std.mem.indexOfScalar(u8, text, '\n') orelse return "";
        text = text[nl + 1 ..];
        if (std.mem.indexOfScalar(u8, head[0..h], '\n')) |e| {
            if (isTsv(head[0..h])) return std.mem.concat(arena, u8, &.{ head[0 .. e + 1], text });
        }
    }
    return text;
}

/// The first `max` bytes of a file; null when it is missing
fn readHead(arena: std.mem.Allocator, io: Io, path: []const u8, max: usize) !?[]const u8 {
    var file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(io);
    const buf = try arena.alloc(u8, @intCast(@min(try file.length(io), max)));
    return buf[0..try file.readPositionalAll(io, buf, 0)];
}

const Storage = struct {
    /// The scan's time (the file's)
    generated: i64,
    /// db, table or index name, kind, bytes, cells
    rows: []const struct { []const u8, []const u8, []const u8, u64, u64 },
};

/// deploy/web-loop.sh's daily dbstat scan (data/storage.tsv); null before the first
fn storage(arena: std.mem.Allocator, io: Io, path: []const u8) !?Storage {
    const text = try readHead(arena, io, path, 4 << 20) orelse return null;
    const st = try Io.Dir.cwd().statFile(io, path, .{});
    var rows: std.ArrayList(@typeInfo(@FieldType(Storage, "rows")).pointer.child) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var f = std.mem.splitScalar(u8, line, '\t');
        const db = f.next() orelse continue;
        const name = f.next() orelse continue;
        const kind = f.next() orelse continue;
        const bytes = std.fmt.parseInt(u64, f.next() orelse continue, 10) catch continue;
        const cells = std.fmt.parseInt(u64, f.next() orelse continue, 10) catch continue;
        try rows.append(arena, .{ db, name, kind, bytes, cells });
    }
    return .{ .generated = st.mtime.toSeconds(), .rows = rows.items };
}

const Backups = struct { bytes: u64, files: u64, newest: i64 };

/// Every file under the backups directory; null when there is none
fn backups(arena: std.mem.Allocator, io: Io, path: []const u8) !?Backups {
    var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return null,
        else => return err,
    };
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    var b: Backups = .{ .bytes = 0, .files = 0, .newest = 0 };
    while (try walker.next(io)) |e| {
        if (e.kind != .file) continue;
        const st = e.dir.statFile(io, e.basename, .{}) catch continue;
        b.bytes += st.size;
        b.files += 1;
        b.newest = @max(b.newest, st.mtime.toSeconds());
    }
    return b;
}

/// systemctl --user is-active, by unit (deploy/systemd)
pub const Services = struct {
    @"meiolol-crawl": []const u8 = "unknown",
    @"meiolol-web": []const u8 = "unknown",
    @"meiolol-render@a": []const u8 = "unknown",
    @"meiolol-render@b": []const u8 = "unknown",
    @"meiolol-backup": []const u8 = "unknown",
    @"meiolol-health": []const u8 = "unknown",
};

pub const RunningAction = struct { name: []const u8, since: i64 };

/// What the admin API (admin_api.zig) found out by running commands
pub const Live = struct {
    data_dir: []const u8,
    now_s: i64,
    services: Services = .{},
    health: []const u8 = "",
    disk: ?[3]u64 = null,
    /// Start of a running `meiolol eval`
    eval_since: ?i64 = null,
    action: ?RunningAction = null,
};

const live_window_s = 3 * 3600;
const live_step_s = 60;

/// /admin/api/live.json: the crawler's last 3 h by minute, queues, files and the admin
/// actions, with `l`'s command results. `db` read-only
pub fn liveJson(arena: std.mem.Allocator, io: Io, db: store.Db, l: Live) ![]const u8 {
    const crawl_log = try std.fs.path.join(arena, &.{ l.data_dir, "crawl.log" });
    const live = .{
        .now = l.now_s,
        .services = l.services,
        .health = l.health,
        .crawl = try crawlSeries(arena, io, crawl_log, l.now_s - live_window_s, l.now_s, live_step_s, 4 << 20, null),
        .queues = .{
            .match = try groups(arena, db, "SELECT status, count(*) FROM match_queue GROUP BY 1 ORDER BY 2 DESC"),
            .timeline = try groups(arena, db, "SELECT region || ' ' || status, count(*) FROM timeline_queue GROUP BY 1 ORDER BY 1"),
        },
        .disk = l.disk,
        .files = try fileSizes(arena, io, l.data_dir),
        .actions = try actionLog(arena, io, try std.fs.path.join(arena, &.{ l.data_dir, action_log })),
        .running = .{ .eval = l.eval_since, .action = l.action },
    };
    return std.json.Stringify.valueAlloc(arena, live, .{});
}

/// Admin actions, one per line: ISO time, name, ok|failed|refused, output's start
pub const action_log = "admin-actions.log";

const ActionEntry = struct { i64, []const u8, []const u8, []const u8 };

/// The last 20, newest last
fn actionLog(arena: std.mem.Allocator, io: Io, path: []const u8) ![]const ActionEntry {
    const text = try tail(arena, io, path, 20);
    var out: std.ArrayList(ActionEntry) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        var f = std.mem.splitScalar(u8, line, '\t');
        const t = stamp(f.next() orelse continue) orelse continue;
        const name = f.next() orelse continue;
        const result = f.next() orelse continue;
        try out.append(arena, .{ t, name, result, f.rest() });
    }
    return out.items;
}

/// A log line for the admin page's log viewer: as written, numbers and times kept, but
/// id-like words (PUUIDs, match ids like EUW1_7123456) and Riot IDs (name#tag) to …
pub fn redact(arena: std.mem.Allocator, line: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < line.len) {
        if (!isWordChar(line[i])) {
            try out.append(arena, line[i]);
            i += 1;
            continue;
        }
        var e = i;
        var digits = false;
        while (e < line.len and isWordChar(line[e])) : (e += 1) digits = digits or std.ascii.isDigit(line[e]);
        // name#tag: both sides, the tag letters or digits
        if (e + 1 < line.len and line[e] == '#' and isWordChar(line[e + 1])) {
            e += 1;
            while (e < line.len and isWordChar(line[e])) e += 1;
            try out.appendSlice(arena, "…");
        } else if (e - i >= 20 or (digits and std.mem.indexOfScalar(u8, line[i..e], '_') != null)) {
            try out.appendSlice(arena, "…");
        } else try out.appendSlice(arena, line[i..e]);
        i = e;
    }
    return out.items;
}

fn isWordChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '-';
}

/// "2026-10-11 23:07:21 ..." or "2026-10-11T23:07:21Z ..." to unix seconds
fn stamp(line: []const u8) ?i64 {
    if (line.len < 19) return null;
    const d = date.Date.parse(line[0..10]) orelse return null;
    if (line[10] != ' ' and line[10] != 'T') return null;
    if (line[13] != ':' or line[16] != ':') return null;
    const h = std.fmt.parseInt(i64, line[11..13], 10) catch return null;
    const m = std.fmt.parseInt(i64, line[14..16], 10) catch return null;
    const s = std.fmt.parseInt(i64, line[17..19], 10) catch return null;
    return d.toDay() * 86400 + h * 3600 + m * 60 + s;
}

/// Riot refused the key: the client's 401/403 line, or the crawl unit's "KEY REJECTED"
/// (exit 3, no time of its own: the line before's)
const KeyProblem = struct { i64, []const u8 };

/// `step`-second buckets from the last `max_bytes` of the log; key problems in the window
/// into `key_problems` when given
fn crawlSeries(
    arena: std.mem.Allocator,
    io: Io,
    path: []const u8,
    from: i64,
    now: i64,
    step: u32,
    max_bytes: u64,
    key_problems: ?*std.ArrayList(KeyProblem),
) !Crawl {
    const start = @divFloor(from, step) * step;
    const n_buckets: usize = @intCast(@divFloor(now - start, step) + 1);
    const buckets = try arena.alloc(Bucket, n_buckets);
    @memset(buckets, .{});
    var restarts: std.ArrayList(i64) = .empty;
    var messages: std.StringArrayHashMapUnmanaged(Message) = .empty;
    var prev: ?struct { t: i64, r: Report } = null;
    var last_report: ?i64 = null;
    var last_t: ?i64 = null;

    const text = try readTail(arena, io, path, max_bytes);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const t = stamp(line) orelse {
            if (key_problems) |kp| if (last_t) |lt| if (std.mem.eql(u8, line, "KEY REJECTED")) {
                try kp.append(arena, .{ lt, "KEY REJECTED" });
            };
            continue;
        };
        if (t < start or t > now) {
            last_t = null;
            continue;
        }
        last_t = t;
        if (line.len < 20) continue;
        const b = &buckets[@intCast(@divFloor(t - start, step))];
        const rest = line[20..];
        if (parseReport(rest)) |r| {
            last_report = t;
            if (prev) |p| {
                // Counters are per process: a drop is a restart, counting from zero
                const base = if (r.jobs < p.r.jobs or r.commits < p.r.commits) Report{} else p.r;
                b.covered += @intCast(@min(t - p.t, 120));
                add(b, base, r);
            }
            prev = .{ .t = t, .r = r };
        } else if (std.mem.indexOf(u8, rest, "workers for") != null or std.mem.indexOf(u8, rest, "threads for") != null) {
            try restarts.append(arena, t);
            prev = .{ .t = t, .r = .{} };
        } else if (std.mem.startsWith(u8, rest, "warning(") or std.mem.startsWith(u8, rest, "error(")) {
            const msg = try normalise(arena, rest);
            if (key_problems) |kp| if (std.mem.indexOf(u8, msg, "key missing or expired") != null) {
                try kp.append(arena, .{ t, msg });
            };
            const kind = classify(msg);
            b.warnings[@backingInt(kind)] += 1;
            if (t >= now - 86400) {
                const e = try messages.getOrPut(arena, msg);
                if (!e.found_existing) e.value_ptr.* = .{ .text = msg, .kind = kind, .count = 0, .last = t };
                e.value_ptr.count += 1;
                e.value_ptr.last = t;
            }
        }
    }
    const msgs = messages.values();
    std.mem.sort(Message, msgs, {}, struct {
        fn gt(_: void, a: Message, b: Message) bool {
            return a.count > b.count;
        }
    }.gt);
    return .{
        .start = start,
        .step = step,
        .buckets = buckets,
        .restarts = restarts.items,
        .messages = msgs[0..@min(msgs.len, 20)],
        .last_report = last_report,
    };
}

fn add(b: *Bucket, from: Report, to: Report) void {
    const d = struct {
        fn f(x: u64, y: u64) u32 {
            return @intCast(@min(y -| x, std.math.maxInt(u32)));
        }
    }.f;
    for (0..regions.len) |i| {
        b.m[i] += d(from.m[i], to.m[i]);
        b.t[i] += d(from.t[i], to.t[i]);
        b.ids[i] += d(from.ids[i], to.ids[i]);
        b.req[i] += d(from.req[i], to.req[i]);
    }
    b.ladder += d(from.ladder, to.ladder);
    b.mastery += d(from.mastery, to.mastery);
    b.platform_req += d(from.platform_req, to.platform_req);
    b.jobs += d(from.jobs, to.jobs);
    b.commits += d(from.commits, to.commits);
    b.pages_written += to.pages_written -| from.pages_written;
    b.pages_read += to.pages_read -| from.pages_read;
    b.queued_max = @max(b.queued_max, @as(u32, @intCast(@min(to.queued, std.math.maxInt(u32)))));
}

/// The crawler's minute line (riot/crawl.zig report()), after the timestamp:
/// "info(crawl): 160216 matches/day | ladder pages 180 | mastery 0 | platform req 180 |
/// americas 3978m 2160t 483ids 6593req | ... | writes 28138 in 3921 commits, 4 queued,
/// 0 busy | pages written 626229, read 454155"
fn parseReport(line: []const u8) ?Report {
    if (!std.mem.startsWith(u8, line, "info(crawl): ") or std.mem.indexOf(u8, line, " matches/day | ") == null) return null;
    var r: Report = .{};
    var parts = std.mem.splitSequence(u8, line, " | ");
    _ = parts.next();
    while (parts.next()) |part| {
        var words = std.mem.tokenizeAny(u8, part, " ,");
        const first = words.next() orelse continue;
        if (std.meta.stringToEnum(Region, first)) |region| {
            const i = @backingInt(region);
            while (words.next()) |word| {
                const digits = std.mem.indexOfNone(u8, word, "0123456789") orelse continue;
                const n = std.fmt.parseInt(u64, word[0..digits], 10) catch continue;
                const unit = word[digits..];
                if (std.mem.eql(u8, unit, "m")) r.m[i] = n;
                if (std.mem.eql(u8, unit, "t")) r.t[i] = n;
                if (std.mem.eql(u8, unit, "ids")) r.ids[i] = n;
                if (std.mem.eql(u8, unit, "req")) r.req[i] = n;
            }
        } else if (std.mem.eql(u8, first, "ladder")) {
            r.ladder = lastNumber(part);
        } else if (std.mem.eql(u8, first, "mastery")) {
            r.mastery = lastNumber(part);
        } else if (std.mem.eql(u8, first, "platform")) {
            r.platform_req = lastNumber(part);
        } else if (std.mem.eql(u8, first, "writes")) {
            // writes J in C commits, Q queued, B busy
            r.jobs = firstNumber(part);
            var after = std.mem.splitSequence(u8, part, " in ");
            _ = after.next();
            const rest = after.next() orelse continue;
            r.commits = firstNumber(rest);
            if (std.mem.indexOf(u8, rest, ", ")) |c| r.queued = firstNumber(rest[c + 2 ..]);
        } else if (std.mem.eql(u8, first, "pages")) {
            // pages written W, read R
            const c = std.mem.indexOfScalar(u8, part, ',') orelse continue;
            r.pages_written = lastNumber(part[0..c]);
            r.pages_read = lastNumber(part[c..]);
        }
    }
    return r;
}

fn firstNumber(s: []const u8) u64 {
    const a = std.mem.indexOfAny(u8, s, "0123456789") orelse return 0;
    const e = std.mem.indexOfNonePos(u8, s, a, "0123456789") orelse s.len;
    return std.fmt.parseInt(u64, s[a..e], 10) catch 0;
}

fn lastNumber(s: []const u8) u64 {
    var words = std.mem.tokenizeAny(u8, s, " ,");
    var n: u64 = 0;
    while (words.next()) |word| n = std.fmt.parseInt(u64, word, 10) catch n;
    return n;
}

/// Digits to N and long id-like words (PUUIDs, match ids) to …, so lines group and
/// carry nothing that names a player or a game
fn normalise(arena: std.mem.Allocator, line: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < line.len) {
        const c = line[i];
        if (std.ascii.isAlphanumeric(c) or c == '_' or c == '-') {
            var e = i;
            var digits = false;
            while (e < line.len and (std.ascii.isAlphanumeric(line[e]) or line[e] == '_' or line[e] == '-')) : (e += 1) {
                digits = digits or std.ascii.isDigit(line[e]);
            }
            const word = line[i..e];
            if (word.len >= 20 or (digits and std.mem.indexOfScalar(u8, word, '_') != null)) {
                try out.appendSlice(arena, "…");
            } else for (word) |ch| {
                if (std.ascii.isDigit(ch)) {
                    if (out.items.len == 0 or out.items[out.items.len - 1] != 'N') try out.append(arena, 'N');
                } else try out.append(arena, ch);
            }
            i = e;
        } else {
            try out.append(arena, c);
            i += 1;
        }
    }
    return out.items;
}

fn classify(msg: []const u8) Kind {
    const has = struct {
        fn f(s: []const u8, needle: []const u8) bool {
            return std.mem.indexOf(u8, s, needle) != null;
        }
    }.f;
    if (has(msg, "N (application)") or has(msg, "N (method)") or has(msg, "N (service)") or has(msg, "rate limit")) return .rate_limit;
    if (has(msg, "(server)")) return .riot_server;
    if (has(msg, "locked") or has(msg, "busy")) return .db_busy;
    if (has(msg, "Connection") or has(msg, "Timeout") or has(msg, "Tls") or has(msg, "Unreachable") or has(msg, "Reset")) return .network;
    return .other;
}

/// Upload times from deploy/web-loop.sh's log ("2026-10-11T22:51:02Z uploaded")
fn uploads(arena: std.mem.Allocator, io: Io, path: []const u8, start: i64) ![]const i64 {
    const text = try readTail(arena, io, path, 8 << 20);
    var out: std.ArrayList(i64) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (!std.mem.endsWith(u8, line, " uploaded")) continue;
        const t = stamp(line) orelse continue;
        if (t >= start) try out.append(arena, t);
    }
    return out.items;
}

test "report line" {
    const line = "info(crawl): 160216 matches/day | ladder pages 180 | mastery 3 | platform req 181" ++
        " | americas 3978m 2160t 483ids 6593req | asia 3823m 2232t 565ids 6597req" ++
        " | writes 28138 in 3921 commits, 4 queued, 0 busy | pages written 626229, read 454155";
    const r = parseReport(line).?;
    try std.testing.expectEqual(3978, r.m[@backingInt(Region.americas)]);
    try std.testing.expectEqual(565, r.ids[@backingInt(Region.asia)]);
    try std.testing.expectEqual(0, r.req[@backingInt(Region.europe)]);
    try std.testing.expectEqual(180, r.ladder);
    try std.testing.expectEqual(3, r.mastery);
    try std.testing.expectEqual(181, r.platform_req);
    try std.testing.expectEqual(28138, r.jobs);
    try std.testing.expectEqual(3921, r.commits);
    try std.testing.expectEqual(4, r.queued);
    try std.testing.expectEqual(626229, r.pages_written);
    try std.testing.expectEqual(454155, r.pages_read);
    try std.testing.expectEqual(null, parseReport("warning(crawl): kr: database busy, pausing"));
}

test "normalise log messages" {
    const a = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(a);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const m = try normalise(arena, "warning(riot): 503 (server) on /lol/match/v5/matches/EUW1_7123456/timeline, waiting 5s");
    try std.testing.expectEqualStrings("warning(riot): N (server) on /lol/match/vN/matches/…/timeline, waiting Ns", m);
    try std.testing.expectEqual(Kind.riot_server, classify(m));
    const p = try normalise(arena, "warning(riot): 500 (server) on /lol/match/v5/matches/by-puuid/-3uog-_IosuG5ssbfFVk1cyKUZg0/ids, waiting 1s");
    try std.testing.expect(std.mem.indexOf(u8, p, "IosuG") == null);
    try std.testing.expectEqual(Kind.db_busy, classify(try normalise(arena, "warning(crawl): kr: database busy, pausing")));
    try std.testing.expectEqual(Kind.rate_limit, classify(try normalise(arena, "warning(riot): 429 (application) on /x, waiting 65s")));
}

test "log stamps" {
    try std.testing.expectEqual(1760224041, stamp("2025-10-11 23:07:21 info(crawl): x"));
    try std.testing.expectEqual(1760224041, stamp("2025-10-11T23:07:21Z uploaded"));
    try std.testing.expectEqual(null, stamp("2026-10-11 00:46:40,823 WARNING"[0..10]));
}
