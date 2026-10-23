//! `meiolol-lab pairprior SNAP`: A4, pair cells that borrow strength (docs/model.md "Pair
//! cells that borrow strength"). Additive v2 (src/additive.zig, effects' "full") with
//! every pair cell shrunk toward a structured part instead of 0, all fitted jointly:
//!   kit:  a parent cell per (kit(a), kit(b)) in each of the 25 pair blocks; kit maps:
//!         tag (Data Dragon tag string, role-free) or prof:K (k-means on the champion-role
//!         profile z of the block's fit games, K per role)
//!   pair: the same two champions in any role slots: one parent block over the 10 ally
//!         blocks (unordered), one over the 15 matchup blocks (signed)
//!   rank: u_a . v_b per pair block (same-role matchups u_a.v_b - u_b.v_a), k per block
//! Every extra part is a function of a v2 cell, so it is fitted at the cell level: each
//! pass sums the cell's gradient and curvature over its games once, then takes diagonal
//! Newton steps on the parents and factors, MacKay variances per block as v2's own.
//! Shippable as terms: parent tables and factor vectors per champion-role and block.
//! Paired per game against v2 fitted on the same games; folds 1-2 develop, 3-5 judge.
//! --plant SD: semi-synthetic power check (outcomes drawn from v2's fit plus a planted
//! kit or rank-2 part of cell sd SD pp in every pair block). Writes DIR/folds.tsv and
//! DIR/games-<label>.tsv (netcheck's format)

