//! Every raw-summary field ranked by draft-time and post-game value (docs/model.md
//! "Field ranking"), on the protocol's games that reached 15:00 and ran 900 s+.
//!   A1: the fields a player sets in champ select for their own seat (spells, runes,
//!       shards, role assignment, account level): shrunk effects within champion-role
//!       on win and the five early outcomes, over the champion-role mean
//!   A2: every end-of-game stat as a target: the share of its variance the draft
//!       explains (champion-role, then lane opponent). Never a champ-select input
//!   B:  each field's win log-loss gain over the game state (team gold diff at 14,
//!       game length): association, not cause. Field class beside it, so consequences
//!       (nexus, surrender) are not read as lessons
//! Ranked on the harness's dev cut; `--final LIST` scores LIST's fields once on test.
//! p-values from the clustered intervals, Benjamini-Hochberg within each table.

const std = @import("std");
const nn = @import("nn");
const store = @import("store");
const rows = @import("rows.zig");
const looks = @import("looks.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");
const analysis = @import("../analysis.zig");
const par = @import("../par.zig");

const Io = std.Io;
const Value = std.json.Value;
const ObjectMap = std.json.ObjectMap;
const log = std.log.scoped(.fields);

pub const usage =
    \\  fields SNAP OUT [--final LIST] [--ref PREDS]  every raw-summary field ranked by
    \\                                  draft-time and post-game value on the dev cut
    \\                                  (lab/fields.zig), tables in OUT; --final scores
    \\                                  LIST's lines (a1|a2|b TAB field) once on test,
    \\                                  A1 also over PREDS (3c-team2.tsv) when given;
    \\                                  final-excl-*.tsv: the test minus test-exclude.tsv
    \\
;

const win: usize = @backingInt(rows.Outcome.win);
const gold14: usize = @backingInt(rows.Outcome.gold14);

pub const Class = enum {
    /// Set in champ select for the player's own seat
    draft,
    /// Ids and constants of the game, not a measurement
    id,
    /// Within a fixed early window (laning phase, before 10 or 15 minutes)
    early,
    /// The game's end or what losing it means: nexus, inhibitors, surrender, length
    result,
    /// Over the whole game
    game,
};

const id_fields = [_][]const u8{
    "p.participantId",  "p.championId",        "p.profileIcon",      "p.teamId",
    "p.item0",          "p.item1",             "p.item2",            "p.item3",
    "p.item4",          "p.item5",             "p.item6",            "p.summoner1Id",
    "p.summoner2Id",    "p.playerSubteamId",   "p.subteamPlacement", "p.placement",
    "p.roleBoundItem",  "p.championTransform", "p.playerAugment1",   "p.playerAugment2",
    "p.playerAugment3", "p.playerAugment4",    "p.playerAugment5",   "p.playerAugment6",
};

const result_words = [_][]const u8{
    "nexus", "inhibitor",      "surrender", "gamelength",   "timeplayed", "turretslost",
    "p.win", "hadafkteammate", "wasafk",    "transgressor", "ignb",
};

const early_words = [_][]const u8{
    "before",      "first10",          "firstxminutes", "early",       "laningphase",
    "15minutes",   "firstblood",       "firsttower",    "firstturret", "initialbuff",
    "initialcrab", "quickfirstturret",
};

/// Riot names suggest an early window but count over the whole game or to 20:00
const not_early = [_][]const u8{ "c.wardTakedownsBefore20M", "c.maxCsAdvantageOnLaneOpponent", "c.maxLevelLeadLaneOpponent" };

pub fn classOf(name: []const u8) Class {
    if (std.mem.startsWith(u8, name, "d.") or std.mem.eql(u8, name, "p.summonerLevel") or
        std.mem.eql(u8, name, "c.playedChampSelectPosition")) return .draft;
    for (id_fields) |f| if (std.mem.eql(u8, f, name)) return .id;
    if (std.mem.startsWith(u8, name, "t.")) return .result;
    var buf: [128]u8 = undefined;
    const lower = std.ascii.lowerString(buf[0..@min(name.len, buf.len)], name[0..@min(name.len, buf.len)]);
    for (result_words) |w| if (std.mem.find(u8, lower, w) != null) return .result;
    for (not_early) |f| if (std.mem.eql(u8, f, name)) return .game;
    for (early_words) |w| if (std.mem.find(u8, lower, w) != null) return .early;
    return .game;
}

/// Champ select fields worked out from the raw summary: spell pair, keystone, rune trees,
/// stat shards, role assignment (status, +10 when played off the assigned role)
const derived_names = [_][]const u8{ "spells", "keystone", "trees", "shards", "assign" };

const assign_status = [_][]const u8{ "PRIMARY", "SECONDARY", "AUTOFILL", "FILL_PRIMARY", "FILL_SECONDARY" };

fn number(v: Value) ?f32 {
    return switch (v) {
        .integer => |i| @floatFromInt(i),
        .float => |f| @floatCast(f),
        .bool => |b| @floatFromInt(@intFromBool(b)),
        else => null,
    };
}

fn int(o: ObjectMap, key: []const u8) ?i64 {
    return switch (o.get(key) orelse return null) {
        .integer => |i| i,
        else => null,
    };
}

fn str(o: ObjectMap, key: []const u8) ?[]const u8 {
    return switch (o.get(key) orelse return null) {
        .string => |s| s,
        else => null,
    };
}

fn obj(o: ObjectMap, key: []const u8) ?ObjectMap {
    return switch (o.get(key) orelse return null) {
        .object => |m| m,
        else => null,
    };
}

fn derived(p: ObjectMap) [derived_names.len]f32 {
    const nan = std.math.nan(f32);
    var out: [derived_names.len]f32 = @splat(nan);
    if (int(p, "summoner1Id")) |a| if (int(p, "summoner2Id")) |b| {
        out[0] = @floatFromInt(@min(a, b) * 100 + @max(a, b));
    };
    if (obj(p, "perks")) |perks| {
        if (perks.get("styles")) |sv| if (sv == .array and sv.array.items.len == 2 and
            sv.array.items[0] == .object and sv.array.items[1] == .object)
        {
            const prim = sv.array.items[0].object;
            const sub = sv.array.items[1].object;
            if (prim.get("selections")) |sel| if (sel == .array and sel.array.items.len > 0 and
                sel.array.items[0] == .object)
            {
                if (int(sel.array.items[0].object, "perk")) |k| out[1] = @floatFromInt(k);
            };
            if (int(prim, "style")) |a| if (int(sub, "style")) |b| {
                out[2] = @floatFromInt(@divTrunc(a, 100) * 100 + @divTrunc(b, 100));
            };
        };
        if (obj(perks, "statPerks")) |s| if (int(s, "offense")) |o| if (int(s, "flex")) |f|
            if (int(s, "defense")) |d| {
                out[3] = @floatFromInt((o - 5000) * 400 + (f - 5000) * 20 + (d - 5000));
            };
    }
    if (str(p, "selectedRolePreferences")) |pref| {
        var it = std.mem.splitScalar(u8, pref, '.');
        _ = it.next();
        const status = it.next() orelse "";
        var code: f32 = 9;
        for (assign_status, 1..) |s, i| if (std.mem.eql(u8, s, status)) {
            code = @floatFromInt(i);
        };
        const played = str(p, "teamPosition") orelse "";
        const assigned = str(p, "positionAssignedByMatchmaking") orelse played;
        if (!std.mem.eql(u8, played, assigned)) code += 10;
        out[4] = code;
    }
    return out;
}

