//! `meiolol admin`: private ops page (crawl rates, storage growth, ingest mix, queues,
//! model accuracy, site uploads) as one static page plus admin.js, which draws the
//! charts, admin-draft.js, the Draft tester (admin-setnet.js: its set net), admin-nn.js, the
//! neural net results, and admin-accounts.js, the logins. The box rebuilds it every 15 min
//! with the site (deploy/web-loop.sh); nginx serves it at /admin/ behind a login.
//! Aggregates only: no PUUIDs, Riot IDs or match ids (log messages are normalised before
//! they are counted).

const std = @import("std");
const store = @import("store");
const date = @import("date.zig");
const ep = @import("riot/endpoints.zig");
const ratelimit = @import("riot/ratelimit.zig");
const tsvlog = @import("tsvlog.zig");
const tpl = @import("tpl");
const status = @import("status.zig");
const ui = @import("ui");
const ad = ui.admindata;

const Io = std.Io;
const Region = ep.Region;
const regions = std.enums.values(Region);

/// Days of crawl and upload history shown
const days_shown: u32 = 7;

pub const Options = struct {
    out_dir: []const u8,
    data_dir: []const u8,
    /// The crawler's log, read from its last `log_tail` bytes
    crawl_log: []const u8,
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

const Kind = ad.Kind;

comptime {
    for (std.meta.fieldNames(Region), std.meta.fieldNames(ad.Region)) |a, b| std.debug.assert(std.mem.eql(u8, a, b));
    std.debug.assert(regions.len == ad.regions);
}

const Bucket = ad.Bucket;

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

const Message = ad.Message;

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
    try appendHistory(arena, io, history_path, o, counts, files);
    const history = try tail(arena, io, history_path, history_lines);

    const window_start = o.now_s - @as(i64, days_shown) * 86400;
    var key_problems: std.ArrayList(KeyProblem) = .empty;
    const crawl = try crawlSeries(arena, io, o.crawl_log, window_start, o.now_s, bucket_s, log_tail, &key_problems);
    const kp = key_problems.items;
    const queue_groups = try queues(arena, db);
    const drafts = try draftMix(arena, db, storedSince(history, "drafts", o.now_s - 86400, count(counts, "drafts")));
    const eval = try tail(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "eval-history.tsv" }), 400);
    const deployed = try tail(arena, io, "DEPLOYED", 15);
    const deploy_events = try deployEvents(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, deploys_file }));
    const eval_report = try readHead(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "eval-latest.md" }), eval_report_max);
    const storage_rows = try storage(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "storage.tsv" }));
    const crawl_args = std.mem.trim(u8, try readHead(arena, io, o.crawl_args orelse
        try std.fs.path.join(arena, &.{ o.data_dir, "..", "crawl.args" }), 4096) orelse "", " \n");
    const page = .{
        .now = o.now_s,
        .days = days_shown,
        .health = o.health,
        .disk = o.disk,
        .platforms = ep.platforms,
        .files = files,
        .counts = counts,
        .queues = queue_groups,
        .players = try playersByRegion(arena, db, count(counts, "players")),
        .ladder = try ladderTiers(arena, db),
        .by_patch = try groups(arena, db, "SELECT patch, count(*) FROM matches GROUP BY 1 ORDER BY 1 DESC LIMIT 8"),
        .drafts = drafts,
        .crawl = crawl,
        .history = history,
        .eval = eval,
        .uploads = try uploads(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "web.log" }), window_start),
        .deploys = deployed,
        .deploy_events = deploy_events,
        .logs = .{
            .health = try tail(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "health.log" }), 12),
            .backup = try tail(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "backup.log" }), 6),
            .builds = try tail(arena, io, try std.fs.path.join(arena, &.{ o.data_dir, "builds.log" }), 6),
        },
        .eval_report = eval_report,
        .storage = storage_rows,
        .backups = try backups(arena, io, o.backups_dir orelse try std.fs.path.join(arena, &.{ o.data_dir, "..", "backups" })),
        .riot = .{
            .app_limit = ratelimit.personal_key,
            // None seeded: the limiter learns them from Riot's headers
            .method_limits = struct {}{},
            .crawl_args = crawl_args,
            .key_problems = kp[kp.len -| 50..],
        },
    };
    const snap: ad.Snapshot = .{
        .now = page.now,
        .days = page.days,
        .health = page.health orelse "",
        .disk = adDisk(page.disk),
        .platforms = try adPlatforms(arena),
        .files = try adFiles(arena, files),
        .counts = counts,
        .queues = queue_groups,
        .players = page.players,
        .ladder = page.ladder,
        .by_patch = page.by_patch,
        .drafts = try adDrafts(arena, drafts),
        .crawl = adCrawl(crawl),
        .history = try tsvRows(arena, ad.HistoryRow, history),
        .eval = try tsvRows(arena, ad.EvalRow, eval),
        .uploads = page.uploads,
        .deploys = try adDeployed(arena, deployed),
        .deploy_events = try adDeployEvents(arena, deploy_events),
        .eval_report = eval_report orelse "",
        .storage = if (storage_rows) |st| try adStorage(arena, st) else null,
        .backups = page.backups,
        .riot = .{
            .app_limit = ratelimit.personal_key,
            .crawl_args = crawl_args,
            .key_problems = try adKeyProblems(arena, page.riot.key_problems),
        },
    };
    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ad.Snapshot, snap, &bin);
    const json = try std.json.Stringify.valueAlloc(arena, page, .{});

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
    try tpl.json(page).render(w);
    try w.writeAll(
        \\</script>
        \\<script src="admin-setnet.js"></script>
        \\<script src="admin-draft.js"></script>
        \\<script src="admin-nn.js"></script>
        \\<script src="admin-accounts.js"></script>
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
    try writeGz(gpa, io, dir, "admin.bin", bin.items);
    try writeGz(gpa, io, dir, "admin-setnet.js", @embedFile("site/static/admin-setnet.js"));
    try writeGz(gpa, io, dir, "admin-draft.js", @embedFile("site/static/admin-draft.js"));
    try writeGz(gpa, io, dir, "admin-nn.js", @embedFile("site/static/admin-nn.js"));
    try writeGz(gpa, io, dir, "admin-accounts.js", @embedFile("site/static/admin-accounts.js"));
    try writeGz(gpa, io, dir, "admin.js", @embedFile("site/static/admin.js"));
    try writeGz(gpa, io, dir, "admin.css", @embedFile("site/static/admin.css"));
}

