//! AdminCharts: the admin page's chart tabs, Crawler and Riot API, an island of their own
//! below AdminPage's tabs (ui-admincharts.wasm, which fetches only once one shows). The
//! tab comes with the URL (#tab=crawler). Crawl charts read live.bin's last 3 h by minute
//! for the 3-hour range, else the snapshot's 10-minute buckets; readings and the backlog
//! read the snapshot's history. Each chart's zoom and tip stay in `times`, so a re-fetch
//! keeps them
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const card = @import("card.zig");
const Gallery = @import("gallery.zig").Gallery;
const strip = @import("strip.zig");
const segmented = @import("segmented.zig");
const chip = @import("chip.zig");
const bar = @import("bar.zig");
const timechart = @import("timechart.zig");
const ad = @import("admindata.zig");
const ap = @import("adminpage.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Text = tree.Text;

pub const name = "AdminCharts";
pub const scope = .{".c-adcharts"};
pub const sel = "[data-island=admincharts]";

pub const Range = enum { hours, day, all };

pub const Charts = struct {
    tab: ap.Tab = .overview,
    range: Range = .day,
    /// Regions shown, a bit each by ad.Region
    regions: u8 = 0xf,
    times: [n]timechart.Time = idle,
    snap: ?*const ad.Snapshot = null,
    live: ?*const ad.Live = null,
    snap_failed: bool = false,
    /// The clock, unix s
    now: i64 = 0,
    /// This island's code, on its root for dom.lazyLoad
    js: []const u8 = "",
    wasm: []const u8 = "",

    /// As AdminPage's: each island writes the same values
    pub const Url = ap.Page.Url;
    pub const Msg = union(enum) { range: Range, region: u8 };

    pub fn toUrl(ch: *const Charts) Url {
        return .{ .tab = ch.tab, .range = ch.range };
    }

    pub fn fromUrl(ch: *Charts, u: Url) void {
        ch.tab = u.tab;
        ch.range = u.range;
    }

    pub fn update(ch: *Charts, m: Msg, ev: *tree.Event) void {
        _ = ev;
        switch (m) {
            .range => |r| {
                ch.range = r;
                for (&ch.times) |*t| {
                    t.zoom = null;
                    t.tip = null;
                }
            },
            // At least one region stays
            .region => |i| {
                const b = bit(i);
                if (ch.regions != b) ch.regions ^= b;
            },
        }
    }

    pub fn shows(ch: *const Charts) bool {
        return switch (ch.tab) {
            .crawler, .riot, .storage, .ingest => true,
            else => false,
        };
    }

    pub fn view(ch: *Charts, h: *H) N {
        const on = ch.shows();
        return h.div(.{ .class = "c-adcharts", .data_island = "admincharts", .data_js = ch.js, .data_wasm = ch.wasm, .hidden = !on }, .{
            if (!on) null else if (ch.snap) |s| switch (ch.tab) {
                .riot => riot(ch, h, s),
                .storage => storage(ch, h, s),
                .ingest => ingest(ch, h, s),
                else => crawler(ch, h, s),
            } else h.p(.{ .class = "lead", .role = "status" }, .{if (ch.snap_failed) ap.W.no_snap else ap.W.loading}),
        });
    }
};

/// One per chart on these tabs: its slot in Charts.times
pub const Chart = enum { matches, timelines, calls, commits, writer, pages, warnings, backlog, requests, platform, errors, dbfiles, disk, m_matches, m_timelines, m_drafts, m_players, m_ranks, m_mastery, gamedays };
pub const n = std.enums.values(Chart).len;
pub const idle: [n]timechart.Time = @splat(.{ .label = .{ .s = "" }, .start = 0, .series = &.{} });

const W = struct {
    pub const range = plain("Range");
    pub const hours = plain("3 hours");
    pub const day = plain("24 hours");
    pub const days = Phrase("{n:count} days");
    pub const regions = plain("Regions");

    pub const readings = plain("Readings");
    pub const readings_sub = plain("From the 15-minute snapshots: least-squares rates, so one odd snapshot doesn't swing them.");
    pub const matches_day = plain("Matches / day");
    pub const timelines_day = plain("Timelines / day");
    pub const trend = Phrase("last 6 h {a:text}, week {b:text}");
    pub const trend_shift = Phrase("last 6 h {a:text}, week {b:text}; {d:text} {p:pct} lately");
    pub const up = plain("up");
    pub const down = plain("down");
    pub const per_match = plain("Timelines per new match");
    pub const asks = Phrase("crawler asks for {n:text}%");
    pub const share = plain("share of matches that get a timeline");
    pub const match_queue = plain("Match queue");
    pub const timeline_queue = plain("Timeline queue");
    pub const steady = plain("steady over the last day");
    pub const shrinking = Phrase("shrinking {n:text} / day: empty in ~{d:text}");
    pub const growing = Phrase("growing {n:text} / day: the crawler falls behind");
    pub const mastery_day = plain("Mastery rows / day");
    pub const collecting = plain("collecting");
    pub const not_collecting = plain("not collecting (off in crawl.args?)");
    pub const keep = Phrase("Raw match summaries on the box: kept {m:text}. Raw timelines: {t:text} (the gpu-box archive takes them hourly). Compact rows: {c:text}.");
    pub const forever = plain("forever");
    pub const keep_days = Phrase("{n:text} days");
    pub const ladder = Phrase("Ladder floor {t:text}; {n:text} ladder pages an hour, refreshed every {r:text} h.");

    pub const crawler = plain("Crawler");
    pub const crawler_sub = plain("From the crawler's minute report lines; gaps: not running, marks: a crawler start. Drag across a chart to zoom.");
    pub const live_sub = plain("From the crawler's minute report lines (live, last 3 hours); gaps: not running, marks: a crawler start. Drag across a chart to zoom.");
    pub const matches = plain("Matches stored per hour");
    pub const timelines = plain("Timelines stored per hour");
    pub const calls = plain("Ladder, mastery and match list calls per hour");
    pub const ladder_pages = plain("ladder pages");
    pub const mastery = plain("mastery");
    pub const id_lists = plain("match id lists");
    pub const commits = plain("Writer commits per minute");
    pub const commits_sub = plain("Each commit is a batch of queued jobs (one per match or timeline).");
    pub const commits_s = plain("commits");
    pub const writer = plain("Writer queue, highest per bucket");
    pub const waiting = plain("jobs waiting");
    pub const full = plain("full: workers block");
    pub const pages = plain("Database pages per minute (writer connection)");
    pub const written = plain("written");
    pub const read = plain("read");
    pub const warnings = plain("Warnings per bucket");
    pub const messages = Phrase("Warning messages ({n:count})");
    pub const raw_log = plain("Logs");
    pub const c_kind = plain("Kind");
    pub const c_message = plain("Message (last 24 h)");
    pub const c_count = plain("Count");
    pub const c_last = plain("Last");

    pub const queues = plain("Queues");
    pub const backlog = plain("Queue backlog (snapshots)");
    pub const match_q = plain("match queue");
    pub const timeline_q = plain("timeline queue");
    pub const no_rows = plain("Empty");
    pub const c_state = plain("State");
    pub const c_jobs = plain("Jobs");

    pub const key = plain("Riot API key");
    pub const key_sub = plain("Personal key: limits per routing value (region). Use from the crawler's report lines, over the last hour.");
    pub const of_limit = Phrase("{n:count} / min of {l:count}");
    pub const r429 = plain("429s, 24 h");
    pub const ours = plain("our key's limits");
    pub const busy = plain("Riot 429 (server), 24 h");
    pub const riots = plain("limit type server: Riot's side");
    pub const r5xx = plain("Riot 5xx, 24 h");
    pub const errors_s = plain("server errors");
    pub const problems = plain("Key problems");
    pub const none = plain("none");
    pub const no_401 = plain("no 401 or 403 in the window");
    pub const last = Phrase("last {t:text}");
    pub const your = plain("Your games");
    pub const first = plain("first in line");
    pub const no_proxy = plain("no proxy");
    pub const proxy_on = plain("its calls take the crawler's next free slot");
    pub const proxy_off = plain("the crawler runs without --proxy: lookups cannot fetch");
    pub const requests = plain("Requests per minute, by region");
    pub const key_limit = plain("key limit (100 / 2 min)");
    pub const platform = plain("Platform route requests per minute");
    pub const platform_sub = plain("Ladder and mastery calls go to platform hosts (own limits per platform).");
    pub const platform_s = plain("platform routes");
    pub const errors = plain("Rate limited and server errors");
    pub const e_ours = plain("429 (our key)");
    pub const e_server = plain("429 (server)");
    pub const e_5xx = plain("Riot 5xx");
    pub const limits = plain("Limits");
    pub const app = plain("app (per region)");
    pub const c_bucket = plain("Bucket");
    pub const c_requests = plain("Requests");
    pub const c_window = plain("Window");
    pub const c_per_min = plain("Per minute");
    pub const args = plain("Crawler arguments");
    pub const no_problems = plain("No rejected-key answers in the crawl log window.");
    pub const c_when = plain("When");
    pub const c_text = plain("Message");

    pub const space = plain("Space");
    pub const space_sub = plain("Snapshots every 15 min; growth over the newest week, WAL excluded.");
    pub const files_n = Phrase("{n:count} files, WAL included");
    pub const growths = Phrase("Growth a day: meiolol {a:text}, timeline {b:text}, raw {c:text}. Files: {f:text}.");
    pub const disk_used = plain("Disk used");
    pub const of = Phrase("{a:text} of {b:text}");
    pub const disk_growth = plain("Disk growth");
    pub const per_day = Phrase("{b:text} / day");
    pub const over = Phrase("over the last {t:text}");
    pub const over_day = Phrase("last 24 h {b:text} / day");
    pub const full_at = plain("Disk full around");
    pub const full_in = Phrase("~{n:count} d at the week's rate");
    pub const full_in2 = Phrase("~{n:count} d at the week's rate, ~{m:count} at the day's");
    pub const databases = plain("Databases");
    pub const per_stored = plain("Per stored match");
    pub const all_dbs = plain("all databases, WAL included");
    pub const db_growth = plain("Database growth");

    pub const backups = plain("Backups");
    pub const backups_sub = Phrase("{n:count} files, newest {t:text}");
    pub const files = plain("Database files on disk");
    pub const files_sub = plain("WAL files included: a sharp drop is a checkpoint folding the WAL back into its database.");
    pub const used = plain("used");
    pub const disk_size = plain("disk size");
    pub const what = plain("What takes the space");
    pub const what_sub = Phrase("Daily dbstat scan, {t:text}. Sizes are pages in the file, so free pages and the WAL are not counted.");
    pub const no_scan = plain("No dbstat scan yet (daily on the box, data/storage.tsv).");
    pub const db_total = Phrase("{d:text}.db: {b:text}");
    pub const indexes = Phrase("Indexes {p:pct} of the file.");
    pub const more = Phrase("{n:count} more");
    pub const index = plain("index");
    pub const every = Phrase("Every table and index ({n:count})");
    pub const c_db = plain("DB");
    pub const c_name = plain("Name");
    pub const c_size = plain("Size");
    pub const c_share = plain("Share of DB");
    pub const c_cells = plain("Cells");
    pub const c_per_cell = plain("Bytes / cell");
    pub const rows = plain("Rows");
    pub const rows_sub = plain("Row counts per snapshot; growth over the newest week.");
    pub const r_matches = plain("Matches");
    pub const r_timelines = plain("Timelines");
    pub const r_drafts = plain("Draft rows");
    pub const r_players = plain("Players (scan pool)");
    pub const r_ranks = plain("Ladder ranks");
    pub const r_mastery = plain("Mastery rows");
    pub const c_table = plain("Table");
    pub const c_rows = plain("Rows");
    pub const c_day = plain("24 h change");
    pub const c_week = plain("Per day (week)");

    pub const ingest = plain("What we ingest");
    pub const ingest_sub = Phrase("Complete ranked games (draft rows): the newest {n:count} stored, by the day each was played.");
    pub const by_day = plain("Games by game day");
    pub const by_day_sub = plain("By the day the game was played, not the day it was stored. Old days keep gaining a few thousand games a day, so no day is complete and the newest few are far from it; the first day is cut by the window.");
    pub const recent = plain("stored in the last 24 h");
    pub const cut = plain("cut by the window");
    pub const length = plain("Game length");
    pub const c_minutes = plain("Minutes");
    pub const c_games = plain("Games");
    pub const mins = Phrase("{a:count} to {b:count}");
    pub const mins_last = plain("60 and over");
    pub const sanity = plain("Sanity");
    pub const c_check = plain("Check");
    pub const c_value = plain("Value");
    pub const blue = plain("Blue side wins");
    pub const ranked = plain("With a median rank");
    pub const platforms = plain("Platforms");
    pub const patches = plain("Patches");
    pub const by_platform = plain("Games by platform");
    pub const by_rank = plain("Games by median rank");
    pub const ladder_tiers = plain("Ladder players by tier");
    pub const pool = plain("Scan pool by region");
    pub const by_patch = plain("Matches by patch");
    pub const c_platform = plain("Platform");
    pub const c_tier = plain("Tier");
    pub const c_players = plain("Players");
    pub const c_region = plain("Region");
    pub const c_patch = plain("Patch");
    pub const c_matches = plain("Matches");
};

const region_names = std.enums.EnumArray(ad.Region, Text).init(.{
    .americas = plain("americas"),
    .asia = plain("asia"),
    .europe = plain("europe"),
    .sea = plain("sea"),
});

/// Highest jobs the writer queue holds before workers block (crawl.zig)
const writer_cap = 128;
/// Warn steps for figures, as the old page's warn and bad
pub const warn: fmt.Step = .{ .s = 2, .low = true };
const bad: fmt.Step = .{ .s = 4, .low = true };

/// The range switcher (crawl tabs) and region chips
fn controls(ch: *Charts, h: *H, s: *const ad.Snapshot, range: bool) N {
    const items = [_]segmented.Item{
        .{ .label = W.hours, .selected = ch.range == .hours, .on = h.on(ch, .{ .range = .hours }) },
        .{ .label = W.day, .selected = ch.range == .day, .on = h.on(ch, .{ .range = .day }) },
        .{ .label = W.days.with(h, .{ .n = s.days }), .selected = ch.range == .all, .on = h.on(ch, .{ .range = .all }) },
    };
    var chips = h.list();
    for (std.enums.values(ad.Region)) |r| {
        const i = @backingInt(r);
        chips.add(chip.view(h, .{ .pressed = ch.regions & bit(i) != 0, .on = h.on(ch, .{ .region = i }) }, .{
            h.span(.{ .class = "sw", .data_s = i, .aria_hidden = true }, .{}),
            region_names.get(r),
        }));
    }
    return h.div(.{ .class = "ctl" }, .{
        if (range) segmented.view(h, .{ .s = .s, .label = W.range }, &items) else null,
        h.div(.{ .class = "chips", .role = "group", .aria_label = W.regions }, .{chips.done()}),
    });
}

fn bit(i: usize) u8 {
    return @as(u8, 1) << @intCast(i);
}

/// Live's when it has buckets (fresher), else the snapshot's
fn crawlOf(ch: *const Charts, s: *const ad.Snapshot) ad.Crawl {
    if (ch.live) |l| if (l.crawl.buckets.len > 0) return l.crawl;
    return s.crawl;
}

// The crawl series in the chosen range

const Span = struct { c: ad.Crawl, first: usize, live: bool };

fn spanOf(ch: *const Charts, s: *const ad.Snapshot) Span {
    if (ch.range == .hours) if (ch.live) |l| if (l.crawl.buckets.len > 0) return .{ .c = l.crawl, .first = 0, .live = true };
    const c = s.crawl;
    const from: i64 = switch (ch.range) {
        .hours => s.now - 3 * 3600,
        .day => s.now - 86400,
        .all => c.start,
    };
    const i: usize = @intCast(@max(@divFloor(from - c.start, c.step), 0));
    return .{ .c = c, .first = @min(i, c.buckets.len), .live = false };
}

fn startOf(sp: Span) i64 {
    return sp.c.start + @as(i64, @intCast(sp.first)) * sp.c.step;
}

/// Counters a chart draws, per region where the bucket keeps them so
const Field = enum { m, t, ids, req, ladder, mastery, platform_req, commits, pages_written, pages_read };

fn get(b: ad.Bucket, f: Field, mask: u8) f64 {
    const per: ?[ad.regions]u32 = switch (f) {
        .m => b.m,
        .t => b.t,
        .ids => b.ids,
        .req => b.req,
        else => null,
    };
    if (per) |x| {
        var v: f64 = 0;
        for (x, 0..) |y, i| if (mask & bit(i) != 0) {
            v += @floatFromInt(y);
        };
        return v;
    }
    return switch (f) {
        .ladder => @floatFromInt(b.ladder),
        .mastery => @floatFromInt(b.mastery),
        .platform_req => @floatFromInt(b.platform_req),
        .commits => @floatFromInt(b.commits),
        .pages_written => @floatFromInt(b.pages_written),
        .pages_read => @floatFromInt(b.pages_read),
        else => unreachable,
    };
}

/// Per `per` seconds of crawler time in each bucket; null where it wasn't running
fn rates(h: *H, sp: Span, f: Field, mask: u8, per: f64) []const ?f32 {
    const bs = sp.c.buckets[sp.first..];
    const out = h.mem.alloc(?f32, bs.len) catch {
        h.oom = true;
        return &.{};
    };
    for (bs, out) |b, *o| o.* = if (b.covered == 0) null else @floatCast(get(b, f, mask) * per / @as(f64, @floatFromInt(b.covered)));
    return out;
}

fn warnings(h: *H, sp: Span, k: ad.Kind) []const ?f32 {
    const bs = sp.c.buckets[sp.first..];
    const out = h.mem.alloc(?f32, bs.len) catch {
        h.oom = true;
        return &.{};
    };
    for (bs, out) |b, *o| o.* = @floatFromInt(b.warnings[@backingInt(k)]);
    return out;
}

/// One series per shown region, in its region's colour
fn byRegion(ch: *const Charts, h: *H, sp: Span, f: Field, per: f64) []const timechart.Series {
    var l: std.ArrayList(timechart.Series) = .empty;
    for (std.enums.values(ad.Region)) |r| {
        const i = @backingInt(r);
        if (ch.regions & bit(i) == 0) continue;
        l.append(h.mem, .{ .name = region_names.get(r), .values = rates(h, sp, f, bit(i), per), .colour = i }) catch {
            h.oom = true;
        };
    }
    return l.items;
}

/// A chart in its card, its zoom and tip kept in the page
fn chart(ch: *Charts, h: *H, c: Chart, sub: ?Text, o: timechart.Time) N {
    const t = &ch.times[@backingInt(c)];
    var x = o;
    x.zoom = t.zoom;
    x.tip = t.tip;
    x.drag = t.drag;
    x.press = t.press;
    t.* = x;
    return card.view(h, .{}, &.{
        card.head(h, o.label, null, &.{}),
        if (sub) |x2| h.p(.{ .class = "lead" }, .{x2}) else .none,
        t.view(h),
    });
}

/// A history column, chosen at run time: one copy of each function that reads one
const Col = std.meta.FieldEnum(ad.HistoryRow);

fn at(r: ad.HistoryRow, c: Col) ?u64 {
    return switch (c) {
        .time => null,
        inline else => |t| @field(r, @tagName(t)),
    };
}

/// Rate of a history column per day over the newest `days`, least squares; null under
/// ~5 h of history
fn growth(hist: []const ad.HistoryRow, c: Col, days: f64) ?f64 {
    return growthLess(hist, c, &.{}, days);
}

/// A size's growth without its WAL columns `wal`, and with them on the lower envelope
/// (points no later point undercuts): a WAL swing would read as growth, then shrinkage
fn growthLess(hist: []const ad.HistoryRow, c: Col, wal: []const Col, days: f64) ?f64 {
    if (hist.len < 2) return null;
    const end = hist[hist.len - 1].time;
    const from = end - @as(i64, @intFromFloat(days * 86400));
    var k: f64 = 0;
    var sx: f64 = 0;
    var sy: f64 = 0;
    var t0: i64 = end;
    var it: Envelope = .{ .hist = hist, .from = from, .c = c, .wal = wal };
    while (it.next()) |pt| {
        t0 = pt[0];
        k += 1;
        sx += @floatFromInt(pt[0] - end);
        sy += pt[1];
    }
    if (k < 2 or end - t0 < 86400 / 5) return null;
    const mx = sx / k;
    const my = sy / k;
    var sxy: f64 = 0;
    var sxx: f64 = 0;
    it = .{ .hist = hist, .from = from, .c = c, .wal = wal };
    while (it.next()) |pt| {
        const dx = @as(f64, @floatFromInt(pt[0] - end)) - mx;
        sxy += dx * (pt[1] - my);
        sxx += dx * dx;
    }
    return if (sxx > 0) sxy / sxx * 86400 else 0;
}

/// A column's points from `from` on, newest first; with WAL columns, only those no later
/// point undercuts
const Envelope = struct {
    hist: []const ad.HistoryRow,
    from: i64,
    c: Col,
    wal: []const Col,
    i: ?usize = null,
    min: f64 = std.math.inf(f64),

    fn next(e: *Envelope) ?struct { i64, f64 } {
        var i = e.i orelse e.hist.len;
        defer e.i = i;
        while (i > 0) {
            i -= 1;
            const r = e.hist[i];
            if (r.time < e.from) return null;
            var v: f64 = @floatFromInt(at(r, e.c) orelse continue);
            for (e.wal) |w| v -= @floatFromInt(at(r, w) orelse 0);
            if (e.wal.len > 0) {
                if (v > e.min) continue;
                e.min = v;
            }
            return .{ r.time, v };
        }
        return null;
    }
};

const wal_all: []const Col = &.{ .meiolol_wal, .timeline_wal, .raw_wal };

fn kilo(h: *H, v: ?f64) Text {
    const x = v orelse return .{ .s = "–" };
    return phrase.num(h, .kilo, @as(i64, @intFromFloat(@round(x))));
}

/// A `--name value` of the crawler's arguments
fn flag(args: []const u8, comptime key: []const u8) ?[]const u8 {
    var it = std.mem.tokenizeAny(u8, args, " \t\n");
    while (it.next()) |a| if (std.mem.eql(u8, a, "--" ++ key)) return it.next();
    return null;
}

/// "3 d 4 h", "5 h", "12 min"
fn span(h: *H, secs: f64) Text {
    const m: u64 = @intFromFloat(@max(secs, 0) / 60);
    if (m < 60) return Phrase("{n:count} min").with(h, .{ .n = m });
    if (m < 48 * 60) return Phrase("{n:count} h").with(h, .{ .n = m / 60 });
    return Phrase("{n:count} d").with(h, .{ .n = m / (24 * 60) });
}

fn readings(h: *H, s: *const ad.Snapshot) N {
    const hist = s.history;
    if (hist.len < 2) return .none;
    var tiles: std.ArrayList(strip.Item) = .empty;
    for ([_]struct { Col, Text }{ .{ .matches, W.matches_day }, .{ .timelines, W.timelines_day } }) |x| {
        const r6 = growth(hist, x[0], 0.25);
        const r24 = growth(hist, x[0], 1);
        const wk = growth(hist, x[0], 7);
        const shift: ?f64 = if (r6 != null and r24 != null and r24.? != 0) r6.? / r24.? - 1 else null;
        const big = if (shift) |d| @abs(d) > 0.25 else false;
        add(h, &tiles, .{
            .label = x[1],
            .value = kilo(h, r24),
            .ctx = if (big) W.trend_shift.with(h, .{
                .a = kilo(h, r6).s,
                .b = kilo(h, wk).s,
                .d = (if (shift.? > 0) W.up else W.down).s,
                .p = @as(u64, @intFromFloat(@round(@abs(shift.?) * 100))),
            }) else W.trend.with(h, .{ .a = kilo(h, r6).s, .b = kilo(h, wk).s }),
            .step = if (shift != null and shift.? < -0.5) warn else null,
        });
    }
    const args = s.riot.crawl_args;
    const m24 = growth(hist, .matches, 1);
    const t24 = growth(hist, .timelines, 1);
    if (m24 != null and t24 != null and m24.? > 0) add(h, &tiles, .{
        .label = W.per_match,
        .value = phrase.num(h, .rate, t24.? / m24.? * 100),
        .ctx = if (flag(args, "timelines")) |v| W.asks.with(h, .{ .n = v }) else W.share,
    });
    const lastr = hist[hist.len - 1];
    for ([_]struct { Col, Text }{ .{ .match_queue, W.match_queue }, .{ .timeline_queue, W.timeline_queue } }) |x| {
        if (at(lastr, x[0])) |q| if (growth(hist, x[0], 1)) |r| {
            const qf: f64 = @floatFromInt(q);
            const flat = @abs(r) < qf * 0.02;
            add(h, &tiles, .{
                .label = x[1],
                .value = phrase.num(h, .count, q),
                .ctx = if (flat) W.steady else if (r < 0) W.shrinking.with(h, .{ .n = kilo(h, -r).s, .d = span(h, qf / -r * 86400).s }) else W.growing.with(h, .{ .n = kilo(h, r).s }),
                .step = if (!flat and r > 0) warn else null,
            });
        };
    }
    if (growth(hist, .mastery, 1)) |ms| add(h, &tiles, .{ .label = W.mastery_day, .value = kilo(h, ms), .ctx = if (ms > 0) W.collecting else W.not_collecting });
    var lines = h.list();
    if (args.len > 0) {
        const keep = struct {
            fn f(hh: *H, v: ?[]const u8) []const u8 {
                const x = v orelse return "?";
                return if (std.mem.eql(u8, x, "0")) W.forever.s else W.keep_days.with(hh, .{ .n = x }).s;
            }
        }.f;
        lines.add(h.li(.{}, .{W.keep.with(h, .{
            .m = keep(h, flag(args, "raw-match-days")),
            .t = keep(h, flag(args, "raw-timeline-days")),
            .c = keep(h, flag(args, "keep-days")),
        })}));
        lines.add(h.li(.{}, .{W.ladder.with(h, .{
            .t = flag(args, "min-tier") orelse "?",
            .n = flag(args, "ladder-per-hour") orelse "?",
            .r = flag(args, "ladder-refresh-hours") orelse "?",
        })}));
    }
    return card.view(h, .{}, &.{
        card.head(h, W.readings, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.readings_sub}),
        strip.view(h, tiles.items),
        if (args.len > 0) h.ul(.{ .class = "readings" }, .{lines.done()}) else .none,
    });
}

