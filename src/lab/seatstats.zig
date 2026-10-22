//! What each player did in a game (`meiolol-lab seat-stats SNAP [DDRAGON [ARCHIVE]]`;
//! api.SeatStat, which mirrors SeatStat here). From match summaries (lab/summaries.zig:
//! SNAP/raw.db, then the raw archive) to
//! SNAP/seat_stats.tsv: match_id, slot, then the SeatStat columns in enum order, nan when
//! unknown; one line per queue 420 participant whose summary exists and names the same
//! champion. rows.zig reads it into Row.stats (fill); no line = unknown.
//! From Data Dragon, the game's own patch (DDRAGON/<patch>/champion.json and item.json,
//! patch as "16.20" from gameVersion; nan without it): armor_end, mr_end = the champion's
//! base + growth at level 15, plus the flat armour and MR of the items held at the end
//! (item0..item6). Ability resists (Rammus W, Malphite's passive) are left out: it is the
//! build's lean, not the game's real value, which only a raw timeline's championStats has
//! (compact timelines drop it, raw ones are archived only from 2026-10-12).
//! attack_range: the champion's base range

const std = @import("std");
const store = @import("store");
const par = @import("../par.zig");
const summaries = @import("summaries.zig");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.seatstats);

pub const SeatStat = enum {
    minutes,
    dmg_phys,
    dmg_magic,
    dmg_true,
    taken_phys,
    taken_magic,
    taken_true,
    mitigated,
    cc_time,
    immobilisations,
    heal,
    heal_allies,
    shield_allies,
    dmg_buildings,
    armor_end,
    mr_end,
    attack_range,
};
pub const count = @typeInfo(SeatStat).@"enum".field_names.len;
pub const Stats = [count]f32;
pub const unknown: Stats = @splat(std.math.nan(f32));

pub const file_name = "seat_stats.tsv";
pub const header = blk: {
    var h: []const u8 = "match_id\tslot";
    for (@typeInfo(SeatStat).@"enum".field_names) |name| h = h ++ "\t" ++ name;
    break :blk h ++ "\n";
};
fn at(s: SeatStat) usize {
    return @backingInt(s);
}

/// match-v5 summary fields read here; anything else is skipped
const Participant = struct {
    participantId: u32 = 0,
    championId: u32 = 0,
    physicalDamageDealtToChampions: ?f64 = null,
    magicDamageDealtToChampions: ?f64 = null,
    trueDamageDealtToChampions: ?f64 = null,
    physicalDamageTaken: ?f64 = null,
    magicDamageTaken: ?f64 = null,
    trueDamageTaken: ?f64 = null,
    damageSelfMitigated: ?f64 = null,
    timeCCingOthers: ?f64 = null,
    totalHeal: ?f64 = null,
    totalHealsOnTeammates: ?f64 = null,
    totalDamageShieldedOnTeammates: ?f64 = null,
    damageDealtToBuildings: ?f64 = null,
    challenges: ?struct { enemyChampionImmobilizations: ?f64 = null } = null,
    item0: u32 = 0,
    item1: u32 = 0,
    item2: u32 = 0,
    item3: u32 = 0,
    item4: u32 = 0,
    item5: u32 = 0,
    item6: u32 = 0,
};

const Doc = struct {
    info: struct {
        /// Seconds (match-v5 since patch 11.20)
        gameDuration: ?f64 = null,
        /// "16.20.712.3456"
        gameVersion: []const u8 = "",
        participants: []const Participant = &.{},
    },
};

fn val(x: ?f64) f32 {
    return if (x) |v| @floatCast(v) else std.math.nan(f32);
}

