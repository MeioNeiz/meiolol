//! The Draft tester's lane model (docs/model.md "Lane model file") as ui.wasm reads it:
//! lane-model.bin, lanefile.zig's export encoded with data.zig (testerbin.zig), scored
//! here as lanefile.Scorer does: gold at 14, lane gold at 14, CS at 10 and deaths before
//! 15 for a champion into its lane opponent, or blind over likely opponents
const std = @import("std");
const data = @import("data.zig");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const Phrase = phrase.Phrase;

const W = struct {
    const ok = Phrase("✓ {file:text}: {n:int} reference matchups match");
    const bad = Phrase("✗ {file:text}: {n:int} reference matchups, worst {gap:text} off");
    const no_refs = Phrase("✗ {file:text}: no reference matchups");
    const failed = Phrase("{file:text}: not found");
    const damaged = Phrase("{file:text}: damaged");
    const loading = Phrase("{file:text}: …");
};

pub const n_role = 5;
pub const n_lane = 4;
const z95 = 1.96;

/// lanefile.outcomes' order
pub const Outcome = enum(u8) { gold14, lanediff14, cs10, deaths15 };

/// Top, mid and bot: for junglers and supports lane gold says more about farming than
/// winning, so the page shows none for them
pub fn shown(role: usize) bool {
    return role == 0 or role == 2 or role == 3;
}

pub const Meta = struct {
    name: []const u8,
    /// yyyy-mm-dd
    newest_game: []const u8,
    training_games: u32,
    /// The patch whose offset the scorer adds; the training games' first and last
    patch: []const u8,
    oldest_patch: []const u8,
    newest_patch: []const u8,
    /// Share of the champion-role baseline's error on lane gold at 14 the matchups remove, %
    lanediff_removed: f32,
};

/// A champion-role term (enemy 0) or a lane pair cell, in the outcome's units; n training
/// games
pub const Term = struct {
    champion: u32,
    enemy: u32 = 0,
    role: u8,
    n: u32,
    b: [n_lane]f32,
    sd: [n_lane]f32,
};

/// lanefile.Ref: the exporter's own scores, rounded to 0.01
pub const Ref = struct {
    role: u8,
    champion: u32,
    enemy: u32,
    value: [n_lane]f32,
    lo: [n_lane]f32,
    hi: [n_lane]f32,
    champ_games: u32,
    pair_games: u32,
};

pub const Model = struct {
    meta: Meta,
    /// With the other eight slots at their average, per outcome and role
    intercept: [n_lane][n_role]f32,
    champ: []const Term,
    /// The lane opponent's own effect, for the player in that role
    enemy: []const Term,
    pairs: []const Term,
    refs: []const Ref,

    pub fn encode(m: Model, a: std.mem.Allocator, out: *std.ArrayList(u8)) !void {
        try data.encode(a, Model, m, out);
    }

    pub fn decode(a: std.mem.Allocator, bytes: []const u8) data.Error!Model {
        return data.decode(a, Model, bytes);
    }
};

pub const Value = struct {
    value: [n_lane]f32,
    lo: [n_lane]f32,
    hi: [n_lane]f32,
    champ_games: u32,
    pair_games: u32,

    pub fn of(v: Value, o: Outcome) f32 {
        return v.value[@backingInt(o)];
    }
};

/// A likely opponent and its weight (its play share in the role)
pub const Opp = struct { id: u32, w: f32 };

pub const Blind = struct {
    v: Value,
    /// Of the 10 likeliest opponents, the one with the least lane gold for the champion
    /// (0 none) and that gold
    hardest: u32 = 0,
    hardest_gold: f32 = 0,
};

