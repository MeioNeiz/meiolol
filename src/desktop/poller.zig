//! The desktop window's data, shared by every window backend (desktop_main.zig on
//! Windows, desktop_dev.zig elsewhere): stats and curves loaded once, and a poller thread
//! that reads the League client once a second and publishes what to show; the UI thread
//! only draws it. Read-only GETs, as `meiolol-app watch`. An update thread keeps the
//! data and the exe current from meio.lol (update.zig), once the app is signed in
//! (device.zig, the window's form: signin.zig); new data is swapped in by the
//! poller between ticks. Practice (practice.zig) is built here too, from the window's
//! setup, whenever the client is not in champ select or a game.

const std = @import("std");
const core = @import("core");
const lcu = @import("../lcu/root.zig");
const lanecard = @import("../lanecard.zig");
const board = @import("../board.zig");
const ingame = @import("../ingame.zig");
const postgame = @import("../postgame.zig");
const loading = @import("../loading.zig");
const practice = @import("../practice.zig");
const comp = @import("../comp.zig");
const Icons = @import("icons.zig").Icons;
const icons_path = @import("icons.zig").lcu_path;
const datafiles = @import("../datafiles.zig");
const state = @import("state.zig");
const update = @import("update.zig");
const device = @import("device.zig");

/// What the UI shows. The poller swaps `status` and the arena that owns it under the
/// mutex; the UI holds the mutex for a whole frame
const Shared = struct {
    mutex: std.Io.Mutex = .init,
    status: state.Status = .no_client,
    arena: ?std.heap.ArenaAllocator = null,
    quit: std.atomic.Value(bool) = .init(false),
    /// Under the mutex: the UI reads it, the poller swaps it
    data: ?*Data = null,
    /// Set by the update thread when new files are on disk; the poller loads them
    fresh: std.atomic.Value(bool) = .init(false),
    /// The update thread's note under the board, under the mutex
    note: state.Note = .none,
    /// Grows as the poller fetches icons from the client, under the mutex
    icons: ?Icons = null,
    /// The window's practice draft, under the mutex; null while practice is off
    practice: ?practice.Setup = null,
    /// Bumped by the window on each practice change; the poller waits on it
    practice_gen: std.atomic.Value(u32) = .init(0),
    /// `status` is the practice draft's, under the mutex
    practicing: bool = false,
    /// The sign-in form's, under the mutex
    signin: state.SignIn = .{},
    /// What update checks send, under the mutex; null until signed in. In auth_buf
    auth: ?update.Auth = null,
    auth_buf: [512]u8 = undefined,
    /// signin.message's when it isn't static
    signin_buf: [256]u8 = undefined,
    /// Bumped by each sign in; the update thread waits on it
    auth_gen: std.atomic.Value(u32) = .init(0),
};

/// Stats, curves and champion facts with the memory they live in
pub const Data = struct {
    arena: std.heap.ArenaAllocator,
    stats: core.Stats,
    curves: ?core.curvesfile.Curves,
    facts: ?core.champfacts.Facts,
};

/// Between checks; after a failure, sooner
const update_every_s = 3 * 3600;

/// Seconds to the next check after `fails` failed ones in a row: 5 minutes, doubling,
/// at most the usual wait
fn retryAfter(fails: u32) u32 {
    return @min(@as(u32, 5 * 60) << @intCast(@min(fails -| 1, 6)), update_every_s);
}

var shared: Shared = .{};
var io: std.Io = undefined;
/// Null finds the client (lockfile.discover); the dev window passes MEIOLOL_LOCKFILE
var lockfile: ?[]const u8 = null;
/// Wakes the UI thread after a publish
var wake: *const fn () void = undefined;
/// This exe's release (update.Options.version)
var version: u64 = 0;
var edition: state.Edition = .private;
var update_exe = true;

pub const Options = struct {
    /// Null finds the client (lockfile.discover)
    lockfile: ?[]const u8 = null,
    /// From the poller thread after each publish
    wake: *const fn () void,
    /// This exe's release (update.Options.version)
    release: u64,
    edition: state.Edition,
    /// Updates may replace the running exe. The webview shell says no until it takes
    /// over meiolol-desktop.exe's name
    update_exe: bool = true,
};

