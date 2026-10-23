//! In-game win chance by minute, the richc model (docs/model.md "Rich state and champions
//! (richc)"): a logistic regression on 91 blue-minus-red features of the state at minute
//! m (livestate.zig) and the draft logit, plus a champion-role effect by minute, every
//! weight linear in minute between knots. Fitted by py/state/stateship.py on every played
//! game with a timeline; the file (state_model.bin, format in docs/model.md "In-game model
//! file") is embedded. `meiolol-lab state-export SNAP --check` checks this scorer against
//! the Python fit on a few hundred games. Descriptive, not causal

const std = @import("std");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const livestate = @import("livestate.zig");
const objectives = @import("objectives.zig");

const Allocator = std.mem.Allocator;
const Minute = livestate.Minute;
const Seat = livestate.Seat;
const Team = livestate.Team;

pub const shipped_bytes = @embedFile("state_model.bin");

const magic = "meiolol-state\x00\x00\x00";
const version = 1;
const name_len = 24;
const platform_len = 8;
const header_len = 16 + 7 * 4 + 8 + 64 + 64;

/// winchance's state, in the model's order
const wc = [_]objectives.Feat{ .gold, .gold_curve, .xp, .towers, .inhibs_down, .dragons, .soul_point, .soul, .elder, .grubs, .herald, .baron };
const per_role = [_][]const u8{ "gold", "xp", "level", "cs", "dead", "items", "unspent", "deaths" };
const lane_names = [_][]const u8{ "top", "mid", "bot" };
const tier_names = [_][]const u8{ "outer", "inner", "base" };
const element_names = [_][]const u8{ "infernal", "ocean", "mountain", "cloud", "hextech", "chemtech" };

/// Feature names in the model's order (py/state/statecommon.py `features`)
pub const names = blk: {
    var n: []const []const u8 = &.{"draft"};
    for (wc) |f| n = n ++ &[_][]const u8{"obj_" ++ @tagName(f)};
    for (core.Role.all) |r| for (per_role) |p| {
        n = n ++ &[_][]const u8{p ++ "_" ++ @tagName(r)};
    };
    n = n ++ &[_][]const u8{ "dead_count", "kills", "dmg_champ", "gold_total" };
    for (lane_names) |l| for (tier_names) |t| {
        n = n ++ &[_][]const u8{"tower_" ++ l ++ "_" ++ t};
    };
    n = n ++ &[_][]const u8{ "tower_nexus", "plates", "inhib_s", "inhibs_ever" };
    for (element_names) |e| n = n ++ &[_][]const u8{"drag_" ++ e};
    for (element_names) |e| n = n ++ &[_][]const u8{"soul_" ++ e};
    n = n ++ &[_][]const u8{ "elder_s", "baron_s", "barons", "elders", "grubs_n", "heralds_n", "wards", "ctrl_wards", "wards_killed" };
    break :blk n;
};
pub const n_features = names.len;

