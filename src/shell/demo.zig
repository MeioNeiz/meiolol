//! A made-up champ select for `--demo` and `--measure`: one pick every 3 s, starting over
//! after the tenth, so the channel and a page can be tried and timed without League

const std = @import("std");
const channel = @import("channel.zig");

const seats = [10][2][]const u8{
    .{ "Irelia", "Irelia" },
    .{ "LeeSin", "Lee Sin" },
    .{ "Zed", "Zed" },
    .{ "Jhin", "Jhin" },
    .{ "Yuumi", "Yuumi" },
    .{ "Darius", "Darius" },
    .{ "Chogath", "Cho'Gath" },
    .{ "Xerath", "Xerath" },
    .{ "Xayah", "Xayah" },
    .{ "Leona", "Leona" },
};
/// Blind pick order by seat: B1, R1, R2, B2, B3, R3, R4, B4, B5, R5
const order = [10]u8{ 0, 5, 6, 1, 2, 7, 8, 3, 4, 9 };

pub fn champSelect(seq: u32) channel.ToPage {
    const step = (seq / 3) % 11;
    var out: channel.ChampSelect = .{
        .seq = seq,
        .timer = @intCast(30 - (seq % 3) * 10),
        .blue = 50.0 + 6.0 * @sin(@as(f32, @floatFromInt(seq)) / 4.0),
        .seats = undefined,
    };
    for (&out.seats, 0..) |*s, i| {
        const turn = std.mem.indexOfScalar(u8, &order, @intCast(i)).?;
        s.* = if (turn < step)
            .{ .key = seats[i][0], .name = seats[i][1], .state = .done }
        else
            .{ .state = if (turn == step) .picking else .empty };
    }
    return .{ .champ_select = out };
}

test "demo: picks fill in pick order and start over" {
    try std.testing.expectEqual(.picking, champSelect(0).champ_select.seats[0].state);
    const later = champSelect(3 * 4).champ_select;
    for ([_]usize{ 0, 5, 6, 1 }) |i| try std.testing.expectEqual(.done, later.seats[i].state);
    try std.testing.expectEqual(.picking, later.seats[2].state);
    try std.testing.expectEqual(.empty, later.seats[9].state);
    try std.testing.expectEqual(.picking, champSelect(33).champ_select.seats[0].state);
}