// admin.bin (ui/admindata.zig) from the pieces data.json carries

fn adDisk(d: ?[3]u64) ?ad.Disk {
    const x = d orelse return null;
    return .{ .size = x[0], .used = x[1], .free = x[2] };
}

fn adPlatforms(arena: std.mem.Allocator) ![]ad.Platform {
    const out = try arena.alloc(ad.Platform, ep.platforms.len);
    for (ep.platforms, out) |p, *o| o.* = .{ .id = p.id, .region = @fromBackingInt(@intCast(@backingInt(p.region))) };
    return out;
}

fn adFiles(arena: std.mem.Allocator, files: []const FileSize) ![]ad.File {
    const out = try arena.alloc(ad.File, files.len);
    for (files, out) |f, *o| o.* = .{ .name = f.name, .bytes = f.bytes };
    return out;
}

fn adDrafts(arena: std.mem.Allocator, m: DraftMix) !ad.Drafts {
    const days = try arena.alloc(ad.DayRow, m.days.len);
    for (m.days, days) |d, *o| o.* = .{ .day = std.math.cast(i32, d.day) orelse 0, .region = d.region, .recent = d.recent };
    const tiers = try arena.alloc(ad.Group, m.tiers.len);
    for (tiers, m.tiers, 0..) |*t, n, i| t.* = .{
        .key = if (i < store.schema.tiers.len) store.schema.tiers[i] else "unknown",
        .n = @intCast(n),
    };
    return .{
        .rows = m.rows,
        .days = days,
        .platforms = m.platforms,
        .patches = m.patches,
        .tiers = tiers,
        .blue_wins = m.blue_wins,
        .minutes = m.minutes,
    };
}

fn adCrawl(c: Crawl) ad.Crawl {
    return .{
        .start = c.start,
        .step = c.step,
        .buckets = c.buckets,
        .restarts = c.restarts,
        .messages = c.messages,
        .last_report = c.last_report,
    };
}

/// DEPLOYED lines: "<sha> <ISO time>"
fn adDeployed(arena: std.mem.Allocator, text: []const u8) ![]ad.Deployed {
    var out: std.ArrayList(ad.Deployed) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const sp = std.mem.findScalar(u8, line, ' ') orelse continue;
        const t = stamp(line[sp + 1 ..]) orelse continue;
        try out.append(arena, .{ .sha = line[0..sp], .time = t });
    }
    return out.items;
}

test "DEPLOYED lines: a sha and its time, others skipped" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const d = try adDeployed(arena_state.allocator(), "20db56f 2026-10-27T00:54:48Z\nab12cd\nab12cd yesterday\n\n");
    try std.testing.expectEqual(1, d.len);
    try std.testing.expectEqualStrings("20db56f", d[0].sha);
    try std.testing.expectEqual(1793062488, d[0].time);
    try std.testing.expectEqual(0, (try adDeployed(arena_state.allocator(), "")).len);
}

fn adDeployEvents(arena: std.mem.Allocator, events: []const DeployEvent) ![]ad.DeployEvent {
    const out = try arena.alloc(ad.DeployEvent, events.len);
    for (events, out) |e, *o| o.* = .{ .time = e[0], .sha = e[1], .step = e[2], .status = e[3], .detail = e[4] };
    return out;
}

fn adStorage(arena: std.mem.Allocator, st: Storage) !ad.Storage {
    const rows = try arena.alloc(ad.StorageRow, st.rows.len);
    for (st.rows, rows) |r, *o| o.* = .{ .db = r[0], .name = r[1], .kind = r[2], .bytes = r[3], .cells = r[4] };
    return .{ .generated = st.generated, .rows = rows };
}

fn adKeyProblems(arena: std.mem.Allocator, kp: []const KeyProblem) ![]ad.KeyProblem {
    const out = try arena.alloc(ad.KeyProblem, kp.len);
    for (kp, out) |k, *o| o.* = .{ .time = k[0], .text = k[1] };
    return out;
}

