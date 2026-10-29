//! The admin page's deploys from deploys.tsv (docs/hosting.md "Deploy events"): events
//! grouped by commit into one deploy each, its steps' times and results, its state, when
//! it went live, and the usual times a running one is measured by
const std = @import("std");
const ad = @import("admindata.zig");
const st = @import("steptimeline.zig");

pub const Key = enum { ci, deploy, build, web, crawl, site, upload, views, reload, swap, cache };

pub const names = std.enums.EnumArray(Key, []const u8).init(.{
    .ci = "Push check",
    .deploy = "Deploy",
    .build = "Build and copy",
    .web = "Web loop",
    .crawl = "Crawler restart",
    .site = "Site build",
    .upload = "Upload",
    .views = "Views file",
    .reload = "Renderer reload",
    .swap = "Renderer swap",
    .cache = "Live on site",
});

pub const whats = std.enums.EnumArray(Key, []const u8).init(.{
    .ci = "zig build ci on the Mac, before the push",
    .deploy = "on-push.sh runs deploy/box.sh web start",
    .build = "clean checkout, cross-compile, binary and scripts to the box",
    .web = "signalled (or restarted) for a round with the new binary",
    .crawl = "only when the deploy changed src/riot or src/store",
    .site = "the deploy round's static core build",
    .upload = "static core to the web server: home page, CSS, JS, sitemap",
    .views = "every view into views.bin; only the parts the deploy changed load again",
    .reload = "the running renderer reads the new views file",
    .swap = "new renderer serving the new code, old one stopped",
    .cache = "nginx cache key moved to the new renderer's data",
});

pub const Step = struct {
    state: st.StepState,
    start: ?i64,
    end: ?i64 = null,
    detail: []const u8 = "",

    fn took(s: Step) ?i64 {
        return if (s.start != null and s.end != null) s.end.? - s.start.? else null;
    }
};

pub const Deploy = struct {
    sha: []const u8,
    start: i64,
    steps: std.enums.EnumArray(Key, ?Step) = .initFill(null),
    /// "sha subject", the latest attempt's
    commits: []const []const u8 = &.{},
    state: st.State = .running,
    /// The swap waited for a views file in a new format; null before the swap began
    waited: ?bool = null,
    /// The later of the static upload and the renderer's cache key
    live: ?i64 = null,

    pub fn subject(d: Deploy) []const u8 {
        if (d.commits.len == 0) return "";
        const c = d.commits[0];
        const sp = std.mem.findScalar(u8, c, ' ') orelse return "";
        return c[sp + 1 ..];
    }

    fn doneAt(d: Deploy, k: Key) ?i64 {
        const s = d.steps.get(k) orelse return null;
        return if (s.state == .done) s.end else null;
    }
};

fn is(e: ad.DeployEvent, step: []const u8, status: []const u8) bool {
    return std.mem.eql(u8, e.step, step) and std.mem.eql(u8, e.status, status);
}

fn ended(status: []const u8) ?st.StepState {
    if (std.mem.eql(u8, status, "ok")) return .done;
    if (std.mem.eql(u8, status, "failed")) return .failed;
    if (std.mem.eql(u8, status, "skipped")) return .skipped;
    return null;
}

/// When `step` first went ok in all of `evs`
fn since(evs: []const ad.DeployEvent, step: []const u8) i64 {
    for (evs) |e| if (is(e, step, "ok")) return e.time;
    return std.math.maxInt(i64);
}

