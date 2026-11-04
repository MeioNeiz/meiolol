//! Meio, the estimate mode (docs/plan/estimates.md E3-E6, J34): one number per cell from
//! every game, old patches moved by what the newest patch changed, every rank and region
//! adjusted to the one picked. E2's truth test (src/truth.zig) calls fit() per origin day
//! and rate() per cell; a cell kind ships only once it beats both raw windows there.
//!
//! E3, champion-role win rate, per champion-role on the logit scale:
//!   a (shared across patches) + d[patch] + b[bracket] + g (EUW1)
//! each a random effect shrunk to 0 with one variance per term kind, estimated from the
//! fit (MacKay's fixed point, as src/additive.zig and patch-transfer A2, which beat the
//! changed-champion prior and the warm start on 16.21: docs/model.md "The latest patch
//! day by day on 16.21"). A champion-role's terms touch only its own games, so each is
//! a tiny Newton fit (Laplace posterior); the variances couple them. The newest patch's
//! number is a + d[0]: on day 0 d[0] is 0 and the shared term carries it, and d[0] takes
//! over as the patch's games arrive. Older games can weigh less (half_life). a shrinks
//! to a line in the champion-role's log share of its role's games, not to 50%: rare
//! (off-role) picks lose, and shrinking them to even cost the unseen keystone cells
//! ~1.8 milli-nats on 16.21

const std = @import("std");
const flat = @import("site/flat.zig");
const Allocator = std.mem.Allocator;

pub const no_gold = std.math.minInt(i32);

/// Every cell kind truth scores; the order keeps truth's keys stable. Rank is the bracket
/// dimension of every kind, not a kind
pub const Kind = enum(u4) {
    /// Champion-role win rate
    champion,
    /// Win rate against the lane opponent (b: opponent cr)
    matchup,
    /// Bottom with its support, win rate (b: support cr)
    duo,
    /// Lane gold difference at 14 against the opponent (an average; b: opponent cr)
    gold14,
    /// Share of a champion-role's games with a finished item (b: item)
    build,
    /// Win rate with a finished item (b: item)
    item,
    /// Win rate with a keystone (b: keystone)
    keystone,
    /// Share of a champion-role's games with a keystone (b: keystone)
    rune,
    /// Win rate with a keystone against a lane opponent (b: keystone << 16 | opponent cr)
    keystone_matchup,
    /// Win rate with a finished item against a lane opponent (b: item << 16 | opponent cr)
    item_matchup,
    /// Win rate with a keystone and a finished item (b: keystone << 16 | item)
    keystone_item,

    pub const count = @typeInfo(Kind).@"enum".field_names.len;
};

/// One player in one game
pub const Row = struct {
    /// Days since the newest patch's start, floored
    day: i16,
    /// champion | role << 13
    cr: u16,
    /// The lane opponent's cr; 0 none
    opp: u16 = 0,
    /// A bottom's support's cr; 0 none
    ally: u16 = 0,
    keystone: u16 = 0,
    gold: i32 = no_gold,
    items: [6]u16 = @splat(0),
    win: bool,
    euw: bool,
    /// The game has a timeline, so its items are known (item shares count these only)
    timeline: bool = false,
    /// 0 the newest patch, 1 the one before, ...
    patch: u8,
    /// 0 unknown, else curvesfile.Bracket (1 low, 2 mid, 3 high)
    bracket: u2,
};

pub const Options = struct {
    /// A game's weight halves every this many days before the origin; 0: all weigh 1
    half_life: f64 = 0,
    /// Patch slots: the newest, the one before, ...; older patches share the last
    patches: u8 = 3,
    /// Patches as a random walk: each patch's offset is the one before plus a shrunk
    /// step, so the newest leans on last patch rather than on the whole window
    walk: bool = false,
    /// Prior sds on the logit scale, by term; 0: estimated from the fit
    sd: [n_terms]f64 = @splat(0),
    rounds: u8 = 40,
    /// Pair terms (matchups, duos, gold's) under a two-part scale mixture prior per
    /// class rather than one Gaussian, so a lone real outlier is not shrunk to the pack
    pair_mix: bool = false,
};

/// Term kinds, one variance each
pub const Term = enum { main, patch, bracket, euw };
const n_terms = 4;
const max_patches = 6;
const max_k = 1 + max_patches + 3 + 1;
/// Pair term classes, one variance each: a matchup per role, then duo
const n_pair_classes = 6;
/// Condition term classes (keystone, item), one per role
const n_roles = 8;

/// Rank brackets a number pools: bit br for bracket br (0 unknown, 1 low, 2 mid, 3 high)
pub const Brackets = struct {
    mask: u4,

    pub const all: Brackets = .{ .mask = 0xf };

    /// One bracket, or 0 for all ranks (the unknown rank too)
    pub fn of(bracket: u2) Brackets {
        return if (bracket == 0) all else .{ .mask = @as(u4, 1) << bracket };
    }

    fn has(b: Brackets, br: usize) bool {
        return b.mask >> @intCast(br) & 1 != 0;
    }
};

/// 80% interval
const z80 = 1.2815515655446004;

const Logit = struct { eta: f64, v: f64 };

pub const Estimate = struct {
    p: f64,
    lo: f64,
    hi: f64,
    /// Games in the cell's own slice (newest patch, this region and bracket), unweighted
    own: f64,

    fn of(eta: f64, v: f64, own: f64) Estimate {
        const s = @sqrt(@max(v, 0));
        return .{
            // Averaged over the posterior, not the mean's rate
            .p = meanSigmoid(eta, s),
            .lo = sigmoid(eta - z80 * s),
            .hi = sigmoid(eta + z80 * s),
            .own = own,
        };
    }

    /// An average, from thousands of gold to gold
    fn ofAvg(mean: f64, v: f64, own: f64) Estimate {
        const s = z80 * @sqrt(@max(v, 0));
        return .{ .p = 1000 * mean, .lo = 1000 * (mean - s), .hi = 1000 * (mean + s), .own = own };
    }

    fn ofNormals(n: Normals, own: f64) Estimate {
        if (n.w == 1) return .of(n.e[0], n.v[0], own);
        const p0 = meanSigmoid(n.e[0], @sqrt(@max(n.v[0], 0)));
        const p1 = meanSigmoid(n.e[1], @sqrt(@max(n.v[1], 0)));
        return .{
            .p = n.w * p0 + (1 - n.w) * p1,
            .lo = sigmoid(n.quantile(0.1)),
            .hi = sigmoid(n.quantile(0.9)),
            .own = own,
        };
    }

    fn ofAvgNormals(n: Normals, own: f64) Estimate {
        if (n.w == 1) return .ofAvg(n.e[0], n.v[0], own);
        return .{ .p = 1000 * n.mean(), .lo = 1000 * n.quantile(0.1), .hi = 1000 * n.quantile(0.9), .own = own };
    }
};

/// Two normals, weight w on the first; one when w is 1. A pair term under the mixture
/// prior (Options.pair_mix) has a two-part posterior, so a sum of terms does too; its
/// range is the mixture's quantiles, as mean +- z sd misplaces a bimodal one
const Normals = struct {
    w: f64 = 1,
    e: [2]f64 = @splat(0),
    v: [2]f64 = @splat(0),

    fn one(e: f64, v: f64) Normals {
        return .{ .e = @splat(e), .v = @splat(v) };
    }

    /// The sum with an independent b; a second split one joins by its moments (no kind
    /// adds two pair terms)
    fn add(a: Normals, b: Normals) Normals {
        if (b.w == 1) return .{
            .w = a.w,
            .e = .{ a.e[0] + b.e[0], a.e[1] + b.e[0] },
            .v = .{ a.v[0] + b.v[0], a.v[1] + b.v[0] },
        };
        if (a.w == 1) return b.add(a);
        return a.add(.one(b.mean(), b.variance()));
    }

    fn mean(n: Normals) f64 {
        return n.w * n.e[0] + (1 - n.w) * n.e[1];
    }

    fn variance(n: Normals) f64 {
        const m = n.mean();
        const sq = n.w * (n.v[0] + n.e[0] * n.e[0]) + (1 - n.w) * (n.v[1] + n.e[1] * n.e[1]);
        return @max(sq - m * m, 0);
    }

    /// By bisection on the CDF
    fn quantile(n: Normals, q: f64) f64 {
        const s: [2]f64 = .{ @sqrt(@max(n.v[0], 1e-300)), @sqrt(@max(n.v[1], 1e-300)) };
        var lo = @min(n.e[0] - 8 * s[0], n.e[1] - 8 * s[1]);
        var hi = @max(n.e[0] + 8 * s[0], n.e[1] + 8 * s[1]);
        for (0..100) |_| {
            const x = (lo + hi) / 2;
            const f = n.w * normCdf((x - n.e[0]) / s[0]) + (1 - n.w) * normCdf((x - n.e[1]) / s[1]);
            if (f < q) lo = x else hi = x;
        }
        return (lo + hi) / 2;
    }
};

/// Abramowitz and Stegun 7.1.26, error under 1.5e-7
fn normCdf(x: f64) f64 {
    const z = @abs(x) / std.math.sqrt2;
    const t = 1 / (1 + 0.3275911 * z);
    const poly = t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
    const erf = 1 - poly * @exp(-z * z);
    return if (x >= 0) 0.5 * (1 + erf) else 0.5 * (1 - erf);
}

/// Weighted games and wins of one champion-role, by patch slot, bracket and EUW1
const Counts = struct {
    n: [max_patches][4][2]f64 = @splat(@splat(@splat(0))),
    k: [max_patches][4][2]f64 = @splat(@splat(@splat(0))),
    /// Unweighted games, the newest patch only
    own: [4][2]f64 = @splat(@splat(0)),
};

const Fitted = struct {
    /// The main term's prior mean, from its popularity
    mu: f64 = 0,
    theta: [max_k]f64 = @splat(0),
    cov: [max_k * max_k]f64 = @splat(0),
};

const Shape = struct {
    patches: u8,
    walk: bool,

    fn params(s: Shape) usize {
        return 1 + s.patches + 3 + 1;
    }

    fn term(s: Shape, j: usize) Term {
        if (j == 0) return .main;
        if (j <= s.patches) return .patch;
        if (j <= s.patches + 3) return .bracket;
        return .euw;
    }

    fn design(s: Shape, patch: usize, bracket: usize, euw: usize, x: *[max_k]f64) void {
        x.* = @splat(0);
        x[0] = 1;
        // Walk: slot p carries the oldest slot's level and every step up to p
        if (s.walk) {
            for (patch..s.patches) |q| x[1 + q] = 1;
        } else x[1 + patch] = 1;
        if (bracket != 0) x[s.patches + bracket] = 1;
        if (euw != 0) x[s.patches + 4] = 1;
    }
};

/// One pair cell's games: weighted games and wins, the logit the two champion-roles'
/// own terms give it, and its newest-patch games unweighted
const PairCell = struct { n: f64, k: f64, off: f64 = 0, own: f64 };

/// One pair's shrunk term: a matchup (lower cr first, from its side) or a duo (bottom,
/// support)
const Pair = struct {
    class: u8,
    i: f64 = 0,
    /// The prior mean
    mu: f64 = 0,
    v: f64 = 0,
    /// Its cells in Model.pair_cells
    first: u32,
    len: u32,
    own: [4][2]f64 = @splat(@splat(0)),
    /// The posterior under the mixture prior (i and v its moments); w 1: Gaussian, i and v
    mix: Normals = .{},
};