pub fn start(init: std.process.Init, opt: Options) !void {
    io = init.io;
    version = opt.release;
    edition = opt.edition;
    update_exe = opt.update_exe;
    shared.icons = .{ .gpa = init.gpa };
    lockfile = opt.lockfile;
    wake = opt.wake;
    const gpa = init.gpa;
    shared.data = load(gpa);
    if (shared.data == null) shared.status = .no_data;
    // Detached, both: a check can download for many minutes (net.client's limit scales
    // with the file), so quitting must not wait for them
    if (updateOptions(init)) |o| {
        updates = o;
        auth_url = init.environ_map.get("MEIOLOL_AUTH_URL") orelse device.default_url;
        if (update.Auth.find(init.arena.allocator(), io, o.dir)) |a| {
            setAuth(a);
            if (shared.data == null) shared.note = .downloading;
        } else shared.signin.needed = true;
        (try std.Thread.spawn(.{}, updateLoop, .{o})).detach();
    }
    (try std.Thread.spawn(.{}, poll, .{gpa})).detach();
}

/// The newest stats and curves files (datafiles.zig); null without stats
fn load(gpa: std.mem.Allocator) ?*Data {
    const data = gpa.create(Data) catch return null;
    data.arena = .init(gpa);
    if (loadInto(data)) return data else |err| std.log.err("loading data: {t}", .{err});
    freeData(gpa, data);
    return null;
}

fn loadInto(data: *Data) !void {
    const arena = data.arena.allocator();
    try fill(data, .{
        .stats = try datafiles.stats(arena, io) orelse return error.NoStatsFile,
        .curves = try datafiles.curves(arena, io),
        .facts = try datafiles.facts(arena, io),
    });
}

pub const Paths = struct { stats: []const u8, curves: ?[]const u8, facts: ?[]const u8 };

/// Named files rather than the newest beside the app, for Replay
pub fn loadPaths(gpa: std.mem.Allocator, io_: std.Io, paths: Paths) !*Data {
    io = io_;
    const data = try gpa.create(Data);
    data.arena = .init(gpa);
    errdefer freeData(gpa, data);
    try fill(data, paths);
    return data;
}

fn fill(data: *Data, paths: Paths) !void {
    const arena = data.arena.allocator();
    const cwd = std.Io.Dir.cwd();
    const limit: std.Io.Limit = .limited(1 << 30);
    data.stats = try core.Stats.parse(arena, try cwd.readFileAlloc(io, paths.stats, arena, limit));
    data.curves = null;
    // Without curves the card still lists options, without lane gold. Viewed in place, not
    // parsed (a copy): the file is ~100 MB. Not mapped: the update renames a new file
    // over it, which Windows may refuse while mapped (untested)
    if (paths.curves) |p| {
        const file_align: std.mem.Alignment = comptime .fromByteUnits(core.curvesfile.file_align);
        const bytes = try cwd.readFileAllocOptions(io, p, arena, limit, file_align, null);
        data.curves = core.curvesfile.Curves.view(arena, bytes) catch |err| blk: {
            std.log.err("{s}: {t}", .{ p, err });
            break :blk null;
        };
    }
    // Without facts the comp view has the lanes alone
    data.facts = null;
    if (paths.facts) |p| {
        data.facts = core.champfacts.Facts.parse(arena, try cwd.readFileAlloc(io, p, arena, .limited(1 << 22))) catch |err| blk: {
            std.log.err("{s}: {t}", .{ p, err });
            break :blk null;
        };
    }
}

pub fn freeData(gpa: std.mem.Allocator, data: *Data) void {
    data.arena.deinit();
    gpa.destroy(data);
}

