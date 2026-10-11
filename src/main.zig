//! `meiolol`: backend. Crawls EUW ranked solo games from the Riot API into SQLite
//! and builds the model file the app reads. Runs on the gpu-box PC (deploy/box.sh).

const std = @import("std");
const store = @import("store");
const core = @import("core");
pub const riot = @import("riot/root.zig");
pub const ddragon = @import("ddragon.zig");
pub const stats = @import("stats.zig");
pub const site = @import("site/root.zig");
pub const serve = @import("serve.zig");

pub const std_options: std.Options = .{ .logFn = logFn };

const usage =
    \\usage: meiolol <command> [options]
    \\
    \\commands:
    \\  crawl       crawl EUW ranked solo games (needs RIOT_API_KEY in env or .env)
    \\              --hours H        stop after H hours (default: run until stopped)
    \\              --since-days N   how far back to collect match ids (default 14)
    \\              --no-mastery     skip champion mastery
    \\  stats       write the model file the app reads (ranked solo, no remakes)
    \\              --patch P        patch to include, repeatable or comma separated
    \\                               (default: the newest patch)
    \\              --out FILE       default DIR/export/stats-<patch>.bin
    \\  site        write the public website (static files)
    \\              --patch P        as for stats
    \\              --out DIR        default DIR/site
    \\              --contact EMAIL  shown on the privacy and terms pages (required)
    \\              --riot-txt TEXT  served as /riot.txt (Riot's verification string)
    \\              --public         listed for search engines, no preview banner; only
    \\                               once Riot grants the production key
    \\  serve       serve the website (default DIR/site) over HTTP, for the tunnel
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8080
    \\              --out DIR        site directory to serve
    \\  status      row counts and crawl queue state
    \\  champions   refresh champion ids and names from Data Dragon
    \\
    \\options for all commands:
    \\  --data DIR  data directory (default $MEIOLOL_DATA or ./data)
    \\
    \\exit codes: 0 ok, 1 error, 2 bad usage, 3 Riot rejected the API key
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 2) return usageError(null);

    var data_dir: []const u8 = init.environ_map.get("MEIOLOL_DATA") orelse "data";
    var hours: ?f64 = null;
    var since_days: i64 = 14;
    var mastery = true;
    var patches: std.ArrayList([]const u8) = .empty;
    var out_path: ?[]const u8 = null;
    var contact: ?[]const u8 = null;
    var riot_txt: ?[]const u8 = null;
    var public = false;
    var host: []const u8 = "127.0.0.1";
    var port: u16 = 8080;
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--no-mastery")) {
            mastery = false;
            continue;
        }
        if (std.mem.eql(u8, a, "--public")) {
            public = true;
            continue;
        }
        if (i + 1 >= args.len) return usageError(a);
        const v = args[i + 1];
        i += 1;
        if (std.mem.eql(u8, a, "--data")) {
            data_dir = v;
        } else if (std.mem.eql(u8, a, "--hours")) {
            hours = std.fmt.parseFloat(f64, v) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--since-days")) {
            since_days = std.fmt.parseInt(i64, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--patch")) {
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |p| try patches.append(arena, p);
        } else if (std.mem.eql(u8, a, "--out")) {
            out_path = v;
        } else if (std.mem.eql(u8, a, "--contact")) {
            contact = v;
        } else if (std.mem.eql(u8, a, "--host")) {
            host = v;
        } else if (std.mem.eql(u8, a, "--port")) {
            port = std.fmt.parseInt(u16, v, 10) catch return usageError(a);
        } else if (std.mem.eql(u8, a, "--riot-txt")) {
            riot_txt = v;
        } else return usageError(a);
    }
    try std.Io.Dir.cwd().createDirPath(init.io, data_dir);

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "crawl")) {
        const key = try apiKey(init, arena) orelse {
            std.log.err("RIOT_API_KEY not set (env or .env)", .{});
            return 1;
        };
        var crawler: riot.crawl.Crawler = .{ .gpa = init.gpa, .io = init.io, .opts = .{
            .data_dir = data_dir,
            .key = key,
            .since_days = since_days,
            .mastery = mastery,
            .hours = hours,
        } };
        crawler.run() catch |err| switch (err) {
            error.KeyRejected => return 3,
            else => return err,
        };
        return 0;
    }
    if (std.mem.eql(u8, cmd, "stats")) {
        try writeStats(init.gpa, init.io, arena, data_dir, patches.items, out_path);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "site")) {
        const email = contact orelse return usageError("--contact");
        const db = try store.open(init.gpa, data_dir);
        defer db.close();
        const chosen = if (patches.items.len > 0) patches.items else try newestPatch(arena, db);
        try site.generate(init.gpa, init.io, db, .{
            .out_dir = out_path orelse try std.fs.path.join(arena, &.{ data_dir, "site" }),
            .patches = chosen,
            .contact = email,
            .riot_txt = riot_txt,
            .updated = try today(arena, init.io),
            .public = public,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "serve")) {
        const dir = out_path orelse try std.fs.path.join(arena, &.{ data_dir, "site" });
        try serve.run(init.gpa, init.io, dir, host, port);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "status")) {
        try status(init.gpa, init.io, data_dir);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "champions")) {
        const db = try store.open(init.gpa, data_dir);
        defer db.close();
        const n = try ddragon.refresh(init.gpa, init.io, db);
        std.log.info("{d} champions", .{n});
        return 0;
    }
    return usageError(cmd);
}

