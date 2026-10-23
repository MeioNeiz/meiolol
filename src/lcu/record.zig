//! `meiolol-app record DIR`: a real game's client replies to files, for fixing the mock
//! and the parsers against what League really sends (docs/plan/app.md APP1). Every
//! distinct champ select session, the gameflow session at each phase change, the pool
//! lists, Live Client Data every `live_every` steps in game and the end of game block,
//! all through session.redact. Read-only GETs, like the rest of the app.

const std = @import("std");
const lcu = @import("root.zig");
const session = @import("session.zig");
const https = @import("https.zig");

const paths = struct {
    const gameflow = "/lol-gameflow/v1/session";
    const eog = "/lol-end-of-game/v1/eog-stats-block";
    const live = "/liveclientdata/allgamedata";
};

pub const Record = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    /// Null finds it (lockfile.discover)
    lockfile: ?[]const u8 = null,
    live_port: u16 = 2999,
    /// Steps between Live Client Data saves; the first after loading is saved at once
    live_every: u32 = 30,
    conn: ?std.heap.ArenaAllocator = null,
    client: ?lcu.Client = null,
    seq: u32 = 0,
    phase_buf: [64]u8 = undefined,
    phase: []const u8 = "",
    session_hash: u64 = 0,
    live_wait: u32 = 0,
    eog_saved: bool = false,
    /// Why Live Client Data failed last, printed once per kind
    live_err: ?anyerror = null,

    pub fn deinit(r: *Record) void {
        r.disconnect();
    }

    pub fn disconnect(r: *Record) void {
        if (r.conn) |*c| c.deinit();
        r.conn = null;
        r.client = null;
    }

    /// One poll; the names of the files it wrote, and notes, go to `log`
    pub fn step(r: *Record, arena: std.mem.Allocator, log: *std.Io.Writer) !void {
        if (r.client == null) {
            r.conn = .init(r.gpa);
            const credentials = try lcu.lockfile.discover(r.conn.?.allocator(), r.io, r.lockfile);
            r.client = .{ .gpa = r.gpa, .io = r.io, .credentials = credentials };
        }
        const client = r.client.?;
        const phase_body = try client.getOk(session.paths.phase);
        defer r.gpa.free(phase_body);
        const phase = session.parsePhase(arena, phase_body) catch "unknown";
        const eql = std.mem.eql;

        if (!eql(u8, phase, r.phase)) {
            const n = @min(phase.len, r.phase_buf.len);
            @memcpy(r.phase_buf[0..n], phase[0..n]);
            r.phase = r.phase_buf[0..n];
            try log.print("phase {s}\n", .{r.phase});
            _ = try r.saveLcu(arena, log, paths.gameflow, "gameflow");
            if (eql(u8, phase, "ChampSelect")) {
                r.session_hash = 0;
                r.eog_saved = false;
                _ = try r.saveLcu(arena, log, session.paths.pickable, "pickable");
                _ = try r.saveLcu(arena, log, session.paths.owned, "owned");
            }
            if (eql(u8, phase, "GameStart")) r.live_wait = 0;
        }

        if (eql(u8, phase, "ChampSelect")) {
            const resp = try client.get(session.paths.session);
            defer r.gpa.free(resp.body);
            if (resp.status / 100 != 2) return;
            const clean = try session.redact(arena, resp.body);
            const hash = std.hash.Wyhash.hash(0, clean);
            if (hash == r.session_hash) return;
            r.session_hash = hash;
            try r.write(arena, log, "session", clean);
        } else if (eql(u8, phase, "GameStart") or eql(u8, phase, "InProgress")) {
            if (r.live_wait > 0) {
                r.live_wait -= 1;
                return;
            }
            const resp = r.getLive() catch |err| {
                if (r.live_err == null or r.live_err.? != err) try log.print("live client data: {t}\n", .{err});
                r.live_err = err;
                return;
            };
            defer r.gpa.free(resp.body);
            if (resp.status / 100 != 2) return;
            try r.write(arena, log, "live", try session.redact(arena, resp.body));
            r.live_wait = r.live_every -| 1;
        } else if (eql(u8, phase, "PreEndOfGame") or eql(u8, phase, "EndOfGame")) {
            if (r.eog_saved) return;
            r.eog_saved = try r.saveLcu(arena, log, paths.eog, "eog");
        }
    }

    /// The game's own server: no lockfile password, Riot's root as the LCU
    fn getLive(r: *Record) !https.Response {
        if (r.client.?.credentials.plain) return https.getPlain(r.gpa, r.io, r.live_port, "", paths.live);
        return https.get(r.gpa, r.io, r.live_port, "", paths.live);
    }

    /// False when the client had nothing there
    fn saveLcu(r: *Record, arena: std.mem.Allocator, log: *std.Io.Writer, path: []const u8, what: []const u8) !bool {
        const resp = try r.client.?.get(path);
        defer r.gpa.free(resp.body);
        if (resp.status / 100 != 2) return false;
        try r.write(arena, log, what, try session.redact(arena, resp.body));
        return true;
    }

    fn write(r: *Record, arena: std.mem.Allocator, log: *std.Io.Writer, what: []const u8, body: []const u8) !void {
        r.seq += 1;
        const name = try std.fmt.allocPrint(arena, "{d:0>4}-{s}-{s}.json", .{ r.seq, r.phase, what });
        try r.dir.writeFile(r.io, .{ .sub_path = name, .data = body });
        try log.print("  {s} ({d} KB)\n", .{ name, (body.len + 1023) / 1024 });
    }
};