fn add(h: *H, l: *std.ArrayList(strip.Item), it: strip.Item) void {
    l.append(h.mem, it) catch {
        h.oom = true;
    };
}

pub fn crawler(ch: *Charts, h: *H, s: *const ad.Snapshot) N {
    const sp = spanOf(ch, s);
    const start = startOf(sp);
    const step = sp.c.step;
    const all: u8 = ch.regions;
    const per_bucket = h.mem.alloc(?f32, sp.c.buckets.len - sp.first) catch {
        h.oom = true;
        return .none;
    };
    for (sp.c.buckets[sp.first..], per_bucket) |b, *o| o.* = if (b.covered == 0) null else @floatFromInt(b.queued_max);
    // Only kinds seen in the range, each in its own colour
    var kinds: std.ArrayList(timechart.Series) = .empty;
    for (std.enums.values(ad.Kind)) |kind| {
        const i = @backingInt(kind);
        for (sp.c.buckets[sp.first..]) |b| if (b.warnings[i] > 0) {
            kinds.append(h.mem, .{ .name = ap.kind_names.get(kind), .values = warnings(h, sp, kind), .colour = i }) catch {
                h.oom = true;
            };
            break;
        };
    }
    const common: timechart.Time = .{ .label = W.matches, .start = start, .step = step, .series = &.{}, .marks = sp.c.restarts };
    var o = common;
    var charts = h.list();
    o.label = W.matches;
    o.kind = .area;
    o.series = byRegion(ch, h, sp, .m, 3600);
    charts.add(chart(ch, h, .matches, null, o));
    o.label = W.timelines;
    o.series = byRegion(ch, h, sp, .t, 3600);
    charts.add(chart(ch, h, .timelines, null, o));
    o = common;
    o.label = W.calls;
    o.series = series(h, &.{
        .{ .name = W.ladder_pages, .values = rates(h, sp, .ladder, all, 3600) },
        .{ .name = W.mastery, .values = rates(h, sp, .mastery, all, 3600) },
        .{ .name = W.id_lists, .values = rates(h, sp, .ids, all, 3600) },
    });
    charts.add(chart(ch, h, .calls, null, o));
    o.label = W.commits;
    o.series = series(h, &.{.{ .name = W.commits_s, .values = rates(h, sp, .commits, all, 60) }});
    charts.add(chart(ch, h, .commits, W.commits_sub, o));
    o.label = W.writer;
    o.series = series(h, &.{.{ .name = W.waiting, .values = per_bucket }});
    o.refs = refs(h, &.{.{ .v = writer_cap, .label = W.full }});
    charts.add(chart(ch, h, .writer, null, o));
    o.refs = &.{};
    o.label = W.pages;
    o.series = series(h, &.{
        .{ .name = W.written, .values = rates(h, sp, .pages_written, all, 60) },
        .{ .name = W.read, .values = rates(h, sp, .pages_read, all, 60) },
    });
    charts.add(chart(ch, h, .pages, null, o));
    o.label = W.warnings;
    o.kind = .bars;
    o.series = kinds.items;
    charts.add(chart(ch, h, .warnings, null, o));

    return h.div(.{ .class = "tab" }, .{
        readings(h, s),
        controls(ch, h, s, true),
        h.p(.{ .class = "lead" }, .{if (sp.live) W.live_sub else W.crawler_sub}),
        h.div(.{ .class = "charts" }, .{charts.done()}),
        messages(ch, h, sp.c),
        queues(ch, h, s),
    });
}

