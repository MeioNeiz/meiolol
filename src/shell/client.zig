//! The League client's state for the shell: a thread steps lcu.Watch once a second
//! (read-only GETs, as the dvui poller) and keeps the latest; the UI thread's 1 s tick
//! sends it to the page when it changes. Champ select seats come with the app's screens

const std = @import("std");
const lcu = @import("lcu");
const channel = @import("channel.zig");

pub const Client = @FieldType(channel.Status, "client");

var latest: std.atomic.Value(u8) = .init(@backingInt(Client.none));
var quit: std.atomic.Value(bool) = .init(false);

/// `lockfile` null finds the client (lockfile.discover); MEIOLOL_LOCKFILE in dev
pub fn start(gpa: std.mem.Allocator, io: std.Io, lockfile: ?[]const u8) !void {
    (try std.Thread.spawn(.{}, loop, .{ gpa, io, lockfile })).detach();
}

pub fn stop() void {
    quit.store(true, .release);
}

pub fn current() Client {
    return @fromBackingInt(@intCast(latest.load(.acquire)));
}

fn loop(gpa: std.mem.Allocator, io: std.Io, lockfile: ?[]const u8) void {
    var watch: lcu.Watch = .init(gpa, io, lockfile);
    defer watch.deinit();
    while (!quit.load(.acquire)) {
        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();
        const now: Client = if (watch.step(arena.allocator())) |s| switch (s) {
            .phase => |p| fromPhase(p),
            .between, .bad_session, .select => .champ_select,
        } else |_| blk: {
            watch.disconnect();
            break :blk .none;
        };
        latest.store(@backingInt(now), .release);
        io.sleep(.fromSeconds(1), .awake) catch return;
    }
}

/// /lol-gameflow/v1/gameflow-phase's names
pub fn fromPhase(phase: []const u8) Client {
    const map = [_]struct { []const u8, Client }{
        .{ "ChampSelect", .champ_select },
        .{ "GameStart", .in_game },
        .{ "InProgress", .in_game },
        .{ "Reconnect", .in_game },
        .{ "WaitingForStats", .post_game },
        .{ "PreEndOfGame", .post_game },
        .{ "EndOfGame", .post_game },
    };
    for (map) |m| if (std.mem.eql(u8, m[0], phase)) return m[1];
    return .idle;
}

test "gameflow phases" {
    try std.testing.expectEqual(.champ_select, fromPhase("ChampSelect"));
    try std.testing.expectEqual(.in_game, fromPhase("InProgress"));
    try std.testing.expectEqual(.post_game, fromPhase("EndOfGame"));
    try std.testing.expectEqual(.idle, fromPhase("Lobby"));
    try std.testing.expectEqual(.idle, fromPhase("unknown"));
}
