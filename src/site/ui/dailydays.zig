//! DailyDays: Daily Draft's head (title, badges) with the days strip and streak, the strip
//! its own island (ui-dailydays.wasm) so ui-daily.wasm stays the puzzle's. Each day
//! links its puzzle's page (daily/<n>.html); answers come from localStorage
//! meiolol.daily.v1 (dailypage.read), so the server renders none. Once the page's puzzle
//! is finished, how everyone did (/api/daily: the browser's answers sent once)
const std = @import("std");
const tree = @import("tree.zig");
const badge = @import("badge.zig");
const dd = @import("dailydata.zig");
const dp = @import("dailypage.zig");
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "DailyDays";
pub const scope = .{ ".c-dhead", ".c-days" };
pub const sel = "[data-island=days]";

/// Days on the strip: the newest up to the viewer's date
pub const shown = 14;

pub const Day = struct { n: u32, date: []const u8 };

pub const Data = struct {
    /// The page's puzzle
    n: u32,
    /// daily.html, which opens the newest puzzle up to the viewer's date (else a puzzle's
    /// own page)
    redirects: bool,
    /// "" from the site root, "../" from daily/
    root: []const u8,
    /// The server's date (UTC): the first render's, before the viewer's own
    utc: []const u8,
    /// Every puzzle with a page, oldest first
    days: []const Day,
    /// The played pick's place in the page's puzzle's options, and who won: the crowd line
    answer: u8,
    winner: dd.Side,
};

/// /api/daily's counts for the page's puzzle: players, those who got the pick, the winner
pub const Crowd = struct { players: u32, pick: u32, side: u32 };

pub const Page = struct {
    d: *const Data,
    /// The viewer's date, "2026-10-27"
    date: []const u8,
    /// localStorage's meiolol.daily.v1 ("" until read)
    saved: []const u8 = "",
    /// The server's render: Data as ui.data, base64, for the island
    bin: []const u8 = "",
    crowd: ?Crowd = null,

    pub const Msg = union(enum) { none };

    pub fn init(_: std.mem.Allocator, d: *const Data) Page {
        return .{ .d = d, .date = d.utc };
    }

    pub fn update(_: *Page, _: Msg, _: *tree.Event) void {}

    /// The days out by the viewer's date
    fn live(s: *const Page) []const Day {
        return s.d.days[0..out(s.d.days, s.date)];
    }

    pub fn streak(s: *const Page) Streak {
        var on_time: [512]bool = undefined;
        const days = s.live();
        const from = days.len -| on_time.len;
        for (days[from..], 0..) |x, i| on_time[i] = if (dp.finishedOn(s.saved, x.n)) |on|
            std.mem.eql(u8, on, x.date)
        else if (dp.read(s.saved, x.n)) |m|
            // Finished before `on` was saved: taken as on time, not a lost streak
            m.marks != null
        else
            false;
        return streakOf(on_time[0 .. days.len - from]);
    }

    pub fn view(s: *Page, h: *H) N {
        const days = s.live();
        const from = days.len -| shown;
        const links = h.mem.alloc(N, days.len - from) catch {
            h.oom = true;
            return .none;
        };
        for (days[from..], links) |x, *l| {
            const m = dp.read(s.saved, x.n);
            const right: ?u8 = if (m) |v| if (v.marks) |k| @as(u8, @intFromBool(k[0])) + @intFromBool(k[1]) else null else null;
            const what = if (right) |r| W.right[r] else if (m != null) W.started else W.not_played;
            const label = W.day.with(h, .{ .n = x.n, .d = shortDate(h, x.date), .r = what.s });
            l.* = h.a(.{
                .href = h.fmt("{s}daily/{d}.html", .{ s.d.root, x.n }),
                .data_r = if (right) |r| "012"[r .. r + 1] else null,
                .aria_current = if (x.n == s.d.n) "page" else if (std.mem.eql(u8, x.date, s.date)) "date" else null,
                .aria_label = label,
                .title = label,
            }, .{});
        }
        const st = s.streak();
        const done = if (dp.read(s.saved, s.d.n)) |m| m.marks != null else false;
        const crowd = if (s.crowd) |c| if (done and c.players > 0) c else null else null;
        return h.span(.{ .class = "c-days", .data_island = "days", .data_bin = if (s.bin.len > 0) s.bin else null }, .{
            h.el(.nav, .{ .class = "strip", .aria_label = W.past }, .{links}),
            h.span(.{ .class = "streak", .role = "img", .title = W.streak_tip, .aria_label = W.streak_read.with(h, .{ .n = st.run, .b = st.best }) }, .{
                phrase.num(h, .int, st.run),
                h.el(.small, .{ .aria_hidden = "true" }, .{W.streak}),
            }),
            if (crowd) |c| h.span(.{ .class = "crowd" }, .{W.crowd.with(h, .{
                .n = c.players,
                .p = share(c.pick, c.players),
                .s = share(c.side, c.players),
            })}) else null,
        });
    }
};