fn series(h: *H, xs: []const timechart.Series) []const timechart.Series {
    return h.mem.dupe(timechart.Series, xs) catch {
        h.oom = true;
        return &.{};
    };
}

fn refs(h: *H, xs: []const timechart.Ref) []const timechart.Ref {
    return h.mem.dupe(timechart.Ref, xs) catch {
        h.oom = true;
        return &.{};
    };
}

fn messages(ch: *Charts, h: *H, c: ad.Crawl) N {
    if (c.messages.len == 0) return .none;
    var rows = h.list();
    for (c.messages) |m| rows.add(h.tr(.{}, .{
        h.td(.{ .class = "nw" }, .{ap.kind_names.get(m.kind)}),
        h.td(.{ .class = "msg" }, .{m.text}),
        h.td(.{ .class = "num" }, .{phrase.num(h, .count, m.count)}),
        h.td(.{ .class = "nw" }, .{ap.ago(h, ch.now - m.last)}),
    }));
    return h.el(.details, .{ .class = "c-card", .open = true }, .{
        h.el(.summary, .{}, .{ W.messages.with(h, .{ .n = c.messages.len }), " ", h.a(.{ .href = "#tab=logs", .class = "sub" }, .{W.raw_log}) }),
        h.div(.{ .class = "tw" }, .{h.table(.{}, .{
            h.thead(.{}, .{h.tr(.{}, .{
                h.th(.{}, .{W.c_kind}),
                h.th(.{}, .{W.c_message}),
                h.th(.{ .class = "num", .data_answer = true }, .{W.c_count}),
                h.th(.{}, .{W.c_last}),
            })}),
            h.tbody(.{}, .{rows.done()}),
        })}),
    });
}