pub const Model = struct {
    shape: Shape,
    sd: [n_terms]f64,
    /// The main term's prior mean: pop[0] + pop[1] * log share of its role's games
    pop: [2]f64 = .{ 0, 0 },
    index: std.AutoHashMapUnmanaged(u16, u32) = .empty,
    counts: []Counts = &.{},
    fitted: []Fitted = &.{},
    pair: Pairs = .{},
    keystone: Cond = .{},
    item: Cond = .{},
    /// Keystone shares, of the games with a keystone
    rune: Share = .{},
    /// Finished item shares, of the timelined games
    build: Share = .{},
    gold: Gold = .{},

    pub fn deinit(m: *Model, gpa: Allocator) void {
        m.index.deinit(gpa);
        gpa.free(m.counts);
        gpa.free(m.fitted);
        m.pair.deinit(gpa);
        m.keystone.deinit(gpa);
        m.item.deinit(gpa);
        m.rune.deinit(gpa);
        m.build.deinit(gpa);
        m.gold.deinit(gpa);
    }

    /// The newest patch's number for a cell; region 1 is EUW1, bracket 0 all ranks. null:
    /// a kind not estimated yet (gold14 is avg's), or a champion-role with no games. Two-lock
    /// kinds add both parts' terms on top of the champion-role (no three-way term); their
    /// own is the fewer of the two parts' games, an upper bound. A share's own is the
    /// games it is a share of
    pub fn rate(m: *const Model, kind: Kind, region: u1, bracket: u2, a: u16, b: u32) ?Estimate {
        return m.rateIn(kind, region, .of(bracket), a, b);
    }

    /// As rate, over a set of brackets pooled by the cell's games (a site rank floor)
    pub fn rateIn(m: *const Model, kind: Kind, region: u1, brackets: Brackets, a: u16, b: u32) ?Estimate {
        const i = m.index.get(a) orelse return null;
        if (kind == .rune or kind == .build) {
            const x = std.math.cast(u16, b) orelse return null;
            return (if (kind == .rune) &m.rune else &m.build).rate(m.shape, i, a, x, brackets, region);
        }
        const t = m.newest(i, brackets, region);
        const first: u16 = @truncate(b >> 16);
        const second: u16 = @truncate(b);
        const parts: [2]?Part = switch (kind) {
            .champion => return .of(t.eta, t.v, ownOf(&m.counts[i].own, brackets, region)),
            .matchup, .duo => blk: {
                const x = std.math.cast(u16, b) orelse return null;
                if (kind == .matchup and a == x) return .{ .p = 0.5, .lo = 0.5, .hi = 0.5, .own = 0 };
                break :blk .{ m.pairPart(&m.pair, m.counts, m.fitted, a, x, kind == .duo, brackets, region) orelse return null, null };
            },
            .keystone, .item => .{ m.condPart(if (kind == .keystone) &m.keystone else &m.item, i, a, std.math.cast(u16, b) orelse return null, brackets, region), null },
            .keystone_matchup, .item_matchup => blk: {
                if (a == second) return null;
                const c = if (kind == .keystone_matchup) &m.keystone else &m.item;
                const pair = m.pairPart(&m.pair, m.counts, m.fitted, a, second, false, brackets, region) orelse return null;
                break :blk .{ m.condPart(c, i, a, first, brackets, region), pair };
            },
            .keystone_item => .{ m.condPart(&m.keystone, i, a, first, brackets, region), m.condPart(&m.item, i, a, second, brackets, region) },
            .gold14, .build, .rune => return null,
        };
        var n: Normals = .one(t.eta, t.v);
        var own: f64 = std.math.inf(f64);
        for (parts) |part| if (part) |q| {
            n = n.add(q.normals());
            own = @min(own, q.own);
        };
        return .ofNormals(n, own);
    }

    /// Lane gold difference at 14 (gold14) in gold, newest patch: the champion-role's
    /// against any opponent, or b's lane (b != 0): minus b's, plus the pair's shrunk term
    pub fn avg(m: *const Model, kind: Kind, region: u1, bracket: u2, a: u16, b: u32) ?Estimate {
        return m.avgIn(kind, region, .of(bracket), a, b);
    }

    /// As avg, over a set of brackets (rateIn)
    pub fn avgIn(m: *const Model, kind: Kind, region: u1, brackets: Brackets, a: u16, b: u32) ?Estimate {
        if (kind != .gold14) return null;
        const i = m.index.get(a) orelse return null;
        const g = &m.gold;
        if (games(&g.counts[i]) == 0) return null;
        const t = newestOf(m.shape, &g.counts[i], &g.fitted[i], brackets, region);
        if (b == 0) return .ofAvg(t.eta, t.v, ownOf(&g.counts[i].own, brackets, region));
        const x = std.math.cast(u16, b) orelse return null;
        if (x == a) return .{ .p = 0, .lo = 0, .hi = 0, .own = 0 };
        const q = m.pairPart(&g.pair, g.counts, g.fitted, a, x, false, brackets, region) orelse return null;
        return .ofAvgNormals(Normals.one(t.eta, t.v).add(q.normals()), q.own);
    }

    /// A cell's terms on top of its champion-role's own, on the logit scale
    /// w < 1: a pair term's mixture, weight 1 - w on (e2, v2), else (e, v)
    const Part = struct {
        e: f64,
        v: f64,
        own: f64,
        w: f64 = 1,
        e2: f64 = 0,
        v2: f64 = 0,

        fn normals(q: Part) Normals {
            return .{ .w = q.w, .e = .{ q.e, q.e2 }, .v = .{ q.v, q.v2 } };
        }
    };

    /// Against a lane opponent (minus its number) or with a support (plus it), and the
    /// pair's shrunk term; null: the other champion-role has no games
    fn pairPart(m: *const Model, pairs: *const Pairs, counts: []const Counts, fitted: []const Fitted, a: u16, b: u16, duo: bool, brackets: Brackets, region: u1) ?Part {
        const ib = m.index.get(b) orelse return null;
        if (games(&counts[ib]) == 0) return null;
        const tb = newestOf(m.shape, &counts[ib], &fitted[ib], brackets, region);
        const lo: u16 = if (duo) a else @min(a, b);
        const hi: u16 = if (duo) b else @max(a, b);
        const sign: f64 = if (duo or lo == a) 1 else -1;
        var q: Part = .{ .e = if (duo) tb.eta else -tb.eta, .v = tb.v, .own = 0 };
        // Never seen: no pair term, the class's prior in the range
        const c = pairClass(lo, duo);
        var term: Normals = .one(0, pairs.sd[c] * pairs.sd[c]);
        if (pairs.prior[c].w < 1) term = pairs.prior[c];
        if (pairs.index.get(pairKey(lo, hi, duo))) |pi| {
            const p = &pairs.terms[pi];
            term = if (p.mix.w < 1) p.mix else .one(p.i, p.v);
            q.own = ownOf(&p.own, brackets, region);
        }
        q.w = term.w;
        q.e2 = q.e + sign * term.e[1];
        q.v2 = q.v + term.v[1];
        q.e += sign * term.e[0];
        q.v += term.v[0];
        return q;
    }

    /// With a keystone or item x: the champion-role's shift off its own mix, x's
    /// role-wide term and the shrunk champion-role x term (the share line if unseen)
    fn condPart(m: *const Model, c: *const Cond, i: u32, a: u16, x: u16, brackets: Brackets, region: u1) Part {
        const role = a >> 13;
        var q: Part = .{ .e = c.shift[i], .v = 0, .own = 0 };
        // Never seen: no term, the class's spread in the range
        if (c.main_index.get(@as(u32, role) << 16 | x)) |j| {
            q.e += c.mains[j].i;
            q.v += c.mains[j].v;
        } else q.v += c.main_sd[role] * c.main_sd[role];
        if (c.inter_index.get(@as(u32, a) << 16 | x)) |j| {
            const p = &c.inters[j];
            q.e += p.i;
            q.v += p.v;
            q.own = ownOf(&p.own, brackets, region);
        } else {
            const l = c.line[role];
            q.e += l[0] + l[1] * @max(Cond.shareOf(0, games(&m.counts[i])), c.least[role]);
            q.v += c.inter_sd[role] * c.inter_sd[role];
        }
        return q;
    }

    /// A champion-role's logit and its variance in one patch slot, bracket and region
    fn eta(m: *const Model, i: u32, patch: usize, bracket: usize, euw: usize) Logit {
        return etaOf(m.shape, &m.fitted[i], patch, bracket, euw);
    }

    fn newest(m: *const Model, i: u32, brackets: Brackets, region: u1) Logit {
        return newestOf(m.shape, &m.counts[i], &m.fitted[i], brackets, region);
    }
};

/// The fitted model as a file (`meiolol meio`, read by the renderer for the champion page
/// locks): every field rate() and avg() read, maps as their entries. The same build
/// writes and reads it; the fingerprint refuses another's
const file_magic = "MEIOMDL1";

/// Frees the per-slot cells only fitting reads; rate() and avg() answer as before
pub fn slim(m: *Model, gpa: Allocator) void {
    inline for (.{ &m.pair, &m.gold.pair, &m.keystone, &m.item }) |x| {
        gpa.free(x.cells);
        x.cells = &.{};
    }
}

pub fn save(w: *std.Io.Writer, m: *const Model) !void {
    try w.writeAll(file_magic);
    try w.writeInt(u64, fingerprint, .little);
    try putValue(w, m.*);
}

/// null for another format or build; everything in `arena` (no Model.deinit)
pub fn load(r: *std.Io.Reader, arena: Allocator) !?Model {
    var head: [file_magic.len + 8]u8 = undefined;
    r.readSliceAll(&head) catch return null;
    if (!std.mem.eql(u8, head[0..file_magic.len], file_magic)) return null;
    if (std.mem.readInt(u64, head[file_magic.len..][0..8], .little) != fingerprint) return null;
    return takeValue(Model, r, arena) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => null,
    };
}

const fingerprint = std.hash.Wyhash.hash(0, shapeOf(Model));

fn isMap(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct" or !@hasDecl(T, "KV")) return false;
    return T == std.AutoHashMapUnmanaged(@FieldType(T.KV, "key"), @FieldType(T.KV, "value"));
}

fn shapeOf(comptime T: type) []const u8 {
    @setEvalBranchQuota(100_000);
    if (comptime isMap(T)) return "map(" ++ shapeOf(@FieldType(T.KV, "key")) ++ "," ++ shapeOf(@FieldType(T.KV, "value")) ++ ")";
    return switch (@typeInfo(T)) {
        .@"struct" => |st| blk: {
            var out: []const u8 = "{";
            for (st.field_names, st.field_types) |name, F| out = out ++ name ++ ":" ++ shapeOf(F) ++ ",";
            break :blk out ++ "}";
        },
        .pointer => |ptr| "[]" ++ shapeOf(ptr.child),
        .array => |a| std.fmt.comptimePrint("[{d}]", .{a.len}) ++ shapeOf(a.child),
        else => std.fmt.comptimePrint("{x}", .{flat.fingerprint(T)}),
    };
}

/// flat's encoding, with hash maps as a count and their entries
fn putValue(w: *std.Io.Writer, value: anytype) !void {
    const T = @TypeOf(value);
    if (comptime isMap(T)) {
        try w.writeInt(u64, value.count(), .little);
        var it = value.iterator();
        while (it.next()) |e| {
            try flat.write(w, e.key_ptr.*);
            try flat.write(w, e.value_ptr.*);
        }
    } else switch (@typeInfo(T)) {
        .@"struct" => |st| inline for (st.field_names) |name| try putValue(w, @field(value, name)),
        else => try flat.write(w, value),
    }
}

fn takeValue(comptime T: type, r: *std.Io.Reader, arena: Allocator) flat.ReadError!T {
    if (comptime isMap(T)) {
        const n = std.math.cast(u32, try r.takeInt(u64, .little)) orelse return error.Corrupt;
        var map: T = .empty;
        try map.ensureTotalCapacity(arena, n);
        for (0..n) |_| {
            const k = try flat.read(@FieldType(T.KV, "key"), r, arena);
            map.putAssumeCapacity(k, try flat.read(@FieldType(T.KV, "value"), r, arena));
        }
        return map;
    }
    switch (@typeInfo(T)) {
        .@"struct" => |st| {
            var out: T = undefined;
            inline for (st.field_names, st.field_types) |name, F| @field(out, name) = try takeValue(F, r, arena);
            return out;
        },
        else => return flat.read(T, r, arena),
    }
}

fn etaOf(shape: Shape, f: *const Fitted, patch: usize, bracket: usize, euw: usize) Logit {
    var x: [max_k]f64 = undefined;
    shape.design(patch, bracket, euw, &x);
    return at(shape, f, &x);
}

/// The newest patch's logit for a set of brackets and a region: brackets and regions
/// averaged by the cell's games, as the raw rates pool them, rather than reading the
/// unknown-rank, other-region baseline. The variance is the mixed design's, so shared
/// terms count once
fn newestOf(shape: Shape, c: *const Counts, f: *const Fitted, brackets: Brackets, region: u1) Logit {
    const k = shape.params();
    var mix: [max_k]f64 = @splat(0);
    var x: [max_k]f64 = undefined;
    var total: f64 = 0;
    for (0..4) |br| for (0..2) |e| {
        if (!brackets.has(br)) continue;
        if (region == 1 and e == 0) continue;
        var n: f64 = 0;
        for (0..shape.patches) |p| n += c.n[p][br][e];
        if (n == 0) continue;
        shape.design(0, br, e, &x);
        for (mix[0..k], x[0..k]) |*a, b| a.* += n * b;
        total += n;
    };
    // No games in the slice: the slice's own terms, all at their prior
    if (total == 0) {
        if (brackets.mask == Brackets.all.mask) return etaOf(shape, f, 0, 0, region);
        for (1..4) |br| if (brackets.has(br)) {
            shape.design(0, br, region, &x);
            for (mix[0..k], x[0..k]) |*a, b| a.* += b;
            total += 1;
        };
    }
    for (mix[0..k]) |*a| a.* /= total;
    return at(shape, f, &mix);
}

fn at(shape: Shape, f: *const Fitted, x: *const [max_k]f64) Logit {
    const k = shape.params();
    var e: f64 = 0;
    var v: f64 = 0;
    for (0..k) |r| {
        if (x[r] == 0) continue;
        e += x[r] * f.theta[r];
        for (0..k) |c| v += x[r] * f.cov[r * k + c] * x[c];
    }
    return .{ .eta = e, .v = v };
}