/// The page head: title, badges and the days island (Page.view)
pub fn head(h: *H, p: *const dd.Puzzle, days: N) N {
    return h.div(.{ .class = "c-dhead" }, .{
        h.el(.h1, .{}, .{ W.title, " ", h.span(.{ .class = "n" }, .{W.number.with(h, .{ .n = p.n })}) }),
        if (p.turns.len > 0) badge.view(h, .neutral, .{W.pro}) else null,
        badge.view(h, .neutral, .{p.patch}),
        days,
    });
}

/// How many of `days` (oldest first) are out by `date`
fn out(days: []const Day, date: []const u8) usize {
    var end = days.len;
    while (end > 0 and std.mem.order(u8, days[end - 1].date, date) == .gt) end -= 1;
    return end;
}

fn share(k: u32, n: u32) u32 {
    return @intFromFloat(@round(100 * @as(f32, @floatFromInt(k)) / @as(f32, @floatFromInt(n))));
}

/// /api/daily for puzzle `n` once finished in `saved`, with its answers when `send`
/// (POST: counted), else without (GET); null until finished
pub fn crowdPath(buf: []u8, saved: []const u8, n: u32, send: bool) ?[]const u8 {
    const m = dp.read(saved, n) orelse return null;
    if (m.marks == null) return null;
    if (!send) return std.fmt.bufPrint(buf, "/api/daily?n={d}", .{n}) catch null;
    const side = m.side orelse return null;
    return std.fmt.bufPrint(buf, "/api/daily?n={d}&pick={d}&side={d}", .{ n, m.opt orelse return null, @backingInt(side) }) catch null;
}

/// /api/daily's reply ({n, players, picks, sides}) for `d`'s puzzle; null when it does not
/// read or is another's
pub fn crowdOf(a: std.mem.Allocator, json: []const u8, d: *const Data) ?Crowd {
    const R = struct { n: u32, players: u32, picks: []const u32, sides: [2]u32 };
    const r = std.json.parseFromSlice(R, a, json, .{ .ignore_unknown_fields = true }) catch return null;
    defer r.deinit();
    const v = r.value;
    if (v.n != d.n or d.answer >= v.picks.len) return null;
    return .{ .players = v.players, .pick = v.picks[d.answer], .side = v.sides[@backingInt(d.winner)] };
}

/// Whether `list` (localStorage meiolol.daily.sent.v1: "15,17") holds n
pub fn sent(list: []const u8, n: u32) bool {
    var it = std.mem.splitScalar(u8, list, ',');
    var buf: [10]u8 = undefined;
    const k = std.fmt.bufPrint(&buf, "{d}", .{n}) catch return false;
    while (it.next()) |x| if (std.mem.eql(u8, x, k)) return true;
    return false;
}

/// ?n= of a location.search ("?n=5&x"): an old link to a puzzle
pub fn wantedOf(search: []const u8) ?u32 {
    var it = std.mem.splitScalar(u8, if (std.mem.startsWith(u8, search, "?")) search[1..] else search, '&');
    while (it.next()) |kv| if (std.mem.startsWith(u8, kv, "n=")) return std.fmt.parseInt(u32, kv[2..], 10) catch null;
    return null;
}

/// The puzzle daily.html shows on the viewer's `date`: `wanted` (?n=, an old link) when it
/// is out by then, else the newest out; null when none is
pub fn target(days: []const Day, date: []const u8, wanted: ?u32) ?u32 {
    const live = days[0..out(days, date)];
    if (live.len == 0) return null;
    if (wanted) |w| for (live) |x| if (x.n == w) return w;
    return live[live.len - 1].n;
}

pub const Streak = struct { run: u32, best: u32 };

