//! More of what each player and team did, for comp discovery (`meiolol-lab comp-stats
//! SNAP DDRAGON [ARCHIVE]`, lab/comps.zig). From match summaries (lab/summaries.zig),
//! beside seat_stats.tsv (whose layout the pack and Row.stats carry, so left alone):
//! - SNAP/comp_stats.tsv: match_id, slot, then the Seat columns (summary totals as Riot
//!   gives them, challenges included, nan when missing) and four item flags, 1 when an
//!   item held at the end matches in Data Dragon's description of the game's patch:
//!   antiheal "Wounds", armour_pen "Armor Penetration", magic_pen "Magic Penetration",
//!   lethality "Lethality" (components and boots count: what the player ended with)
//! - SNAP/comp_teams.tsv: match_id, side (0 blue), then first and kills per objective
//! One line per queue 420 seat or team whose summary names the same champions as
//! participants. Training covariates and outcomes only, never a champ-select input

const std = @import("std");
const store = @import("store");
const par = @import("../par.zig");
const summaries = @import("summaries.zig");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const seat_file = "comp_stats.tsv";
pub const team_file = "comp_teams.tsv";

/// Summary fields read per participant; the column names are these names
const Top = struct {
    visionScore: ?f64 = null,
    wardsPlaced: ?f64 = null,
    wardsKilled: ?f64 = null,
    damageDealtToEpicMonsters: ?f64 = null,
    damageDealtToTurrets: ?f64 = null,
    damageDealtToObjectives: ?f64 = null,
    totalMinionsKilled: ?f64 = null,
    neutralMinionsKilled: ?f64 = null,
    kills: ?f64 = null,
    deaths: ?f64 = null,
    assists: ?f64 = null,
    totalTimeSpentDead: ?f64 = null,
    totalTimeCCDealt: ?f64 = null,
    goldEarned: ?f64 = null,
};

const Challenges = struct {
    controlWardsPlaced: ?f64 = null,
    dragonTakedowns: ?f64 = null,
    baronTakedowns: ?f64 = null,
    riftHeraldTakedowns: ?f64 = null,
    epicMonsterSteals: ?f64 = null,
    turretPlatesTaken: ?f64 = null,
    soloTurretsLategame: ?f64 = null,
    turretsTakenWithRiftHerald: ?f64 = null,
    laneMinionsFirst10Minutes: ?f64 = null,
    twentyMinionsIn3SecondsCount: ?f64 = null,
    soloKills: ?f64 = null,
    outnumberedKills: ?f64 = null,
    killParticipation: ?f64 = null,
    teamDamagePercentage: ?f64 = null,
    damageTakenOnTeamPercentage: ?f64 = null,
    pickKillWithAlly: ?f64 = null,
    immobilizeAndKillWithAlly: ?f64 = null,
    killAfterHiddenWithAlly: ?f64 = null,
    knockEnemyIntoTeamAndKill: ?f64 = null,
    killsNearEnemyTurret: ?f64 = null,
    killsUnderOwnTurret: ?f64 = null,
    saveAllyFromDeath: ?f64 = null,
    effectiveHealAndShielding: ?f64 = null,
    takedownsFirstXMinutes: ?f64 = null,
    killsOnOtherLanesEarlyJungleAsLaner: ?f64 = null,
    getTakedownsInAllLanesEarlyJungleAsLaner: ?f64 = null,
    skillshotsHit: ?f64 = null,
    multikills: ?f64 = null,
};

pub const Flag = enum { antiheal, armour_pen, magic_pen, lethality };
const flag_text = [_][]const u8{ "Wounds", "Armor Penetration", "Magic Penetration", "Lethality" };

const top_names = @typeInfo(Top).@"struct".field_names;
const challenge_names = @typeInfo(Challenges).@"struct".field_names;
const flag_names = @typeInfo(Flag).@"enum".field_names;
pub const seat_count = top_names.len + challenge_names.len + flag_names.len;
pub const Seat = [seat_count]f32;

