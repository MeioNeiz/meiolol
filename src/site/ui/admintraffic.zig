//! AdminTraffic: the admin page's Traffic tab, an island of its own below AdminCharts
//! (ui-admintraffic.wasm, which fetches api/traffic.bin only once the tab shows). The
//! site's nginx log as deploy/traffic.sh counts it: views by people, unconfirmed and bots,
//! server errors, page time, top pages, referrers, agents, status codes, render cache and
//! not found. A day or more draws a bar per UK day, else per hour
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const card = @import("card.zig");
const Gallery = @import("gallery.zig").Gallery;
const strip = @import("strip.zig");
const segmented = @import("segmented.zig");
const timechart = @import("timechart.zig");
const ad = @import("admindata.zig");
const ap = @import("adminpage.zig");
const ac = @import("admincharts.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Text = tree.Text;

pub const name = "AdminTraffic";
pub const scope = .{".c-adtraffic"};
pub const sel = "[data-island=admintraffic]";

pub const Span = enum { day, week, month };

pub const Traffic = struct {
    tab: ap.Tab = .overview,
    /// AdminCharts', kept so this island's URL writes keep it
    range: ac.Range = .day,
    span: Span = .week,
    /// Top pages: the last 24 h, else 7 days
    pages_day: bool = false,
    times: [2]timechart.Time = @splat(.{ .label = .{ .s = "" }, .start = 0, .series = &.{} }),
    data: ?*const ad.Traffic = null,
    failed: bool = false,
    now: i64 = 0,
    /// This island's code, on its root for dom.lazyLoad
    js: []const u8 = "",
    wasm: []const u8 = "",

    pub const Url = ap.Page.Url;
    pub const Msg = union(enum) { span: Span, pages_day: bool };

    pub fn toUrl(t: *const Traffic) Url {
        return .{ .tab = t.tab, .range = t.range };
    }

    pub fn fromUrl(t: *Traffic, u: Url) void {
        t.tab = u.tab;
        t.range = u.range;
    }

    pub fn update(t: *Traffic, m: Msg, ev: *tree.Event) void {
        _ = ev;
        switch (m) {
            .span => |s| {
                t.span = s;
                for (&t.times) |*x| {
                    x.zoom = null;
                    x.tip = null;
                }
            },
            .pages_day => |d| t.pages_day = d,
        }
    }

    pub fn shows(t: *const Traffic) bool {
        return t.tab == .traffic;
    }

    pub fn view(t: *Traffic, h: *H) N {
        const on = t.shows();
        return h.div(.{ .class = "c-adtraffic", .data_island = "admintraffic", .data_js = t.js, .data_wasm = t.wasm, .hidden = !on }, .{
            if (!on) null else if (t.data) |d| traffic(t, h, d) else h.p(.{ .class = "lead", .role = "status" }, .{if (t.failed) W.failed else ap.W.loading}),
        });
    }
};

const W = struct {
    pub const title = plain("Site traffic");
    pub const sub = Phrase("From the site's nginx log, no IP addresses; updated {t:text}. People: a browser user agent that also fetched the stylesheet. Unconfirmed: a browser user agent with no stylesheet fetch, mostly bots. Bots: named by their user agent.");
    pub const failed = plain("Traffic (api/traffic.bin) didn't load: Refresh to try again");
    pub const range = plain("Range");
    pub const day = plain("24 hours");
    pub const week = plain("7 days");
    pub const month = plain("30 days");

    pub const views_day = plain("Views, 24 h");
    pub const by_people = plain("pages by people");
    pub const views = Phrase("Views, {s:text}");
    pub const others = Phrase("{u:count} unconfirmed, {b:count} by bots");
    pub const errors_day = plain("Server errors, 24 h");
    pub const answers_5xx = plain("5xx answers");
    pub const p95 = plain("Page time, p95");
    pub const ms = Phrase("{n:count} ms");
    pub const p50_99 = Phrase("p50 {a:text}, p99 {b:text} (bucket bounds)");
    pub const sent = plain("Sent, 24 h");
    pub const assets = Phrase("{n:count} asset requests");

    pub const views_hour = plain("Page views per hour");
    pub const views_daily = plain("Page views per day");
    pub const errors_hour = plain("Server errors per hour");
    pub const errors_daily = plain("Server errors per day");
    pub const people = plain("people");
    pub const unconfirmed = plain("unconfirmed");
    pub const bots = plain("bots");
    pub const s5xx = plain("5xx");

    pub const top_pages = plain("Top pages");
    pub const pages_window = plain("Pages window");
    pub const h24 = plain("24 h");
    pub const referrers = plain("Referrers, 7 days");
    pub const agents = plain("Browsers and bots, 7 days");
    pub const status = plain("Status codes, 24 h");
    pub const render_cache = plain("Render cache, 24 h");
    pub const render_sub = plain("Pages the static build leaves out come from the box (MISS) or nginx's cache (HIT, STALE).");
    pub const static = plain("static");
    pub const not_found = plain("Not found, 24 h");
    pub const c_page = plain("Page");
    pub const c_views = plain("Views");
    pub const c_domain = plain("Domain");
    pub const c_agent = plain("Agent");
    pub const c_code = plain("Code");
    pub const c_cache = plain("Cache");
    pub const c_requests = plain("Requests");
    pub const c_path = plain("Path");
    pub const c_hits = plain("Hits");
    pub const no_rows = plain("Empty");
};

const span_s = std.EnumArray(Span, i64).init(.{ .day = 86400, .week = 7 * 86400, .month = 30 * 86400 });
const span_names = std.EnumArray(Span, Text).init(.{ .day = W.day, .week = W.week, .month = W.month });

/// Hour rows from `since` on
fn since(d: *const ad.Traffic, s: i64) []const ad.Hour {
    for (d.hours, 0..) |r, i| if (r.time >= s) return d.hours[i..];
    return &.{};
}

const Sums = struct { people: u64 = 0, bots: u64 = 0, unconfirmed: u64 = 0, errors: u64 = 0, assets: u64 = 0, bytes: u64 = 0 };

fn sum(hs: []const ad.Hour) Sums {
    var s: Sums = .{};
    for (hs) |r| {
        s.people += r.people;
        s.bots += r.bots;
        s.unconfirmed += r.unconfirmed;
        s.errors += r.errors;
        s.assets += r.assets;
        s.bytes += r.bytes;
    }
    return s;
}

/// Days since the epoch on the UK clock
fn ukDay(t: i64) i64 {
    return @divFloor(t + timechart.ukOffset(t), 86400);
}

/// The chart buckets: per hour for a day (traffic.sh's 24 hours to the current one), else
/// per UK day, the newest the one `generated` is in
pub const Buckets = struct {
    start: i64,
    step: u32,
    people: []?f32,
    unconfirmed: []?f32,
    bots: []?f32,
    errors: []?f32,

    pub fn of(a: std.mem.Allocator, d: *const ad.Traffic, span: Span) !Buckets {
        const daily = span != .day;
        const n: usize = if (daily) @intCast(@divExact(span_s.get(span), 86400)) else 24;
        const last_day = ukDay(d.generated);
        const first_day = last_day - @as(i64, @intCast(n)) + 1;
        const start = if (daily) first_day * 86400 - timechart.ukOffset(first_day * 86400) else @divFloor(d.generated, 3600) * 3600 - 23 * 3600;
        var b: Buckets = .{ .start = start, .step = if (daily) 86400 else 3600, .people = try a.alloc(?f32, n), .unconfirmed = try a.alloc(?f32, n), .bots = try a.alloc(?f32, n), .errors = try a.alloc(?f32, n) };
        for ([_][]?f32{ b.people, b.unconfirmed, b.bots, b.errors }) |xs| @memset(xs, 0);
        for (since(d, start)) |r| {
            const i: usize = @intCast(if (daily) ukDay(r.time) - first_day else @divFloor(r.time - start, 3600));
            if (i >= n) continue;
            b.people[i].? += @floatFromInt(r.people);
            b.unconfirmed[i].? += @floatFromInt(r.unconfirmed);
            b.bots[i].? += @floatFromInt(r.bots);
            b.errors[i].? += @floatFromInt(r.errors);
        }
        return b;
    }
};

fn oom(h: *H) N {
    h.oom = true;
    return .none;
}

fn ms(h: *H, v: ?u32) Text {
    return if (v) |x| W.ms.with(h, .{ .n = x }) else .{ .s = "–" };
}

fn traffic(t: *Traffic, h: *H, d: *const ad.Traffic) N {
    const day = sum(since(d, d.generated - 86400));
    const all = sum(since(d, d.generated - span_s.get(t.span)));
    var tiles: std.ArrayList(strip.Item) = .empty;
    tiles.appendSlice(h.mem, &.{
        .{ .label = W.views_day, .value = phrase.num(h, .count, day.people), .ctx = W.by_people, .answer = true },
        .{ .label = W.views.with(h, .{ .s = span_names.get(t.span).s }), .value = phrase.num(h, .count, all.people), .ctx = W.others.with(h, .{ .u = all.unconfirmed, .b = all.bots }) },
        .{ .label = W.errors_day, .value = phrase.num(h, .count, day.errors), .ctx = W.answers_5xx, .step = if (day.errors > 0) ac.warn else null },
    }) catch return oom(h);
    if (d.latency_day) |l| tiles.append(h.mem, .{ .label = W.p95, .value = ms(h, l.p95), .ctx = W.p50_99.with(h, .{ .a = ms(h, l.p50).s, .b = ms(h, l.p99).s }) }) catch return oom(h);
    tiles.append(h.mem, .{ .label = W.sent, .value = ac.bytes(h, @floatFromInt(day.bytes)), .ctx = W.assets.with(h, .{ .n = day.assets }) }) catch return oom(h);

    const b = Buckets.of(h.mem, d, t.span) catch return oom(h);
    const daily = t.span != .day;
    const series = h.mem.dupe(timechart.Series, &.{
        .{ .name = W.people, .values = b.people, .colour = 0 },
        .{ .name = W.unconfirmed, .values = b.unconfirmed, .colour = 3 },
        .{ .name = W.bots, .values = b.bots, .colour = 5 },
    }) catch return oom(h);
    const errors = h.mem.dupe(timechart.Series, &.{.{ .name = W.s5xx, .values = b.errors, .colour = 1 }}) catch return oom(h);
    const common: timechart.Time = .{ .label = W.views_hour, .kind = .bars, .start = b.start, .step = b.step, .series = series };
    var views = common;
    views.label = if (daily) W.views_daily else W.views_hour;
    var errs = common;
    errs.label = if (daily) W.errors_daily else W.errors_hour;
    errs.series = errors;

    const spans = [_]segmented.Item{
        .{ .label = W.day, .selected = t.span == .day, .on = h.on(t, .{ .span = .day }) },
        .{ .label = W.week, .selected = t.span == .week, .on = h.on(t, .{ .span = .week }) },
        .{ .label = W.month, .selected = t.span == .month, .on = h.on(t, .{ .span = .month }) },
    };
    const windows = [_]segmented.Item{
        .{ .label = W.h24, .selected = t.pages_day, .on = h.on(t, .{ .pages_day = true }) },
        .{ .label = W.week, .selected = !t.pages_day, .on = h.on(t, .{ .pages_day = false }) },
    };
    const status = h.mem.dupe(ad.Group, d.status_day) catch return oom(h);
    const cache = h.mem.dupe(ad.Group, d.render_cache_day) catch return oom(h);
    for (cache) |*c| if (c.key.len == 0) {
        c.key = W.static.s;
    };

    return h.div(.{ .class = "tab" }, .{
        card.sechead(h, W.title, null, &.{segmented.view(h, .{ .s = .s, .label = W.range }, &spans)}),
        h.p(.{ .class = "lead" }, .{W.sub.with(h, .{ .t = ap.ago(h, t.now - d.generated).s })}),
        strip.view(h, tiles.items),
        h.div(.{ .class = "charts" }, .{
            chart(t, h, 0, views),
            chart(t, h, 1, errs),
        }),
        h.div(.{ .class = "cards" }, .{
            rows(h, W.top_pages, &.{segmented.view(h, .{ .s = .s, .label = W.pages_window }, &windows)}, if (t.pages_day) d.pages_day else d.pages_week, W.c_page, W.c_views),
            ac.groupBars(h, W.referrers, null, d.referrers_week, W.c_domain, W.c_views),
            ac.groupBars(h, W.agents, null, d.agents_week, W.c_agent, W.c_requests),
            ac.groupBars(h, W.status, null, status, W.c_code, W.c_requests),
            ac.groupBars(h, W.render_cache, W.render_sub, cache, W.c_cache, W.c_requests),
            rows(h, W.not_found, &.{}, d.not_found_day, W.c_path, W.c_hits),
        }),
    });
}

/// A chart in its card, its zoom and tip kept in the island
fn chart(t: *Traffic, h: *H, i: usize, o: timechart.Time) N {
    const x = &t.times[i];
    var c = o;
    c.zoom = x.zoom;
    c.tip = x.tip;
    c.drag = x.drag;
    c.press = x.press;
    x.* = c;
    return card.view(h, .{}, &.{ card.head(h, o.label, null, &.{}), x.view(h) });
}

/// Paths and their counts, most first
fn rows(h: *H, title: Text, controls: []const N, gs: []const ad.Group, key: Text, value: Text) N {
    var trs = h.list();
    for (gs) |g| trs.add(h.tr(.{}, .{
        h.td(.{ .class = "msg" }, .{g.key}),
        h.td(.{ .class = "num" }, .{phrase.num(h, .count, g.n)}),
    }));
    return card.view(h, .{}, &.{
        card.head(h, title, null, controls),
        if (gs.len == 0) h.p(.{ .class = "lead" }, .{W.no_rows}) else h.div(.{ .class = "tw" }, .{h.table(.{}, .{
            h.thead(.{}, .{h.tr(.{}, .{ h.th(.{}, .{key}), h.th(.{ .class = "num", .data_answer = true }, .{value}) })}),
            h.tbody(.{}, .{trs.done()}),
        })}),
    });
}

pub const Demo = struct {
    const now = ap.Demo.now;
    const start = @divFloor(now, 3600) * 3600 - 30 * 24 * 3600;
    const hours = blk: {
        @setEvalBranchQuota(20_000);
        var out: [30 * 24]ad.Hour = undefined;
        for (&out, 0..) |*r, i| {
            const hod = i % 24;
            // Busier in the UK evening, a slow climb over the month
            const base: u32 = @intCast(2 + i / 120 + (if (hod >= 17 and hod <= 22) 6 else if (hod >= 8) 3 else 0));
            r.* = .{ .time = start + @as(i64, @intCast(i)) * 3600, .people = base, .bots = 20 + @as(u32, @intCast(i % 7)) * 3, .assets = base * 12, .errors = if (i % 97 == 0) 2 else 0, .bytes = @as(u64, base) * 400_000 + 900_000, .unconfirmed = 1 + @as(u32, @intCast(i % 5)) };
        }
        break :blk out;
    };
    pub const data: ad.Traffic = .{
        .generated = now - 240,
        .hours = &hours,
        .pages_day = &.{ .{ .key = "/", .n = 41 }, .{ .key = "/your", .n = 17 }, .{ .key = "/champions/karthus", .n = 6 }, .{ .key = "/daily", .n = 4 } },
        .pages_week = &.{ .{ .key = "/", .n = 213 }, .{ .key = "/your", .n = 96 }, .{ .key = "/daily", .n = 30 }, .{ .key = "/matchups/mid/ahri-vs-zed", .n = 12 }, .{ .key = "/champions/karthus", .n = 9 } },
        .referrers_week = &.{ .{ .key = "reddit.com", .n = 41 }, .{ .key = "google.com", .n = 22 }, .{ .key = "discord.com", .n = 5 } },
        .agents_week = &.{ .{ .key = "Chrome", .n = 50320 }, .{ .key = "Edge", .n = 16297 }, .{ .key = "Googlebot", .n = 4120 }, .{ .key = "Safari", .n = 378 }, .{ .key = "Firefox", .n = 284 }, .{ .key = "other bot", .n = 96 } },
        .status_day = &.{ .{ .key = "200", .n = 47029 }, .{ .key = "301", .n = 829 }, .{ .key = "302", .n = 12173 }, .{ .key = "304", .n = 22 }, .{ .key = "404", .n = 161 }, .{ .key = "503", .n = 1 } },
        .not_found_day = &.{ .{ .key = "/wp-admin/install.php", .n = 75 }, .{ .key = "/wp-login.php", .n = 6 }, .{ .key = "/matchups/bot/neeko-vs-yunara-and-a-path-long-enough-to-wrap-at-phone-width", .n = 2 } },
        .render_cache_day = &.{ .{ .key = "MISS", .n = 45539 }, .{ .key = "STALE", .n = 1018 }, .{ .key = "HIT", .n = 400 }, .{ .key = "", .n = 210 } },
        .latency_day = .{ .p50 = 25, .p95 = 50, .p99 = 250 },
    };

    pub fn island() Traffic {
        return .{ .tab = .traffic, .data = &data, .now = now };
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const states = [_][]const u8{ "7 days, one chart tipped", "24 hours, top pages of the day", "30 days", "loading", "failed", "no traffic yet", "another tab: hidden" };
    const empty: ad.Traffic = .{ .generated = Demo.now - 60, .hours = &.{}, .pages_day = &.{}, .pages_week = &.{}, .referrers_week = &.{}, .agents_week = &.{}, .status_day = &.{}, .not_found_day = &.{}, .render_cache_day = &.{}, .latency_day = null };
    for (states, 0..) |caption, i| {
        const t = a.create(Traffic) catch return;
        t.* = switch (i) {
            0, 1, 2 => Demo.island(),
            3 => .{ .tab = .traffic },
            4 => .{ .tab = .traffic, .failed = true },
            5 => .{ .tab = .traffic, .data = &empty, .now = Demo.now },
            else => .{},
        };
        switch (i) {
            0 => t.times[0].tip = 5,
            1 => {
                t.span = .day;
                t.pages_day = true;
            },
            2 => t.span = .month,
            else => {},
        }
        g.addFill(caption, t.view(g.h));
    }
}

pub const css =
    \\@layer components {
    \\  .c-adtraffic { display: grid; gap: var(--sp-3); }
    \\  .c-adtraffic .tab { display: grid; gap: var(--sp-3); }
    \\  .c-adtraffic .lead { margin: 0 0 var(--sp-2); color: var(--muted); font-size: var(--fs-s); }
    \\  .c-adtraffic .charts, .c-adtraffic .cards { display: grid; gap: var(--sp-3);
    \\    grid-template-columns: repeat(auto-fit, minmax(min(100%, 26rem), 1fr)); }
    \\  .c-adtraffic .tw { overflow-x: auto; }
    \\  .c-adtraffic table { width: 100%; border-collapse: collapse; font-size: var(--fs-s); }
    \\  .c-adtraffic :is(th, td) { padding: var(--sp-1) var(--sp-2); border-bottom: 1px solid var(--line);
    \\    text-align: start; vertical-align: top; }
    \\  .c-adtraffic thead th { color: var(--muted); font-weight: var(--w-m); }
    \\  .c-adtraffic tbody th { font-size: inherit; font-weight: var(--w-r); color: var(--text);
    \\    text-transform: none; letter-spacing: normal; }
    \\  .c-adtraffic :is(td, th).num { text-align: end; font-variant-numeric: tabular-nums; }
    \\  .c-adtraffic .msg { overflow-wrap: anywhere; white-space: normal; }
    \\  .c-adtraffic table.bars th { width: 40%; overflow-wrap: anywhere; }
    \\}
    \\
;

const testing = std.testing;

test "admin traffic: hourly buckets to the current hour, daily by UK day" {
    var a_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer a_state.deinit();
    const a = a_state.allocator();
    // 29 Oct 2026, GMT; 21 Oct 23:30 UTC was BST, so the UK's 22 Oct
    const gen: i64 = 1_793_269_200;
    const mid = @divFloor(gen, 86400) * 86400;
    const hours = [_]ad.Hour{
        .{ .time = mid - 7 * 86400 - 1800, .people = 1, .bots = 0, .assets = 0, .errors = 0, .bytes = 0, .unconfirmed = 0 },
        .{ .time = mid - 7 * 86400 + 1800, .people = 2, .bots = 0, .assets = 0, .errors = 0, .bytes = 0, .unconfirmed = 0 },
        .{ .time = @divFloor(gen, 3600) * 3600, .people = 4, .bots = 1, .assets = 0, .errors = 1, .bytes = 0, .unconfirmed = 2 },
    };
    var d = Demo.data;
    d.generated = gen;
    d.hours = &hours;
    const h = try Buckets.of(a, &d, .day);
    try testing.expectEqual(24, h.people.len);
    try testing.expectEqual(4, h.people[23].?);
    try testing.expectEqual(0, h.people[0].?);
    const w = try Buckets.of(a, &d, .week);
    // 23 Oct 00:00 BST
    try testing.expectEqual(mid - 6 * 86400 - 3600, w.start);
    try testing.expectEqual(4, w.people[6].?);
    try testing.expectEqual(1, w.errors[6].?);
    const m = try Buckets.of(a, &d, .month);
    try testing.expectEqual(30, m.people.len);
    // 30 Sep 00:00 BST
    try testing.expectEqual(mid - 29 * 86400 - 3600, m.start);
    try testing.expectEqual(3, m.people[22].?);
}