fn seat(p: Participant, minutes: f32, dd: *const Static) Stats {
    var s = unknown;
    s[at(.minutes)] = minutes;
    s[at(.dmg_phys)] = val(p.physicalDamageDealtToChampions);
    s[at(.dmg_magic)] = val(p.magicDamageDealtToChampions);
    s[at(.dmg_true)] = val(p.trueDamageDealtToChampions);
    s[at(.taken_phys)] = val(p.physicalDamageTaken);
    s[at(.taken_magic)] = val(p.magicDamageTaken);
    s[at(.taken_true)] = val(p.trueDamageTaken);
    s[at(.mitigated)] = val(p.damageSelfMitigated);
    s[at(.cc_time)] = val(p.timeCCingOthers);
    if (p.challenges) |c| s[at(.immobilisations)] = val(c.enemyChampionImmobilizations);
    s[at(.heal)] = val(p.totalHeal);
    s[at(.heal_allies)] = val(p.totalHealsOnTeammates);
    s[at(.shield_allies)] = val(p.totalDamageShieldedOnTeammates);
    s[at(.dmg_buildings)] = val(p.damageDealtToBuildings);
    if (dd.champions.get(p.championId)) |c| {
        var resist = [2]f32{ c.armor_base, c.mr_base };
        for ([_]u32{ p.item0, p.item1, p.item2, p.item3, p.item4, p.item5, p.item6 }) |id| {
            const it = dd.items.get(id) orelse continue;
            resist[0] += it[0];
            resist[1] += it[1];
        }
        s[at(.armor_end)] = resist[0];
        s[at(.mr_end)] = resist[1];
        s[at(.attack_range)] = c.range;
    }
    return s;
}

pub const Summary = struct {
    /// Queue 420 games in meiolol.db
    games: usize = 0,
    /// Of them, with a raw summary
    docs: usize = 0,
    /// Of docs, from the raw archive (not in raw.db)
    from_archive: usize = 0,
    /// Summaries that failed to decompress or parse
    bad_docs: usize = 0,
    lines: usize = 0,
    /// Seats whose summary names another champion than participants (left out)
    mismatch: usize = 0,
    /// Lines with Data Dragon values (armor_end, mr_end, attack_range)
    with_static: usize = 0,
};

/// ARCHIVE: the raw archive, for games whose summary has left the box's raw.db
pub fn run(gpa: Allocator, io: Io, snap: []const u8, ddragon: ?[]const u8, archive_dir: ?[]const u8) !Summary {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var sum: Summary = .{};

    var dd: Patches = .empty;
    defer {
        for (dd.values()) |*v| v.deinit(gpa);
        dd.deinit(gpa);
    }
    if (ddragon) |dir| try loadPatches(gpa, arena, io, dir, &dd);

    var games = try summaries.loadGames(gpa, arena, snap);
    defer games.deinit(gpa);
    sum.games = games.count();

    const cwd = Io.Dir.cwd();
    const out_path = try std.fs.path.join(arena, &.{ snap, file_name });
    const tmp_path = try std.fmt.allocPrint(arena, "{s}.tmp", .{out_path});
    {
        var file = try cwd.createFile(io, tmp_path, .{});
        errdefer cwd.deleteFile(io, tmp_path) catch {};
        defer file.close(io);
        var wbuf: [64 * 1024]u8 = undefined;
        var fw = file.writer(io, &wbuf);
        const w = &fw.interface;
        try w.writeAll(header);

        const b = try gpa.create(Batch);
        defer gpa.destroy(b);
        b.* = .{ .dd = &dd, .io = io, .w = w, .sum = &sum };
        const counts = try summaries.each(gpa, io, snap, archive_dir, &games, b);
        sum.from_archive = counts.from_archive;
        try w.flush();
    }
    try cwd.rename(tmp_path, cwd, out_path, io);
    return sum;
}

const Seat = union(enum) { none, mismatch, stats: Stats };

