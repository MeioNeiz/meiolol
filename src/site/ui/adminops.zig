//! AdminOps: the admin page's Deploys and Logs tabs, an island of its own below
//! AdminTraffic (ui-adminops.wasm, which fetches only once one of them shows). Deploys:
//! every push from the check on the Mac until the site serves it (ui.admindeploys over
//! live.bin's deploy events, admin.bin's when the live API is down), one StepTimeline
//! each. Logs: the tail of each of the box's logs (api/log, text) in a LogView, stamps in
//! UK time, errors and warnings of the last 24 h per file
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const card = @import("card.zig");
const Gallery = @import("gallery.zig").Gallery;
const timechart = @import("timechart.zig");
const steptimeline = @import("steptimeline.zig");
const logview = @import("logview.zig");
const ad = @import("admindata.zig");
const ap = @import("adminpage.zig");
const ac = @import("admincharts.zig");
const dl = @import("admindeploys.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Text = tree.Text;

pub const name = "AdminOps";
pub const scope = .{".c-adops"};
pub const sel = "[data-island=adminops]";

/// The box's logs api/log serves (admin_api.zig log_files)
pub const log_files = [_][]const u8{ "crawl", "web", "eval", "render", "health", "backup", "builds" };
/// Lines fetched of each: the errors and warnings are counted over these
pub const log_lines = 2000;

/// A log's tail as fetched (logTail)
pub const LogTail = struct {
    /// Oldest first, stamps in UK time
    lines: []const []const u8,
    /// In the 24 h before it was fetched
    errors: u32 = 0,
    warnings: u32 = 0,
};

/// Deploys drawn, newest first
const max_deploys = 25;
/// Deploys keyed by their sha's first 7 characters
const Short = [7]u8;

pub const Ops = struct {
    tab: ap.Tab = .overview,
    /// AdminCharts', kept so this island's URL writes keep it
    range: ac.Range = .day,
    now: i64 = 0,
    /// When the page opened: a deploy failing after it is announced
    opened: i64 = 0,
    /// The wasm's: live.bin's, or admin.bin's when live.bin failed (snap)
    events: ?[]const ad.DeployEvent = null,
    snap: bool = false,
    /// Neither answered
    failed: bool = false,
    /// Deploys the viewer opened or folded, over the default (the newest and a running
    /// one open), oldest choice first
    folds: [max_deploys]struct { sha: Short, open: bool } = undefined,
    n_folds: u8 = 0,
    /// The deploys as last drawn, so a toggle finds its row's
    rows: [max_deploys]Short = undefined,
    /// Index into log_files
    shown: u8 = 0,
    /// The wasm's, null until a file's first answer
    tails: [log_files.len]?LogTail = @splat(null),
    /// A file's last fetch failed
    log_failed: [log_files.len]bool = @splat(false),
    filter: [80]u8 = undefined,
    filter_len: u8 = 0,
    follow: bool = false,
    /// A log to fetch again, for the wasm after an update
    want: ?u8 = null,
    /// This island's code, on its root for dom.lazyLoad
    js: []const u8 = "",
    wasm: []const u8 = "",

    pub const Url = ap.Page.Url;

    pub const Msg = union(enum) {
        /// A deploy row opened or folded, by its index as drawn
        fold: u8,
        file: u8,
        filter,
        follow,
        reload,
    };

    pub fn toUrl(o: *const Ops) Url {
        return .{ .tab = o.tab, .range = o.range };
    }

    pub fn fromUrl(o: *Ops, u: Url) void {
        o.tab = u.tab;
        o.range = u.range;
    }

    pub fn update(o: *Ops, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .fold => |i| if (i < max_deploys) o.setFold(o.rows[i], ev.opened()),
            .file => |i| o.shown = i,
            .filter => {
                const n = @min(ev.text.len, o.filter.len);
                @memcpy(o.filter[0..n], ev.text[0..n]);
                o.filter_len = @intCast(n);
            },
            .follow => o.follow = !o.follow,
            .reload => o.want = o.shown,
        }
    }

    pub fn shows(o: *const Ops) bool {
        return o.tab == .deploys or o.tab == .logs;
    }

    fn setFold(o: *Ops, sha: Short, open: bool) void {
        for (o.folds[0..o.n_folds]) |*f| if (std.mem.eql(u8, &f.sha, &sha)) {
            f.open = open;
            return;
        };
        if (o.n_folds == max_deploys) {
            std.mem.copyForwards(@TypeOf(o.folds[0]), o.folds[0 .. max_deploys - 1], o.folds[1..]);
            o.n_folds -= 1;
        }
        o.folds[o.n_folds] = .{ .sha = sha, .open = open };
        o.n_folds += 1;
    }

    fn foldOf(o: *const Ops, sha: Short) ?bool {
        for (o.folds[0..o.n_folds]) |f| if (std.mem.eql(u8, &f.sha, &sha)) return f.open;
        return null;
    }

    pub fn view(o: *Ops, h: *H) N {
        const on = o.shows();
        return h.div(.{ .class = "c-adops", .data_island = "adminops", .data_js = o.js, .data_wasm = o.wasm, .hidden = !on }, .{
            if (!on) null else if (o.tab == .logs) logsTab(o, h) else deploysTab(o, h),
        });
    }
};