const std = @import("std");
const nn = @import("nn");
const api = @import("api");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const seatstats = @import("seatstats.zig");
const additive = @import("../additive.zig");
const addinputs = @import("addinputs.zig");
const par = @import("../par.zig");
const winnet = @import("winnet.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const A = additive;
const sigmoid = nn.sigmoid;
const n_role = A.n_role;

pub const usage =
    \\  pairprior SNAP [--out DIR] [--blocks 1,2|dev,1,2,3,4,5] [--threads N]
    \\                                  [--variants kit:prof:8,pair,rank:4,...]
    \\                                  (+ joins parts: kit:tag+rank:4; a part with
    \\                                  :shuf shuffles its kit map or pair keys)
    \\                                  [--resample N] [--shuffle SEED] (labels)
    \\                                  [--plant SD --plant-kind kit:prof:8|rank]
    \\                                  A4: v2's pair cells shrunk toward kit x kit,
    \\                                  the same pair in other slots, or low rank,
    \\                                  paired per game vs v2 (lab/pairprior.zig)
    \\
;

const Block = winnet.FoldBlock;
const blockName = winnet.foldName;

const Options = struct {
    out: []const u8 = ".",
    blocks: []const Block = &.{ .f1, .f2 },
    threads: u32 = 4,
    variants: []const Variant = &.{},
    resample: ?u32 = null,
    shuffle: ?u64 = null,
    plant: f64 = 0,
    plant_kind: ?Kit = null,
    plant_rank: bool = false,
    plant_seed: u64 = 0x91a7,
};

// ---------------------------------------------------------------- variants

const Kit = struct {
    kind: enum { tag, prof },
    k: u32 = 0,
    shuf: bool = false,

    fn eql(a: Kit, b: Kit) bool {
        return a.kind == b.kind and a.k == b.k and a.shuf == b.shuf;
    }
};

const Variant = struct {
    label: []const u8,
    kit: ?Kit = null,
    pair: bool = false,
    pair_mode: PairMode = .pooled,
    rank: u32 = 0,
    /// Factor entries' prior sd, fixed; 0: MacKay, capped
    fac_sd: f64 = 0,
};

/// pooled: the same two champions in any slot share a parent; shuf: a slot's own
/// relabelling first (control); multi: only parents with cells in 2+ slots; ident: one
/// parent per cell, sharing the kind's variance (no pooling: tells pooling from the
/// shared variance)
const PairMode = enum { pooled, shuf, multi, ident };

fn parseVariant(label: []const u8) !Variant {
    var v: Variant = .{ .label = label };
    var parts = std.mem.tokenizeScalar(u8, label, '+');
    while (parts.next()) |part| {
        var f = std.mem.tokenizeScalar(u8, part, ':');
        const head = f.next() orelse return error.BadVariant;
        if (std.mem.eql(u8, head, "kit")) {
            const kind = f.next() orelse return error.BadVariant;
            var kit: Kit = undefined;
            if (std.mem.eql(u8, kind, "tag")) {
                kit = .{ .kind = .tag };
            } else if (std.mem.eql(u8, kind, "prof")) {
                kit = .{ .kind = .prof, .k = try std.fmt.parseInt(u32, f.next() orelse return error.BadVariant, 10) };
            } else return error.BadVariant;
            if (f.next()) |s| kit.shuf = std.mem.eql(u8, s, "shuf");
            v.kit = kit;
        } else if (std.mem.eql(u8, head, "pair")) {
            v.pair = true;
            if (f.next()) |m| v.pair_mode = std.meta.stringToEnum(PairMode, m) orelse return error.BadVariant;
        } else if (std.mem.eql(u8, head, "rank")) {
            v.rank = try std.fmt.parseInt(u32, f.next() orelse return error.BadVariant, 10);
            if (f.next()) |x| v.fac_sd = try std.fmt.parseFloat(f64, x);
        } else return error.BadVariant;
    }
    return v;
}

// ---------------------------------------------------------------- pair blocks and keys

/// The 25 pair blocks of v2: 10 ally (r < q), 15 matchups (r <= q)
const n_slots = 25;
const Slot = struct { group: usize, ally: bool, r: usize, q: usize };

const slots: [n_slots]Slot = blk: {
    var out: [n_slots]Slot = undefined;
    var k: usize = 0;
    for (0..n_role) |r| for (r + 1..n_role) |q| {
        out[k] = .{ .group = A.allyGroup(r, q), .ally = true, .r = r, .q = q };
        k += 1;
    };
    for (0..n_role) |r| for (r..n_role) |q| {
        out[k] = .{ .group = A.enemyGroup(r, q), .ally = false, .r = r, .q = q };
        k += 1;
    };
    break :blk out;
};

fn slotOf(group: usize) ?usize {
    for (slots, 0..) |s, i| if (s.group == group) return i;
    return null;
}

/// additive.key's layout
fn key(g: usize, a: u32, b: u32) u64 {
    return @as(u64, g) << 48 | @as(u64, a) << 24 | b;
}

const Cell = struct { key: u64, x: f32 };

/// additive.cells for v2's mains and pair blocks: the cells a game touches in group g
fn cellsOf(g: usize, t: *const [2][n_role]u32, out: *[2]Cell) usize {
    if (g < A.g_ally) {
        const r = g - A.g_main;
        out[0] = .{ .key = key(g, t[0][r], 0), .x = 1 };
        out[1] = .{ .key = key(g, t[1][r], 0), .x = -1 };
        return 2;
    }
    const s = slots[slotOf(g).?];
    if (s.ally) {
        out[0] = .{ .key = key(g, t[0][s.r], t[0][s.q]), .x = 1 };
        out[1] = .{ .key = key(g, t[1][s.r], t[1][s.q]), .x = -1 };
        return 2;
    }
    if (s.r == s.q) {
        const a = t[0][s.r];
        const b = t[1][s.r];
        if (a == b) return 0;
        out[0] = .{ .key = key(g, @min(a, b), @max(a, b)), .x = if (a < b) 1 else -1 };
        return 1;
    }
    out[0] = .{ .key = key(g, t[0][s.r], t[1][s.q]), .x = 1 };
    out[1] = .{ .key = key(g, t[1][s.r], t[0][s.q]), .x = -1 };
    return 2;
}

/// Kit class per champion-role; `none` for champion-roles the map doesn't know
const KitMap = struct {
    class: std.AutoHashMapUnmanaged(u64, u16) = .empty,
    none: u16,

    fn of(m: *const KitMap, champion: u32, role: usize) u16 {
        return m.class.get(cellKey(champion, role)) orelse m.none;
    }

    fn deinit(m: *KitMap, gpa: Allocator) void {
        m.class.deinit(gpa);
    }
};

fn cellKey(champion: u32, role: usize) u64 {
    return @as(u64, champion) << 3 | role;
}

const Parent = struct { key: u64, sign: f32 };

/// Parent key ids: kit parents 64 + slot, pair parents 128 (ally) and 129 (matchups)
fn kitParent(map: *const KitMap, slot: usize, a: u32, b: u32) ?Parent {
    const s = slots[slot];
    const ka = map.of(a, s.r);
    const kb = map.of(b, s.q);
    if (s.ally or s.r != s.q) return .{ .key = key(64 + slot, ka, kb), .sign = 1 };
    if (ka == kb) return null;
    return .{ .key = key(64 + slot, @min(ka, kb), @max(ka, kb)), .sign = if (ka < kb) 1 else -1 };
}

/// The same two champions in any slots of the kind; perm (control): a slot's own
/// relabelling of champions, so a parent pools unrelated pairs across slots
fn pairParent(perm: ?*const Perm, ident: bool, slot: usize, a0: u32, b0: u32) ?Parent {
    const s = slots[slot];
    if (ident) return .{ .key = key(130 + slot, a0, b0), .sign = 1 };
    const a = if (perm) |p| p.of(slot, a0) else a0;
    const b = if (perm) |p| p.of(slot, b0) else b0;
    if (a == b) return null;
    if (s.ally) return .{ .key = key(128, @min(a, b), @max(a, b)), .sign = 1 };
    return .{ .key = key(129, @min(a, b), @max(a, b)), .sign = if (a < b) 1 else -1 };
}

/// Per slot, a fixed random bijection of champion ids (by hash rank)
const Perm = struct {
    map: [n_slots]std.AutoHashMapUnmanaged(u32, u32) = @splat(.empty),

    fn of(p: *const Perm, slot: usize, a: u32) u32 {
        return p.map[slot].get(a) orelse a;
    }

    fn init(gpa: Allocator, champions: []const u32, seed: u64) !Perm {
        var p: Perm = .{};
        const shuffled = try gpa.dupe(u32, champions);
        defer gpa.free(shuffled);
        for (&p.map, 0..) |*m, slot| {
            var rng: std.Random.DefaultPrng = .init(seed +% slot *% 0x9e3779b97f4a7c15);
            rng.random().shuffle(u32, shuffled);
            for (champions, shuffled) |a, b| try m.put(gpa, a, b);
        }
        return p;
    }

    fn deinit(p: *Perm, gpa: Allocator) void {
        for (&p.map) |*m| m.deinit(gpa);
    }
};

// ---------------------------------------------------------------- structure

const none_u32 = std.math.maxInt(u32);

/// The extra parts of one variant on one v2 problem, indexed by v2's pair cells
const Struct = struct {
    rank: u32,
    /// Per v2 param (pair cells only): its parents (none_u32) and signs
    kit_of: []u32,
    kit_sign: []f32,
    pair_of: []u32,
    pair_sign: []f32,
    /// Parent params: variance group (kit: slot; pair: 0 ally, 1 matchups)
    kit_group: []u8,
    pair_group: []u8,
    parent_idx: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    /// Low rank, per v2 pair cell: slot and its two champions' factor rows
    cell_slot: []u8,
    ia: []u32,
    ib: []u32,
    /// Per slot: champion -> row of U (role r) and V (role q; same-role: U's rows)
    rows_u: [n_slots]std.AutoHashMapUnmanaged(u32, u32) = @splat(.empty),
    rows_v: [n_slots]std.AutoHashMapUnmanaged(u32, u32) = @splat(.empty),
    /// Offsets of each slot's U and V in the factor array (k per row)
    u_off: [n_slots]u32 = @splat(0),
    v_off: [n_slots]u32 = @splat(0),
    n_fac: u32 = 0,
    kit: ?*const KitMap,
    perm: ?*const Perm,
    ident: bool,
    fac_sd: f64,

    fn deinit(s: *Struct, gpa: Allocator) void {
        gpa.free(s.kit_of);
        gpa.free(s.kit_sign);
        gpa.free(s.pair_of);
        gpa.free(s.pair_sign);
        gpa.free(s.kit_group);
        gpa.free(s.pair_group);
        gpa.free(s.cell_slot);
        gpa.free(s.ia);
        gpa.free(s.ib);
        s.parent_idx.deinit(gpa);
        for (&s.rows_u, &s.rows_v) |*u, *v| {
            u.deinit(gpa);
            v.deinit(gpa);
        }
    }

    fn sameRole(slot: usize) bool {
        const s = slots[slot];
        return !s.ally and s.r == s.q;
    }
};

const Parts = struct {
    kit: ?*const KitMap = null,
    pair: bool = false,
    pair_mode: PairMode = .pooled,
    /// pair_mode shuf: the slots' relabellings
    perm: ?*const Perm = null,
    rank: u32 = 0,
    fac_sd: f64 = 0,
};

fn buildStruct(gpa: Allocator, p: *const A.Problem, parts: Parts) !Struct {
    const np = p.n_params();
    const kit = parts.kit;
    const pair = parts.pair;
    const rank = parts.rank;
    const perm = if (parts.pair_mode == .shuf) parts.perm.? else null;
    const ident = parts.pair_mode == .ident;
    var s: Struct = .{
        .rank = rank,
        .kit_of = try gpa.alloc(u32, np),
        .kit_sign = try gpa.alloc(f32, np),
        .pair_of = try gpa.alloc(u32, np),
        .pair_sign = try gpa.alloc(f32, np),
        .kit_group = &.{},
        .pair_group = &.{},
        .cell_slot = try gpa.alloc(u8, np),
        .ia = try gpa.alloc(u32, np),
        .ib = try gpa.alloc(u32, np),
        .kit = kit,
        .perm = perm,
        .ident = ident,
        .fac_sd = parts.fac_sd,
    };
    errdefer s.deinit(gpa);
    @memset(s.kit_of, none_u32);
    @memset(s.pair_of, none_u32);
    @memset(s.cell_slot, 0xff);
    var kit_group: std.ArrayList(u8) = .empty;
    defer kit_group.deinit(gpa);
    var pair_group: std.ArrayList(u8) = .empty;
    defer pair_group.deinit(gpa);
    var n_kit: u32 = 0;
    var n_pair: u32 = 0;
    for (slots, 0..) |sl, slot| {
        for (p.param_start[sl.group]..p.param_start[sl.group + 1]) |j| {
            const k = p.key_of[j];
            const a: u32 = @intCast(k >> 24 & 0xffffff);
            const b: u32 = @intCast(k & 0xffffff);
            s.cell_slot[j] = @intCast(slot);
            if (kit) |m| if (kitParent(m, slot, a, b)) |pa| {
                const e = try s.parent_idx.getOrPut(gpa, pa.key);
                if (!e.found_existing) {
                    e.value_ptr.* = n_kit;
                    n_kit += 1;
                    try kit_group.append(gpa, @intCast(slot));
                }
                s.kit_of[j] = e.value_ptr.*;
                s.kit_sign[j] = pa.sign;
            };
            if (pair) if (pairParent(perm, ident, slot, a, b)) |pa| {
                const e = try s.parent_idx.getOrPut(gpa, pa.key);
                if (!e.found_existing) {
                    e.value_ptr.* = n_pair;
                    n_pair += 1;
                    try pair_group.append(gpa, @intFromBool(!sl.ally));
                }
                s.pair_of[j] = e.value_ptr.*;
                s.pair_sign[j] = pa.sign;
            };
            if (rank > 0) {
                const same = Struct.sameRole(slot);
                s.ia[j] = try rowOf(gpa, &s.rows_u[slot], a);
                s.ib[j] = try rowOf(gpa, if (same) &s.rows_u[slot] else &s.rows_v[slot], b);
            }
        }
    }
    if (rank > 0) {
        var at: u32 = 0;
        for (0..n_slots) |slot| {
            s.u_off[slot] = at;
            at += s.rows_u[slot].count() * rank;
            // Same-role: V has U's rows
            s.v_off[slot] = at;
            const nv = if (Struct.sameRole(slot)) s.rows_u[slot].count() else s.rows_v[slot].count();
            at += nv * rank;
        }
        s.n_fac = at;
    }
    if (parts.pair_mode == .multi) {
        // A parent only where the two champions met in 2+ slots
        const slot_seen = try gpa.alloc(u32, n_pair);
        defer gpa.free(slot_seen);
        const n_slots_of = try gpa.alloc(u8, n_pair);
        defer gpa.free(n_slots_of);
        @memset(slot_seen, none_u32);
        @memset(n_slots_of, 0);
        for (s.pair_of, s.cell_slot) |k, slot| {
            if (k == none_u32 or slot_seen[k] == slot) continue;
            slot_seen[k] = slot;
            n_slots_of[k] +|= 1;
        }
        for (s.pair_of) |*k| if (k.* != none_u32 and n_slots_of[k.*] < 2) {
            k.* = none_u32;
        };
    }
    s.kit_group = try kit_group.toOwnedSlice(gpa);
    s.pair_group = try pair_group.toOwnedSlice(gpa);
    return s;
}

fn rowOf(gpa: Allocator, m: *std.AutoHashMapUnmanaged(u32, u32), a: u32) !u32 {
    const e = try m.getOrPut(gpa, a);
    if (!e.found_existing) e.value_ptr.* = m.count() - 1;
    return e.value_ptr.*;
}

// ---------------------------------------------------------------- fit

const Fitted = struct {
    theta: []f64,
    kit: []f64,
    pair: []f64,
    fac: []f64,
    sigma2: [A.n_groups]f64,
    kit_s2: [n_slots]f64,
    pair_s2: [2]f64,
    fac_s2: [n_slots]f64,

    fn deinit(f: *Fitted, gpa: Allocator) void {
        gpa.free(f.theta);
        gpa.free(f.kit);
        gpa.free(f.pair);
        gpa.free(f.fac);
    }
};

/// v2's fit (additive.fit, logistic, default variances) with the structure's steps after
/// each pass over v2's groups; with no structure it is additive.fit exactly
fn fitAll(gpa: Allocator, p: *const A.Problem, s: ?*const Struct, cfg: A.Config, seed: u64) !Fitted {
    const np = p.n_params();
    const ng = p.games.len;
    const theta = try gpa.alloc(f64, np);
    errdefer gpa.free(theta);
    const h = try gpa.alloc(f64, np);
    defer gpa.free(h);
    const grad = try gpa.alloc(f64, np);
    defer gpa.free(grad);
    const eta = try gpa.alloc(f64, ng);
    defer gpa.free(eta);
    const r = try gpa.alloc(f64, ng);
    defer gpa.free(r);
    const c = try gpa.alloc(f64, ng);
    defer gpa.free(c);
    const n_kit = if (s) |x| x.kit_group.len else 0;
    const n_pair = if (s) |x| x.pair_group.len else 0;
    const n_fac = if (s) |x| x.n_fac else 0;
    const kit = try gpa.alloc(f64, n_kit);
    errdefer gpa.free(kit);
    const pair = try gpa.alloc(f64, n_pair);
    errdefer gpa.free(pair);
    const fac = try gpa.alloc(f64, n_fac);
    errdefer gpa.free(fac);
    @memset(theta, 0);
    @memset(kit, 0);
    @memset(pair, 0);
    var sigma2: [A.n_groups]f64 = @splat(cfg.sigma2_init);
    var kit_s2: [n_slots]f64 = @splat(cfg.sigma2_init);
    var pair_s2: [2]f64 = @splat(cfg.sigma2_init);
    const fac_sd = if (s) |x| x.fac_sd else 0;
    var fac_s2: [n_slots]f64 = @splat(if (fac_sd > 0) fac_sd * fac_sd else cfg.sigma2_init);
    // Structure work arrays: per v2 param the cell's gradient, curvature and change
    const gc = try gpa.alloc(f64, if (s != null) np else 0);
    defer gpa.free(gc);
    const hc = try gpa.alloc(f64, gc.len);
    defer gpa.free(hc);
    const dc = try gpa.alloc(f64, gc.len);
    defer gpa.free(dc);
    const kit_h = try gpa.alloc(f64, n_kit);
    defer gpa.free(kit_h);
    const kit_g = try gpa.alloc(f64, n_kit);
    defer gpa.free(kit_g);
    const pair_g = try gpa.alloc(f64, n_pair);
    defer gpa.free(pair_g);
    const pair_h = try gpa.alloc(f64, n_pair);
    defer gpa.free(pair_h);
    const fac_h = try gpa.alloc(f64, n_fac);
    defer gpa.free(fac_h);
    const fac_g = try gpa.alloc(f64, n_fac);
    defer gpa.free(fac_g);
    @memset(kit_h, 1);
    @memset(pair_h, 1);
    @memset(fac_h, 1);
    {
        // A small random start: at u = v = 0 the factors' gradient is 0
        var rng: std.Random.DefaultPrng = .init(seed);
        const sd = @sqrt(fac_s2[0]) * 0.5;
        for (fac) |*x| x.* = rng.random().floatNorm(f64) * sd;
    }
    @memset(eta, 0);
    // Pair entries: v2's entries of the 25 slots' groups
    const pe_lo = p.group_start[slots[0].group];
    const pe_hi = p.group_start[slots[n_slots - 1].group + 1];
    for (slots) |sl| std.debug.assert(p.group_start[sl.group] >= pe_lo and p.group_start[sl.group + 1] <= pe_hi);
    if (s) |x| if (x.rank > 0) {
        // The factors' start enters eta through their cells
        for (gc, 0..) |*d, j| d.* = if (x.cell_slot[j] != 0xff) facValue(x, fac, j) else 0;
        for (p.entries[pe_lo..pe_hi]) |e| eta[e.game] += e.x * gc[e.param];
    };

    const fixed_params = A.n_platforms + A.n_cont;
    const passes = cfg.outer * cfg.inner + cfg.final;
    var pass: u32 = 0;
    while (pass < passes) : (pass += 1) {
        for (0..A.n_groups) |g| {
            const lo = p.param_start[g];
            const hi = if (g == A.g_fixed) fixed_params else p.param_start[g + 1];
            if (hi <= lo) continue;
            residuals(p, eta, r, c);
            @memset(grad[lo..hi], 0);
            @memset(h[lo..hi], 0);
            const es = p.entries[p.group_start[g]..p.group_start[g + 1]];
            for (es) |e| {
                grad[e.param] += e.x * r[e.game];
                h[e.param] += e.x * e.x * c[e.game];
            }
            const lam = if (g == A.g_fixed) cfg.fixed_l2 else 1 / sigma2[g];
            for (lo..hi) |j| {
                h[j] += lam;
                const step = (grad[j] - lam * theta[j]) / h[j];
                theta[j] += step;
                grad[j] = step;
            }
            for (es) |e| eta[e.game] += e.x * grad[e.param];
        }
        if (s) |x| {
            const steps = [_]Step{ .kit, .pair, .u, .v };
            for (steps) |st| {
                switch (st) {
                    .kit => if (n_kit == 0) continue,
                    .pair => if (n_pair == 0) continue,
                    .u, .v => if (n_fac == 0) continue,
                }
                residuals(p, eta, r, c);
                @memset(gc, 0);
                @memset(hc, 0);
                for (p.entries[pe_lo..pe_hi]) |e| {
                    gc[e.param] += e.x * r[e.game];
                    hc[e.param] += e.x * e.x * c[e.game];
                }
                @memset(dc, 0);
                switch (st) {
                    .kit => parentStep(x.kit_of, x.kit_sign, x.kit_group, &kit_s2, kit, kit_h, kit_g, gc, hc, dc),
                    .pair => parentStep(x.pair_of, x.pair_sign, x.pair_group, &pair_s2, pair, pair_h, pair_g, gc, hc, dc),
                    .u, .v => facStep(x, st == .u, &fac_s2, fac, fac_h, fac_g, gc, hc, dc),
                }
                for (p.entries[pe_lo..pe_hi]) |e| eta[e.game] += e.x * dc[e.param];
            }
        }
        const last_inner = (pass + 1) % cfg.inner == 0;
        if (pass < cfg.outer * cfg.inner and last_inner) {
            for (1..A.n_groups) |g| {
                const lo = p.param_start[g];
                const hi = p.param_start[g + 1];
                if (hi <= lo) continue;
                var ss: f64 = 0;
                var gam: f64 = 0;
                for (lo..hi) |j| {
                    ss += theta[j] * theta[j];
                    gam += 1 - 1 / (sigma2[g] * h[j]);
                }
                sigma2[g] = if (gam > 1e-9) @max(ss / gam, cfg.sigma2_floor) else cfg.sigma2_floor;
            }
            if (s) |x| {
                mackay(kit, kit_h, x.kit_group, &kit_s2, cfg);
                mackay(pair, pair_h, x.pair_group, &pair_s2, cfg);
                if (n_fac > 0 and fac_sd == 0) for (0..n_slots) |slot| {
                    const lo = x.u_off[slot];
                    const hi = if (slot + 1 < n_slots) x.u_off[slot + 1] else x.n_fac;
                    var ss: f64 = 0;
                    var gam: f64 = 0;
                    for (lo..hi) |j| {
                        ss += fac[j] * fac[j];
                        gam += 1 - 1 / (fac_s2[slot] * fac_h[j]);
                    }
                    // Capped: a bilinear block's MacKay update can run away (sd 5 per
                    // entry on 1007Z fold 1, rank 2)
                    if (hi > lo) fac_s2[slot] = @min(fac_cap, if (gam > 1e-9) @max(ss / gam, cfg.sigma2_floor) else cfg.sigma2_floor);
                };
            }
        }
    }
    return .{ .theta = theta, .kit = kit, .pair = pair, .fac = fac, .sigma2 = sigma2, .kit_s2 = kit_s2, .pair_s2 = pair_s2, .fac_s2 = fac_s2 };
}

const Step = enum { kit, pair, u, v };
const fac_cap = 0.05;

fn residuals(p: *const A.Problem, eta: []const f64, r: []f64, c: []f64) void {
    for (p.games, eta, r, c) |gm, e, *ri, *ci| {
        const w: f64 = gm.weight;
        const q = sigmoid(e);
        ri.* = w * (gm.y - q);
        ci.* = w * q * (1 - q);
    }
}

fn mackay(theta: []const f64, h: []const f64, group: []const u8, s2: []f64, cfg: A.Config) void {
    var ss: [n_slots]f64 = @splat(0);
    var gam: [n_slots]f64 = @splat(0);
    for (theta, h, group) |t, hj, g| {
        ss[g] += t * t;
        gam[g] += 1 - 1 / (s2[g] * hj);
    }
    for (s2, 0..) |*v, g| {
        if (gam[g] == 0 and ss[g] == 0) continue;
        v.* = if (gam[g] > 1e-9) @max(ss[g] / gam[g], cfg.sigma2_floor) else cfg.sigma2_floor;
    }
}

/// One diagonal Newton step on parent params from their cells' gradient and curvature;
/// dc gets each cell's change
fn parentStep(of: []const u32, sign: []const f32, group: []const u8, s2: []const f64, theta: []f64, h: []f64, grad: []f64, gc: []const f64, hc: []const f64, dc: []f64) void {
    @memset(grad, 0);
    @memset(h, 0);
    for (of, sign, gc, hc) |k, sg, gj, hj| {
        if (k == none_u32) continue;
        grad[k] += sg * gj;
        h[k] += hj;
    }
    for (theta, h, grad, group) |*t, *hk, *gk, grp| {
        const lam = 1 / s2[grp];
        hk.* += lam;
        const step = (gk.* - lam * t.*) / hk.*;
        t.* += step;
        gk.* = step;
    }
    for (of, sign, dc) |k, sg, *d| {
        if (k == none_u32) continue;
        d.* += sg * grad[k];
    }
}

/// A low-rank cell's value: u_a . v_b, same-role u_a . v_b - u_b . v_a
fn facValue(s: *const Struct, fac: []const f64, j: usize) f64 {
    const slot = s.cell_slot[j];
    const k = s.rank;
    const ua = fac[s.u_off[slot] + s.ia[j] * k ..][0..k];
    const vb = fac[s.v_off[slot] + s.ib[j] * k ..][0..k];
    var x: f64 = 0;
    for (ua, vb) |a, b| x += a * b;
    if (Struct.sameRole(slot)) {
        const ub = fac[s.u_off[slot] + s.ib[j] * k ..][0..k];
        const va = fac[s.v_off[slot] + s.ia[j] * k ..][0..k];
        for (ub, va) |a, b| x -= a * b;
    }
    return x;
}

/// One diagonal Newton step on U (or V) with the other side fixed; dc gets each cell's
/// change, exact as cells are linear in U given V
fn facStep(s: *const Struct, on_u: bool, s2: []const f64, fac: []f64, h: []f64, g: []f64, gc: []const f64, hc: []const f64, dc: []f64) void {
    const k = s.rank;
    for (0..n_slots) |slot| {
        const lo = if (on_u) s.u_off[slot] else s.v_off[slot];
        const hi = if (on_u) s.v_off[slot] else if (slot + 1 < n_slots) s.u_off[slot + 1] else s.n_fac;
        @memset(g[lo..hi], 0);
        @memset(h[lo..hi], 0);
    }
    // d cell / d (row i of the stepped side) = sign x the other side's row
    const Acc = struct {
        fn add(fa: []const f64, gg: []f64, hh: []f64, row: usize, other: usize, kk: usize, sg: f64, gj: f64, hj: f64) void {
            for (0..kk) |m| {
                const o = fa[other + m];
                gg[row + m] += sg * gj * o;
                hh[row + m] += hj * o * o;
            }
        }
    };
    for (s.cell_slot, gc, hc, 0..) |slot, gj, hj, j| {
        if (slot == 0xff) continue;
        const same = Struct.sameRole(slot);
        const ua = s.u_off[slot] + s.ia[j] * k;
        const vb = s.v_off[slot] + s.ib[j] * k;
        if (on_u) {
            Acc.add(fac, g, h, ua, vb, k, 1, gj, hj);
            if (same) Acc.add(fac, g, h, s.u_off[slot] + s.ib[j] * k, s.v_off[slot] + s.ia[j] * k, k, -1, gj, hj);
        } else {
            Acc.add(fac, g, h, vb, ua, k, 1, gj, hj);
            if (same) Acc.add(fac, g, h, s.v_off[slot] + s.ia[j] * k, s.u_off[slot] + s.ib[j] * k, k, -1, gj, hj);
        }
    }
    for (0..n_slots) |slot| {
        const lo = if (on_u) s.u_off[slot] else s.v_off[slot];
        const hi = if (on_u) s.v_off[slot] else if (slot + 1 < n_slots) s.u_off[slot + 1] else s.n_fac;
        const lam = 1 / s2[slot];
        for (lo..hi) |j| {
            h[j] += lam;
            // Clamped: the objective is not convex in the factors
            const step = std.math.clamp((g[j] - lam * fac[j]) / h[j], -0.1, 0.1);
            fac[j] += step;
            g[j] = step;
        }
    }
    // Change of each cell: the step's row against the fixed side
    for (s.cell_slot, dc, 0..) |slot, *d, j| {
        if (slot == 0xff) continue;
        const ua = s.u_off[slot] + s.ia[j] * k;
        const vb = s.v_off[slot] + s.ib[j] * k;
        var x: f64 = 0;
        if (on_u) {
            for (0..k) |m| x += g[ua + m] * fac[vb + m];
            if (Struct.sameRole(slot)) {
                const ub = s.u_off[slot] + s.ib[j] * k;
                const va = s.v_off[slot] + s.ia[j] * k;
                for (0..k) |m| x -= g[ub + m] * fac[va + m];
            }
        } else {
            for (0..k) |m| x += fac[ua + m] * g[vb + m];
            if (Struct.sameRole(slot)) {
                const ub = s.u_off[slot] + s.ib[j] * k;
                const va = s.v_off[slot] + s.ia[j] * k;
                for (0..k) |m| x -= fac[ub + m] * g[va + m];
            }
        }
        d.* += x;
    }
}

/// Blue's logit for any game: v2's terms (cells not in the fit games 0) plus the
/// structure's, which also covers pair cells the fit games never had
fn predict(p: *const A.Problem, s: ?*const Struct, f: *const Fitted, g: *const A.GameIn) f64 {
    var x = f.theta[g.platform];
    for (0..A.n_cont) |ci| {
        if (p.variant.cont >> @intCast(ci) & 1 == 1) x += f.theta[A.n_platforms + ci] * g.cont[ci];
    }
    var buf: [2]Cell = undefined;
    for (A.g_main..A.g_ally) |gr| {
        if (!p.variant.has(gr)) continue;
        const n = cellsOf(gr, &g.teams, &buf);
        for (buf[0..n]) |cl| if (p.keys.get(cl.key)) |j| {
            x += cl.x * f.theta[j];
        };
    }
    for (slots, 0..) |sl, slot| {
        if (!p.variant.has(sl.group)) continue;
        const n = cellsOf(sl.group, &g.teams, &buf);
        for (buf[0..n]) |cl| {
            if (p.keys.get(cl.key)) |j| x += cl.x * f.theta[j];
            if (s) |st| x += cl.x * structValue(st, f, slot, cl.key);
        }
    }
    return x;
}

fn structValue(s: *const Struct, f: *const Fitted, slot: usize, k: u64) f64 {
    const a: u32 = @intCast(k >> 24 & 0xffffff);
    const b: u32 = @intCast(k & 0xffffff);
    var x: f64 = 0;
    if (s.kit) |m| if (kitParent(m, slot, a, b)) |pa| {
        if (s.parent_idx.get(pa.key)) |i| x += pa.sign * f.kit[i];
    };
    if (f.pair.len > 0) if (pairParent(s.perm, s.ident, slot, a, b)) |pa| {
        if (s.parent_idx.get(pa.key)) |i| x += pa.sign * f.pair[i];
    };
    if (s.rank > 0) {
        const same = Struct.sameRole(slot);
        const ia = s.rows_u[slot].get(a) orelse return x;
        const ib = (if (same) s.rows_u[slot].get(b) else s.rows_v[slot].get(b)) orelse return x;
        const kk = s.rank;
        const ua = f.fac[s.u_off[slot] + ia * kk ..][0..kk];
        const vb = f.fac[s.v_off[slot] + ib * kk ..][0..kk];
        for (ua, vb) |u, v| x += u * v;
        if (same) {
            const ub = f.fac[s.u_off[slot] + ib * kk ..][0..kk];
            const va = f.fac[s.v_off[slot] + ia * kk ..][0..kk];
            for (ub, va) |u, v| x -= u * v;
        }
    }
    return x;
}

// ---------------------------------------------------------------- kit maps

/// Data Dragon tag strings ("Fighter,Tank"), role-free; shuf: classes permuted among
/// champions
fn tagMap(gpa: Allocator, arena: Allocator, io: Io, snap: []const u8, shuf: bool) !KitMap {
    const path = try std.fmt.allocPrint(arena, "{s}/ddragon/16.20/champion.json", .{snap});
    const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20));
    const doc = try std.json.parseFromSliceLeaky(std.json.Value, arena, text, .{});
    const data = doc.object.get("data").?.object;
    var names: std.StringArrayHashMapUnmanaged(void) = .empty;
    var ids: std.ArrayList(u32) = .empty;
    var tags: std.ArrayList([]const u8) = .empty;
    var it = data.iterator();
    while (it.next()) |e| {
        const id = try std.fmt.parseInt(u32, e.value_ptr.object.get("key").?.string, 10);
        var t: std.ArrayList(u8) = .empty;
        for (e.value_ptr.object.get("tags").?.array.items, 0..) |x, i| {
            if (i > 0) try t.append(arena, ',');
            try t.appendSlice(arena, x.string);
        }
        try ids.append(arena, id);
        try tags.append(arena, t.items);
        try names.put(arena, t.items, {});
    }
    const sorted = try arena.dupe([]const u8, names.keys());
    std.mem.sort([]const u8, sorted, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt);
    const class = try arena.alloc(u16, ids.items.len);
    for (tags.items, class) |t, *c| {
        for (sorted, 0..) |s, i| if (std.mem.eql(u8, s, t)) {
            c.* = @intCast(i);
        };
    }
    if (shuf) {
        var rng: std.Random.DefaultPrng = .init(0x5f0f);
        rng.random().shuffle(u16, class);
    }
    var m: KitMap = .{ .none = @intCast(sorted.len) };
    errdefer m.deinit(gpa);
    for (ids.items, class) |id, c| for (0..n_role) |r| try m.class.put(gpa, cellKey(id, r), c);
    return m;
}