const testing = std.testing;
const mock = @import("mock.zig");

test "a full game recorded from the mock, identities removed" {
    const io = testing.io;
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const s = try mock.Scenario.load(arena, io, "testdata/lcu/scenarios/full-game.json");
    var h: mock.Harness = undefined;
    try h.start(arena, &s);
    defer h.stop();

    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var r: Record = .{
        .gpa = gpa,
        .io = io,
        .dir = tmp.dir,
        .lockfile = h.lock_path,
        .live_port = h.livePort(),
        .live_every = 2,
    };
    defer r.deinit();
    var log: std.Io.Writer.Allocating = .init(gpa);
    defer log.deinit();
    while (try h.mock.advance()) |_| {
        var frame: std.heap.ArenaAllocator = .init(gpa);
        defer frame.deinit();
        try r.step(frame.allocator(), &log.writer);
    }

    var counts: std.StringHashMapUnmanaged(u32) = .empty;
    var it = tmp.dir.iterate();
    while (try it.next(io)) |e| {
        const body = try tmp.dir.readFileAlloc(io, e.name, arena, .limited(1 << 20));
        try testing.expect(std.mem.indexOf(u8, body, "MockPlayer") == null);
        try testing.expect(std.mem.indexOf(u8, body, "mock-puuid") == null);
        const what = e.name[std.mem.lastIndexOfScalar(u8, e.name, '-').? + 1 ..];
        const got = try counts.getOrPutValue(arena, try arena.dupe(u8, what), 0);
        got.value_ptr.* += 1;
    }
    const want = [_]struct { []const u8, u32 }{
        .{ "pickable.json", 1 },
        .{ "owned.json", 1 },
        .{ "eog.json", 1 },
    };
    for (want) |w| try testing.expectEqual(w[1], counts.get(w[0]) orelse 0);
    // Every champ select step changes the session; live data every other in-game step
    try testing.expect((counts.get("session.json") orelse 0) >= 10);
    try testing.expect((counts.get("live.json") orelse 0) >= 2);
    try testing.expect((counts.get("gameflow.json") orelse 0) >= 8);
    try testing.expect(std.mem.indexOf(u8, log.written(), "phase EndOfGame") != null);
}