fn usageError(arg: ?[]const u8) u8 {
    if (arg) |a| std.log.err("unexpected or incomplete argument: {s}", .{a});
    std.debug.print("{s}", .{usage});
    return 2;
}

/// RIOT_API_KEY from the environment, else from ./.env
fn apiKey(init: std.process.Init, arena: std.mem.Allocator) !?[]const u8 {
    if (init.environ_map.get("RIOT_API_KEY")) |k| return k;
    const text = std.Io.Dir.cwd().readFileAlloc(init.io, ".env", arena, .limited(64 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    var lines = std.mem.tokenizeAny(u8, text, "\r\n");
    while (lines.next()) |line| {
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        if (std.mem.eql(u8, std.mem.trim(u8, line[0..eq], " "), "RIOT_API_KEY")) {
            return std.mem.trim(u8, line[eq + 1 ..], " \"'");
        }
    }
    return null;
}

fn writeStats(
    gpa: std.mem.Allocator,
    io: std.Io,
    arena: std.mem.Allocator,
    data_dir: []const u8,
    wanted: []const []const u8,
    out_path: ?[]const u8,
) !void {
    const db = try store.open(gpa, data_dir);
    defer db.close();
    const chosen = if (wanted.len > 0) wanted else try newestPatch(arena, db);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    const path = out_path orelse
        try std.fmt.allocPrint(arena, "{s}/export/stats-{s}.bin", .{ data_dir, label });

    var r = try stats.build(gpa, db, chosen);
    defer r.builder.deinit();
    if (r.summary.games == 0) {
        std.log.err("no complete ranked solo games on patch {s}", .{label});
        return error.NoMatches;
    }

    const cwd = std.Io.Dir.cwd();
    var file = try cwd.createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try r.builder.write(&w.interface, label);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}: patch {s}, {d} games ({d} skipped), {d} champions", .{
        path, label, r.summary.games, r.summary.skipped, r.builder.ids.len,
    });
}

fn newestPatch(arena: std.mem.Allocator, db: store.Db) ![]const []const u8 {
    const all = try stats.patches(arena, db);
    if (all.len == 0) return error.NoMatches;
    return all[0..1];
}

/// "11 October 2026", UTC
fn today(arena: std.mem.Allocator, io: std.Io) ![]const u8 {
    const secs: u64 = @intCast(std.Io.Clock.real.now(io).toSeconds());
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = secs };
    const day = epoch.getEpochDay().calculateYearDay();
    const md = day.calculateMonthDay();
    const months = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
    return std.fmt.allocPrint(arena, "{d} {s} {d}", .{ md.day_index + 1, months[md.month.numeric() - 1], day.year });
}

fn status(gpa: std.mem.Allocator, io: std.Io, data_dir: []const u8) !void {
    const db = try store.open(gpa, data_dir);
    defer db.close();
    var buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const out = &stdout.interface;
    inline for (.{ "players", "ladder_pages", "match_queue", "matches", "participants", "bans", "mastery", "champions", "raw.raw_docs" }) |t| {
        try out.print("{s}: {d}\n", .{ t, try db.scalar("SELECT count(*) FROM " ++ t, .{}) orelse 0 });
    }
    var q = try db.prepare("SELECT status, count(*) FROM match_queue GROUP BY 1 ORDER BY 1");
    defer q.deinit();
    try q.bind(.{});
    try out.writeAll("queue:");
    while (try q.step()) try out.print(" {s}={d}", .{ q.bytes(0), q.int(1) });
    var p = try db.prepare("SELECT patch, count(*) FROM matches GROUP BY 1 ORDER BY 1 DESC LIMIT 6");
    defer p.deinit();
    try p.bind(.{});
    try out.writeAll("\nby patch:");
    while (try p.step()) try out.print(" {s}={d}", .{ p.bytes(0), p.int(1) });
    try out.writeAll("\n");
    try out.flush();
}

/// Default log format plus a UTC timestamp, for the crawl log on the box
fn logFn(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    const io = std.Options.debug_io;
    const secs: u64 = @intCast(std.Io.Clock.real.now(io).toSeconds());
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = secs };
    const day = epoch.getEpochDay().calculateYearDay();
    const md = day.calculateMonthDay();
    const ds = epoch.getDaySeconds();
    var buffer: [64]u8 = undefined;
    const stderr = std.debug.lockStderr(&buffer).terminal();
    defer std.debug.unlockStderr();
    stderr.writer.print("{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2} ", .{
        day.year,             md.month.numeric(),      md.day_index + 1,
        ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
    }) catch {};
    std.log.defaultLogFileTerminal(level, scope, format, args, stderr) catch {};
}

test {
    std.testing.refAllDecls(@This());
}