/// Days in a row from each puzzle (oldest first) finished on its own day or not: one miss
/// between finished ones is forgiven (not counted), two in a row end the run (forgiving
/// breaks bring players back: research/sources/duolingo-streaks.md ^f4). The newest
/// unfinished is pending, not missed
pub fn streakOf(on_time: []const bool) Streak {
    const days = if (on_time.len > 0 and !on_time[on_time.len - 1]) on_time[0 .. on_time.len - 1] else on_time;
    var s: Streak = .{ .run = 0, .best = 0 };
    var missed: u8 = 0;
    for (days) |ok| {
        if (ok) {
            s.run += 1;
            missed = 0;
            s.best = @max(s.best, s.run);
        } else {
            missed +|= 1;
            if (missed >= 2) s.run = 0;
        }
    }
    return s;
}

/// "27 Oct" for "2026-10-27"
fn shortDate(h: *H, date: []const u8) []const u8 {
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    if (date.len != 10) return date;
    const m = std.fmt.parseInt(u8, date[5..7], 10) catch 0;
    const d = std.fmt.parseInt(u8, date[8..10], 10) catch 0;
    if (m < 1 or m > 12 or d < 1) return date;
    return h.fmt("{d} {s}", .{ d, months[m - 1] });
}

const W = struct {
    const title = plain("Daily Draft");
    const number = Phrase("#{n:int}");
    const pro = plain("Pro game");
    const past = plain("Past puzzles");
    const day = Phrase("#{n:int}, {d:text}: {r:text}");
    const right = [3]tree.Text{ plain("none right"), plain("one of two right"), plain("both right") };
    const started = plain("started");
    const not_played = plain("not played");
    const streak = plain("streak");
    const streak_read = Phrase("Streak {n:int}, best {b:int}");
    const crowd = Phrase("{n:count} played: {p:pct} got the pick, {s:pct} the winner");
    const streak_tip = plain("Puzzles finished on their own day. One missed day is forgiven; two in a row end it.");
};

pub const css =
    \\@layer components {
    \\  .c-dhead { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2); }
    \\  .c-dhead h1 { margin: 0 var(--sp-1) 0 0; font-size: var(--fs-l); }
    \\  .c-dhead .n { color: var(--muted); font-weight: var(--w-m); }
    \\  .c-days { display: flex; flex-wrap: wrap; justify-content: flex-end; align-items: center; column-gap: var(--sp-3); row-gap: var(--sp-1); margin-left: auto; }
    \\  .c-days .strip { display: flex; gap: 3px; }
    \\  .c-days .strip a { width: 18px; height: 18px; border-radius: 4px; background: var(--panel-3); }
    \\  .c-days .strip a[data-r="2"] { background: var(--hi2); }
    \\  .c-days .strip a[data-r="1"] { background: var(--hi1); opacity: 0.7; }
    \\  .c-days .strip a[data-r="0"] { background: var(--lo1); opacity: 0.6; }
    \\  .c-days .strip a[aria-current="date"] { box-shadow: 0 0 0 2px var(--bg), 0 0 0 3.5px var(--text); }
    \\  .c-days .strip a[aria-current="page"] { outline: 1.5px dashed var(--text); outline-offset: 2px; }
    \\  .c-days .streak { font-size: var(--fs-l); font-weight: var(--w-b); font-variant-numeric: tabular-nums; }
    \\  .c-days .crowd { flex-basis: 100%; text-align: right; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-days .streak small { margin-left: 3px; font-size: var(--fs-s); font-weight: var(--w-r); color: var(--faint); }
    \\  @media (max-width: 760px) {
    \\    .c-days { margin-left: 0; width: 100%; justify-content: flex-start; }
    \\    .c-days .crowd { text-align: left; }
    \\    .c-days .strip a { width: 15px; height: 15px; }
    \\  }
    \\}
    \\
;

const demo_days = [_]Day{
    .{ .n = 4, .date = "2026-10-14" },  .{ .n = 5, .date = "2026-10-15" },  .{ .n = 6, .date = "2026-10-16" },
    .{ .n = 7, .date = "2026-10-17" },  .{ .n = 8, .date = "2026-10-18" },  .{ .n = 9, .date = "2026-10-19" },
    .{ .n = 10, .date = "2026-10-20" }, .{ .n = 11, .date = "2026-10-21" }, .{ .n = 12, .date = "2026-10-22" },
    .{ .n = 13, .date = "2026-10-23" }, .{ .n = 14, .date = "2026-10-24" }, .{ .n = 15, .date = "2026-10-25" },
    .{ .n = 16, .date = "2026-10-26" }, .{ .n = 17, .date = "2026-10-27" }, .{ .n = 18, .date = "2026-10-28" },
};