/// Groups as bars on one scale (AdminTraffic's too)
pub fn groupBars(h: *H, title: Text, sub: ?Text, gs: []const ad.Group, key: Text, value: Text) N {
    var most: i64 = 0;
    for (gs) |g| most = @max(most, g.n);
    var rows = h.list();
    for (gs) |g| rows.add(h.tr(.{}, .{
        h.th(.{ .scope = "row" }, .{g.key}),
        h.td(.{ .class = "barcell" }, .{bar.view(h, @floatFromInt(g.n), @floatFromInt(most), phrase.num(h, .count, g.n))}),
    }));
    return card.view(h, .{}, &.{
        card.head(h, title, null, &.{}),
        if (sub) |x| h.p(.{ .class = "lead" }, .{x}) else .none,
        if (gs.len == 0) h.p(.{ .class = "lead" }, .{W.no_rows}) else h.table(.{ .class = "bars" }, .{
            h.thead(.{}, .{h.tr(.{}, .{ h.th(.{}, .{key}), h.th(.{ .data_answer = true }, .{value}) })}),
            h.tbody(.{}, .{rows.done()}),
        }),
    });
}

/// The snapshots, 15 minutes apart, as 15-minute buckets
const hist_step = 900;

fn histStart(hist: []const ad.HistoryRow) i64 {
    return @divFloor(hist[0].time, hist_step) * hist_step;
}

/// A history column per bucket from histStart, times `scale`; null without a snapshot
fn histValues(h: *H, hist: []const ad.HistoryRow, c: Col, scale: f64) []const ?f32 {
    const start = histStart(hist);
    const len: usize = @intCast(@divFloor(hist[hist.len - 1].time - start, hist_step) + 1);
    const out = h.mem.alloc(?f32, len) catch {
        h.oom = true;
        return &.{};
    };
    @memset(out, null);
    for (hist) |r| if (at(r, c)) |v| {
        out[@intCast(@divFloor(r.time - start, hist_step))] = @floatCast(@as(f64, @floatFromInt(v)) * scale);
    };
    return out;
}