const Batch = struct {
    dd: *const Patches,
    io: Io,
    w: *Io.Writer,
    sum: *Summary,
    docs: []const summaries.Doc = &.{},
    out: [summaries.batch_len][10]Seat = undefined,
    ok: [summaries.batch_len]bool = undefined,

    pub fn batch(b: *Batch, docs: []const summaries.Doc) !void {
        b.docs = docs;
        try par.forEach(b.io, docs.len, b, body);
        const sum = b.sum;
        for (docs, b.out[0..docs.len], b.ok[0..docs.len]) |d, seats, ok| {
            sum.docs += 1;
            if (!ok) {
                sum.bad_docs += 1;
                continue;
            }
            for (seats, 0..) |s, slot| switch (s) {
                .none => {},
                .mismatch => sum.mismatch += 1,
                .stats => |st| {
                    try b.w.print("{s}\t{d}", .{ d.key, slot });
                    for (st) |x| try b.w.print("\t{d}", .{x});
                    try b.w.writeByte('\n');
                    sum.lines += 1;
                    sum.with_static += @intFromBool(!std.math.isNan(st[at(.attack_range)]));
                },
            };
        }
    }

    fn body(b: *Batch, i: usize) !void {
        b.out[i] = @splat(.none);
        b.ok[i] = false;
        var arena: std.heap.ArenaAllocator = .init(std.heap.smp_allocator);
        defer arena.deinit();
        const a = arena.allocator();
        const d = b.docs[i];
        const json = d.json(a) catch return;
        const doc = std.json.parseFromSliceLeaky(Doc, a, json, .{ .ignore_unknown_fields = true }) catch return;
        b.ok[i] = true;
        const minutes = val(doc.info.gameDuration) / 60;
        const dd = b.dd.getPtr(patchOf(doc.info.gameVersion)) orelse &Static{};
        for (doc.info.participants) |p| {
            if (p.participantId < 1 or p.participantId > 10) continue;
            const slot = p.participantId - 1;
            const want = d.champions[slot];
            if (want == 0) continue;
            b.out[i][slot] = if (want != p.championId) .mismatch else .{ .stats = seat(p, minutes, dd) };
        }
    }
};

/// "16.20.712.3456" -> "16.20"
fn patchOf(version: []const u8) []const u8 {
    const first = std.mem.indexOfScalar(u8, version, '.') orelse return version;
    const second = std.mem.indexOfScalarPos(u8, version, first + 1, '.') orelse return version;
    return version[0..second];
}

const Patches = std.StringArrayHashMapUnmanaged(Static);

/// Every DDRAGON/<patch>/ with champion.json and item.json
fn loadPatches(gpa: Allocator, arena: Allocator, io: Io, dir_path: []const u8, out: *Patches) !void {
    var dir = try Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .directory) continue;
        var s: Static = .{};
        errdefer s.deinit(gpa);
        try s.load(gpa, arena, io, try std.fs.path.join(arena, &.{ dir_path, e.name }));
        try out.put(gpa, try arena.dupe(u8, e.name), s);
    }
    if (out.count() == 0) return error.NoDataDragon;
}