const demo: Data = .{ .n = 17, .redirects = true, .root = "", .utc = "2026-10-27", .days = &demo_days, .answer = 2, .winner = .red };
const demo_archive: Data = .{ .n = 12, .redirects = false, .root = "../", .utc = "2026-10-27", .days = &demo_days, .answer = 0, .winner = .blue };

/// Finished on their days but #11 (late) and #15 (missed): the streak forgives #15, and
/// #11 and #12 both late would have ended it
const demo_saved =
    \\{"8":{"opt":0,"side":0,"marks":"11","on":"2026-10-18"},"9":{"opt":1,"side":1,"marks":"10","on":"2026-10-19"},
    \\"10":{"opt":2,"side":0,"marks":"00","on":"2026-10-20"},"11":{"opt":0,"side":1,"marks":"01","on":"2026-10-22"},
    \\"12":{"opt":3,"side":0,"marks":"11","on":"2026-10-22"},"13":{"opt":0,"side":0,"marks":"10","on":"2026-10-23"},
    \\"14":{"opt":1,"side":1,"marks":"11","on":"2026-10-24"},"16":{"opt":5,"side":1,"marks":"01","on":"2026-10-26"},
    \\"17":{"opt":2}}
;

fn demoPage(h: *H, d: *const Data, saved: []const u8) ?*Page {
    const p = h.mem.create(Page) catch return null;
    p.* = .init(h.mem, d);
    p.saved = saved;
    return p;
}

pub fn gallery(g: *@import("gallery.zig").Gallery) void {
    const h = g.h;
    if (demoPage(h, &demo, "")) |p| g.add("first visit: today ringed, nothing played", head(h, &dd.sample, p.view(h)));
    if (demoPage(h, &demo, demo_saved)) |p| g.add("both, one and none right; #15 missed and forgiven; today started", head(h, &dd.sample, p.view(h)));
    if (demoPage(h, &demo_archive, demo_saved)) |p| {
        p.crowd = .{ .players = 1234, .pick = 512, .side = 802 };
        g.add("an archive puzzle's page (#12, dashed), finished: how everyone did", head(h, &dd.sample, p.view(h)));
    }
}

const testing = std.testing;

test "streak: one miss forgiven, two end it; the newest unfinished is pending" {
    const t = true;
    const f = false;
    try testing.expectEqual(Streak{ .run = 3, .best = 3 }, streakOf(&.{ t, t, t }));
    try testing.expectEqual(Streak{ .run = 3, .best = 3 }, streakOf(&.{ t, t, t, f }));
    try testing.expectEqual(Streak{ .run = 4, .best = 4 }, streakOf(&.{ t, t, f, t, t }));
    try testing.expectEqual(Streak{ .run = 1, .best = 2 }, streakOf(&.{ t, t, f, f, t }));
    try testing.expectEqual(Streak{ .run = 0, .best = 1 }, streakOf(&.{ t, f, f, f }));
    try testing.expectEqual(Streak{ .run = 0, .best = 0 }, streakOf(&.{}));
}

test "target: ?n= when out by the viewer's date, else the newest out" {
    try testing.expectEqual(@as(?u32, 17), target(&demo_days, "2026-10-27", null));
    try testing.expectEqual(@as(?u32, 18), target(&demo_days, "2026-10-28", null));
    try testing.expectEqual(@as(?u32, 16), target(&demo_days, "2026-10-26", null));
    try testing.expectEqual(@as(?u32, 9), target(&demo_days, "2026-10-27", 9));
    // Published early, not playable early
    try testing.expectEqual(@as(?u32, 17), target(&demo_days, "2026-10-27", 18));
    try testing.expectEqual(@as(?u32, null), target(&demo_days, "2026-10-01", null));
}