fn histChart(ch: *Charts, h: *H, c: Chart, hist: []const ad.HistoryRow, o: timechart.Time) N {
    var x = o;
    x.start = histStart(hist);
    x.step = hist_step;
    return chart(ch, h, c, null, x);
}

fn queues(ch: *Charts, h: *H, s: *const ad.Snapshot) N {
    const q = if (ch.live) |l| l.queues else s.queues;
    const hist = s.history;
    return h.div(.{ .class = "tab" }, .{
        card.sechead(h, W.queues, null, &.{}),
        h.div(.{ .class = "cards" }, .{
            groupBars(h, W.match_queue, null, q.match, W.c_state, W.c_jobs),
            groupBars(h, W.timeline_queue, null, q.timeline, W.c_state, W.c_jobs),
        }),
        if (hist.len >= 2) histChart(ch, h, .backlog, hist, .{
            .label = W.backlog,
            .start = 0,
            .series = series(h, &.{
                .{ .name = W.match_q, .values = histValues(h, hist, .match_queue, 1) },
                .{ .name = W.timeline_q, .values = histValues(h, hist, .timeline_queue, 1) },
            }),
        }) else null,
    });
}

fn oom(h: *H) N {
    h.oom = true;
    return .none;
}

/// Requests a minute of the last hour per region, from the newest crawl data
fn lastHour(c: ad.Crawl, now: i64, i: usize) ?f64 {
    var v: f64 = 0;
    var cov: f64 = 0;
    for (c.buckets, 0..) |b, j| if (c.start + @as(i64, @intCast(j)) * c.step >= now - 3600) {
        v += @floatFromInt(b.req[i]);
        cov += @floatFromInt(b.covered);
    };
    return if (cov > 0) v * 60 / cov else null;
}

fn dayCount(s: *const ad.Snapshot, k: ad.Kind) u64 {
    const c = s.crawl;
    var v: u64 = 0;
    for (c.buckets, 0..) |b, j| if (c.start + @as(i64, @intCast(j)) * c.step >= s.now - 86400) {
        v += b.warnings[@backingInt(k)];
    };
    return v;
}

pub fn riot(ch: *Charts, h: *H, s: *const ad.Snapshot) N {
    const newest = crawlOf(ch, s);
    const now = if (ch.live != null and newest.buckets.len > 0 and newest.step != s.crawl.step) ch.live.?.now else s.now;
    var tiles: std.ArrayList(strip.Item) = .empty;
    for (std.enums.values(ad.Region)) |r| {
        const i = @backingInt(r);
        if (ch.regions & bit(i) == 0) continue;
        const pm = lastHour(newest, now, i);
        const use = if (pm) |x| x / ap.per_region_min else null;
        add(h, &tiles, .{
            .label = region_names.get(r),
            .value = if (use) |u| phrase.num(h, .rate, u * 100) else Text{ .s = "–" },
            .ctx = W.of_limit.with(h, .{ .n = @as(u64, @intFromFloat(@round(pm orelse 0))), .l = ap.per_region_min }),
            .step = if (use != null and use.? > 0.98) warn else null,
        });
    }
    const r429 = dayCount(s, .rate_limit);
    add(h, &tiles, .{ .label = W.r429, .value = phrase.num(h, .count, r429), .ctx = W.ours, .step = if (r429 > 50) warn else null });
    add(h, &tiles, .{ .label = W.busy, .value = phrase.num(h, .count, dayCount(s, .riot_busy)), .ctx = W.riots });
    add(h, &tiles, .{ .label = W.r5xx, .value = phrase.num(h, .count, dayCount(s, .riot_server)), .ctx = W.errors_s });
    const kp = s.riot.key_problems;
    add(h, &tiles, .{
        .label = W.problems,
        .value = if (kp.len > 0) phrase.num(h, .count, kp.len) else W.none,
        .ctx = if (kp.len > 0) W.last.with(h, .{ .t = ap.ago(h, s.now - kp[kp.len - 1].time).s }) else W.no_401,
        .step = if (kp.len > 0) bad else null,
    });
    const args = s.riot.crawl_args;
    if (args.len > 0) {
        const proxy = flag(args, "proxy") != null;
        add(h, &tiles, .{
            .label = W.your,
            .value = if (proxy) W.first else W.no_proxy,
            .ctx = if (proxy) W.proxy_on else W.proxy_off,
            .step = if (proxy) null else bad,
        });
    }

    const sp = spanOf(ch, s);
    const common: timechart.Time = .{ .label = W.requests, .start = startOf(sp), .step = sp.c.step, .series = &.{}, .marks = sp.c.restarts };
    var o = common;
    var charts = h.list();
    o.series = byRegion(ch, h, sp, .req, 60);
    o.refs = refs(h, &.{.{ .v = ap.per_region_min, .label = W.key_limit }});
    charts.add(chart(ch, h, .requests, null, o));
    o = common;
    o.label = W.platform;
    o.series = series(h, &.{.{ .name = W.platform_s, .values = rates(h, sp, .platform_req, ch.regions, 60), .colour = 4 }});
    charts.add(chart(ch, h, .platform, W.platform_sub, o));
    o.label = W.errors;
    o.kind = .bars;
    o.series = series(h, &.{
        .{ .name = W.e_ours, .values = warnings(h, sp, .rate_limit), .colour = 3 },
        .{ .name = W.e_server, .values = warnings(h, sp, .riot_busy), .colour = 5 },
        .{ .name = W.e_5xx, .values = warnings(h, sp, .riot_server), .colour = 1 },
    });
    charts.add(chart(ch, h, .errors, null, o));

    return h.div(.{ .class = "tab" }, .{
        card.view(h, .{}, &.{
            card.head(h, W.key, null, &.{}),
            h.p(.{ .class = "lead" }, .{W.key_sub}),
            strip.view(h, tiles.items),
        }),
        controls(ch, h, s, true),
        h.div(.{ .class = "charts" }, .{charts.done()}),
        h.div(.{ .class = "cards" }, .{ limits(h, s.riot), keyProblems(h, kp) }),
    });
}

fn limits(h: *H, r: ad.Riot) N {
    var rows = h.list();
    var it = std.mem.tokenizeScalar(u8, r.app_limit, ',');
    while (it.next()) |part| {
        const c = std.mem.indexOfScalar(u8, part, ':') orelse continue;
        const lim = std.fmt.parseInt(u32, part[0..c], 10) catch continue;
        const secs = std.fmt.parseInt(u32, part[c + 1 ..], 10) catch continue;
        if (secs == 0) continue;
        rows.add(h.tr(.{}, .{
            h.th(.{ .scope = "row" }, .{W.app}),
            h.td(.{ .class = "num" }, .{phrase.num(h, .count, lim)}),
            h.td(.{ .class = "num" }, .{if (secs < 60) Phrase("{n:count} s").with(h, .{ .n = secs }) else span(h, @floatFromInt(secs))}),
            h.td(.{ .class = "num" }, .{phrase.num(h, .count, lim * 60 / secs)}),
        }));
    }
    return card.view(h, .{}, &.{
        card.head(h, W.limits, null, &.{}),
        h.table(.{}, .{
            h.thead(.{}, .{h.tr(.{}, .{
                h.th(.{}, .{W.c_bucket}),
                h.th(.{ .class = "num" }, .{W.c_requests}),
                h.th(.{ .class = "num" }, .{W.c_window}),
                h.th(.{ .class = "num", .data_answer = true }, .{W.c_per_min}),
            })}),
            h.tbody(.{}, .{rows.done()}),
        }),
        if (r.crawl_args.len > 0) h.p(.{ .class = "lead" }, .{ W.args, ": ", h.span(.{ .class = "mono" }, .{std.mem.trim(u8, r.crawl_args, " \n")}) }) else .none,
    });
}

fn keyProblems(h: *H, kp: []const ad.KeyProblem) N {
    var rows = h.list();
    var i = kp.len;
    while (i > 0) {
        i -= 1;
        rows.add(h.tr(.{}, .{ h.td(.{ .class = "nw" }, .{ap.when(h, kp[i].time)}), h.td(.{ .class = "msg" }, .{kp[i].text}) }));
    }
    return card.view(h, .{}, &.{
        card.head(h, W.problems, null, &.{}),
        if (kp.len == 0) h.p(.{ .class = "lead" }, .{W.no_problems}) else h.div(.{ .class = "tw" }, .{h.table(.{}, .{
            h.thead(.{}, .{h.tr(.{}, .{ h.th(.{}, .{W.c_when}), h.th(.{ .data_answer = true }, .{W.c_text}) })}),
            h.tbody(.{}, .{rows.done()}),
        })}),
    });
}

// Storage