/// One commit's events, oldest first
const Group = struct {
    evs: []const ad.DeployEvent,
    d: *Deploy,

    /// A step's start, end and result from its events from `from` on. One with no events
    /// yet runs from `start_of` once `begun` (the round's site build, the upload after it)
    fn step(g: Group, k: Key, from: i64, start_of: ?i64, begun: bool) ?Step {
        var begin: ?ad.DeployEvent = null;
        var end: ?ad.DeployEvent = null;
        var last: ?ad.DeployEvent = null;
        for (g.evs) |e| {
            if (e.time < from or !std.mem.eql(u8, e.step, @tagName(k))) continue;
            last = e;
            if (end == null and ended(e.status) != null) end = e;
            if (begin == null and (std.mem.eql(u8, e.status, "start") or std.mem.eql(u8, e.status, "waiting"))) begin = e;
        }
        const s0 = if (begin) |b| b.time else start_of;
        const s: ?Step = if (end) |e|
            .{ .state = ended(e.status).?, .start = s0, .end = e.time, .detail = e.detail }
        else if (begin) |b|
            .{ .state = if (std.mem.eql(u8, b.status, "waiting")) .waiting else .running, .start = s0, .detail = last.?.detail }
        else if (begun and start_of != null)
            .{ .state = .running, .start = start_of }
        else
            null;
        if (s != null) g.d.steps.set(k, s);
        return s;
    }

    fn endOf(s: ?Step) ?i64 {
        return if (s) |x| x.end else null;
    }
};

/// on-push.sh keeps the first 2,000 characters of "sha subject" (200 before 17 Oct 2026)
fn cut(s: []const u8) bool {
    return s.len >= 2000 or s.len == 200;
}

/// Every commit's deploy, newest first. `evs` oldest first, as deploys.tsv
pub fn list(a: std.mem.Allocator, evs: []const ad.DeployEvent) ![]Deploy {
    // Live meant the cache key from its first use (16 Oct), before that the renderer
    // swap (14 Oct), before that the upload
    const cache_from = since(evs, "cache");
    const swap_from = since(evs, "swap");
    var shas: std.StringArrayHashMapUnmanaged(std.ArrayList(ad.DeployEvent)) = .empty;
    for (evs) |e| {
        const g = try shas.getOrPut(a, e.sha);
        if (!g.found_existing) g.value_ptr.* = .empty;
        try g.value_ptr.append(a, e);
    }
    var out: std.ArrayList(Deploy) = .empty;
    for (shas.keys(), shas.values()) |sha, l| {
        const xs = l.items;
        // A re-run of the same commit (by hand, or a retry after a failure) starts its
        // own attempt: the steps and commits are the latest attempt's
        var dep: ?ad.DeployEvent = null;
        var first_dep: ?ad.DeployEvent = null;
        var prev_start: ?i64 = null;
        var ci: ?ad.DeployEvent = null;
        var ci_failed = false;
        for (xs) |e| {
            if (std.mem.eql(u8, e.step, "ci")) {
                if (ci == null) ci = e;
                ci_failed = ci_failed or std.mem.eql(u8, e.status, "failed");
            }
            if (!std.mem.eql(u8, e.step, "deploy")) continue;
            if (first_dep == null) first_dep = e;
            if (std.mem.eql(u8, e.status, "start")) {
                if (dep) |d| prev_start = d.time;
                dep = e;
            }
        }
        if (dep == null) dep = first_dep;
        if (dep == null and ci == null) continue;
        // on-push.sh sends the commits just before its deploy start
        const after = prev_start orelse std.math.minInt(i64);
        const start = (dep orelse ci.?).time;
        try out.append(a, .{ .sha = sha, .start = start });
        const d = &out.items[out.items.len - 1];
        const g: Group = .{ .evs = xs, .d = d };
        if (ci) |c| _ = g.step(.ci, c.time, null, false);
        if (dep != null) {
            _ = g.step(.deploy, start, null, false);
            const build = g.step(.build, start, start, false);
            _ = g.step(.web, start, Group.endOf(build), false);
            _ = g.step(.crawl, start, null, false);
            // The deploy's round: the first forced round after the deploy began
            for (xs) |e| if (std.mem.eql(u8, e.step, "round") and e.time >= start) {
                const site = g.step(.site, e.time, e.time, true);
                _ = g.step(.upload, e.time, Group.endOf(site), true);
                const views = g.step(.views, e.time, null, false);
                _ = g.step(.reload, e.time, Group.endOf(views), false);
                break;
            };
            if (g.step(.swap, start, null, false)) |sw| if (sw.state == .done) {
                _ = g.step(.cache, sw.end.?, sw.end, false);
            };
        }
        var commits: std.ArrayList([]const u8) = .empty;
        for (xs) |e| if (std.mem.eql(u8, e.step, "commit") and e.time > after) {
            try commits.append(a, if (cut(e.detail)) try std.mem.concat(a, u8, &.{ e.detail, "…" }) else e.detail);
        };
        d.commits = commits.items;
        var failed = false;
        for (std.enums.values(Key)) |k| if (k != .cache) if (d.steps.get(k)) |s| {
            failed = failed or s.state == .failed;
        };
        var cache = d.doneAt(.cache);
        if (cache == null and start < cache_from) cache = if (start < swap_from) d.doneAt(.upload) else d.doneAt(.swap);
        d.state = if (dep == null)
            (if (ci_failed) .refused else .running)
        else if (d.steps.get(.deploy) != null and d.steps.get(.deploy).?.state == .skipped)
            .skipped
        else if (failed)
            .failed
        else if (cache != null)
            .live
        else
            .running;
        // Known once the swap has begun
        for (xs) |e| if (std.mem.eql(u8, e.step, "swap")) {
            d.waited = (d.waited orelse false) or std.mem.eql(u8, e.status, "waiting");
        };
        if (cache) |c| d.live = @max(c, d.doneAt(.upload) orelse 0);
    }
    std.mem.sort(Deploy, out.items, {}, struct {
        fn f(_: void, x: Deploy, y: Deploy) bool {
            return x.start > y.start;
        }
    }.f);
    // A newer deploy whose binary reached the box before this one went live replaced it;
    // a skipped one (binary unchanged, no round of its own) leaves this one running
    var built = false;
    for (out.items) |*d| {
        if (d.state == .running and built) d.state = .superseded;
        if (d.state != .skipped) if (d.steps.get(.build)) |b| {
            built = built or b.state == .done;
        };
    }
    return out.items;
}