/// Calls sink.put(prefix, key, value) for every number or bool of a participant: its own
/// fields (p.), challenges (c.), missions (m.), PlayerBehavior (b.), derived champ select
/// fields (d.) and its team's objectives (t.<name>.kills, t.<name>.first)
fn walk(sink: anytype, p: ObjectMap, team: ?ObjectMap) !void {
    var it = p.iterator();
    while (it.next()) |e| {
        const k = e.key_ptr.*;
        switch (e.value_ptr.*) {
            .object => |o| {
                const prefix: []const u8 = if (std.mem.eql(u8, k, "challenges"))
                    "c."
                else if (std.mem.eql(u8, k, "missions"))
                    "m."
                else if (std.mem.eql(u8, k, "PlayerBehavior"))
                    "b."
                else
                    continue;
                var ci = o.iterator();
                while (ci.next()) |c| if (number(c.value_ptr.*)) |v| try sink.put(prefix, c.key_ptr.*, v);
            },
            else => if (number(e.value_ptr.*)) |v| try sink.put("p.", k, v),
        }
    }
    for (derived(p), derived_names) |v, name| if (!std.math.isNan(v)) try sink.put("d.", name, v);
    const t = team orelse return;
    const objectives = obj(t, "objectives") orelse return;
    var oi = objectives.iterator();
    while (oi.next()) |e| {
        if (e.value_ptr.* != .object) continue;
        var buf: [64]u8 = undefined;
        for ([_][]const u8{ "kills", "first" }) |what| {
            const v = number(e.value_ptr.object.get(what) orelse continue) orelse continue;
            const key = std.mem.print(&buf, "{s}.{s}", .{ e.key_ptr.*, what }) catch continue;
            try sink.put("t.", key, v);
        }
    }
}

const Player = struct { p: ObjectMap, team: ?ObjectMap };

/// Participants of a match document with their team object
fn players(doc: Value, out: *[10]Player) usize {
    if (doc != .object) return 0;
    const info = obj(doc.object, "info") orelse return 0;
    const ps = info.get("participants") orelse return 0;
    if (ps != .array) return 0;
    const teams: []const Value = if (info.get("teams")) |t| (if (t == .array) t.array.items else &.{}) else &.{};
    var n: usize = 0;
    for (ps.array.items) |pv| {
        if (pv != .object or n == out.len) continue;
        var team: ?ObjectMap = null;
        if (int(pv.object, "teamId")) |team_id| for (teams) |tv| {
            if (tv == .object and (int(tv.object, "teamId") orelse continue) == team_id) team = tv.object;
        };
        out[n] = .{ .p = pv.object, .team = team };
        n += 1;
    }
    return n;
}

const max_name = 128;

fn joinName(buf: *[max_name]u8, prefix: []const u8, key: []const u8) ?[]const u8 {
    return std.mem.print(buf, "{s}{s}", .{ prefix, key }) catch null;
}

const Collect = struct {
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    names: *std.StringArrayHashMapUnmanaged(void),

    fn put(c: Collect, prefix: []const u8, key: []const u8, _: f32) !void {
        var buf: [max_name]u8 = undefined;
        const name = joinName(&buf, prefix, key) orelse return;
        if (c.names.contains(name)) return;
        try c.names.put(c.gpa, try c.arena.dupe(u8, name), {});
    }
};

const Fill = struct {
    index: *const std.StringArrayHashMapUnmanaged(void),
    cols: []const []f32,
    seat: u32,

    fn put(f: Fill, prefix: []const u8, key: []const u8, v: f32) !void {
        var buf: [max_name]u8 = undefined;
        const name = joinName(&buf, prefix, key) orelse return;
        const i = f.index.getIndex(name) orelse return;
        f.cols[i][f.seat] = v;
    }
};

/// One player row of a selected game
const Seat = struct {
    game: u32,
    /// Participant index (0-4 blue, 5-9 red)
    slot: u8,
    side: u1,
    role: u3,
    champion: u32,
    /// Dense champion-role
    cr: u32,
    /// Lane opponent's champion
    opp: u32,
    minutes: f32,
    /// Own team's gold minus the enemy's at 14:00, thousands
    gd14: f32,
    y: [rows.outcome_count]f32,
    fit: bool,
    scored: bool,
};

const Table = struct {
    arena: std.heap.ArenaAllocator,
    seats: []Seat,
    /// Field names in the order of cols
    names: std.StringArrayHashMapUnmanaged(void),
    /// cols[field][seat], NaN when the document lacks it
    cols: [][]f32,
    n_cr: u32,
    /// Role of each dense champion-role
    cr_role: []const u3,
    missing_docs: usize,
    champion_mismatch: usize,

    fn deinit(t: *Table, gpa: std.mem.Allocator) void {
        for (t.cols) |c| gpa.free(c);
        gpa.free(t.cols);
        t.names.deinit(gpa);
        t.arena.deinit();
    }
};

const Seats = struct { seats: []Seat, cr_role: []u3, by_game: []const [10]u32 };

fn selectSeats(gpa: std.mem.Allocator, arena: std.mem.Allocator, d: *const rows.Data, c: harness.Cuts, phase: harness.Phase) !Seats {
    const none = std.math.maxInt(u32);
    const by_game = try arena.alloc([10]u32, d.games.len);
    @memset(by_game, @splat(none));
    const gold = try gpa.alloc([2]f64, d.games.len);
    defer gpa.free(gold);
    @memset(gold, .{ 0, 0 });
    for (d.rows) |r| gold[r.game][r.side] += r.y[gold14];

    var cr_ids: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer cr_ids.deinit(gpa);
    var cr_role: std.ArrayList(u3) = .empty;
    var seats: std.ArrayList(Seat) = .empty;
    for (d.rows) |r| {
        const g = d.games[r.game];
        const fit = harness.visible(phase, c, g);
        const scored = harness.scored(phase, c, g);
        if (!g.timeline15 or !(fit or scored) or r.slot >= 10) continue;
        const gd = gold[r.game][r.side] - gold[r.game][1 - r.side];
        if (std.math.isNan(gd)) continue;
        const role: u3 = @backingInt(r.role);
        const e = try cr_ids.getOrPut(gpa, (@as(u64, r.champion) << 3) | role);
        if (!e.found_existing) {
            e.value_ptr.* = @intCast(cr_role.items.len);
            try cr_role.append(arena, role);
        }
        by_game[r.game][r.slot] = @intCast(seats.items.len);
        try seats.append(arena, .{
            .game = r.game,
            .slot = r.slot,
            .side = r.side,
            .role = role,
            .champion = r.champion,
            .cr = e.value_ptr.*,
            .opp = 0,
            .minutes = @as(f32, @floatFromInt(g.duration_s)) / 60,
            .gd14 = @floatCast(gd / 1000),
            .y = r.y,
            .fit = fit,
            .scored = scored,
        });
    }
    for (by_game) |slots| for (slots) |a| {
        if (a == none) continue;
        for (slots) |b| if (b != none) {
            const sb = seats.items[b];
            if (sb.role == seats.items[a].role and sb.side != seats.items[a].side) seats.items[a].opp = sb.champion;
        };
    };
    return .{ .seats = seats.items, .cr_role = cr_role.items, .by_game = by_game };
}

const Batch = struct {
    gpa: std.mem.Allocator,
    bodies: []const []const u8,
    games: []const u32,
    by_game: []const [10]u32,
    seats: []const Seat,
    index: *const std.StringArrayHashMapUnmanaged(void),
    cols: []const []f32,
    mismatch: *std.atomic.Value(usize),

    fn body(b: *const Batch, i: usize) !void {
        var arena: std.heap.ArenaAllocator = .init(b.gpa);
        defer arena.deinit();
        const a = arena.allocator();
        const json = try store.raw.decompress(a, b.bodies[i]);
        const doc = try std.json.parseFromSliceLeaky(Value, a, json, .{});
        var ps: [10]Player = undefined;
        const n = players(doc, &ps);
        const slots = b.by_game[b.games[i]];
        for (ps[0..n]) |pl| {
            const pid = int(pl.p, "participantId") orelse continue;
            if (pid < 1 or pid > 10) continue;
            const seat = slots[@intCast(pid - 1)];
            if (seat == std.math.maxInt(u32)) continue;
            const champion = int(pl.p, "championId") orelse continue;
            if (champion != b.seats[seat].champion) {
                _ = b.mismatch.fetchAdd(1, .monotonic);
                continue;
            }
            try walk(Fill{ .index = b.index, .cols = b.cols, .seat = seat }, pl.p, pl.team);
        }
    }
};