/// Kit profile of a seat (NaN unknown): what the champion does, not whether it won
const n_feat = 13;

fn seatFeatures(r: *const rows.Row) [n_feat]f64 {
    const s = r.stats;
    const st = struct {
        fn f(x: seatstats.Stats, k: seatstats.SeatStat) f64 {
            return x[@backingInt(k)];
        }
    }.f;
    var out: [n_feat]f64 = @splat(std.math.nan(f64));
    const m = st(s, .minutes);
    if (std.math.isNan(m) or m <= 0) return out;
    const phys = st(s, .dmg_phys);
    const magic = st(s, .dmg_magic);
    const tru = st(s, .dmg_true);
    const dmg = phys + magic + tru;
    const taken = st(s, .taken_phys) + st(s, .taken_magic) + st(s, .taken_true);
    const mit = st(s, .mitigated);
    if (dmg > 0) {
        out[0] = magic / dmg;
        out[1] = tru / dmg;
    }
    out[2] = dmg / m;
    out[3] = taken / m;
    if (mit + taken > 0) out[4] = mit / (mit + taken);
    out[5] = st(s, .cc_time) / m;
    out[6] = st(s, .immobilisations) / m;
    out[7] = (st(s, .heal) - st(s, .heal_allies)) / m;
    out[8] = (st(s, .heal_allies) + st(s, .shield_allies)) / m;
    out[9] = st(s, .dmg_buildings) / m;
    out[10] = st(s, .armor_end) - st(s, .mr_end);
    out[11] = st(s, .attack_range);
    out[12] = r.y[api.outcomeIndex(.gold14)];
    return out;
}