pub const Objective = enum { baron, champion, dragon, horde, inhibitor, riftHerald, tower, voidGator };
const objective_names = @typeInfo(Objective).@"enum".field_names;
/// Per objective: first (0/1), kills
pub const team_count = 2 * objective_names.len;
pub const Team = [team_count]f32;

/// Column index of a seat field by name (Top, Challenges or Flag), at comptime
pub fn col(comptime name: []const u8) usize {
    inline for (top_names, 0..) |n, i| if (comptime std.mem.eql(u8, n, name)) return i;
    inline for (challenge_names, 0..) |n, i| if (comptime std.mem.eql(u8, n, name)) return top_names.len + i;
    inline for (flag_names, 0..) |n, i| if (comptime std.mem.eql(u8, n, name)) return top_names.len + challenge_names.len + i;
    @compileError("no comp_stats column " ++ name);
}

pub fn teamCol(o: Objective, comptime what: enum { first, kills }) usize {
    return 2 * @as(usize, @backingInt(o)) + @backingInt(what);
}

pub const seat_header = blk: {
    var h: []const u8 = "match_id\tslot";
    for (top_names ++ challenge_names ++ flag_names) |n| h = h ++ "\t" ++ n;
    break :blk h ++ "\n";
};
pub const team_header = blk: {
    var h: []const u8 = "match_id\tside";
    for (objective_names) |n| h = h ++ "\t" ++ n ++ "_first\t" ++ n ++ "_kills";
    break :blk h ++ "\n";
};

/// Top's fields are parsed from the same object separately
const Participant = struct {
    participantId: u32 = 0,
    championId: u32 = 0,
    challenges: ?Challenges = null,
    item0: u32 = 0,
    item1: u32 = 0,
    item2: u32 = 0,
    item3: u32 = 0,
    item4: u32 = 0,
    item5: u32 = 0,
    item6: u32 = 0,
};

const ObjectiveCount = struct { first: bool = false, kills: f64 = 0 };
const Objectives = struct {
    baron: ?ObjectiveCount = null,
    champion: ?ObjectiveCount = null,
    dragon: ?ObjectiveCount = null,
    horde: ?ObjectiveCount = null,
    inhibitor: ?ObjectiveCount = null,
    riftHerald: ?ObjectiveCount = null,
    tower: ?ObjectiveCount = null,
    voidGator: ?ObjectiveCount = null,
};

const Doc = struct {
    info: struct {
        gameVersion: []const u8 = "",
        participants: []const std.json.Value = &.{},
        teams: []const struct { teamId: u32 = 0, objectives: Objectives = .{} } = &.{},
    },
};

pub const Summary = struct {
    games: usize = 0,
    docs: usize = 0,
    bad_docs: usize = 0,
    seats: usize = 0,
    mismatch: usize = 0,
    teams: usize = 0,
    /// Of docs, from the raw archive (not in raw.db)
    from_archive: usize = 0,
    /// Seats whose patch had Data Dragon items (flags known)
    with_items: usize = 0,
};

/// Item flags per patch ("16.20") by item id
const Patches = std.StringArrayHashMapUnmanaged(std.AutoHashMapUnmanaged(u32, [flag_names.len]bool));

/// ARCHIVE: the raw archive, for games whose summary has left the box's raw.db
pub fn run(gpa: Allocator, io: Io, snap: []const u8, ddragon: []const u8, archive_dir: ?[]const u8) !Summary {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var sum: Summary = .{};

    var dd: Patches = .empty;
    defer {
        for (dd.values()) |*v| v.deinit(gpa);
        dd.deinit(gpa);
    }
    try loadItems(gpa, arena, io, ddragon, &dd);

    var games = try summaries.loadGames(gpa, arena, snap);
    defer games.deinit(gpa);
    sum.games = games.count();

    const cwd = Io.Dir.cwd();
    var outs: [2]struct { path: []const u8, tmp: []const u8, file: Io.File, fw: Io.File.Writer, buf: [64 * 1024]u8 } = undefined;
    for (&outs, [_][]const u8{ seat_file, team_file }, [_][]const u8{ seat_header, team_header }) |*o, name, header| {
        o.path = try std.fs.path.join(arena, &.{ snap, name });
        o.tmp = try arena.print("{s}.tmp", .{o.path});
        o.file = try cwd.createFile(io, o.tmp, .{});
        o.fw = o.file.writer(io, &o.buf);
        try o.fw.interface.writeAll(header);
    }
    defer for (&outs) |*o| o.file.close(io);

    const b = try gpa.create(Batch);
    defer gpa.destroy(b);
    b.* = .{ .dd = &dd, .io = io, .sw = &outs[0].fw.interface, .tw = &outs[1].fw.interface, .sum = &sum };
    sum.from_archive = (try summaries.each(gpa, io, snap, archive_dir, &games, b)).from_archive;
    for (&outs) |*o| {
        try o.fw.interface.flush();
        try cwd.rename(o.tmp, cwd, o.path, io);
    }
    return sum;
}

