//! Where the window opens: last time's place, saved on close as one line of text, kept
//! on the screen it was on if that screen is still there (else moved onto the nearest)

const std = @import("std");

pub const Rect = struct { x: i32, y: i32, w: i32, h: i32 };

pub const Saved = struct {
    /// The restored (not maximised) frame, in physical pixels
    rect: Rect,
    maximised: bool,
};

/// Smallest window the board fits in, at 96 dpi
pub const min_w = 720;
pub const min_h = 480;

pub fn format(w: *std.Io.Writer, s: Saved) !void {
    try w.print("{d} {d} {d} {d} {d}\n", .{ s.rect.x, s.rect.y, s.rect.w, s.rect.h, @intFromBool(s.maximised) });
}

pub fn parse(text: []const u8) ?Saved {
    var it = std.mem.tokenizeAny(u8, text, " \r\n");
    var v: [5]i32 = undefined;
    for (&v) |*x| x.* = std.fmt.parseInt(i32, it.next() orelse return null, 10) catch return null;
    if (it.next() != null or v[2] <= 0 or v[3] <= 0 or v[4] < 0 or v[4] > 1) return null;
    return .{ .rect = .{ .x = v[0], .y = v[1], .w = v[2], .h = v[3] }, .maximised = v[4] == 1 };
}

/// `r` moved and shrunk to lie inside `work` (the nearest screen's work area): a window
/// saved on a screen since unplugged, or larger than this one, still opens whole
pub fn fit(r: Rect, work: Rect) Rect {
    const w = @min(r.w, work.w);
    const h = @min(r.h, work.h);
    return .{
        .x = std.math.clamp(r.x, work.x, work.x + work.w - w),
        .y = std.math.clamp(r.y, work.y, work.y + work.h - h),
        .w = w,
        .h = h,
    };
}

test "saved place round trip, bad text is no place" {
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    const s: Saved = .{ .rect = .{ .x = -1900, .y = 40, .w = 1280, .h = 800 }, .maximised = true };
    try format(&w, s);
    try std.testing.expectEqualDeep(s, parse(w.buffered()).?);
    for ([_][]const u8{ "", "1 2 3", "1 2 0 4 0", "1 2 3 4 2", "1 2 3 4 0 5", "a b c d e" }) |bad|
        try std.testing.expect(parse(bad) == null);
}

test "fit: kept where it fits, moved on and shrunk where not" {
    const screen: Rect = .{ .x = 0, .y = 0, .w = 1920, .h = 1040 };
    const r: Rect = .{ .x = 100, .y = 50, .w = 1120, .h = 720 };
    try std.testing.expectEqualDeep(r, fit(r, screen));
    // Saved on a second screen to the left, since unplugged
    try std.testing.expectEqualDeep(Rect{ .x = 0, .y = 50, .w = 1120, .h = 720 }, fit(.{ .x = -1500, .y = 50, .w = 1120, .h = 720 }, screen));
    // Larger than this screen
    try std.testing.expectEqualDeep(screen, fit(.{ .x = 10, .y = 10, .w = 2560, .h = 1400 }, screen));
}