/// Usual times from recent deploys that went live, to measure a running one by
pub const Usual = struct {
    /// Start to live, median
    total: ?i64 = null,
    /// Deploys the medians are over
    n: usize = 0,
    /// Over deploys like this one only: their swap waited for a views file, or not
    kind: bool = false,
    step: std.enums.EnumArray(Key, ?i64) = .initFill(null),
};

/// Deploys whose renderer waited for a new views file (a part's code changed) take
/// longer, so those are compared with their own kind when there are 2 or more
pub fn usual(all: []const Deploy, d: *const Deploy) Usual {
    var done: [12]*const Deploy = undefined;
    var n: usize = 0;
    for (all) |*x| if (x.state == .live and x != d and n < done.len) {
        done[n] = x;
        n += 1;
    };
    var same: [12]*const Deploy = undefined;
    var m: usize = 0;
    if (d.waited) |w| for (done[0..n]) |x| if (x.waited == w) {
        same[m] = x;
        m += 1;
    };
    const pool = if (m >= 2) same[0..m] else done[0..n];
    var u: Usual = .{ .n = pool.len, .kind = m >= 2 };
    var buf: [12]i64 = undefined;
    var k: usize = 0;
    for (pool) |x| if (x.live) |l| {
        buf[k] = l - x.start;
        k += 1;
    };
    u.total = median(buf[0..k]);
    for (std.enums.values(Key)) |key| {
        k = 0;
        for (pool) |x| if (x.steps.get(key)) |s| if (s.state == .done) if (s.took()) |t| {
            buf[k] = t;
            k += 1;
        };
        u.step.set(key, median(buf[0..k]));
    }
    return u;
}

fn median(xs: []i64) ?i64 {
    if (xs.len == 0) return null;
    std.mem.sort(i64, xs, {}, std.sort.asc(i64));
    const h = xs.len / 2;
    return if (xs.len % 2 == 1) xs[h] else @divFloor(xs[h - 1] + xs[h], 2);
}