/// Pair terms (matchups, duos) on top of their two champion-roles
const Pairs = struct {
    /// pair key (a << 16 | b) << 1 | duo -> terms
    index: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    terms: []Pair = &.{},
    cells: []PairCell = &.{},
    sd: [n_pair_classes]f64 = @splat(0),
    /// Per class, the mixture prior an unseen pair takes (pair_mix); w 1: N(0, sd^2)
    prior: [n_pair_classes]Normals = @splat(.{}),

    fn deinit(p: *Pairs, gpa: Allocator) void {
        p.index.deinit(gpa);
        gpa.free(p.terms);
        gpa.free(p.cells);
    }
};

/// E5, lane gold difference at 14: E3's form on the Gaussian scale, in thousands of gold
/// (one noise variance per game), and matchups' pair terms the same way. By
/// champion-role index (Model.index)
const Gold = struct {
    counts: []Counts = &.{},
    fitted: []Fitted = &.{},
    sd: [n_terms]f64 = @splat(0),
    /// A game's variance around its cell's mean
    noise: f64 = 1,
    pair: Pairs = .{},

    fn deinit(g: *Gold, gpa: Allocator) void {
        gpa.free(g.counts);
        gpa.free(g.fitted);
        g.pair.deinit(gpa);
    }
};

/// E6, the share of a champion-role's games with x (a keystone, a finished item): each
/// (champion-role, x) its own E3-shaped logit (shared + patch + bracket + EUW1), the
/// shared term shrunk to x's share across the role, so a patch's share leans on the
/// other patches' until its own games arrive. One binomial per option, not a
/// multinomial: a champion-role's keystone shares need not sum to 1
const Share = struct {
    /// cr << 16 | x -> counts, fitted
    index: std.AutoHashMapUnmanaged(u32, u32) = .empty,
    /// n: the games x could be in (Share.anchor's), k: those with x
    counts: []Counts = &.{},
    fitted: []Fitted = &.{},
    sd: [n_terms]f64 = @splat(0),
    /// By champion-role index: the games its shares are of (n and own)
    anchor: []Counts = &.{},
    /// role << 16 | x -> x's pooled share of the role's games, logit
    pooled: std.AutoHashMapUnmanaged(u32, f64) = .empty,
    role_n: [n_roles]f64 = @splat(0),
    drift: Drift = .{},

    fn deinit(s: *Share, gpa: Allocator) void {
        s.index.deinit(gpa);
        gpa.free(s.counts);
        gpa.free(s.fitted);
        gpa.free(s.anchor);
        s.pooled.deinit(gpa);
    }

    /// The shared term's prior mean: x's share of the role's games, or half a game of
    /// them if nobody in the role took x
    fn prior(s: *const Share, role: u16, x: u16) f64 {
        return s.pooled.get(@as(u32, role) << 16 | x) orelse logit(0.5 / (s.role_n[role] + 1));
    }

    fn rate(s: *const Share, shape: Shape, i: u32, a: u16, x: u16, brackets: Brackets, region: u1) ?Estimate {
        if (x == 0) return null;
        const anchor = &s.anchor[i];
        if (games(anchor) == 0) return null;
        const own = ownOf(&anchor.own, brackets, region);
        if (s.index.get(@as(u32, a) << 16 | x)) |j| {
            const t = newestOf(shape, &s.counts[j], &s.fitted[j], brackets, region);
            return .of(t.eta, t.v + s.drift.tau2In(&anchor.own, brackets, region), own);
        }
        // Never seen: its games with none of x, fitted on the spot
        const c: Counts = .{ .n = anchor.n, .own = anchor.own };
        const mu = s.prior(a >> 13, x);
        var f: Fitted = .{ .mu = mu };
        f.theta[0] = mu;
        newton(&c, &f, shape, s.sd, 0);
        const t = newestOf(shape, &c, &f, brackets, region);
        return .of(t.eta, t.v + s.drift.tau2In(&anchor.own, brackets, region), own);
    }
};

/// A share's spread beyond its fit, from Halves, per rank bracket and region (EUW1 or
/// not): games cluster (players repeat their picks), so a share's binomial variance is
/// phi times too small; and a share moves within a patch, tau2 on the logit scale over
/// about a week. A slot with too few cells takes the pooled fit
const Drift = struct {
    phi: [4][2]f64 = @splat(@splat(1)),
    tau2: [4][2]f64 = @splat(@splat(0)),
    cells: [4][2]f64 = @splat(@splat(0)),

    /// tau2 over a set of brackets, mixed by the newest patch's games
    fn tau2In(d: *const Drift, own: *const [4][2]f64, brackets: Brackets, region: u1) f64 {
        var t: f64 = 0;
        var n: f64 = 0;
        var plain: f64 = 0;
        var slots: f64 = 0;
        for (0..4) |br| for (0..2) |e| {
            if (!brackets.has(br) or (region == 1 and e == 0)) continue;
            t += own[br][e] * d.tau2[br][e];
            n += own[br][e];
            plain += d.tau2[br][e];
            slots += 1;
        };
        return if (n > 0) t / n else plain / slots;
    }
};

/// Within-patch halves for Drift: games by champion-role << 24 | x << 8 | slot, x 0 for
/// the games a share is of, slot = euw << 5 | bracket << 3 | patch << 1 | half.
/// Unweighted, the newest three patches, each split at its middle day when it has four
/// days or more
const Halves = struct {
    games: std.AutoHashMapUnmanaged(u64, f64) = .empty,

    fn deinit(h: *Halves, gpa: Allocator) void {
        h.games.deinit(gpa);
    }

    fn add(h: *Halves, gpa: Allocator, cr: u16, x: u16, slot: u8) !void {
        const g = try h.games.getOrPut(gpa, @as(u64, cr) << 24 | @as(u64, x) << 8 | slot);
        if (!g.found_existing) g.value_ptr.* = 0;
        g.value_ptr.* += 1;
    }

    fn get(h: *const Halves, key: u64) f64 {
        return h.games.get(key) orelse 0;
    }

    /// Each (champion-role, x, slot's patch): the squared difference d of its two halves'
    /// shares against b = q(1 - q)(1/n1 + 1/n2), the binomial variance of d, and
    /// c = (q(1 - q))^2, which turns a logit-scale variance into one of d. E[d^2] =
    /// phi b + tau2 c, fitted by weighted least squares (Var d^2 = 2 E[d^2]^2), pooled
    /// and per bracket and region
    fn drift(h: *const Halves, gpa: Allocator) !Drift {
        const min_games = 20;
        // A slot's own fit from this many cells (phi's sd ~0.2 at 60)
        const min_slot_cells = 300;
        var by_slot: [4][2]std.ArrayList([3]f64) = @splat(@splat(.empty));
        defer for (&by_slot) |*b| for (b) |*l| l.deinit(gpa);
        var all: std.ArrayList([3]f64) = .empty;
        defer all.deinit(gpa);
        var it = h.games.iterator();
        while (it.next()) |e| {
            const key = e.key_ptr.*;
            if (key >> 8 & 0xffff == 0 or key & 1 == 1) continue;
            const anchor = key & ~@as(u64, 0xffff_ff);
            const n1 = h.get(anchor | (key & 0xff));
            const n2 = h.get(anchor | (key & 0xff) | 1);
            if (n1 < min_games or n2 < min_games) continue;
            const k1 = @min(e.value_ptr.*, n1);
            const k2 = @min(h.get(key | 1), n2);
            const q = (k1 + k2) / (n1 + n2);
            if (q == 0 or q == 1) continue;
            const d = k1 / n1 - k2 / n2;
            const qq = q * (1 - q);
            const c: [3]f64 = .{ d * d, qq * (1 / n1 + 1 / n2), qq * qq };
            try all.append(gpa, c);
            try by_slot[key >> 3 & 3][key >> 5 & 1].append(gpa, c);
        }
        var out: Drift = .{};
        if (all.items.len < 30) return out;
        const pooled = phiTau(all.items);
        for (&out.phi, &out.tau2, &out.cells, by_slot) |*phi, *tau2, *cells, slots| {
            for (phi, tau2, cells, slots) |*p, *t, *n, l| {
                const f = if (l.items.len >= min_slot_cells) phiTau(l.items) else pooled;
                p.* = f[0];
                t.* = f[1];
                n.* = @floatFromInt(l.items.len);
            }
        }
        return out;
    }

    fn phiTau(cells: []const [3]f64) [2]f64 {
        var out: [2]f64 = .{ 1, 0 };
        for (0..20) |_| {
            var a: [3]f64 = @splat(0);
            var y: [2]f64 = @splat(0);
            for (cells) |c| {
                const e = out[0] * c[1] + out[1] * c[2];
                const w = 1 / (e * e);
                a[0] += w * c[1] * c[1];
                a[1] += w * c[1] * c[2];
                a[2] += w * c[2] * c[2];
                y[0] += w * c[1] * c[0];
                y[1] += w * c[2] * c[0];
            }
            const det = a[0] * a[2] - a[1] * a[1];
            var phi = (a[2] * y[0] - a[1] * y[1]) / det;
            var tau2 = (a[0] * y[1] - a[1] * y[0]) / det;
            // Bounded: no less spread than binomial, no negative drift
            if (phi < 1 or tau2 < 0) {
                phi = @max(1, phi);
                tau2 = @max(0, (y[1] - a[1] * phi) / a[2]);
            }
            const moved = @abs(phi - out[0]) + @abs(tau2 - out[1]);
            out = .{ phi, tau2 };
            if (moved < 1e-6) break;
        }
        return out;
    }
};

fn logit(p: f64) f64 {
    return @log(p / (1 - p));
}

/// A champion-role's win rate under a condition x (a keystone, an item it finished): its
/// own terms, plus x's role-wide term, plus a shrunk champion-role x condition term. Both
/// shrunk to 0, one variance per role each; fitted in that order on top of E3. A
/// champion-role's own rate already holds the conditions it takes, so it is first
/// shifted by minus their role-wide terms, weighted by its games: one that only takes a
/// weak keystone gains the full gap on a strong one it never took. The interaction
/// shrinks to a line, per role, in the log share of the champion-role's games with x:
/// an x it seldom takes does worse (16.21: under 0.1% of its games, 43% against its 49%)
const Cond = struct {
    /// role << 16 | x -> mains
    main_index: std.AutoHashMapUnmanaged(u32, u32) = .empty,
    mains: []Pair = &.{},
    /// cr << 16 | x -> inters
    inter_index: std.AutoHashMapUnmanaged(u32, u32) = .empty,
    inters: []Pair = &.{},
    /// Sorted by condKey: one main's cells are contiguous, and so are one inter's
    cells: []PairCell = &.{},
    /// By champion-role index (Model.index)
    shift: []f64 = &.{},
    main_sd: [n_roles]f64 = @splat(0),
    inter_sd: [n_roles]f64 = @splat(0),
    /// The interactions' prior mean: line[role][0] + line[role][1] * shareOf(cell, games)
    line: [n_roles][2]f64 = @splat(.{ 0, 0 }),
    /// The lowest share a fitted interaction has, per role: an unseen x reads the line
    /// no further out
    least: [n_roles]f64 = @splat(0),

    fn shareOf(with: f64, games_: f64) f64 {
        return @log((with + 0.5) / (games_ + 1));
    }

    fn deinit(c: *Cond, gpa: Allocator) void {
        c.main_index.deinit(gpa);
        gpa.free(c.mains);
        c.inter_index.deinit(gpa);
        gpa.free(c.inters);
        gpa.free(c.cells);
        gpa.free(c.shift);
    }

    /// A cell's own win rate over every slot, for tests
    fn raw(c: *const Cond, cr: u16, x: u16) f64 {
        const p = c.inters[c.inter_index.get(@as(u32, cr) << 16 | x).?];
        var n: f64 = 0;
        var k: f64 = 0;
        for (c.cells[p.first..][0..p.len]) |cell| {
            n += cell.n;
            k += cell.k;
        }
        return k / n;
    }
};

/// role | x | champion | patch slot << 3 | bracket << 1 | euw, so that sorting groups by
/// (role, x) and within it by champion-role
fn condKey(cr: u16, x: u16, slot: u64) u64 {
    return @as(u64, cr >> 13) << 37 | @as(u64, x) << 21 | @as(u64, cr & 0x1fff) << 8 | slot;
}

fn addCell(gpa: Allocator, cells: *std.AutoHashMapUnmanaged(u64, PairCell), key: u64, w: f64, win: f64, own: f64) !void {
    const pc = try cells.getOrPut(gpa, key);
    if (!pc.found_existing) pc.value_ptr.* = .{ .n = 0, .k = 0, .own = 0 };
    pc.value_ptr.n += w;
    pc.value_ptr.k += win;
    pc.value_ptr.own += own;
}