test "the strip: last 14 out, marks as data-r, today ringed, the page's own dashed" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var p: Page = .init(arena.allocator(), &demo);
    p.saved = demo_saved;
    const v = p.view(&h);
    try testing.expect(!h.oom);
    const strip = t.find(v, "class", "strip").?;
    const days = t.kidsOf(strip);
    // #18 is out tomorrow
    try testing.expectEqual(14, days.len);
    try testing.expectEqualStrings("daily/4.html", t.attr(days[0], "href").?);
    try testing.expectEqualStrings("2", t.attr(days[4], "data-r").?);
    try testing.expectEqualStrings("#8, 18 Oct: both right", t.attr(days[4], "aria-label").?);
    try testing.expectEqual(null, t.attr(days[11], "data-r"));
    try testing.expectEqualStrings("#15, 25 Oct: not played", t.attr(days[11], "aria-label").?);
    try testing.expectEqualStrings("page", t.attr(days[13], "aria-current").?);
    try testing.expectEqualStrings("#17, 27 Oct: started", t.attr(days[13], "aria-label").?);
    // 8, 9, 10 on time; 11 late (one miss, forgiven), 12-14 on time; 15 missed (forgiven); 16 on
    // time; 17 pending
    try testing.expectEqual(Streak{ .run = 7, .best = 7 }, p.streak());
    try testing.expectEqualStrings("Streak 7, best 7", t.attr(t.find(v, "class", "streak").?, "aria-label").?);

    // The viewer a day ahead: #18 out and today's, the page's own (#17) still marked
    p.date = "2026-10-28";
    const ahead = p.view(&h);
    const kids = t.kidsOf(t.find(ahead, "class", "strip").?);
    try testing.expectEqualStrings("daily/5.html", t.attr(kids[0], "href").?);
    try testing.expectEqualStrings("date", t.attr(kids[13], "aria-current").?);
    try testing.expectEqualStrings("page", t.attr(kids[12], "aria-current").?);
}

test "an archive page links from daily/" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var p: Page = .init(arena.allocator(), &demo_archive);
    const v = p.view(&h);
    const days = t.kidsOf(t.find(v, "class", "strip").?);
    try testing.expectEqualStrings("../daily/4.html", t.attr(days[0], "href").?);
    try testing.expectEqualStrings("page", t.attr(days[8], "aria-current").?);
    try testing.expectEqualStrings("date", t.attr(days[13], "aria-current").?);
}

test "wantedOf: n= as its own key only" {
    try testing.expectEqual(@as(?u32, 5), wantedOf("?n=5"));
    try testing.expectEqual(@as(?u32, 5), wantedOf("?n=5&x=1"));
    try testing.expectEqual(@as(?u32, 5), wantedOf("?x=1&n=5"));
    for ([_][]const u8{ "", "?", "?n=", "?n=-1", "?n=99999999999", "?column=3", "?fn=9", "?n=5x" }) |q| {
        try testing.expectEqual(null, wantedOf(q));
    }
}

test "days out and today's target across a year end and February" {
    const year = [_]Day{
        .{ .n = 1, .date = "2026-12-30" }, .{ .n = 2, .date = "2026-12-31" },
        .{ .n = 3, .date = "2027-01-01" }, .{ .n = 4, .date = "2027-01-02" },
    };
    try testing.expectEqual(2, out(&year, "2026-12-31"));
    try testing.expectEqual(@as(?u32, 3), target(&year, "2027-01-01", null));
    try testing.expectEqual(@as(?u32, 2), target(&year, "2027-01-01", 2));
    const feb = [_]Day{
        .{ .n = 1, .date = "2027-02-27" }, .{ .n = 2, .date = "2027-02-28" },
        .{ .n = 3, .date = "2027-03-01" },
    };
    try testing.expectEqual(2, out(&feb, "2027-02-28"));
    try testing.expectEqual(@as(?u32, 3), target(&feb, "2027-03-01", null));
}

test "streak: nothing or junk saved is no run; entries from before `on` count on time" {
    var p: Page = .init(testing.allocator, &demo);
    try testing.expectEqual(Streak{ .run = 0, .best = 0 }, p.streak());
    p.saved = "{not json";
    try testing.expectEqual(Streak{ .run = 0, .best = 0 }, p.streak());
    // 14 and 15 finished before `on`, 16 on its day, 17 (today) a hint only
    p.saved =
        \\{"14":{"opt":1,"marks":"11"},"15":{"opt":0,"side":1,"marks":"01"},
        \\"16":{"opt":5,"side":1,"marks":"01","on":"2026-10-26"},"17":{"hint":1}}
    ;
    try testing.expectEqual(Streak{ .run = 3, .best = 3 }, p.streak());
    // Finished late: misses
    p.saved =
        \\{"14":{"marks":"11","on":"2026-10-25"},"15":{"marks":"01","on":"2026-10-27"},
        \\"16":{"marks":"01","on":"2026-10-27"}}
    ;
    try testing.expectEqual(Streak{ .run = 0, .best = 0 }, p.streak());
}

