//! /admin/api/ in `meiolol render`: live data, log tails and a few fixed actions for the
//! admin page (src/site/static/admin.js). nginx asks for the basic auth password and adds
//! X-Meiolol-Admin with the token in admin.token (cwd); without exactly that token, a
//! request here is answered as if these routes did not exist. docs/hosting.md

const std = @import("std");
const store = @import("store");
const admin = @import("admin.zig");
const date = @import("date.zig");

const Io = std.Io;
const Request = std.http.Server.Request;
const log = std.log.scoped(.admin_api);

const prefix = "/admin/api/";
const token_file = "admin.token";
const token_len = 64;
const live_cache_s = 30;
const health_cache_s = 120;
/// An action lock older than this was left by a crash
const lock_stale_s = 600;
const lock_file = "admin-action.lock";

pub const Api = struct {
    gpa: std.mem.Allocator,
    io: Io,
    data_dir: []const u8,
    mutex: Io.Mutex = .init,
    /// gpa-owned
    live: ?[]u8 = null,
    live_at: i64 = 0,
    health: ?[]u8 = null,
    health_at: i64 = 0,

    pub fn deinit(api: *Api) void {
        if (api.live) |l| api.gpa.free(l);
        if (api.health) |h| api.gpa.free(h);
    }
};

/// Answers an authorised /admin/api/ request and returns true; false for anything else,
/// which the caller then handles like any other request
pub fn handle(api: *Api, request: *Request) !bool {
    const target = request.head.target;
    if (!std.mem.startsWith(u8, target, prefix)) return false;
    var token_buf: [256]u8 = undefined;
    const token = Io.Dir.cwd().readFile(api.io, token_file, &token_buf) catch null;
    if (!authorised(token, header(request, "x-meiolol-admin"))) return false;

    const path = target[prefix.len .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];
    const query = if (std.mem.indexOfScalar(u8, target, '?')) |q| target[q + 1 ..] else "";
    if (std.mem.startsWith(u8, path, "action/")) {
        // A bodyless POST has neither length nor encoding; respond() asserts on one
        if (request.head.transfer_encoding == .none and request.head.content_length == null) {
            request.head.content_length = 0;
        }
        if (request.head.method != .POST) return reply(request, .method_not_allowed, "text/plain; charset=utf-8", "method not allowed\n");
        const flag = header(request, "x-meiolol-action") orelse "";
        if (!std.mem.eql(u8, flag, "1")) return reply(request, .forbidden, "text/plain; charset=utf-8", "forbidden\n");
        const action = find(path["action/".len..]) orelse return reply(request, .not_found, "text/plain; charset=utf-8", "not found\n");
        try runAction(api, request, action);
        return true;
    }
    if (request.head.method != .GET) {
        if (request.head.transfer_encoding == .none and request.head.content_length == null) {
            request.head.content_length = 0;
        }
        return reply(request, .method_not_allowed, "text/plain; charset=utf-8", "method not allowed\n");
    }
    if (std.mem.eql(u8, path, "live.json")) {
        var arena_state: std.heap.ArenaAllocator = .init(api.gpa);
        defer arena_state.deinit();
        return reply(request, .ok, "application/json", try liveJson(api, arena_state.allocator()));
    }
    if (std.mem.eql(u8, path, "log")) {
        var arena_state: std.heap.ArenaAllocator = .init(api.gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        const q = parseLogQuery(query) orelse return reply(request, .not_found, "text/plain; charset=utf-8", "not found\n");
        const file = try std.fmt.allocPrint(arena, "{s}/{s}.log", .{ api.data_dir, q.file });
        return reply(request, .ok, "text/plain; charset=utf-8", try logTail(arena, api.io, file, q.lines));
    }
    return reply(request, .not_found, "text/plain; charset=utf-8", "not found\n");
}

fn reply(request: *Request, status: std.http.Status, content_type: []const u8, body: []const u8) !bool {
    try request.respond(body, .{ .status = status, .extra_headers = &.{
        .{ .name = "content-type", .value = content_type },
        .{ .name = "cache-control", .value = "no-store" },
    } });
    return true;
}

/// The header's value; null when absent or sent more than once
fn header(request: *Request, name: []const u8) ?[]const u8 {
    var found: ?[]const u8 = null;
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, name)) continue;
        if (found != null) return null;
        found = h.value;
    }
    return found;
}

