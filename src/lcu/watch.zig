//! Polling the League client through champ select, shared by `meiolol-app watch` and the
//! desktop window: the connection, the gameflow phase, the session and the player's pool

const std = @import("std");
const lcu = @import("root.zig");
const session = @import("session.zig");

pub const Watch = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    /// Null finds it (lockfile.discover)
    lockfile: ?[]const u8 = null,
    /// Holds the credentials; reset on reconnect
    conn: ?std.heap.ArenaAllocator = null,
    client: ?lcu.Client = null,
    /// The pool, loaded once per champ select
    pool_arena: std.heap.ArenaAllocator,
    /// Pickable and owned champions; null when neither loads, so anything may show
    pool: ?[]u32 = null,
    pool_tries: u8 = 0,

    pub const Step = union(enum) {
        /// Not in champ select: the gameflow phase, "unknown" when unreadable
        phase: []const u8,
        /// In champ select, the session missing for a moment between phases
        between,
        /// A session the parser can't read (a client update?): the connection is fine
        bad_session: anyerror,
        select: session.ChampSelect,
    };

    pub fn init(gpa: std.mem.Allocator, io: std.Io, lockfile: ?[]const u8) Watch {
        return .{ .gpa = gpa, .io = io, .lockfile = lockfile, .pool_arena = .init(gpa) };
    }

    pub fn deinit(w: *Watch) void {
        if (w.conn) |*c| c.deinit();
        w.pool_arena.deinit();
    }

    /// After an error from step: the next step reconnects
    pub fn disconnect(w: *Watch) void {
        if (w.conn) |*c| c.deinit();
        w.conn = null;
        w.client = null;
        w.forgetPool();
    }

    fn forgetPool(w: *Watch) void {
        _ = w.pool_arena.reset(.retain_capacity);
        w.pool = null;
        w.pool_tries = 0;
    }

    /// The client's state now, read into `arena`
    pub fn step(w: *Watch, arena: std.mem.Allocator) !Step {
        if (w.client == null) {
            w.conn = .init(w.gpa);
            const credentials = try lcu.lockfile.discover(w.conn.?.allocator(), w.io, w.lockfile);
            w.client = .{ .gpa = w.gpa, .io = w.io, .credentials = credentials };
        }
        const client = w.client.?;

        const phase_body = try client.getOk(session.paths.phase);
        defer w.gpa.free(phase_body);
        const phase = session.parsePhase(arena, phase_body) catch "unknown";
        if (!std.mem.eql(u8, phase, "ChampSelect")) {
            w.forgetPool();
            return .{ .phase = phase };
        }

        const resp = try client.get(session.paths.session);
        defer w.gpa.free(resp.body);
        if (resp.status == 404) return .between;
        if (resp.status / 100 != 2) return error.HttpStatus;
        const cs = session.parse(arena, resp.body) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return .{ .bad_session = err },
        };
        // Up to 5 tries: either list may fail to load
        if (w.pool == null and w.pool_tries < 5) {
            w.pool_tries += 1;
            const a = w.pool_arena.allocator();
            const pickable = ids(a, client, session.paths.pickable, false);
            const owned = ids(a, client, session.paths.owned, true);
            w.pool = try session.intersectPool(a, pickable, owned);
        }
        return .{ .select = cs };
    }

    fn ids(a: std.mem.Allocator, client: lcu.Client, path: []const u8, objects: bool) ?[]u32 {
        const body = client.getOk(path) catch return null;
        defer client.gpa.free(body);
        const list = (if (objects) session.parseOwned(a, body) else session.parseIds(a, body)) catch return null;
        return if (list.len == 0) null else list;
    }
};
