//! /daily: Daily Draft (ui.dailypage), the newest puzzle up to today (UTC) from
//! daily/<n>.bin (dailydata.zig) in the island's data-bin; a note when there is none.
//! /daily/<n>: puzzle n's own page (the days strip links them), none past tomorrow
//! (UTC): a viewer a day ahead of UTC plays it. Noindex: today's would repeat /daily
//! and tomorrow's is not out for most. The head's days strip is its own island
//! (ui.dailydays). Answers stay in the browser
const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const assets = @import("assets.zig");
const daily = @import("../daily.zig");
const Date = @import("../date.zig").Date;
const ui = @import("ui");
const dd = ui.dailydata;
const ds = ui.dailydays;

const Writer = std.Io.Writer;
const Site = root.Site;
const File = root.File;
const tpl = html.tpl;
const log = std.log.scoped(.site);

pub fn write(site: *const Site, w: *Writer) !void {
    const a = site.arena;
    const p = try site.sharedPage(
        "Daily Draft | meiolol",
        "Guess the last pick and the winner of a real pro draft, then see how the model reads every seat.",
        .daily,
    );
    try html.head(w, p);
    const today = todayNumber(site.io);
    const got = try pick(a, site.daily_files, today);
    if (if (got) |g| g.page else null) |shown| {
        try body(a, w, site.daily_files, shown, .{ .today = today, .redirects = true, .root = "/", .origin = origin(site) });
    } else try w.writeAll(
        \\<h1>Daily Draft</h1>
        \\<p class="note">No puzzle today. Come back tomorrow.</p>
        \\
    );
    try html.foot(w, p);
}

/// /daily/<n>; false (not found) past tomorrow or without page data
pub fn route(site: *const Site, w: *Writer, n: u32) !bool {
    var buf: [10]u8 = undefined;
    return routeOn(site, w, std.fmt.bufPrint(&buf, "{d}", .{n}) catch unreachable, todayNumber(site.io));
}

fn routeOn(site: *const Site, w: *Writer, slug: []const u8, today: u32) !bool {
    const a = site.arena;
    const n = slugN(slug) orelse return false;
    const shown = try own(a, site.daily_files, n, today) orelse return false;
    var p = try site.sharedPage(
        try a.print("Daily Draft #{d} | meiolol", .{n}),
        "A past Daily Draft: guess the last pick and the winner of a real pro draft, then see how the model reads every seat.",
        .daily,
    );
    p.index = false;
    try html.head(w, p);
    try body(a, w, site.daily_files, shown, .{ .today = today, .redirects = false, .root = "/", .origin = origin(site) });
    try html.foot(w, p);
    return true;
}

const Where = struct {
    /// Today's (UTC) puzzle number
    today: u32,
    /// /daily (the days island opens the viewer's own day's puzzle from there)
    redirects: bool,
    /// From the page to the site root
    root: []const u8,
    /// "https://meio.lol" for Share's link; null hides Share
    origin: ?[]const u8 = null,
};

/// Share only once the site is public: a preview may not be advertised
fn origin(site: *const Site) ?[]const u8 {
    return if (site.opts.public) site.opts.origin else null;
}