fn load(gpa: std.mem.Allocator, io: Io, snap: []const u8, d: *const rows.Data, c: harness.Cuts, phase: harness.Phase) !Table {
    var t: Table = .{
        .arena = .init(gpa),
        .seats = &.{},
        .names = .empty,
        .cols = &.{},
        .n_cr = 0,
        .cr_role = &.{},
        .missing_docs = 0,
        .champion_mismatch = 0,
    };
    errdefer t.deinit(gpa);
    const arena = t.arena.allocator();
    const sel = try selectSeats(gpa, arena, d, c, phase);
    t.seats = sel.seats;
    t.n_cr = @intCast(sel.cr_role.len);
    t.cr_role = sel.cr_role;

    var want: std.StringHashMapUnmanaged(u32) = .empty;
    defer want.deinit(gpa);
    for (sel.by_game, 0..) |slots, gi| for (slots) |seat| if (seat != std.math.maxInt(u32)) {
        try want.put(gpa, d.games[gi].match_id, @intCast(gi));
        break;
    };

    const path = try std.fs.path.joinZ(arena, &.{ snap, "raw.db" });
    const db = try store.sqlite.Db.openReadOnly(path);
    defer db.close();
    var q = try db.prepare("SELECT key, body FROM raw_docs WHERE source = 'riot_match'");
    defer q.deinit();

    // Field names from every 40th wanted document, fixed before the parallel fill
    var batch_arena: std.heap.ArenaAllocator = .init(gpa);
    defer batch_arena.deinit();
    const batch_len = 4096;
    var bodies: std.ArrayList([]const u8) = .empty;
    defer bodies.deinit(gpa);
    var games: std.ArrayList(u32) = .empty;
    defer games.deinit(gpa);
    var seen: usize = 0;
    try q.bind(.{});
    while (try q.step()) {
        if (!want.contains(q.bytes(0))) continue;
        seen += 1;
        if (seen % 40 != 0) continue;
        const ba = batch_arena.allocator();
        const json = try store.raw.decompress(ba, q.bytes(1));
        const doc = try std.json.parseFromSliceLeaky(Value, ba, json, .{});
        var ps: [10]Player = undefined;
        for (ps[0..players(doc, &ps)]) |pl| try walk(Collect{ .gpa = gpa, .arena = arena, .names = &t.names }, pl.p, pl.team);
        _ = batch_arena.reset(.retain_capacity);
    }
    const Sort = struct {
        keys: [][]const u8,
        pub fn lessThan(s: @This(), a: usize, b: usize) bool {
            return std.mem.lessThan(u8, s.keys[a], s.keys[b]);
        }
    };
    t.names.sort(Sort{ .keys = t.names.keys() });
    log.info("{d} fields from {d} sampled documents", .{ t.names.count(), seen / 40 });

    t.cols = try gpa.alloc([]f32, t.names.count());
    for (t.cols) |*col| col.* = &.{};
    for (t.cols) |*col| {
        col.* = try gpa.alloc(f32, t.seats.len);
        @memset(col.*, std.math.nan(f32));
    }

    var mismatch: std.atomic.Value(usize) = .init(0);
    var found: usize = 0;
    try q.bind(.{});
    var more = true;
    while (more) {
        _ = batch_arena.reset(.retain_capacity);
        bodies.clearRetainingCapacity();
        games.clearRetainingCapacity();
        while (bodies.items.len < batch_len) {
            more = try q.step();
            if (!more) break;
            const g = want.get(q.bytes(0)) orelse continue;
            try bodies.append(gpa, try batch_arena.allocator().dupe(u8, q.bytes(1)));
            try games.append(gpa, g);
        }
        found += bodies.items.len;
        const b: Batch = .{
            .gpa = std.heap.smp_allocator,
            .bodies = bodies.items,
            .games = games.items,
            .by_game = sel.by_game,
            .seats = t.seats,
            .index = &t.names,
            .cols = t.cols,
            .mismatch = &mismatch,
        };
        try par.forEach(io, bodies.items.len, &b, Batch.body);
    }
    t.missing_docs = want.count() - found;
    t.champion_mismatch = mismatch.load(.monotonic);
    log.info("{d} games, {d} seats; {d} games without a raw summary, {d} seats whose champion differs", .{
        found, t.seats.len, t.missing_docs, t.champion_mismatch,
    });
    return t;
}

// ---- statistics ----

/// Standard normal upper tail, Abramowitz and Stegun 7.1.26 (error under 1.5e-7)
pub fn upperTail(z: f64) f64 {
    const x = @abs(z) / std.math.sqrt2;
    const k = 1 / (1 + 0.3275911 * x);
    const poly = k * (0.254829592 + k * (-0.284496736 + k * (1.421413741 + k * (-1.453152027 + k * 1.061405429))));
    const erfc = poly * @exp(-x * x);
    return if (z >= 0) erfc / 2 else 1 - erfc / 2;
}

/// Two-sided p of a gain with a 95% half-width
fn pValue(g: analysis.Gain) f64 {
    if (g.half_width <= 0) return if (g.mean == 0) 1 else 0;
    return 2 * upperTail(@abs(g.mean) / (g.half_width / 1.96));
}