fn pairKey(a: u16, b: u16, duo: bool) u64 {
    return (@as(u64, a) << 16 | b) << 1 | @intFromBool(duo);
}

fn pairClass(a: u16, duo: bool) u8 {
    return if (duo) n_pair_classes - 1 else @intCast(a >> 13);
}

/// Unweighted newest-patch games of a set of brackets and region (0 every region)
fn ownOf(own: *const [4][2]f64, brackets: Brackets, region: u1) f64 {
    var n: f64 = 0;
    for (0..4) |br| {
        if (!brackets.has(br)) continue;
        n += own[br][1];
        if (region == 0) n += own[br][0];
    }
    return n;
}

pub fn sigmoid(z: f64) f64 {
    return 1 / (1 + @exp(-z));
}

/// The mean of sigmoid(eta + s z), z standard normal: a trapezoid over +-6 sd, exact
/// enough for a smooth integrand. The probit approximation strays far out on the logit,
/// where small shares sit (it put an unseen keystone's share above its own range)
fn meanSigmoid(eta: f64, s: f64) f64 {
    if (s == 0) return sigmoid(eta);
    const steps = 48;
    var sum: f64 = 0;
    var weights: f64 = 0;
    for (0..steps + 1) |j| {
        const z = -6 + 12 * @as(f64, @floatFromInt(j)) / steps;
        const w = @exp(-z * z / 2);
        sum += w * sigmoid(eta + s * z);
        weights += w;
    }
    return sum / weights;
}

/// Fits on every row with day < before_day
pub fn fit(gpa: Allocator, rows: []const Row, before_day: i32, opts: Options) !Model {
    std.debug.assert(opts.patches >= 1 and opts.patches <= max_patches);
    const shape: Shape = .{ .patches = opts.patches, .walk = opts.walk };
    var m: Model = .{ .shape = shape, .sd = opts.sd };
    errdefer m.deinit(gpa);
    var counts: std.ArrayList(Counts) = .empty;
    defer counts.deinit(gpa);
    // Per champion-role, as counts: gold, and the games its keystone and item shares are of
    var gold: std.ArrayList(Counts) = .empty;
    defer gold.deinit(gpa);
    var rune: std.ArrayList(Counts) = .empty;
    defer rune.deinit(gpa);
    var build: std.ArrayList(Counts) = .empty;
    defer build.deinit(gpa);
    var gold_sq: f64 = 0;
    // Pair cells by pair key << 8 | patch << 3 | bracket << 1 | euw
    var cells: std.AutoHashMapUnmanaged(u64, PairCell) = .empty;
    defer cells.deinit(gpa);
    var gold_cells: std.AutoHashMapUnmanaged(u64, PairCell) = .empty;
    defer gold_cells.deinit(gpa);
    var keystones: std.AutoHashMapUnmanaged(u64, PairCell) = .empty;
    defer keystones.deinit(gpa);
    var items: std.AutoHashMapUnmanaged(u64, PairCell) = .empty;
    defer items.deinit(gpa);
    var rune_halves: Halves = .{};
    defer rune_halves.deinit(gpa);
    var build_halves: Halves = .{};
    defer build_halves.deinit(gpa);
    // Each of the newest three patches' first and last day
    var span: [3][2]i32 = @splat(.{ std.math.maxInt(i32), std.math.minInt(i32) });
    for (rows) |r| if (r.day < before_day and r.patch < 3) {
        span[r.patch][0] = @min(span[r.patch][0], r.day);
        span[r.patch][1] = @max(span[r.patch][1], r.day);
    };
    const ln2 = @log(2.0);
    for (rows) |r| {
        if (r.day >= before_day) continue;
        if (r.patch < 3 and span[r.patch][1] - span[r.patch][0] >= 3) {
            const mid = @divFloor(span[r.patch][0] + span[r.patch][1] + 1, 2);
            const slot: u8 = @as(u8, @intFromBool(r.euw)) << 2 | r.bracket;
            const ph: u8 = slot << 3 | @as(u8, r.patch) << 1 | @intFromBool(r.day >= mid);
            if (r.keystone != 0) {
                try rune_halves.add(gpa, r.cr, 0, ph);
                try rune_halves.add(gpa, r.cr, r.keystone, ph);
            }
            if (r.timeline) {
                try build_halves.add(gpa, r.cr, 0, ph);
                for (r.items) |x| if (x != 0) try build_halves.add(gpa, r.cr, x, ph);
            }
        }
        const e = try m.index.getOrPut(gpa, r.cr);
        if (!e.found_existing) {
            e.value_ptr.* = @intCast(counts.items.len);
            try counts.append(gpa, .{});
            try gold.append(gpa, .{});
            try rune.append(gpa, .{});
            try build.append(gpa, .{});
        }
        const c = &counts.items[e.value_ptr.*];
        const age: f64 = @floatFromInt(before_day - 1 - r.day);
        const w = if (opts.half_life > 0) @exp(-ln2 * age / opts.half_life) else 1;
        const p = @min(r.patch, opts.patches - 1);
        const euw: usize = @intFromBool(r.euw);
        const win: f64 = if (r.win) w else 0;
        const own: f64 = if (r.patch == 0) 1 else 0;
        c.n[p][r.bracket][euw] += w;
        c.k[p][r.bracket][euw] += win;
        c.own[r.bracket][euw] += own;
        const slot = @as(u64, p) << 3 | @as(u64, r.bracket) << 1 | euw;
        // A lane counted once, from the lower champion-role's side; mirrors are 50%
        if (r.opp != 0 and r.cr < r.opp) try addCell(gpa, &cells, pairKey(r.cr, r.opp, false) << 8 | slot, w, win, own);
        if (r.ally != 0) try addCell(gpa, &cells, pairKey(r.cr, r.ally, true) << 8 | slot, w, win, own);
        if (r.keystone != 0) {
            try addCell(gpa, &keystones, condKey(r.cr, r.keystone, slot), w, win, own);
            const a = &rune.items[e.value_ptr.*];
            a.n[p][r.bracket][euw] += w;
            a.own[r.bracket][euw] += own;
        }
        // Items are known only in timelined games, as truth counts them
        if (r.timeline) {
            for (r.items) |x| if (x != 0) try addCell(gpa, &items, condKey(r.cr, x, slot), w, win, own);
            const a = &build.items[e.value_ptr.*];
            a.n[p][r.bracket][euw] += w;
            a.own[r.bracket][euw] += own;
        }
        if (r.gold != no_gold) {
            const y = @as(f64, @floatFromInt(r.gold)) / 1000;
            const g = &gold.items[e.value_ptr.*];
            g.n[p][r.bracket][euw] += w;
            g.k[p][r.bracket][euw] += w * y;
            g.own[r.bracket][euw] += own;
            gold_sq += w * y * y;
            if (r.opp != 0 and r.cr < r.opp) try addCell(gpa, &gold_cells, pairKey(r.cr, r.opp, false) << 8 | slot, w, w * y, own);
        }
    }
    m.counts = try counts.toOwnedSlice(gpa);
    m.fitted = try gpa.alloc(Fitted, m.counts.len);
    @memset(m.fitted, .{});

    const share = try logShares(gpa, &m);
    defer gpa.free(share);
    m.sd = fitLevels(m.counts, m.fitted, shape, opts.sd, 0, opts.rounds, .{ .m = &m, .share = share });
    m.pair = try fitPairs(gpa, shape, &m.index, m.fitted, &cells, 0, opts.rounds, opts.pair_mix);
    m.keystone = try fitCond(gpa, &m, &keystones, opts.rounds);
    m.item = try fitCond(gpa, &m, &items, opts.rounds);
    m.rune = try fitShare(gpa, &m, try rune.toOwnedSlice(gpa), &keystones, try rune_halves.drift(gpa), opts.rounds);
    m.build = try fitShare(gpa, &m, try build.toOwnedSlice(gpa), &items, try build_halves.drift(gpa), opts.rounds);
    m.gold = try fitGold(gpa, &m, try gold.toOwnedSlice(gpa), gold_sq, &gold_cells, opts.rounds, opts.pair_mix);
    return m;
}

/// The champion-role's main term's popularity line, refitted each round (E3 only)
const Pop = struct { m: *Model, share: []const f64 };

/// E3's terms for each cell, its variances by MacKay; noise 0: binomial, else Gaussian
/// with that variance per game. Returns the variances
fn fitLevels(counts: []const Counts, fitted: []Fitted, shape: Shape, fixed: [n_terms]f64, noise: f64, rounds: u8, pop: ?Pop) [n_terms]f64 {
    var sd: [n_terms]f64 = undefined;
    for (&sd, fixed) |*s, o| s.* = if (o > 0) o else 0.1;
    const k = shape.params();
    for (0..rounds) |_| {
        var sum_sq: [n_terms]f64 = @splat(0);
        var gamma: [n_terms]f64 = @splat(0);
        for (counts, fitted) |*c, *f| {
            newton(c, f, shape, sd, noise);
            for (0..k) |j| {
                const t = @backingInt(shape.term(j));
                const d = f.theta[j] - (if (j == 0) f.mu else 0);
                sum_sq[t] += d * d;
                gamma[t] += 1 - f.cov[j * k + j] / (sd[t] * sd[t]);
            }
        }
        const pop_moved = if (pop) |q| fitPopularity(q.m, q.share) else 0;
        if (!mackay(&sd, &fixed, &sum_sq, &gamma) and pop_moved < 1e-5) break;
    }
    for (counts, fitted) |*c, *f| newton(c, f, shape, sd, noise);
    return sd;
}

/// Shares from the condition's cells (k: its weighted games with x) and each
/// champion-role's anchor games (owned by the result). Games count 1 / phi each, so the
/// fit's variances carry the clustering; the range adds the drift
fn fitShare(gpa: Allocator, m: *const Model, anchor: []Counts, map: *const std.AutoHashMapUnmanaged(u64, PairCell), drift: Drift, rounds: u8) !Share {
    var s: Share = .{ .anchor = anchor, .drift = drift };
    errdefer s.deinit(gpa);
    var it = m.index.iterator();
    while (it.next()) |e| s.role_n[e.key_ptr.* >> 13] += games(&anchor[e.value_ptr.*]);
    var counts: std.ArrayList(Counts) = .empty;
    defer counts.deinit(gpa);
    var with: std.AutoHashMapUnmanaged(u32, f64) = .empty;
    defer with.deinit(gpa);
    var cells = map.iterator();
    while (cells.next()) |e| {
        const key = e.key_ptr.*;
        const role: u16 = @intCast(key >> 37);
        const x: u16 = @intCast(key >> 21 & 0xffff);
        const cr: u16 = role << 13 | @as(u16, @intCast(key >> 8 & 0x1fff));
        const g = try s.index.getOrPut(gpa, @as(u32, cr) << 16 | x);
        if (!g.found_existing) {
            g.value_ptr.* = @intCast(counts.items.len);
            const a = &anchor[m.index.get(cr).?];
            try counts.append(gpa, .{ .n = a.n, .own = a.own });
        }
        const slot = key & 0xff;
        counts.items[g.value_ptr.*].k[slot >> 3][slot >> 1 & 3][slot & 1] += e.value_ptr.n;
        const w = try with.getOrPut(gpa, @as(u32, role) << 16 | x);
        if (!w.found_existing) w.value_ptr.* = 0;
        w.value_ptr.* += e.value_ptr.n;
    }
    var pooled = with.iterator();
    while (pooled.next()) |e| try s.pooled.put(gpa, e.key_ptr.*, logit((e.value_ptr.* + 0.5) / (s.role_n[e.key_ptr.* >> 16] + 1)));
    s.counts = try counts.toOwnedSlice(gpa);
    for (anchor) |*a| for (&a.n) |*np| for (np, drift.phi) |*nb, pb| for (nb, pb) |*ne, phi| {
        ne.* /= phi;
    };
    s.fitted = try gpa.alloc(Fitted, s.counts.len);
    var keys = s.index.iterator();
    while (keys.next()) |e| {
        const c = &s.counts[e.value_ptr.*];
        // An item twice in one game counts twice, as truth counts it; a share stays <= 1
        for (&c.k, c.n) |*kp, np| for (kp, np, drift.phi) |*kb, nb, pb| for (kb, nb, pb) |*ke, ne, phi| {
            ke.* = @min(ke.*, ne) / phi;
        };
        for (&c.n) |*np| for (np, drift.phi) |*nb, pb| for (nb, pb) |*ne, phi| {
            ne.* /= phi;
        };
        const mu = s.prior(@intCast(e.key_ptr.* >> 29), @truncate(e.key_ptr.*));
        s.fitted[e.value_ptr.*] = .{ .mu = mu };
        s.fitted[e.value_ptr.*].theta[0] = mu;
    }
    s.sd = fitLevels(s.counts, s.fitted, m.shape, @splat(0), 0, rounds, null);
    return s;
}