const W = struct {
    pub const deploys = plain("Deploys");
    pub const deploys_lead = plain("Every push to main: the check on the Mac, the build and copy, the deploy round on the box and the renderer swap, until the site serves it. Times in UK time; steps from data/deploys.tsv on the box (docs/hosting.md, Deploy events).");
    pub const from_snap = plain("The live API is unavailable: deploys as of the last snapshot.");
    pub const failed = plain("Deploys (api/live.bin, admin.bin) didn't load: Refresh to try again");
    pub const no_deploys = plain("No deploy events yet: the next push records them.");
    pub const pushed = Phrase("pushed {t:text}");
    pub const live_at = Phrase(", live at {at:text} after {t:time}");
    pub const tracks = Phrase(" (static upload {u:text}, renderer {r:text})");
    pub const eta = Phrase(", expected live around {at:text} ({b:text})");
    pub const late = Phrase(", taking longer than usual ({b:text})");
    pub const untimed = plain(", no finished deploy yet to time it by");
    pub const basis = Phrase("median {t:time} over the last {n:count} deploys{k:text}");
    pub const superseded = plain(", replaced by a newer deploy before it went live");
    pub const skipped = plain(", nothing on the box changed, so no round of its own");
    pub const docs_only = "docs or research only";

    pub const logs = plain("Logs");
    pub const logs_lead = plain("The last 2,000 lines of each of the box's logs, player names, ids and match ids removed. Counts are errors and warnings in the last 24 h. Times in UK time (the box logs UTC).");
};

fn deploysTab(o: *Ops, h: *H) N {
    const evs = o.events orelse return h.p(.{ .class = "lead", .role = "status" }, .{if (o.failed) W.failed else ap.W.loading});
    const all = dl.list(h.mem, evs) catch {
        h.oom = true;
        return .none;
    };
    var rows = h.list();
    for (all[0..@min(all.len, max_deploys)], 0..) |*d, i| {
        var short: Short = @splat(' ');
        const n = @min(d.sha.len, short.len);
        @memcpy(short[0..n], d.sha[0..n]);
        o.rows[i] = short;
        const u: ?dl.Usual = if (d.state == .running) dl.usual(all, d) else null;
        const steps = dl.steps(h.mem, d, o.now, u) catch {
            h.oom = true;
            return .none;
        };
        // Failed while the page was open
        var alert = false;
        if (d.state == .failed and o.opened > 0) for (d.steps.values) |x| if (x) |y| {
            alert = alert or (y.state == .failed and (y.end orelse 0) >= o.opened);
        };
        rows.add(steptimeline.view(h, .{
            .state = d.state,
            .sha = d.sha[0..n],
            .subject = if (d.subject().len == 0 and d.state == .skipped) W.docs_only else d.subject(),
            .when = deployWhen(h, d, u, o.now),
            .steps = steps,
            .commits = d.commits,
            .open = o.foldOf(short) orelse (i == 0 or d.state == .running),
            .on_toggle = h.on(o, .{ .fold = @intCast(i) }),
            .alert = alert,
        }));
    }
    return card.view(h, .{}, &.{
        card.head(h, W.deploys, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.deploys_lead}),
        if (o.snap) h.p(.{ .class = "lead", .role = "status" }, .{W.from_snap}) else .none,
        if (all.len == 0) h.p(.{ .class = "lead" }, .{W.no_deploys}) else h.div(.{}, .{rows.done()}),
    });
}

