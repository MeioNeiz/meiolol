//! Bits of running text shared by pages

const std = @import("std");

/// "s" unless one: `{n} game{s}`
pub fn plural(n: u64) []const u8 {
    return if (n == 1) "" else "s";
}

/// 1 -> "st", 12 -> "th", 22 -> "nd"
pub fn ordinal(n: usize) []const u8 {
    if (n % 100 >= 11 and n % 100 <= 13) return "th";
    return switch (n % 10) {
        1 => "st",
        2 => "nd",
        3 => "rd",
        else => "th",
    };
}

/// `part` of `whole` as a whole percentage, "-" when there is none; for tpl.call
pub fn percent(w: *std.Io.Writer, part: u64, whole: u64) !void {
    if (whole == 0) return w.writeAll("-");
    try w.print("{d:.0}%", .{100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole))});
}

test percent {
    var buf: [8]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try percent(&w, 1, 3);
    try percent(&w, 0, 0);
    try std.testing.expectEqualStrings("33%-", w.buffered());
}