/// The token file holds 64 hex characters (and maybe a newline); anything else, or no
/// file, authorises nothing. Constant time in the token's contents
fn authorised(file: ?[]const u8, sent: ?[]const u8) bool {
    const want = std.mem.trim(u8, file orelse return false, " \t\r\n");
    const got = sent orelse return false;
    if (want.len != token_len or got.len != token_len) return false;
    for (want) |c| if (!std.ascii.isHex(c)) return false;
    return std.crypto.timing_safe.eql([token_len]u8, want[0..token_len].*, got[0..token_len].*);
}

const log_files = [_][]const u8{ "crawl", "web", "eval", "render", "health", "backup", "builds" };

const LogQuery = struct { file: []const u8, lines: usize };

/// file= from log_files (required), lines= 1 to 2000 (default 300)
fn parseLogQuery(query: []const u8) ?LogQuery {
    var q: LogQuery = .{ .file = "", .lines = 300 };
    var file: ?[]const u8 = null;
    var params = std.mem.splitScalar(u8, query, '&');
    while (params.next()) |p| {
        const eq = std.mem.indexOfScalar(u8, p, '=') orelse continue;
        const value = p[eq + 1 ..];
        if (std.mem.eql(u8, p[0..eq], "file")) {
            for (log_files) |f| if (std.mem.eql(u8, value, f)) {
                file = f;
            };
        } else if (std.mem.eql(u8, p[0..eq], "lines")) {
            const n = std.fmt.parseInt(usize, value, 10) catch continue;
            q.lines = std.math.clamp(n, 1, 2000);
        }
    }
    q.file = file orelse return null;
    return q;
}

/// The last `n` lines of a log, each redacted (admin.redact)
fn logTail(arena: std.mem.Allocator, io: Io, path: []const u8, n: usize) ![]const u8 {
    const text = std.mem.trimEnd(u8, try admin.tail(arena, io, path, n), "\n");
    if (text.len == 0) return "";
    var out: std.ArrayList(u8) = .empty;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        try out.appendSlice(arena, try admin.redact(arena, line));
        try out.append(arena, '\n');
    }
    return out.items;
}

/// Fixed commands only: nothing from the request reaches them
const Action = struct { name: []const u8, argv: []const []const u8 };

/// As deploy/web-loop.sh's daily eval, and under the same lock: two at once would both
/// write eval-latest.md.new and append to eval-history.tsv
const eval_command = "exec 9> data/eval.lock && flock -n 9 " ++
    "&& nice -n 10 bin/meiolol eval --platform all --test-platform EUW1 " ++
    "--history data/eval-history.tsv > data/eval-latest.md.new 2> data/eval.log " ++
    "&& mv data/eval-latest.md.new data/eval-latest.md";

const actions = [_]Action{
    .{ .name = "crawl-start", .argv = &.{ "systemctl", "--user", "enable", "--now", "meiolol-crawl" } },
    .{ .name = "crawl-stop", .argv = &.{ "systemctl", "--user", "disable", "--now", "meiolol-crawl" } },
    .{ .name = "crawl-restart", .argv = &.{ "systemctl", "--user", "restart", "meiolol-crawl" } },
    .{ .name = "site-build", .argv = &.{ "systemctl", "--user", "kill", "-s", "USR1", "--kill-whom=main", "meiolol-web" } },
    .{ .name = "eval-run", .argv = &.{ "systemd-run", "--user", "--collect", "--same-dir", "--unit", "meiolol-eval-now", "/bin/sh", "-c", eval_command } },
    .{ .name = "health-check", .argv = &.{"bin/health.sh"} },
};

fn find(name: []const u8) ?Action {
    for (actions) |a| if (std.mem.eql(u8, a.name, name)) return a;
    return null;
}