/// Data Dragon values of one patch by champion id and item id
const Static = struct {
    /// armor_base, mr_base: at level 15
    champions: std.AutoHashMapUnmanaged(u32, struct { armor_base: f32, mr_base: f32, range: f32 }) = .empty,
    /// Flat armour, flat MR
    items: std.AutoHashMapUnmanaged(u32, [2]f32) = .empty,

    fn deinit(s: *Static, gpa: Allocator) void {
        s.champions.deinit(gpa);
        s.items.deinit(gpa);
    }

    fn load(s: *Static, gpa: Allocator, arena: Allocator, io: Io, dir: []const u8) !void {
        const opts: std.json.ParseOptions = .{ .ignore_unknown_fields = true };
        const cpath = try std.fs.path.join(arena, &.{ dir, "champion.json" });
        const Champion = struct {
            key: []const u8,
            stats: struct { attackrange: f32, armor: f32, armorperlevel: f32, spellblock: f32, spellblockperlevel: f32 },
        };
        const champs = try std.json.parseFromSliceLeaky(
            struct { data: std.json.ArrayHashMap(Champion) },
            arena,
            try Io.Dir.cwd().readFileAlloc(io, cpath, arena, .limited(64 << 20)),
            opts,
        );
        for (champs.data.map.values()) |c| {
            const id = std.fmt.parseInt(u32, c.key, 10) catch continue;
            const st = c.stats;
            try s.champions.put(gpa, id, .{
                .armor_base = atLevel(st.armor, st.armorperlevel, 15),
                .mr_base = atLevel(st.spellblock, st.spellblockperlevel, 15),
                .range = st.attackrange,
            });
        }
        const ipath = try std.fs.path.join(arena, &.{ dir, "item.json" });
        const Item = struct { stats: struct { FlatArmorMod: f32 = 0, FlatSpellBlockMod: f32 = 0 } = .{} };
        const items = try std.json.parseFromSliceLeaky(
            struct { data: std.json.ArrayHashMap(Item) },
            arena,
            try Io.Dir.cwd().readFileAlloc(io, ipath, arena, .limited(64 << 20)),
            opts,
        );
        for (items.data.map.keys(), items.data.map.values()) |k, it| {
            const id = std.fmt.parseInt(u32, k, 10) catch continue;
            try s.items.put(gpa, id, .{ it.stats.FlatArmorMod, it.stats.FlatSpellBlockMod });
        }
        if (s.champions.count() == 0 or s.items.count() == 0) return error.NoDataDragon;
    }
};

/// A stat at champion level n: Riot's growth curve, base + growth * (n - 1) *
/// (0.7025 + 0.0175 * (n - 1))
fn atLevel(base: f32, growth: f32, n: f32) f32 {
    return base + growth * (n - 1) * (0.7025 + 0.0175 * (n - 1));
}

/// SNAP/seat_stats.tsv into `sink.at(match_id, slot)` (a *Stats, or null for a seat the
/// caller doesn't have). Returns the lines placed, or null when there is no file
pub fn fill(io: Io, snap: []const u8, sink: anytype) !?usize {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ snap, file_name });
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
        log.err("{s}: header is not this binary's (rerun meiolol-lab seat-stats)", .{path});
        return error.SeatStatsHeader;
    }
    var placed: usize = 0;
    while (r.takeDelimiter('\n') catch |e| return fr.err orelse e) |line| {
        if (line.len == 0) continue;
        var f = std.mem.splitScalar(u8, line, '\t');
        const match_id = f.first();
        const slot = std.fmt.parseInt(u8, f.next() orelse return error.BadSeatStatsLine, 10) catch
            return error.BadSeatStatsLine;
        var s: Stats = undefined;
        for (&s) |*x| x.* = std.fmt.parseFloat(f32, f.next() orelse return error.BadSeatStatsLine) catch
            return error.BadSeatStatsLine;
        if (f.next() != null) return error.BadSeatStatsLine;
        const dst = sink.at(match_id, slot) orelse continue;
        dst.* = s;
        placed += 1;
    }
    return placed;
}

const testing = std.testing;

