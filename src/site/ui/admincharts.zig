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
        return ch.tab == .crawler or ch.tab == .riot;
    }

    pub fn view(ch: *Charts, h: *H) N {
        const on = ch.shows();
        return h.div(.{ .class = "c-adcharts", .data_island = "admincharts", .data_js = ch.js, .data_wasm = ch.wasm, .hidden = !on }, .{
            if (!on) null else if (ch.snap) |s| switch (ch.tab) {
                .riot => riot(ch, h, s),
                else => crawler(ch, h, s),
            } else h.p(.{ .class = "lead", .role = "status" }, .{if (ch.snap_failed) ap.W.no_snap else ap.W.loading}),
        });
    }
};

/// One per chart on these tabs: its slot in Charts.times
pub const Chart = enum { matches, timelines, calls, commits, writer, pages, warnings, backlog, requests, platform, errors };
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
const warn: fmt.Step = .{ .s = 2, .low = true };
const bad: fmt.Step = .{ .s = 4, .low = true };

/// The range switcher and region chips over a crawl tab
fn controls(ch: *Charts, h: *H, s: *const ad.Snapshot) N {
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
        segmented.view(h, .{ .s = .s, .label = W.range }, &items),
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

/// Rate of a history column per day over the newest `days`, least squares; null under
/// ~5 h of history
fn growth(hist: []const ad.HistoryRow, comptime col: []const u8, days: f64) ?f64 {
    if (hist.len < 2) return null;
    const end = hist[hist.len - 1].time;
    const from = end - @as(i64, @intFromFloat(days * 86400));
    var k: f64 = 0;
    var sx: f64 = 0;
    var sy: f64 = 0;
    var t0: ?i64 = null;
    for (hist) |r| if (r.time >= from) if (@field(r, col)) |v| {
        if (t0 == null) t0 = r.time;
        k += 1;
        sx += @floatFromInt(r.time - end);
        sy += @floatFromInt(v);
    };
    if (k < 2 or end - t0.? < 86400 / 5) return null;
    const mx = sx / k;
    const my = sy / k;
    var sxy: f64 = 0;
    var sxx: f64 = 0;
    for (hist) |r| if (r.time >= from) if (@field(r, col)) |v| {
        const dx = @as(f64, @floatFromInt(r.time - end)) - mx;
        sxy += dx * (@as(f64, @floatFromInt(v)) - my);
        sxx += dx * dx;
    };
    return if (sxx > 0) sxy / sxx * 86400 else 0;
}

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
    inline for (.{ .{ "matches", W.matches_day }, .{ "timelines", W.timelines_day } }) |x| {
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
    const m24 = growth(hist, "matches", 1);
    const t24 = growth(hist, "timelines", 1);
    if (m24 != null and t24 != null and m24.? > 0) add(h, &tiles, .{
        .label = W.per_match,
        .value = phrase.num(h, .rate, t24.? / m24.? * 100),
        .ctx = if (flag(args, "timelines")) |v| W.asks.with(h, .{ .n = v }) else W.share,
    });
    const lastr = hist[hist.len - 1];
    inline for (.{ .{ "match_queue", W.match_queue }, .{ "timeline_queue", W.timeline_queue } }) |x| {
        if (@field(lastr, x[0])) |q| if (growth(hist, x[0], 1)) |r| {
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
    if (growth(hist, "mastery", 1)) |ms| add(h, &tiles, .{ .label = W.mastery_day, .value = kilo(h, ms), .ctx = if (ms > 0) W.collecting else W.not_collecting });
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
        controls(ch, h, s),
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

/// A queue's groups as bars on one scale
fn groupBars(h: *H, title: Text, gs: []const ad.Group) N {
    var most: i64 = 0;
    for (gs) |g| most = @max(most, g.n);
    var rows = h.list();
    for (gs) |g| rows.add(h.tr(.{}, .{
        h.th(.{ .scope = "row" }, .{g.key}),
        h.td(.{ .class = "barcell" }, .{bar.view(h, @floatFromInt(g.n), @floatFromInt(most), phrase.num(h, .count, g.n))}),
    }));
    return card.view(h, .{}, &.{
        card.head(h, title, null, &.{}),
        if (gs.len == 0) h.p(.{ .class = "lead" }, .{W.no_rows}) else h.table(.{ .class = "bars" }, .{
            h.thead(.{}, .{h.tr(.{}, .{ h.th(.{}, .{W.c_state}), h.th(.{ .data_answer = true }, .{W.c_jobs}) })}),
            h.tbody(.{}, .{rows.done()}),
        }),
    });
}

fn queues(ch: *Charts, h: *H, s: *const ad.Snapshot) N {
    const q = if (ch.live) |l| l.queues else s.queues;
    // The snapshots, 15 minutes apart, into 15-minute buckets
    const step = 900;
    const hist = s.history;
    var backlog: ?N = null;
    if (hist.len >= 2) {
        const start = @divFloor(hist[0].time, step) * step;
        const len: usize = @intCast(@divFloor(hist[hist.len - 1].time - start, step) + 1);
        const mq = h.mem.alloc(?f32, len) catch return oom(h);
        const tq = h.mem.alloc(?f32, len) catch return oom(h);
        @memset(mq, null);
        @memset(tq, null);
        for (hist) |r| {
            const i: usize = @intCast(@divFloor(r.time - start, step));
            if (r.match_queue) |v| mq[i] = @floatFromInt(v);
            if (r.timeline_queue) |v| tq[i] = @floatFromInt(v);
        }
        backlog = chart(ch, h, .backlog, null, .{
            .label = W.backlog,
            .start = start,
            .step = step,
            .series = series(h, &.{ .{ .name = W.match_q, .values = mq }, .{ .name = W.timeline_q, .values = tq } }),
        });
    }
    return h.div(.{ .class = "tab" }, .{
        card.sechead(h, W.queues, null, &.{}),
        h.div(.{ .class = "cards" }, .{ groupBars(h, W.match_queue, q.match), groupBars(h, W.timeline_queue, q.timeline) }),
        backlog,
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
        controls(ch, h, s),
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

pub const Demo = struct {
    pub fn charts(tab: ap.Tab) Charts {
        const d = ap.Demo;
        return .{ .tab = tab, .snap = &d.snap, .live = &d.live, .now = d.now };
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const states = [_][]const u8{ "crawler: a day, all regions", "crawler: 3 hours live, europe and asia", "Riot API: a key problem, one chart tipped", "loading", "another tab: hidden" };
    for (states, 0..) |caption, i| {
        const ch = a.create(Charts) catch return;
        ch.* = switch (i) {
            0, 1 => Demo.charts(.crawler),
            2 => Demo.charts(.riot),
            3 => .{ .tab = .riot },
            else => .{},
        };
        switch (i) {
            1 => {
                ch.range = .hours;
                ch.regions = 0b0110;
            },
            2 => ch.times[@backingInt(Chart.requests)].tip = 20,
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
    \\  .c-adcharts table.bars th { width: 40%; }
    \\  .c-adcharts details.c-card > summary { cursor: pointer; font-weight: var(--w-b); }
    \\  .c-adcharts summary .sub { font-weight: var(--w-r); font-size: var(--fs-s); }
    \\}
    \\
;