const Outcome = enum { ok, failed, refused };

fn runAction(api: *Api, request: *Request, action: Action) !void {
    const io = api.io;
    var arena_state: std.heap.ArenaAllocator = .init(api.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const now = Io.Clock.real.now(io).toSeconds();
    const lock_path = try std.fs.path.join(arena, &.{ api.data_dir, lock_file });

    var outcome: Outcome = .refused;
    var output: []const u8 = "";
    if (try takeLock(io, lock_path, action.name, now)) {
        defer Io.Dir.cwd().deleteFile(io, lock_path) catch {};
        const is_eval = std.mem.eql(u8, action.name, "eval-run");
        if (is_eval and noEval()) {
            output = "MEIOLOL_NO_EVAL is set (host.env): this box doesn't run evals";
        } else if (is_eval and try evalSince(arena, io, now) != null) {
            output = "an eval is already running";
        } else {
            const ran = run(arena, io, action.argv);
            outcome = if (ran.ok) .ok else .failed;
            output = ran.output;
        }
    } else output = "another action is running";
    log.info("action {s}: {t}", .{ action.name, outcome });
    appendActionLog(arena, io, try std.fs.path.join(arena, &.{ api.data_dir, admin.action_log }), now, action.name, outcome, output) catch |err| {
        log.warn("action log: {t}", .{err});
    };
    // A new action shows in live.json at once
    api.mutex.lockUncancelable(io);
    api.live_at = 0;
    api.mutex.unlock(io);
    const body = try std.json.Stringify.valueAlloc(arena, .{ .ok = outcome == .ok, .output = output }, .{});
    _ = try reply(request, if (outcome == .refused) .conflict else .ok, "application/json", body);
}

/// One action at a time across both renderer instances: the lock file holds the name and
/// start. False when another holds it
fn takeLock(io: Io, path: []const u8, name: []const u8, now: i64) !bool {
    for (0..2) |_| {
        var file = Io.Dir.cwd().createFile(io, path, .{ .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => {
                const st = Io.Dir.cwd().statFile(io, path, .{}) catch continue;
                if (now - st.mtime.toSeconds() < lock_stale_s) return false;
                Io.Dir.cwd().deleteFile(io, path) catch {};
                continue;
            },
            else => return err,
        };
        defer file.close(io);
        var buf: [128]u8 = undefined;
        var w = file.writer(io, &buf);
        try w.interface.print("{s}\t{d}\n", .{ name, now });
        try w.interface.flush();
        return true;
    }
    return false;
}

/// The lock's holder, for live.json
fn runningAction(arena: std.mem.Allocator, io: Io, path: []const u8) ?admin.RunningAction {
    var buf: [128]u8 = undefined;
    const text = Io.Dir.cwd().readFile(io, path, &buf) catch return null;
    var f = std.mem.splitScalar(u8, std.mem.trimEnd(u8, text, "\n"), '\t');
    const name = arena.dupe(u8, f.next() orelse return null) catch return null;
    const since = std.fmt.parseInt(i64, f.next() orelse return null, 10) catch return null;
    return .{ .name = name, .since = since };
}

const Ran = struct { ok: bool, output: []const u8 };

fn run(arena: std.mem.Allocator, io: Io, argv: []const []const u8) Ran {
    const r = std.process.run(arena, io, .{
        .argv = argv,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
        .timeout = .{ .duration = .{ .raw = .fromSeconds(60), .clock = .awake } },
    }) catch |err| return .{ .ok = false, .output = @errorName(err) };
    const out = std.mem.trim(u8, std.mem.concat(arena, u8, &.{ r.stdout, r.stderr }) catch r.stdout, " \n");
    return .{ .ok = r.term.success(), .output = out };
}

fn appendActionLog(arena: std.mem.Allocator, io: Io, path: []const u8, now: i64, name: []const u8, outcome: Outcome, output: []const u8) !void {
    const short = output[0..@min(output.len, 200)];
    const one_line = try std.mem.replaceOwned(u8, arena, short, "\n", " / ");
    std.mem.replaceScalar(u8, one_line, '\t', ' ');
    var file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = false });
    defer file.close(io);
    const len = try file.length(io);
    var buf: [512]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.seekTo(len);
    const d = date.Date.fromSeconds(now);
    const s: u64 = @intCast(@mod(now, 86400));
    try fw.interface.print("{f}T{d:0>2}:{d:0>2}:{d:0>2}Z\t{s}\t{t}\t{s}\n", .{ d, s / 3600, s / 60 % 60, s % 60, name, outcome, one_line });
    try fw.interface.flush();
}