/// k-means on champion-role kit profiles (fit games' seats, shrunk to the role mean by
/// 20 seats, z within role over champion-roles with 200+ seats), K per role; every
/// champion-role of the fit games goes to its nearest centre. shuf: classes permuted
/// among a role's champion-roles
fn profMap(gpa: Allocator, d: *const rows.Data, fit: []const bool, k: u32, shuf: bool) !KitMap {
    const Acc = struct { sum: [n_feat]f64 = @splat(0), n: [n_feat]f64 = @splat(0), seats: f64 = 0 };
    var acc: std.AutoHashMapUnmanaged(u64, Acc) = .empty;
    defer acc.deinit(gpa);
    var role_acc: [n_role]Acc = @splat(.{});
    for (d.rows) |*r| {
        if (!fit[r.game]) continue;
        const role: usize = @backingInt(r.role);
        const x = seatFeatures(r);
        const e = try acc.getOrPutValue(gpa, cellKey(r.champion, role), .{});
        for ([_]*Acc{ e.value_ptr, &role_acc[role] }) |a| {
            a.seats += 1;
            for (x, 0..) |v, i| if (!std.math.isNan(v) and !std.math.isInf(v)) {
                a.sum[i] += v;
                a.n[i] += 1;
            };
        }
    }
    var m: KitMap = .{ .none = @intCast(k) };
    errdefer m.deinit(gpa);
    for (0..n_role) |role| {
        var keys: std.ArrayList(u64) = .empty;
        defer keys.deinit(gpa);
        var pts: std.ArrayList([n_feat]f64) = .empty;
        defer pts.deinit(gpa);
        var it = acc.iterator();
        while (it.next()) |e| if (e.key_ptr.* & 7 == role) try keys.append(gpa, e.key_ptr.*);
        std.mem.sort(u64, keys.items, {}, std.sort.asc(u64));
        const ra = role_acc[role];
        for (keys.items) |key_| {
            const a = acc.get(key_).?;
            var p: [n_feat]f64 = undefined;
            for (&p, 0..) |*v, i| {
                const mean = if (ra.n[i] > 0) ra.sum[i] / ra.n[i] else 0;
                v.* = (a.sum[i] + 20 * mean) / (a.n[i] + 20);
            }
            try pts.append(gpa, p);
        }
        // z over the main champion-roles
        var mu: [n_feat]f64 = @splat(0);
        var sd: [n_feat]f64 = @splat(0);
        var nm: f64 = 0;
        for (keys.items, pts.items) |key_, p| if (acc.get(key_).?.seats >= 200) {
            nm += 1;
            for (&mu, p) |*x, v| x.* += v;
        };
        for (&mu) |*x| x.* /= @max(nm, 1);
        for (keys.items, pts.items) |key_, p| if (acc.get(key_).?.seats >= 200) {
            for (&sd, p, mu) |*x, v, u| x.* += (v - u) * (v - u);
        };
        for (&sd) |*x| x.* = @sqrt(x.* / @max(nm, 1));
        for (pts.items) |*p| for (p, mu, sd) |*v, u, s| {
            v.* = if (s > 0) (v.* - u) / s else 0;
        };
        var main_pts: std.ArrayList([n_feat]f64) = .empty;
        defer main_pts.deinit(gpa);
        for (keys.items, pts.items) |key_, p| if (acc.get(key_).?.seats >= 200) try main_pts.append(gpa, p);
        const centres = try kmeans(gpa, main_pts.items, @min(k, @as(u32, @intCast(main_pts.items.len))), 0xc105 +% role);
        defer gpa.free(centres);
        const class = try gpa.alloc(u16, keys.items.len);
        defer gpa.free(class);
        for (pts.items, class) |p, *c| c.* = nearest(centres, p);
        if (shuf) {
            var rng: std.Random.DefaultPrng = .init(0x5f0f +% role);
            rng.random().shuffle(u16, class);
        }
        for (keys.items, class) |key_, c| try m.class.put(gpa, key_, c);
    }
    return m;
}

