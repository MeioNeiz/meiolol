//! Histogram gradient boosting for a binary outcome on dense features (lab/stack.zig's
//! tree row): depth-limited trees on quantile bins, Newton leaf values with L2, log loss,
//! fitted on a margin offset so the trees only add to it. Rows are row-major f64
//! features; NaN goes to its own bin (left of every split)

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Options = struct {
    depth: u8 = 3,
    rate: f64 = 0.05,
    max_trees: u32 = 300,
    /// Stop when validation log loss hasn't improved for this many trees
    patience: u32 = 30,
    min_hess: f64 = 50,
    lambda: f64 = 1,
    bins: u8 = 32,
};

const Node = struct {
    feature: u32 = 0,
    /// Bin index: rows with bin <= split go left
    split: u8 = 0,
    leaf: bool = true,
    value: f64 = 0,
};

pub const Model = struct {
    k: usize,
    /// Per feature: bin upper edges (bins - 1 of them), ascending
    edges: []f64,
    n_edges: usize,
    /// Trees as complete binary trees of 2^(depth+1) - 1 nodes
    nodes: []Node,
    depth: u8,
    trees: usize,
    rate: f64,

    pub fn deinit(m: *Model, gpa: Allocator) void {
        gpa.free(m.edges);
        gpa.free(m.nodes);
    }

    fn binOf(m: *const Model, f: usize, x: f64) u8 {
        if (std.math.isNan(x)) return 0;
        const e = m.edges[f * m.n_edges ..][0..m.n_edges];
        var b: u8 = 1;
        for (e) |v| {
            if (x <= v) break;
            b += 1;
        }
        return b;
    }

    /// Tree t's leaf value for one row, before the learning rate
    fn leafValue(m: *const Model, row: []const f64, t: usize) f64 {
        const per = treeSize(m.depth);
        const nodes = m.nodes[t * per ..][0..per];
        var i: usize = 0;
        while (!nodes[i].leaf) {
            const b = m.binOf(nodes[i].feature, row[nodes[i].feature]);
            i = 2 * i + @as(usize, if (b <= nodes[i].split) 1 else 2);
        }
        return nodes[i].value;
    }

    /// The trees' summed margin for one row (offset not included)
    pub fn margin(m: *const Model, row: []const f64) f64 {
        var s: f64 = 0;
        for (0..m.trees) |t| s += m.rate * m.leafValue(row, t);
        return s;
    }
};

fn treeSize(depth: u8) usize {
    return (@as(usize, 1) << @intCast(depth + 1)) - 1;
}

fn sigmoid(z: f64) f64 {
    return 1 / (1 + @exp(-z));
}