/// Features of state `s` with draft logit `draft`, in `names` order
pub fn features(s: *const Minute, draft: f64) [n_features]f64 {
    var x: [n_features]f64 = undefined;
    var i: usize = 0;
    const put = struct {
        fn f(out: *[n_features]f64, at: *usize, v: f64) void {
            out[at.*] = v;
            at.* += 1;
        }
    }.f;
    const seat = struct {
        fn diff(st: *const Minute, role: usize, c: Seat) f64 {
            return @as(f64, st.get(role, c)) - st.get(5 + role, c);
        }
        fn side(st: *const Minute, c: Seat) f64 {
            var d: f64 = 0;
            for (0..5) |r| d += @as(f64, st.get(r, c)) - st.get(5 + r, c);
            return d;
        }
        fn team(st: *const Minute, c: Team) f64 {
            return @as(f64, st.teamGet(0, c)) - st.teamGet(1, c);
        }
    };
    put(&x, &i, draft);
    for (wc) |f| put(&x, &i, s.obj[@backingInt(f)]);
    for (0..5) |r| {
        put(&x, &i, seat.diff(s, r, .gold) / 1000);
        put(&x, &i, seat.diff(s, r, .xp) / 1000);
        put(&x, &i, seat.diff(s, r, .level));
        put(&x, &i, seat.diff(s, r, .cs) / 10);
        put(&x, &i, seat.diff(s, r, .respawn_s) / 10);
        put(&x, &i, seat.diff(s, r, .legendaries));
        put(&x, &i, seat.diff(s, r, .unspent) / 1000);
        put(&x, &i, seat.diff(s, r, .deaths));
    }
    var dead: f64 = 0;
    var gold: f64 = 0;
    for (0..10) |st| {
        if (s.get(st, .respawn_s) > 0) dead += if (st < 5) 1 else -1;
        gold += s.get(st, .gold);
    }
    put(&x, &i, dead);
    put(&x, &i, seat.team(s, .kills));
    put(&x, &i, seat.side(s, .dmg_champ) / 1000);
    put(&x, &i, gold / 10000);
    for (0..9) |k| put(&x, &i, seat.team(s, @fromBackingInt(@backingInt(Team.tower_top_outer) + @as(u5, @intCast(k)))));
    put(&x, &i, seat.team(s, .tower_nexus));
    put(&x, &i, seat.team(s, .plates));
    put(&x, &i, (seat.team(s, .inhib_top_s) + seat.team(s, .inhib_mid_s) + seat.team(s, .inhib_bot_s)) / 100);
    put(&x, &i, seat.team(s, .inhibs));
    for (0..6) |e| put(&x, &i, seat.team(s, @fromBackingInt(@backingInt(Team.infernal) + @as(u5, @intCast(e)))));
    for (0..6) |e| {
        const v: f64 = @floatFromInt(e + 1);
        const b: f64 = @floatFromInt(@intFromBool(s.teamGet(0, .soul) == v));
        const r: f64 = @floatFromInt(@intFromBool(s.teamGet(1, .soul) == v));
        put(&x, &i, b - r);
    }
    put(&x, &i, seat.team(s, .elder_s) / 100);
    put(&x, &i, seat.team(s, .baron_s) / 100);
    put(&x, &i, seat.team(s, .barons));
    put(&x, &i, seat.team(s, .elders));
    put(&x, &i, seat.team(s, .grubs));
    put(&x, &i, seat.team(s, .heralds));
    put(&x, &i, seat.side(s, .wards) / 10);
    put(&x, &i, seat.side(s, .ctrl_wards));
    put(&x, &i, seat.side(s, .wards_killed) / 10);
    std.debug.assert(i == n_features);
    return x;
}

pub const max_knots = 16;