const SeatOut = union(enum) { none, mismatch, stats: Seat };

const Batch = struct {
    dd: *const Patches,
    io: Io,
    sw: *Io.Writer,
    tw: *Io.Writer,
    sum: *Summary,
    docs: []const summaries.Doc = &.{},
    out: [summaries.batch_len]struct { ok: bool, seats: [10]SeatOut, teams: [2]?Team } = undefined,

    pub fn batch(b: *Batch, docs: []const summaries.Doc) !void {
        b.docs = docs;
        try par.forEach(b.io, docs.len, b, body);
        const sum = b.sum;
        for (docs, b.out[0..docs.len]) |d, out| {
            sum.docs += 1;
            if (!out.ok) {
                sum.bad_docs += 1;
                continue;
            }
            for (out.seats, 0..) |s, slot| switch (s) {
                .none => {},
                .mismatch => sum.mismatch += 1,
                .stats => |st| {
                    try b.sw.print("{s}\t{d}", .{ d.key, slot });
                    for (st) |x| try b.sw.print("\t{d}", .{x});
                    try b.sw.writeByte('\n');
                    sum.seats += 1;
                    sum.with_items += @intFromBool(!std.math.isNan(st[col("antiheal")]));
                },
            };
            // A team line only when all its seats matched: the same game as participants
            for (out.teams, 0..) |t, side| {
                const team = t orelse continue;
                var ok = true;
                for (out.seats[side * 5 ..][0..5]) |s| ok = ok and s == .stats;
                if (!ok) continue;
                try b.tw.print("{s}\t{d}", .{ d.key, side });
                for (team) |x| try b.tw.print("\t{d}", .{x});
                try b.tw.writeByte('\n');
                sum.teams += 1;
            }
        }
    }

    fn body(b: *Batch, i: usize) !void {
        const out = &b.out[i];
        out.* = .{ .ok = false, .seats = @splat(.none), .teams = .{ null, null } };
        var arena: std.heap.ArenaAllocator = .init(std.heap.smp_allocator);
        defer arena.deinit();
        const a = arena.allocator();
        const json = b.docs[i].json(a) catch return;
        const opts: std.json.ParseOptions = .{ .ignore_unknown_fields = true };
        const doc = std.json.parseFromSliceLeaky(Doc, a, json, opts) catch return;
        out.ok = true;
        const items = b.dd.getPtr(patchOf(doc.info.gameVersion));
        for (doc.info.participants) |v| {
            const p = std.json.parseFromValueLeaky(Participant, a, v, opts) catch continue;
            const top = std.json.parseFromValueLeaky(Top, a, v, opts) catch continue;
            if (p.participantId < 1 or p.participantId > 10) continue;
            const slot = p.participantId - 1;
            const want = b.docs[i].champions[slot];
            if (want == 0) continue;
            out.seats[slot] = if (want != p.championId) .mismatch else .{ .stats = seat(p, top, items) };
        }
        for (doc.info.teams) |t| {
            const side: usize = switch (t.teamId) {
                100 => 0,
                200 => 1,
                else => continue,
            };
            var team: Team = @splat(std.math.nan(f32));
            inline for (objective_names, 0..) |n, k| if (@field(t.objectives, n)) |o| {
                team[2 * k] = if (o.first) 1 else 0;
                team[2 * k + 1] = @floatCast(o.kills);
            };
            out.teams[side] = team;
        }
    }
};

