//! daily.html: Daily Draft (ui.dailypage), the newest puzzle up to today (UTC) from
//! daily/<n>.bin (dailydata.zig) in the island's data-bin; a note when there is none.
//! Answers stay in the browser
const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const assets = @import("assets.zig");
const Date = @import("../date.zig").Date;
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
    const day = @divFloor(std.Io.Clock.real.now(site.io).toSeconds(), std.time.s_per_day);
    try body(a, w, site.daily_files, try a.print("{f}", .{Date.fromDay(day)}));
    try html.foot(w, p);
}

/// The island on the newest puzzle up to `today`, else a note
fn body(a: std.mem.Allocator, w: *Writer, files: []const File, today: []const u8) !void {
    const bin = try todays(a, files, today) orelse return w.writeAll(
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

const Shown = struct { p: dd.Puzzle, base64: []const u8 };

/// The newest puzzle dated `today` or before with page data that reads and checks out
fn todays(a: std.mem.Allocator, files: []const File, today: []const u8) !?Shown {
    const index = find(files, "daily/index.json") orelse return null;
    const Entry = struct { n: u32, date: []const u8 };
    const list = std.json.parseFromSliceLeaky([]const Entry, a, index, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            log.warn("daily/index.json: {t}", .{err});
            return null;
        },
    };
    var best: ?Shown = null;
    var best_date: []const u8 = "";
    for (list) |e| {
        if (std.mem.order(u8, e.date, today) == .gt) continue;
        if (best != null and std.mem.order(u8, e.date, best_date) != .gt) continue;
        const raw = find(files, try a.print("daily/{d}.bin", .{e.n})) orelse continue;
        const p = dd.decode(a, raw) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                log.warn("daily/{d}.bin: {t}", .{ e.n, err });
                continue;
            },
        };
        if (!p.valid()) {
            log.warn("daily/{d}.bin: not a valid puzzle", .{e.n});
            continue;
        }
        const enc = std.base64.standard.Encoder;
        const out = try a.alloc(u8, enc.calcSize(raw.len));
        best = .{ .p = p, .base64 = enc.encode(out, raw) };
        best_date = e.date;
    }
    return best;
}

fn find(files: []const File, path: []const u8) ?[]const u8 {
    for (files) |f| if (std.mem.eql(u8, f.path, path)) return f.data;
    return null;
}

test "today's puzzle: the newest dated today or before with page data" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p8 = dd.sample;
    p8.n = 8;
    var p9 = dd.sample;
    p9.n = 9;
    const files = [_]File{
        .{ .path = "daily/index.json", .data = "[{\"n\":7,\"date\":\"2026-10-26\"},{\"n\":8,\"date\":\"2026-10-27\"},{\"n\":9,\"date\":\"2026-10-28\"}]" },
        .{ .path = "daily/8.bin", .data = try dd.encode(a, p8) },
        .{ .path = "daily/9.bin", .data = try dd.encode(a, p9) },
    };
    try std.testing.expectEqual(@as(u32, 8), (try todays(a, &files, "2026-10-27")).?.p.n);
    try std.testing.expectEqual(@as(u32, 9), (try todays(a, &files, "2026-10-29")).?.p.n);
    // 7 has no page data
    try std.testing.expectEqual(null, try todays(a, &files, "2026-10-26"));
    try std.testing.expectEqual(null, try todays(a, files[1..], "2026-10-27"));
    // The newest date wins, not the last entry
    const unsorted = [_]File{
        .{ .path = "daily/index.json", .data = "[{\"n\":9,\"date\":\"2026-10-28\"},{\"n\":8,\"date\":\"2026-10-27\"}]" },
        files[1],
        files[2],
    };
    try std.testing.expectEqual(@as(u32, 9), (try todays(a, &unsorted, "2026-10-29")).?.p.n);
}

test "the island with its data, or the note without a puzzle" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const raw = try dd.encode(a, dd.sample);
    const files = [_]File{
        .{ .path = "daily/index.json", .data = try a.print("[{{\"n\":{d},\"date\":\"2026-10-27\"}}]", .{dd.sample.n}) },
        .{ .path = try a.print("daily/{d}.bin", .{dd.sample.n}), .data = raw },
    };
    var out: std.Io.Writer.Allocating = .init(a);
    try body(a, &out.writer, &files, "2026-10-27");
    const s = out.written();
    try std.testing.expect(std.mem.find(u8, s, "data-island=\"daily\"") != null);
    const enc = std.base64.standard.Encoder;
    const b64 = try a.alloc(u8, enc.calcSize(raw.len));
    try std.testing.expect(std.mem.find(u8, s, try a.print("data-bin=\"{s}\"", .{enc.encode(b64, raw)})) != null);
    try std.testing.expect(std.mem.find(u8, s, assets.daily_wasm.path) != null);
    try std.testing.expect(std.mem.find(u8, s, assets.daily_js.path) != null);
    try std.testing.expect(std.mem.find(u8, s, "No puzzle today") == null);

    var none: std.Io.Writer.Allocating = .init(a);
    try body(a, &none.writer, &files, "2026-10-26");
    try std.testing.expect(std.mem.find(u8, none.written(), "No puzzle today") != null);
}
