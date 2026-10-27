//! daily.html: Daily Draft (ui.dailypage), the newest puzzle up to today (UTC) from
//! daily/<n>.bin (dailydata.zig) in the island's data-bin; a note when there is none.
//! Answers stay in the browser
const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const assets = @import("assets.zig");
const daily = @import("../daily.zig");
const ui = @import("ui");
const dd = ui.dailydata;

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
    try body(a, w, site.daily_files, todayNumber(site.io));
    try html.foot(w, p);
}

/// The island on the newest puzzle up to number `today` (pick), else a note
fn body(a: std.mem.Allocator, w: *Writer, files: []const File, today: u32) !void {
    const got = try pick(a, files, today);
    const bin = (if (got) |g| g.page else null) orelse return w.writeAll(
        \\<h1>Daily Draft</h1>
        \\<p class="note">No puzzle today. Come back tomorrow.</p>
        \\
    );
    var page: ui.dailypage.Page = .init(a, &bin.p);
    page.bin = bin.base64;
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    t.root = page.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    try tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{ .js = assets.daily_js.path, .wasm = assets.daily_wasm.path });
}

pub const Shown = struct { p: dd.Puzzle, base64: []const u8 };

/// Today's (UTC) puzzle number; puzzle n is dated first_day + n - 1 (daily.update)
pub fn todayNumber(io: std.Io) u32 {
    const day = @divFloor(std.Io.Clock.real.now(io).toSeconds(), std.time.s_per_day);
    return if (day < daily.first_day) 0 else @intCast(day - daily.first_day + 1);
}

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
        if (bins) {
            const p = dd.decode(a, f.data) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => {
                    log.warn("daily/{d}.bin: {t}", .{ n, err });
                    continue;
                },
            };
            if (!p.valid()) {
                log.warn("daily/{d}.bin: not a valid puzzle", .{n});
                continue;
            }
            const enc = std.base64.standard.Encoder;
            const out = try a.alloc(u8, enc.calcSize(f.data.len));
            got.page = .{ .p = p, .base64 = enc.encode(out, f.data) };
        }
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

test "the island with its data, or the note without a puzzle" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const raw = try dd.encode(a, dd.sample);
    const files = [_]File{
        .{ .path = try a.print("daily/{d}.bin", .{dd.sample.n}), .data = raw },
    };
    var out: std.Io.Writer.Allocating = .init(a);
    try body(a, &out.writer, &files, dd.sample.n);
    const s = out.written();
    try std.testing.expect(std.mem.find(u8, s, "data-island=\"daily\"") != null);
    const enc = std.base64.standard.Encoder;
    const b64 = try a.alloc(u8, enc.calcSize(raw.len));
    try std.testing.expect(std.mem.find(u8, s, try a.print("data-bin=\"{s}\"", .{enc.encode(b64, raw)})) != null);
    try std.testing.expect(std.mem.find(u8, s, assets.daily_wasm.path) != null);
    try std.testing.expect(std.mem.find(u8, s, assets.daily_js.path) != null);
    try std.testing.expect(std.mem.find(u8, s, "No puzzle today") == null);

    var none: std.Io.Writer.Allocating = .init(a);
    try body(a, &none.writer, &files, dd.sample.n - 1);
    try std.testing.expect(std.mem.find(u8, none.written(), "No puzzle today") != null);
}