fn val(x: ?f64) f32 {
    return if (x) |v| @floatCast(v) else std.math.nan(f32);
}

fn seat(p: Participant, top: Top, items: ?*const std.AutoHashMapUnmanaged(u32, [flag_names.len]bool)) Seat {
    var s: Seat = @splat(std.math.nan(f32));
    inline for (top_names, 0..) |n, i| s[i] = val(@field(top, n));
    if (p.challenges) |c| inline for (challenge_names, 0..) |n, i| {
        s[top_names.len + i] = val(@field(c, n));
    };
    if (items) |dd| {
        var flags: [flag_names.len]bool = @splat(false);
        for ([_]u32{ p.item0, p.item1, p.item2, p.item3, p.item4, p.item5, p.item6 }) |id| {
            const f = dd.get(id) orelse continue;
            for (&flags, f) |*x, y| x.* = x.* or y;
        }
        for (flags, 0..) |f, i| s[top_names.len + challenge_names.len + i] = if (f) 1 else 0;
    }
    return s;
}

/// "16.20.712.3456" -> "16.20"
fn patchOf(version: []const u8) []const u8 {
    const first = std.mem.findScalar(u8, version, '.') orelse return version;
    const second = std.mem.findScalarPos(u8, version, first + 1, '.') orelse return version;
    return version[0..second];
}

/// Every DDRAGON/<patch>/item.json
fn loadItems(gpa: Allocator, arena: Allocator, io: Io, dir_path: []const u8, out: *Patches) !void {
    var dir = try Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .directory) continue;
        const path = try std.fs.path.join(arena, &.{ dir_path, e.name, "item.json" });
        const Item = struct { description: []const u8 = "" };
        const parsed = try std.json.parseFromSliceLeaky(
            struct { data: std.json.ArrayHashMap(Item) },
            arena,
            try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20)),
            .{ .ignore_unknown_fields = true },
        );
        var m: std.AutoHashMapUnmanaged(u32, [flag_names.len]bool) = .empty;
        errdefer m.deinit(gpa);
        for (parsed.data.map.keys(), parsed.data.map.values()) |k, item| {
            const id = std.fmt.parseInt(u32, k, 10) catch continue;
            var f: [flag_names.len]bool = undefined;
            for (&f, flag_text) |*x, t| x.* = std.mem.find(u8, item.description, t) != null;
            try m.put(gpa, id, f);
        }
        if (m.count() == 0) return error.NoDataDragon;
        try out.put(gpa, try arena.dupe(u8, e.name), m);
    }
    if (out.count() == 0) return error.NoDataDragon;
}

/// Reads SNAP/comp_stats.tsv or comp_teams.tsv (which = .seat or .team) into
/// `sink.at(match_id, n)` (slot or side; a *Seat or *Team, or null to skip). Returns the
/// lines placed, or null when there is no file
pub fn fill(io: Io, snap: []const u8, comptime which: enum { seat, team }, sink: anytype) !?usize {
    const name, const header, const width = switch (which) {
        .seat => .{ seat_file, seat_header, seat_count },
        .team => .{ team_file, team_header, team_count },
    };
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.mem.print(&path_buf, "{s}/{s}", .{ snap, name });
    var file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(io);
    var rbuf: [64 * 1024]u8 = undefined;
    var fr = file.reader(io, &rbuf);
    const r = &fr.interface;
    const first = (r.takeDelimiter('\n') catch |e| return fr.err orelse e) orelse "";
    if (!std.mem.eql(u8, first, header[0 .. header.len - 1])) {
        std.log.err("{s}: header is not this binary's (rerun meiolol-lab comp-stats)", .{path});
        return error.CompStatsHeader;
    }
    var placed: usize = 0;
    while (r.takeDelimiter('\n') catch |e| return fr.err orelse e) |line| {
        if (line.len == 0) continue;
        var f = std.mem.splitScalar(u8, line, '\t');
        const match_id = f.first();
        const n = std.fmt.parseInt(u8, f.next() orelse return error.BadCompStatsLine, 10) catch
            return error.BadCompStatsLine;
        var s: [width]f32 = undefined;
        for (&s) |*x| x.* = std.fmt.parseFloat(f32, f.next() orelse return error.BadCompStatsLine) catch
            return error.BadCompStatsLine;
        if (f.next() != null) return error.BadCompStatsLine;
        const dst = sink.at(match_id, n) orelse continue;
        dst.* = s;
        placed += 1;
    }
    return placed;
}

