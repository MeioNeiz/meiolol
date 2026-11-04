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
//! over as the patch's games arrive. Older games can weigh less (half_life)

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const no_gold = std.math.minInt(i32);

/// Every cell kind truth scores; the order keeps truth's keys stable. Rank is the bracket
/// dimension of every kind, not a kind
pub const Kind = enum(u3) {
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

    pub const count = 8;
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

/// 80% interval
const z80 = 1.2815515655446004;

pub const Estimate = struct {
    p: f64,
    lo: f64,
    hi: f64,
    /// Games in the cell's own slice (newest patch, this region and bracket), unweighted
    own: f64,

    fn of(eta: f64, v: f64, own: f64) Estimate {
        const s = @sqrt(@max(v, 0));
        return .{
            // Averaged over the posterior (probit approximation), not the mean's rate
            .p = sigmoid(eta / @sqrt(1 + std.math.pi * v / 8)),
            .lo = sigmoid(eta - z80 * s),
            .hi = sigmoid(eta + z80 * s),
            .own = own,
        };
    }
};

/// Weighted games and wins of one champion-role, by patch slot, bracket and EUW1
const Counts = struct {
    n: [max_patches][4][2]f64 = @splat(@splat(@splat(0))),
    k: [max_patches][4][2]f64 = @splat(@splat(@splat(0))),
    /// Unweighted games, the newest patch only
    own: [4][2]f64 = @splat(@splat(0)),
};

const Fitted = struct {
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
    v: f64 = 0,
    /// Its cells in Model.pair_cells
    first: u32,
    len: u32,
    own: [4][2]f64 = @splat(@splat(0)),
};

pub const Model = struct {
    shape: Shape,
    sd: [n_terms]f64,
    pair_sd: [n_pair_classes]f64 = @splat(0),
    index: std.AutoHashMapUnmanaged(u16, u32) = .empty,
    counts: []Counts = &.{},
    fitted: []Fitted = &.{},
    /// pair key (a << 16 | b) << 1 | duo -> Model.pairs
    pair_index: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    pairs: []Pair = &.{},
    pair_cells: []PairCell = &.{},
    keystone: Cond = .{},
    item: Cond = .{},

    pub fn deinit(m: *Model, gpa: Allocator) void {
        m.index.deinit(gpa);
        gpa.free(m.counts);
        gpa.free(m.fitted);
        m.pair_index.deinit(gpa);
        gpa.free(m.pairs);
        gpa.free(m.pair_cells);
        m.keystone.deinit(gpa);
        m.item.deinit(gpa);
    }

    /// The newest patch's number for a cell; region 1 is EUW1, bracket 0 all ranks. null:
    /// a kind not estimated yet, or a champion-role with no games
    pub fn rate(m: *const Model, kind: Kind, region: u1, bracket: u2, a: u16, b: u32) ?Estimate {
        switch (kind) {
            .champion => {
                const i = m.index.get(a) orelse return null;
                const t = m.eta(i, 0, bracket, region);
                var own: f64 = 0;
                for (0..4) |br| {
                    if (bracket != 0 and br != bracket) continue;
                    own += m.counts[i].own[br][1];
                    if (region == 0) own += m.counts[i].own[br][0];
                }
                return .of(t.eta, t.v, own);
            },
            .matchup, .duo => {
                const ia = m.index.get(a) orelse return null;
                const ib = m.index.get(@intCast(b)) orelse return null;
                const ta = m.eta(ia, 0, bracket, region);
                const tb = m.eta(ib, 0, bracket, region);
                if (kind == .matchup and a == b) return .{ .p = 0.5, .lo = 0.5, .hi = 0.5, .own = 0 };
                const duo = kind == .duo;
                const lo: u16 = if (duo) a else @min(a, @as(u16, @intCast(b)));
                const hi: u16 = if (duo) @intCast(b) else @max(a, @as(u16, @intCast(b)));
                const sign: f64 = if (duo or lo == a) 1 else -1;
                var e = ta.eta + (if (duo) tb.eta else -tb.eta);
                var v = ta.v + tb.v;
                var own: f64 = 0;
                if (m.pair_index.get(pairKey(lo, hi, duo))) |pi| {
                    const p = &m.pairs[pi];
                    e += sign * p.i;
                    v += p.v;
                    for (0..4) |br| {
                        if (bracket != 0 and br != bracket) continue;
                        own += p.own[br][1];
                        if (region == 0) own += p.own[br][0];
                    }
                } else {
                    // Never seen: no pair term, the class's spread in the range
                    const s = m.pair_sd[pairClass(lo, duo)];
                    v += s * s;
                }
                return .of(e, v, own);
            },
            .keystone, .item => {
                const i = m.index.get(a) orelse return null;
                const x = std.math.cast(u16, b) orelse return null;
                const t = m.eta(i, 0, bracket, region);
                const c = if (kind == .keystone) &m.keystone else &m.item;
                const role = a >> 13;
                var e = t.eta + c.shift[i];
                var v = t.v;
                var own: f64 = 0;
                // Never seen: no term, the class's spread in the range
                if (c.main_index.get(@as(u32, role) << 16 | x)) |j| {
                    e += c.mains[j].i;
                    v += c.mains[j].v;
                } else v += c.main_sd[role] * c.main_sd[role];
                if (c.inter_index.get(@as(u32, a) << 16 | x)) |j| {
                    const p = &c.inters[j];
                    e += p.i;
                    v += p.v;
                    for (0..4) |br| {
                        if (bracket != 0 and br != bracket) continue;
                        own += p.own[br][1];
                        if (region == 0) own += p.own[br][0];
                    }
                } else v += c.inter_sd[role] * c.inter_sd[role];
                return .of(e, v, own);
            },
            .gold14, .build, .rune => return null,
        }
    }

    /// A champion-role's logit and its variance in one patch slot, bracket and region
    fn eta(m: *const Model, i: u32, patch: usize, bracket: usize, euw: usize) struct { eta: f64, v: f64 } {
        const k = m.shape.params();
        var x: [max_k]f64 = undefined;
        m.shape.design(patch, bracket, euw, &x);
        const f = &m.fitted[i];
        var e: f64 = 0;
        var v: f64 = 0;
        for (0..k) |r| {
            if (x[r] == 0) continue;
            e += f.theta[r];
            for (0..k) |c| v += x[r] * f.cov[r * k + c] * x[c];
        }
        return .{ .eta = e, .v = v };
    }
};

/// A champion-role's win rate under a condition x (a keystone, an item it finished): its
/// own terms, plus x's role-wide term, plus a shrunk champion-role x condition term. Both
/// shrunk to 0, one variance per role each; fitted in that order on top of E3. A
/// champion-role's own rate already holds the conditions it takes, so it is first
/// shifted by minus their role-wide terms, weighted by its games: one that only takes a
/// weak keystone gains the full gap on a strong one it never took
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

pub fn sigmoid(z: f64) f64 {
    return 1 / (1 + @exp(-z));
}

/// Fits on every row with day < before_day
pub fn fit(gpa: Allocator, rows: []const Row, before_day: i32, opts: Options) !Model {
    std.debug.assert(opts.patches >= 1 and opts.patches <= max_patches);
    const shape: Shape = .{ .patches = opts.patches, .walk = opts.walk };
    var m: Model = .{ .shape = shape, .sd = opts.sd };
    errdefer m.deinit(gpa);
    var counts: std.ArrayList(Counts) = .empty;
    defer counts.deinit(gpa);
    // Pair cells by pair key << 8 | patch << 3 | bracket << 1 | euw
    var cells: std.AutoHashMapUnmanaged(u64, PairCell) = .empty;
    defer cells.deinit(gpa);
    var keystones: std.AutoHashMapUnmanaged(u64, PairCell) = .empty;
    defer keystones.deinit(gpa);
    var items: std.AutoHashMapUnmanaged(u64, PairCell) = .empty;
    defer items.deinit(gpa);
    const ln2 = @log(2.0);
    for (rows) |r| {
        if (r.day >= before_day) continue;
        const e = try m.index.getOrPut(gpa, r.cr);
        if (!e.found_existing) {
            e.value_ptr.* = @intCast(counts.items.len);
            try counts.append(gpa, .{});
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
        if (r.keystone != 0) try addCell(gpa, &keystones, condKey(r.cr, r.keystone, slot), w, win, own);
        // Items are known only in timelined games, as truth counts them
        if (r.timeline) for (r.items) |x| if (x != 0) try addCell(gpa, &items, condKey(r.cr, x, slot), w, win, own);
    }
    m.counts = try counts.toOwnedSlice(gpa);
    m.fitted = try gpa.alloc(Fitted, m.counts.len);
    @memset(m.fitted, .{});

    var sd: [n_terms]f64 = undefined;
    for (&sd, opts.sd) |*s, o| s.* = if (o > 0) o else 0.1;
    const k = shape.params();
    for (0..opts.rounds) |_| {
        var sum_sq: [n_terms]f64 = @splat(0);
        var gamma: [n_terms]f64 = @splat(0);
        for (m.counts, m.fitted) |*c, *f| {
            newton(c, f, shape, sd);
            for (0..k) |j| {
                const t = @backingInt(shape.term(j));
                sum_sq[t] += f.theta[j] * f.theta[j];
                gamma[t] += 1 - f.cov[j * k + j] / (sd[t] * sd[t]);
            }
        }
        if (!mackay(&sd, &opts.sd, &sum_sq, &gamma)) break;
    }
    for (m.counts, m.fitted) |*c, *f| newton(c, f, shape, sd);
    m.sd = sd;
    try fitPairs(gpa, &m, &cells, opts.rounds);
    m.keystone = try fitCond(gpa, &m, &keystones, opts.rounds);
    m.item = try fitCond(gpa, &m, &items, opts.rounds);
    return m;
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
fn fitPairs(gpa: Allocator, m: *Model, cells: *const std.AutoHashMapUnmanaged(u64, PairCell), rounds: u8) !void {
    const keys = try sortedKeys(gpa, cells);
    defer gpa.free(keys);

    m.pair_cells = try gpa.alloc(PairCell, keys.len);
    var pairs: std.ArrayList(Pair) = .empty;
    defer pairs.deinit(gpa);
    for (keys, m.pair_cells, 0..) |key, *out, j| {
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
        const ta = if (m.index.get(a)) |i| m.eta(i, patch, bracket, euw).eta else 0;
        const tb = if (m.index.get(b)) |i| m.eta(i, patch, bracket, euw).eta else 0;
        out.off = ta + (if (duo) tb else -tb);
        if (j == 0 or keys[j - 1] >> 8 != pk) {
            try m.pair_index.put(gpa, pk, @intCast(pairs.items.len));
            try pairs.append(gpa, .{ .class = pairClass(a, duo), .first = @intCast(j), .len = 0 });
        }
        const p = &pairs.items[pairs.items.len - 1];
        p.len += 1;
        p.own[bracket][euw] += out.own;
    }
    m.pairs = try pairs.toOwnedSlice(gpa);
    fitTerms(m.pairs, m.pair_cells, &m.pair_sd, rounds);
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
        fitTerms(c.mains, c.cells, &c.main_sd, rounds);
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
    fitTerms(c.inters, c.cells, &c.inter_sd, rounds);
    return c;
}

/// Shrunk single terms on fixed offsets, one variance per class (MacKay)
fn fitTerms(terms: []Pair, cells: []const PairCell, sd_out: []f64, rounds: u8) void {
    var sd: [n_roles]f64 = @splat(0.1);
    const fixed: [n_roles]f64 = @splat(0);
    const classes = sd_out.len;
    for (0..rounds) |_| {
        var sum_sq: [n_roles]f64 = @splat(0);
        var gamma: [n_roles]f64 = @splat(0);
        for (terms) |*p| {
            pairNewton(p, cells[p.first..][0..p.len], sd[p.class]);
            sum_sq[p.class] += p.i * p.i;
            gamma[p.class] += 1 - p.v / (sd[p.class] * sd[p.class]);
        }
        if (!mackay(sd[0..classes], fixed[0..classes], sum_sq[0..classes], gamma[0..classes])) break;
    }
    for (terms) |*p| pairNewton(p, cells[p.first..][0..p.len], sd[p.class]);
    @memcpy(sd_out, sd[0..classes]);
}

fn pairNewton(p: *Pair, cells: []const PairCell, sd: f64) void {
    const prec = 1 / (sd * sd);
    for (0..8) |_| {
        var g = -prec * p.i;
        var h = prec;
        for (cells) |c| {
            const q = sigmoid(c.off + p.i);
            g += c.k - c.n * q;
            h += c.n * q * (1 - q);
        }
        p.v = 1 / h;
        p.i += g / h;
        if (@abs(g / h) < 1e-10) break;
    }
}

/// Newton steps on one champion-role's penalised log likelihood from its current terms;
/// leaves the posterior covariance (inverse Hessian) in f.cov
fn newton(c: *const Counts, f: *Fitted, shape: Shape, sd: [n_terms]f64) void {
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
            grad[j] = -prec[j] * f.theta[j];
            hess[j * k + j] = prec[j];
        }
        for (0..shape.patches) |p| for (0..4) |br| for (0..2) |e| {
            const n = c.n[p][br][e];
            if (n == 0) continue;
            shape.design(p, br, e, &x);
            var eta: f64 = 0;
            for (0..k) |j| eta += x[j] * f.theta[j];
            const q = sigmoid(eta);
            const r = c.k[p][br][e] - n * q;
            const wt = n * q * (1 - q);
            for (0..k) |i| {
                if (x[i] == 0) continue;
                grad[i] += r;
                for (0..k) |j| hess[i * k + j] += wt * x[j];
            }
        };
        invert(hess[0 .. k * k], k, f.cov[0 .. k * k]);
        var step: f64 = 0;
        for (0..k) |i| {
            var s: f64 = 0;
            for (0..k) |j| s += f.cov[i * k + j] * grad[j];
            f.theta[i] += s;
            step = @max(step, @abs(s));
        }
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
    const sd = m.pair_sd[0];
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
    try std.testing.expectEqual(@as(?Estimate, null), m.rate(.rune, 0, 0, 3, 8010));
}