/// A model file, read in place
pub const Model = struct {
    bytes: []const u8,
    n_knots: usize,
    n_platforms: usize,
    n_terms: usize,
    training_games: u32,
    newest_ms: i64,
    snapshot: []const u8,
    run: []const u8,
    knots_off: usize,
    mu_off: usize,
    sd_off: usize,
    w_off: usize,
    b_off: usize,
    default_off: usize,
    platforms_off: usize,
    terms_off: usize,

    pub const Error = error{ BadModelFile, FeaturesDiffer };

    pub fn parse(bytes: []const u8) Error!Model {
        if (bytes.len < header_len or !std.mem.eql(u8, bytes[0..16], magic)) return error.BadModelFile;
        const int = struct {
            fn at(b: []const u8, off: usize) u32 {
                return std.mem.readInt(u32, b[off..][0..4], .little);
            }
        }.at;
        if (int(bytes, 16) != version) return error.BadModelFile;
        const f = int(bytes, 20);
        const k = int(bytes, 24);
        if (f != n_features) return error.FeaturesDiffer;
        if (k < 2 or k > max_knots) return error.BadModelFile;
        var m: Model = .{
            .bytes = bytes,
            .n_knots = k,
            .n_platforms = int(bytes, 28),
            .n_terms = int(bytes, 32),
            .training_games = int(bytes, 36),
            .newest_ms = std.mem.readInt(i64, bytes[44..52], .little),
            .snapshot = std.mem.sliceTo(bytes[52..116], 0),
            .run = std.mem.sliceTo(bytes[116..180], 0),
            .knots_off = header_len,
            .mu_off = 0,
            .sd_off = 0,
            .w_off = 0,
            .b_off = 0,
            .default_off = 0,
            .platforms_off = 0,
            .terms_off = 0,
        };
        const names_off = m.knots_off + 4 * k;
        m.mu_off = names_off + name_len * f;
        m.sd_off = m.mu_off + 4 * f;
        m.w_off = m.sd_off + 4 * f;
        m.b_off = m.w_off + 4 * f * k;
        m.default_off = m.b_off + 4 * k;
        m.platforms_off = m.default_off + 4;
        m.terms_off = m.platforms_off + (platform_len + 4) * m.n_platforms;
        if (m.terms_off + (12 + 4 * k) * m.n_terms != bytes.len) return error.BadModelFile;
        for (names, 0..) |want, i| {
            const got = std.mem.sliceTo(bytes[names_off + i * name_len ..][0..name_len], 0);
            if (!std.mem.eql(u8, got, want)) return error.FeaturesDiffer;
        }
        for (1..k) |i| if (!(m.knot(i) > m.knot(i - 1))) return error.BadModelFile;
        return m;
    }

    fn float(m: Model, off: usize) f64 {
        return @as(f32, @bitCast(std.mem.readInt(u32, m.bytes[off..][0..4], .little)));
    }
    pub fn knot(m: Model, k: usize) f64 {
        return m.float(m.knots_off + 4 * k);
    }

    /// The platform's intercept in the draft logit (match id prefix, "EUW1"); the
    /// games-weighted mean for an unknown one
    pub fn intercept(m: Model, platform: []const u8) f64 {
        for (0..m.n_platforms) |p| {
            const off = m.platforms_off + p * (platform_len + 4);
            if (std.mem.eql(u8, std.mem.sliceTo(m.bytes[off..][0..platform_len], 0), platform)) return m.float(off + platform_len);
        }
        return m.float(m.default_off);
    }

    /// A champion-role's rating and per-knot effect (offset of the first), null when the
    /// fit never saw it (counts 0)
    fn term(m: Model, champion: u32, role: usize) ?struct { rating: f64, effect_off: usize } {
        const size = 12 + 4 * m.n_knots;
        for (0..m.n_terms) |t| {
            const off = m.terms_off + t * size;
            if (std.mem.readInt(u32, m.bytes[off..][0..4], .little) != champion) continue;
            if (std.mem.readInt(u32, m.bytes[off + 4 ..][0..4], .little) != role) continue;
            return .{ .rating = m.float(off + 8), .effect_off = off + 12 };
        }
        return null;
    }

    /// Hat basis at `minute`: weights linear in minute between knots, flat outside
    pub fn hat(m: Model, minute: f64) [max_knots]f64 {
        var h: [max_knots]f64 = @splat(0);
        const k = m.n_knots;
        const t = std.math.clamp(minute, m.knot(0), m.knot(k - 1));
        if (t >= m.knot(k - 1)) {
            h[k - 1] = 1;
            return h;
        }
        for (0..k - 1) |i| {
            const lo = m.knot(i);
            const hi = m.knot(i + 1);
            if (t >= lo and t < hi) {
                h[i] = (hi - t) / (hi - lo);
                h[i + 1] = (t - lo) / (hi - lo);
                break;
            }
        }
        return h;
    }

    /// The draft side of one game: the draft logit and blue's minus red's champion
    /// effect per knot
    pub fn draft(m: Model, champions: [10]u32, platform: []const u8) Draft {
        var d: Draft = .{ .logit = m.intercept(platform) };
        for (champions, 0..) |c, s| {
            const sign: f64 = if (s < 5) 1 else -1;
            const t = m.term(c, s % 5) orelse continue;
            d.logit += sign * t.rating;
            for (0..m.n_knots) |k| d.effect[k] += sign * m.float(t.effect_off + 4 * k);
        }
        return d;
    }

    /// Blue's log-odds at `minute` given state `s`
    pub fn logit(m: Model, d: Draft, s: *const Minute, minute: u8) f64 {
        const x = features(s, d.logit);
        const h = m.hat(@floatFromInt(minute));
        const k = m.n_knots;
        var z: f64 = 0;
        for (0..k) |j| {
            if (h[j] == 0) continue;
            var dot = m.float(m.b_off + 4 * j) + d.effect[j];
            for (x, 0..) |v, f| {
                const xs = (v - m.float(m.mu_off + 4 * f)) / m.float(m.sd_off + 4 * f);
                dot += xs * m.float(m.w_off + 4 * (f * k + j));
            }
            z += h[j] * dot;
        }
        return z;
    }
};