/// "pushed 28 Oct 14:02, live at 14:09 after 7:12 (…)", or how it ended, or when it is
/// expected live
fn deployWhen(h: *H, d: *const dl.Deploy, u: ?dl.Usual, now: i64) Text {
    const pushed = W.pushed.with(h, .{ .t = ap.when(h, d.start).s }).s;
    const rest: []const u8 = switch (d.state) {
        .live => blk: {
            const l = d.live orelse break :blk "";
            const at = W.live_at.with(h, .{ .at = hm(h, l), .t = l - d.start }).s;
            const up = if (d.steps.get(.upload)) |x| x.end else null;
            const ren = if (d.steps.get(.cache)) |x| x.end else null;
            if (up == null or ren == null) break :blk at;
            break :blk h.fmt("{s}{s}", .{ at, W.tracks.with(h, .{ .u = hm(h, up.?), .r = hm(h, ren.?) }).s });
        },
        .running => blk: {
            const x = u orelse break :blk "";
            const total = x.total orelse break :blk W.untimed.s;
            const kind: []const u8 = if (!x.kind) "" else if (d.waited orelse false) " that changed a views part" else " that changed no views part";
            const b = W.basis.with(h, .{ .t = total, .n = x.n, .k = kind }).s;
            const at = d.start + total;
            break :blk if (at > now) W.eta.with(h, .{ .at = hm(h, at), .b = b }).s else W.late.with(h, .{ .b = b }).s;
        },
        .superseded => W.superseded.s,
        .skipped => W.skipped.s,
        .failed, .refused => "",
    };
    return .{ .s = h.fmt("{s}{s}", .{ pushed, rest }) };
}

fn logsTab(o: *Ops, h: *H) N {
    var files: [log_files.len]logview.File = undefined;
    for (&files, log_files, o.tails, 0..) |*f, file, t, i| f.* = .{
        .name = h.fmt("{s}.log", .{file}),
        .errors = if (t) |x| x.errors else 0,
        .warnings = if (t) |x| x.warnings else 0,
        .on = h.on(o, .{ .file = @intCast(i) }),
    };
    const tail = o.tails[o.shown];
    return card.view(h, .{}, &.{
        card.head(h, W.logs, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.logs_lead}),
        logview.view(h, .{
            .files = &files,
            .shown = o.shown,
            // A tail already there stays while it reloads (Follow, each 10 s)
            .state = if (tail != null) .ready else if (o.log_failed[o.shown]) .failed else .loading,
            .lines = if (tail) |t| t.lines else &.{},
            .filter = o.filter[0..o.filter_len],
            .on_filter = h.on(o, .filter),
            .follow = o.follow,
            .on_follow = h.on(o, .follow),
            .on_reload = h.on(o, .reload),
        }),
    });
}