/// The head with its days island, then the puzzle's island
fn body(a: std.mem.Allocator, w: *Writer, files: []const File, shown: Shown, at: Where) !void {
    const days: ds.Data = .{
        .n = shown.p.n,
        .redirects = at.redirects,
        .root = at.root,
        .utc = try a.print("{f}", .{dateOf(at.today)}),
        .days = try dayList(a, files, at.today + 1),
        .answer = @intCast(std.mem.findScalar(u16, shown.p.options, dd.played(&shown.p)) orelse return error.BadPuzzle),
        .winner = shown.p.result.winner,
        .hidden_side = shown.p.hidden_side,
        .hidden_role = shown.p.hidden_role,
        .url = if (at.origin) |o| try a.print("{s}/daily/{d}", .{ o, shown.p.n }) else "",
    };
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, ds.Data, days, &raw);
    const enc = std.base64.standard.Encoder;
    var strip: ds.Page = .init(a, &days);
    strip.bin = enc.encode(try a.alloc(u8, enc.calcSize(raw.items.len)), raw.items);
    var page: ui.dailypage.Page = .init(a, &shown.p);
    page.bin = shown.base64;
    var seat: ui.dailyseat.Seat = .init(a, &shown.p);
    seat.js = "/" ++ assets.dailyseat_js.path;
    seat.wasm = "/" ++ assets.dailyseat_wasm.path;
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const head = ds.head(&h, &shown.p, strip.view(&h));
    const cols = ui.dailypage.layout(&h, page.view(&h), seat.view(&h));
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, head, w);
    try ui.html.write(&t, cols, w);
    try tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\<script src="{djs}" data-wasm="{dwasm}" defer></script>
        \\
    , .{
        .js = html.Link{ .path = assets.daily_js.path },
        .wasm = html.Link{ .path = assets.daily_wasm.path },
        .djs = html.Link{ .path = assets.dailydays_js.path },
        .dwasm = html.Link{ .path = assets.dailydays_wasm.path },
    });
}

/// The puzzles' own pages the static build writes (route answers the same)
pub fn pagePaths(site: *const Site) ![]const ui.urls.Page {
    const a = site.arena;
    const days = try dayList(a, site.daily_files, todayNumber(site.io) + 1);
    const pages = try a.alloc(ui.urls.Page, days.len);
    for (pages, days) |*p, d| p.* = .{ .daily = d.n };
    return pages;
}

/// n of /daily/<n>, only as written: "07", "+7" and "1_7" would each be a copy of a
/// page (and a cache entry)
fn slugN(slug: []const u8) ?u32 {
    const n = std.fmt.parseInt(u32, slug, 10) catch return null;
    var buf: [10]u8 = undefined;
    return if (std.mem.eql(u8, std.fmt.bufPrint(&buf, "{d}", .{n}) catch unreachable, slug)) n else null;
}

/// Puzzle n's for its own page: none past tomorrow (`today` + 1)
fn own(a: std.mem.Allocator, files: []const File, n: u32, today: u32) !?Shown {
    if (n == 0 or n > today + 1) return null;
    return decoded(a, files, n);
}

/// Puzzles numbered `last` or before whose page data checks out (each a page `route`
/// answers), oldest first
fn dayList(a: std.mem.Allocator, files: []const File, last: u32) ![]const ds.Day {
    var ns: std.ArrayList(u32) = .empty;
    for (files) |f| if (puzzleOf(f.path, ".bin")) |n| if (n > 0 and n <= last and try checked(a, f.data, n) != null) try ns.append(a, n);
    std.mem.sort(u32, ns.items, {}, std.sort.asc(u32));
    const days = try a.alloc(ds.Day, ns.items.len);
    for (days, ns.items) |*d, n| d.* = .{ .n = n, .date = try a.print("{f}", .{dateOf(n)}) };
    return days;
}

/// Puzzle n's date (daily.update)
fn dateOf(n: u32) Date {
    return .fromDay(@as(i64, daily.first_day) + n - 1);
}

/// Puzzle n's page data, decoded and checked; null without it
fn decoded(a: std.mem.Allocator, files: []const File, n: u32) !?Shown {
    const raw = find(files, try a.print("daily/{d}.bin", .{n})) orelse return null;
    const p = try checked(a, raw, n) orelse return null;
    const enc = std.base64.standard.Encoder;
    const out = try a.alloc(u8, enc.calcSize(raw.len));
    return .{ .p = p, .base64 = enc.encode(out, raw) };
}

fn checked(a: std.mem.Allocator, raw: []const u8, n: u32) !?dd.Puzzle {
    const p = dd.decode(a, raw) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            log.warn("daily/{d}.bin: {t}", .{ n, err });
            return null;
        },
    };
    if (!p.valid()) {
        log.warn("daily/{d}.bin: not a valid puzzle", .{n});
        return null;
    }
    return p;
}

