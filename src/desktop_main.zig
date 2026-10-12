//! `meiolol-desktop`: the lane card in a window (dvui, Direct3D 11). A poller thread
//! reads the League client once a second and publishes what to show; the UI thread
//! only draws it. Read-only GETs, as `meiolol-app watch`.

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const lcu = @import("lcu/root.zig");
const lanecard = @import("lanecard.zig");
const datafiles = @import("datafiles.zig");
const ui = @import("desktop/ui.zig");

pub const dvui_app: dvui.App = .{
    .config = .{ .options = .{
        .size = ui.size,
        .min_size = .{ .w = 360, .h = 400 },
        .title = ui.title,
        .window_init_options = .{ .theme = ui.theme },
    } },
    .initFn = start,
    .deinitFn = stop,
    .frameFn = frame,
};
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
// The poller retries every second; Debug builds would print a stack trace for each
// error.Unexpected from the network layer
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn, .unexpected_error_tracing = false };

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

fn start(win: *dvui.Window) !void {
    const init = dvui.App.main_init orelse return error.NoProcessInit;
    io = init.io;
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
    const thread = try std.Thread.spawn(.{}, poll, .{ win, gpa });
    thread.detach();
}

fn stop(_: *dvui.Window) void {
    shared.quit.store(true, .release);
}

fn frame() !dvui.App.Result {
    shared.mutex.lockUncancelable(io);
    defer shared.mutex.unlock(io);
    ui.frame(.{ .status = shared.status, .stats = if (stats) |*s| s else null });
    return .ok;
}

fn publish(win: *dvui.Window, status: ui.Status, arena: std.heap.ArenaAllocator) void {
    shared.mutex.lockUncancelable(io);
    const old = shared.arena;
    shared.status = status;
    shared.arena = arena;
    shared.mutex.unlock(io);
    if (old) |o| o.deinit();
    dvui.refresh(win, @src(), null);
}

fn poll(win: *dvui.Window, gpa: std.mem.Allocator) void {
    var p: Poller = .{ .gpa = gpa, .own_arena = .init(gpa) };
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
            publish(win, status, arena);
        } else arena.deinit();
        std.Io.sleep(io, .fromSeconds(1), .awake) catch {};
    }
}

/// The client connection and the player's own data, kept across ticks
const Poller = struct {
    gpa: std.mem.Allocator,
    /// Holds the credentials; reset on reconnect
    conn: ?std.heap.ArenaAllocator = null,
    client: ?lcu.Client = null,
    /// Pool, mastery and tier: loaded once per champ select
    own_arena: std.heap.ArenaAllocator,
    own: ?Own = null,
    /// What the last tick saw, for key()
    fingerprint: u64 = 0,

    const Own = struct {
        pickable: ?[]u32,
        mastery: []lanecard.Mastery,
        tier: ?[]const u8,
    };

    fn deinit(p: *Poller) void {
        if (p.conn) |*c| c.deinit();
        p.own_arena.deinit();
    }

    fn forgetOwn(p: *Poller) void {
        _ = p.own_arena.reset(.retain_capacity);
        p.own = null;
    }

    fn disconnect(p: *Poller, arena: std.mem.Allocator, err: anyerror) ui.Status {
        if (p.conn) |*c| c.deinit();
        p.conn = null;
        p.client = null;
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
        if (p.client == null) {
            p.conn = .init(p.gpa);
            const found = try lcu.lockfile.discover(p.conn.?.allocator(), io, null);
            p.client = .{ .gpa = p.gpa, .io = io, .credentials = found.credentials };
        }
        const client = p.client.?;

        const phase_body = try client.getOk(lcu.session.paths.phase);
        defer p.gpa.free(phase_body);
        const phase = lcu.session.parsePhase(arena, phase_body) catch "unknown";
        if (!std.mem.eql(u8, phase, "ChampSelect")) {
            p.forgetOwn();
            return .{ .waiting = phaseLabel(phase) };
        }

        const resp = try client.get(lcu.session.paths.session);
        defer p.gpa.free(resp.body);
        // Between phases the session can briefly be missing
        if (resp.status == 404) return .{ .waiting = "Champ select" };
        if (resp.status / 100 != 2) return error.HttpStatus;
        const cs = try lcu.session.parse(arena, resp.body);
        const role = cs.my_role orelse return .no_role;

        if (p.own == null) p.own = p.loadOwn(client);
        const own = p.own.?;
        var h: std.hash.Wyhash = .init(cs.fingerprint());
        h.update(std.mem.asBytes(&role));
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
            .pickable = own.pickable,
            .mastery = own.mastery,
            .tier = own.tier,
        });
        return .{ .card = card };
    }

    /// Whatever fails to load is left out: the card works without it
    fn loadOwn(p: *Poller, client: lcu.Client) Own {
        const a = p.own_arena.allocator();
        const pickable = ids(a, client, lcu.session.paths.pickable, false);
        const owned = ids(a, client, lcu.session.paths.owned, true);
        var own: Own = .{
            .pickable = lcu.session.intersectPool(a, pickable, owned) catch null,
            .mastery = &.{},
            .tier = null,
        };
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

    fn ids(a: std.mem.Allocator, client: lcu.Client, path: []const u8, objects: bool) ?[]u32 {
        const body = client.getOk(path) catch return null;
        defer client.gpa.free(body);
        const list = (if (objects) lcu.session.parseOwned(a, body) else lcu.session.parseIds(a, body)) catch return null;
        return if (list.len == 0) null else list;
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