fn nearest(centres: []const [n_feat]f64, p: [n_feat]f64) u16 {
    var best: usize = 0;
    var bd: f64 = std.math.inf(f64);
    for (centres, 0..) |c, i| {
        var dd: f64 = 0;
        for (c, p) |a, b| dd += (a - b) * (a - b);
        if (dd < bd) {
            bd = dd;
            best = i;
        }
    }
    return @intCast(best);
}

/// k-means++ start, then Lloyd until no point moves (at most 100 rounds)
fn kmeans(gpa: Allocator, pts: []const [n_feat]f64, k: u32, seed: u64) ![][n_feat]f64 {
    const centres = try gpa.alloc([n_feat]f64, k);
    errdefer gpa.free(centres);
    if (k == 0) return centres;
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    centres[0] = pts[rnd.uintLessThan(usize, pts.len)];
    const dist = try gpa.alloc(f64, pts.len);
    defer gpa.free(dist);
    for (1..k) |ci| {
        var total: f64 = 0;
        for (pts, dist) |p, *dd| {
            const c = centres[nearest(centres[0..ci], p)];
            dd.* = 0;
            for (c, p) |a, b| dd.* += (a - b) * (a - b);
            total += dd.*;
        }
        var u = rnd.float(f64) * total;
        var pick: usize = pts.len - 1;
        for (dist, 0..) |dd, i| {
            if (u < dd) {
                pick = i;
                break;
            }
            u -= dd;
        }
        centres[ci] = pts[pick];
    }
    const assign = try gpa.alloc(u16, pts.len);
    defer gpa.free(assign);
    @memset(assign, std.math.maxInt(u16));
    for (0..100) |_| {
        var moved = false;
        for (pts, assign) |p, *a| {
            const n = nearest(centres, p);
            if (n != a.*) moved = true;
            a.* = n;
        }
        if (!moved) break;
        for (centres, 0..) |*c, ci| {
            var sum: [n_feat]f64 = @splat(0);
            var n: f64 = 0;
            for (pts, assign) |p, a| if (a == ci) {
                n += 1;
                for (&sum, p) |*s, v| s.* += v;
            };
            if (n > 0) for (c, sum) |*x, s| {
                x.* = s / n;
            };
        }
    }
    return centres;
}