const testing = std.testing;

test "summaries to comp_stats.tsv and comp_teams.tsv and back" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const snap = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});

    {
        const db = try store.sqlite.Db.open(try std.fs.path.joinZ(arena, &.{ snap, "meiolol.db" }));
        defer db.close();
        try db.exec(
            \\CREATE TABLE matches (match_id TEXT PRIMARY KEY, queue_id INTEGER);
            \\CREATE TABLE participants (match_id TEXT, slot INTEGER, champion_id INTEGER);
            \\INSERT INTO matches VALUES ('EUW1_1', 420), ('EUW1_2', 450);
            \\INSERT INTO participants VALUES ('EUW1_1', 0, 33), ('EUW1_1', 1, 63),
            \\  ('EUW1_1', 2, 7), ('EUW1_2', 0, 33);
        );
    }
    const doc =
        \\{"metadata":{},"info":{"gameVersion":"16.20.712.3456","participants":[
        \\{"participantId":1,"championId":33,"visionScore":36,"kills":10,"item0":3075,"item1":3111,
        \\ "challenges":{"soloKills":2,"teamDamagePercentage":0.25,"legendaryItemUsed":[1]}},
        \\{"participantId":2,"championId":63,"item0":3135},
        \\{"participantId":3,"championId":99}],
        \\"teams":[{"teamId":100,"objectives":{"dragon":{"first":true,"kills":3},"tower":{"first":false,"kills":4}}},
        \\{"teamId":200,"objectives":{"dragon":{"first":false,"kills":1}}}]}}
    ;
    {
        const db = try store.sqlite.Db.open(try std.fs.path.joinZ(arena, &.{ snap, "raw.db" }));
        defer db.close();
        try db.exec("CREATE TABLE raw_docs (key TEXT, source TEXT, body BLOB)");
        for ([_]struct { []const u8, []const u8 }{ .{ "EUW1_1", doc }, .{ "EUW1_2", doc } }) |d| {
            const body = try store.raw.compress(arena, d[1]);
            try db.run("INSERT INTO raw_docs VALUES (?, 'riot_match', ?)", .{ d[0], store.Blob{ .bytes = body } });
        }
    }
    const dd = try arena.print("{s}/ddragon", .{snap});
    const dd_patch = try arena.print("{s}/16.20", .{dd});
    try Io.Dir.cwd().createDirPath(io, dd_patch);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try arena.print("{s}/item.json", .{dd_patch}), .data =
        \\{"type":"item","data":{"3075":{"name":"Thornmail","description":"apply 40% <keyword>Wounds</keyword>"},
        \\"3111":{"description":"boots"},"3135":{"description":"40% Magic Penetration"}}}
    });

    const sum = try run(gpa, io, snap, dd, null);
    // Seat 3 names another champion: its team gets no line
    try testing.expectEqual(Summary{ .games = 1, .docs = 1, .seats = 2, .mismatch = 1, .teams = 0, .with_items = 2 }, sum);

    const Sink = struct {
        seats: [2]Seat = @splat(@splat(0)),
        fn at(s: *@This(), match_id: []const u8, slot: u8) ?*Seat {
            if (!std.mem.eql(u8, match_id, "EUW1_1") or slot > 1) return null;
            return &s.seats[slot];
        }
    };
    var sink: Sink = .{};
    try testing.expectEqual(@as(?usize, 2), try fill(io, snap, .seat, &sink));
    const s0 = sink.seats[0];
    try testing.expectEqual(@as(f32, 36), s0[col("visionScore")]);
    try testing.expectEqual(@as(f32, 10), s0[col("kills")]);
    try testing.expectEqual(@as(f32, 2), s0[col("soloKills")]);
    try testing.expectEqual(@as(f32, 0.25), s0[col("teamDamagePercentage")]);
    try testing.expect(std.math.isNan(s0[col("deaths")]));
    try testing.expectEqual(@as(f32, 1), s0[col("antiheal")]);
    try testing.expectEqual(@as(f32, 0), s0[col("magic_pen")]);
    try testing.expectEqual(@as(f32, 1), sink.seats[1][col("magic_pen")]);
    try testing.expect(std.math.isNan(sink.seats[1][col("soloKills")]));
}