test "summaries to seat_stats.tsv and back" {
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
            \\INSERT INTO matches VALUES ('EUW1_1', 420), ('EUW1_2', 420), ('EUW1_3', 450),
            \\  ('EUW1_4', 420);
            \\INSERT INTO participants VALUES ('EUW1_1', 0, 33), ('EUW1_1', 1, 63),
            \\  ('EUW1_1', 2, 7), ('EUW1_2', 0, 33), ('EUW1_3', 0, 33), ('EUW1_4', 0, 33);
        );
    }
    const doc1 =
        \\{"metadata":{},"info":{"gameDuration":1830,"gameVersion":"16.20.712.3456","participants":[
        \\{"participantId":1,"championId":33,"physicalDamageDealtToChampions":5000,
        \\ "magicDamageDealtToChampions":2000,"trueDamageDealtToChampions":300,
        \\ "physicalDamageTaken":15000,"magicDamageTaken":9000,"trueDamageTaken":1000,
        \\ "damageSelfMitigated":40000,"timeCCingOthers":25,"totalHeal":3000,
        \\ "totalHealsOnTeammates":0,"totalDamageShieldedOnTeammates":0,
        \\ "damageDealtToBuildings":1200,"item0":3075,"item1":3111,"item6":3340,
        \\ "challenges":{"enemyChampionImmobilizations":12,"legendaryItemUsed":[1]}},
        \\{"participantId":2,"championId":63,"magicDamageDealtToChampions":30000},
        \\{"participantId":3,"championId":99}]}}
    ;
    {
        const db = try store.sqlite.Db.open(try std.fs.path.joinZ(arena, &.{ snap, "raw.db" }));
        defer db.close();
        try db.exec("CREATE TABLE raw_docs (key TEXT, source TEXT, body BLOB)");
        for ([_]struct { []const u8, []const u8 }{
            .{ "EUW1_1", doc1 },
            .{ "EUW1_3", doc1 },
            .{ "EUW1_4", "not json" },
        }) |d| {
            const body = try store.raw.compress(arena, d[1]);
            try db.run("INSERT INTO raw_docs VALUES (?, 'riot_match', ?)", .{ d[0], store.Blob{ .bytes = body } });
        }
    }
    const dd = try arena.print("{s}/ddragon", .{snap});
    const dd_patch = try arena.print("{s}/16.20", .{dd});
    try Io.Dir.cwd().createDirPath(io, dd_patch);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try arena.print("{s}/champion.json", .{dd_patch}), .data =
        \\{"type":"champion","data":{"Rammus":{"key":"33","stats":{"attackrange":125,"hp":675,
        \\"armor":36,"armorperlevel":4.2,"spellblock":32,"spellblockperlevel":2.05}},
        \\"Brand":{"key":"63","stats":{"attackrange":550,"armor":27,"armorperlevel":4.2,
        \\"spellblock":30,"spellblockperlevel":1.3}}}}
    });
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try arena.print("{s}/item.json", .{dd_patch}), .data =
        \\{"type":"item","data":{"3075":{"name":"Thornmail","stats":{"FlatArmorMod":75,"FlatHPPoolMod":150}},
        \\"3111":{"stats":{"FlatSpellBlockMod":25}},"3340":{"stats":{}}}}
    });

    const sum = try run(gpa, io, snap, dd, null);
    try testing.expectEqual(Summary{ .games = 3, .docs = 2, .bad_docs = 1, .lines = 2, .mismatch = 1, .with_static = 2 }, sum);
    const out = try Io.Dir.cwd().readFileAlloc(io, try arena.print("{s}/{s}", .{ snap, file_name }), arena, .limited(1 << 20));
    try testing.expectEqualStrings(header ++
        "EUW1_1\t0\t30.5\t5000\t2000\t300\t15000\t9000\t1000\t40000\t25\t12\t3000\t0\t0\t1200\t166.713\t84.19325\t125\n" ++
        "EUW1_1\t1\t30.5\tnan\t30000\tnan\tnan\tnan\tnan\tnan\tnan\tnan\tnan\tnan\tnan\tnan\t82.713\t47.2445\t550\n", out);

    const Sink = struct {
        stats: [2]Stats = .{ unknown, unknown },
        fn at(s: *@This(), match_id: []const u8, slot: u8) ?*Stats {
            if (!std.mem.eql(u8, match_id, "EUW1_1") or slot > 1) return null;
            return &s.stats[slot];
        }
    };
    var sink: Sink = .{};
    try testing.expectEqual(@as(?usize, 2), try fill(io, snap, &sink));
    try testing.expectEqual(@as(f32, 30000), sink.stats[1][at(.dmg_magic)]);
    try testing.expect(std.math.isNan(sink.stats[1][at(.dmg_phys)]));
    try testing.expectEqual(@as(f32, 12), sink.stats[0][at(.immobilisations)]);

    var none: Sink = .{};
    try testing.expectEqual(@as(?usize, null), try fill(io, "no-such-snap", &none));
    for (none.stats) |s| for (s) |x| try testing.expect(std.math.isNan(x));
}