pub const Draft = struct { logit: f64, effect: [max_knots]f64 = @splat(0) };

/// The embedded model; checked by a test, so this cannot fail in a built binary
pub fn shipped() Model {
    return Model.parse(shipped_bytes) catch unreachable;
}

pub const Game = struct {
    t: timeline.Timeline,
    /// Participant id - 1 -> seat (side * 5 + role, side 0 blue)
    seat_of: [10]u8,
    /// Riot champion id by seat
    champions: [10]u32,
    /// Match id prefix ("EUW1"), "" unknown
    platform: []const u8,
    items: livestate.Items,

    /// Seats from team ids (100 blue) and Riot teamPositions, by participant id - 1;
    /// null unless each side has the five roles once
    pub fn seats(teams: [10]i64, positions: [10][]const u8) ?[10]u8 {
        var seat_of: [10]u8 = undefined;
        var taken: [10]bool = @splat(false);
        for (teams, positions, &seat_of) |team, pos, *s| {
            const side: u8 = switch (team) {
                100 => 0,
                200 => 1,
                else => return null,
            };
            const role = core.Role.fromLcu(pos) orelse return null;
            s.* = side * 5 + @backingInt(role);
            if (taken[s.*]) return null;
            taken[s.*] = true;
        }
        return seat_of;
    }
};

/// Blue's chance by minute from 0 while the game is going; empty unless the timeline
/// has 10 participants. 0:00 is the champions alone: the even opening frame, scored with
/// the first fitted minute's weights (Jacob, 14 Oct: start from the draft, not 50%)
pub fn chances(arena: Allocator, m: Model, g: Game) ![]f64 {
    if (g.t.participants != 10) return &.{};
    const d = m.draft(g.champions, g.platform);
    var walk: livestate.Walker = .init(g.t, g.seat_of, g.items);
    var out: std.ArrayList(f64) = .empty;
    for (0..255) |i| {
        const minute: u8 = @intCast(i);
        const s = walk.at(minute) orelse break;
        try out.append(arena, 1 / (1 + @exp(-m.logit(d, &s, minute))));
    }
    return out.items;
}

const testing = std.testing;

test {
    _ = livestate;
}

test "the embedded model parses and its features are statecommon's" {
    const m = try Model.parse(shipped_bytes);
    try testing.expect(m.n_terms > 100);
    try testing.expect(m.training_games > 1000);
    try testing.expectEqual(@as(usize, 91), n_features);
    try testing.expectEqualStrings("gold_top", names[13]);
    try testing.expectEqualStrings("deaths_utility", names[52]);
    try testing.expectEqualStrings("wards_killed", names[90]);
    try testing.expectError(error.BadModelFile, Model.parse(shipped_bytes[0 .. shipped_bytes.len - 1]));
}