test "team lines when every seat matches" {
    const gpa = testing.allocator;
    const io = testing.io;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const snap = try arena.print(".zig-cache/tmp/{s}", .{&tmp.sub_path});
    {
        const db = try store.sqlite.Db.open(try std.fs.path.joinZ(arena, &.{ snap, "meiolol.db" }));
        defer db.close();
        try db.exec(
            \\CREATE TABLE matches (match_id TEXT PRIMARY KEY, queue_id INTEGER);
            \\CREATE TABLE participants (match_id TEXT, slot INTEGER, champion_id INTEGER);
            \\INSERT INTO matches VALUES ('EUW1_1', 420);
        );
        for (0..10) |slot| try db.run("INSERT INTO participants VALUES ('EUW1_1', ?, ?)", .{ @as(i64, @intCast(slot)), @as(i64, @intCast(slot + 1)) });
    }
    var parts: std.ArrayList(u8) = .empty;
    for (0..10) |slot| try parts.print(arena, "{s}{{\"participantId\":{d},\"championId\":{d}}}", .{ if (slot == 0) "" else ",", slot + 1, slot + 1 });
    const doc = try arena.print(
        \\{{"info":{{"gameVersion":"16.20.1","participants":[{s}],
        \\"teams":[{{"teamId":100,"objectives":{{"dragon":{{"first":true,"kills":3}},"tower":{{"first":false,"kills":4}}}}}},
        \\{{"teamId":200,"objectives":{{"dragon":{{"first":false,"kills":1}}}}}}]}}}}
    , .{parts.items});
    {
        const db = try store.sqlite.Db.open(try std.fs.path.joinZ(arena, &.{ snap, "raw.db" }));
        defer db.close();
        try db.exec("CREATE TABLE raw_docs (key TEXT, source TEXT, body BLOB)");
        try db.run("INSERT INTO raw_docs VALUES ('EUW1_1', 'riot_match', ?)", .{store.Blob{ .bytes = try store.raw.compress(arena, doc) }});
    }
    const dd = try arena.print("{s}/ddragon/16.20", .{snap});
    try Io.Dir.cwd().createDirPath(io, dd);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try arena.print("{s}/item.json", .{dd}), .data = "{\"data\":{\"1\":{}}}" });
    const sum = try run(gpa, io, snap, try arena.print("{s}/ddragon", .{snap}), null);
    try testing.expectEqual(@as(usize, 10), sum.seats);
    try testing.expectEqual(@as(usize, 2), sum.teams);

    const Sink = struct {
        teams: [2]Team = @splat(@splat(0)),
        fn at(s: *@This(), _: []const u8, side: u8) ?*Team {
            return &s.teams[side];
        }
    };
    var sink: Sink = .{};
    try testing.expectEqual(@as(?usize, 2), try fill(io, snap, .team, &sink));
    try testing.expectEqual(@as(f32, 1), sink.teams[0][teamCol(.dragon, .first)]);
    try testing.expectEqual(@as(f32, 3), sink.teams[0][teamCol(.dragon, .kills)]);
    try testing.expectEqual(@as(f32, 4), sink.teams[0][teamCol(.tower, .kills)]);
    try testing.expectEqual(@as(f32, 1), sink.teams[1][teamCol(.dragon, .kills)]);
    try testing.expect(std.math.isNan(sink.teams[1][teamCol(.baron, .kills)]));
}