pub const Scorer = struct {
    m: *const Model,
    champ: Map = .empty,
    enemy: Map = .empty,
    pairs: Map = .empty,

    const Map = std.AutoHashMapUnmanaged(u64, *const Term);

    fn key(role: u8, champion: u32, enemy: u32) u64 {
        return (@as(u64, champion) << 32) | (@as(u64, enemy) << 3) | role;
    }

    pub fn init(a: std.mem.Allocator, m: *const Model) !Scorer {
        var s: Scorer = .{ .m = m };
        for ([_]*Map{ &s.champ, &s.enemy, &s.pairs }, [_][]const Term{ m.champ, m.enemy, m.pairs }) |map, terms| {
            try map.ensureTotalCapacity(a, @intCast(terms.len));
            for (terms) |*t| {
                if (t.role >= n_role) return error.BadTerm;
                map.putAssumeCapacity(key(t.role, t.champion, t.enemy), t);
            }
        }
        return s;
    }

    fn present(s: *const Scorer, role: u8, champion: u32, enemy: u32) [3]?*const Term {
        return .{ s.champ.get(key(role, champion, 0)), s.enemy.get(key(role, enemy, 0)), s.pairs.get(key(role, champion, enemy)) };
    }

    /// lanefile.Scorer.value with others: intercept + champ + enemy + pair, a missing term
    /// 0; the 95% range from the present terms' sds, as independent
    pub fn value(s: *const Scorer, role: u8, champion: u32, enemy: u32) Value {
        const t = s.present(role, champion, enemy);
        var v: Value = .{ .value = undefined, .lo = undefined, .hi = undefined, .champ_games = if (t[0]) |x| x.n else 0, .pair_games = if (t[2]) |x| x.n else 0 };
        for (0..n_lane) |o| {
            var x: f64 = s.m.intercept[o][role];
            var vr: f64 = 0;
            for (t) |maybe| if (maybe) |term| {
                x += term.b[o];
                vr += @as(f64, term.sd[o]) * term.sd[o];
            };
            const h = z95 * @sqrt(vr);
            v.value[o] = @floatCast(x);
            v.lo[o] = @floatCast(x - h);
            v.hi[o] = @floatCast(x + h);
        }
        return v;
    }

    /// Into a field of opponents, the champion itself left out and the rest's weights
    /// scaled to 1: the weighted average; in its range the champion's own term stays whole
    /// while the opponents' and pairs' average down
    pub fn blind(s: *const Scorer, role: u8, champion: u32, field: []const Opp) Blind {
        const own = s.champ.get(key(role, champion, 0));
        var sum: [n_lane]f64 = @splat(0);
        var vr: [n_lane]f64 = @splat(0);
        var out: Blind = .{ .v = .{ .value = undefined, .lo = undefined, .hi = undefined, .champ_games = if (own) |x| x.n else 0, .pair_games = 0 } };
        var total: f64 = 0;
        for (field) |f| {
            if (f.id != champion) total += f.w;
        }
        for (field) |f| {
            if (f.id == champion or total <= 0) continue;
            const w = f.w / total;
            const v = s.value(role, champion, f.id);
            const t = s.present(role, champion, f.id);
            for (0..n_lane) |o| {
                sum[o] += w * v.value[o];
                var rest: f64 = 0;
                for (t[1..]) |maybe| if (maybe) |term| {
                    rest += @as(f64, term.sd[o]) * term.sd[o];
                };
                vr[o] += w * w * rest;
            }
        }
        for (0..n_lane) |o| {
            const sd_own: f64 = if (own) |x| x.sd[o] else 0;
            const h = z95 * @sqrt(sd_own * sd_own + vr[o]);
            out.v.value[o] = @floatCast(sum[o]);
            out.v.lo[o] = @floatCast(sum[o] - h);
            out.v.hi[o] = @floatCast(sum[o] + h);
        }
        var top: [10]?Opp = @splat(null);
        for (field) |f| {
            if (f.id == champion) continue;
            var cur = f;
            for (&top) |*slot| {
                const x = slot.* orelse {
                    slot.* = cur;
                    break;
                };
                if (cur.w > x.w) {
                    slot.* = cur;
                    cur = x;
                }
            }
        }
        const g = @backingInt(Outcome.lanediff14);
        for (top) |maybe| if (maybe) |f| {
            const v = s.value(role, champion, f.id).value[g];
            if (out.hardest == 0 or v < out.hardest_gold) {
                out.hardest = f.id;
                out.hardest_gold = v;
            }
        };
        return out;
    }

    /// The largest gap to the exporter's references; games must match exactly
    pub fn check(s: *const Scorer) Check {
        var c: Check = .{ .refs = @intCast(s.m.refs.len), .worst = 0 };
        for (s.m.refs) |r| {
            const v = s.value(r.role, r.champion, r.enemy);
            if (v.champ_games != r.champ_games or v.pair_games != r.pair_games) c.worst = std.math.inf(f32);
            for ([_][n_lane]f32{ v.value, v.lo, v.hi }, [_][n_lane]f32{ r.value, r.lo, r.hi }) |got, want| for (got, want) |x, y| {
                const d = x - y;
                // A NaN gap (a NaN parameter) counts as the worst, not as none
                if (!(@abs(d) <= c.worst)) c.worst = if (std.math.isNan(d)) std.math.inf(f32) else @abs(d);
            };
        }
        return c;
    }
};