/// "132.4 GB", "512.0 MB"
pub fn bytes(h: *H, v: ?f64) Text {
    const x = v orelse return .{ .s = "–" };
    const a = @abs(x);
    const sign: []const u8 = if (x < 0) "-" else "";
    if (a >= 1e9) return Phrase("{s:text}{n:dec} GB").with(h, .{ .s = sign, .n = a / 1e9 });
    if (a >= 1e6) return Phrase("{s:text}{n:dec} MB").with(h, .{ .s = sign, .n = a / 1e6 });
    if (a >= 1e3) return Phrase("{s:text}{n:dec} KB").with(h, .{ .s = sign, .n = a / 1e3 });
    return Phrase("{s:text}{n:count} B").with(h, .{ .s = sign, .n = @as(u64, @intFromFloat(a)) });
}

/// A history column named as the counts' table (timeline.timelines is timelines)
fn colOf(table: []const u8) ?Col {
    return std.meta.stringToEnum(Col, if (std.mem.eql(u8, table, "timeline.timelines")) "timelines" else table);
}

pub fn storage(ch: *Charts, h: *H, s: *const ad.Snapshot) N {
    const hist = s.history;
    const dk = if (ch.live) |l| l.disk orelse s.disk else s.disk;
    var tiles: std.ArrayList(strip.Item) = .empty;
    const span_s: f64 = if (hist.len > 1) @min(7 * 86400, @as(f64, @floatFromInt(hist[hist.len - 1].time - hist[0].time))) else 0;
    if (dk) |d| if (d.size > 0) {
        const used = @as(f64, @floatFromInt(d.used)) / @as(f64, @floatFromInt(d.size));
        add(h, &tiles, .{
            .label = W.disk_used,
            .value = phrase.num(h, .rate, used * 100),
            .ctx = W.of.with(h, .{ .a = bytes(h, @floatFromInt(d.used)).s, .b = bytes(h, @floatFromInt(d.size)).s }),
            .step = if (used > 0.8) bad else if (used > 0.65) warn else null,
        });
        const g = growthLess(hist, .disk_used, wal_all, 7);
        const g1 = growthLess(hist, .disk_used, wal_all, 1);
        add(h, &tiles, .{
            .label = W.disk_growth,
            .value = if (g) |x| W.per_day.with(h, .{ .b = bytes(h, x).s }) else Text{ .s = "–" },
            .ctx = if (g1) |x| W.over_day.with(h, .{ .b = bytes(h, x).s }) else W.over.with(h, .{ .t = span(h, span_s).s }),
        });
        if (g) |x| if (x > 0) {
            const left = @as(f64, @floatFromInt(d.free)) / x;
            const faster: ?f64 = if (g1) |y| (if (y > x) @as(f64, @floatFromInt(d.free)) / y else null) else null;
            const ld: u64 = @intFromFloat(@round(left));
            add(h, &tiles, .{
                .label = W.full_at,
                .value = ap.day(h, s.now + @as(i64, @intFromFloat(@min(left, 1e5) * 86400))),
                .ctx = if (faster) |f| W.full_in2.with(h, .{ .n = ld, .m = @as(u64, @intFromFloat(@round(f))) }) else W.full_in.with(h, .{ .n = ld }),
                .step = if (left < 14) bad else if (left < 30) warn else null,
            });
        };
    };
    var total: f64 = 0;
    var parts: std.Io.Writer.Allocating = .init(h.mem);
    for (s.files, 0..) |f, i| {
        total += @floatFromInt(f.bytes);
        const nm = if (std.mem.endsWith(u8, f.name, ".db")) f.name[0 .. f.name.len - 3] else f.name;
        parts.writer.print("{s}{s} {s}", .{ if (i > 0) ", " else "", nm, bytes(h, @floatFromInt(f.bytes)).s }) catch {
            h.oom = true;
        };
    }
    add(h, &tiles, .{ .label = W.databases, .value = bytes(h, total), .ctx = W.files_n.with(h, .{ .n = s.files.len }) });
    for (s.counts) |c| if (std.mem.eql(u8, c.name, "matches") and c.rows > 0) {
        add(h, &tiles, .{ .label = W.per_stored, .value = bytes(h, total / @as(f64, @floatFromInt(c.rows))), .ctx = W.all_dbs });
    };
    const gm = growthLess(hist, .meiolol_db, &.{.meiolol_wal}, 7);
    const gt = growthLess(hist, .timeline_db, &.{.timeline_wal}, 7);
    const gr = growthLess(hist, .raw_db, &.{.raw_wal}, 7);
    add(h, &tiles, .{
        .label = W.db_growth,
        .value = if (gm == null and gt == null and gr == null) Text{ .s = "–" } else W.per_day.with(h, .{ .b = bytes(h, (gm orelse 0) + (gt orelse 0) + (gr orelse 0)).s }),
    });
    if (s.backups) |b| add(h, &tiles, .{
        .label = W.backups,
        .value = bytes(h, @floatFromInt(b.bytes)),
        .ctx = W.backups_sub.with(h, .{ .n = b.files, .t = ap.ago(h, s.now - b.newest).s }),
        .step = if (b.newest > 0 and s.now - b.newest > 2 * 86400) warn else null,
    });

    var charts = h.list();
    if (hist.len >= 2) {
        charts.add(histChart(ch, h, .dbfiles, hist, .{
            .label = W.files,
            .kind = .area,
            .unit = .gb,
            .start = 0,
            .series = series(h, &.{
                .{ .name = .{ .s = "meiolol.db" }, .values = histValues(h, hist, .meiolol_db, 1e-9) },
                .{ .name = .{ .s = "timeline.db" }, .values = histValues(h, hist, .timeline_db, 1e-9) },
                .{ .name = .{ .s = "raw.db" }, .values = histValues(h, hist, .raw_db, 1e-9) },
            }),
        }));
        if (dk) |d| charts.add(histChart(ch, h, .disk, hist, .{
            .label = W.disk_used,
            .unit = .gb,
            .start = 0,
            .series = series(h, &.{.{ .name = W.used, .values = histValues(h, hist, .disk_used, 1e-9), .colour = 1 }}),
            .refs = refs(h, &.{.{ .v = @floatCast(@as(f64, @floatFromInt(d.size)) / 1e9), .label = W.disk_size }}),
        }));
    }
    return h.div(.{ .class = "tab" }, .{
        card.view(h, .{}, &.{
            card.head(h, W.space, null, &.{}),
            h.p(.{ .class = "lead" }, .{W.space_sub}),
            strip.view(h, tiles.items),
            h.p(.{ .class = "lead" }, .{W.growths.with(h, .{ .a = bytes(h, gm).s, .b = bytes(h, gt).s, .c = bytes(h, gr).s, .f = @as([]const u8, parts.written()) })}),
        }),
        if (hist.len >= 2) h.p(.{ .class = "lead" }, .{W.files_sub}) else null,
        h.div(.{ .class = "charts" }, .{charts.done()}),
        space(h, s),
        rowsOf(ch, h, s),
    });
}