/// Benjamini-Hochberg adjusted p-values (q), in place of `p`
pub fn adjustBH(gpa: std.mem.Allocator, p: []f64) !void {
    const order = try gpa.alloc(usize, p.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = i;
    std.mem.sort(usize, order, p, struct {
        fn lt(ps: []f64, a: usize, b: usize) bool {
            return ps[a] < ps[b];
        }
    }.lt);
    const m: f64 = @floatFromInt(p.len);
    var running: f64 = 1;
    var k = p.len;
    while (k > 0) : (k -= 1) {
        const i = order[k - 1];
        running = @min(running, p[i] * m / @as(f64, @floatFromInt(k)));
        p[i] = running;
    }
}

/// Paired per-row differences summed per game (seats are in game order)
fn paired(seats: []const Seat, idx: []const u32, before: []const f64, after: []const f64) analysis.Gain {
    var sums: analysis.PairedSums = .{};
    var i: usize = 0;
    while (i < idx.len) {
        const g = seats[idx[i]].game;
        var dsum: f64 = 0;
        var n: f64 = 0;
        while (i < idx.len and seats[idx[i]].game == g) : (i += 1) {
            if (std.math.isNan(before[i]) or std.math.isNan(after[i])) continue;
            dsum += before[i] - after[i];
            n += 1;
        }
        if (n > 0) sums.add(dsum, n);
    }
    if (sums.games == 0) return .{ .mean = 0, .half_width = 0 };
    return sums.gain();
}

// ---- lens B: win over the game state ----

const n_base = 5;
const per_role = 3;
const n_params = n_base + 5 * per_role;
const z_clip = 5;
const min_cell_rows = 30;
const ridge = 1.0;

fn baseFeatures(s: Seat) [n_base]f64 {
    const g: f64 = s.gd14;
    const l: f64 = (s.minutes - 30) / 10;
    return .{ 1, g, g * l, l, l * l };
}

/// Per champion-role mean and sd of a column over fit seats, role's when a cell is thin
const Standard = struct {
    mean: []f64,
    sd: []f64,

    fn init(gpa: std.mem.Allocator, t: *const Table, col: []const f32, per_minute: bool) !Standard {
        const n = t.n_cr;
        const buf = try gpa.alloc(f64, 3 * n + 15);
        defer gpa.free(buf);
        @memset(buf, 0);
        const cn = buf[0..n];
        const cs = buf[n .. 2 * n];
        const cq = buf[2 * n .. 3 * n];
        const rn = buf[3 * n ..][0..5];
        const rs = buf[3 * n + 5 ..][0..5];
        const rq = buf[3 * n + 10 ..][0..5];
        const role_of = t.cr_role;
        for (t.seats, col) |s, v| {
            if (!s.fit or std.math.isNan(v)) continue;
            const x: f64 = if (per_minute) v / s.minutes else v;
            cn[s.cr] += 1;
            cs[s.cr] += x;
            cq[s.cr] += x * x;
            rn[s.role] += 1;
            rs[s.role] += x;
            rq[s.role] += x * x;
        }
        const st: Standard = .{ .mean = try gpa.alloc(f64, n), .sd = try gpa.alloc(f64, n) };
        for (0..n) |i| {
            const r = role_of[i];
            const use_cell = cn[i] >= min_cell_rows;
            const k = if (use_cell) cn[i] else rn[r];
            const s1 = if (use_cell) cs[i] else rs[r];
            const s2 = if (use_cell) cq[i] else rq[r];
            const m = if (k > 0) s1 / k else 0;
            st.mean[i] = m;
            st.sd[i] = if (k > 1) @sqrt(@max(s2 / k - m * m, 0)) else 0;
        }
        return st;
    }

    fn deinit(s: Standard, gpa: std.mem.Allocator) void {
        gpa.free(s.mean);
        gpa.free(s.sd);
    }

    fn z(s: Standard, cr: u32, x: f64) f64 {
        if (s.sd[cr] <= 1e-12) return 0;
        return std.math.clamp((x - s.mean[cr]) / s.sd[cr], -z_clip, z_clip);
    }
};

const Active = struct { ix: [n_base + per_role]u8, x: [n_base + per_role]f64, n: usize };

const sigmoid = nn.sigmoid;

/// Solves a·x = b (n x n, row-major) by Gaussian elimination with partial pivoting
fn solve(comptime n: usize, a: *[n][n]f64, b: *[n]f64) void {
    for (0..n) |col| {
        var piv = col;
        for (col + 1..n) |r| if (@abs(a[r][col]) > @abs(a[piv][col])) {
            piv = r;
        };
        std.mem.swap([n]f64, &a[col], &a[piv]);
        std.mem.swap(f64, &b[col], &b[piv]);
        const d = a[col][col];
        if (@abs(d) < 1e-300) continue;
        for (col + 1..n) |r| {
            const f = a[r][col] / d;
            if (f == 0) continue;
            for (col..n) |k| a[r][k] -= f * a[col][k];
            b[r] -= f * b[col];
        }
    }
    var i = n;
    while (i > 0) {
        i -= 1;
        var s = b[i];
        for (i + 1..n) |k| s -= a[i][k] * b[k];
        b[i] = if (@abs(a[i][i]) < 1e-300) 0 else s / a[i][i];
    }
}

/// Logistic fit by Newton steps with a small ridge on the field terms
fn fitLogistic(ctx: anytype, seats: []const Seat, beta: *[n_params]f64) void {
    for (0..25) |_| {
        var h: [n_params][n_params]f64 = @splat(@splat(0));
        var g: [n_params]f64 = @splat(0);
        for (seats, 0..) |s, i| {
            if (!s.fit) continue;
            const a = ctx.active(s, i);
            var e: f64 = 0;
            for (a.ix[0..a.n], a.x[0..a.n]) |j, x| e += beta[j] * x;
            const p = sigmoid(e);
            const w = p * (1 - p);
            const r = s.y[win] - p;
            for (a.ix[0..a.n], a.x[0..a.n]) |j, xj| {
                g[j] += r * xj;
                for (a.ix[0..a.n], a.x[0..a.n]) |k, xk| h[j][k] += w * xj * xk;
            }
        }
        for (n_base..n_params) |j| {
            h[j][j] += ridge;
            g[j] -= ridge * beta[j];
        }
        solve(n_params, &h, &g);
        var step: f64 = 0;
        for (beta, g) |*b, d| {
            b.* += d;
            step = @max(step, @abs(d));
        }
        if (step < 1e-7) break;
    }
}

fn logLoss(y: f32, p: f64) f64 {
    const q = std.math.clamp(p, 1e-9, 1 - 1e-9);
    return if (y > 0.5) -@log(q) else -@log(1 - q);
}

const BaseCtx = struct {
    fn active(_: BaseCtx, s: Seat, _: usize) Active {
        var a: Active = .{ .ix = undefined, .x = undefined, .n = n_base };
        for (baseFeatures(s), 0..) |x, j| {
            a.ix[j] = @intCast(j);
            a.x[j] = x;
        }
        return a;
    }
};

const FieldCtx = struct {
    col: []const f32,
    raw: Standard,
    pm: Standard,

    fn active(c: FieldCtx, s: Seat, i: usize) Active {
        var a = BaseCtx.active(.{}, s, i);
        const v = c.col[i];
        const off = n_base + @as(usize, s.role) * per_role;
        const missing = std.math.isNan(v);
        const vals = [per_role]f64{
            if (missing) 0 else c.raw.z(s.cr, v),
            if (missing) 0 else c.pm.z(s.cr, v / s.minutes),
            @floatFromInt(@intFromBool(missing)),
        };
        for (vals, 0..) |x, k| {
            a.ix[n_base + k] = @intCast(off + k);
            a.x[n_base + k] = x;
        }
        a.n = n_base + per_role;
        return a;
    }
};

fn predict(ctx: anytype, s: Seat, i: usize, beta: *const [n_params]f64) f64 {
    const a = ctx.active(s, i);
    var e: f64 = 0;
    for (a.ix[0..a.n], a.x[0..a.n]) |j, x| e += beta[j] * x;
    return sigmoid(e);
}

const BResult = struct {
    field: u32,
    coverage: f64,
    gain: analysis.Gain,
    base_loss: f64,
    /// Mean within-champion-role z of winners minus losers' (fit seats)
    win_minus_loss: f64,
    p: f64 = 1,
    q: f64 = 1,
};

const LensB = struct {
    gpa: std.mem.Allocator,
    t: *const Table,
    fields: []const u32,
    base_beta: [n_params]f64,
    /// Scored seat indexes and their base log loss
    scored: []const u32,
    base_loss: []const f64,
    out: []BResult,

    fn body(l: *const LensB, k: usize) !void {
        const f = l.fields[k];
        const col = l.t.cols[f];
        var n_fit: f64 = 0;
        var present: f64 = 0;
        for (l.t.seats, col) |s, v| if (s.fit) {
            n_fit += 1;
            present += @floatFromInt(@intFromBool(!std.math.isNan(v)));
        };
        const raw = try Standard.init(l.gpa, l.t, col, false);
        defer raw.deinit(l.gpa);
        const pm = try Standard.init(l.gpa, l.t, col, true);
        defer pm.deinit(l.gpa);
        const ctx: FieldCtx = .{ .col = col, .raw = raw, .pm = pm };
        var beta = l.base_beta;
        fitLogistic(ctx, l.t.seats, &beta);
        const after = try l.gpa.alloc(f64, l.scored.len);
        defer l.gpa.free(after);
        for (l.scored, after) |si, *a| a.* = logLoss(l.t.seats[si].y[win], predict(ctx, l.t.seats[si], si, &beta));
        var zs: [2][2]f64 = @splat(.{ 0, 0 });
        for (l.t.seats, col) |s, v| if (s.fit and !std.math.isNan(v)) {
            const won: usize = @intFromBool(s.y[win] > 0.5);
            zs[won][0] += raw.z(s.cr, v);
            zs[won][1] += 1;
        };
        l.out[k] = .{
            .field = f,
            .coverage = present / @max(n_fit, 1),
            .gain = paired(l.t.seats, l.scored, l.base_loss, after),
            .base_loss = analysis.mean(l.base_loss),
            .win_minus_loss = zs[1][0] / @max(zs[1][1], 1) - zs[0][0] / @max(zs[0][1], 1),
        };
    }
};

fn scoredSeats(gpa: std.mem.Allocator, t: *const Table) ![]u32 {
    var out: std.ArrayList(u32) = .empty;
    for (t.seats, 0..) |s, i| if (s.scored) try out.append(gpa, @intCast(i));
    return out.toOwnedSlice(gpa);
}

fn lensB(gpa: std.mem.Allocator, io: Io, t: *const Table, fields: []const u32) ![]BResult {
    var beta: [n_params]f64 = @splat(0);
    fitLogistic(BaseCtx{}, t.seats, &beta);
    const scored = try scoredSeats(gpa, t);
    defer gpa.free(scored);
    const base_loss = try gpa.alloc(f64, scored.len);
    defer gpa.free(base_loss);
    for (scored, base_loss) |si, *b| b.* = logLoss(t.seats[si].y[win], predict(BaseCtx{}, t.seats[si], si, &beta));
    log.info("lens B base: {d} scored seats, log loss {d:.4}; gold diff at 14 {d:.3} per 1k", .{
        scored.len, analysis.mean(base_loss), beta[1],
    });
    const out = try gpa.alloc(BResult, fields.len);
    errdefer gpa.free(out);
    const l: LensB = .{
        .gpa = std.heap.smp_allocator,
        .t = t,
        .fields = fields,
        .base_beta = beta,
        .scored = scored,
        .base_loss = base_loss,
        .out = out,
    };
    try par.forEach(io, fields.len, &l, LensB.body);
    const p = try gpa.alloc(f64, out.len);
    defer gpa.free(p);
    for (out, p) |*r, *pi| {
        r.p = pValue(r.gain);
        pi.* = r.p;
    }
    try adjustBH(gpa, p);
    for (out, p) |*r, q| r.q = q;
    return out;
}

// ---- lens A2: the stat as a target of the draft ----

const A2Result = struct {
    field: u32,
    rows: usize,
    /// % of the role-mean MSE removed by champion-role, by the lane opponent after it,
    /// and by both
    champion: analysis.Gain,
    lane: analysis.Gain,
    draft: analysis.Gain,
    p: f64 = 1,
    q: f64 = 1,
};

const LensA2 = struct {
    gpa: std.mem.Allocator,
    t: *const Table,
    fields: []const u32,
    scored: []const u32,
    out: []A2Result,

    fn body(l: *const LensA2, k: usize) !void {
        const gpa = l.gpa;
        const t = l.t;
        const col = t.cols[l.fields[k]];
        // Role means
        var rn: [5]f64 = @splat(0);
        var rs: [5]f64 = @splat(0);
        for (t.seats, col) |s, v| if (s.fit and !std.math.isNan(v)) {
            rn[s.role] += 1;
            rs[s.role] += v;
        };
        var rm: [5]f64 = undefined;
        for (&rm, rn, rs) |*m, n, s| m.* = if (n > 0) s / n else 0;

        // Champion-role cells, shrunk per role
        const n = t.n_cr;
        const cell = try gpa.alloc(f64, 4 * n);
        defer gpa.free(cell);
        @memset(cell, 0);
        const sxr = cell[0..n];
        const cnt = cell[n .. 2 * n];
        const sq = cell[2 * n .. 3 * n];
        const eff = cell[3 * n ..];
        for (t.seats, col) |s, v| {
            if (!s.fit or std.math.isNan(v)) continue;
            const r = v - rm[s.role];
            sxr[s.cr] += r;
            cnt[s.cr] += 1;
            sq[s.cr] += r * r;
        }
        try shrinkCells(gpa, t.cr_role, sxr, cnt, sq, eff);

        // Lane opponent cells on the residual: (champion-role, opponent)
        var pairs: std.AutoHashMapUnmanaged(u64, u32) = .empty;
        defer pairs.deinit(gpa);
        var p_sxr: std.ArrayList(f64) = .empty;
        defer p_sxr.deinit(gpa);
        var p_cnt: std.ArrayList(f64) = .empty;
        defer p_cnt.deinit(gpa);
        var p_sq: std.ArrayList(f64) = .empty;
        defer p_sq.deinit(gpa);
        var p_role: std.ArrayList(u3) = .empty;
        defer p_role.deinit(gpa);
        for (t.seats, col) |s, v| {
            if (!s.fit or std.math.isNan(v)) continue;
            const e = try pairs.getOrPut(gpa, (@as(u64, s.cr) << 32) | s.opp);
            if (!e.found_existing) {
                e.value_ptr.* = @intCast(p_sxr.items.len);
                try p_sxr.append(gpa, 0);
                try p_cnt.append(gpa, 0);
                try p_sq.append(gpa, 0);
                try p_role.append(gpa, s.role);
            }
            const r = v - rm[s.role] - eff[s.cr];
            p_sxr.items[e.value_ptr.*] += r;
            p_cnt.items[e.value_ptr.*] += 1;
            p_sq.items[e.value_ptr.*] += r * r;
        }
        const p_eff = try gpa.alloc(f64, p_sxr.items.len);
        defer gpa.free(p_eff);
        try shrinkCells(gpa, p_role.items, p_sxr.items, p_cnt.items, p_sq.items, p_eff);

        const se = try gpa.alloc(f64, 3 * l.scored.len);
        defer gpa.free(se);
        const se0 = se[0..l.scored.len];
        const se1 = se[l.scored.len .. 2 * l.scored.len];
        const se2 = se[2 * l.scored.len ..];
        var used: usize = 0;
        var base_sum: f64 = 0;
        for (l.scored, se0, se1, se2) |si, *a, *b, *c| {
            const s = t.seats[si];
            const v = col[si];
            if (std.math.isNan(v)) {
                a.* = std.math.nan(f64);
                b.* = std.math.nan(f64);
                c.* = std.math.nan(f64);
                continue;
            }
            const e1 = eff[s.cr];
            const e2 = if (pairs.get((@as(u64, s.cr) << 32) | s.opp)) |pi| p_eff[pi] else 0;
            const r0 = v - rm[s.role];
            a.* = r0 * r0;
            b.* = (r0 - e1) * (r0 - e1);
            c.* = (r0 - e1 - e2) * (r0 - e1 - e2);
            used += 1;
            base_sum += a.*;
        }
        const base_mse = base_sum / @as(f64, @floatFromInt(@max(used, 1)));
        const pct = struct {
            fn f(g: analysis.Gain, m: f64) analysis.Gain {
                if (m <= 0) return .{ .mean = 0, .half_width = 0 };
                return .{ .mean = 100 * g.mean / m, .half_width = 100 * g.half_width / m };
            }
        }.f;
        l.out[k] = .{
            .field = l.fields[k],
            .rows = used,
            .champion = pct(paired(t.seats, l.scored, se0, se1), base_mse),
            .lane = pct(paired(t.seats, l.scored, se1, se2), base_mse),
            .draft = pct(paired(t.seats, l.scored, se0, se2), base_mse),
        };
    }
};

/// Shrunk cell effects with a method-of-moments prior per role (analysis.Prior); sigma2
/// is the role's pooled within-cell variance
fn shrinkCells(gpa: std.mem.Allocator, role_of: []const u3, sxr: []const f64, cnt: []const f64, sq: []const f64, eff: []f64) !void {
    @memset(eff, 0);
    for (0..5) |r| {
        var idx: std.ArrayList(usize) = .empty;
        defer idx.deinit(gpa);
        var within: f64 = 0;
        var dof: f64 = 0;
        for (role_of, 0..) |ro, i| if (ro == r and cnt[i] > 0) {
            try idx.append(gpa, i);
            within += sq[i] - sxr[i] * sxr[i] / cnt[i];
            dof += cnt[i] - 1;
        };
        if (dof <= 0) continue;
        const sigma2 = within / dof;
        const xs = try gpa.alloc(f64, 2 * idx.items.len);
        defer gpa.free(xs);
        for (idx.items, 0..) |i, j| {
            xs[j] = sxr[i];
            xs[idx.items.len + j] = cnt[i];
        }
        const prior = analysis.Prior.estimate(xs[0..idx.items.len], xs[idx.items.len..], null, sigma2);
        for (idx.items) |i| eff[i] = prior.effect(sxr[i], cnt[i]);
    }
}

fn lensA2(gpa: std.mem.Allocator, io: Io, t: *const Table, fields: []const u32) ![]A2Result {
    const scored = try scoredSeats(gpa, t);
    defer gpa.free(scored);
    const out = try gpa.alloc(A2Result, fields.len);
    errdefer gpa.free(out);
    const l: LensA2 = .{ .gpa = std.heap.smp_allocator, .t = t, .fields = fields, .scored = scored, .out = out };
    try par.forEach(io, fields.len, &l, LensA2.body);
    const p = try gpa.alloc(f64, out.len);
    defer gpa.free(p);
    for (out, p) |*r, *pi| {
        r.p = pValue(r.draft);
        pi.* = r.p;
    }
    try adjustBH(gpa, p);
    for (out, p) |*r, q| r.q = q;
    return out;
}

// ---- lens A1: champ select fields on the protocol's outcomes ----

/// Prior strength (rows) pulling a champion-role win rate to its role's, as the harness
const win_prior = 1000;
const level_buckets = 10;

const A1Result = struct {
    field: u32,
    outcome: usize,
    rows: usize,
    /// Continuous: % of base MSE; win: log loss, nats per 1000 rows
    gain: analysis.Gain,
    /// Over the reference predictions (3c-team2) on test, when given
    over_ref: ?analysis.Gain = null,
    /// Largest and smallest shrunk category effect (outcome units; win in pp)
    top: f64 = 0,
    top_label: f64 = 0,
    bottom: f64 = 0,
    bottom_label: f64 = 0,
    p: f64 = 1,
    q: f64 = 1,
};

/// Reference test predictions by (match id, slot, outcome)
const Ref = std.StringHashMapUnmanaged(f32);

/// null when it doesn't fit buf: no game has so long a match id
fn refKey(buf: []u8, match_id: []const u8, slot: usize, outcome: usize) ?[]const u8 {
    return std.mem.print(buf, "{s}/{d}/{d}", .{ match_id, slot, outcome }) catch null;
}

fn loadRef(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, path: []const u8) !Ref {
    const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .unlimited);
    var ref: Ref = .empty;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var f = std.mem.splitScalar(u8, line, '\t');
        const id = f.next() orelse continue;
        const slot = std.fmt.parseInt(usize, f.next() orelse continue, 10) catch continue;
        const name = f.next() orelse continue;
        _ = f.next();
        const pred = std.fmt.parseFloat(f32, f.next() orelse continue) catch continue;
        const o = std.meta.stringToEnum(rows.Outcome, name) orelse continue;
        var buf: [96]u8 = undefined;
        try ref.put(gpa, try arena.dupe(u8, refKey(&buf, id, slot, @backingInt(o)) orelse continue), pred);
    }
    return ref;
}

