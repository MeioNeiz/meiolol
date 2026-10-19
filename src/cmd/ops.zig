//! `meiolol api`, `your-example`, `status`, `admin`

const std = @import("std");
const store = @import("store");
const core = @import("core");
const api = @import("../api/root.zig");
const admin = @import("../admin.zig");
const status = @import("../status.zig");
const main = @import("../main.zig");
const Cmd = main.Cmd;

pub const usage_api =
    \\  api         the "Your games" service: JSON at /api/ (src/api/root.zig). Cache in
    \\              DIR/api.db. Riot calls through the crawler's proxy, else
    \\              straight to Riot with RIOT_API_KEY (testing)
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8090
    \\              --exchange DIR   shared with the box: curves/ in, forgotten
    \\                               PUUID lists both ways (docs/your-games.md)
    \\              --curves DIR     curves-<patch>.bin files (default EXCHANGE/curves,
    \\                               else DIR/export)
    \\              --riot-proxy URL the crawler's --proxy (box: http://10.0.0.3:8092)
    \\              --cors ORIGIN    allow a page on ORIGIN (local testing)
    \\
;

pub fn cmdApi(c: *Cmd) !u8 {
    var o: api.Options = .{ .db_path = "", .curves_dir = "" };
    var curves_dir: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--host")) {
            o.host = try c.value();
        } else if (c.is("--port")) {
            o.port = try c.int(u16);
        } else if (c.is("--exchange")) {
            o.fetch.exchange_dir = try c.value();
        } else if (c.is("--curves")) {
            curves_dir = try c.value();
        } else if (c.is("--riot-proxy")) {
            o.fetch.proxy = try c.value();
        } else if (c.is("--cors")) {
            o.cors = try c.value();
        } else return error.Usage;
    }
    const arena = c.arena;
    if (o.fetch.proxy == null) o.fetch.key = try c.apiKey();
    o.db_path = try arena.printSentinel("{s}/api.db", .{c.data_dir}, 0);
    o.curves_dir = curves_dir orelse if (o.fetch.exchange_dir) |x|
        try std.fs.path.join(arena, &.{ x, "curves" })
    else
        try std.fs.path.join(arena, &.{ c.data_dir, "export" });
    try api.run(c.init.gpa, c.init.io, o);
    return 0;
}

pub const usage_your_example =
    \\  your-example  an anonymised player's recent games per role as GET /api/games
    \\              answers, for your.html's example (src/api/example.zig); read-only
    \\              --out FILE       default DIR/your-example.json
    \\              --curves DIR     curves-<patch>.bin files (default DIR/export)
    \\              --days N         recent days a player is picked from (default 7)
    \\
;

pub fn cmdYourExample(c: *Cmd) !u8 {
    var out: ?[]const u8 = null;
    var curves_dir: ?[]const u8 = null;
    var days: u32 = 7;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--curves")) {
            curves_dir = try c.value();
        } else if (c.is("--days")) {
            days = try c.int(u32);
        } else return error.Usage;
    }
    const arena = c.arena;
    const io = c.init.io;
    const path = out orelse try std.fs.path.join(arena, &.{ c.data_dir, "your-example.json" });
    const dir = curves_dir orelse try std.fs.path.join(arena, &.{ c.data_dir, "export" });
    const set = try api.loadCurveSet(arena, io, dir);
    const db = try store.schema.openReadOnly(c.init.gpa, c.data_dir);
    defer db.close();
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const examples = try api.example.buildAll(arena, db, set, .{
        .since_ms = now_ms - @as(i64, days) * std.time.ms_per_day,
    }) orelse {
        std.log.err("no player with enough games of a role with timelines in the last {d} days", .{days});
        return 1;
    };
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = try api.example.json(arena, examples) });
    inline for (core.Role.all) |r| {
        if (@field(examples, r.label())) |ex| {
            std.log.info("{s} {s}: {d} games", .{ path, r.label(), ex.report.?.games.len });
        } else std.log.info("{s} {s}: nobody qualifies", .{ path, r.label() });
    }
    return 0;
}

pub const usage_status =
    \\  status      row counts and crawl queue state; read-only, estimates (~) for the
    \\              big tables (src/status.zig)
    \\              --exact          count every row (slow on the box)
    \\
;

pub fn cmdStatus(c: *Cmd) !u8 {
    var exact = false;
    while (c.next()) |_| {
        if (c.is("--exact")) exact = true else return error.Usage;
    }
    const db = try store.schema.openReadOnly(c.init.gpa, c.data_dir);
    defer db.close();
    var buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(c.init.io, &buf);
    try status.write(c.arena, db, &stdout.interface, .{ .exact = exact });
    try stdout.interface.flush();
    return 0;
}

pub const usage_admin =
    \\  admin       private ops page (src/admin.zig): crawl rates from the crawl log,
    \\              storage growth (appends DIR/admin-history.tsv), ingest mix, queues
    \\              --out DIR        default DIR/admin
    \\              --log FILE       crawler log (default DIR/crawl.log)
    \\              --days N         history shown (default 7)
    \\              --disk "S U A"   data disk size, used, available in bytes
    \\              --health TEXT    deploy/health.sh output
    \\
;

pub fn cmdAdmin(c: *Cmd) !u8 {
    const now = std.Io.Clock.real.now(c.init.io).toSeconds();
    var o: admin.Options = .{ .out_dir = "", .data_dir = c.data_dir, .crawl_log = "", .now_s = now };
    var out: ?[]const u8 = null;
    var log_path: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--log")) {
            log_path = try c.value();
        } else if (c.is("--days")) {
            o.days = try c.int(u32);
        } else if (c.is("--disk")) {
            var words = std.mem.tokenizeScalar(u8, try c.value(), ' ');
            var d: [3]u64 = undefined;
            for (&d) |*x| x.* = std.fmt.parseInt(u64, words.next() orelse return error.Usage, 10) catch return error.Usage;
            o.disk = d;
        } else if (c.is("--health")) {
            o.health = try c.value();
        } else return error.Usage;
    }
    o.out_dir = out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "admin" });
    o.crawl_log = log_path orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "crawl.log" });
    const db = try store.open(c.init.gpa, c.data_dir);
    defer db.close();
    try admin.generate(c.init.gpa, c.init.io, db, o);
    return 0;
}