/// Updates in the exe's folder, with its sign in or update.key (Options.auth is set per
/// check); MEIOLOL_UPDATE_URL points them elsewhere
fn updateOptions(init: std.process.Init) ?update.Options {
    const arena = init.arena.allocator();
    const exe_path = std.process.executablePathAlloc(io, arena) catch return null;
    const dir_path = std.fs.path.dirname(exe_path) orelse return null;
    const dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch return null;
    return .{
        .gpa = init.gpa,
        .io = io,
        .dir = dir,
        .exe = if (update_exe) std.fs.path.basename(exe_path) else null,
        .base = init.environ_map.get("MEIOLOL_UPDATE_URL") orelse update.default_base,
        .auth = undefined,
        .version = version,
    };
}

/// Set when updates can run at all: the exe's folder, for the sign in too
var updates: ?update.Options = null;
/// POST /auth/device; MEIOLOL_AUTH_URL points it elsewhere
var auth_url: []const u8 = device.default_url;

/// Without a sign in it waits for one
fn updateLoop(base: update.Options) void {
    var buf: [512]u8 = undefined;
    var fails: u32 = 0;
    var last_gen = shared.auth_gen.load(.acquire);
    while (!shared.quit.load(.acquire)) {
        const gen = shared.auth_gen.load(.acquire);
        // A new sign in starts the backoff again
        if (gen != last_gen) fails = 0;
        last_gen = gen;
        shared.mutex.lockUncancelable(io);
        const auth = if (shared.auth) |a| copyAuth(&buf, a) else null;
        shared.mutex.unlock(io);
        var wait_s: u32 = update_every_s;
        if (auth) |a| {
            var o = base;
            o.auth = a;
            if (update.run(o)) |r| {
                fails = 0;
                clearFailure();
                if (r.data) shared.fresh.store(true, .release);
                if (r.exe) setNote(.restart);
            } else |err| {
                fails +|= 1;
                wait_s = retryAfter(fails);
                std.log.warn("update: {t} ({s}), check {d} in a row, next in {d} min", .{ err, o.base, fails, wait_s / 60 });
                switch (err) {
                    error.Unauthorized, error.Forbidden => signedOut(a, err == error.Forbidden),
                    error.Moved => setNote(.moved),
                    else => setNote(.{ .failed = .{ .why = update.why(err), .minutes = wait_s / 60 } }),
                }
            }
        }
        // A sign in ends the wait
        const wait: std.Io.Duration = .fromSeconds(wait_s);
        io.futexWaitTimeout(u32, &shared.auth_gen.raw, gen, .{ .duration = .{ .raw = wait, .clock = .awake } }) catch {};
    }
}

/// `a` with its bytes in `buf`; null when they don't fit
fn copyAuth(buf: []u8, a: update.Auth) ?update.Auth {
    switch (a) {
        inline else => |bytes, tag| {
            if (bytes.len > buf.len) return null;
            @memcpy(buf[0..bytes.len], bytes);
            return @unionInit(update.Auth, @tagName(tag), buf[0..bytes.len]);
        },
    }
}

/// Under the mutex, or before the threads start
fn setAuth(a: update.Auth) void {
    shared.auth = copyAuth(&shared.auth_buf, a);
}

/// The server refused the sign in (removed on the account page, logged out everywhere, a
/// new password, the role lowered) or, after the cut-over, the shared key: the form comes
/// back. No sign in can be on its way meanwhile: the form only shows without a working one
fn signedOut(was: update.Auth, forbidden: bool) void {
    if (was == .device) device.forget(io, updates.?.dir);
    shared.mutex.lockUncancelable(io);
    shared.auth = null;
    shared.signin.needed = true;
    shared.signin.message = if (forbidden)
        "This account no longer gets the app: sign in with another."
    else if (was == .device)
        "Signed out: this app was removed from your account, or you logged out everywhere."
    else
        "";
    shared.mutex.unlock(io);
    wake();
}

const Credentials = struct {
    username: [64]u8 = undefined,
    username_len: usize = 0,
    password: [256]u8 = undefined,
    password_len: usize = 0,
};