/// `T`'s rows from a TSV with a header: each field from the column of its name, so
/// columns may be added or reordered. An empty or missing cell leaves an optional field
/// null and drops the row for any other field; a `date` field reads YYYY-MM-DD as a day
fn tsvRows(arena: std.mem.Allocator, comptime T: type, text: []const u8) ![]T {
    const fields = @typeInfo(T).@"struct".field_names;
    var lines = std.mem.splitScalar(u8, text, '\n');
    var col: [fields.len]?usize = @splat(null);
    var heads = std.mem.splitScalar(u8, lines.first(), '\t');
    var i: usize = 0;
    while (heads.next()) |h| : (i += 1) {
        inline for (fields, &col) |f, *c| if (std.mem.eql(u8, h, f)) {
            c.* = i;
        };
    }
    var out: std.ArrayList(T) = .empty;
    var cells: [64][]const u8 = undefined;
    rows: while (lines.next()) |line| {
        var n: usize = 0;
        var it = std.mem.splitScalar(u8, line, '\t');
        while (it.next()) |c| : (n += 1) {
            if (n == cells.len) break;
            cells[n] = c;
        }
        var row: T = undefined;
        inline for (fields, col) |f, c| {
            const cell = if (c) |x| (if (x < n) cells[x] else "") else "";
            @field(row, f) = switch (@typeInfo(@FieldType(T, f))) {
                .optional => |o| if (cell.len == 0) null else tsvCell(o.child, f, cell),
                else => tsvCell(@FieldType(T, f), f, cell) orelse continue :rows,
            };
        }
        try out.append(arena, row);
    }
    return out.items;
}

fn tsvCell(comptime V: type, comptime name: []const u8, cell: []const u8) ?V {
    if (comptime std.mem.eql(u8, name, "date")) {
        return std.math.cast(V, (date.Date.parse(cell) orelse return null).toDay());
    }
    return switch (@typeInfo(V)) {
        .int => std.fmt.parseInt(V, cell, 10) catch null,
        .float => std.fmt.parseFloat(V, cell) catch null,
        else => @compileError("tsvRows: " ++ @typeName(V)),
    };
}

test "tsv rows by column name: optional cells null, rows short of a required cell dropped" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const h = try tsvRows(a, ad.HistoryRow, "time\tmatches\tdisk_size\tdrafts\n" ++
        "1760137700\t12\t9\t\nbad\t1\t\t\n\n1760138600\t13\t9\t4");
    try std.testing.expectEqual(2, h.len);
    try std.testing.expectEqual(@as(?u64, 12), h[0].matches);
    try std.testing.expectEqual(@as(?u64, null), h[0].drafts);
    try std.testing.expectEqual(@as(?u64, null), h[0].players);
    try std.testing.expectEqual(@as(?u64, 4), h[1].drafts);
    // An older line, short of the newer columns
    const e = try tsvRows(a, ad.EvalRow, "date\tgames\ttest\tll_base\tll_tunedw\n" ++
        "2026-10-11\t8303\t1458\t0.69299\n1970-01-02\t1\t1\t\t0.5\n2026-13-01\t1\t1");
    try std.testing.expectEqual(2, e.len);
    try std.testing.expectEqual(20737, e[0].date);
    try std.testing.expectEqual(@as(?f32, null), e[0].ll_tunedw);
    try std.testing.expectApproxEqAbs(@as(f32, 0.69299), e[0].ll_base.?, 1e-6);
    try std.testing.expectEqual(1, e[1].date);
    try std.testing.expectEqual(@as(?f32, 0.5), e[1].ll_tunedw);
}

/// The private site's Draft tester (/p/, docs/plan/accounts.md AC3): the admin page in
/// private mode (admin.js PRIVATE), no box data, only the shipped models the web loop
/// copies into models/; and pv.js, the public pages' private numbers. nginx serves it to
/// view_private logins
pub fn private(gpa: std.mem.Allocator, io: Io, out_dir: []const u8, now_s: i64) !void {
    var buf: [1024]u8 = undefined;
    const page = try std.fmt.bufPrint(&buf,
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="robots" content="noindex">
        \\<title>meiolol private</title>
        \\<link rel="stylesheet" href="admin.css">
        \\</head>
        \\<body>
        \\<main id="app"><p>Loading…</p></main>
        \\<script id="data" type="application/json">{{"private":true,"now":{d}}}</script>
        \\<script src="admin-setnet.js"></script>
        \\<script src="admin-draft.js"></script>
        \\<script src="admin.js"></script>
        \\</body>
        \\</html>
        \\
    , .{now_s});
    const cwd = Io.Dir.cwd();
    try cwd.createDirPath(io, out_dir);
    var dir = try cwd.openDir(io, out_dir, .{});
    defer dir.close(io);
    try writeGz(gpa, io, dir, "index.html", page);
    try writeGz(gpa, io, dir, "admin-setnet.js", @embedFile("site/static/admin-setnet.js"));
    try writeGz(gpa, io, dir, "admin-draft.js", @embedFile("site/static/admin-draft.js"));
    try writeGz(gpa, io, dir, "admin.js", @embedFile("site/static/admin.js"));
    try writeGz(gpa, io, dir, "admin.css", @embedFile("site/static/admin.css"));
    try writeGz(gpa, io, dir, "pv.js", @embedFile("site/static/pv.js"));
}