/// Gold from each champion-role's games (owned by the result) and its lanes' cells
fn fitGold(gpa: Allocator, m: *const Model, counts: []Counts, sum_sq: f64, cells: *const std.AutoHashMapUnmanaged(u64, PairCell), rounds: u8, mix: bool) !Gold {
    var g: Gold = .{ .counts = counts };
    errdefer g.deinit(gpa);
    g.fitted = try gpa.alloc(Fitted, counts.len);
    @memset(g.fitted, .{});
    // The noise: games' spread around their champion-role's mean
    var ss = sum_sq;
    var n: f64 = 0;
    var groups: f64 = 0;
    for (counts) |*c| {
        const cn = games(c);
        if (cn == 0) continue;
        var y: f64 = 0;
        for (c.k) |p| for (p) |br| for (br) |x| {
            y += x;
        };
        ss -= y * y / cn;
        n += cn;
        groups += 1;
    }
    g.noise = if (n > groups + 1) @max(ss / (n - groups), 1e-6) else 1;
    g.sd = fitLevels(g.counts, g.fitted, m.shape, @splat(0), g.noise, rounds, null);
    g.pair = try fitPairs(gpa, m.shape, &m.index, g.fitted, cells, g.noise, rounds, mix);
    return g;
}

/// Each champion-role's log share of its role's (weighted) games
fn logShares(gpa: Allocator, m: *const Model) ![]f64 {
    const out = try gpa.alloc(f64, m.counts.len);
    var role_n: [n_roles]f64 = @splat(0);
    var it = m.index.iterator();
    while (it.next()) |e| {
        out[e.value_ptr.*] = games(&m.counts[e.value_ptr.*]);
        role_n[e.key_ptr.* >> 13] += out[e.value_ptr.*];
    }
    it = m.index.iterator();
    while (it.next()) |e| {
        const i = e.value_ptr.*;
        out[i] = @log(@max(out[i], 1e-9) / role_n[e.key_ptr.* >> 13]);
    }
    return out;
}

fn games(c: *const Counts) f64 {
    var n: f64 = 0;
    for (c.n) |p| for (p) |br| for (br) |x| {
        n += x;
    };
    return n;
}

/// The main terms' line in log share: least squares of their posterior means (the EM
/// step for a Gaussian prior's mean), then each prior mean from it; how far pop moved
fn fitPopularity(m: *Model, share: []const f64) f64 {
    const n: f64 = @floatFromInt(share.len);
    var mx: f64 = 0;
    var my: f64 = 0;
    for (share, m.fitted) |x, f| {
        mx += x;
        my += f.theta[0];
    }
    mx /= n;
    my /= n;
    var sxx: f64 = 0;
    var sxy: f64 = 0;
    for (share, m.fitted) |x, f| {
        sxx += (x - mx) * (x - mx);
        sxy += (x - mx) * (f.theta[0] - my);
    }
    // Every champion-role equally popular: no slope to see
    const b = if (sxx > 1e-9 * n) sxy / sxx else 0;
    const pop: [2]f64 = .{ my - b * mx, b };
    const moved = @max(@abs(pop[0] - m.pop[0]), @abs(pop[1] - m.pop[1]));
    m.pop = pop;
    for (share, m.fitted) |x, *f| f.mu = pop[0] + pop[1] * x;
    return moved;
}

/// MacKay's fixed point for each variance not fixed by the options; false once settled
fn mackay(sd: []f64, fixed: []const f64, sum_sq: []const f64, gamma: []const f64) bool {
    var moved: f64 = 0;
    for (sd, fixed, sum_sq, gamma) |*s, o, q, g| {
        if (o > 0) continue;
        // A floor keeps a term the data can't see from collapsing to exactly 0
        const new = @max(@sqrt(q / @max(g, 1e-9)), 1e-4);
        moved = @max(moved, @abs(new - s.*) / s.*);
        s.* = new;
    }
    return moved >= 1e-4;
}

/// Pair terms on top of the fitted champion-roles: each pair cell's logit is the two
/// champion-roles' (matchup: one minus the other; duo: the sum) plus the pair's term
fn fitPairs(gpa: Allocator, shape: Shape, index: *const std.AutoHashMapUnmanaged(u16, u32), fitted: []const Fitted, cells: *const std.AutoHashMapUnmanaged(u64, PairCell), noise: f64, rounds: u8, mix: bool) !Pairs {
    const keys = try sortedKeys(gpa, cells);
    defer gpa.free(keys);

    var out_pairs: Pairs = .{};
    errdefer out_pairs.deinit(gpa);
    out_pairs.cells = try gpa.alloc(PairCell, keys.len);
    var pairs: std.ArrayList(Pair) = .empty;
    defer pairs.deinit(gpa);
    for (keys, out_pairs.cells, 0..) |key, *out, j| {
        const pk = key >> 8;
        const duo = pk & 1 != 0;
        const a: u16 = @intCast(pk >> 17);
        const b: u16 = @intCast(pk >> 1 & 0xffff);
        const slot = key & 0xff;
        const patch: usize = @intCast(slot >> 3);
        const bracket: usize = @intCast(slot >> 1 & 3);
        const euw: usize = @intCast(slot & 1);
        out.* = cells.get(key).?;
        // Both sides of a game have rows, unless a caller dropped some: then 0
        const ta = if (index.get(a)) |i| etaOf(shape, &fitted[i], patch, bracket, euw).eta else 0;
        const tb = if (index.get(b)) |i| etaOf(shape, &fitted[i], patch, bracket, euw).eta else 0;
        out.off = ta + (if (duo) tb else -tb);
        if (j == 0 or keys[j - 1] >> 8 != pk) {
            try out_pairs.index.put(gpa, pk, @intCast(pairs.items.len));
            try pairs.append(gpa, .{ .class = pairClass(a, duo), .first = @intCast(j), .len = 0 });
        }
        const p = &pairs.items[pairs.items.len - 1];
        p.len += 1;
        p.own[bracket][euw] += out.own;
    }
    out_pairs.terms = try pairs.toOwnedSlice(gpa);
    fitTerms(out_pairs.terms, out_pairs.cells, &out_pairs.sd, noise, rounds);
    if (mix) fitTermsMixed(&out_pairs, noise, rounds);
    return out_pairs;
}

/// Sorted keys of a cell map
fn sortedKeys(gpa: Allocator, cells: *const std.AutoHashMapUnmanaged(u64, PairCell)) ![]u64 {
    const keys = try gpa.alloc(u64, cells.count());
    var it = cells.keyIterator();
    var n: usize = 0;
    while (it.next()) |key| : (n += 1) keys[n] = key.*;
    std.mem.sortUnstable(u64, keys, {}, std.sort.asc(u64));
    return keys;
}

fn fitCond(gpa: Allocator, m: *const Model, map: *const std.AutoHashMapUnmanaged(u64, PairCell), rounds: u8) !Cond {
    var c: Cond = .{};
    errdefer c.deinit(gpa);
    const keys = try sortedKeys(gpa, map);
    defer gpa.free(keys);
    c.cells = try gpa.alloc(PairCell, keys.len);
    c.shift = try gpa.alloc(f64, m.counts.len);
    @memset(c.shift, 0);
    // Each cell's champion-role index and E3 logit
    const cri = try gpa.alloc(u32, keys.len);
    defer gpa.free(cri);
    const base = try gpa.alloc(f64, keys.len);
    defer gpa.free(base);
    const total = try gpa.alloc(f64, m.counts.len);
    defer gpa.free(total);
    var mains: std.ArrayList(Pair) = .empty;
    defer mains.deinit(gpa);
    var inters: std.ArrayList(Pair) = .empty;
    defer inters.deinit(gpa);
    for (keys, c.cells, 0..) |key, *out, j| {
        const role: u16 = @intCast(key >> 37);
        const x: u16 = @intCast(key >> 21 & 0xffff);
        const cr: u16 = role << 13 | @as(u16, @intCast(key >> 8 & 0x1fff));
        const patch: usize = @intCast(key >> 3 & 0x1f);
        const bracket: usize = @intCast(key >> 1 & 3);
        const euw: usize = @intCast(key & 1);
        out.* = map.get(key).?;
        cri[j] = m.index.get(cr).?;
        base[j] = m.eta(cri[j], patch, bracket, euw).eta;
        if (j == 0 or keys[j - 1] >> 21 != key >> 21) {
            try c.main_index.put(gpa, @as(u32, role) << 16 | x, @intCast(mains.items.len));
            try mains.append(gpa, .{ .class = @intCast(role), .first = @intCast(j), .len = 0 });
        }
        mains.items[mains.items.len - 1].len += 1;
        if (j == 0 or keys[j - 1] >> 8 != key >> 8) {
            try c.inter_index.put(gpa, @as(u32, cr) << 16 | x, @intCast(inters.items.len));
            try inters.append(gpa, .{ .class = @intCast(role), .first = @intCast(j), .len = 0 });
        }
        const p = &inters.items[inters.items.len - 1];
        p.len += 1;
        p.own[bracket][euw] += out.own;
    }
    c.mains = try mains.toOwnedSlice(gpa);
    c.inters = try inters.toOwnedSlice(gpa);
    for (0..10) |_| {
        for (c.cells, cri, base) |*cell, i, b| cell.off = b + c.shift[i];
        fitTerms(c.mains, c.cells, &c.main_sd, 0, rounds);
        @memset(c.shift, 0);
        @memset(total, 0);
        for (c.mains) |p| for (c.cells[p.first..][0..p.len], cri[p.first..][0..p.len]) |cell, i| {
            c.shift[i] -= cell.n * p.i;
            total[i] += cell.n;
        };
        for (c.shift, total) |*sh, t| sh.* = if (t > 0) sh.* / t else 0;
    }
    // Two stages, as pairs on top of E3: the interactions see the role-wide terms as fixed
    for (c.cells, cri, base) |*cell, i, b| cell.off = b + c.shift[i];
    for (c.mains) |p| for (c.cells[p.first..][0..p.len]) |*cell| {
        cell.off += p.i;
    };
    const share = try gpa.alloc(f64, c.inters.len);
    defer gpa.free(share);
    for (c.inters, share) |p, *x| {
        var with: f64 = 0;
        for (c.cells[p.first..][0..p.len]) |cell| with += cell.n;
        x.* = Cond.shareOf(with, games(&m.counts[cri[p.first]]));
        c.least[p.class] = @min(c.least[p.class], x.*);
    }
    fitTermsOnLine(c.inters, c.cells, &c.inter_sd, &c.line, share, 0, rounds);
    return c;
}

/// Shrunk single terms on fixed offsets, one variance per class (MacKay); noise as newton's
fn fitTerms(terms: []Pair, cells: []const PairCell, sd_out: []f64, noise: f64, rounds: u8) void {
    fitTermsOnLine(terms, cells, sd_out, null, &.{}, noise, rounds);
}

/// fitTerms with each class's prior mean a line in x (one per term), fitted as the
/// champion-roles' popularity line is (fitPopularity)
fn fitTermsOnLine(terms: []Pair, cells: []const PairCell, sd_out: []f64, line: ?*[n_roles][2]f64, x: []const f64, noise: f64, rounds: u8) void {
    var sd: [n_roles]f64 = @splat(0.1);
    const fixed: [n_roles]f64 = @splat(0);
    const classes = sd_out.len;
    for (0..rounds) |_| {
        var sum_sq: [n_roles]f64 = @splat(0);
        var gamma: [n_roles]f64 = @splat(0);
        for (terms) |*p| {
            pairNewton(p, cells[p.first..][0..p.len], sd[p.class], noise);
            sum_sq[p.class] += (p.i - p.mu) * (p.i - p.mu);
            gamma[p.class] += 1 - p.v / (sd[p.class] * sd[p.class]);
        }
        const moved = if (line) |l| fitLines(terms, x, l) else 0;
        if (!mackay(sd[0..classes], fixed[0..classes], sum_sq[0..classes], gamma[0..classes]) and moved < 1e-5) break;
    }
    for (terms) |*p| pairNewton(p, cells[p.first..][0..p.len], sd[p.class], noise);
    @memcpy(sd_out, sd[0..classes]);
}

/// Per class, least squares of the terms' posterior means on x; sets each prior mean,
/// returns how far a line moved
fn fitLines(terms: []Pair, x: []const f64, line: *[n_roles][2]f64) f64 {
    var n: [n_roles]f64 = @splat(0);
    var mx: [n_roles]f64 = @splat(0);
    var my: [n_roles]f64 = @splat(0);
    for (terms, x) |p, xi| {
        n[p.class] += 1;
        mx[p.class] += xi;
        my[p.class] += p.i;
    }
    for (&mx, &my, n) |*a, *b, c| if (c > 0) {
        a.* /= c;
        b.* /= c;
    };
    var sxx: [n_roles]f64 = @splat(0);
    var sxy: [n_roles]f64 = @splat(0);
    for (terms, x) |p, xi| {
        sxx[p.class] += (xi - mx[p.class]) * (xi - mx[p.class]);
        sxy[p.class] += (xi - mx[p.class]) * (p.i - my[p.class]);
    }
    var moved: f64 = 0;
    for (line, n, mx, my, sxx, sxy) |*l, c, a, b, xx, xy| {
        if (c == 0) continue;
        const slope = if (xx > 1e-9 * c) xy / xx else 0;
        const new: [2]f64 = .{ b - slope * a, slope };
        moved = @max(moved, @max(@abs(new[0] - l[0]), @abs(new[1] - l[1])));
        l.* = new;
    }
    for (terms, x) |*p, xi| p.mu = line[p.class][0] + line[p.class][1] * xi;
    return moved;
}

