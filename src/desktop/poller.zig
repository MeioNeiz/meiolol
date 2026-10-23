//! The desktop window's data, shared by every window backend (desktop_main.zig on
//! Windows, desktop_dev.zig elsewhere): stats and curves loaded once, and a poller thread
//! that reads the League client once a second and publishes what to show; the UI thread
//! only draws it. Read-only GETs, as `meiolol-app watch`. An update thread keeps the
//! data and the exe current from meio.lol (update.zig); new data is swapped in by the
//! poller between ticks.

const std = @import("std");
const core = @import("core");
const lcu = @import("../lcu/root.zig");
const lanecard = @import("../lanecard.zig");
const board = @import("../board.zig");
const Icons = @import("icons.zig").Icons;
const icons_path = @import("icons.zig").lcu_path;
const datafiles = @import("../datafiles.zig");
const ui = @import("ui.zig");
const update = @import("update.zig");

/// What the UI shows. The poller swaps `status` and the arena that owns it under the
/// mutex; the UI holds the mutex for a whole frame
const Shared = struct {
    mutex: std.Io.Mutex = .init,
    status: ui.Status = .no_client,
    arena: ?std.heap.ArenaAllocator = null,
    quit: std.atomic.Value(bool) = .init(false),
    /// Under the mutex: the UI reads it, the poller swaps it
    data: ?*Data = null,
    /// Set by the update thread when new files are on disk; the poller loads them
    fresh: std.atomic.Value(bool) = .init(false),
    /// The update thread's note for the footer, under the mutex
    note: Note = .none,
    /// Grows as the poller fetches icons from the client, under the mutex
    icons: ?Icons = null,
};

/// Stats and curves with the memory they live in
const Data = struct {
    arena: std.heap.ArenaAllocator,
    stats: core.Stats,
    curves: ?core.curvesfile.Curves,
};

pub const Note = union(enum) {
    none,
    /// First start with update.key: fetching the data
    downloading,
    /// Error name of the last failed check, while there is no data
    failed: [32]u8,
    /// A new exe is in place
    restart,
};

/// Between checks; after a failure, sooner
const update_every: std.Io.Duration = .fromSeconds(3 * 3600);
const retry_after: std.Io.Duration = .fromSeconds(5 * 60);

var shared: Shared = .{};
var io: std.Io = undefined;
/// Null finds the client (lockfile.discover); the dev window passes MEIOLOL_LOCKFILE
var lockfile: ?[]const u8 = null;
/// Wakes the UI thread after a publish
var wake: *const fn () void = undefined;
/// This exe's release (update.Options.version)
var version: u64 = 0;
var edition: ui.Edition = .private;

pub fn start(init: std.process.Init, lockfile_override: ?[]const u8, wake_ui: *const fn () void, release: u64, ed: ui.Edition) !void {
    io = init.io;
    version = release;
    edition = ed;
    shared.icons = .{ .gpa = init.gpa };
    lockfile = lockfile_override;
    wake = wake_ui;
    const gpa = init.gpa;
    shared.data = load(gpa);
    if (shared.data == null) shared.status = .no_data;
    // Detached, both: a request to a hung client or server cannot be interrupted (no
    // network timeouts in Threaded IO), so quitting must not wait for them
    if (updateOptions(init)) |o| {
        if (shared.data == null) shared.note = .downloading;
        (try std.Thread.spawn(.{}, updateLoop, .{o})).detach();
    }
    (try std.Thread.spawn(.{}, poll, .{gpa})).detach();
}

/// The newest stats and curves files (datafiles.zig); null without stats
fn load(gpa: std.mem.Allocator) ?*Data {
    const data = gpa.create(Data) catch return null;
    data.arena = .init(gpa);
    if (loadInto(data)) return data else |err| std.log.err("loading data: {t}", .{err});
    data.arena.deinit();
    gpa.destroy(data);
    return null;
}

fn loadInto(data: *Data) !void {
    const arena = data.arena.allocator();
    const cwd = std.Io.Dir.cwd();
    const limit: std.Io.Limit = .limited(1 << 30);
    const stats_path = try datafiles.stats(arena, io) orelse return error.NoStatsFile;
    data.stats = try core.Stats.parse(arena, try cwd.readFileAlloc(io, stats_path, arena, limit));
    data.curves = null;
    // Without curves the card still lists options, without lane gold
    if (try datafiles.curves(arena, io)) |p| {
        data.curves = core.curvesfile.Curves.parse(arena, try cwd.readFileAlloc(io, p, arena, limit)) catch |err| blk: {
            std.log.err("{s}: {t}", .{ p, err });
            break :blk null;
        };
    }
}

fn freeData(gpa: std.mem.Allocator, data: *Data) void {
    data.arena.deinit();
    gpa.destroy(data);
}

/// Updates need update.key beside the exe; MEIOLOL_UPDATE_URL points them elsewhere
fn updateOptions(init: std.process.Init) ?update.Options {
    const arena = init.arena.allocator();
    const exe_path = std.process.executablePathAlloc(io, arena) catch return null;
    const dir_path = std.fs.path.dirname(exe_path) orelse return null;
    const dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch return null;
    const key = update.readKey(arena, io, dir) orelse {
        dir.close(io);
        return null;
    };
    return .{
        .gpa = init.gpa,
        .io = io,
        .dir = dir,
        .exe = std.fs.path.basename(exe_path),
        .base = init.environ_map.get("MEIOLOL_UPDATE_URL") orelse update.default_base,
        .key = key,
        .version = version,
    };
}