pub const Shown = struct { p: dd.Puzzle, base64: []const u8 };

pub const todayNumber = daily.todayNumber;

pub const Pick = struct {
    n: u32,
    /// daily/<n>.json; null in files without it
    json: ?[]const u8,
    /// daily/<n>.bin, decoded; null in files without page data
    page: ?Shown,
};

/// The newest puzzle numbered `today` or before, the Daily page's and home's: when `files`
/// hold page data (daily/<n>.bin), one whose data reads and checks out; else (the box's
/// core build reads only puzzle files) one with its JSON
pub fn pick(a: std.mem.Allocator, files: []const File, today: u32) !?Pick {
    var bins = false;
    for (files) |f| bins = bins or puzzleOf(f.path, ".bin") != null;
    const ext = if (bins) ".bin" else ".json";
    var best: ?Pick = null;
    for (files) |f| {
        const n = puzzleOf(f.path, ext) orelse continue;
        if (n > today) continue;
        if (best) |b| if (n <= b.n) continue;
        var got: Pick = .{ .n = n, .json = find(files, try a.print("daily/{d}.json", .{n})), .page = null };
        if (bins) got.page = try decoded(a, files, n) orelse continue;
        best = got;
    }
    return best;
}

/// n of daily/<n><ext>
fn puzzleOf(path: []const u8, ext: []const u8) ?u32 {
    if (!std.mem.startsWith(u8, path, "daily/") or !std.mem.endsWith(u8, path, ext)) return null;
    return std.fmt.parseInt(u32, path["daily/".len .. path.len - ext.len], 10) catch null;
}

fn find(files: []const File, path: []const u8) ?[]const u8 {
    for (files) |f| if (std.mem.eql(u8, f.path, path)) return f.data;
    return null;
}

test "today's puzzle: the newest numbered today or before with page data, else its JSON" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p8 = dd.sample;
    p8.n = 8;
    var p9 = dd.sample;
    p9.n = 9;
    const files = [_]File{
        .{ .path = "daily/7.json", .data = "{}" },
        .{ .path = "daily/8.json", .data = "{}" },
        .{ .path = "daily/9.json", .data = "{}" },
        .{ .path = "daily/index.json", .data = "[]" },
        .{ .path = "daily/8.bin", .data = try dd.encode(a, p8) },
        .{ .path = "daily/9.bin", .data = try dd.encode(a, p9) },
    };
    try std.testing.expectEqual(@as(u32, 8), (try pick(a, &files, 8)).?.page.?.p.n);
    const nine = (try pick(a, &files, 12)).?;
    try std.testing.expectEqual(@as(u32, 9), nine.page.?.p.n);
    try std.testing.expectEqualStrings("{}", nine.json.?);
    // The newest number wins, not the last file
    const unsorted = [_]File{ files[5], files[4] };
    try std.testing.expectEqual(@as(u32, 9), (try pick(a, &unsorted, 12)).?.page.?.p.n);
    // 7 has no page data
    try std.testing.expectEqual(null, try pick(a, &files, 7));
    // The core build's: puzzle files only
    const core = (try pick(a, files[0..4], 8)).?;
    try std.testing.expectEqual(@as(u32, 8), core.n);
    try std.testing.expectEqual(null, core.page);
    try std.testing.expectEqual(@as(u32, 9), (try pick(a, files[0..4], 100)).?.n);
    try std.testing.expectEqual(null, try pick(a, files[0..4], 0));
    try std.testing.expectEqual(null, try pick(a, &.{}, 8));
}