test "hat basis" {
    const m = shipped();
    const h10 = m.hat(10);
    try testing.expectEqual(@as(f64, 1), h10[2]);
    const h12 = m.hat(12);
    try testing.expectApproxEqAbs(@as(f64, 0.6), h12[2], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.4), h12[3], 1e-12);
    try testing.expectEqual(@as(f64, 1), m.hat(55)[m.n_knots - 1]);
}

test "features: blue minus red, units as statecommon" {
    var s: Minute = .{ .t_ms = 0, .seat = @splat(@splat(0)), .obj = @splat(0), .team = @splat(@splat(0)) };
    s.seat[0][@backingInt(Seat.gold)] = 3000;
    s.seat[5][@backingInt(Seat.gold)] = 2500;
    s.seat[8][@backingInt(Seat.respawn_s)] = 12;
    s.team[0][@backingInt(Team.soul)] = 2;
    s.team[1][@backingInt(Team.inhib_mid_s)] = 150;
    s.team[0][@backingInt(Team.tower_mid_inner)] = 1;
    const x = features(&s, 0.25);
    const at = struct {
        fn f(name: []const u8) usize {
            for (names, 0..) |n, i| if (std.mem.eql(u8, n, name)) return i;
            unreachable;
        }
    }.f;
    try testing.expectEqual(@as(f64, 0.25), x[at("draft")]);
    try testing.expectEqual(@as(f64, 0.5), x[at("gold_top")]);
    try testing.expectEqual(@as(f64, -1.2), x[at("dead_bottom")]);
    try testing.expectEqual(@as(f64, -1), x[at("dead_count")]);
    try testing.expectEqual(@as(f64, 0.55), x[at("gold_total")]);
    try testing.expectEqual(@as(f64, 1), x[at("soul_ocean")]);
    try testing.expectEqual(@as(f64, -1.5), x[at("inhib_s")]);
    try testing.expectEqual(@as(f64, 1), x[at("tower_mid_inner")]);
}

test "seats need each side's five roles once" {
    const teams = [10]i64{ 100, 100, 100, 100, 100, 200, 200, 200, 200, 200 };
    var pos = [10][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY", "UTILITY", "BOTTOM", "MIDDLE", "JUNGLE", "TOP" };
    try testing.expectEqual([10]u8{ 0, 1, 2, 3, 4, 9, 8, 7, 6, 5 }, Game.seats(teams, pos).?);
    pos[1] = "TOP";
    try testing.expectEqual(@as(?[10]u8, null), Game.seats(teams, pos));
    pos[1] = "";
    try testing.expectEqual(@as(?[10]u8, null), Game.seats(teams, pos));
}

test "chances: the champions alone at the start, then the model while the game is going" {
    var a: std.heap.ArenaAllocator = .init(testing.allocator);
    defer a.deinit();
    const arena = a.allocator();
    const store = @import("store");
    const raw = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, raw);
    const ids: []const u32 = &.{};
    const m = shipped();
    const seat_of = [10]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    // Ahri and Jinx in their usual roles, so their terms are in any fit
    const champions = [10]u32{ 0, 0, 103, 222, 0, 0, 0, 103, 222, 0 };
    const p = try chances(arena, m, .{ .t = t, .seat_of = seat_of, .champions = champions, .platform = "EUW1", .items = .sorted(&ids) });
    try testing.expect(p.len > 10);
    for (p) |x| try testing.expect(x > 0 and x < 1);
    // Same champions on both sides in the same roles: the draft cancels but the intercept
    const d = m.draft(champions, "EUW1");
    try testing.expectApproxEqAbs(m.intercept("EUW1"), d.logit, 1e-12);
    try testing.expectEqual(m.intercept("XX9"), m.float(m.default_off));
}