/// Per table and index, from the daily dbstat scan
fn space(h: *H, s: *const ad.Snapshot) N {
    const st = s.storage orelse return h.div(.{ .class = "tab" }, .{ card.sechead(h, W.what, null, &.{}), h.p(.{ .class = "lead" }, .{W.no_scan}) });
    const rows = h.mem.dupe(ad.StorageRow, st.rows) catch return oom(h);
    std.mem.sort(ad.StorageRow, rows, {}, struct {
        fn f(_: void, a: ad.StorageRow, b: ad.StorageRow) bool {
            return a.bytes > b.bytes;
        }
    }.f);
    var cards = h.list();
    var dbs: std.ArrayList([]const u8) = .empty;
    for (rows) |x| {
        for (dbs.items) |d| {
            if (std.mem.eql(u8, d, x.db)) break;
        } else dbs.append(h.mem, x.db) catch return oom(h);
    }
    const totals = h.mem.alloc(f64, dbs.items.len) catch return oom(h);
    for (dbs.items, totals) |d, *t| {
        var sum: f64 = 0;
        var idx: f64 = 0;
        var most: f64 = 0;
        var listed: usize = 0;
        var rest: f64 = 0;
        var restn: usize = 0;
        var list = h.list();
        for (rows) |x| if (std.mem.eql(u8, x.db, d)) {
            const b: f64 = @floatFromInt(x.bytes);
            sum += b;
            if (std.mem.eql(u8, x.kind, "index")) idx += b;
            most = @max(most, b);
        };
        t.* = sum;
        for (rows) |x| if (std.mem.eql(u8, x.db, d)) {
            const b: f64 = @floatFromInt(x.bytes);
            if (listed == 8) {
                rest += b;
                restn += 1;
                continue;
            }
            listed += 1;
            list.add(h.tr(.{}, .{
                h.th(.{ .scope = "row" }, .{ x.name, if (std.mem.eql(u8, x.kind, "index")) h.small(.{}, .{ " ", W.index }) else null }),
                h.td(.{ .class = "barcell" }, .{bar.view(h, b, most, bytes(h, b))}),
            }));
        };
        if (restn > 0) list.add(h.tr(.{}, .{
            h.th(.{ .scope = "row" }, .{W.more.with(h, .{ .n = restn })}),
            h.td(.{ .class = "barcell" }, .{bar.view(h, rest, most, bytes(h, rest))}),
        }));
        cards.add(card.view(h, .{}, &.{
            card.head(h, W.db_total.with(h, .{ .d = d, .b = bytes(h, sum).s }), null, &.{}),
            h.p(.{ .class = "lead" }, .{W.indexes.with(h, .{ .p = @as(u64, @intFromFloat(@round(if (sum > 0) idx / sum * 100 else 0))) })}),
            h.table(.{ .class = "bars" }, .{
                h.thead(.{}, .{h.tr(.{}, .{ h.th(.{}, .{W.c_name}), h.th(.{ .data_answer = true }, .{W.c_size}) })}),
                h.tbody(.{}, .{list.done()}),
            }),
        }));
    }
    var all = h.list();
    for (rows) |x| {
        var t: f64 = 0;
        for (dbs.items, totals) |d, v| if (std.mem.eql(u8, d, x.db)) {
            t = v;
        };
        const b: f64 = @floatFromInt(x.bytes);
        all.add(h.tr(.{}, .{
            h.td(.{}, .{x.db}),
            h.td(.{ .class = "msg" }, .{x.name}),
            h.td(.{}, .{x.kind}),
            h.td(.{ .class = "num" }, .{bytes(h, b)}),
            h.td(.{ .class = "num" }, .{phrase.num(h, .rate, if (t > 0) b / t * 100 else 0)}),
            h.td(.{ .class = "num" }, .{phrase.num(h, .count, x.cells)}),
            h.td(.{ .class = "num" }, .{if (x.cells > 0) phrase.num(h, .count, x.bytes / x.cells) else Text{ .s = "–" }}),
        }));
    }
    return h.div(.{ .class = "tab" }, .{
        card.sechead(h, W.what, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.what_sub.with(h, .{ .t = ap.ago(h, s.now - st.generated).s })}),
        h.div(.{ .class = "cards" }, .{cards.done()}),
        h.el(.details, .{ .class = "c-card" }, .{
            h.el(.summary, .{}, .{W.every.with(h, .{ .n = rows.len })}),
            h.div(.{ .class = "tw" }, .{h.table(.{}, .{
                h.thead(.{}, .{h.tr(.{}, .{
                    h.th(.{}, .{W.c_db}),
                    h.th(.{}, .{W.c_name}),
                    h.th(.{}, .{W.c_kind}),
                    h.th(.{ .class = "num", .data_answer = true }, .{W.c_size}),
                    h.th(.{ .class = "num" }, .{W.c_share}),
                    h.th(.{ .class = "num" }, .{W.c_cells}),
                    h.th(.{ .class = "num" }, .{W.c_per_cell}),
                })}),
                h.tbody(.{}, .{all.done()}),
            })}),
        }),
    });
}

/// Row counts: a small chart each, and the table
fn rowsOf(ch: *Charts, h: *H, s: *const ad.Snapshot) N {
    const hist = s.history;
    var minis = h.list();
    if (hist.len >= 2) {
        for ([_]struct { Chart, Col, Text }{
            .{ .m_matches, .matches, W.r_matches },
            .{ .m_timelines, .timelines, W.r_timelines },
            .{ .m_drafts, .drafts, W.r_drafts },
            .{ .m_players, .players, W.r_players },
            .{ .m_ranks, .ranks, W.r_ranks },
            .{ .m_mastery, .mastery, W.r_mastery },
        }) |x| minis.add(histChart(ch, h, x[0], hist, .{
            .label = x[2],
            .start = 0,
            .height = 100,
            .series = series(h, &.{.{ .name = x[2], .values = histValues(h, hist, x[1], 1) }}),
        }));
    }
    var day_ago: ?ad.HistoryRow = null;
    for (hist) |r| if (r.time >= s.now - 86400) {
        day_ago = r;
        break;
    };
    var rows = h.list();
    for (s.counts) |c| {
        const col = colOf(c.name);
        const before = if (day_ago) |r| (if (col) |x| at(r, x) else null) else null;
        rows.add(h.tr(.{}, .{
            h.th(.{ .scope = "row" }, .{c.name}),
            h.td(.{ .class = "num" }, .{phrase.num(h, .count, c.rows)}),
            h.td(.{ .class = "num" }, .{if (before) |b| phrase.num(h, .signed, c.rows - @as(i64, @intCast(b))) else null}),
            h.td(.{ .class = "num" }, .{if (if (col) |x| growth(hist, x, 7) else null) |g| kilo(h, g) else null}),
        }));
    }
    return h.div(.{ .class = "tab" }, .{
        card.sechead(h, W.rows, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.rows_sub}),
        h.div(.{ .class = "minis" }, .{minis.done()}),
        card.view(h, .{ .flush = true }, &.{h.div(.{ .class = "tw" }, .{h.table(.{}, .{
            h.thead(.{}, .{h.tr(.{}, .{
                h.th(.{}, .{W.c_table}),
                h.th(.{ .class = "num", .data_answer = true }, .{W.c_rows}),
                h.th(.{ .class = "num" }, .{W.c_day}),
                h.th(.{ .class = "num" }, .{W.c_week}),
            })}),
            h.tbody(.{}, .{rows.done()}),
        })})}),
    });
}

// Ingest

fn regionOf(s: *const ad.Snapshot, platform: []const u8) ?ad.Region {
    for (s.platforms) |p| if (std.mem.eql(u8, p.id, platform)) return p.region;
    return null;
}

fn shown(ch: *const Charts, r: ad.Region) bool {
    return ch.regions & bit(@backingInt(r)) != 0;
}