/// On the private site: the box's daily refit
pub const file = "/private/models/lane-model.bin";

/// `failed`: not fetched (a network error, no file); `bad`: fetched, didn't decode or
/// score
pub const Load = union(enum) { none, loading, failed, bad, ready: *const Loaded };

/// A lane model file, decoded, with its scorer and self-check
pub const Loaded = struct {
    m: Model,
    sc: Scorer,
    check: Check,

    /// In place: the scorer points at `l.m`. Decoded slices point into `bytes`
    pub fn init(l: *Loaded, a: std.mem.Allocator, bytes: []const u8) !void {
        l.m = try Model.decode(a, bytes);
        l.sc = try Scorer.init(a, &l.m);
        l.check = l.sc.check();
    }
};

/// The tester's Files line for the lane model
pub fn fileLine(h: *tree.H, load: Load) tree.Text {
    return switch (load) {
        .ready => |l| if (l.check.refs == 0)
            W.no_refs.with(h, .{ .file = file })
        else if (l.check.ok())
            W.ok.with(h, .{ .file = file, .n = l.check.refs })
        else
            W.bad.with(h, .{ .file = file, .n = l.check.refs, .gap = gap(h, l.check.worst) }),
        .failed => W.failed.with(h, .{ .file = file }),
        .bad => W.damaged.with(h, .{ .file = file }),
        .none, .loading => W.loading.with(h, .{ .file = file }),
    };
}

/// Three decimals through ui/fmt.zig: std's float formatter is KBs of ui.wasm
fn gap(h: *tree.H, x: f32) []const u8 {
    if (!std.math.isFinite(x)) return "?";
    var w: std.Io.Writer.Allocating = .init(h.mem);
    fmt.fixed(&w.writer, x, 3, false) catch {
        h.oom = true;
        return "?";
    };
    return w.written();
}

/// One candidate's lane, for the candidate panel's feed (ui.data): lane gold at 14 and
/// its 95% range, CS at 10, deaths before 15
pub const Gold = struct {
    v: f32,
    lo: f32,
    hi: f32,
    cs10: f32,
    deaths15: f32,
    /// Games of the matchup in the model; blind 0
    pair_games: u32 = 0,
    /// Blind: of the likeliest opponents, the one with the least gold for it (0 none)
    hardest: u32 = 0,
    hardest_gold: f32 = 0,
};

/// `champion` in `role` into `opp`, or blind over `field` when `opp` is 0
pub fn gold(s: *const Scorer, role: u8, champion: u32, opp: u32, field: []const Opp) Gold {
    const b: Blind = if (opp != 0) .{ .v = s.value(role, champion, opp) } else s.blind(role, champion, field);
    const g = @backingInt(Outcome.lanediff14);
    return .{
        .v = b.v.value[g],
        .lo = b.v.lo[g],
        .hi = b.v.hi[g],
        .cs10 = b.v.of(.cs10),
        .deaths15 = b.v.of(.deaths15),
        .pair_games = b.v.pair_games,
        .hardest = b.hardest,
        .hardest_gold = b.hardest_gold,
    };
}

pub const Check = struct {
    refs: u32,
    worst: f32,

    /// The references are rounded to 0.01 and the terms stored as f32: the old page's
    /// tolerance
    pub fn ok(c: Check) bool {
        return c.refs > 0 and c.worst <= 0.01;
    }
};

const testing = std.testing;