fn updateLoop(o: update.Options) void {
    while (!shared.quit.load(.acquire)) {
        var wait = update_every;
        if (update.run(o)) |r| {
            if (r.data) shared.fresh.store(true, .release);
            if (r.exe) setNote(.restart);
        } else |err| {
            std.log.warn("update: {t}", .{err});
            wait = retry_after;
            var name: [32]u8 = @splat(0);
            const e = @errorName(err);
            @memcpy(name[0..@min(e.len, name.len)], e[0..@min(e.len, name.len)]);
            setNote(.{ .failed = name });
        }
        std.Io.sleep(io, wait, .awake) catch {};
    }
}

/// A failure never hides the restart note
fn setNote(note: Note) void {
    shared.mutex.lockUncancelable(io);
    if (note != .failed or shared.note != .restart) shared.note = note;
    shared.mutex.unlock(io);
    wake();
}

pub fn stop() void {
    shared.quit.store(true, .release);
}

/// Draws the current status: call between dvui's begin and end
pub fn frame() void {
    shared.mutex.lockUncancelable(io);
    defer shared.mutex.unlock(io);
    const stats = if (shared.data) |d| &d.stats else null;
    const note: ui.Note = switch (shared.note) {
        .none => .none,
        .downloading => .downloading,
        // Only matters while there is nothing else to show
        .failed => |*e| if (stats == null) .{ .failed = std.mem.sliceTo(e, 0) } else .none,
        .restart => .restart,
    };
    ui.frame(.{ .status = shared.status, .stats = stats, .icons = &shared.icons.?, .edition = edition, .note = note });
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
        // The UI may still draw a card made from the old data until the publish below
        // replaces it, so the old data goes only after that
        var old: ?*Data = null;
        if (shared.fresh.swap(false, .acq_rel)) {
            if (load(gpa)) |new| {
                shared.mutex.lockUncancelable(io);
                old = shared.data;
                shared.data = new;
                if (shared.note == .downloading or shared.note == .failed) shared.note = .none;
                shared.mutex.unlock(io);
                shown = 0;
            }
        }
        var arena: std.heap.ArenaAllocator = .init(gpa);
        const status = if (shared.data) |d| p.tick(arena.allocator(), d) catch |err| switch (err) {
            error.OutOfMemory => return,
            else => p.disconnect(arena.allocator(), err),
        } else ui.Status.no_data;
        const key = p.key(status);
        if (key != shown) {
            shown = key;
            publish(status, arena);
        } else arena.deinit();
        if (old) |d| freeData(gpa, d);
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
            .select => h.update(std.mem.asBytes(&p.fingerprint)),
            else => {},
        }
        return h.final();
    }

    fn tick(p: *Poller, arena: std.mem.Allocator, data: *const Data) !ui.Status {
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
        const by_mastery = ui.by_mastery.load(.acquire);
        var h: std.hash.Wyhash = .init(cs.fingerprint());
        h.update(std.mem.asBytes(&role));
        h.update(std.mem.asBytes(&by_mastery));
        if (pool) |ids| h.update(std.mem.sliceAsBytes(ids));
        p.fingerprint = h.final();

        const sel = try arena.create(ui.Select);
        sel.card = try lanecard.build(arena, .{
            .stats = &data.stats,
            .curves = if (data.curves) |*c| c else null,
            .role = role,
            .me = cs.my_champion,
            .locked = cs.my_locked,
            .allies = cs.allies,
            .enemies = cs.enemies,
            .bans = cs.bans,
            .pickable = pool,
            .mastery = own.mastery,
            .tier = own.tier,
            .expertise = if (by_mastery) .fitted else null,
        });
        sel.board = try board.build(arena, &data.stats, .{}, cs, &sel.card);
        p.fetchIcons(sel);
        return .{ .select = sel };
    }

    /// Icons for every champion the select shows, from the client. Fetched outside the
    /// mutex, added under it; a new icon changes the fingerprint so the window redraws
    fn fetchIcons(p: *Poller, sel: *const ui.Select) void {
        const client = p.watch.client orelse return;
        var want: [64]u32 = undefined;
        var n: usize = 0;
        const add = struct {
            fn f(list: *[64]u32, len: *usize, c: u32) void {
                if (c == 0 or len.* == list.len) return;
                if (std.mem.indexOfScalar(u32, list[0..len.*], c) != null) return;
                list[len.*] = c;
                len.* += 1;
            }
        }.f;
        for ([_][]const board.Seat{ sel.board.allies, sel.board.enemies }) |seats| for (seats) |s| {
            add(&want, &n, s.slot.champion);
            for (s.ideas) |c| add(&want, &n, c);
        };
        for (sel.board.my_bans) |c| add(&want, &n, c);
        for (sel.board.their_bans) |c| add(&want, &n, c);
        for (sel.board.ban_options) |o| add(&want, &n, o.champion);
        for (sel.card.options) |o| add(&want, &n, o.champion);
        if (sel.card.opponent) |o| add(&want, &n, o.champion);
        add(&want, &n, sel.card.me);

        var got: u32 = 0;
        for (want[0..n]) |c| {
            shared.mutex.lockUncancelable(io);
            const wanted = shared.icons.?.wanted(c);
            shared.mutex.unlock(io);
            if (!wanted) continue;
            var buf: [96]u8 = undefined;
            const path = std.fmt.bufPrint(&buf, icons_path, .{c}) catch continue;
            const png: ?[]const u8 = client.getOk(path) catch null;
            shared.mutex.lockUncancelable(io);
            shared.icons.?.put(c, png) catch {};
            shared.mutex.unlock(io);
            got += 1;
        }
        if (got > 0) p.fingerprint +%= got;
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