/// From the window, holding the mutex: the request runs on a thread of its own
fn submit(username: []const u8, password: []const u8) void {
    const o = updates orelse return;
    if (shared.signin.busy or username.len > 64 or password.len > 256) return;
    const c = o.gpa.create(Credentials) catch return;
    c.* = .{ .username_len = username.len, .password_len = password.len };
    @memcpy(c.username[0..username.len], username);
    @memcpy(c.password[0..password.len], password);
    shared.signin.busy = true;
    shared.signin.message = "";
    const t = std.Thread.spawn(.{}, signInThread, .{c}) catch {
        std.crypto.secureZero(u8, &c.password);
        o.gpa.destroy(c);
        shared.signin.busy = false;
        shared.signin.message = "Couldn't start the sign in.";
        return;
    };
    t.detach();
}

fn signInThread(c: *Credentials) void {
    const o = updates.?;
    defer {
        std.crypto.secureZero(u8, &c.password);
        o.gpa.destroy(c);
    }
    var arena_state: std.heap.ArenaAllocator = .init(o.gpa);
    defer arena_state.deinit();
    const answer = device.signIn(arena_state.allocator(), o.gpa, io, o.dir, auth_url, c.username[0..c.username_len], c.password[0..c.password_len]);
    var signed_in = false;
    shared.mutex.lockUncancelable(io);
    shared.signin.busy = false;
    if (answer) |a| switch (a) {
        .token => |t| {
            setAuth(.{ .device = t });
            shared.signin.needed = false;
            shared.signin.message = "";
            if (shared.data == null) shared.note = .downloading;
            signed_in = true;
        },
        .refused => |m| shared.signin.message = std.fmt.bufPrint(&shared.signin_buf, "{s}", .{m}) catch "Refused.",
    } else |err| {
        std.log.warn("sign in: {t}", .{err});
        shared.signin.message = std.fmt.bufPrint(&shared.signin_buf, "Couldn't reach meio.lol ({t}); try again in a moment.", .{err}) catch "Couldn't reach meio.lol.";
    }
    shared.mutex.unlock(io);
    if (signed_in) {
        // This install's own sign in replaces the shared key
        o.dir.deleteFile(io, update.key_file) catch {};
        _ = shared.auth_gen.fetchAdd(1, .release);
        io.futexWake(u32, &shared.auth_gen.raw, 1);
    }
    wake();
}

/// A failure never hides the restart note
fn setNote(note: state.Note) void {
    shared.mutex.lockUncancelable(io);
    const failure = note == .failed or note == .moved;
    if (!failure or shared.note != .restart) shared.note = note;
    shared.mutex.unlock(io);
    wake();
}

/// A check went through: an earlier failure's note no longer holds
fn clearFailure() void {
    shared.mutex.lockUncancelable(io);
    const was = shared.note == .failed or shared.note == .moved;
    if (was) shared.note = .none;
    shared.mutex.unlock(io);
    if (was) wake();
}

pub fn stop() void {
    shared.quit.store(true, .release);
}

/// What to draw, valid until `unlock`: the window holds the poller's mutex for a frame
pub const Shown = struct {
    status: state.Status,
    stats: ?*const core.Stats,
    icons: *const Icons,
    edition: state.Edition,
    note: state.Note,
    /// Null where updates can't run (no exe folder)
    signin: ?*const state.SignIn,
    /// From the window, holding the mutex; copies what it keeps
    submit: *const fn (username: []const u8, password: []const u8) void = submit,
    /// The window's practice draft; null while practice is off
    practice: *?practice.Setup,
    /// `status` is the practice draft's, not the client's
    practicing: bool,
    /// The window changed `practice`
    practice_changed: *const fn () void = practiceChanged,
};

pub fn lock() Shown {
    shared.mutex.lockUncancelable(io);
    const stats = if (shared.data) |d| &d.stats else null;
    return .{
        .status = shared.status,
        .stats = stats,
        .icons = &shared.icons.?,
        .edition = edition,
        .note = switch (shared.note) {
            // Only matters while there is nothing else to show
            .failed => if (stats == null) shared.note else .none,
            .none, .downloading, .moved, .restart => shared.note,
        },
        .signin = if (updates != null) &shared.signin else null,
        .practice = &shared.practice,
        .practicing = shared.practicing,
    };
}