// ---------------------------------------------------------------- planted part

fn hashNorm(seed: u64, parts: []const u64) f64 {
    var h: std.hash.Wyhash = .init(seed);
    for (parts) |x| h.update(std.mem.asBytes(&x));
    var rng: std.Random.DefaultPrng = .init(h.final());
    return rng.random().floatNorm(f64);
}

/// The planted structured part of blue's logit: per pair slot, a kit-pair cell (sd
/// `sd` logit) or a rank-2 cell u_a . v_b with sd `sd`
const Plant = struct {
    sd: f64,
    kit: ?*const KitMap,
    seed: u64,

    fn value(pl: Plant, t: *const [2][n_role]u32) f64 {
        var x: f64 = 0;
        var buf: [2]Cell = undefined;
        for (slots, 0..) |sl, slot| {
            const n = cellsOf(sl.group, t, &buf);
            for (buf[0..n]) |cl| {
                const a: u32 = @intCast(cl.key >> 24 & 0xffffff);
                const b: u32 = @intCast(cl.key & 0xffffff);
                x += cl.x * pl.cell(slot, a, b);
            }
        }
        return x;
    }

    fn cell(pl: Plant, slot: usize, a: u32, b: u32) f64 {
        if (pl.kit) |m| {
            const pa = kitParent(m, slot, a, b) orelse return 0;
            return pa.sign * pl.sd * hashNorm(pl.seed, &.{pa.key});
        }
        const same = Struct.sameRole(slot);
        // Each product term has variance s^4 per dimension; 2 dims, twice for same-role
        const s = std.math.pow(f64, pl.sd * pl.sd / @as(f64, if (same) 4 else 2), 0.25);
        var x: f64 = 0;
        for (0..2) |m| {
            x += s * s * hashNorm(pl.seed, &.{ slot, a, 0, m }) * hashNorm(pl.seed, &.{ slot, b, 1, m });
            if (same) x -= s * s * hashNorm(pl.seed, &.{ slot, b, 0, m }) * hashNorm(pl.seed, &.{ slot, a, 1, m });
        }
        return x;
    }
};

// ---------------------------------------------------------------- blocks