/// Also `path`.gz, as the site's pages (nginx gzip_static)
fn writeGz(gpa: std.mem.Allocator, io: Io, dir: Io.Dir, path: []const u8, data: []const u8) !void {
    try dir.writeFile(io, .{ .sub_path = path, .data = data });
    const gz = try store.raw.compress(gpa, data);
    defer gpa.free(gz);
    var buf: [64]u8 = undefined;
    try dir.writeFile(io, .{ .sub_path = try std.mem.print(&buf, "{s}.gz", .{path}), .data = gz });
}

const Count = ad.Count;

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
        c.* = .{ .name = t, .rows = try status.rows(db, t) };
    }
    return out;
}

fn count(counts: []const Count, name: []const u8) i64 {
    for (counts) |c| if (std.mem.eql(u8, c.name, name)) return c.rows;
    return 0;
}

const FileSize = struct { name: []const u8, bytes: u64, wal: u64 };

/// Each database with its WAL (bytes includes wal)
fn fileSizes(arena: std.mem.Allocator, io: Io, data_dir: []const u8) ![]FileSize {
    const names = [_][]const u8{ "meiolol.db", "timeline.db", "raw.db" };
    const out = try arena.alloc(FileSize, names.len);
    for (names, out) |n, *f| {
        f.* = .{ .name = n, .bytes = 0, .wal = 0 };
        for ([_][]const u8{ "", "-wal" }) |suffix| {
            const path = try arena.print("{s}/{s}{s}", .{ data_dir, n, suffix });
            const st = Io.Dir.cwd().statFile(io, path, .{}) catch continue;
            f.bytes += st.size;
            if (suffix.len > 0) f.wal = st.size;
        }
    }
    return out;
}

// WAL columns: growth readable without the WAL's swings (it once reached 57 GB)
const history_header = "time\tmeiolol_db\ttimeline_db\traw_db\tdisk_used\tdisk_size\tplayers\tranks" ++
    "\tmatches\ttimelines\tdrafts\tmatch_queue\ttimeline_queue\tmastery" ++
    "\tmeiolol_wal\ttimeline_wal\traw_wal\n";

fn appendHistory(arena: std.mem.Allocator, io: Io, path: []const u8, o: Options, counts: []const Count, files: []const FileSize) !void {
    var row: Io.Writer.Allocating = .init(arena);
    const w = &row.writer;
    try w.print("{d}", .{o.now_s});
    for (files) |f| try w.print("\t{d}", .{f.bytes});
    if (o.disk) |d| try w.print("\t{d}\t{d}", .{ d[1], d[0] }) else try w.writeAll("\t\t");
    for ([_][]const u8{ "players", "ranks", "matches", "timeline.timelines", "drafts", "match_queue", "timeline_queue", "mastery" }) |t| {
        try w.print("\t{d}", .{count(counts, t)});
    }
    for (files) |f| try w.print("\t{d}", .{f.wal});
    try w.writeAll("\n");
    try tsvlog.append(arena, io, path, history_header, row.written());
}

const Group = ad.Group;

const Queues = ad.Queues;

fn queues(arena: std.mem.Allocator, db: store.Db) !Queues {
    return .{
        .match = try groups(arena, db, "SELECT status, count(*) FROM match_queue GROUP BY 1 ORDER BY 2 DESC"),
        .timeline = try groups(arena, db, "SELECT region || ' ' || status, count(*) FROM timeline_queue GROUP BY 1 ORDER BY 1"),
    };
}

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

/// Players by region from status's 1/16 PUUID sample, or every row when `total` (status's
/// estimate) says the sample would be too small to stand for them
fn playersByRegion(arena: std.mem.Allocator, db: store.Db, total: i64) ![]Group {
    const select = "SELECT coalesce(region, '?'), count(*) FROM players";
    const rest = " GROUP BY 1 ORDER BY 2 DESC";
    if (total < (status.Options{}).min_sample * status.puuid_scale) return groups(arena, db, select ++ rest);
    const gs = try groups(arena, db, select ++ " WHERE " ++ status.puuid_sample ++ rest);
    for (gs) |*g| g.n *= status.puuid_scale;
    return gs;
}

/// Ranked players on the ladder, by tier (ranks: every player a ladder page showed).
/// Counted, not sampled: a 1/64 sample is far off for the small tiers (Challenger, Iron)
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
/// recent: of region, rows stored in the last 24 h
const DayRow = struct { day: i64, region: [regions.len]u64, recent: [regions.len]u64 };

/// Rows of history's `col` added since `at` (its last line at or before), given the count
/// now; null without a line in the day before `at`. drafts counts are rowid ranges
/// (status.rows), so this many back from the newest rowid were stored since `at`
fn storedSince(history: []const u8, col: []const u8, at: i64, now: i64) ?u64 {
    var lines = std.mem.tokenizeScalar(u8, history, '\n');
    const ci = tsvlog.column(lines.next() orelse return null, col) orelse return null;
    var then: ?i64 = null;
    while (lines.next()) |line| {
        const t = std.fmt.parseInt(i64, field(line, 0) orelse continue, 10) catch continue;
        if (t > at) break;
        if (t < at - 86400) continue;
        then = std.fmt.parseInt(i64, field(line, ci) orelse continue, 10) catch continue;
    }
    return @intCast(@max(now - (then orelse return null), 0));
}