test "the head's days island and the puzzle's, from the site root or daily/" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const raw = try dd.encode(a, dd.sample);
    const n = dd.sample.n;
    const files = [_]File{
        .{ .path = try a.print("daily/{d}.bin", .{n}), .data = raw },
        .{ .path = try a.print("daily/{d}.bin", .{n + 2}), .data = raw },
        .{ .path = try a.print("daily/{d}.bin", .{n - 1}), .data = "bad" },
        .{ .path = try a.print("daily/{d}.json", .{n}), .data = "{}" },
    };
    const shown = (try own(a, &files, n, n)).?;
    const saved = std.testing.log_level;
    defer std.testing.log_level = saved;
    std.testing.log_level = .err;
    var out: std.Io.Writer.Allocating = .init(a);
    try body(a, &out.writer, &files, shown, .{ .today = n, .redirects = true, .root = "/" });
    const s = out.written();
    const enc = std.base64.standard.Encoder;
    const b64 = try a.alloc(u8, enc.calcSize(raw.len));
    try std.testing.expect(std.mem.find(u8, s, try a.print("data-bin=\"{s}\"", .{enc.encode(b64, raw)})) != null);
    try std.testing.expect(std.mem.find(u8, s, "<div class=\"c-dhead\"><h1>") != null);
    try std.testing.expect(std.mem.find(u8, s, "data-island=\"days\"") != null);
    try std.testing.expect(std.mem.find(u8, s, "data-island=\"daily\"") != null);
    try std.testing.expect(std.mem.find(u8, s, try a.print("<script src=\"/{s}\" data-wasm=\"/{s}\"", .{ assets.daily_js.path, assets.daily_wasm.path })) != null);
    try std.testing.expect(std.mem.find(u8, s, try a.print("<script src=\"/{s}\" data-wasm=\"/{s}\"", .{ assets.dailydays_js.path, assets.dailydays_wasm.path })) != null);
    // The seat review's island, loaded by ui-daily.wasm once answered
    try std.testing.expect(std.mem.find(u8, s, try a.print("<div class=\"c-dseat\" data-island=\"dailyseat\" data-js=\"/{s}\" data-wasm=\"/{s}\"></div>", .{ assets.dailyseat_js.path, assets.dailyseat_wasm.path })) != null);
    // The strip: puzzles with good page data up to tomorrow; n + 2 not yet, n - 1's
    // would be a link to a 404
    const days = try dayList(a, &files, n + 1);
    try std.testing.expectEqual(1, days.len);
    try std.testing.expectEqualStrings(try a.print("{f}", .{dateOf(n)}), days[0].date);
    try std.testing.expect(std.mem.find(u8, s, try a.print("href=\"/daily/{d}\"", .{n})) != null);

    var past: std.Io.Writer.Allocating = .init(a);
    try body(a, &past.writer, &files, shown, .{ .today = n + 1, .redirects = false, .root = "/" });
    try std.testing.expect(std.mem.find(u8, past.written(), try a.print("<script src=\"/{s}\"", .{assets.dailydays_js.path})) != null);
    try std.testing.expect(std.mem.find(u8, past.written(), try a.print("href=\"/daily/{d}\"", .{n})) != null);
}

test "a puzzle's own page: none past tomorrow, none without good page data" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const n = dd.sample.n;
    const files = [_]File{
        .{ .path = try a.print("daily/{d}.bin", .{n}), .data = try dd.encode(a, dd.sample) },
        .{ .path = try a.print("daily/{d}.bin", .{n - 1}), .data = "bad" },
    };
    try std.testing.expect(try own(a, &files, n, n) != null);
    try std.testing.expect(try own(a, &files, n, n - 1) != null);
    try std.testing.expectEqual(null, try own(a, &files, n, n - 2));
    try std.testing.expectEqual(null, try own(a, &files, n + 1, n + 1));
    try std.testing.expectEqual(null, try own(a, &files, 0, n));
    const saved = std.testing.log_level;
    defer std.testing.log_level = saved;
    std.testing.log_level = .err;
    try std.testing.expectEqual(null, try own(a, &files, n - 1, n));
}