fn loss1(y: f32, p: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

/// Per block and model: games, summed loss, and the paired difference to v2's
const Sums = struct { n: f64 = 0, loss: f64 = 0, d: f64 = 0, d2: f64 = 0 };

const Task = struct {
    variant: ?Variant,
    kit: ?*const KitMap = null,
    perm: ?*const Perm = null,
};

const TaskOut = struct {
    pred: []f64 = &.{},
    fit: ?Fitted = null,
    /// Parent and factor counts, for the table
    n_kit: usize = 0,
    n_pair: usize = 0,
    n_fac: usize = 0,
};

fn runBlock(
    gpa: Allocator,
    arena: Allocator,
    io: Io,
    d: *const rows.Data,
    in: addinputs.Inputs,
    c: harness.Cuts,
    block: Block,
    opts: Options,
    tags: [2]*const KitMap,
    champions: []const u32,
    dir: Io.Dir,
    sums: [][6]Sums,
    w: *Io.Writer,
    sw: *Io.Writer,
) !void {
    const t0 = Io.Clock.awake.now(io);
    const spec: winnet.Spec = switch (block) {
        .dev => .{ .before = c.dev, .lo = c.dev, .hi = c.test_, .dev = true, .resample = opts.resample },
        else => blk: {
            const f = c.fold(@backingInt(block));
            break :blk .{ .before = f.lo, .lo = f.lo, .hi = f.hi, .dev = false, .resample = opts.resample };
        },
    };
    var fit_idx: std.ArrayList(u32) = .empty;
    var scored: std.ArrayList(u32) = .empty;
    const is_fit = try arena.alloc(bool, d.games.len);
    for (d.games, is_fit, 0..) |g, *f, i| {
        f.* = spec.fits(c, g, 1);
        if (f.*) try fit_idx.append(arena, @intCast(i));
        if (spec.scores(c, g, 1)) try scored.append(arena, @intCast(i));
    }
    var mix = try addinputs.Mix.init(gpa, d, is_fit, in.win);
    defer mix.deinit(gpa);
    const fit_win = try arena.alloc(A.GameIn, fit_idx.items.len);
    for (fit_idx.items, fit_win) |gi, *fw| fw.* = addinputs.gameIn(d, gi, in.win[gi], mix.diff(d, in, gi, true));
    const scored_in = try arena.alloc(A.GameIn, scored.items.len);
    for (scored.items, scored_in) |gi, *s| s.* = addinputs.gameIn(d, gi, in.win[gi], mix.diff(d, in, gi, false));
    var p = try A.build(gpa, .logistic, addinputs.fullVariant(true, 1), fit_win);
    defer p.deinit(gpa);

    // Kit maps this block needs (prof maps from its fit games)
    var maps: std.ArrayList(struct { kit: Kit, map: *KitMap }) = .empty;
    defer for (maps.items) |m| {
        if (m.kit.kind == .prof) m.map.deinit(gpa);
    };
    const want = try arena.alloc(?Kit, opts.variants.len + 1);
    for (opts.variants, want[0..opts.variants.len]) |v, *k| k.* = v.kit;
    want[opts.variants.len] = opts.plant_kind;
    for (want) |wk| if (wk) |k| {
        for (maps.items) |m| {
            if (m.kit.eql(k)) break;
        } else {
            const map = switch (k.kind) {
                .tag => @constCast(tags[@intFromBool(k.shuf)]),
                .prof => blk: {
                    const m = try arena.create(KitMap);
                    m.* = try profMap(gpa, d, is_fit, k.k, k.shuf);
                    break :blk m;
                },
            };
            try maps.append(arena, .{ .kit = k, .map = map });
        }
    };
    const mapOf = struct {
        fn f(ms: anytype, k: ?Kit) ?*const KitMap {
            const kk = k orelse return null;
            for (ms) |m| if (m.kit.eql(kk)) return m.map;
            unreachable;
        }
    }.f;
    var perm: ?Perm = null;
    defer if (perm) |*x| x.deinit(gpa);
    for (opts.variants) |v| if (v.pair_mode == .shuf and perm == null) {
        perm = try Perm.init(gpa, champions, 0x9e57);
    };

    // Planted power check: outcomes drawn from v2's fit on the real games plus the plant
    const ys = try arena.alloc(f32, scored.items.len);
    for (scored.items, ys) |gi, *y| y.* = in.win[gi];
    if (opts.plant > 0 or opts.plant_kind != null or opts.plant_rank) {
        var truth = try fitAll(gpa, &p, null, .{}, 1);
        defer truth.deinit(gpa);
        const pl: Plant = .{ .sd = opts.plant / 25, .kit = if (opts.plant_rank) null else mapOf(maps.items, opts.plant_kind), .seed = opts.plant_seed };
        var rng: std.Random.DefaultPrng = .init(opts.plant_seed ^ 0x51a7);
        const rnd = rng.random();
        var planted_var: f64 = 0;
        for (fit_win) |*g| {
            const pv = pl.value(&g.teams);
            planted_var += pv * pv;
            g.y = if (rnd.float(f64) < sigmoid(predict(&p, null, &truth, g) + pv)) 1 else 0;
        }
        for (scored_in, ys) |*g, *y| {
            y.* = if (rnd.float(f64) < sigmoid(predict(&p, null, &truth, g) + pl.value(&g.teams))) 1 else 0;
            g.y = y.*;
        }
        try w.print("block {s}: planted {s} part, cell sd {d:.2} pp: sd of its blue logit {d:.2} pp\n", .{ blockName(block), if (pl.kit != null) "kit" else "rank-2", opts.plant, @sqrt(planted_var / @as(f64, @floatFromInt(fit_win.len))) * 25 });
    }

    const tasks = try arena.alloc(Task, opts.variants.len + 1);
    tasks[0] = .{ .variant = null };
    for (opts.variants, tasks[1..]) |v, *t| t.* = .{
        .variant = v,
        .kit = mapOf(maps.items, v.kit),
        .perm = if (v.pair_mode == .shuf) &perm.? else null,
    };
    const outs = try arena.alloc(TaskOut, tasks.len);
    defer for (outs) |*o| {
        gpa.free(o.pred);
        if (o.fit) |*f| f.deinit(gpa);
    };
    const Ctx = struct {
        gpa: Allocator,
        p: *const A.Problem,
        tasks: []const Task,
        outs: []TaskOut,
        scored: []const A.GameIn,
        fn one(x: @This(), i: usize) !void {
            const t = x.tasks[i];
            var st: ?Struct = null;
            defer if (st) |*s| s.deinit(x.gpa);
            if (t.variant) |v| st = try buildStruct(x.gpa, x.p, .{ .kit = t.kit, .pair = v.pair, .pair_mode = v.pair_mode, .perm = t.perm, .rank = v.rank, .fac_sd = v.fac_sd });
            const sp: ?*const Struct = if (st) |*s| s else null;
            const f = try fitAll(x.gpa, x.p, sp, .{}, 0xfac +% i);
            const pred = try x.gpa.alloc(f64, x.scored.len);
            for (x.scored, pred) |*g, *o| o.* = sigmoid(predict(x.p, sp, &f, g));
            x.outs[i] = .{
                .pred = pred,
                .fit = f,
                .n_kit = if (sp) |s| s.kit_group.len else 0,
                .n_pair = if (sp) |s| s.pair_group.len else 0,
                .n_fac = if (sp) |s| s.n_fac else 0,
            };
        }
    };
    var at: usize = 0;
    while (at < tasks.len) : (at += opts.threads) {
        const n = @min(opts.threads, tasks.len - at);
        try par.forEach(io, n, Ctx{ .gpa = gpa, .p = &p, .tasks = tasks[at..][0..n], .outs = outs[at..][0..n], .scored = scored_in }, Ctx.one);
    }
    if (block == opts.blocks[0]) {
        // fitAll without structure must be additive.fit
        var ref = try A.fit(gpa, &p, .{}, null, null);
        defer ref.deinit(gpa);
        var dmax: f64 = 0;
        for (ref.theta, outs[0].fit.?.theta) |a, b| dmax = @max(dmax, @abs(a - b));
        try w.print("check: v2 here vs additive.fit, max |theta difference| {e:.2}\n", .{dmax});
    }

    const name = blockName(block);
    try w.print("block {s}: fit {d} games, {d} v2 params, scored {d}; {d:.0} s\n", .{ name, fit_idx.items.len, p.n_params(), scored.items.len, winnet.secondsSince(io, t0) });
    const bi: usize = @backingInt(block);
    const nsc: f64 = @floatFromInt(@max(scored.items.len, 1));
    for (tasks, outs, 0..) |t, o, ti| {
        var s: Sums = .{ .n = nsc };
        for (ys, outs[0].pred, o.pred) |y, a, b| {
            const lb = loss1(y, b);
            const dd = lb - loss1(y, a);
            s.loss += lb;
            s.d += dd;
            s.d2 += dd * dd;
        }
        sums[ti][bi] = s;
        const label = if (t.variant) |v| v.label else "v2";
        const mean = s.d / nsc;
        const se = @sqrt(@max(s.d2 / nsc - mean * mean, 0) / @max(nsc - 1, 1));
        try w.print("  {s:<28} loss {d:.5}  vs v2 {d:.3} +- {d:.3} mnats  ({d} kit, {d} pair, {d} factor params)\n", .{ label, s.loss / nsc, mean * 1000, 1.96 * se * 1000, o.n_kit, o.n_pair, o.n_fac });
        const f = &o.fit.?;
        // Spreads per slot, pp at 50%: v2's own cells, then the parts'
        for (slots, 0..) |sl, slot| {
            var nbuf: [64]u8 = undefined;
            try sw.print("{s}\t{s}\t{s}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\n", .{
                name,                                               label,                                                                  A.groupName(&nbuf, sl.group),                       @sqrt(f.sigma2[sl.group]) * 25,
                if (o.n_kit > 0) @sqrt(f.kit_s2[slot]) * 25 else 0, if (o.n_pair > 0) @sqrt(f.pair_s2[@intFromBool(!sl.ally)]) * 25 else 0, if (o.n_fac > 0) @sqrt(f.fac_s2[slot]) * 25 else 0,
            });
        }
        const gw = try dir.createFile(io, try std.fmt.allocPrint(arena, "games-{s}-{s}.tsv", .{ label, name }), .{});
        defer gw.close(io);
        var gbuf: [64 * 1024]u8 = undefined;
        var gfw = gw.writer(io, &gbuf);
        try gfw.interface.writeAll("match_id\tslot\toutcome\ty\tpred\tblock\n");
        for (scored.items, ys, o.pred) |gi, y, pr| try gfw.interface.print("{s}\t0\twin\t{d}\t{d:.6}\t{s}\n", .{ d.games[gi].match_id, y, pr, name });
        try gfw.interface.flush();
    }
    try w.flush();
    try sw.flush();
}

// ---------------------------------------------------------------- main

fn parseOptions(arena: Allocator, args: []const []const u8) !Options {
    var o: Options = .{};
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        if (i + 1 >= args.len) return error.MissingValue;
        const k = args[i];
        const v = args[i + 1];
        if (std.mem.eql(u8, k, "--out")) {
            o.out = v;
        } else if (std.mem.eql(u8, k, "--blocks")) {
            var out: std.ArrayList(Block) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |b| {
                try out.append(arena, if (std.mem.eql(u8, b, "dev")) .dev else switch (try std.fmt.parseInt(u8, b, 10)) {
                    1 => .f1,
                    2 => .f2,
                    3 => .f3,
                    4 => .f4,
                    5 => .f5,
                    else => return error.BadBlock,
                });
            }
            o.blocks = out.items;
        } else if (std.mem.eql(u8, k, "--threads")) {
            o.threads = @max(1, try std.fmt.parseInt(u32, v, 10));
        } else if (std.mem.eql(u8, k, "--variants")) {
            var out: std.ArrayList(Variant) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |x| try out.append(arena, try parseVariant(x));
            o.variants = out.items;
        } else if (std.mem.eql(u8, k, "--resample")) {
            o.resample = try std.fmt.parseInt(u32, v, 10);
        } else if (std.mem.eql(u8, k, "--shuffle")) {
            o.shuffle = try std.fmt.parseInt(u64, v, 10);
        } else if (std.mem.eql(u8, k, "--plant")) {
            o.plant = try std.fmt.parseFloat(f64, v);
        } else if (std.mem.eql(u8, k, "--plant-kind")) {
            if (std.mem.eql(u8, v, "rank")) {
                o.plant_rank = true;
            } else o.plant_kind = (try parseVariant(v)).kit orelse return error.BadPlant;
        } else if (std.mem.eql(u8, k, "--plant-seed")) {
            o.plant_seed = try std.fmt.parseInt(u64, v, 10);
        } else return error.UnknownOption;
    }
    return o;
}

