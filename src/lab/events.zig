//! `meiolol-lab events SNAP`: SNAP/events.tsv, one line per tower, inhibitor, epic monster
//! and champion kill in every lab game (rows.load) with a 10-participant timeline, with
//! the game's result and the state just before the event (objectives.stateBefore: gold
//! and XP from the last frame at or before it, objectives from earlier events), blue
//! minus red. Columns (`header`):
//!   is_test: protocol's split; winner, team: 100 blue, 200 red, 0 none (a monster no team
//!   took). type tower|inhibitor|monster|kill. subtype: tower OUTER_TURRET..NEXUS_TURRET,
//!   monster the dragon's element, ELDER_DRAGON, or HORDE, RIFTHERALD, BARON_NASHOR,
//!   ATAKHAN; lane for buildings. team: who took it (a building's owner's opponent).
//!   killer: participant id, 0 none (minion, turret, monster); roles as rows.Row.role.
//!   bounty: a kill's bounty plus shutdown; the compact timeline keeps no gold for the
//!   rest (nan). steal: see `steal`. kills_near_*: each team's champion kills within 30 s
//!   either side, this event left out (a contested proxy)

const std = @import("std");
const store = @import("store");
const timeline = @import("../riot/timeline.zig");
const objectives = @import("../objectives.zig");
const stats = @import("../stats.zig");
const par = @import("../par.zig");
const rows = @import("rows.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const Feat = objectives.Feat;

pub const usage =
    \\  events SNAP                     SNAP/events.tsv: towers, inhibitors, epic monsters
    \\                                  and champion kills with the state just before,
    \\                                  steal flag and result (lab/events.zig)
    \\
;

pub const file_name = "events.tsv";
const state_feats = [_]Feat{ .gold, .xp } ++ objectives.held[0..9].*;
pub const header = blk: {
    var h: []const u8 = "match_id\tis_test\twinner\tduration_s\tt_ms\tminute\ttype\tsubtype\tlane" ++
        "\tteam\tkiller\tkiller_role\tvictim_role\tfirst_blood\tbounty\tsteal" ++
        "\tkills_near_100\tkills_near_200";
    for (state_feats) |f| h = h ++ "\t" ++ @tagName(f);
    break :blk h ++ "\n";
};
const near_ms = 30_000;

pub const Summary = struct {
    games: usize = 0,
    /// Of them, with a 10-participant timeline
    timelines: usize = 0,
    /// Of them, with a readable match summary (steals)
    summaries: usize = 0,
    lines: usize = 0,
    /// Epic monster lines whose steal is unknown (no summary, no killer, grubs, or
    /// fewer steals than monsters taken)
    steal_unknown: usize = 0,
};

/// 1 when the killer stole this monster, 0 when not, nan when it can't be told. The
/// summary gives only a count per player (challenges.epicMonsterSteals): with none the
/// answer is 0; with as many steals as epic monsters they took (dragons, elder, herald,
/// baron, Atakhan) every one was a steal; otherwise which ones is unknown. Grubs: nan,
/// since whether Riot counts them is unknown
pub fn steal(steals: ?u16, taken: u16, grubs: bool) f32 {
    const s = steals orelse return std.math.nan(f32);
    if (grubs) return std.math.nan(f32);
    if (s == 0) return 0;
    return if (s >= taken) 1 else std.math.nan(f32);
}

pub fn run(gpa: Allocator, io: Io, snap: []const u8) !Summary {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var sum: Summary = .{};

    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    sum.games = data.games.len;
    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    for (data.games, 0..) |g, gi| try index.put(gpa, stats.matchKey(g.match_id), @intCast(gi));
    const no_role = 255;
    const roles = try arena.alloc([10]u8, data.games.len);
    @memset(roles, @splat(no_role));
    for (data.rows) |r| if (r.slot < 10) {
        roles[r.game][r.slot] = @backingInt(r.role);
    };
    const steals = try arena.alloc([10]?u16, data.games.len);
    sum.summaries = try readSteals(gpa, arena, io, snap, &index, steals);

    const out_path = try std.fs.path.join(arena, &.{ snap, file_name });
    var af = try Io.Dir.cwd().createFileAtomic(io, out_path, .{ .replace = true });
    defer af.deinit(io);
    {
        var wbuf: [256 * 1024]u8 = undefined;
        var fw = af.file.writer(io, &wbuf);
        const w = &fw.interface;
        try w.writeAll(header);

        const db = try store.sqlite.Db.openReadOnly(try std.fs.path.joinZ(arena, &.{ snap, "timeline.db" }));
        defer db.close();
        var q = try db.prepare("SELECT match_id, data FROM timelines");
        defer q.deinit();
        try q.bind(.{});
        var tl_arena: std.heap.ArenaAllocator = .init(gpa);
        defer tl_arena.deinit();
        while (try q.step()) {
            const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
            _ = tl_arena.reset(.retain_capacity);
            const ta = tl_arena.allocator();
            const raw = try store.raw.decompress(ta, q.bytes(1));
            const t = timeline.decode(ta, raw) catch continue;
            if (t.participants != 10 or t.frames.len == 0) continue;
            sum.timelines += 1;
            const g = Game{ .game = data.games[gi], .roles = roles[gi], .steals = steals[gi] };
            const n = try writeGame(ta, w, g, t);
            sum.lines += n.lines;
            sum.steal_unknown += n.steal_unknown;
        }
        try w.flush();
    }
    try af.replace(io);
    return sum;
}

const Game = struct {
    game: rows.Game,
    /// By slot: @backingInt(core.Role), 255 unknown
    roles: [10]u8,
    /// By slot: challenges.epicMonsterSteals, null without a summary
    steals: [10]?u16,
};

fn teamOf(participant: u8) u16 {
    return if (participant >= 1 and participant <= 5) 100 else if (participant >= 6 and participant <= 10) 200 else 0;
}

fn roleName(g: Game, participant: u8) []const u8 {
    if (participant < 1 or participant > 10) return "-";
    const r = g.roles[participant - 1];
    return if (r == 255) "-" else @tagName(@as(@FieldType(rows.Row, "role"), @fromBackingInt(@intCast(r))));
}

const Written = struct { lines: usize = 0, steal_unknown: usize = 0 };

fn writeGame(arena: Allocator, w: *Io.Writer, g: Game, t: timeline.Timeline) !Written {
    var out: Written = .{};
    var kills: std.ArrayList(struct { t_ms: i64, team: u16, event: usize }) = .empty;
    var taken: [10]u16 = @splat(0);
    for (t.events, 0..) |e, i| switch (e.data) {
        .champion_kill => |k| {
            const team = if (teamOf(k.killer) != 0) teamOf(k.killer) else switch (teamOf(k.victim)) {
                100 => @as(u16, 200),
                200 => 100,
                else => 0,
            };
            try kills.append(arena, .{ .t_ms = e.t_ms, .team = team, .event = i });
        },
        .elite_monster => |m| if (m.killer >= 1 and m.killer <= 10 and !std.mem.eql(u8, m.monster, "HORDE")) {
            taken[m.killer - 1] += 1;
        },
        else => {},
    };

    var frame: usize = 0;
    var first_kill = true;
    for (t.events, 0..) |e, i| {
        const Line = struct {
            kind: []const u8,
            subtype: []const u8 = "-",
            lane: []const u8 = "-",
            team: u16,
            killer: u8,
            victim: u8 = 0,
            first_blood: bool = false,
            bounty: f32 = std.math.nan(f32),
            steal: f32 = std.math.nan(f32),
        };
        const line: Line = switch (e.data) {
            .building_kill => |b| blk: {
                const tower = std.mem.eql(u8, b.building, "TOWER_BUILDING");
                if (!tower and !std.mem.eql(u8, b.building, "INHIBITOR_BUILDING")) continue;
                break :blk .{
                    .kind = if (tower) "tower" else "inhibitor",
                    .subtype = if (tower and b.tower.len > 0) b.tower else "-",
                    .lane = if (b.lane.len > 0) b.lane else "-",
                    .team = switch (b.team) {
                        100 => 200,
                        200 => 100,
                        else => 0,
                    },
                    .killer = b.killer,
                };
            },
            .elite_monster => |m| blk: {
                const grubs = std.mem.eql(u8, m.monster, "HORDE");
                const known = m.killer >= 1 and m.killer <= 10;
                const s = if (known) steal(g.steals[m.killer - 1], taken[m.killer - 1], grubs) else std.math.nan(f32);
                out.steal_unknown += @intFromBool(std.math.isNan(s));
                break :blk .{
                    .kind = "monster",
                    .subtype = if (m.subtype.len > 0) m.subtype else m.monster,
                    .team = if (m.team == 100 or m.team == 200) m.team else 0,
                    .killer = m.killer,
                    .steal = s,
                };
            },
            .champion_kill => |k| blk: {
                defer first_kill = false;
                break :blk .{
                    .kind = "kill",
                    .team = for (kills.items) |kl| {
                        if (kl.event == i) break kl.team;
                    } else 0,
                    .killer = k.killer,
                    .victim = k.victim,
                    .first_blood = first_kill,
                    .bounty = @floatFromInt(k.bounty + k.shutdown),
                };
            },
            else => continue,
        };
        while (frame + 1 < t.frames.len and t.frames[frame + 1].t_ms <= e.t_ms) frame += 1;
        const state = objectives.stateBefore(t, t.frames[frame], e.t_ms);
        var near: [2]u16 = @splat(0);
        for (kills.items) |kl| {
            if (kl.event == i or kl.team == 0 or @abs(kl.t_ms - e.t_ms) > near_ms) continue;
            near[@intFromBool(kl.team == 200)] += 1;
        }

        try w.print("{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{s}\t{s}\t{s}\t{d}\t{d}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}", .{
            g.game.match_id,          @intFromBool(g.game.is_test),   @as(u16, if (g.game.winner == 0) 100 else 200),
            g.game.duration_s,        e.t_ms,                         @divFloor(e.t_ms, 60_000),
            line.kind,                line.subtype,                   line.lane,
            line.team,                line.killer,                    roleName(g, line.killer),
            roleName(g, line.victim), @intFromBool(line.first_blood), line.bounty,
            line.steal,               near[0],                        near[1],
        });
        for (state_feats) |f| try w.print("\t{d}", .{state[@backingInt(f)]});
        try w.writeByte('\n');
        out.lines += 1;
    }
    return out;
}

/// Per game and slot, challenges.epicMonsterSteals from SNAP/raw.db's summaries; returns
/// the games with a readable one
fn readSteals(
    gpa: Allocator,
    arena: Allocator,
    io: Io,
    snap: []const u8,
    index: *const std.AutoHashMapUnmanaged(u64, u32),
    out: [][10]?u16,
) !usize {
    @memset(out, @splat(null));
    const seen = try arena.alloc(bool, out.len);
    @memset(seen, false);
    var read: usize = 0;
    const path = try std.fs.path.joinZ(arena, &.{ snap, "raw.db" });
    const db = store.sqlite.Db.openReadOnly(path) catch return 0;
    defer db.close();
    var q = db.prepare("SELECT key, body FROM raw_docs WHERE source = 'riot_match'") catch return 0;
    defer q.deinit();
    try q.bind(.{});
    var batch_arena: std.heap.ArenaAllocator = .init(gpa);
    defer batch_arena.deinit();
    const b = try gpa.create(Batch);
    defer gpa.destroy(b);
    var more = true;
    while (more) {
        _ = batch_arena.reset(.retain_capacity);
        const ba = batch_arena.allocator();
        var n: usize = 0;
        while (n < Batch.len) {
            more = try q.step();
            if (!more) break;
            const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
            if (seen[gi]) continue;
            seen[gi] = true;
            b.games[n] = gi;
            b.bodies[n] = try ba.dupe(u8, q.bytes(1));
            n += 1;
        }
        try par.forEach(io, n, b, Batch.body);
        for (b.games[0..n], b.out[0..n], b.ok[0..n]) |gi, s, ok| {
            out[gi] = s;
            read += @intFromBool(ok);
        }
    }
    return read;
}

const Batch = struct {
    const len = 4096;
    games: [len]u32 = undefined,
    bodies: [len][]const u8 = undefined,
    out: [len][10]?u16 = undefined,
    ok: [len]bool = undefined,

    const Doc = struct {
        info: struct {
            participants: []const struct {
                participantId: u32 = 0,
                challenges: ?struct { epicMonsterSteals: ?u16 = null } = null,
            } = &.{},
        },
    };

    fn body(b: *Batch, i: usize) !void {
        b.out[i] = @splat(null);
        b.ok[i] = false;
        var arena: std.heap.ArenaAllocator = .init(std.heap.smp_allocator);
        defer arena.deinit();
        const a = arena.allocator();
        const json = store.raw.decompress(a, b.bodies[i]) catch return;
        const doc = std.json.parseFromSliceLeaky(Doc, a, json, .{ .ignore_unknown_fields = true }) catch return;
        b.ok[i] = true;
        // A summary without challenges (older games) leaves every slot unknown
        for (doc.info.participants) |p| {
            if (p.participantId < 1 or p.participantId > 10) continue;
            const c = p.challenges orelse continue;
            b.out[i][p.participantId - 1] = c.epicMonsterSteals orelse continue;
        }
    }
};

test steal {
    try std.testing.expectEqual(@as(f32, 0), steal(0, 2, false));
    try std.testing.expectEqual(@as(f32, 1), steal(2, 2, false));
    try std.testing.expect(std.math.isNan(steal(1, 2, false)));
    try std.testing.expect(std.math.isNan(steal(null, 1, false)));
    try std.testing.expect(std.math.isNan(steal(0, 0, true)));
}