test "slugs: a number only as printed" {
    try std.testing.expectEqual(@as(?u32, 7), slugN("7"));
    try std.testing.expectEqual(@as(?u32, 17), slugN("17"));
    try std.testing.expectEqual(@as(?u32, 0), slugN("0"));
    for ([_][]const u8{ "07", "+7", "1_7", "-1", "", "7x", " 7", "99999999999", "4294967296" }) |bad| {
        try std.testing.expectEqual(null, slugN(bad));
    }
}

test "route: a good n renders noindex from daily/, any other slug or n past tomorrow 404s" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const n = dd.sample.n;
    const files = [_]File{
        .{ .path = try a.print("daily/{d}.bin", .{n}), .data = try dd.encode(a, dd.sample) },
        .{ .path = try a.print("daily/{d}.bin", .{n + 2}), .data = try dd.encode(a, dd.sample) },
    };
    var site: Site = undefined;
    site.arena = a;
    site.patch = "16.20";
    site.when = "last 30 days";
    site.games = 1000;
    site.patch_mix = "";
    site.view = html.View.shared;
    site.daily_files = &files;
    site.opts = .{
        .out_dir = "",
        .patches = &.{"16.20"},
        .since_ms = 0,
        .all_platforms = &.{"EUW1"},
        .contact = "",
        .updated = "",
        .public = true,
        .origin = "https://x.io",
    };
    var out: std.Io.Writer.Allocating = .init(a);
    try std.testing.expect(try routeOn(&site, &out.writer, try a.print("{d}", .{n}), n));
    const s = out.written();
    try std.testing.expectEqualStrings(try a.print("https://x.io/daily/{d}", .{n}), (try daysData(a, s)).url);
    try std.testing.expect(std.mem.find(u8, s, try a.print("<title>Daily Draft #{d} | meiolol</title>", .{n})) != null);
    try std.testing.expect(std.mem.find(u8, s, "content=\"noindex") != null);
    try std.testing.expect(std.mem.find(u8, s, "rel=\"canonical\"") == null);
    try std.testing.expect(std.mem.find(u8, s, try a.print("href=\"/daily/{d}\"", .{n})) != null);
    try std.testing.expect(std.mem.find(u8, s, try a.print("<script src=\"/{s}\"", .{assets.daily_js.path})) != null);
    // Tomorrow's is out for a viewer a day ahead
    try std.testing.expect(try routeOn(&site, &out.writer, try a.print("{d}", .{n}), n - 1));
    for ([_][]const u8{ try a.print("0{d}", .{n}), try a.print("+{d}", .{n}), "0", "", "99999999999" }) |slug| {
        try std.testing.expect(!try routeOn(&site, &out.writer, slug, n));
    }
    try std.testing.expect(!try routeOn(&site, &out.writer, try a.print("{d}", .{n + 2}), n));
    try std.testing.expect(!try routeOn(&site, &out.writer, try a.print("{d}", .{n}), n - 2));

    // Preview: no Share
    site.opts.public = false;
    var preview: std.Io.Writer.Allocating = .init(a);
    try std.testing.expect(try routeOn(&site, &preview.writer, try a.print("{d}", .{n}), n));
    try std.testing.expectEqualStrings("", (try daysData(a, preview.written())).url);
}

/// The days island's data in a rendered page
fn daysData(a: std.mem.Allocator, page: []const u8) !ds.Data {
    const at = std.mem.find(u8, page, "data-island=\"days\" data-bin=\"") orelse return error.TestUnexpectedResult;
    const from = page[at + "data-island=\"days\" data-bin=\"".len ..];
    const b64 = from[0 .. std.mem.findScalar(u8, from, '"') orelse return error.TestUnexpectedResult];
    const dec = std.base64.standard.Decoder;
    const raw = try a.alloc(u8, try dec.calcSizeForSlice(b64));
    try dec.decode(raw, b64);
    return ui.data.decode(a, ds.Data, raw);
}