/// Fits on (x, y, offset); with validation rows, keeps the tree count that minimised their
/// log loss (patience trees past it), else all max_trees
pub fn fit(gpa: Allocator, x: []const f64, y: []const f64, offset: []const f64, k: usize, val: ?struct { x: []const f64, y: []const f64, offset: []const f64 }, o: Options) !Model {
    const n = y.len;
    const n_edges: usize = o.bins - 1;
    var m: Model = .{
        .k = k,
        .edges = try gpa.alloc(f64, k * n_edges),
        .n_edges = n_edges,
        .nodes = try gpa.alloc(Node, o.max_trees * treeSize(o.depth)),
        .depth = o.depth,
        .trees = 0,
        .rate = o.rate,
    };
    errdefer m.deinit(gpa);

    // Quantile edges per feature from the fit rows
    const col = try gpa.alloc(f64, n);
    defer gpa.free(col);
    for (0..k) |f| {
        var c: usize = 0;
        for (0..n) |i| if (!std.math.isNan(x[i * k + f])) {
            col[c] = x[i * k + f];
            c += 1;
        };
        std.mem.sort(f64, col[0..c], {}, std.sort.asc(f64));
        for (0..n_edges) |e| m.edges[f * n_edges + e] = if (c == 0) 0 else col[@min(c - 1, (e + 1) * c / o.bins)];
    }
    const bins = try gpa.alloc(u8, n * k);
    defer gpa.free(bins);
    for (0..n) |i| for (0..k) |f| {
        bins[i * k + f] = m.binOf(f, x[i * k + f]);
    };

    const marg = try gpa.alloc(f64, n);
    defer gpa.free(marg);
    @memcpy(marg, offset);
    const g = try gpa.alloc(f64, n);
    defer gpa.free(g);
    const h = try gpa.alloc(f64, n);
    defer gpa.free(h);
    const node_of = try gpa.alloc(u32, n);
    defer gpa.free(node_of);

    const vn = if (val) |v| v.y.len else 0;
    const vmarg = try gpa.alloc(f64, vn);
    defer gpa.free(vmarg);
    if (val) |v| @memcpy(vmarg, v.offset);
    var best_loss = std.math.inf(f64);
    var best_trees: usize = 0;

    // Bin 0 is NaN, then one per edge gap
    const n_bins: usize = @as(usize, o.bins) + 1;
    const hist_g = try gpa.alloc(f64, k * n_bins);
    defer gpa.free(hist_g);
    const hist_h = try gpa.alloc(f64, k * n_bins);
    defer gpa.free(hist_h);
    const per = treeSize(o.depth);

    for (0..o.max_trees) |t| {
        for (0..n) |i| {
            const p = sigmoid(marg[i]);
            g[i] = p - y[i];
            h[i] = @max(p * (1 - p), 1e-6);
        }
        const nodes = m.nodes[t * per ..][0..per];
        @memset(nodes, .{});
        @memset(node_of, 0);
        // Grow level by level; a node's rows are those with node_of == its index
        for (0..per) |ni| {
            const level = std.math.log2_int(usize, ni + 1);
            var gs: f64 = 0;
            var hs: f64 = 0;
            for (0..n) |i| if (node_of[i] == ni) {
                gs += g[i];
                hs += h[i];
            };
            nodes[ni].value = -gs / (hs + o.lambda);
            if (level == o.depth or hs < 2 * o.min_hess) continue;
            @memset(hist_g, 0);
            @memset(hist_h, 0);
            for (0..n) |i| if (node_of[i] == ni) {
                for (0..k) |f| {
                    const b = bins[i * k + f];
                    hist_g[f * n_bins + b] += g[i];
                    hist_h[f * n_bins + b] += h[i];
                }
            };
            const parent = gs * gs / (hs + o.lambda);
            var best_gain: f64 = 0;
            for (0..k) |f| {
                var gl: f64 = 0;
                var hl: f64 = 0;
                for (0..n_bins - 1) |b| {
                    gl += hist_g[f * n_bins + b];
                    hl += hist_h[f * n_bins + b];
                    const hr = hs - hl;
                    if (hl < o.min_hess or hr < o.min_hess) continue;
                    const gr = gs - gl;
                    const gain = gl * gl / (hl + o.lambda) + gr * gr / (hr + o.lambda) - parent;
                    if (gain > best_gain) {
                        best_gain = gain;
                        nodes[ni].feature = @intCast(f);
                        nodes[ni].split = @intCast(b);
                        nodes[ni].leaf = false;
                    }
                }
            }
            if (nodes[ni].leaf) continue;
            for (0..n) |i| if (node_of[i] == ni) {
                const left = bins[i * k + nodes[ni].feature] <= nodes[ni].split;
                node_of[i] = @intCast(2 * ni + @as(usize, if (left) 1 else 2));
            };
        }
        for (0..n) |i| marg[i] += o.rate * nodes[node_of[i]].value;
        m.trees = t + 1;

        if (val) |v| {
            var loss: f64 = 0;
            for (0..vn) |i| {
                vmarg[i] += m.rate * m.leafValue(v.x[i * k ..][0..k], t);
                const p = std.math.clamp(sigmoid(vmarg[i]), 1e-6, 1 - 1e-6);
                loss -= v.y[i] * @log(p) + (1 - v.y[i]) * @log(1 - p);
            }
            if (loss < best_loss) {
                best_loss = loss;
                best_trees = t + 1;
            } else if (t + 1 - best_trees >= o.patience) break;
        }
    }
    if (val != null) m.trees = best_trees;
    return m;
}

test "gbdt learns a step on top of an offset" {
    const gpa = std.testing.allocator;
    const n = 4000;
    var x: [n]f64 = undefined;
    var y: [n]f64 = undefined;
    var off: [n]f64 = undefined;
    var prng = std.Random.DefaultPrng.init(3);
    const rnd = prng.random();
    for (&x, &y, &off) |*a, *b, *c| {
        a.* = rnd.float(f64);
        c.* = 0;
        b.* = if (rnd.float(f64) < (if (a.* > 0.5) @as(f64, 0.8) else 0.2)) 1 else 0;
    }
    var m = try fit(gpa, &x, &y, &off, 1, null, .{ .max_trees = 100, .rate = 0.2 });
    defer m.deinit(gpa);
    try std.testing.expect(sigmoid(m.margin(&.{0.9})) > 0.7);
    try std.testing.expect(sigmoid(m.margin(&.{0.1})) < 0.3);
}