fn testModel() Model {
    return .{
        .meta = .{ .name = "3c-team2", .newest_game = "2026-10-29", .training_games = 1000, .patch = "16.21", .oldest_patch = "16.19", .newest_patch = "16.21", .lanediff_removed = 12.5 },
        .intercept = .{ @splat(5000), @splat(0), @splat(80), @splat(1.5) },
        .champ = &.{
            .{ .champion = 1, .role = 0, .n = 500, .b = .{ 100, 200, 5, -0.2 }, .sd = .{ 30, 40, 1, 0.1 } },
            .{ .champion = 2, .role = 0, .n = 400, .b = .{ -50, -100, -2, 0.1 }, .sd = .{ 30, 40, 1, 0.1 } },
            .{ .champion = 3, .role = 0, .n = 300, .b = @splat(0), .sd = @splat(0) },
        },
        .enemy = &.{
            .{ .champion = 2, .role = 0, .n = 400, .b = .{ 20, -60, 0, 0.05 }, .sd = .{ 30, 30, 1, 0.1 } },
            .{ .champion = 3, .role = 0, .n = 300, .b = .{ 0, -10, 0, 0 }, .sd = @splat(0) },
        },
        .pairs = &.{.{ .champion = 1, .enemy = 2, .role = 0, .n = 120, .b = .{ 10, 50, 1, 0 }, .sd = .{ 20, 30, 0.5, 0.05 } }},
        .refs = &.{},
    };
}

test "lane: the documented formula, encoded and back" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var out: std.ArrayList(u8) = .empty;
    try testModel().encode(a, &out);
    const m = try Model.decode(a, out.items);
    const s = try Scorer.init(a, &m);
    const v = s.value(0, 1, 2);
    // 0 + 200 - 60 + 50; range 1.96 sqrt(40² + 30² + 30²)
    try testing.expectApproxEqAbs(190, v.of(.lanediff14), 1e-4);
    try testing.expectApproxEqAbs(190 - 1.96 * @sqrt(@as(f32, 3400)), v.lo[1], 1e-3);
    try testing.expectEqual(500, v.champ_games);
    try testing.expectEqual(120, v.pair_games);
    // An unknown champion: the intercept and the opponent's term
    try testing.expectApproxEqAbs(5020, s.value(0, 99, 2).of(.gold14), 1e-4);
    // Blind, half each: (190 + 190) / 2 for gold (1 into 3: 200 - 10); the champion's sd
    // stays whole
    const b = s.blind(0, 1, &.{ .{ .id = 2, .w = 0.5 }, .{ .id = 3, .w = 0.5 } });
    try testing.expectApproxEqAbs(190, b.v.of(.lanediff14), 1e-4);
    try testing.expectApproxEqAbs(190 - 1.96 * @sqrt(@as(f32, 40 * 40 + 0.25 * (30 * 30 + 30 * 30))), b.v.lo[1], 1e-3);
    try testing.expectEqual(2, b.hardest);
    // The champion itself in the field is left out, the rest scaled to 1
    const self = s.blind(0, 1, &.{ .{ .id = 1, .w = 0.5 }, .{ .id = 2, .w = 0.25 }, .{ .id = 3, .w = 0.25 } });
    try testing.expectApproxEqAbs(190, self.v.of(.lanediff14), 1e-4);
    try testing.expectEqual(2, self.hardest);
    const g = gold(&s, 0, 1, 2, &.{});
    try testing.expectApproxEqAbs(190, g.v, 1e-4);
    try testing.expectEqual(120, g.pair_games);
}

test "lane: the check finds an off reference, and passes a true one" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = testModel();
    const s0 = try Scorer.init(a, &m);
    const v = s0.value(0, 1, 2);
    var refs = [_]Ref{.{ .role = 0, .champion = 1, .enemy = 2, .value = v.value, .lo = v.lo, .hi = v.hi, .champ_games = 500, .pair_games = 120 }};
    m.refs = &refs;
    const s = try Scorer.init(a, &m);
    try testing.expect(s.check().ok());
    refs[0].value[1] += 0.02;
    try testing.expect(!s.check().ok());
    refs[0].value[1] -= 0.02;
    refs[0].pair_games = 1;
    try testing.expect(!s.check().ok());
}
