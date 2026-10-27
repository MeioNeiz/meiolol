//! Admin page data (/admin/, private), ui.data encoded: admin.bin, the box's snapshot
//! each web round (src/admin.zig generate), and live.bin, the admin API's last 3 h
//! (src/admin_api.zig). Aggregates only: no PUUIDs, Riot IDs or match ids
const std = @import("std");

/// Riot routing regions (riot/endpoints.zig Region; names asserted in admin.zig)
pub const Region = enum(u8) { americas, asia, europe, sea };
pub const regions = std.enums.values(Region).len;

/// Crawl log lines that are not report lines, by what they say. riot_busy: 429s with
/// limit type "server", Riot's side, not our key's
pub const Kind = enum(u8) { rate_limit, riot_busy, riot_server, riot_blocked, db_busy, network, other };
pub const kinds = std.enums.values(Kind).len;

/// One step of the crawl series: what the crawler's report lines added in it
pub const Bucket = struct {
    /// Seconds of crawler reports in this bucket; 0 = not running
    covered: u32 = 0,
    /// Per region: matches, timelines, match id calls, requests
    m: [regions]u32 = @splat(0),
    t: [regions]u32 = @splat(0),
    ids: [regions]u32 = @splat(0),
    req: [regions]u32 = @splat(0),
    ladder: u32 = 0,
    mastery: u32 = 0,
    platform_req: u32 = 0,
    jobs: u32 = 0,
    commits: u32 = 0,
    pages_written: u64 = 0,
    pages_read: u64 = 0,
    queued_max: u32 = 0,
    warnings: [kinds]u32 = @splat(0),
};

pub const Message = struct { text: []const u8, kind: Kind, count: u32, last: i64 };

pub const Crawl = struct {
    start: i64,
    /// Seconds per bucket
    step: u32,
    buckets: []const Bucket,
    /// Crawler starts in the window
    restarts: []const i64,
    /// Normalised warnings of the last day, most frequent first
    messages: []const Message,
    /// Last report line's time
    last_report: ?i64,
};

pub const Group = struct { key: []const u8, n: i64 };
pub const Queues = struct { match: []const Group, timeline: []const Group };
pub const Disk = struct { size: u64, used: u64, free: u64 };
pub const File = struct { name: []const u8, bytes: u64 };
pub const Count = struct { name: []const u8, rows: i64 };
pub const Platform = struct { id: []const u8, region: Region };

/// recent: of region, rows stored in the last 24 h
pub const DayRow = struct { day: i32, region: [regions]u64, recent: [regions]u64 };

/// The ingest mix: the newest draft rows
pub const Drafts = struct {
    rows: u64 = 0,
    days: []const DayRow = &.{},
    platforms: []const Group = &.{},
    patches: []const Group = &.{},
    /// Ladder order, then "unknown"
    tiers: []const Group = &.{},
    blue_wins: u64 = 0,
    /// Game length histogram, 5-minute bins from 0 (last: 60+)
    minutes: [13]u64 = @splat(0),
};

/// admin-history.tsv, one line per round; fields named as its columns, null when empty
pub const HistoryRow = struct {
    time: i64,
    meiolol_db: ?u64 = null,
    timeline_db: ?u64 = null,
    raw_db: ?u64 = null,
    disk_used: ?u64 = null,
    players: ?u64 = null,
    ranks: ?u64 = null,
    matches: ?u64 = null,
    timelines: ?u64 = null,
    drafts: ?u64 = null,
    match_queue: ?u64 = null,
    timeline_queue: ?u64 = null,
    mastery: ?u64 = null,
    meiolol_wal: ?u64 = null,
    timeline_wal: ?u64 = null,
    raw_wal: ?u64 = null,
};

/// eval-history.tsv, one line per `meiolol eval --history`; fields named as its columns
/// (date as a unix day), null where an older line has no such column
pub const EvalRow = struct {
    date: i32,
    games: u32,
    @"test": u32,
    ll_base: ?f32 = null,
    ll_current: ?f32 = null,
    ll_eb: ?f32 = null,
    ll_joint: ?f32 = null,
    ll_tunedw: ?f32 = null,
    pick_top10_win: ?f32 = null,
};

/// A commit that reached the site (DEPLOYED)
pub const Deployed = struct { sha: []const u8, time: i64 };

/// deploys.tsv: one deploy step (docs/hosting.md "Deploy events"), detail redacted
pub const DeployEvent = struct { time: i64, sha: []const u8, step: []const u8, status: []const u8, detail: []const u8 };

/// Space by table and index (storage.tsv, a daily dbstat scan)
pub const StorageRow = struct { db: []const u8, name: []const u8, kind: []const u8, bytes: u64, cells: u64 };
pub const Storage = struct { generated: i64, rows: []const StorageRow };

/// A mirror's mastery history (backups/acks/NAME.mastery)
pub const Mirror = struct { mirror: []const u8, time: i64, bytes: u64, files: u64 };
pub const Backups = struct { bytes: u64, files: u64, newest: i64, mastery: []const Mirror = &.{} };

/// Riot refused the key, with the log line
pub const KeyProblem = struct { time: i64, text: []const u8 };

pub const Riot = struct {
    /// Our key's app limit, Riot's header format ("20:1,100:120")
    app_limit: []const u8,
    /// The crawler's arguments (deploy/box.sh start)
    crawl_args: []const u8,
    /// The last 50
    key_problems: []const KeyProblem,
};

/// admin.bin
pub const Snapshot = struct {
    now: i64,
    /// Days of crawl and upload history
    days: u32,
    /// deploy/health.sh: one problem per line, empty when all is well
    health: []const u8,
    disk: ?Disk,
    platforms: []const Platform,
    files: []const File,
    counts: []const Count,
    queues: Queues,
    players: []const Group,
    ladder: []const Group,
    by_patch: []const Group,
    drafts: Drafts,
    crawl: Crawl,
    /// Oldest first, 30 days at most
    history: []const HistoryRow,
    eval: []const EvalRow,
    /// Site upload times
    uploads: []const i64,
    deploys: []const Deployed,
    /// Oldest first
    deploy_events: []const DeployEvent,
    /// eval-latest.md
    eval_report: []const u8,
    storage: ?Storage,
    backups: ?Backups,
    riot: Riot,
};

/// systemctl --user is-active of one unit
pub const Service = struct { unit: []const u8, state: []const u8 };

/// An admin action's log line (admin-actions.log)
pub const Action = struct { time: i64, name: []const u8, result: []const u8, output: []const u8 };

pub const Running = struct { name: []const u8, since: i64 };

/// live.bin: polled each minute between snapshots
pub const Live = struct {
    now: i64,
    services: []const Service,
    health: []const u8,
    /// The last 3 h by minute
    crawl: Crawl,
    queues: Queues,
    disk: ?Disk,
    /// The last 20, newest last
    actions: []const Action,
    deploys: []const DeployEvent,
    /// Start of a running `meiolol eval`
    eval_since: ?i64,
    action: ?Running,
};
