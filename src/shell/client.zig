//! The League client's state for the shell, from the app's poller (src/desktop/poller.zig:
//! read-only GETs once a second, with the stats and curves beside the exe). The UI
//! thread's 1 s tick, or the poller's wake, sends it to the page when it changes

const std = @import("std");
const build_options = @import("build_options");
const desktop = @import("desktop");
const channel = @import("channel.zig");
const poller = desktop.poller;
const state = desktop.state;

pub const Client = @FieldType(channel.Status, "client");

/// `lockfile` null finds the client; MEIOLOL_LOCKFILE in dev. `wake` runs on the poller's
/// thread after each change
pub fn start(init: std.process.Init, lockfile: ?[]const u8, wake: *const fn () void) !void {
    try poller.start(init, .{
        .lockfile = lockfile,
        .wake = wake,
        .release = build_options.desktop_version,
        .edition = if (build_options.public) .public else .private,
        .update_exe = false,
    });
}

pub fn stop() void {
    poller.stop();
}

/// The page's sign-in form; the poller copies what it keeps
pub fn signIn(username: []const u8, password: []const u8) void {
    const s = poller.lock();
    defer poller.unlock();
    s.submit(username, password);
}

/// Champ select's mastery toggle; wakes the poller to rebuild the card now
pub fn mastery(on: bool) void {
    state.by_mastery.store(on, .release);
    const s = poller.lock();
    defer poller.unlock();
    s.practice_changed();
}

pub fn current() Client {
    const s = poller.lock();
    defer poller.unlock();
    return of(s.status);
}

fn of(s: state.Status) Client {
    return switch (s) {
        .no_data => .no_data,
        .no_client, .client_error => .none,
        .waiting => |phase| if (std.mem.eql(u8, phase, "Champ select"))
            .champ_select
        else if (std.mem.eql(u8, phase, "In game") or std.mem.eql(u8, phase, "Reconnect"))
            .in_game
        else if (std.mem.eql(u8, phase, "Post game"))
            .post_game
        else
            .idle,
        .no_role, .select => .champ_select,
        .loading, .in_game => .in_game,
        .post_game => .post_game,
    };
}

test "the poller's status as the page's client state" {
    try std.testing.expectEqual(.none, of(.no_client));
    try std.testing.expectEqual(.none, of(.{ .client_error = "ConnectionRefused" }));
    try std.testing.expectEqual(.no_data, of(.no_data));
    try std.testing.expectEqual(.idle, of(.{ .waiting = "Lobby" }));
    try std.testing.expectEqual(.champ_select, of(.{ .waiting = "Champ select" }));
    try std.testing.expectEqual(.in_game, of(.{ .waiting = "In game" }));
    try std.testing.expectEqual(.post_game, of(.{ .waiting = "Post game" }));
    try std.testing.expectEqual(.champ_select, of(.no_role));
}