test "streak: more days than it counts keeps the newest 512" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const many = try a.alloc(Day, 600);
    var saved: std.Io.Writer.Allocating = .init(a);
    try saved.writer.writeByte('{');
    for (many, 0..) |*d, i| {
        const date = try a.print("{d}-01-01", .{1000 + i});
        d.* = .{ .n = @intCast(i + 1), .date = date };
        try saved.writer.print("{s}\"{d}\":{{\"marks\":\"11\",\"on\":\"{s}\"}}", .{ if (i > 0) "," else "", i + 1, date });
    }
    try saved.writer.writeByte('}');
    const d: Data = .{ .n = 600, .redirects = true, .root = "", .utc = many[599].date, .days = many, .answer = 0, .winner = .blue };
    var p: Page = .init(a, &d);
    p.saved = saved.written();
    try testing.expectEqual(Streak{ .run = 512, .best = 512 }, p.streak());
}

test "out of memory in the strip sets oom" {
    var buf: [256]u8 = undefined;
    for ([_]usize{ 0, buf.len }) |size| {
        var fba: std.heap.FixedBufferAllocator = .init(buf[0..size]);
        var p: Page = .init(fba.allocator(), &demo);
        p.saved = demo_saved;
        var t: tree.Tree = .{};
        var h: H = .init(fba.allocator(), &t);
        _ = p.view(&h);
        try testing.expect(h.oom);
    }
}

test "the crowd: sent once finished, read back for the page's puzzle only" {
    var buf: [96]u8 = undefined;
    const saved =
        \\{"12":{"opt":3,"side":1,"marks":"01","on":"2026-10-22"},"17":{"opt":2}}
    ;
    try testing.expectEqualStrings("/api/daily?n=12&pick=3&side=1", crowdPath(&buf, saved, 12, true).?);
    try testing.expectEqualStrings("/api/daily?n=12", crowdPath(&buf, saved, 12, false).?);
    try testing.expectEqual(null, crowdPath(&buf, saved, 17, false));
    try testing.expectEqual(null, crowdPath(&buf, saved, 9, true));
    // Marks without the answers behind them: nothing to count
    try testing.expectEqual(null, crowdPath(&buf, "{\"12\":{\"marks\":\"01\"}}", 12, true));

    const a = testing.allocator;
    const reply = "{\"n\":12,\"players\":40,\"picks\":[10,0,5,25,0,0],\"sides\":[30,10]}";
    try testing.expectEqual(Crowd{ .players = 40, .pick = 10, .side = 30 }, crowdOf(a, reply, &demo_archive).?);
    try testing.expectEqual(null, crowdOf(a, reply, &demo));
    try testing.expectEqual(null, crowdOf(a, "{\"n\":12,\"players\":40,\"picks\":[],\"sides\":[30,10]}", &demo_archive));
    try testing.expectEqual(null, crowdOf(a, "<html>", &demo_archive));

    try testing.expect(sent("15,12", 12));
    try testing.expect(!sent("15,120", 12));
    try testing.expect(!sent("", 12));
}

test "the crowd line: only once the page's puzzle is finished and someone played" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var p: Page = .init(arena.allocator(), &demo_archive);
    p.crowd = .{ .players = 1234, .pick = 512, .side = 802 };
    try testing.expectEqual(null, t.find(p.view(&h), "class", "crowd"));
    p.saved = demo_saved;
    const line = t.find(p.view(&h), "class", "crowd").?;
    var text: std.Io.Writer.Allocating = .init(arena.allocator());
    try t.textOf(line, &text.writer);
    try testing.expectEqualStrings("1,234 played: 41% got the pick, 65% the winner", text.written());
    p.crowd = .{ .players = 0, .pick = 0, .side = 0 };
    try testing.expectEqual(null, t.find(p.view(&h), "class", "crowd"));
}