pub fn unlock() void {
    shared.mutex.unlock(io);
}

/// From the window, holding the mutex (it draws with it held)
fn practiceChanged() void {
    _ = shared.practice_gen.fetchAdd(1, .release);
    io.futexWake(u32, &shared.practice_gen.raw, 1);
}

fn publish(status: state.Status, arena: std.heap.ArenaAllocator, practicing: bool) void {
    shared.mutex.lockUncancelable(io);
    const old = shared.arena;
    shared.status = status;
    shared.arena = arena;
    shared.practicing = practicing;
    shared.mutex.unlock(io);
    if (old) |o| o.deinit();
    wake();
}

fn poll(gpa: std.mem.Allocator) void {
    var p: Poller = .{ .watch = .init(gpa, io, lockfile), .own_arena = .init(gpa), .seats_arena = .init(gpa), .practice_arena = .init(gpa) };
    defer p.deinit();
    var shown: u64 = 0;
    var seen_gen: u32 = 0;
    // The client is in champ select or a game: that shows, practice waits
    var live = false;
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
        const gen = shared.practice_gen.load(.acquire);
        shared.mutex.lockUncancelable(io);
        const setup = shared.practice;
        shared.mutex.unlock(io);
        // A practice change alone needs no round trip to the client
        const practice_only = state.private_code and gen != seen_gen and setup != null and shared.data != null;
        seen_gen = gen;
        var status: ?state.Status = null;
        if (!practice_only) {
            const s = if (shared.data) |d| p.tick(arena.allocator(), d) catch |err| switch (err) {
                error.OutOfMemory => return,
                else => p.disconnect(err),
            } else state.Status.no_data;
            live = switch (s) {
                .select, .loading, .in_game, .post_game => true,
                else => false,
            };
            status = s;
        }
        var practicing = false;
        if (state.private_code and setup != null and !live) if (shared.data) |d| {
            if (p.practiceStatus(arena.allocator(), d, setup.?, gen)) |s| {
                status = s;
                practicing = true;
            } else |err| switch (err) {
                error.OutOfMemory => return,
                else => std.log.err("practice: {t}", .{err}),
            }
        };
        if (status) |s| {
            const key = p.key(s, practicing);
            if (key != shown) {
                shown = key;
                publish(s, arena, practicing);
            } else arena.deinit();
        } else arena.deinit();
        if (old) |d| freeData(gpa, d);
        io.futexWaitTimeout(u32, &shared.practice_gen.raw, gen, .{ .duration = .{ .raw = .fromSeconds(1), .clock = .awake } }) catch {};
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
    /// This game's team gold so far; a new game starts it again
    history: std.ArrayList(ingame.Sample) = .empty,
    /// The last champ select's seats and draft, for the loading screen
    seats_arena: std.heap.ArenaAllocator,
    seats: ?[2][]const loading.Seat = null,
    draft: ?board.Draft = null,
    /// Positions the last in-game tick saw, for the post game
    hints: [10]postgame.Hint = undefined,
    n_hints: usize = 0,
    /// Mastery and tier for practice, loaded once per client connection
    practice_arena: std.heap.ArenaAllocator,
    practice_own: ?Own = null,
    /// Live Client Data's; Replay's mock serves it on a free one
    live_port: u16 = lcu.live.port,

    const Own = struct {
        mastery: []lanecard.Mastery,
        tier: ?[]const u8,
    };

    fn deinit(p: *Poller) void {
        p.history.deinit(p.own_arena.child_allocator);
        p.seats_arena.deinit();
        p.practice_arena.deinit();
        p.watch.deinit();
        p.own_arena.deinit();
    }

    fn forgetOwn(p: *Poller) void {
        _ = p.own_arena.reset(.retain_capacity);
        p.own = null;
    }

    fn disconnect(p: *Poller, err: anyerror) state.Status {
        p.watch.disconnect();
        p.forgetOwn();
        _ = p.practice_arena.reset(.retain_capacity);
        p.practice_own = null;
        return switch (err) {
            error.ClientNotRunning => .no_client,
            else => .{ .client_error = @errorName(err) },
        };
    }

    /// Changes whenever what the status shows would
    fn key(p: *const Poller, s: state.Status, practicing: bool) u64 {
        var h: std.hash.Wyhash = .init(0);
        h.update(@tagName(s));
        h.update(&.{@intFromBool(practicing)});
        switch (s) {
            .waiting => |phase| h.update(phase),
            .client_error => |e| h.update(e),
            .select, .loading, .in_game, .post_game => h.update(std.mem.asBytes(&p.fingerprint)),
            else => {},
        }
        return h.final();
    }

    fn tick(p: *Poller, arena: std.mem.Allocator, data: *const Data) !state.Status {
        const step = try p.watch.step(arena);
        if (step != .select) state.lane_role.store(state.own_lane, .release);
        const cs = switch (step) {
            .phase => |phase| {
                // Live Client Data is up once the game has loaded; until then, waiting
                // After it, the client's end of game block; the game's history stays
                if (std.mem.eql(u8, phase, "InProgress")) {
                    if (p.inGame(arena, data)) |g| return .{ .in_game = g } else |err| switch (err) {
                        error.OutOfMemory => return err,
                        else => {},
                    }
                } else if (std.mem.eql(u8, phase, "PreEndOfGame") or std.mem.eql(u8, phase, "EndOfGame")) {
                    if (p.postGame(arena, data)) |pg| return .{ .post_game = pg } else |err| switch (err) {
                        error.OutOfMemory => return err,
                        else => {},
                    }
                } else if (std.mem.eql(u8, phase, "GameStart")) {
                    if (p.seats) |seats| {
                        const l = try arena.create(loading.Loading);
                        l.* = try loading.build(arena, .{
                            .stats = &data.stats,
                            .curves = if (data.curves) |*c| c else null,
                            .facts = if (data.facts) |*f| f else null,
                            .seats = seats,
                            .draft = p.draft,
                            .tier = if (p.own) |o| o.tier else null,
                        });
                        return .{ .loading = l };
                    }
                } else if (!std.mem.eql(u8, phase, "WaitingForStats")) p.forgetOwn();
                return .{ .waiting = phaseLabel(phase) };
            },
            .between => return .{ .waiting = "Champ select" },
            .bad_session => |err| return .{ .client_error = @errorName(err) },
            .select => |cs| cs,
        };
        const role = cs.my_role orelse return .no_role;

        if (p.own == null) p.own = loadOwn(p.own_arena.allocator(), p.watch.client.?);
        const own = p.own.?;
        const pool = p.watch.pool;
        const by_mastery = state.by_mastery.load(.acquire);
        const shown = state.lane_role.load(.acquire);
        var h: std.hash.Wyhash = .init(cs.fingerprint());
        h.update(std.mem.asBytes(&role));
        h.update(std.mem.asBytes(&by_mastery));
        h.update(&.{shown});
        if (pool) |ids| h.update(std.mem.sliceAsBytes(ids));
        p.fingerprint = h.final();

        const sel = try arena.create(state.Select);
        sel.ally = false;
        const mine: lanecard.Input = .{
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
        };
        sel.card = try lanecard.build(arena, mine);
        sel.board = try board.build(arena, &data.stats, .{}, cs, &sel.card, if (data.facts) |*f| f else null);
        if (shown < core.Role.count) if (try board.allyLane(arena, mine, cs, @fromBackingInt(@intCast(shown)))) |in| {
            sel.card = try lanecard.build(arena, in);
            sel.ally = true;
        };
        sel.comp = try comp.after(arena, .{
            .stats = &data.stats,
            .curves = if (data.curves) |*c| c else null,
            .facts = if (data.facts) |*f| f else null,
            .tier = own.tier,
        }, &sel.board);
        _ = p.seats_arena.reset(.retain_capacity);
        p.seats = try loading.seatsOf(p.seats_arena.allocator(), &sel.board);
        p.draft = sel.board.draft;
        var want: Want = .{};
        want.addSelect(sel);
        p.fetchIcons(want.list[0..want.n]);
        return .{ .select = sel };
    }

    /// The practice draft on its screen, built as a real one would be
    fn practiceStatus(p: *Poller, arena: std.mem.Allocator, data: *const Data, setup: practice.Setup, gen: u32) !state.Status {
        if (p.practice_own == null) if (p.watch.client) |c| {
            p.practice_own = loadOwn(p.practice_arena.allocator(), c);
        };
        const own: Own = p.practice_own orelse .{ .mastery = &.{}, .tier = null };
        const by_mastery = state.by_mastery.load(.acquire);
        const built = try practice.build(arena, .{
            .stats = &data.stats,
            .curves = if (data.curves) |*c| c else null,
            .facts = if (data.facts) |*f| f else null,
            .mastery = own.mastery,
            .tier = own.tier,
            .expertise = if (by_mastery) .fitted else null,
        }, setup);
        var h: std.hash.Wyhash = .init(3);
        h.update(std.mem.asBytes(&gen));
        h.update(std.mem.asBytes(&by_mastery));
        p.fingerprint = h.final();
        var want: Want = .{};
        for (setup.mine) |s| want.add(s.champion);
        for (setup.theirs) |s| want.add(s.champion);
        for (setup.my_bans ++ setup.their_bans) |c| want.add(c);
        const status: state.Status = switch (built) {
            .select => |s| blk: {
                const sel = try arena.create(state.Select);
                sel.* = .{ .card = s.card, .board = s.board, .comp = s.comp };
                want.addSelect(sel);
                break :blk .{ .select = sel };
            },
            .loading => |l| .{ .loading = try dupe(arena, l) },
            .in_game => |g| .{ .in_game = try dupe(arena, g) },
            .post_game => |pg| .{ .post_game = try dupe(arena, pg) },
        };
        p.fetchIcons(want.list[0..want.n]);
        return status;
    }

    /// The game's own server; the mock serves it in plain HTTP, as the client
    fn inGame(p: *Poller, arena: std.mem.Allocator, data: *const Data) !*const ingame.InGame {
        const client = p.watch.client.?;
        const live = lcu.live;
        const resp = if (client.credentials.plain)
            try lcu.https.getPlain(client.gpa, io, p.live_port, "", live.path)
        else
            try lcu.https.get(client.gpa, io, live.port, "", live.path);
        defer client.gpa.free(resp.body);
        if (resp.status / 100 != 2) return error.HttpStatus;
        const game = try live.parse(arena, resp.body);
        if (p.own == null) p.own = loadOwn(p.own_arena.allocator(), client);
        const g = try arena.create(ingame.InGame);
        g.* = try ingame.build(arena, &data.stats, if (data.curves) |*c| c else null, game, p.own.?.tier);
        p.fingerprint = std.hash.Wyhash.hash(1, resp.body);
        const gpa = p.own_arena.child_allocator;
        const last: ?ingame.Sample = if (p.history.items.len > 0) p.history.items[p.history.items.len - 1] else null;
        if (last != null and game.time < last.?.time) p.history.clearRetainingCapacity();
        if (last == null or p.history.items.len == 0 or game.time >= last.?.time + ingame.sample_every) {
            try p.history.append(gpa, g.sample());
        }
        g.history = try arena.dupe(ingame.Sample, p.history.items);
        p.n_hints = 0;
        for (g.rows) |r| for ([_]?ingame.Seat{ r.ours, r.theirs }, [_]bool{ true, false }) |s, ours| if (s) |seat| {
            p.hints[p.n_hints] = .{ .champion = seat.champion, .role = r.role, .ours = ours };
            p.n_hints += 1;
        };
        var want: Want = .{};
        for (g.rows) |r| for ([_]?ingame.Seat{ r.ours, r.theirs }) |s| if (s) |seat| want.add(seat.champion);
        p.fetchIcons(want.list[0..want.n]);
        return g;
    }

    fn dupe(arena: std.mem.Allocator, v: anytype) !*const @TypeOf(v) {
        const out = try arena.create(@TypeOf(v));
        out.* = v;
        return out;
    }

    fn postGame(p: *Poller, arena: std.mem.Allocator, data: *const Data) !*const postgame.PostGame {
        const client = p.watch.client.?;
        const body = try client.getOk(lcu.eog.path);
        defer client.gpa.free(body);
        const e = try lcu.eog.parse(arena, body);
        if (e.players.len == 0) return error.NoPlayers;
        if (p.own == null) p.own = loadOwn(p.own_arena.allocator(), client);
        const pg = try arena.create(postgame.PostGame);
        pg.* = try postgame.build(arena, .{
            .stats = &data.stats,
            .curves = if (data.curves) |*c| c else null,
            .eog = e,
            .history = try arena.dupe(ingame.Sample, p.history.items),
            .hints = p.hints[0..p.n_hints],
            .tier = p.own.?.tier,
        });
        p.fingerprint = std.hash.Wyhash.hash(2, body);
        var want: Want = .{};
        for (e.players) |pl| want.add(pl.champion);
        p.fetchIcons(want.list[0..want.n]);
        return pg;
    }

    /// Champions to fetch icons for, each once
    const Want = struct {
        list: [64]u32 = undefined,
        n: usize = 0,

        fn add(w: *Want, c: u32) void {
            if (c == 0 or w.n == w.list.len) return;
            if (std.mem.indexOfScalar(u32, w.list[0..w.n], c) != null) return;
            w.list[w.n] = c;
            w.n += 1;
        }

        fn addSelect(w: *Want, sel: *const state.Select) void {
            for ([_][]const board.Seat{ sel.board.allies, sel.board.enemies }) |seats| for (seats) |s| {
                w.add(s.slot.champion);
                for (s.ideas) |c| w.add(c);
            };
            for (sel.board.my_bans) |c| w.add(c);
            for (sel.board.their_bans) |c| w.add(c);
            for (sel.board.ban_options) |o| w.add(o.champion);
            for (sel.card.options) |o| w.add(o.champion);
            if (sel.card.opponent) |o| w.add(o.champion);
            w.add(sel.card.me);
        }
    };

    /// Icons from the client. Fetched outside the mutex, added under it; a new icon
    /// changes the fingerprint so the window redraws
    fn fetchIcons(p: *Poller, want: []const u32) void {
        const client = p.watch.client orelse return;
        // Replay: no store, the review pages use the site's icons
        if (shared.icons == null) return;
        var got: u32 = 0;
        for (want) |c| {
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
    fn loadOwn(a: std.mem.Allocator, client: lcu.Client) Own {
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

/// The poller's tick without its thread, window or updates, for the app review pages
/// (src/site/appreview.zig): a mock client's lockfile, stepped by the caller. Not beside
/// start(): both set this file's io
pub const Replay = struct {
    p: Poller,
    data: *const Data,
    shown: u64 = 0,

    pub fn init(gpa: std.mem.Allocator, io_: std.Io, lock_path: []const u8, live_port: u16, data: *const Data) Replay {
        io = io_;
        var p: Poller = .{ .watch = .init(gpa, io, lock_path), .own_arena = .init(gpa), .seats_arena = .init(gpa), .practice_arena = .init(gpa) };
        p.live_port = live_port;
        return .{ .p = p, .data = data };
    }

    pub fn deinit(r: *Replay) void {
        r.p.deinit();
    }

    /// What the client shows now, into `arena`; null when the poller would publish
    /// nothing new
    pub fn tick(r: *Replay, arena: std.mem.Allocator) !?state.Status {
        const s = r.p.tick(arena, r.data) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => r.p.disconnect(err),
        };
        const k = r.p.key(s, false);
        if (k == r.shown) return null;
        r.shown = k;
        return s;
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

test "update retries back off from 5 minutes to the usual 3 hours" {
    const want = [_]u32{ 300, 300, 600, 1200, 2400, 4800, 9600, 10800, 10800 };
    for (want, 0..) |w, fails| try std.testing.expectEqual(w, retryAfter(@intCast(fails)));
    try std.testing.expectEqual(10800, retryAfter(std.math.maxInt(u32)));
}