/// A stamp at a log line's start ("2026-10-17 18:52:27", "2026-10-17T18:52:14Z" or
/// Python's "…,823"): its time and length
fn stamp(l: []const u8) ?struct { t: i64, len: usize } {
    if (l.len < 19) return null;
    for (l[0..19], "0000-00-00T00:00:00") |c, want| switch (want) {
        '0' => if (!std.ascii.isDigit(c)) return null,
        'T' => if (c != 'T' and c != ' ') return null,
        else => if (c != want) return null,
    };
    const n = struct {
        fn f(x: []const u8) i64 {
            return std.fmt.parseInt(i64, x, 10) catch 0;
        }
    }.f;
    var len: usize = 19;
    if (len < l.len and l[len] == 'Z') {
        len += 1;
    } else if (len < l.len and l[len] == ',') {
        len += 1;
        while (len < l.len and std.ascii.isDigit(l[len])) len += 1;
    }
    const d = timechart.days(n(l[0..4]), n(l[5..7]), n(l[8..10]));
    return .{ .t = d * 86400 + n(l[11..13]) * 3600 + n(l[14..16]) * 60 + n(l[17..19]), .len = len };
}

/// A log's text as the Logs tab shows it: leading stamps in UK time (the box logs UTC),
/// the zone dropped so LogView still finds the level after them; errors and warnings
/// counted over the 24 h before `now`. Every line `a`'s
pub fn logTail(a: std.mem.Allocator, text: []const u8, now: i64) !LogTail {
    var lines: std.ArrayList([]const u8) = .empty;
    var out: LogTail = .{ .lines = &.{} };
    const all = std.mem.trimEnd(u8, text, "\n");
    if (all.len == 0) return out;
    var it = std.mem.splitScalar(u8, all, '\n');
    while (it.next()) |l| {
        const st = stamp(l) orelse {
            try lines.append(a, try a.dupe(u8, l));
            continue;
        };
        if (st.t >= now - 86400) switch (logview.level(l)) {
            .err => out.errors += 1,
            .warn => out.warnings += 1,
            .none => {},
        };
        const t = st.t + timechart.ukOffset(st.t);
        const c = fmt.civil(@intCast(@divFloor(t, 86400)));
        const sec: u32 = @intCast(@mod(t, 86400));
        try lines.append(a, try std.fmt.allocPrint(a, "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}{s}", .{ c.year, c.month, c.day, sec / 3600, sec / 60 % 60, sec % 60, l[st.len..] }));
    }
    out.lines = lines.items;
    return out;
}

/// UK time of day ("14:05")
fn hm(h: *H, at: i64) []const u8 {
    const sec = @mod(at + timechart.ukOffset(at), 86400);
    return h.fmt("{d:0>2}:{d:0>2}", .{ @as(u32, @intCast(@divFloor(sec, 3600))), @as(u32, @intCast(@divFloor(@mod(sec, 3600), 60))) });
}

pub const css =
    \\@layer components {
    \\  .c-adops .lead { margin: 0 0 var(--sp-2); color: var(--muted); font-size: var(--fs-s); }
    \\}
    \\
;

