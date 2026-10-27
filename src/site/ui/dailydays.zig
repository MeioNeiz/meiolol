//! DailyDays: Daily Draft's head (title, badges) with the days strip and streak, the strip
//! its own island (ui-dailydays.wasm) so ui-daily.wasm stays the puzzle's. Each day
//! links its puzzle's page (daily/<n>.html); answers come from localStorage
//! meiolol.daily.v1 (dailypage.read), so the server renders none
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
    /// daily.html, whose puzzle is the newest up to the viewer's date (else a puzzle's own page)
    today: bool,
    /// "" from the site root, "../" from daily/
    root: []const u8,
    /// The server's date (UTC): the first render's, before the viewer's own
    utc: []const u8,
    /// Every puzzle with a page, oldest first
    days: []const Day,
};

pub const Page = struct {
    d: *const Data,
    /// The viewer's date, "2026-10-27"
    date: []const u8,
    /// localStorage's meiolol.daily.v1 ("" until read)
    saved: []const u8 = "",
    /// The server's render: Data as ui.data, base64, for the island
    bin: []const u8 = "",

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
        for (days[from..], 0..) |x, i| on_time[i] = if (dp.finishedOn(s.saved, x.n)) |on| std.mem.eql(u8, on, x.date) else false;
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
            const m = if (dp.read(s.saved, x.n)) |v| v else null;
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
        return h.span(.{ .class = "c-days", .data_island = "days", .data_bin = if (s.bin.len > 0) s.bin else null }, .{
            h.el(.nav, .{ .class = "strip", .aria_label = W.past }, .{links}),
            h.span(.{ .class = "streak", .title = W.streak_tip, .aria_label = W.streak_read.with(h, .{ .n = st.run, .b = st.best }) }, .{
                phrase.num(h, .int, st.run),
                h.el(.small, .{ .aria_hidden = "true" }, .{W.streak}),
            }),
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
    const streak_read = Phrase("{n:int} days in a row, best {b:int}");
    const streak_tip = plain("Puzzles finished on their own day. One missed day is forgiven; two in a row end it.");
};

pub const css =
    \\@layer components {
    \\  .c-dhead { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2); }
    \\  .c-dhead h1 { margin: 0 var(--sp-1) 0 0; font-size: var(--fs-l); }
    \\  .c-dhead .n { color: var(--muted); font-weight: var(--w-m); }
    \\  .c-days { display: flex; align-items: center; gap: var(--sp-3); margin-left: auto; }
    \\  .c-days .strip { display: flex; gap: 3px; }
    \\  .c-days .strip a { width: 18px; height: 18px; border-radius: 4px; background: var(--panel-3); }
    \\  .c-days .strip a[data-r="2"] { background: var(--hi2); }
    \\  .c-days .strip a[data-r="1"] { background: var(--hi1); opacity: 0.7; }
    \\  .c-days .strip a[data-r="0"] { background: var(--lo1); opacity: 0.6; }
    \\  .c-days .strip a[aria-current="date"] { box-shadow: 0 0 0 2px var(--bg), 0 0 0 3.5px var(--text); }
    \\  .c-days .strip a[aria-current="page"] { outline: 1.5px dashed var(--text); outline-offset: 2px; }
    \\  .c-days .streak { font-size: var(--fs-l); font-weight: var(--w-b); font-variant-numeric: tabular-nums; }
    \\  .c-days .streak small { margin-left: 3px; font-size: var(--fs-s); font-weight: var(--w-r); color: var(--faint); }
    \\  @media (max-width: 760px) {
    \\    .c-days { margin-left: 0; width: 100%; }
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

const demo: Data = .{ .n = 17, .today = true, .root = "", .utc = "2026-10-27", .days = &demo_days };
const demo_archive: Data = .{ .n = 12, .today = false, .root = "../", .utc = "2026-10-27", .days = &demo_days };

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
    if (demoPage(h, &demo_archive, demo_saved)) |p| g.add("an archive puzzle's page (#12, dashed)", head(h, &dd.sample, p.view(h)));
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
    try testing.expectEqualStrings("7 days in a row, best 7", t.attr(t.find(v, "class", "streak").?, "aria-label").?);

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