/// From fitTerms' Gaussian fit, each class's prior as pi N(mu, s1^2) + (1 - pi) N(mu,
/// s2^2), s2 >= s1, by EM: a term's posterior is its two parts' Laplace posteriors
/// weighted by their marginal likelihoods (Pair.mix; i and v its moments). The scales
/// have a floor (a marginal-likelihood scale can collapse to 0, and a slab started from
/// a collapsed sd could not grow) and a cap, the widest spread of real pair effects we
/// believe in. sd becomes the mixture's, prior the one an unseen pair takes
fn fitTermsMixed(pairs: *Pairs, noise: f64, rounds: u8) void {
    // Logit, or thousands of gold
    const floor: f64 = if (noise > 0) 0.01 else 0.02;
    const cap: f64 = if (noise > 0) 1 else 0.5;
    const cells = pairs.cells;
    var s1: [n_pair_classes]f64 = undefined;
    var s2: [n_pair_classes]f64 = undefined;
    var pi: [n_pair_classes]f64 = @splat(0.8);
    for (pairs.sd, &s1, &s2) |sd, *a, *b| {
        a.* = std.math.clamp(sd * 0.7, floor, cap);
        b.* = std.math.clamp(sd * 2.5, 4 * floor, cap);
    }
    for (0..rounds + 1) |round| {
        var r_sum: [n_pair_classes]f64 = @splat(0);
        var n: [n_pair_classes]f64 = @splat(0);
        var m1: [n_pair_classes]f64 = @splat(0);
        var m2: [n_pair_classes]f64 = @splat(0);
        for (pairs.terms) |*p| {
            const c = p.class;
            const a = mixPart(p.*, cells[p.first..][0..p.len], s1[c], noise);
            const b = mixPart(p.*, cells[p.first..][0..p.len], s2[c], noise);
            const r = sigmoid(@log(pi[c]) + a.ll - @log(1 - pi[c]) - b.ll);
            p.mix = .{ .w = r, .e = .{ a.i, b.i }, .v = .{ a.v, b.v } };
            p.i = p.mix.mean();
            p.v = p.mix.variance();
            r_sum[c] += r;
            n[c] += 1;
            m1[c] += r * ((a.i - p.mu) * (a.i - p.mu) + a.v);
            m2[c] += (1 - r) * ((b.i - p.mu) * (b.i - p.mu) + b.v);
        }
        if (round == rounds) break;
        var moved: f64 = 0;
        for (0..n_pair_classes) |c| {
            if (n[c] == 0 or r_sum[c] <= 0 or r_sum[c] >= n[c]) continue;
            const new_pi = std.math.clamp(r_sum[c] / n[c], 0.05, 0.99);
            var a = std.math.clamp(@sqrt(m1[c] / r_sum[c]), floor, cap);
            var b = std.math.clamp(@sqrt(m2[c] / (n[c] - r_sum[c])), floor, cap);
            // Keep part 2 the wide one
            if (b < a) std.mem.swap(f64, &a, &b);
            moved = @max(moved, @max(@abs(new_pi - pi[c]), @max(@abs(a - s1[c]), @abs(b - s2[c]))));
            pi[c] = new_pi;
            s1[c] = a;
            s2[c] = b;
        }
        if (moved < 1e-5) break;
    }
    for (&pairs.sd, &pairs.prior, pi, s1, s2) |*sd, *prior, w, a, b| {
        sd.* = @sqrt(w * a * a + (1 - w) * b * b);
        prior.* = .{ .w = w, .v = .{ a * a, b * b } };
    }
}

/// A term's Laplace posterior under one Gaussian prior part, and its log marginal
/// likelihood up to a constant shared by the parts
fn mixPart(p: Pair, cells: []const PairCell, sd: f64, noise: f64) struct { i: f64, v: f64, ll: f64 } {
    var q = p;
    pairNewton(&q, cells, sd, noise);
    var ll: f64 = 0;
    for (cells) |c| {
        const eta = c.off + q.i;
        if (noise > 0) {
            ll += (c.k * eta - 0.5 * c.n * eta * eta) / noise;
            continue;
        }
        // log sigmoid(eta) k + log sigmoid(-eta) (n - k), stable at large |eta|
        ll -= c.k * softplus(-eta) + (c.n - c.k) * softplus(eta);
    }
    const z = (q.i - p.mu) / sd;
    ll += -0.5 * z * z - @log(sd) + 0.5 * @log(q.v);
    return .{ .i = q.i, .v = q.v, .ll = ll };
}

fn softplus(x: f64) f64 {
    return if (x > 0) x + std.math.log1p(@exp(-x)) else std.math.log1p(@exp(x));
}

/// noise as newton's; a Gaussian cell's k is its sum
fn pairNewton(p: *Pair, cells: []const PairCell, sd: f64, noise: f64) void {
    const prec = 1 / (sd * sd);
    for (0..8) |_| {
        var g = -prec * (p.i - p.mu);
        var h = prec;
        for (cells) |c| {
            if (noise > 0) {
                g += (c.k - c.n * (c.off + p.i)) / noise;
                h += c.n / noise;
                continue;
            }
            const q = sigmoid(c.off + p.i);
            g += c.k - c.n * q;
            h += c.n * q * (1 - q);
        }
        p.v = 1 / h;
        p.i += g / h;
        if (@abs(g / h) < 1e-10) break;
    }
}

/// Newton steps on one cell's penalised log likelihood from its current terms; leaves the
/// posterior covariance (inverse Hessian) in f.cov. noise 0: binomial (k wins of n), else
/// Gaussian with that variance per game (k the sum of n games)
fn newton(c: *const Counts, f: *Fitted, shape: Shape, sd: [n_terms]f64, noise: f64) void {
    const max_step = 2;
    const k = shape.params();
    var prec: [max_k]f64 = undefined;
    for (0..k) |j| {
        const s = sd[@backingInt(shape.term(j))];
        prec[j] = 1 / (s * s);
    }
    var x: [max_k]f64 = undefined;
    for (0..8) |_| {
        var grad: [max_k]f64 = @splat(0);
        var hess: [max_k * max_k]f64 = @splat(0);
        for (0..k) |j| {
            grad[j] = -prec[j] * (f.theta[j] - (if (j == 0) f.mu else 0));
            hess[j * k + j] = prec[j];
        }
        for (0..shape.patches) |p| for (0..4) |br| for (0..2) |e| {
            const n = c.n[p][br][e];
            if (n == 0) continue;
            shape.design(p, br, e, &x);
            var eta: f64 = 0;
            for (0..k) |j| eta += x[j] * f.theta[j];
            const q = sigmoid(eta);
            const r = if (noise > 0) (c.k[p][br][e] - n * eta) / noise else c.k[p][br][e] - n * q;
            const wt = if (noise > 0) n / noise else n * q * (1 - q);
            for (0..k) |i| {
                if (x[i] == 0) continue;
                grad[i] += r;
                for (0..k) |j| hess[i * k + j] += wt * x[j];
            }
        };
        invert(hess[0 .. k * k], k, f.cov[0 .. k * k]);
        var delta: [max_k]f64 = @splat(0);
        var step: f64 = 0;
        for (0..k) |i| {
            for (0..k) |j| delta[i] += f.cov[i * k + j] * grad[j];
            step = @max(step, @abs(delta[i]));
        }
        // A share of 0 or 1 in every slot has no finite optimum: under a weak prior a full
        // step can overflow, and one NaN collapses every variance through MacKay
        const scale = @min(1, max_step / step);
        for (0..k) |i| f.theta[i] += scale * delta[i];
        if (step < 1e-10) break;
    }
}

/// out = a^-1 for a symmetric positive definite k x k matrix (Gauss-Jordan; a is
/// overwritten)
fn invert(a: []f64, k: usize, out: []f64) void {
    @memset(out, 0);
    for (0..k) |i| out[i * k + i] = 1;
    for (0..k) |col| {
        const pivot = a[col * k + col];
        for (0..k) |j| {
            a[col * k + j] /= pivot;
            out[col * k + j] /= pivot;
        }
        for (0..k) |r| {
            if (r == col) continue;
            const f = a[r * k + col];
            if (f == 0) continue;
            for (0..k) |j| {
                a[r * k + j] -= f * a[col * k + j];
                out[r * k + j] -= f * out[col * k + j];
            }
        }
    }
}

fn testRow(cr: u16, day: i16, patch: u8, bracket: u2, win: bool) Row {
    return .{ .day = day, .cr = cr, .win = win, .euw = false, .patch = patch, .bracket = bracket };
}

test "invert" {
    var a = [_]f64{ 4, 2, 2, 3 };
    var out: [4]f64 = undefined;
    invert(&a, 2, &out);
    // [[4,2],[2,3]]^-1 = [[3,-2],[-2,4]] / 8
    for ([_]f64{ 3.0 / 8.0, -2.0 / 8.0, -2.0 / 8.0, 4.0 / 8.0 }, out) |want, got| {
        try std.testing.expectApproxEqAbs(want, got, 1e-12);
    }
}

test "the newest patch's games pull its number away from the old patch" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    // 40 champion-roles at 50% on the old patch; on the new one champions 1-10 move to
    // 60% or 40% in turn, the rest stay
    var prng: std.Random.DefaultPrng = .init(7);
    const rand = prng.random();
    for (1..41) |ch| {
        const cr: u16 = @intCast(ch);
        for (0..2000) |_| try rows.append(gpa, testRow(cr, -5, 1, 2, rand.float(f64) < 0.5));
        const p: f64 = if (ch > 10) 0.5 else if (ch % 2 == 1) 0.6 else 0.4;
        for (0..1000) |_| try rows.append(gpa, testRow(cr, 0, 0, 2, rand.float(f64) < p));
    }
    // Day 0: no newest-patch games yet, so champion 1 reads as the old 50%
    var before = try fit(gpa, rows.items, 0, .{});
    defer before.deinit(gpa);
    const e0 = before.rate(.champion, 0, 0, 1, 0).?;
    try std.testing.expectApproxEqAbs(0.5, e0.p, 0.03);
    try std.testing.expectEqual(@as(f64, 0), e0.own);
    // Day 1: its 1000 new games move it most of the way to 60%
    var after = try fit(gpa, rows.items, 1, .{});
    defer after.deinit(gpa);
    const e1 = after.rate(.champion, 0, 0, 1, 0).?;
    try std.testing.expect(e1.p > 0.56 and e1.p < 0.62);
    try std.testing.expect(e1.lo < e1.p and e1.p < e1.hi);
    try std.testing.expectEqual(@as(f64, 1000), e1.own);
    // An unmoved one lands between its old and new raw rates
    const c20 = after.counts[after.index.get(20).?];
    const old = c20.k[1][2][0] / c20.n[1][2][0];
    const new = c20.k[0][2][0] / c20.n[0][2][0];
    const e20 = after.rate(.champion, 0, 2, 20, 0).?.p;
    try std.testing.expect((e20 - old) * (new - e20) > 0);
    try std.testing.expectEqual(@as(?Estimate, null), after.rate(.rune, 0, 0, 1, 2));
    try std.testing.expectEqual(@as(?Estimate, null), after.rate(.champion, 0, 0, 99, 0));
    // The planted moves are 0.41 on the logit for a quarter of them: sd about 0.2
    const sd = after.sd[@backingInt(Term.patch)];
    try std.testing.expect(sd > 0.12 and sd < 0.3);
}