pub const Demo = struct {
    const now = ap.Demo.now;

    fn ev(t: i64, sha: []const u8, step: []const u8, status: []const u8, detail: []const u8) ad.DeployEvent {
        return .{ .time = t, .sha = sha, .step = step, .status = status, .detail = detail };
    }

    /// From push check to live in 8:20
    fn whole(t0: i64, sha: []const u8, commit: []const u8) [16]ad.DeployEvent {
        return .{
            ev(t0 - 210, sha, "ci", "start", ""),
            ev(t0 - 5, sha, "ci", "ok", ""),
            ev(t0 - 1, sha, "commit", "info", commit),
            ev(t0, sha, "deploy", "start", ""),
            ev(t0, sha, "build", "start", ""),
            ev(t0 + 150, sha, "build", "ok", "deployed"),
            ev(t0 + 160, sha, "web", "ok", "signalled the running loop"),
            ev(t0 + 165, sha, "deploy", "ok", ""),
            ev(t0 + 170, sha, "round", "start", ""),
            ev(t0 + 330, sha, "site", "ok", ""),
            ev(t0 + 360, sha, "upload", "ok", ""),
            ev(t0 + 420, sha, "views", "ok", "loaded 2 parts again, kept 14"),
            ev(t0 + 430, sha, "swap", "start", ""),
            ev(t0 + 440, sha, "reload", "ok", ""),
            ev(t0 + 490, sha, "swap", "ok", ""),
            ev(t0 + 500, sha, "cache", "ok", "k-9f2"),
        };
    }

    pub const events = whole(now - 26_000, "459b807f11aa22bb", "459b807f Learn: Enter is the focused control's; digits choose and focus Lock in") ++
        [_]ad.DeployEvent{
            ev(now - 20_000, "13c90240aa12bb34", "commit", "info", "13c90240 Admin data: deploy events in live.bin"),
            ev(now - 20_000, "13c90240aa12bb34", "deploy", "start", ""),
            ev(now - 19_940, "13c90240aa12bb34", "build", "failed", "zig build -Dtarget=x86_64-linux: error: expected type 'u32', found 'i64'"),
        } ++ whole(now - 3_600, "c9e836bf23992353", "c9e836bf Prose leftovers SF4/6/7") ++
        [_]ad.DeployEvent{
            ev(now - 1_800, "6cdb138100000000", "deploy", "skipped", "docs only: no copy, no round"),
            ev(now - 450, "e80f952e00000000", "ci", "start", ""),
            ev(now - 245, "e80f952e00000000", "ci", "ok", ""),
            ev(now - 241, "e80f952e00000000", "commit", "info", "e80f952e Draft tester review fixes: restore checks champions"),
            ev(now - 241, "e80f952e00000000", "commit", "info", "11b1467d game.html reads the default role's file"),
            ev(now - 240, "e80f952e00000000", "deploy", "start", ""),
            ev(now - 240, "e80f952e00000000", "build", "start", ""),
            ev(now - 90, "e80f952e00000000", "build", "ok", "deployed"),
            ev(now - 80, "e80f952e00000000", "web", "ok", "signalled the running loop"),
            ev(now - 70, "e80f952e00000000", "round", "start", ""),
        };
    /// The dev server's live.bin
    pub const live: ad.Live = blk: {
        var l = ap.Demo.live;
        l.deploys = &events;
        break :blk l;
    };
    /// The dev server's api/log, every file
    pub const log =
        \\2026-10-28T13:10:02Z info(crawl): EUW1 182 matches/min, queue 41,203
        \\2026-10-28T13:10:31Z warning(riot): 429 on match-v5, backing off 4 s
        \\2026-10-28T13:11:40Z error(store): disk write took 2.4 s (fsync), kept going
        \\2026-10-28T13:12:02Z info(crawl): lane model rms error 0.31
        \\
    ;

    const demo_lines = [_][]const u8{
        "2026-10-28 13:10:02 info(crawl): EUW1 182 matches/min, queue 41,203",
        "2026-10-28 13:10:31 warning(riot): 429 on match-v5, backing off 4 s",
        "2026-10-28 13:11:40 error(store): disk write took 2.4 s (fsync), kept going",
        "2026-10-28 13:12:02 info(crawl): lane model rms error 0.31",
    };

    fn island(tab: ap.Tab) Ops {
        var o: Ops = .{ .tab = tab, .now = now, .opened = now - 30_000, .events = &events };
        o.tails[0] = .{ .lines = &demo_lines, .errors = 1, .warnings = 1 };
        o.tails[1] = .{ .lines = &.{}, .warnings = 3 };
        o.log_failed[2] = true;
        return o;
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const states = [_][]const u8{ "deploys: one running, untimed", "deploys: from the snapshot, none yet", "deploys: loading", "deploys: failed", "logs: filtered", "logs: a file failed", "logs: loading", "another tab: hidden" };
    for (states, 0..) |caption, i| {
        const o = a.create(Ops) catch return;
        o.* = switch (i) {
            // The skipped and running ones: within the gallery's word budget
            0 => blk: {
                var x = Demo.island(.deploys);
                x.events = Demo.events[35..];
                break :blk x;
            },
            1 => .{ .tab = .deploys, .events = &.{}, .snap = true },
            2 => .{ .tab = .deploys },
            3 => .{ .tab = .deploys, .failed = true },
            4, 5 => Demo.island(.logs),
            6 => .{ .tab = .logs },
            else => .{},
        };
        switch (i) {
            4 => {
                o.filter_len = 4;
                @memcpy(o.filter[0..4], "rate");
            },
            5 => o.shown = 2,
            else => {},
        }
        g.addFill(caption, o.view(g.h));
    }
}

const testing = std.testing;

fn render(a: std.mem.Allocator, o: *Ops) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const root = o.view(&h);
    try testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, root, &out.writer);
    return out.written();
}