pub fn main(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const opts = parseOptions(arena, argv[1..]) catch |e| {
        std.debug.print("pairprior: {s}\nusage:\n{s}", .{ @errorName(e), usage });
        return 2;
    };
    const snap = argv[0];
    var data = try rows.loadSnap(gpa, io, snap);
    defer data.deinit();
    const c = try harness.cuts(gpa, &data);
    const in = try addinputs.inputs(arena, &data);
    if (opts.shuffle) |seed| {
        var rng: std.Random.DefaultPrng = .init(seed);
        const r = rng.random();
        var i = in.win.len;
        while (i > 1) {
            i -= 1;
            const j = r.uintLessThan(usize, i + 1);
            std.mem.swap(f32, &in.win[i], &in.win[j]);
        }
    }
    var tag = try tagMap(gpa, arena, io, snap, false);
    defer tag.deinit(gpa);
    var tag_shuf = try tagMap(gpa, arena, io, snap, true);
    defer tag_shuf.deinit(gpa);
    var champ_set: std.AutoArrayHashMapUnmanaged(u32, void) = .empty;
    for (data.games) |g| for (g.teams) |t| for (t) |ch| try champ_set.put(arena, ch, {});
    const champions = try arena.dupe(u32, champ_set.keys());
    std.mem.sort(u32, champions, {}, std.sort.asc(u32));

    try Io.Dir.cwd().createDirPath(io, opts.out);
    var dir = try Io.Dir.cwd().openDir(io, opts.out, .{});
    defer dir.close(io);
    var sf = try dir.createFile(io, "spreads.tsv", .{});
    defer sf.close(io);
    var sbuf: [16 * 1024]u8 = undefined;
    var sfw = sf.writer(io, &sbuf);
    try sfw.interface.writeAll("block\tmodel\tslot\tcell_sd_pp\tkit_sd_pp\tpair_sd_pp\tfactor_sd\n");
    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    try w.print("# pairprior: blocks {any}, resample {?d}, shuffle {?d}, plant {d:.2} pp ({s})\n", .{ opts.blocks, opts.resample, opts.shuffle, opts.plant, if (opts.plant_rank) "rank-2" else if (opts.plant_kind != null) "kit" else "-" });
    if (opts.shuffle != null) try w.writeAll("SHUFFLED LABELS: a control, every gain must be ~0\n");
    try w.flush();

    const sums = try arena.alloc([6]Sums, opts.variants.len + 1);
    for (sums) |*s| s.* = @splat(.{});
    for (opts.blocks) |b| {
        var block_arena: std.heap.ArenaAllocator = .init(gpa);
        defer block_arena.deinit();
        try runBlock(gpa, block_arena.allocator(), io, &data, in, c, b, opts, .{ &tag, &tag_shuf }, champions, dir, sums, w, &sfw.interface);
    }

    // Pools: development folds 1-2, sealed folds 3-5, dev-val; milli-nats vs v2
    var ff = try dir.createFile(io, "folds.tsv", .{});
    defer ff.close(io);
    var fbuf: [16 * 1024]u8 = undefined;
    var fw = ff.writer(io, &fbuf);
    try fw.interface.writeAll("model\tpool\tgames\tloss\tdiff\tse\tfolds_better\n");
    const pools = [_]struct { name: []const u8, blocks: []const usize }{
        .{ .name = "folds 1-2", .blocks = &.{ 1, 2 } },
        .{ .name = "folds 3-5", .blocks = &.{ 3, 4, 5 } },
        .{ .name = "folds 1-5", .blocks = &.{ 1, 2, 3, 4, 5 } },
        .{ .name = "dev-val", .blocks = &.{0} },
    };
    try w.writeAll("\nvs v2, milli-nats a game (negative: better), 95%; folds better\n");
    for (sums[1..], opts.variants) |s, v| {
        try w.print("  {s:<28}", .{v.label});
        for (pools) |pl| {
            var t: Sums = .{};
            var better: u32 = 0;
            var have: u32 = 0;
            for (pl.blocks) |b| {
                if (s[b].n == 0) continue;
                have += 1;
                t.n += s[b].n;
                t.loss += s[b].loss;
                t.d += s[b].d;
                t.d2 += s[b].d2;
                better += @intFromBool(s[b].d < 0);
            }
            if (t.n == 0) continue;
            const mean = t.d / t.n;
            const se = @sqrt(@max(t.d2 / t.n - mean * mean, 0) / @max(t.n - 1, 1));
            try w.print("  {s} {d:.3} +- {d:.3} ({d}/{d})", .{ pl.name, mean * 1000, 1.96 * se * 1000, better, have });
            try fw.interface.print("{s}\t{s}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\t{d}\n", .{ v.label, pl.name, t.n, t.loss / t.n, mean, se, better });
        }
        try w.writeAll("\n");
    }
    try fw.interface.flush();
    try w.writeAll("RESULT pairprior done\n");
    try w.flush();
    return 0;
}

const testing = std.testing;
const quick: A.Config = .{ .outer = 20 };

/// Random games over n champions per role (ids by role in disjoint ranges, as real ids
/// differ by role); truth: strength sd 0.2 per role plus the plant
fn synthGames(gpa: Allocator, n_games: usize, n_champ: u32, plant: Plant, seed: u64) ![]A.GameIn {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const games = try gpa.alloc(A.GameIn, n_games);
    for (games) |*g| {
        g.* = .{ .teams = undefined, .platform = 0, .y = 0 };
        for (0..2) |s| for (0..n_role) |r| {
            g.teams[s][r] = @intCast(1 + r * 1000 + rnd.uintLessThan(u32, n_champ));
        };
        var eta: f64 = 0.05 + plant.value(&g.teams);
        for (0..n_role) |r| eta += 0.2 * (hashNorm(7, &.{g.teams[0][r]}) - hashNorm(7, &.{g.teams[1][r]}));
        g.y = if (rnd.float(f64) < sigmoid(eta)) 1 else 0;
    }
    return games;
}

/// Kit class: champion id mod 4
fn modMap(gpa: Allocator, n_champ: u32) !KitMap {
    var m: KitMap = .{ .none = 4 };
    for (0..n_role) |r| for (0..n_champ) |i| {
        const id: u32 = @intCast(1 + r * 1000 + i);
        try m.class.put(gpa, cellKey(id, r), @intCast(id % 4));
    };
    return m;
}

fn heldOut(gpa: Allocator, train: []const A.GameIn, test_: []const A.GameIn, kit: ?*const KitMap, pair: bool, rank: u32) ![2]f64 {
    var p = try A.build(gpa, .logistic, addinputs.fullVariant(true, 0), train);
    defer p.deinit(gpa);
    var st = try buildStruct(gpa, &p, .{ .kit = kit, .pair = pair, .rank = rank });
    defer st.deinit(gpa);
    var f0 = try fitAll(gpa, &p, null, quick, 1);
    defer f0.deinit(gpa);
    var f1 = try fitAll(gpa, &p, &st, quick, 1);
    defer f1.deinit(gpa);
    var d: f64 = 0;
    for (test_) |*g| d += loss1(g.y, sigmoid(predict(&p, &st, &f1, g))) - loss1(g.y, sigmoid(predict(&p, null, &f0, g)));
    var sd: f64 = 0;
    if (kit != null) {
        for (f1.kit_s2) |v| sd = @max(sd, @sqrt(v));
    } else if (rank > 0) {
        for (f1.fac_s2) |v| sd = @max(sd, @sqrt(v));
    }
    return .{ d / @as(f64, @floatFromInt(test_.len)), sd };
}

test "pairprior: no structure is additive.fit" {
    const gpa = testing.allocator;
    const games = try synthGames(gpa, 6_000, 8, .{ .sd = 0.2, .kit = null, .seed = 3 }, 1);
    defer gpa.free(games);
    var p = try A.build(gpa, .logistic, addinputs.fullVariant(true, 0), games);
    defer p.deinit(gpa);
    var a = try A.fit(gpa, &p, quick, null, null);
    defer a.deinit(gpa);
    var b = try fitAll(gpa, &p, null, quick, 1);
    defer b.deinit(gpa);
    for (a.theta, b.theta) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
    for (games[0..50]) |*g| try testing.expectApproxEqAbs(A.predict(&p, &a, g), predict(&p, null, &b, g), 1e-12);
}

test "pairprior: a planted kit part is recovered and predicts" {
    const gpa = testing.allocator;
    var m = try modMap(gpa, 30);
    defer m.deinit(gpa);
    // Kit cells sd 0.25 in every slot; 30 champions a role leave thin pair cells
    const plant: Plant = .{ .sd = 0.25, .kit = &m, .seed = 5 };
    const games = try synthGames(gpa, 40_000, 30, plant, 2);
    defer gpa.free(games);
    const r = try heldOut(gpa, games[0..30_000], games[30_000..], &m, false, 0);
    try testing.expect(r[0] < -0.003);
    var none = try synthGames(gpa, 40_000, 30, .{ .sd = 0, .kit = &m, .seed = 5 }, 2);
    defer gpa.free(none);
    const z = try heldOut(gpa, none[0..30_000], none[30_000..], &m, false, 0);
    try testing.expect(@abs(z[0]) < 0.0005);
    try testing.expect(z[1] < 0.06);
}

test "pairprior: a planted rank-2 part predicts" {
    const gpa = testing.allocator;
    const plant: Plant = .{ .sd = 0.25, .kit = null, .seed = 9 };
    const games = try synthGames(gpa, 40_000, 30, plant, 4);
    defer gpa.free(games);
    const r = try heldOut(gpa, games[0..30_000], games[30_000..], null, false, 2);
    try testing.expect(r[0] < -0.003);
}

test "pairprior: swapping sides negates the prediction beyond the side term" {
    const gpa = testing.allocator;
    var m = try modMap(gpa, 8);
    defer m.deinit(gpa);
    const games = try synthGames(gpa, 4_000, 8, .{ .sd = 0.2, .kit = &m, .seed = 3 }, 6);
    defer gpa.free(games);
    var p = try A.build(gpa, .logistic, addinputs.fullVariant(true, 0), games);
    defer p.deinit(gpa);
    var st = try buildStruct(gpa, &p, .{ .kit = &m, .pair = true, .rank = 2 });
    defer st.deinit(gpa);
    var f = try fitAll(gpa, &p, &st, .{ .outer = 5 }, 1);
    defer f.deinit(gpa);
    for (games[0..20]) |g0| {
        var g = g0;
        const a = predict(&p, &st, &f, &g) - f.theta[0];
        std.mem.swap([n_role]u32, &g.teams[0], &g.teams[1]);
        const b = predict(&p, &st, &f, &g) - f.theta[0];
        try testing.expectApproxEqAbs(a, -b, 1e-9);
    }
}

test "pairprior: variants parse" {
    const v = try parseVariant("kit:prof:8:shuf+pair:multi+rank:4:0.15");
    try testing.expect(v.kit.?.kind == .prof and v.kit.?.k == 8 and v.kit.?.shuf);
    try testing.expect(v.pair and v.pair_mode == .multi and v.rank == 4 and v.fac_sd == 0.15);
    try testing.expectError(error.BadVariant, parseVariant("kat"));
}
