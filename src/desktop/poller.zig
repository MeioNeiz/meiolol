//! The desktop window's data, shared by every window backend (desktop_main.zig on
//! Windows, desktop_dev.zig elsewhere): stats and curves loaded once, and a poller thread
//! that reads the League client once a second and publishes what to show; the UI thread
//! only draws it. Read-only GETs, as `meiolol-app watch`.

const std = @import("std");
const core = @import("core");
const lcu = @import("../lcu/root.zig");
const lanecard = @import("../lanecard.zig");
const datafiles = @import("../datafiles.zig");
const ui = @import("ui.zig");

/// What the UI shows. The poller swaps `status` and the arena that owns it under the
/// mutex; the UI holds the mutex for a whole frame
const Shared = struct {
    mutex: std.Io.Mutex = .init,
    status: ui.Status = .no_client,
    arena: ?std.heap.ArenaAllocator = null,
    quit: std.atomic.Value(bool) = .init(false),
};

var shared: Shared = .{};
var io: std.Io = undefined;
var stats: ?core.Stats = null;
var curves: ?core.curvesfile.Curves = null;
/// Null finds the client (lockfile.discover); the dev window passes MEIOLOL_LOCKFILE
var lockfile: ?[]const u8 = null;
/// Wakes the UI thread after a publish
var wake: *const fn () void = undefined;

pub fn start(init: std.process.Init, lockfile_override: ?[]const u8, wake_ui: *const fn () void) !void {
    io = init.io;
    lockfile = lockfile_override;
    wake = wake_ui;
    const gpa = init.gpa;
    const arena = init.arena.allocator();
    const cwd = std.Io.Dir.cwd();
    const limit: std.Io.Limit = .limited(1 << 30);

    const stats_path = try datafiles.stats(arena, io) orelse {
        shared.status = .no_data;
        return;
    };
    stats = core.Stats.parse(arena, try cwd.readFileAlloc(io, stats_path, arena, limit)) catch |err| {
        std.log.err("{s}: {t}", .{ stats_path, err });
        shared.status = .no_data;
        return;
    };
    // Without curves the card still lists options, without lane gold
    if (try datafiles.curves(arena, io)) |p| {
        curves = core.curvesfile.Curves.parse(arena, try cwd.readFileAlloc(io, p, arena, limit)) catch |err| blk: {
            std.log.err("{s}: {t}", .{ p, err });
            break :blk null;
        };
    }
    // Detached: a request to a hung client cannot be interrupted (no network timeouts
    // in Threaded IO), so quitting must not wait for it
    const thread = try std.Thread.spawn(.{}, poll, .{gpa});
    thread.detach();
}

pub fn stop() void {
    shared.quit.store(true, .release);
}

/// Draws the current status: call between dvui's begin and end
pub fn frame() void {
    shared.mutex.lockUncancelable(io);
    defer shared.mutex.unlock(io);
    ui.frame(.{ .status = shared.status, .stats = if (stats) |*s| s else null });
}

fn publish(status: ui.Status, arena: std.heap.ArenaAllocator) void {
    shared.mutex.lockUncancelable(io);
    const old = shared.arena;
    shared.status = status;
    shared.arena = arena;
    shared.mutex.unlock(io);
    if (old) |o| o.deinit();
    wake();
}

fn poll(gpa: std.mem.Allocator) void {
    var p: Poller = .{ .watch = .init(gpa, io, lockfile), .own_arena = .init(gpa) };
    defer p.deinit();
    var shown: u64 = 0;
    while (!shared.quit.load(.acquire)) {
        var arena: std.heap.ArenaAllocator = .init(gpa);
        const status = p.tick(arena.allocator()) catch |err| switch (err) {
            error.OutOfMemory => return,
            else => p.disconnect(arena.allocator(), err),
        };
        const key = p.key(status);
        if (key != shown) {
            shown = key;
            publish(status, arena);
        } else arena.deinit();
        std.Io.sleep(io, .fromSeconds(1), .awake) catch {};
    }
}