fn expectHas(s: []const u8, wants: []const []const u8) !void {
    for (wants) |w| if (std.mem.find(u8, s, w) == null) {
        std.debug.print("missing {s} in {s}\n", .{ w, s });
        return error.TestExpectedEqual;
    };
}

test "admin deploys: newest and running open, a fold kept, the running one timed" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var o = Demo.island(.deploys);
    var s = try render(a, &o);
    // Running since 13:56, live in 8:20 both times before
    try expectHas(s, &.{
        "data-state=\"running\" open",
        "pushed 28 Oct 13:56, expected live around 14:04 (median 8:20 over the last 2 deploys)",
        "Site build<span class=\"sr\">, running</span><span class=\"t\">1:10 so far, usually 2:40</span>",
        ">docs or research only<",
        "live at 13:08 after 8:20 (static upload 13:06, renderer 13:08)",
        "role=\"alert\"",
        ">Prose leftovers SF4/6/7<",
    });
    try testing.expectEqual(1, std.mem.count(u8, s, " open"));
    var ev: tree.Event = .{ .kind = .toggle, .text = "" };
    o.update(.{ .fold = 0 }, &ev);
    ev.text = "open";
    o.update(.{ .fold = 2 }, &ev);
    s = try render(a, &o);
    try expectHas(s, &.{ "data-state=\"running\">", "data-state=\"live\" open" });
    // Failed before the page opened: not announced
    o.opened = Demo.now;
    try testing.expect(std.mem.find(u8, try render(a, &o), "role=\"alert\"") == null);
    o.tab = .crawler;
    try expectHas(try render(a, &o), &.{" hidden"});
}

test "admin logs: UK stamps, 24 h counts, a file's state, filter and reload" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const t = try logTail(a, "2026-10-28T13:00:00Z error(x): boom\n2026-08-01 12:00:00,123 warning(y): w\nno stamp\n2026-10-27T13:59:59Z warning(z): old\n", Demo.now);
    try testing.expectEqualStrings("2026-10-28 13:00:00 error(x): boom", t.lines[0]);
    try testing.expectEqualStrings("2026-08-01 13:00:00 warning(y): w", t.lines[1]);
    try testing.expectEqualStrings("no stamp", t.lines[2]);
    try testing.expectEqual(logview.Level.err, logview.level(t.lines[0]));
    try testing.expectEqual(1, t.errors);
    try testing.expectEqual(0, t.warnings);
    try testing.expectEqual(0, (try logTail(a, "\n", Demo.now)).lines.len);
    try testing.expectEqual(4, (try logTail(a, Demo.log, Demo.now)).lines.len);

    var o: Ops = .{ .tab = .logs };
    try expectHas(try render(a, &o), &.{ "Loading", "crawl.log" });
    o = Demo.island(.logs);
    var ev: tree.Event = .{ .kind = .input, .text = "DISK" };
    o.update(.filter, &ev);
    try expectHas(try render(a, &o), &.{ "1 of 4 lines", "<mark>disk</mark>" });
    o.update(.{ .file = 2 }, &ev);
    try expectHas(try render(a, &o), &.{"Could not load eval.log"});
    o.update(.reload, &ev);
    try testing.expectEqual(2, o.want.?);
}