/// Category of a seat for an A1 field: its code, account level as a train decile
fn categories(gpa: std.mem.Allocator, t: *const Table, col: []const f32, bucket_level: bool) ![]f32 {
    const out = try gpa.dupe(f32, col);
    if (!bucket_level) return out;
    var vals: std.ArrayList(f32) = .empty;
    defer vals.deinit(gpa);
    for (t.seats, col) |s, v| if (s.fit and !std.math.isNan(v)) try vals.append(gpa, v);
    if (vals.items.len == 0) return out;
    std.mem.sort(f32, vals.items, {}, std.sort.asc(f32));
    var edges: [level_buckets - 1]f32 = undefined;
    for (&edges, 1..) |*e, i| e.* = vals.items[vals.items.len * i / level_buckets];
    for (out) |*v| if (!std.math.isNan(v.*)) {
        var b: f32 = 0;
        for (edges) |e| b += @floatFromInt(@intFromBool(v.* >= e));
        v.* = b;
    };
    return out;
}

fn lensA1(
    gpa: std.mem.Allocator,
    t: *const Table,
    d: *const rows.Data,
    fields: []const u32,
    ref: ?*const Ref,
) ![]A1Result {
    const scored = try scoredSeats(gpa, t);
    defer gpa.free(scored);
    var out: std.ArrayList(A1Result) = .empty;
    errdefer out.deinit(gpa);

    // Champion-role means per outcome on fit seats; win shrunk to the role's
    const n = t.n_cr;
    const base = try gpa.alloc([rows.outcome_count]f64, n);
    defer gpa.free(base);
    {
        const cs = try gpa.alloc([rows.outcome_count][2]f64, n);
        defer gpa.free(cs);
        @memset(cs, @splat(.{ 0, 0 }));
        var rs: [5][rows.outcome_count][2]f64 = @splat(@splat(.{ 0, 0 }));
        for (t.seats) |s| {
            if (!s.fit) continue;
            for (s.y, 0..) |y, o| if (!std.math.isNan(y)) {
                cs[s.cr][o][0] += y;
                cs[s.cr][o][1] += 1;
                rs[s.role][o][0] += y;
                rs[s.role][o][1] += 1;
            };
        }
        for (base, cs, t.cr_role) |*b, c, r| for (b, c, rs[r], 0..) |*bo, co, ro, o| {
            const role_mean = ro[0] / @max(ro[1], 1);
            bo.* = if (o == win)
                (co[0] + win_prior * role_mean) / (co[1] + win_prior)
            else if (co[1] > 0) co[0] / co[1] else role_mean;
        };
    }

    for (fields) |f| {
        const name = t.names.keys()[f];
        const cat = try categories(gpa, t, t.cols[f], std.mem.eql(u8, name, "p.summonerLevel"));
        defer gpa.free(cat);
        for (0..rows.outcome_count) |o| {
            // Level 1: (role, category), one prior over every role's cells (few categories);
            // level 2: (champion-role, category) on its residual, a prior per role
            var c1: std.AutoArrayHashMapUnmanaged(u64, [3]f64) = .empty;
            defer c1.deinit(gpa);
            var c2: std.AutoArrayHashMapUnmanaged(u64, [3]f64) = .empty;
            defer c2.deinit(gpa);
            const key1 = struct {
                fn of(s: Seat, c: f32) u64 {
                    return (@as(u64, @as(u32, @trunc(c))) << 3) | s.role;
                }
            }.of;
            const key2 = struct {
                fn of(s: Seat, c: f32) u64 {
                    return (@as(u64, @as(u32, @trunc(c))) << 32) | s.cr;
                }
            }.of;
            for (t.seats, cat) |s, c| {
                const y = s.y[o];
                if (!s.fit or std.math.isNan(c) or std.math.isNan(y)) continue;
                const r = y - base[s.cr][o];
                const e = try c1.getOrPutValue(gpa, key1(s, c), .{ 0, 0, 0 });
                e.value_ptr.* = .{ e.value_ptr[0] + r, e.value_ptr[1] + 1, e.value_ptr[2] + r * r };
            }
            const e1 = try effects(gpa, c1.values(), null);
            defer gpa.free(e1);
            for (t.seats, cat) |s, c| {
                const y = s.y[o];
                if (!s.fit or std.math.isNan(c) or std.math.isNan(y)) continue;
                const r = y - base[s.cr][o] - e1[c1.getIndex(key1(s, c)).?];
                const e = try c2.getOrPutValue(gpa, key2(s, c), .{ 0, 0, 0 });
                e.value_ptr.* = .{ e.value_ptr[0] + r, e.value_ptr[1] + 1, e.value_ptr[2] + r * r };
            }
            const roles2 = try gpa.alloc(u3, c2.count());
            defer gpa.free(roles2);
            for (c2.keys(), roles2) |k, *r| r.* = t.cr_role[@as(u32, @truncate(k))];
            const e2 = try effects(gpa, c2.values(), roles2);
            defer gpa.free(e2);

            const before = try gpa.alloc(f64, 3 * scored.len);
            defer gpa.free(before);
            const after = before[scored.len .. 2 * scored.len];
            const after_ref = before[2 * scored.len ..];
            var ref_before: std.ArrayList(f64) = .empty;
            defer ref_before.deinit(gpa);
            var used: usize = 0;
            var base_sum: f64 = 0;
            for (scored, 0..) |si, j| {
                const s = t.seats[si];
                const y = s.y[o];
                const c = cat[si];
                if (std.math.isNan(y) or std.math.isNan(c)) {
                    before[j] = std.math.nan(f64);
                    after[j] = std.math.nan(f64);
                    after_ref[j] = std.math.nan(f64);
                    continue;
                }
                var adj: f64 = 0;
                if (c1.getIndex(key1(s, c))) |i| adj += e1[i];
                if (c2.getIndex(key2(s, c))) |i| adj += e2[i];
                const b = base[s.cr][o];
                if (o == win) {
                    before[j] = logLoss(y, b);
                    after[j] = logLoss(y, std.math.clamp(b + adj, 0.02, 0.98));
                } else {
                    before[j] = (y - b) * (y - b);
                    after[j] = (y - b - adj) * (y - b - adj);
                }
                used += 1;
                base_sum += before[j];
                after_ref[j] = std.math.nan(f64);
                if (ref) |rf| if (o != win) {
                    var buf: [96]u8 = undefined;
                    const g = d.games[s.game];
                    const key = refKey(&buf, g.match_id, s.slot, o) orelse continue;
                    if (rf.get(key)) |pr| {
                        try ref_before.append(gpa, (y - pr) * (y - pr));
                        after_ref[j] = (y - pr - adj) * (y - pr - adj);
                    }
                };
            }
            const base_mean = base_sum / @as(f64, @floatFromInt(@max(used, 1)));
            var g = paired(t.seats, scored, before, after);
            if (o == win) {
                g = .{ .mean = 1000 * g.mean, .half_width = 1000 * g.half_width };
            } else if (base_mean > 0) {
                g = .{ .mean = 100 * g.mean / base_mean, .half_width = 100 * g.half_width / base_mean };
            }
            var res: A1Result = .{ .field = f, .outcome = o, .rows = used, .gain = g };
            if (ref != null and o != win and ref_before.items.len > 0) {
                // Rows with a reference prediction, its own squared errors as the base
                const rb = try gpa.alloc(f64, scored.len);
                defer gpa.free(rb);
                var k: usize = 0;
                var rsum: f64 = 0;
                for (after_ref, rb) |a, *bv| {
                    if (std.math.isNan(a)) {
                        bv.* = std.math.nan(f64);
                        continue;
                    }
                    bv.* = ref_before.items[k];
                    rsum += bv.*;
                    k += 1;
                }
                const rm = rsum / @as(f64, @floatFromInt(k));
                const rg = paired(t.seats, scored, rb, after_ref);
                res.over_ref = .{ .mean = 100 * rg.mean / rm, .half_width = 100 * rg.half_width / rm };
            }
            // Largest category effects at level 1, pooled over roles by rows
            var by_cat: std.AutoArrayHashMapUnmanaged(u32, [2]f64) = .empty;
            defer by_cat.deinit(gpa);
            for (c1.keys(), c1.values(), e1) |k, v, e| {
                const ent = try by_cat.getOrPutValue(gpa, @intCast(k >> 3), .{ 0, 0 });
                ent.value_ptr.* = .{ ent.value_ptr[0] + e * v[1], ent.value_ptr[1] + v[1] };
            }
            var first = true;
            for (by_cat.keys(), by_cat.values()) |k, v| {
                if (v[1] < 1000) continue;
                const e = v[0] / v[1] * @as(f64, if (o == win) 100 else 1);
                if (first or e > res.top) {
                    res.top = e;
                    res.top_label = @floatFromInt(k);
                }
                if (first or e < res.bottom) {
                    res.bottom = e;
                    res.bottom_label = @floatFromInt(k);
                }
                first = false;
            }
            try out.append(gpa, res);
        }
    }
    const p = try gpa.alloc(f64, out.items.len);
    defer gpa.free(p);
    for (out.items, p) |*r, *pi| {
        r.p = pValue(r.gain);
        pi.* = r.p;
    }
    try adjustBH(gpa, p);
    for (out.items, p) |*r, q| r.q = q;
    return out.toOwnedSlice(gpa);
}