/// MEIOLOL_NO_EVAL (host.env, the render unit's EnvironmentFile), as web-loop.sh reads it
fn noEval() bool {
    const v = std.c.getenv("MEIOLOL_NO_EVAL") orelse return false;
    return std.mem.span(v).len > 0;
}

/// When a `meiolol eval` started (ps), null when none runs
fn evalSince(arena: std.mem.Allocator, io: Io, now: i64) !?i64 {
    const r = run(arena, io, &.{ "ps", "-eo", "etimes=,args=" });
    if (!r.ok) return null;
    var lines = std.mem.splitScalar(u8, r.output, '\n');
    while (lines.next()) |line| {
        var words = std.mem.tokenizeScalar(u8, line, ' ');
        const age = std.fmt.parseInt(i64, words.next() orelse continue, 10) catch continue;
        if (std.mem.startsWith(u8, words.rest(), "bin/meiolol eval")) return now - age;
    }
    return null;
}

/// Cached live_cache_s; one build at a time
fn liveJson(api: *Api, arena: std.mem.Allocator) ![]const u8 {
    const io = api.io;
    api.mutex.lockUncancelable(io);
    defer api.mutex.unlock(io);
    const now = Io.Clock.real.now(io).toSeconds();
    if (api.live) |l| if (now - api.live_at < live_cache_s) return arena.dupe(u8, l);

    if (api.health == null or now - api.health_at >= health_cache_s) {
        const h = run(arena, io, &.{"bin/health.sh"});
        if (api.health) |old| api.gpa.free(old);
        api.health = try api.gpa.dupe(u8, h.output);
        api.health_at = now;
    }
    const l: admin.Live = .{
        .data_dir = api.data_dir,
        .now_s = now,
        .health = api.health.?,
        .services = services(arena, io),
        .disk = disk(arena, io, api.data_dir),
        .eval_since = try evalSince(arena, io, now),
        .action = runningAction(arena, io, try std.fs.path.join(arena, &.{ api.data_dir, lock_file })),
    };
    const db = try store.schema.openReadOnly(api.gpa, api.data_dir);
    defer db.close();
    const json = try admin.liveJson(arena, io, db, l);
    if (api.live) |old| api.gpa.free(old);
    api.live = try api.gpa.dupe(u8, json);
    api.live_at = now;
    return json;
}

fn services(arena: std.mem.Allocator, io: Io) admin.Services {
    var s: admin.Services = .{};
    const fields = comptime std.meta.fieldNames(admin.Services);
    var argv: [3 + fields.len][]const u8 = undefined;
    argv[0..3].* = .{ "systemctl", "--user", "is-active" };
    inline for (fields, 3..) |f, i| argv[i] = f;
    // Non-zero when any is inactive; the states are on stdout either way
    const r = std.process.run(arena, io, .{
        .argv = &argv,
        .stdout_limit = .limited(4096),
        .stderr_limit = .limited(4096),
        .timeout = .{ .duration = .{ .raw = .fromSeconds(10), .clock = .awake } },
    }) catch return s;
    var lines = std.mem.splitScalar(u8, r.stdout, '\n');
    inline for (fields) |f| @field(s, f) = lines.next() orelse "unknown";
    return s;
}