test "a matchup is both champions' strength plus a shrunk pair term" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(3);
    const rand = prng.random();
    // Ten top champions, every pair 1000 lanes; the lower one wins 60% where the two
    // ids' sum is even, 40% where odd (0.41 on the logit), so strengths stay ~50%.
    // Champion 11 is a bottom whose duo with support 12 wins 65%
    const bot: u16 = 11 | 3 << 13;
    const sup: u16 = 12 | 4 << 13;
    for (1..11) |ia| for (ia + 1..11) |ib| {
        const a: u16 = @intCast(ia);
        const b: u16 = @intCast(ib);
        const p: f64 = if ((a + b) % 2 == 0) 0.6 else 0.4;
        for (0..1000) |_| {
            const win = rand.float(f64) < p;
            try rows.append(gpa, .{ .day = -1, .cr = a, .opp = b, .win = win, .euw = false, .patch = 1, .bracket = 0 });
            try rows.append(gpa, .{ .day = -1, .cr = b, .opp = a, .win = !win, .euw = false, .patch = 1, .bracket = 0 });
        }
    };
    for (0..4000) |g| {
        const with = g % 4 == 0;
        const win = rand.float(f64) < @as(f64, if (with) 0.65 else 0.5);
        try rows.append(gpa, .{ .day = -1, .cr = bot, .ally = if (with) sup else 0, .win = win, .euw = false, .patch = 1, .bracket = 0 });
        if (with) try rows.append(gpa, .{ .day = -1, .cr = sup, .win = win, .euw = false, .patch = 1, .bracket = 0 });
    }
    // Top champion 13 with no lane opponent known
    for (0..500) |_| try rows.append(gpa, .{ .day = -1, .cr = 13, .win = rand.boolean(), .euw = false, .patch = 1, .bracket = 0 });
    var m = try fit(gpa, rows.items, 0, .{});
    defer m.deinit(gpa);
    const sd = m.pair.sd[0];
    try std.testing.expect(sd > 0.25 and sd < 0.6);
    const ab = m.rate(.matchup, 0, 0, 1, 3).?;
    const ba = m.rate(.matchup, 0, 0, 3, 1).?;
    try std.testing.expectApproxEqAbs(0.6, ab.p, 0.05);
    try std.testing.expectApproxEqAbs(1, ab.p + ba.p, 1e-9);
    try std.testing.expectApproxEqAbs(0.4, m.rate(.matchup, 0, 0, 1, 2).?.p, 0.05);
    try std.testing.expect(ab.own == 0 and ab.lo < ab.p and ab.p < ab.hi);
    // A lane nobody played: both strengths, no pair term, the spread as its range
    const unseen = m.rate(.matchup, 0, 0, 1, 13).?;
    try std.testing.expect(unseen.hi - unseen.lo > ab.hi - ab.lo);
    try std.testing.expectApproxEqAbs(0.5, m.rate(.matchup, 0, 0, 4, 4).?.p, 1e-12);
    const d = m.rate(.duo, 0, 0, bot, sup).?;
    // One duo among mostly 50% champions: shrunk, but above the bottom's own rate
    try std.testing.expect(d.p > m.rate(.champion, 0, 0, bot, 0).?.p + 0.01);
}

test "a keystone's rate is the champion-role's plus a role-wide term plus a shrunk pair term" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(11);
    const rand = prng.random();
    // Twenty top champions split between keystones 8010 and 8437; 8010 is 0.4 better on
    // the logit everywhere, and on top of that champions 1-10 gain or lose 0.4 with it in
    // turn. Champion 20 never takes 8010. Item 3071 in timelined games only
    for (1..21) |ch| {
        const cr: u16 = @intCast(ch);
        const extra: f64 = if (ch > 10) 0 else if (ch % 2 == 1) 0.4 else -0.4;
        for (0..2000) |g| {
            const ks: u16 = if (ch == 20 or g % 2 == 0) 8437 else 8010;
            const z: f64 = if (ks == 8010) 0.4 + extra else 0;
            const win = rand.float(f64) < sigmoid(z - 0.2);
            try rows.append(gpa, .{ .day = -1, .cr = cr, .keystone = ks, .win = win, .euw = false, .patch = 0, .bracket = 0, .timeline = g % 4 < 2, .items = .{ 3071, 0, 0, 0, 0, 0 } });
        }
    }
    var m = try fit(gpa, rows.items, 0, .{});
    defer m.deinit(gpa);
    const one = m.rate(.keystone, 0, 0, 1, 8010).?;
    const two = m.rate(.keystone, 0, 0, 2, 8010).?;
    // Near each cell's own 1000 games, a little shrunk
    try std.testing.expectApproxEqAbs(m.keystone.raw(1, 8010), one.p, 0.015);
    try std.testing.expectApproxEqAbs(m.keystone.raw(2, 8010), two.p, 0.015);
    try std.testing.expectApproxEqAbs(sigmoid(0.6), one.p, 0.05);
    try std.testing.expect(one.lo < one.p and one.p < one.hi);
    try std.testing.expectEqual(@as(f64, 1000), one.own);
    // Nobody-played combination: champion 20's own rate moved by 8010's role-wide term
    const unseen = m.rate(.keystone, 0, 0, 20, 8010).?;
    const base = m.rate(.champion, 0, 0, 20, 0).?;
    try std.testing.expect(unseen.p > base.p + 0.05);
    try std.testing.expect(unseen.hi - unseen.lo > one.hi - one.lo);
    try std.testing.expectEqual(@as(f64, 0), unseen.own);
    try std.testing.expectApproxEqAbs(sigmoid(0.2), unseen.p, 0.03);
    // A keystone nobody in the role took: about the rate of a champion taking both
    const none = m.rate(.keystone, 0, 0, 15, 8229).?;
    try std.testing.expectApproxEqAbs(m.rate(.champion, 0, 0, 15, 0).?.p, none.p, 0.02);
    // Each planted 0.4 splits across a champion's two keystones once it is centred
    const sd = m.keystone.inter_sd[0];
    try std.testing.expect(sd > 0.08 and sd < 0.2);
    // Items count only timelined games: half of champion 3's
    const it = m.rate(.item, 0, 0, 3, 3071).?;
    try std.testing.expectApproxEqAbs(m.rate(.champion, 0, 0, 3, 0).?.p, it.p, 0.03);
    try std.testing.expectEqual(@as(?Estimate, null), m.rate(.gold14, 0, 0, 3, 0));
}

test "a share leans on the old patch until the new one's games arrive" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(5);
    const rand = prng.random();
    // Thirty top champions take keystone 8010 in a share from 20% to 78%, else 8437, on
    // two old patches; on the new one champion 1 moves from 20% to 90%. Champion 31 has
    // no timelines
    for (1..31) |ch| {
        const old = 0.2 + 0.02 * @as(f64, @floatFromInt(ch - 1));
        const new: f64 = if (ch == 1) 0.9 else old;
        for (0..1000) |g| {
            const ks: u16 = if (rand.float(f64) < old) 8010 else 8437;
            const patch: u8 = if (g % 2 == 0) 1 else 2;
            try rows.append(gpa, .{ .day = -5 - 10 * @as(i16, patch - 1), .cr = @intCast(ch), .keystone = ks, .win = rand.boolean(), .euw = false, .patch = patch, .bracket = 0, .timeline = true, .items = .{ if (g % 4 < 2) 3071 else 6610, 0, 0, 0, 0, 0 } });
        }
        for (0..500) |_| {
            const ks: u16 = if (rand.float(f64) < new) 8010 else 8437;
            try rows.append(gpa, .{ .day = 0, .cr = @intCast(ch), .keystone = ks, .win = rand.boolean(), .euw = false, .patch = 0, .bracket = 0 });
        }
    }
    for (0..200) |_| try rows.append(gpa, .{ .day = -5, .cr = 31, .keystone = 8010, .win = rand.boolean(), .euw = false, .patch = 1, .bracket = 0 });
    var before = try fit(gpa, rows.items, 0, .{});
    defer before.deinit(gpa);
    const b1 = before.rate(.rune, 0, 0, 1, 8010).?;
    try std.testing.expectApproxEqAbs(0.2, b1.p, 0.04);
    try std.testing.expectEqual(@as(f64, 0), b1.own);
    var after = try fit(gpa, rows.items, 1, .{});
    defer after.deinit(gpa);
    const a1 = after.rate(.rune, 0, 0, 1, 8010).?;
    try std.testing.expect(a1.p > 0.8 and a1.p < 0.93);
    try std.testing.expect(a1.lo < a1.p and a1.p < a1.hi);
    try std.testing.expectEqual(@as(f64, 500), a1.own);
    // An unmoved one stays near its share, and its two keystones near 1 together
    const a20 = after.rate(.rune, 0, 0, 20, 8010).?;
    try std.testing.expectApproxEqAbs(0.58, a20.p, 0.05);
    try std.testing.expectApproxEqAbs(1, a20.p + after.rate(.rune, 0, 0, 20, 8437).?.p, 0.02);
    // A keystone nobody took: near 0, a range that allows a little
    const none = after.rate(.rune, 0, 0, 20, 8229).?;
    try std.testing.expect(none.p < 0.01 and none.lo < none.p and none.p < none.hi);
    // Items: of timelined games, so only the old patch's; none for champion 31
    const it = after.rate(.build, 0, 0, 5, 3071).?;
    try std.testing.expectApproxEqAbs(0.5, it.p, 0.05);
    try std.testing.expectEqual(@as(?Estimate, null), after.rate(.build, 0, 0, 31, 3071));
    try std.testing.expect(after.rate(.rune, 0, 0, 31, 8010).?.p > 0.9);
}

test "lane gold at 14 is both champions' leads plus a shrunk pair term" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(9);
    const rand = prng.random();
    // Ten top champions, champion c leads by 100 c gold against an average one; the
    // pair 1-2 is special: 1 leads 2 by 800 more. Champion 11 has no opponent known
    for (1..11) |ia| for (ia + 1..11) |ib| {
        const a: u16 = @intCast(ia);
        const b: u16 = @intCast(ib);
        const mean = 100 * (@as(f64, @floatFromInt(ia)) - @as(f64, @floatFromInt(ib))) + @as(f64, if (a == 1 and b == 2) 800 else 0);
        for (0..400) |_| {
            const y: i32 = @intFromFloat(@round(mean + 1500 * rand.floatNorm(f64)));
            try rows.append(gpa, .{ .day = -1, .cr = a, .opp = b, .gold = y, .win = rand.boolean(), .euw = false, .patch = 0, .bracket = 0 });
            try rows.append(gpa, .{ .day = -1, .cr = b, .opp = a, .gold = -y, .win = rand.boolean(), .euw = false, .patch = 0, .bracket = 0 });
        }
    };
    for (0..300) |_| try rows.append(gpa, .{ .day = -1, .cr = 11, .win = rand.boolean(), .euw = false, .patch = 0, .bracket = 0 });
    var m = try fit(gpa, rows.items, 0, .{});
    defer m.deinit(gpa);
    try std.testing.expectApproxEqAbs(2.25, m.gold.noise, 0.2);
    const ab = m.avg(.gold14, 0, 0, 3, 7).?;
    try std.testing.expectApproxEqAbs(-400, ab.p, 150);
    try std.testing.expectApproxEqAbs(-ab.p, m.avg(.gold14, 0, 0, 7, 3).?.p, 1e-6);
    try std.testing.expect(ab.lo < ab.p and ab.p < ab.hi and ab.own == 400);
    // The special pair keeps most of its 800
    try std.testing.expect(m.avg(.gold14, 0, 0, 1, 2).?.p > 300);
    try std.testing.expectEqual(@as(f64, 0), m.avg(.gold14, 0, 0, 4, 4).?.p);
    // Against anyone: the champion's own lead
    const solo = m.avg(.gold14, 0, 0, 10, 0).?;
    try std.testing.expect(solo.p > 200);
    try std.testing.expectEqual(@as(?Estimate, null), m.avg(.gold14, 0, 0, 11, 0));
    try std.testing.expectEqual(@as(?Estimate, null), m.avg(.gold14, 0, 0, 3, 11));
    try std.testing.expectEqual(@as(?Estimate, null), m.avg(.matchup, 0, 0, 3, 7));
}

test "all ranks is the champion-role's own mix of brackets, not the unknown-rank baseline" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(5);
    const rand = prng.random();
    // Twenty champions at 50% in low ranks and 58% in high ranks, three in four games high
    for (1..21) |ch| for (0..4000) |g| {
        const high = g % 4 != 0;
        const p: f64 = if (high) 0.58 else 0.5;
        var r = testRow(@intCast(ch), -1, 0, if (high) 3 else 1, rand.float(f64) < p);
        r.euw = g % 2 == 0;
        try rows.append(gpa, r);
    };
    var m = try fit(gpa, rows.items, 0, .{});
    defer m.deinit(gpa);
    const all = m.rate(.champion, 0, 0, 7, 0).?;
    const c = m.counts[m.index.get(7).?];
    var n: f64 = 0;
    var k: f64 = 0;
    for (0..4) |br| for (0..2) |e| {
        n += c.n[0][br][e];
        k += c.k[0][br][e];
    };
    try std.testing.expectApproxEqAbs(k / n, all.p, 0.01);
    try std.testing.expect(all.p > m.rate(.champion, 0, 1, 7, 0).?.p);
    try std.testing.expect(all.p < m.rate(.champion, 0, 3, 7, 0).?.p);
}