fn field(line: []const u8, i: usize) ?[]const u8 {
    var it = std.mem.splitScalar(u8, line, '\t');
    for (0..i) |_| _ = it.next() orelse return null;
    return it.next();
}

/// Complete ranked games (drafts rows) of the newest `draft_tail` stored: by game day
/// and region, platform, patch, rank, side and length
fn draftMix(arena: std.mem.Allocator, db: store.Db, stored_day: ?u64) !DraftMix {
    const max_id = try db.scalar("SELECT coalesce(max(id), 0) FROM drafts", .{}) orelse 0;
    // No history from a day ago: nothing counts as recent
    const recent_from = max_id - @as(i64, @intCast(stored_day orelse 0));
    var q = try db.prepare(
        \\SELECT id, day, platform, patch, rank, blue_win, minutes FROM drafts
        \\WHERE id > ? AND queue = ?
    );
    defer q.deinit();
    // Solo only, as the models: drafts also holds the flex test sample
    try q.bind(.{ max_id - draft_tail, ep.ranked_solo });
    var mix: DraftMix = .{};
    var days: std.AutoArrayHashMapUnmanaged(i64, [2][regions.len]u64) = .empty;
    var platforms: std.StringArrayHashMapUnmanaged(i64) = .empty;
    var patches: std.StringArrayHashMapUnmanaged(i64) = .empty;
    while (try q.step()) {
        const row = q.row(struct {
            id: i64,
            day: i64,
            platform: []const u8,
            patch: []const u8,
            rank: ?i64,
            blue_win: u64,
            minutes: ?i64,
        });
        mix.rows += 1;
        try bump(arena, &platforms, row.platform);
        try bump(arena, &patches, row.patch);
        if (ep.platform(row.platform)) |pl| {
            const d = try days.getOrPut(arena, row.day);
            if (!d.found_existing) d.value_ptr.* = @splat(@splat(0));
            d.value_ptr[0][@backingInt(pl.region)] += 1;
            if (row.id > recent_from) d.value_ptr[1][@backingInt(pl.region)] += 1;
        }
        const tier: usize = if (row.rank) |r| @min(@as(usize, @intCast(@max(r, 0))) / 4, store.schema.tiers.len) else store.schema.tiers.len;
        mix.tiers[tier] += 1;
        mix.blue_wins += row.blue_win;
        if (row.minutes) |m| mix.minutes[@min(@as(usize, @intCast(@max(m, 0))) / 5, mix.minutes.len - 1)] += 1;
    }
    const day_rows = try arena.alloc(DayRow, days.count());
    for (days.keys(), days.values(), day_rows) |d, v, *r| r.* = .{ .day = d, .region = v[0], .recent = v[1] };
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

/// `key` is the statement's: duped when new
fn bump(arena: std.mem.Allocator, m: *std.StringArrayHashMapUnmanaged(i64), key: []const u8) !void {
    const e = try m.getOrPut(arena, key);
    if (!e.found_existing) {
        e.key_ptr.* = try arena.dupe(u8, key);
        e.value_ptr.* = 0;
    }
    e.value_ptr.* += 1;
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
pub fn tail(arena: std.mem.Allocator, io: Io, path: []const u8, n: usize) ![]const u8 {
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
        const header = text[0 .. std.mem.findScalar(u8, text, '\n').? + 1];
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
        const nl = std.mem.findScalar(u8, text, '\n') orelse return "";
        text = text[nl + 1 ..];
        if (std.mem.findScalar(u8, head[0..h], '\n')) |e| {
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

const Backups = ad.Backups;

/// A mirror's mastery history (backups/acks/NAME.mastery: "time bytes files", sent by
/// deploy/backup-mirror.sh after each round)
const MirrorMastery = ad.Mirror;

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
    var mastery: std.ArrayList(MirrorMastery) = .empty;
    for ([_][]const u8{ "gpu-box", "mac" }) |name| {
        const text = dir.readFileAlloc(io, try arena.print("acks/{s}.mastery", .{name}), arena, .limited(256)) catch continue;
        if (parseMirrorMastery(name, text)) |m| try mastery.append(arena, m);
    }
    b.mastery = mastery.items;
    return b;
}

fn parseMirrorMastery(name: []const u8, text: []const u8) ?MirrorMastery {
    var f = std.mem.tokenizeAny(u8, text, " \t\r\n");
    const time = std.fmt.parseInt(i64, f.next() orelse return null, 10) catch return null;
    const bytes = std.fmt.parseInt(u64, f.next() orelse return null, 10) catch return null;
    const files = std.fmt.parseInt(u64, f.next() orelse return null, 10) catch return null;
    return .{ .mirror = name, .time = time, .bytes = bytes, .files = files };
}

test "a mirror's mastery history line" {
    const m = parseMirrorMastery("gpu-box", "1792312149 12345 7\n").?;
    try std.testing.expectEqual(@as(u64, 12345), m.bytes);
    try std.testing.expectEqual(@as(u64, 7), m.files);
    try std.testing.expectEqual(@as(?MirrorMastery, null), parseMirrorMastery("mac", "garbage"));
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
        .queues = try queues(arena, db),
        .disk = l.disk,
        .files = try fileSizes(arena, io, l.data_dir),
        .actions = try actionLog(arena, io, try std.fs.path.join(arena, &.{ l.data_dir, action_log })),
        .deploys = try deployEvents(arena, io, try std.fs.path.join(arena, &.{ l.data_dir, deploys_file })),
        .running = .{ .eval = l.eval_since, .action = l.action },
    };
    return std.json.Stringify.valueAlloc(arena, live, .{});
}

/// /admin/api/live.bin: live.json's data as ui/admindata.zig's Live, for the new page
pub fn liveBin(arena: std.mem.Allocator, io: Io, db: store.Db, l: Live) ![]const u8 {
    const crawl_log = try std.fs.path.join(arena, &.{ l.data_dir, "crawl.log" });
    var services: std.ArrayList(ad.Service) = .empty;
    inline for (comptime std.meta.fieldNames(Services)) |f| {
        try services.append(arena, .{ .unit = f, .state = @field(l.services, f) });
    }
    const actions = try actionLog(arena, io, try std.fs.path.join(arena, &.{ l.data_dir, action_log }));
    const ad_actions = try arena.alloc(ad.Action, actions.len);
    for (actions, ad_actions) |x, *o| o.* = .{ .time = x[0], .name = x[1], .result = x[2], .output = x[3] };
    const live: ad.Live = .{
        .now = l.now_s,
        .services = services.items,
        .health = l.health,
        .crawl = adCrawl(try crawlSeries(arena, io, crawl_log, l.now_s - live_window_s, l.now_s, live_step_s, 4 << 20, null)),
        .queues = try queues(arena, db),
        .disk = adDisk(l.disk),
        .actions = ad_actions,
        .deploys = try adDeployEvents(arena, try deployEvents(arena, io, try std.fs.path.join(arena, &.{ l.data_dir, deploys_file }))),
        .eval_since = l.eval_since,
        .action = if (l.action) |x| .{ .name = x.name, .since = x.since } else null,
    };
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(arena, ad.Live, live, &out);
    return out.items;
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

/// Deploy steps, one per line (docs/hosting.md "Deploy events"): unix time, commit,
/// step, status, detail. Written by deploy/deploy-events.sh (the Mac's pre-push check and
/// on-push.sh), render-swap.sh, web-loop.sh and cache-version.sh on the box
pub const deploys_file = "deploys.tsv";
/// About a week of deploys and the hourly cache key lines beside them
const deploy_event_lines = 3000;

const DeployEvent = struct { i64, []const u8, []const u8, []const u8, []const u8 };

/// The newest `deploy_event_lines`, oldest first; details redacted (commit subjects and
/// error lines could name a game)
fn deployEvents(arena: std.mem.Allocator, io: Io, path: []const u8) ![]const DeployEvent {
    const text = try tail(arena, io, path, deploy_event_lines);
    var out: std.ArrayList(DeployEvent) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    next: while (lines.next()) |line| {
        var f = std.mem.splitScalar(u8, line, '\t');
        const t = std.fmt.parseInt(i64, f.next() orelse continue, 10) catch continue;
        const sha = f.next() orelse continue;
        if (sha.len > 40) continue;
        for (sha) |c| if (!std.ascii.isHex(c)) continue :next;
        const step = f.next() orelse continue;
        const result = f.next() orelse continue;
        if (step.len > 16 or result.len > 16) continue;
        try out.append(arena, .{ t, sha, step, result, try redact(arena, f.rest()) });
    }
    return out.items;
}

/// A log line for the admin page's log viewer: as written, numbers and times kept, but
/// id-like words and Riot IDs to … (`scrub`)
pub fn redact(arena: std.mem.Allocator, line: []const u8) ![]const u8 {
    return scrub(arena, line, false);
}

/// `line` with id-like words (PUUIDs, match ids like EUW1_7123456) and Riot IDs (name#tag)
/// to …, and with `digits`, digit runs to N so lines group
fn scrub(arena: std.mem.Allocator, line: []const u8, digits: bool) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var id = riotIdAt(line, 0);
    var i: usize = 0;
    while (i < line.len) {
        if (id) |r| if (i == r.start) {
            try out.appendSlice(arena, "…");
            i = r.end;
            id = riotIdAt(line, i);
            continue;
        };
        if (!isWordChar(line[i])) {
            try out.append(arena, line[i]);
            i += 1;
            continue;
        }
        const stop = if (id) |r| r.start else line.len;
        var e = i;
        while (e < stop and isWordChar(line[e])) e += 1;
        const word = line[i..e];
        const has_digit = std.mem.findAny(u8, word, "0123456789") != null;
        // Error names such as HttpConnectionClosing stay: letters only, shorter than any
        // PUUID or encrypted id
        const error_name = word.len < 32 and for (word) |c| {
            if (!std.ascii.isAlphabetic(c)) break false;
        } else true;
        if ((word.len >= 20 and !error_name) or (has_digit and std.mem.findScalar(u8, word, '_') != null)) {
            try out.appendSlice(arena, "…");
        } else if (!digits or isStatus(line, i, e)) {
            try out.appendSlice(arena, word);
        } else for (word) |c| {
            if (!std.ascii.isDigit(c)) {
                try out.append(arena, c);
            } else if (out.items.len == 0 or out.items[out.items.len - 1] != 'N') {
                try out.append(arena, 'N');
            }
        }
        i = e;
    }
    return out.items;
}

/// An HTTP status as the Riot client logs it ("503 on ...", "429 (server) on ..."): kept
/// through normalise, so a 5xx and a 429 still read apart
fn isStatus(line: []const u8, start: usize, end: usize) bool {
    if (end - start != 3 or (line[start] != '4' and line[start] != '5')) return false;
    for (line[start..end]) |c| if (!std.ascii.isDigit(c)) return false;
    const after = line[end..];
    return std.mem.startsWith(u8, after, " on ") or std.mem.startsWith(u8, after, " (");
}

fn isWordChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '-';
}

/// Riot ID game names: 3-16 letters (any script), digits or spaces; tags 3-5
const max_name_chars = 16;

/// The first Riot ID (name#tag) at or after `from`. The name runs back from `#` over
/// letters, digits, spaces and non-ASCII bytes to the previous separator, at most 16
/// characters and whole words; the tag is 3 or more letters or digits. Wider than Riot's
/// rules, so a neighbouring word may go too: better than a name left half shown
fn riotIdAt(line: []const u8, from: usize) ?struct { start: usize, end: usize } {
    var h = from;
    while (std.mem.findScalarPos(u8, line, h, '#')) |hash| : (h = hash + 1) {
        if (hash == from or !isNameByte(line[hash - 1]) or line[hash - 1] == ' ') continue;
        var end = hash + 1;
        var tag_chars: usize = 0;
        while (end < line.len and (std.ascii.isAlphanumeric(line[end]) or line[end] >= 0x80)) : (end += 1) {
            if (!isContinuation(line[end])) tag_chars += 1;
        }
        if (tag_chars < 3) continue;
        var start = hash;
        var name_chars: usize = 0;
        while (start > from and isNameByte(line[start - 1])) {
            var c = start - 1;
            while (c > from and isContinuation(line[c]) and isNameByte(line[c - 1])) c -= 1;
            if (name_chars == max_name_chars) break;
            name_chars += 1;
            start = c;
        }
        // Cut off inside a word: that word is too long to be in the name
        if (start > from and isNameByte(line[start - 1]) and line[start - 1] != ' ') {
            if (std.mem.findScalarPos(u8, line[0..hash], start, ' ')) |sp| start = sp;
        }
        while (line[start] == ' ') start += 1;
        return .{ .start = start, .end = end };
    }
    return null;
}

fn isNameByte(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == ' ' or c == '_' or c >= 0x80;
}

fn isContinuation(c: u8) bool {
    return c & 0xc0 == 0x80;
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
        } else if (std.mem.find(u8, rest, "workers for") != null or std.mem.find(u8, rest, "threads for") != null) {
            try restarts.append(arena, t);
            prev = .{ .t = t, .r = .{} };
        } else if (std.mem.startsWith(u8, rest, "warning(") or std.mem.startsWith(u8, rest, "error(")) {
            const msg = try normalise(arena, rest);
            if (key_problems) |kp| if (std.mem.find(u8, msg, "key missing or expired") != null) {
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
    if (!std.mem.startsWith(u8, line, "info(crawl): ") or std.mem.find(u8, line, " matches/day | ") == null) return null;
    var r: Report = .{};
    var parts = std.mem.splitSequence(u8, line, " | ");
    _ = parts.next();
    while (parts.next()) |part| {
        var words = std.mem.tokenizeAny(u8, part, " ,");
        const first = words.next() orelse continue;
        if (std.meta.stringToEnum(Region, first)) |region| {
            const i = @backingInt(region);
            while (words.next()) |word| {
                const digits = std.mem.findNone(u8, word, "0123456789") orelse continue;
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
            if (std.mem.find(u8, rest, ", ")) |c| r.queued = firstNumber(rest[c + 2 ..]);
        } else if (std.mem.eql(u8, first, "pages")) {
            // pages written W, read R
            const c = std.mem.findScalar(u8, part, ',') orelse continue;
            r.pages_written = lastNumber(part[0..c]);
            r.pages_read = lastNumber(part[c..]);
        }
    }
    return r;
}

fn firstNumber(s: []const u8) u64 {
    const a = std.mem.findAny(u8, s, "0123456789") orelse return 0;
    const e = std.mem.findNonePos(u8, s, a, "0123456789") orelse s.len;
    return std.fmt.parseInt(u64, s[a..e], 10) catch 0;
}

fn lastNumber(s: []const u8) u64 {
    var words = std.mem.tokenizeAny(u8, s, " ,");
    var n: u64 = 0;
    while (words.next()) |word| n = std.fmt.parseInt(u64, word, 10) catch n;
    return n;
}

/// Digits to N and id-like words and Riot IDs to …, so lines group and carry nothing that
/// names a player or a game
fn normalise(arena: std.mem.Allocator, line: []const u8) ![]const u8 {
    return scrub(arena, line, true);
}

fn classify(msg: []const u8) Kind {
    const has = struct {
        fn f(s: []const u8, needle: []const u8) bool {
            return std.mem.find(u8, s, needle) != null;
        }
    }.f;
    if (has(msg, "429 (server)")) return .riot_busy;
    if (has(msg, "429 (") or has(msg, "rate limit")) return .rate_limit;
    if (has(msg, "Riot's edge refusing") or std.mem.endsWith(u8, msg, ": Blocked")) return .riot_blocked;
    if (serverError(msg)) return .riot_server;
    if (has(msg, "database is locked") or has(msg, "database busy")) return .db_busy;
    if (has(msg, "Connection") or has(msg, "Timeout") or has(msg, "Tls") or has(msg, "Unreachable") or has(msg, "Reset") or has(msg, "ReadFailed")) return .network;
    return .other;
}

/// A 5xx status kept by normalise, as a word of its own
fn serverError(msg: []const u8) bool {
    var words = std.mem.tokenizeAny(u8, msg, " :");
    while (words.next()) |w| {
        if (w.len == 3 and w[0] == '5' and std.ascii.isDigit(w[1]) and std.ascii.isDigit(w[2])) return true;
    }
    return false;
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
    const m = try normalise(arena, "warning(riot): 503 on /lol/match/v5/matches/EUW1_7123456/timeline, retrying");
    try std.testing.expectEqualStrings("warning(riot): 503 on /lol/match/vN/matches/…/timeline, retrying", m);
    const p = try normalise(arena, "warning(riot): 504 on /lol/match/v5/matches/by-puuid/-3uog-_IosuG5ssbfFVk1cyKUZg0/ids, retrying");
    try std.testing.expect(std.mem.find(u8, p, "IosuG") == null);
    try std.testing.expectEqualStrings("warning(crawl): writer: database busy, retrying N jobs", try normalise(arena, "warning(crawl): writer: database busy, retrying 500 jobs"));
    // Lines as the crawler logs them on 17 Oct
    const cases = [_]struct { []const u8, Kind }{
        .{ "warning(riot): 503 on /lol/match/v5/matches/EUW1_7123456/timeline, retrying", .riot_server },
        .{ "warning(riot): 504 on /lol/champion-mastery/v4/champion-masteries/by-puuid/x, retrying", .riot_server },
        .{ "warning(riot): 429 (server) on /lol/match/v5/matches/EUW1_7123456, waiting 5s", .riot_busy },
        .{ "warning(riot): 429 (application) on /x, waiting 65s", .rate_limit },
        .{ "warning(riot): 429 (method) on /x, waiting 10s", .rate_limit },
        .{ "warning(riot): 403 on /lol/champion-mastery/v4/x: an HTML page, Riot's edge refusing this request, not the key", .riot_blocked },
        .{ "warning(crawl): tw2 mastery: Blocked", .riot_blocked },
        .{ "warning(crawl): kr: database busy, pausing", .db_busy },
        .{ "warning(crawl): writer: database busy, retrying 24 jobs", .db_busy },
        .{ "warning(sqlite): exec: database is locked", .db_busy },
        .{ "warning(riot): HttpConnectionClosing on /lol/match/v5/matches/EUW1_1, retrying", .network },
        .{ "warning(riot): ReadFailed on /lol/match/v5/matches/EUW1_1, retrying", .network },
        .{ "warning(crawl): euw1 mastery: UnexpectedStatus", .other },
        .{ "warning(riot): 400 on /x", .other },
    };
    for (cases) |c| try std.testing.expectEqual(c[1], classify(try normalise(arena, c[0])));
}

test "redact Riot IDs" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cases = [_][2][]const u8{
        .{ "warning(api): Ñandú#EUW: not found", "warning(api): …: not found" },
        .{ "info: 404, Hide on bush#KR1, retrying", "info: 404, …, retrying" },
        // At most 16 characters back: Riot's longest name
        .{ "info: 404 for Hide on bush#KR1", "info: 404 …" },
        .{ "on /x/EUW1_7123456 for Faker#KR1", "on /x/… …" },
        .{ "x (Faker#KR1) y", "x (…) y" },
        .{ "joined: 김치찌개#한국1 left", "joined: … left" },
        .{ "puzzle #1, issue#22, colour #fff", "puzzle #1, issue#22, colour #fff" },
    };
    for (cases) |c| try std.testing.expectEqualStrings(c[1], try redact(arena, c[0]));
    try std.testing.expectEqualStrings("warning(api): …: 503 (server)", try normalise(arena, "warning(api): Some One#EUW1: 503 (server)"));
}

test "log stamps" {
    try std.testing.expectEqual(1760224041, stamp("2025-10-11 23:07:21 info(crawl): x"));
    try std.testing.expectEqual(1760224041, stamp("2025-10-11T23:07:21Z uploaded"));
    try std.testing.expectEqual(null, stamp("2026-10-11 00:46:40,823 WARNING"[0..10]));
}