/// Shrunk effects of [sum r, n, sum r^2] cells: one prior over all cells, or one per role
fn effects(gpa: std.mem.Allocator, cells: []const [3]f64, roles: ?[]const u3) ![]f64 {
    const sxr = try gpa.alloc(f64, 3 * cells.len);
    defer gpa.free(sxr);
    const cnt = sxr[cells.len .. 2 * cells.len];
    const sq = sxr[2 * cells.len ..];
    for (cells, 0..) |c, i| {
        sxr[i] = c[0];
        cnt[i] = c[1];
        sq[i] = c[2];
    }
    const eff = try gpa.alloc(f64, cells.len);
    errdefer gpa.free(eff);
    if (roles) |r| {
        try shrinkCells(gpa, r, sxr[0..cells.len], cnt, sq, eff);
    } else {
        const all = try gpa.alloc(u3, cells.len);
        defer gpa.free(all);
        @memset(all, 0);
        try shrinkCells(gpa, all, sxr[0..cells.len], cnt, sq, eff);
    }
    return eff;
}

// ---- output ----

fn writeB(w: *Io.Writer, t: *const Table, res: []const BResult) !void {
    try w.writeAll("field\tclass\tcoverage\tgain_mnats\thalf_width\tpct_of_base\twin_minus_loss_sd\tp\tq_bh\n");
    for (res) |r| {
        const name = t.names.keys()[r.field];
        try w.print("{s}\t{t}\t{d:.3}\t{d:.4}\t{d:.4}\t{d:.3}\t{d:.2}\t{e:.2}\t{e:.2}\n", .{
            name,               classOf(name),            r.coverage,
            1000 * r.gain.mean, 1000 * r.gain.half_width, 100 * r.gain.mean / r.base_loss,
            r.win_minus_loss,   r.p,                      r.q,
        });
    }
}

