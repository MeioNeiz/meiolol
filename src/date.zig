//! UTC calendar dates. std.time.epoch has the calendar maths but no formatting or
//! parsing; everything that prints or reads a date goes through here.

const std = @import("std");
const epoch = std.time.epoch;

pub const Date = struct {
    year: u16,
    /// 1..12
    month: u8,
    /// 1..31
    day: u8,

    /// Days since 1970-01-01 (not before it)
    pub fn fromDay(day: i64) Date {
        const yd = (epoch.EpochDay{ .day = @intCast(day) }).calculateYearDay();
        const md = yd.calculateMonthDay();
        return .{ .year = yd.year, .month = md.month.numeric(), .day = md.day_index + 1 };
    }

    /// Unix seconds
    pub fn fromSeconds(secs: i64) Date {
        return fromDay(@divFloor(secs, std.time.s_per_day));
    }

    /// Unix milliseconds (Riot's timestamps)
    pub fn fromMs(ms: i64) Date {
        return fromDay(@divFloor(ms, std.time.ms_per_day));
    }

    /// Days since 1970-01-01 (Howard Hinnant's days_from_civil)
    pub fn toDay(d: Date) i64 {
        const m: i64 = d.month;
        const y = if (m <= 2) @as(i64, d.year) - 1 else d.year;
        const era = @divFloor(y, 400);
        const yoe = y - era * 400;
        const mp = @mod(m + 9, 12);
        const doy = @divFloor(153 * mp + 2, 5) + d.day - 1;
        const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
        return era * 146097 + doe - 719468;
    }

    /// "2026-10-11"; null for anything else
    pub fn parse(s: []const u8) ?Date {
        if (s.len != 10 or s[4] != '-' or s[7] != '-') return null;
        const d: Date = .{
            .year = std.fmt.parseInt(u16, s[0..4], 10) catch return null,
            .month = std.fmt.parseInt(u8, s[5..7], 10) catch return null,
            .day = std.fmt.parseInt(u8, s[8..10], 10) catch return null,
        };
        if (d.month < 1 or d.month > 12 or d.day < 1 or d.day > 31) return null;
        return d;
    }

    /// "2026-10-11"
    pub fn format(d: Date, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("{d:0>4}-{d:0>2}-{d:0>2}", .{ d.year, d.month, d.day });
    }

    /// "11 October 2026", for pages
    pub fn long(d: Date) std.fmt.Alt(Date, writeLong) {
        return .{ .data = d };
    }

    fn writeLong(d: Date, w: *std.Io.Writer) std.Io.Writer.Error!void {
        const months = [_][]const u8{
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December",
        };
        try w.print("{d} {s} {d}", .{ d.day, months[d.month - 1], d.year });
    }
};

test Date {
    const d: Date = .fromSeconds(1_760_140_800 + 3600);
    try std.testing.expectEqual(Date{ .year = 2025, .month = 10, .day = 11 }, d);
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("2025-10-11", try std.fmt.bufPrint(&buf, "{f}", .{d}));
    try std.testing.expectEqualStrings("11 October 2025", try std.fmt.bufPrint(&buf, "{f}", .{d.long()}));
    try std.testing.expectEqual(d, Date.parse("2025-10-11").?);
    try std.testing.expectEqual(null, Date.parse("2025-13-01"));
    try std.testing.expectEqual(0, (Date{ .year = 1970, .month = 1, .day = 1 }).toDay());
    try std.testing.expectEqual(20737, (Date{ .year = 2026, .month = 10, .day = 11 }).toDay());
    for ([_]i64{ 0, 59, 60, 20737, 40000 }) |day| try std.testing.expectEqual(day, Date.fromDay(day).toDay());
}