/// The pills in the order the steps ran; steps not begun keep the pipeline's order after
/// them, as pending while the deploy runs, skipped once live, not reached otherwise. A
/// push check not recorded (--no-verify) has no pill, nor has a step a skipped or refused
/// deploy never had
pub fn steps(a: std.mem.Allocator, d: *const Deploy, now: i64, u: ?Usual) ![]st.Step {
    const only_had = d.state == .skipped or d.state == .refused;
    var order: std.ArrayList(Key) = .empty;
    for (std.enums.values(Key)) |k| {
        if ((k == .ci or only_had) and d.steps.get(k) == null) continue;
        try order.append(a, k);
    }
    std.mem.sort(Key, order.items, d, struct {
        fn at(dd: *const Deploy, k: Key) i64 {
            const s = dd.steps.get(k) orelse return std.math.maxInt(i64);
            return s.start orelse std.math.maxInt(i64);
        }
        fn f(dd: *const Deploy, x: Key, y: Key) bool {
            const ax = at(dd, x);
            const ay = at(dd, y);
            return ax < ay or (ax == ay and @backingInt(x) < @backingInt(y));
        }
    }.f);
    const out = try a.alloc(st.Step, order.items.len);
    for (order.items, out) |k, *o| {
        o.* = .{ .name = .{ .s = names.get(k) }, .what = whats.get(k), .state = switch (d.state) {
            .running => .pending,
            .live => .skipped,
            else => .none,
        } };
        const s = d.steps.get(k) orelse continue;
        o.state = s.state;
        o.detail = s.detail;
        if (s.start) |t0| o.took = @intCast(@max(0, (s.end orelse now) - t0));
        if (s.end == null) if (u) |x| if (x.step.get(k)) |t| {
            o.usual = @intCast(@max(0, t));
        };
    }
    return out;
}

const testing = std.testing;

fn ev(time: i64, sha: []const u8, step: []const u8, status: []const u8, detail: []const u8) ad.DeployEvent {
    return .{ .time = time, .sha = sha, .step = step, .status = status, .detail = detail };
}

/// A full deploy from push check to live, at t0, its steps each 10 s, live at t0 + 100
fn whole(t0: i64, sha: []const u8, swap_waits: bool) [16]ad.DeployEvent {
    return .{
        ev(t0 - 200, sha, "ci", "start", ""),
        ev(t0 - 10, sha, "ci", "ok", ""),
        ev(t0 - 1, sha, "commit", "info", "abc1234 Fix the thing"),
        ev(t0, sha, "deploy", "start", ""),
        ev(t0, sha, "build", "start", ""),
        ev(t0 + 10, sha, "build", "ok", "deployed"),
        ev(t0 + 20, sha, "web", "ok", "signalled"),
        ev(t0 + 21, sha, "deploy", "ok", ""),
        ev(t0 + 30, sha, "round", "start", ""),
        ev(t0 + 40, sha, "site", "ok", ""),
        ev(t0 + 50, sha, "upload", "ok", ""),
        ev(t0 + 60, sha, "views", "ok", "kept 3"),
        ev(t0 + 65, sha, "swap", if (swap_waits) "waiting" else "start", ""),
        ev(t0 + 70, sha, "reload", "ok", ""),
        ev(t0 + 90, sha, "swap", "ok", ""),
        ev(t0 + 100, sha, "cache", "ok", "k1"),
    };
}

test "list: a full deploy goes live, its steps timed, subject from its commit" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const evs = whole(1000, "aaaa", false);
    const l = try list(a, &evs);
    try testing.expectEqual(1, l.len);
    const d = l[0];
    try testing.expectEqual(st.State.live, d.state);
    try testing.expectEqual(1100, d.live.?);
    try testing.expectEqualStrings("Fix the thing", d.subject());
    try testing.expectEqual(false, d.waited.?);
    try testing.expectEqual(10, d.steps.get(.build).?.took().?);
    // The web loop's start is the build's end
    try testing.expectEqual(1010, d.steps.get(.web).?.start.?);
    try testing.expectEqual(1090, d.steps.get(.cache).?.start.?);
    try testing.expectEqual(null, d.steps.get(.crawl));
    const ps = try steps(a, &d, 2000, null);
    try testing.expectEqualStrings("Push check", ps[0].name.s);
    // Steps with no start event (views: only its ok) and not begun (crawl) come last
    try testing.expectEqualStrings("Crawler restart", ps[ps.len - 2].name.s);
    try testing.expectEqual(st.StepState.skipped, ps[ps.len - 2].state);
    try testing.expectEqualStrings("Views file", ps[ps.len - 1].name.s);
}