test "a rare champion-role shrinks to what rare picks win, not to 50%" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    // Games from 4000 down to 30; win rate 0.5 + 0.03 * log2(games / 4000): the rarest
    // win ~29%
    var prng: std.Random.DefaultPrng = .init(11);
    const rand = prng.random();
    for (1..41) |ch| {
        const n: f64 = 4000 * std.math.pow(f64, 30.0 / 4000.0, @as(f64, @floatFromInt(ch - 1)) / 39);
        const p = 0.5 + 0.03 * @log2(n / 4000);
        for (0..@intFromFloat(n)) |_| try rows.append(gpa, testRow(@intCast(ch), -3, 0, 2, rand.float(f64) < p));
    }
    var m = try fit(gpa, rows.items, 0, .{});
    defer m.deinit(gpa);
    try std.testing.expect(m.pop[1] > 0.05);
    const rare = m.rate(.champion, 0, 0, 40, 0).?;
    try std.testing.expect(rare.p < 0.36);
}

test "a keystone a champion-role seldom takes does worse with it" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    // 30 top champions, 3000 games each; 8010's share falls from 50% to 0.5%, and with it
    // the logit 0.3 * ln(share / 0.5); otherwise 8437, even. Champion 31 never takes 8010
    var prng: std.Random.DefaultPrng = .init(5);
    const rand = prng.random();
    for (1..32) |ch| {
        const s: f64 = if (ch == 31) 0 else 0.5 * std.math.pow(f64, 0.01, @as(f64, @floatFromInt(ch - 1)) / 29);
        for (0..3000) |_| {
            const take = rand.float(f64) < s;
            const z: f64 = if (take) 0.3 * @log(s / 0.5) else 0;
            const win = rand.float(f64) < sigmoid(z);
            try rows.append(gpa, .{ .day = -1, .cr = @intCast(ch), .keystone = if (take) 8010 else 8437, .win = win, .euw = false, .patch = 0, .bracket = 0 });
        }
    }
    var m = try fit(gpa, rows.items, 0, .{});
    defer m.deinit(gpa);
    // The role-wide term takes part of the slope
    try std.testing.expect(m.keystone.line[0][1] > 0.03);
    const unseen = m.rate(.keystone, 0, 0, 31, 8010).?;
    try std.testing.expect(unseen.p < m.rate(.champion, 0, 0, 31, 0).?.p - 0.1);
}

test "a two-lock cell adds both parts' terms to the champion-role" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(5);
    const rand = prng.random();
    // Top champions 1-12 meet their neighbours; keystone 8010 is 0.3 better
    for (1..13) |ch| {
        for (0..1500) |g| {
            const opp: u16 = @intCast(if (g % 2 == 0) ch % 12 + 1 else (ch + 10) % 12 + 1);
            const ks: u16 = if (g % 3 == 0) 8010 else 8437;
            const bonus: f64 = if (ks == 8010) 0.3 else 0;
            const z = bonus + 0.05 * @as(f64, @floatFromInt(ch)) - 0.05 * @as(f64, @floatFromInt(opp));
            const win = rand.float(f64) < sigmoid(z - 0.1);
            try rows.append(gpa, .{ .day = -1, .cr = @intCast(ch), .opp = opp, .keystone = ks, .win = win, .euw = false, .patch = 0, .bracket = 0, .timeline = true, .items = .{ 3071, 0, 0, 0, 0, 0 } });
        }
    }
    var m = try fit(gpa, rows.items, 0, .{});
    defer m.deinit(gpa);
    const mid = struct {
        // The range is symmetric on the logit scale around the mean's logit
        fn mid(e: Estimate) f64 {
            return (@log(e.lo / (1 - e.lo)) + @log(e.hi / (1 - e.hi))) / 2;
        }
    }.mid;
    const c = m.rate(.champion, 0, 0, 3, 0).?;
    const k = m.rate(.keystone, 0, 0, 3, 8010).?;
    const mu = m.rate(.matchup, 0, 0, 3, 4).?;
    const it = m.rate(.item, 0, 0, 3, 3071).?;
    const km = m.rate(.keystone_matchup, 0, 0, 3, @as(u32, 8010) << 16 | 4).?;
    try std.testing.expectApproxEqAbs(mid(k) + mid(mu) - mid(c), mid(km), 1e-9);
    try std.testing.expect(km.hi - km.lo > k.hi - k.lo and km.hi - km.lo > mu.hi - mu.lo);
    try std.testing.expectEqual(@min(k.own, mu.own), km.own);
    const ki = m.rate(.keystone_item, 0, 0, 3, @as(u32, 8010) << 16 | 3071).?;
    try std.testing.expectApproxEqAbs(mid(k) + mid(it) - mid(c), mid(ki), 1e-9);
    const im = m.rate(.item_matchup, 0, 0, 3, @as(u32, 3071) << 16 | 4).?;
    try std.testing.expectApproxEqAbs(mid(it) + mid(mu) - mid(c), mid(im), 1e-9);
    // An unseen pair still gets a number, with a wider range
    const far = m.rate(.keystone_matchup, 0, 0, 3, @as(u32, 8010) << 16 | 9).?;
    try std.testing.expect(far.hi - far.lo > km.hi - km.lo);
    try std.testing.expectEqual(@as(?Estimate, null), m.rate(.keystone_matchup, 0, 0, 3, @as(u32, 8010) << 16 | 3));
    try std.testing.expectEqual(@as(?Estimate, null), m.rate(.item_matchup, 0, 0, 3, @as(u32, 3071) << 16 | 40));
}

test "two normals' range is their mixture's quantiles" {
    const one: Normals = .one(0.3, 0.04);
    try std.testing.expectApproxEqAbs(0.3 + z80 * 0.2, one.quantile(0.9), 1e-6);
    // Two equal parts are the one normal
    const same: Normals = .{ .w = 0.4, .e = @splat(0.3), .v = @splat(0.04) };
    try std.testing.expectApproxEqAbs(one.quantile(0.1), same.quantile(0.1), 1e-6);
    // A wide part on one side stretches that side only
    const split: Normals = .{ .w = 0.7, .e = .{ 0, 1 }, .v = .{ 0.01, 0.04 } };
    try std.testing.expect(split.quantile(0.9) - split.mean() > split.mean() - split.quantile(0.1));
    // Adding a normal shifts both parts
    const sum = split.add(.one(0.5, 0.01));
    try std.testing.expectApproxEqAbs(split.mean() + 0.5, sum.mean(), 1e-12);
    try std.testing.expectApproxEqAbs(split.variance() + 0.01, sum.variance(), 1e-12);
}

test "a mixture prior lets a lone real outlier pair stand out of a tight pack" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(5);
    const rand = prng.random();
    // Twelve top champions, every pair 600 lanes at 50% but 1 into 2 at 65%
    for (1..13) |ia| for (ia + 1..13) |ib| {
        const a: u16 = @intCast(ia);
        const b: u16 = @intCast(ib);
        const p: f64 = if (a == 1 and b == 2) 0.65 else 0.5;
        for (0..600) |_| {
            const win = rand.float(f64) < p;
            try rows.append(gpa, .{ .day = -1, .cr = a, .opp = b, .win = win, .euw = false, .patch = 1, .bracket = 0 });
            try rows.append(gpa, .{ .day = -1, .cr = b, .opp = a, .win = !win, .euw = false, .patch = 1, .bracket = 0 });
        }
    };
    var g = try fit(gpa, rows.items, 0, .{});
    defer g.deinit(gpa);
    var x = try fit(gpa, rows.items, 0, .{ .pair_mix = true });
    defer x.deinit(gpa);
    const pg = g.rate(.matchup, 0, 0, 1, 2).?;
    const px = x.rate(.matchup, 0, 0, 1, 2).?;
    try std.testing.expect(px.p > pg.p + 0.02);
    try std.testing.expect(px.lo < 0.65 and 0.65 < px.hi);
    // The pack stays put
    try std.testing.expectApproxEqAbs(0.5, x.rate(.matchup, 0, 0, 3, 4).?.p, 0.03);
}

test "a share that moves within its patch widens its range by the drift" {
    const gpa = std.testing.allocator;
    var prng: std.Random.DefaultPrng = .init(9);
    const rand = prng.random();
    var steady: std.ArrayList(Row) = .empty;
    defer steady.deinit(gpa);
    var moving: std.ArrayList(Row) = .empty;
    defer moving.deinit(gpa);
    // 60 top champions, 300 to 1480 games over the patch's first 10 days, keystone 8010
    // at 20% to 60%; moving: each champion's share steps by +-0.4 logit at day 5
    for (1..61) |ch| {
        const base = logit(0.2 + 0.4 * @as(f64, @floatFromInt(ch - 1)) / 60);
        const step: f64 = if (ch % 2 == 0) 0.4 else -0.4;
        for (0..280 + 20 * ch) |g| {
            const day: i16 = @intCast(g % 10);
            const p_moving = sigmoid(base + if (day >= 5) step / 2 else -step / 2);
            inline for (.{ &steady, &moving }, .{ sigmoid(base), p_moving }) |rows, p| {
                const ks: u16 = if (rand.float(f64) < p) 8010 else 8437;
                try rows.append(gpa, .{ .day = day, .cr = @intCast(ch), .keystone = ks, .win = rand.boolean(), .euw = false, .patch = 0, .bracket = 0 });
            }
        }
    }
    var a = try fit(gpa, steady.items, 10, .{});
    defer a.deinit(gpa);
    var b = try fit(gpa, moving.items, 10, .{});
    defer b.deinit(gpa);
    // 60 independent cells: phi's sd is about 0.2
    try std.testing.expect(a.rune.drift.tau2[0][0] < 0.02 and a.rune.drift.phi[0][0] < 1.5);
    // Halves 0.4 logit apart: the squared step, 0.16
    try std.testing.expect(b.rune.drift.tau2[0][0] > 0.1 and b.rune.drift.tau2[0][0] < 0.25 and b.rune.drift.phi[0][0] < 1.3);
    const ea = a.rate(.rune, 0, 0, 30, 8010).?;
    const eb = b.rate(.rune, 0, 0, 30, 8010).?;
    try std.testing.expect(eb.hi - eb.lo > 2 * (ea.hi - ea.lo));
}

test "a saved model answers as the fitted one, over any set of brackets" {
    const gpa = std.testing.allocator;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(3);
    const rand = prng.random();
    for (1..9) |ch| for (0..800) |g| {
        const opp: u16 = @intCast(ch % 8 + 1);
        const br: u2 = @intCast(g % 4);
        const z = 0.05 * @as(f64, @floatFromInt(ch)) + 0.1 * @as(f64, @floatFromInt(br)) - 0.2;
        try rows.append(gpa, .{
            .day = if (g % 5 == 0) -40 else -1,
            .cr = @intCast(ch),
            .opp = opp,
            .keystone = if (g % 3 == 0) 8010 else 8437,
            .gold = @intFromFloat(@round(1500 * rand.floatNorm(f64))),
            .items = .{ if (g % 2 == 0) 3071 else 6333, 0, 0, 0, 0, 0 },
            .timeline = true,
            .win = rand.float(f64) < sigmoid(z),
            .euw = g % 7 == 0,
            .patch = if (g % 5 == 0) 1 else 0,
            .bracket = br,
        });
    };
    var m = try fit(gpa, rows.items, 0, .{});
    defer m.deinit(gpa);
    slim(&m, gpa);
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try save(&aw.writer, &m);
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var r: std.Io.Reader = .fixed(aw.written());
    const got = (try load(&r, arena.allocator())).?;
    const plat: Brackets = .{ .mask = 0b1100 };
    const asks = [_]struct { Kind, u32 }{
        .{ .champion, 0 },                  .{ .matchup, 4 },                       .{ .keystone, 8010 },
        .{ .item, 3071 },                   .{ .rune, 8010 },                       .{ .build, 6333 },
        .{ .rune, 8229 },                   .{ .keystone_matchup, 8010 << 16 | 4 }, .{ .keystone_item, 8437 << 16 | 3071 },
        .{ .item_matchup, 3071 << 16 | 2 },
    };
    for (asks) |ask| for ([_]Brackets{ .all, .of(2), plat }) |bs| for (0..2) |region| {
        const want = m.rateIn(ask[0], @intCast(region), bs, 3, ask[1]).?;
        try std.testing.expectEqualDeep(want, got.rateIn(ask[0], @intCast(region), bs, 3, ask[1]).?);
    };
    try std.testing.expectEqualDeep(m.avgIn(.gold14, 0, plat, 3, 4).?, got.avgIn(.gold14, 0, plat, 3, 4).?);
    // Gold-Emerald and Diamond+ pooled: between the two, its range no wider than the wider
    const mid = m.rate(.champion, 0, 2, 5, 0).?;
    const high = m.rate(.champion, 0, 3, 5, 0).?;
    const both = m.rateIn(.champion, 0, plat, 5, 0).?;
    try std.testing.expect(both.p > mid.p and both.p < high.p);
    try std.testing.expect(both.hi - both.lo <= @max(mid.hi - mid.lo, high.hi - high.lo));
    try std.testing.expectEqual(mid.own + high.own, both.own);

    var bad: std.Io.Reader = .fixed(aw.written()[0..20]);
    try std.testing.expectEqual(null, try load(&bad, arena.allocator()));
}