/// `df -B1` of the data directory: size, used, available
fn disk(arena: std.mem.Allocator, io: Io, data_dir: []const u8) ?[3]u64 {
    const r = run(arena, io, &.{ "df", "-B1", "--output=size,used,avail", data_dir });
    if (!r.ok) return null;
    const last = r.output[(std.mem.lastIndexOfScalar(u8, r.output, '\n') orelse return null) + 1 ..];
    var words = std.mem.tokenizeScalar(u8, last, ' ');
    var d: [3]u64 = undefined;
    for (&d) |*x| x.* = std.fmt.parseInt(u64, words.next() orelse return null, 10) catch return null;
    return d;
}

const testing = std.testing;

test "admin token" {
    const t = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    try testing.expect(authorised(t ++ "\n", t));
    try testing.expect(!authorised(t, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdee"));
    try testing.expect(!authorised(null, t));
    try testing.expect(!authorised(t, null));
    try testing.expect(!authorised(t, t[0..63]));
    try testing.expect(!authorised("", ""));
    // Not hex, or not 64: no token at all
    try testing.expect(!authorised("g" ++ t[1..], "g" ++ t[1..]));
    try testing.expect(!authorised(t ++ "00", t ++ "00"));
}

test "admin routes" {
    try testing.expect(find("crawl-restart") != null);
    try testing.expect(find("crawl-restart; rm -rf /") == null);
    try testing.expect(find("../crawl-start") == null);
    try testing.expect(find("") == null);
    const q = parseLogQuery("file=crawl&lines=50").?;
    try testing.expectEqualStrings("crawl", q.file);
    try testing.expectEqual(50, q.lines);
    try testing.expectEqual(300, parseLogQuery("file=web").?.lines);
    try testing.expectEqual(2000, parseLogQuery("file=web&lines=99999").?.lines);
    try testing.expectEqual(null, parseLogQuery("file=../meiolol.db"));
    try testing.expectEqual(null, parseLogQuery("file=crawl.log"));
    try testing.expectEqual(null, parseLogQuery("lines=5"));
}

test "admin log tail redacted" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "crawl.log", .data = "2026-10-12 20:00:00 one\n" ++
        "2026-10-12 20:01:00 info(crawl): 174204 matches/day | europe 13840m\n" ++
        "2026-10-12 20:02:00 warning(riot): 500 (server) on /lol/match/v5/matches/by-puuid/-3uog-_IosuG5ssbfFVk1cyKUZg0/ids\n" ++
        "2026-10-12 20:03:00 warning(riot): 503 on /lol/match/v5/matches/EUW1_7123456 for Faker#KR1, puzzle #1\n" });
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const path = try std.fs.path.join(arena_state.allocator(), &.{ ".zig-cache", "tmp", &tmp.sub_path, "crawl.log" });
    const text = try logTail(arena_state.allocator(), io, path, 3);
    try testing.expectEqualStrings("2026-10-12 20:01:00 info(crawl): 174204 matches/day | europe 13840m\n" ++
        "2026-10-12 20:02:00 warning(riot): 500 (server) on /lol/match/v5/matches/by-puuid/…/ids\n" ++
        "2026-10-12 20:03:00 warning(riot): 503 on /lol/match/v5/matches/… …, puzzle #1\n", text);
    try testing.expectEqualStrings("", try logTail(arena_state.allocator(), io, "no/such.log", 3));
}

test "admin action lock and log" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    const lock = try std.fs.path.join(arena, &.{ dir, lock_file });
    const now = Io.Clock.real.now(io).toSeconds();
    try testing.expect(try takeLock(io, lock, "crawl-restart", now));
    try testing.expect(!try takeLock(io, lock, "site-build", now));
    const held = runningAction(arena, io, lock).?;
    try testing.expectEqualStrings("crawl-restart", held.name);
    try testing.expectEqual(now, held.since);
    // Stale: taken over
    try testing.expect(try takeLock(io, lock, "site-build", now + lock_stale_s + 1));

    const path = try std.fs.path.join(arena, &.{ dir, admin.action_log });
    try appendActionLog(arena, io, path, 1760224200, "health-check", .failed, "crawler silent\tlong\nsite stale");
    const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(4096));
    try testing.expectEqualStrings("2025-10-11T23:10:00Z\thealth-check\tfailed\tcrawler silent long / site stale\n", text);
}