pub fn ingest(ch: *Charts, h: *H, s: *const ad.Snapshot) N {
    const m = s.drafts;
    const days = m.days;
    var day_chart: ?N = null;
    if (days.len > 0) {
        var l: std.ArrayList(timechart.Series) = .empty;
        const recent = h.mem.alloc(?f32, days.len) catch return oom(h);
        const cut = h.mem.alloc(?f32, days.len) catch return oom(h);
        @memset(recent, 0);
        @memset(cut, 0);
        for (std.enums.values(ad.Region)) |r| {
            if (!shown(ch, r)) continue;
            const i = @backingInt(r);
            const v = h.mem.alloc(?f32, days.len) catch return oom(h);
            for (days, v, 0..) |d, *o, k| {
                // The window's first day is cut by the row limit
                if (k == 0) {
                    o.* = 0;
                    cut[0].? += @floatFromInt(d.region[i]);
                    continue;
                }
                o.* = @floatFromInt(d.region[i] -| d.recent[i]);
                recent[k].? += @floatFromInt(d.recent[i]);
            }
            l.append(h.mem, .{ .name = region_names.get(r), .values = v, .colour = i }) catch return oom(h);
        }
        l.append(h.mem, .{ .name = W.recent, .values = recent, .colour = 4 }) catch return oom(h);
        l.append(h.mem, .{ .name = W.cut, .values = cut, .colour = 5 }) catch return oom(h);
        day_chart = chart(ch, h, .gamedays, W.by_day_sub, .{
            .label = W.by_day,
            .kind = .bars,
            .clock = .utc,
            .start = @as(i64, days[0].day) * 86400,
            .step = 86400,
            .series = l.items,
        });
    }
    var most: u64 = 0;
    for (m.minutes) |x| most = @max(most, x);
    var lens = h.list();
    for (m.minutes, 0..) |x, i| lens.add(h.tr(.{}, .{
        h.th(.{ .scope = "row" }, .{if (i + 1 == m.minutes.len) W.mins_last else W.mins.with(h, .{ .a = i * 5, .b = i * 5 + 5 })}),
        h.td(.{ .class = "barcell" }, .{bar.view(h, @floatFromInt(x), @floatFromInt(most), phrase.num(h, .count, x))}),
    }));
    const unknown: u64 = if (m.tiers.len > 0) @intCast(@max(m.tiers[m.tiers.len - 1].n, 0)) else 0;
    var patches: std.Io.Writer.Allocating = .init(h.mem);
    for (m.patches, 0..) |p, i| patches.writer.print("{s}{s}", .{ if (i > 0) ", " else "", p.key }) catch {
        h.oom = true;
    };
    var plats: std.ArrayList(ad.Group) = .empty;
    for (m.platforms) |g| if (if (regionOf(s, g.key)) |r| shown(ch, r) else true) plats.append(h.mem, g) catch return oom(h);
    var pool: std.ArrayList(ad.Group) = .empty;
    for (s.players) |g| {
        const r = std.meta.stringToEnum(ad.Region, g.key);
        if (r == null or shown(ch, r.?)) pool.append(h.mem, g) catch return oom(h);
    }
    return h.div(.{ .class = "tab" }, .{
        controls(ch, h, s, false),
        h.p(.{ .class = "lead" }, .{W.ingest_sub.with(h, .{ .n = m.rows })}),
        day_chart,
        h.div(.{ .class = "cards" }, .{
            card.view(h, .{}, &.{
                card.head(h, W.length, null, &.{}),
                h.table(.{ .class = "bars" }, .{
                    h.thead(.{}, .{h.tr(.{}, .{ h.th(.{}, .{W.c_minutes}), h.th(.{ .data_answer = true }, .{W.c_games}) })}),
                    h.tbody(.{}, .{lens.done()}),
                }),
            }),
            card.view(h, .{}, &.{
                card.head(h, W.sanity, null, &.{}),
                h.table(.{ .class = "kv" }, .{
                    h.thead(.{}, .{h.tr(.{}, .{ h.th(.{}, .{W.c_check}), h.th(.{ .data_answer = true }, .{W.c_value}) })}),
                    h.tbody(.{}, .{
                        h.tr(.{}, .{ h.th(.{ .scope = "row" }, .{W.blue}), h.td(.{}, .{if (m.rows > 0) phrase.num(h, .rate, @as(f64, @floatFromInt(m.blue_wins)) / @as(f64, @floatFromInt(m.rows)) * 100) else Text{ .s = "–" }}) }),
                        h.tr(.{}, .{ h.th(.{ .scope = "row" }, .{W.ranked}), h.td(.{}, .{if (m.rows > 0) phrase.num(h, .rate, (1 - @as(f64, @floatFromInt(unknown)) / @as(f64, @floatFromInt(m.rows))) * 100) else Text{ .s = "–" }}) }),
                        h.tr(.{}, .{ h.th(.{ .scope = "row" }, .{W.platforms}), h.td(.{}, .{phrase.num(h, .count, m.platforms.len)}) }),
                        h.tr(.{}, .{ h.th(.{ .scope = "row" }, .{W.patches}), h.td(.{}, .{if (m.patches.len > 0) Text{ .s = patches.written() } else Text{ .s = "–" }}) }),
                    }),
                }),
            }),
            groupBars(h, W.by_platform, null, plats.items, W.c_platform, W.c_games),
            groupBars(h, W.by_rank, null, m.tiers, W.c_tier, W.c_games),
            groupBars(h, W.ladder_tiers, null, s.ladder, W.c_tier, W.c_players),
            groupBars(h, W.pool, null, pool.items, W.c_region, W.c_players),
            groupBars(h, W.by_patch, null, s.by_patch, W.c_patch, W.c_matches),
        }),
    });
}

pub const Demo = struct {
    pub fn charts(tab: ap.Tab) Charts {
        const d = ap.Demo;
        return .{ .tab = tab, .snap = &d.snap, .live = &d.live, .now = d.now };
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const states = [_][]const u8{ "crawler: a day, all regions", "crawler: 3 hours live, europe and asia", "Riot API: a key problem, one chart tipped", "loading", "another tab: hidden", "storage", "ingest: no sea" };
    for (states, 0..) |caption, i| {
        const ch = a.create(Charts) catch return;
        ch.* = switch (i) {
            0, 1 => Demo.charts(.crawler),
            2 => Demo.charts(.riot),
            3 => .{ .tab = .riot },
            5 => Demo.charts(.storage),
            6 => Demo.charts(.ingest),
            else => .{},
        };
        switch (i) {
            1 => {
                ch.range = .hours;
                ch.regions = 0b0110;
            },
            2 => ch.times[@backingInt(Chart.requests)].tip = 20,
            6 => ch.regions = 0b0111,
            else => {},
        }
        g.addFill(caption, ch.view(g.h));
    }
}

pub const css =
    \\@layer components {
    \\  .c-adcharts { display: grid; gap: var(--sp-3); }
    \\  .c-adcharts .tab { display: grid; gap: var(--sp-3); }
    \\  .c-adcharts .lead { margin: 0 0 var(--sp-2); color: var(--muted); font-size: var(--fs-s); }
    \\  .c-adcharts .ctl { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\  .c-adcharts .chips { display: flex; flex-wrap: wrap; gap: var(--sp-1); }
    \\  .c-adcharts .sw { display: inline-block; width: 0.6rem; height: 0.6rem; border-radius: 50%;
    \\    margin-inline-end: var(--sp-1); background: var(--s); }
    \\  .c-adcharts .sw[data-s="0"] { --s: var(--us); }
    \\  .c-adcharts .sw[data-s="1"] { --s: var(--drop); }
    \\  .c-adcharts .sw[data-s="2"] { --s: var(--gain); }
    \\  .c-adcharts .sw[data-s="3"] { --s: var(--accent); }
    \\  .c-adcharts .charts, .c-adcharts .cards { display: grid; gap: var(--sp-3);
    \\    grid-template-columns: repeat(auto-fit, minmax(min(100%, 26rem), 1fr)); }
    \\  .c-adcharts .minis { display: grid; gap: var(--sp-3);
    \\    grid-template-columns: repeat(auto-fit, minmax(min(100%, 18rem), 1fr)); }
    \\  .c-adcharts th small { color: var(--muted); }
    \\  .c-adcharts .readings { margin: 0; padding-inline-start: var(--sp-4); font-size: var(--fs-s); color: var(--muted); }
    \\  .c-adcharts .tw { overflow-x: auto; }
    \\  .c-adcharts table { width: 100%; border-collapse: collapse; font-size: var(--fs-s); }
    \\  .c-adcharts :is(th, td) { padding: var(--sp-1) var(--sp-2); border-bottom: 1px solid var(--line);
    \\    text-align: start; vertical-align: top; }
    \\  .c-adcharts thead th { color: var(--muted); font-weight: var(--w-m); }
    \\  .c-adcharts tbody th { font-size: inherit; font-weight: var(--w-r); color: var(--text);
    \\    text-transform: none; letter-spacing: normal; }
    \\  .c-adcharts :is(td, th).num { text-align: end; font-variant-numeric: tabular-nums; }
    \\  .c-adcharts .nw { white-space: nowrap; }
    \\  .c-adcharts .msg { overflow-wrap: anywhere; }
    \\  .c-adcharts .mono { font-family: ui-monospace, monospace; font-size: var(--fs-xs); }
    \\  .c-adcharts table.bars th { width: 40%; overflow-wrap: anywhere; }
    \\  .c-adcharts details.c-card > summary { cursor: pointer; font-weight: var(--w-b); }
    \\  .c-adcharts summary .sub { font-weight: var(--w-r); font-size: var(--fs-s); }
    \\}
    \\
;

const testing = std.testing;

test "admin charts: growth per day by least squares, WAL swings left out" {
    var hist: [9]ad.HistoryRow = undefined;
    for (&hist, 0..) |*r, i| {
        const k: u64 = @intCast(i);
        // 1 GB a day in the file, 3 h apart; the WAL swings by 4 GB and back
        r.* = .{ .time = @as(i64, @intCast(i)) * 3 * 3600, .meiolol_db = 100_000_000_000 + k * 125_000_000 + (if (i % 2 == 1) @as(u64, 4_000_000_000) else 0), .meiolol_wal = if (i % 2 == 1) 4_000_000_000 else 0, .matches = 1000 + k * 300 };
    }
    try testing.expectApproxEqAbs(@as(f64, 2400), growth(&hist, .matches, 7).?, 1e-6);
    try testing.expectApproxEqAbs(@as(f64, 1e9), growthLess(&hist, .meiolol_db, &.{.meiolol_wal}, 7).?, 1);
    // Under ~5 h of history: no rate
    try testing.expectEqual(@as(?f64, null), growth(hist[0..2], .matches, 7));
    try testing.expectEqual(@as(?f64, null), growth(&hist, .raw_db, 7));
}