test "list: running with usual times; a newer build supersedes; refused and skipped" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var evs: std.ArrayList(ad.DeployEvent) = .empty;
    try evs.appendSlice(a, &whole(1000, "s1", false));
    try evs.appendSlice(a, &whole(2000, "s2", false));
    try evs.appendSlice(a, &whole(3000, "s3", true));
    // s4 started, round running, nothing since
    try evs.appendSlice(a, &.{
        ev(4000, "s4", "deploy", "start", ""),
        ev(4000, "s4", "build", "start", ""),
        ev(4010, "s4", "build", "ok", ""),
        ev(4030, "s4", "round", "start", ""),
    });
    var l = try list(a, evs.items);
    try testing.expectEqualStrings("s4", l[0].sha);
    try testing.expectEqual(st.State.running, l[0].state);
    // Not in the ci or round of its own: running from the round's start
    try testing.expectEqual(st.StepState.running, l[0].steps.get(.site).?.state);
    try testing.expectEqual(null, l[0].steps.get(.ci));
    const u = usual(l, &l[0]);
    try testing.expectEqual(3, u.n);
    try testing.expectEqual(false, u.kind);
    try testing.expectEqual(100, u.total.?);
    try testing.expectEqual(10, u.step.get(.site).?);
    const ps = try steps(a, &l[0], 4045, u);
    for (ps) |p| if (std.mem.eql(u8, p.name.s, "Site build")) {
        try testing.expectEqual(15, p.took.?);
        try testing.expectEqual(10, p.usual.?);
    };
    try testing.expectEqual(st.StepState.pending, ps[ps.len - 1].state);
    try testing.expect(ps[0].state == .running and std.mem.eql(u8, ps[0].name.s, "Deploy"));

    // s5's build lands while s4 still runs: s4 superseded. s6 skipped, s7's push refused
    try evs.appendSlice(a, &.{
        ev(4100, "s5", "deploy", "start", ""),
        ev(4110, "s5", "build", "ok", ""),
        ev(4200, "s6", "deploy", "skipped", "docs only"),
        ev(4300, "s7", "ci", "start", ""),
        ev(4400, "s7", "ci", "failed", "2 tests failed"),
    });
    l = try list(a, evs.items);
    try testing.expectEqual(st.State.refused, l[0].state);
    try testing.expectEqual(st.State.skipped, l[1].state);
    try testing.expectEqual(st.State.running, l[2].state);
    try testing.expectEqual(st.State.superseded, l[3].state);
    // s3's swap waited: compared with its own kind once two such are live
    try testing.expectEqual(true, l[4].waited.?);
}

test "list: a re-run starts its own attempt with its own commits; failed step" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const evs = [_]ad.DeployEvent{
        ev(99, "s1", "commit", "info", "s1 First try"),
        ev(100, "s1", "deploy", "start", ""),
        ev(110, "s1", "build", "failed", "error: no space"),
        ev(199, "s1", "commit", "info", "s1 Second try"),
        ev(200, "s1", "deploy", "start", ""),
        ev(210, "s1", "build", "failed", "error: still"),
    };
    const l = try list(a, &evs);
    try testing.expectEqual(1, l.len);
    try testing.expectEqual(200, l[0].start);
    try testing.expectEqual(st.State.failed, l[0].state);
    try testing.expectEqual(1, l[0].commits.len);
    try testing.expectEqualStrings("Second try", l[0].subject());
    try testing.expectEqualStrings("error: still", l[0].steps.get(.build).?.detail);
}

test "median" {
    var xs = [_]i64{ 5, 1, 3, 2 };
    try testing.expectEqual(2, median(&xs).?);
    try testing.expectEqual(null, median(xs[0..0]));
}
