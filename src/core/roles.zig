const std = @import("std");

/// Riot match-v5 teamPosition order: TOP JUNGLE MIDDLE BOTTOM UTILITY
pub const Role = enum(u3) {
    top,
    jungle,
    middle,
    bottom,
    utility,

    pub const count = 5;
    pub const all = [count]Role{ .top, .jungle, .middle, .bottom, .utility };

    /// LCU assignedPosition ("top", "jungle", "middle", "bottom", "utility"; "" when
    /// unknown) or a Riot teamPosition ("TOP" ...). Null for "" and anything else.
    pub fn fromLcu(s: []const u8) ?Role {
        var buf: [16]u8 = undefined;
        if (s.len > buf.len) return null;
        return std.meta.stringToEnum(Role, std.ascii.lowerString(&buf, s));
    }

    /// Typed by a person: Riot names plus common aliases, any case
    pub fn parse(s: []const u8) ?Role {
        if (fromLcu(s)) |r| return r;
        var buf: [16]u8 = undefined;
        if (s.len > buf.len) return null;
        const lower = std.ascii.lowerString(&buf, s);
        const aliases = [_]struct { []const u8, Role }{
            .{ "mid", .middle },
            .{ "adc", .bottom },
            .{ "bot", .bottom },
            .{ "carry", .bottom },
            .{ "sup", .utility },
            .{ "supp", .utility },
            .{ "support", .utility },
            .{ "jg", .jungle },
            .{ "jng", .jungle },
            .{ "jungler", .jungle },
        };
        for (aliases) |a| if (std.mem.eql(u8, lower, a[0])) return a[1];
        return null;
    }

    /// For people: "top", "jungle", "mid", "bot", "support"
    pub fn label(r: Role) []const u8 {
        return switch (r) {
            .top => "top",
            .jungle => "jungle",
            .middle => "mid",
            .bottom => "bot",
            .utility => "support",
        };
    }
};

test "lcu positions" {
    try std.testing.expectEqual(Role.top, Role.fromLcu("top").?);
    try std.testing.expectEqual(Role.utility, Role.fromLcu("UTILITY").?);
    try std.testing.expectEqual(@as(?Role, null), Role.fromLcu(""));
    try std.testing.expectEqual(@as(?Role, null), Role.fromLcu("mid"));
}

test "aliases" {
    try std.testing.expectEqual(Role.middle, Role.parse("Mid").?);
    try std.testing.expectEqual(Role.bottom, Role.parse("adc").?);
    try std.testing.expectEqual(Role.bottom, Role.parse("bot").?);
    try std.testing.expectEqual(Role.utility, Role.parse("sup").?);
    try std.testing.expectEqual(Role.utility, Role.parse("support").?);
    try std.testing.expectEqual(Role.jungle, Role.parse("jg").?);
    try std.testing.expectEqual(Role.jungle, Role.parse("JNG").?);
    try std.testing.expectEqual(@as(?Role, null), Role.parse("feeder"));
    try std.testing.expectEqual(3, @intFromEnum(Role.bottom));
}