/// The client watch and the player's own data, kept across ticks
const Poller = struct {
    watch: lcu.Watch,
    /// Mastery and tier: loaded once per champ select
    own_arena: std.heap.ArenaAllocator,
    own: ?Own = null,
    /// What the last tick saw, for key()
    fingerprint: u64 = 0,

    const Own = struct {
        mastery: []lanecard.Mastery,
        tier: ?[]const u8,
    };

    fn deinit(p: *Poller) void {
        p.watch.deinit();
        p.own_arena.deinit();
    }

    fn forgetOwn(p: *Poller) void {
        _ = p.own_arena.reset(.retain_capacity);
        p.own = null;
    }

    fn disconnect(p: *Poller, arena: std.mem.Allocator, err: anyerror) ui.Status {
        p.watch.disconnect();
        p.forgetOwn();
        if (err == error.ClientNotRunning) return .no_client;
        return .{ .client_error = arena.dupe(u8, @errorName(err)) catch "error" };
    }

    /// Changes whenever what the status shows would
    fn key(p: *const Poller, s: ui.Status) u64 {
        var h: std.hash.Wyhash = .init(0);
        h.update(@tagName(s));
        switch (s) {
            .waiting => |phase| h.update(phase),
            .client_error => |e| h.update(e),
            .card => h.update(std.mem.asBytes(&p.fingerprint)),
            else => {},
        }
        return h.final();
    }

    fn tick(p: *Poller, arena: std.mem.Allocator) !ui.Status {
        const cs = switch (try p.watch.step(arena)) {
            .phase => |phase| {
                p.forgetOwn();
                return .{ .waiting = phaseLabel(phase) };
            },
            .between => return .{ .waiting = "Champ select" },
            .bad_session => |err| return .{ .client_error = @errorName(err) },
            .select => |cs| cs,
        };
        const role = cs.my_role orelse return .no_role;

        if (p.own == null) p.own = p.loadOwn(p.watch.client.?);
        const own = p.own.?;
        const pool = p.watch.pool;
        var h: std.hash.Wyhash = .init(cs.fingerprint());
        h.update(std.mem.asBytes(&role));
        if (pool) |ids| h.update(std.mem.sliceAsBytes(ids));
        p.fingerprint = h.final();

        const card = try arena.create(lanecard.Card);
        card.* = try lanecard.build(arena, .{
            .stats = &stats.?,
            .curves = if (curves) |*c| c else null,
            .role = role,
            .me = cs.my_champion,
            .locked = cs.my_locked,
            .allies = cs.allies,
            .enemies = cs.enemies,
            .bans = cs.bans,
            .pickable = pool,
            .mastery = own.mastery,
            .tier = own.tier,
        });
        return .{ .card = card };
    }

    /// Whatever fails to load is left out: the card works without it
    fn loadOwn(p: *Poller, client: lcu.Client) Own {
        const a = p.own_arena.allocator();
        var own: Own = .{ .mastery = &.{}, .tier = null };
        if (client.getOk(lcu.me.paths.mastery)) |body| {
            defer client.gpa.free(body);
            const rows = lcu.me.parseMastery(a, body) catch &.{};
            own.mastery = a.alloc(lanecard.Mastery, rows.len) catch &.{};
            for (own.mastery, rows[0..own.mastery.len]) |*m, r| m.* = .{ .champion = r.champion, .points = r.points };
        } else |_| {}
        if (client.getOk(lcu.me.paths.ranked)) |body| {
            defer client.gpa.free(body);
            own.tier = lcu.me.parseSoloTier(a, body) catch null;
        } else |_| {}
        return own;
    }
};

/// Gameflow phases as the header shows them
fn phaseLabel(phase: []const u8) []const u8 {
    const names = [_]struct { []const u8, []const u8 }{
        .{ "None", "Home" },
        .{ "Lobby", "Lobby" },
        .{ "Matchmaking", "In queue" },
        .{ "ReadyCheck", "Match found" },
        .{ "InProgress", "In game" },
        .{ "WaitingForStats", "Post game" },
        .{ "PreEndOfGame", "Post game" },
        .{ "EndOfGame", "Post game" },
        .{ "Reconnect", "Reconnect" },
    };
    for (names) |n| if (std.mem.eql(u8, phase, n[0])) return n[1];
    return "Client open";
}