fn writeA2(w: *Io.Writer, t: *const Table, res: []const A2Result) !void {
    try w.writeAll("field\tclass\trows\tdraft_pct\tdraft_hw\tchampion_pct\tchampion_hw\tlane_pct\tlane_hw\tp\tq_bh\n");
    for (res) |r| {
        const name = t.names.keys()[r.field];
        try w.print("{s}\t{t}\t{d}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{e:.2}\t{e:.2}\n", .{
            name,                  classOf(name),      r.rows,
            r.draft.mean,          r.draft.half_width, r.champion.mean,
            r.champion.half_width, r.lane.mean,        r.lane.half_width,
            r.p,                   r.q,
        });
    }
}

fn writeA1(w: *Io.Writer, t: *const Table, res: []const A1Result) !void {
    try w.writeAll("field\toutcome\trows\tgain\thalf_width\tunit\tover_ref\tover_ref_hw\ttop_cat\ttop_effect\tbottom_cat\tbottom_effect\tp\tq_bh\n");
    for (res) |r| {
        const o: rows.Outcome = @fromBackingInt(@as(u3, @intCast(r.outcome)));
        try w.print("{s}\t{t}\t{d}\t{d:.4}\t{d:.4}\t{s}\t", .{
            t.names.keys()[r.field],               o, r.rows, r.gain.mean, r.gain.half_width,
            if (o == .win) "mnats" else "pct_mse",
        });
        if (r.over_ref) |g| try w.print("{d:.4}\t{d:.4}\t", .{ g.mean, g.half_width }) else try w.writeAll("\t\t");
        try w.print("{d}\t{d:.3}\t{d}\t{d:.3}\t{e:.2}\t{e:.2}\n", .{
            r.top_label, r.top, r.bottom_label, r.bottom, r.p, r.q,
        });
    }
}

fn writeFile(gpa: std.mem.Allocator, io: Io, dir: []const u8, name: []const u8, comptime f: anytype, args: anytype) !void {
    const path = try std.fs.path.join(gpa, &.{ dir, name });
    defer gpa.free(path);
    var file = try Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try @call(.auto, f, .{&fw.interface} ++ args);
    try fw.interface.flush();
    log.info("wrote {s}", .{path});
}

fn byGainB(_: void, a: BResult, b: BResult) bool {
    return a.gain.mean > b.gain.mean;
}

fn byGainA2(_: void, a: A2Result, b: A2Result) bool {
    return a.draft.mean > b.draft.mean;
}

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 2) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const snap = argv[0];
    const out_dir = argv[1];
    var final_list: ?[]const u8 = null;
    var ref_path: ?[]const u8 = null;
    var i: usize = 2;
    while (i + 1 < argv.len) : (i += 2) {
        if (std.mem.eql(u8, argv[i], "--final")) final_list = argv[i + 1] else if (std.mem.eql(u8, argv[i], "--ref")) ref_path = argv[i + 1] else {
            std.debug.print("usage:\n{s}", .{usage});
            return 2;
        }
    }
    const phase: harness.Phase = if (final_list != null) .final else .dev;
    if (phase == .final) {
        var lb: [256]u8 = undefined;
        var lw = Io.File.stdout().writer(io, &lb);
        _ = try looks.record(gpa, io, Io.Dir.cwd(), snap, "fields", argv, &lw.interface);
    }
    try Io.Dir.cwd().createDirPath(io, out_dir);

    var data = try rows.loadSnap(gpa, io, snap);
    defer data.deinit();
    const c = try harness.cuts(gpa, &data);

    var t = try load(gpa, io, snap, &data, c, phase);
    defer t.deinit(gpa);

    // Fields per lens: every field (all phases list them from the same sample), or LIST's
    var b_fields: std.ArrayList(u32) = .empty;
    defer b_fields.deinit(gpa);
    var a2_fields: std.ArrayList(u32) = .empty;
    defer a2_fields.deinit(gpa);
    var a1_fields: std.ArrayList(u32) = .empty;
    defer a1_fields.deinit(gpa);
    if (final_list) |path| {
        const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (line[0] == '#') continue;
            var f = std.mem.splitScalar(u8, line, '\t');
            const lens = f.next() orelse continue;
            const name = std.mem.trim(u8, f.next() orelse continue, " \r");
            const fi: u32 = @intCast(t.names.getIndex(name) orelse {
                log.err("{s}: no field {s}", .{ path, name });
                return error.UnknownField;
            });
            const list = if (std.mem.eql(u8, lens, "b")) &b_fields else if (std.mem.eql(u8, lens, "a2")) &a2_fields else if (std.mem.eql(u8, lens, "a1")) &a1_fields else return error.UnknownLens;
            try list.append(gpa, fi);
        }
    } else {
        for (t.names.keys(), 0..) |name, fi| switch (classOf(name)) {
            .id => {},
            // Category codes (d.) are A1's only: as numbers they mean nothing
            .draft => if (std.mem.startsWith(u8, name, "d.")) {
                try a1_fields.append(gpa, @intCast(fi));
            } else {
                if (std.mem.eql(u8, name, "p.summonerLevel")) try a1_fields.append(gpa, @intCast(fi));
                try b_fields.append(gpa, @intCast(fi));
            },
            else => {
                try b_fields.append(gpa, @intCast(fi));
                try a2_fields.append(gpa, @intCast(fi));
            },
        };
    }
    // Final: the test, then the test minus the games an earlier snapshot's looks saw. Fits
    // read fit seats only, so the second pass rescoring fewer seats keeps the same models
    var exclude = if (phase == .final) try looks.Exclude.load(gpa, io, Io.Dir.cwd(), snap) else null;
    defer if (exclude) |*e| e.deinit(gpa);
    var ref_arena: std.heap.ArenaAllocator = .init(gpa);
    defer ref_arena.deinit();
    var ref: ?Ref = null;
    defer if (ref) |*r| r.deinit(gpa);
    if (ref_path) |p| {
        if (phase != .final) return error.RefIsTestOnly;
        ref = try loadRef(gpa, ref_arena.allocator(), io, p);
    }
    for (0..2) |pass| {
        if (pass == 1) {
            const e = if (exclude) |*e| e else {
                if (phase == .final) log.info("no {s}: {s}'s final tables are the only ones", .{ looks.exclude_name, out_dir });
                break;
            };
            var dropped: usize = 0;
            for (t.seats) |*s| if (s.scored and e.has(data.games[s.game].match_id)) {
                s.scored = false;
                dropped += 1;
            };
            log.info("test minus {s}: {d} scored seats dropped", .{ looks.exclude_name, dropped });
        }
        const stem = if (phase == .dev) "dev" else if (pass == 0) "final" else "final-excl";

        const b = try lensB(gpa, io, &t, b_fields.items);
        defer gpa.free(b);
        std.mem.sort(BResult, b, {}, byGainB);
        try writeFile(gpa, io, out_dir, try arena.print("{s}-b.tsv", .{stem}), writeB, .{ &t, b });

        const a2 = try lensA2(gpa, io, &t, a2_fields.items);
        defer gpa.free(a2);
        std.mem.sort(A2Result, a2, {}, byGainA2);
        try writeFile(gpa, io, out_dir, try arena.print("{s}-a2.tsv", .{stem}), writeA2, .{ &t, a2 });

        const a1 = try lensA1(gpa, &t, &data, a1_fields.items, if (ref) |*r| r else null);
        defer gpa.free(a1);
        try writeFile(gpa, io, out_dir, try arena.print("{s}-a1.tsv", .{stem}), writeA1, .{ &t, a1 });
    }
    return 0;
}

const testing = std.testing;

test "classOf" {
    try testing.expectEqual(Class.draft, classOf("d.assign"));
    try testing.expectEqual(Class.id, classOf("p.item3"));
    try testing.expectEqual(Class.result, classOf("p.nexusKills"));
    try testing.expectEqual(Class.result, classOf("t.tower.kills"));
    try testing.expectEqual(Class.early, classOf("c.laneMinionsFirst10Minutes"));
    try testing.expectEqual(Class.game, classOf("c.soloKills"));
}

test "walk reads fields, challenges, derived champ select fields and team objectives" {
    const doc =
        \\{"info":{"participants":[{"participantId":1,"teamId":100,"kills":3,"win":true,
        \\"teamPosition":"TOP","positionAssignedByMatchmaking":"TOP",
        \\"selectedRolePreferences":"TOP.AUTOFILL.MIDDLE.BOTTOM","summoner1Id":14,"summoner2Id":4,
        \\"challenges":{"soloKills":2,"kda":1.5,"legendaryItemUsed":[1]},
        \\"perks":{"statPerks":{"defense":5011,"flex":5008,"offense":5007},
        \\"styles":[{"style":8000,"selections":[{"perk":8010}]},{"style":8300,"selections":[]}]}}],
        \\"teams":[{"teamId":100,"objectives":{"baron":{"first":false,"kills":1}}}]}}
    ;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const v = try std.json.parseFromSliceLeaky(Value, arena.allocator(), doc, .{});
    var ps: [10]Player = undefined;
    try testing.expectEqual(1, players(v, &ps));
    var names: std.StringArrayHashMapUnmanaged(void) = .empty;
    defer names.deinit(testing.allocator);
    try walk(Collect{ .gpa = testing.allocator, .arena = arena.allocator(), .names = &names }, ps[0].p, ps[0].team);
    for ([_][]const u8{ "p.kills", "p.win", "c.soloKills", "c.kda", "d.spells", "d.keystone", "d.trees", "d.shards", "d.assign", "t.baron.kills", "t.baron.first" }) |n| {
        try testing.expect(names.contains(n));
    }
    try testing.expect(!names.contains("c.legendaryItemUsed"));
    const dv = derived(ps[0].p);
    try testing.expectEqual(@as(f32, 414), dv[0]);
    try testing.expectEqual(@as(f32, 8010), dv[1]);
    try testing.expectEqual(@as(f32, 8083), dv[2]);
    try testing.expectEqual(@as(f32, 7 * 400 + 8 * 20 + 11), dv[3]);
    try testing.expectEqual(@as(f32, 3), dv[4]);
}

test "Benjamini-Hochberg" {
    var p = [_]f64{ 0.01, 0.04, 0.03, 0.5 };
    try adjustBH(testing.allocator, &p);
    try testing.expectApproxEqAbs(0.04, p[0], 1e-12);
    try testing.expectApproxEqAbs(0.16 / 3.0, p[1], 1e-12);
    try testing.expectApproxEqAbs(0.16 / 3.0, p[2], 1e-12);
    try testing.expectApproxEqAbs(0.5, p[3], 1e-12);
}

test "logistic Newton recovers a slope" {
    var seats: [2000]Seat = undefined;
    var prng: std.Random.DefaultPrng = .init(1);
    const rnd = prng.random();
    for (&seats) |*s| {
        const g = rnd.floatNorm(f32);
        s.* = .{ .game = 0, .slot = 0, .side = 0, .role = 0, .champion = 1, .cr = 0, .opp = 0, .minutes = 30, .gd14 = g, .y = @splat(0), .fit = true, .scored = false };
        s.y[win] = @floatFromInt(@intFromBool(rnd.float(f64) < sigmoid(@as(f64, 1.5 * g))));
    }
    var beta: [n_params]f64 = @splat(0);
    fitLogistic(BaseCtx{}, &seats, &beta);
    try testing.expectApproxEqAbs(1.5, beta[1], 0.25);
}

test "--ref: a match id too long for a key is skipped, not a crash" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const long: [100]u8 = @splat('x');
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "ref.tsv", .data = "match_id\tslot\toutcome\ty\tpred\n" ++
        long ++ "\t0\tgold14\t1\t2\nEUW1_1\t3\tcs10\t1\t0.5\n" });
    const path = try arena.print(".zig-cache/tmp/{s}/ref.tsv", .{&tmp.sub_path});
    var ref = try loadRef(testing.allocator, arena, testing.io, path);
    defer ref.deinit(testing.allocator);
    try testing.expectEqual(1, ref.count());
    var buf: [96]u8 = undefined;
    try testing.expectEqual(0.5, ref.get(refKey(&buf, "EUW1_1", 3, @backingInt(rows.Outcome.cs10)).?));
}
