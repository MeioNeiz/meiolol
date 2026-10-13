//! Device code: built for nvptx64-cuda to PTX by build.zig and embedded in meiolol-lab

fn special(comptime reg: []const u8) u32 {
    return asm ("mov.u32 %[r], %" ++ reg ++ ";"
        : [r] "=r" (-> u32),
    );
}

fn globalId() u32 {
    return special("ctaid.x") * special("ntid.x") + special("tid.x");
}

export fn vadd(a: [*]const f32, b: [*]const f32, c: [*]f32, n: u32) callconv(.kernel) void {
    const i = globalId();
    if (i < n) c[i] = a[i] + b[i];
}

const fm = @import("fm_layout.zig");

fn atomicAdd(p: *f32, v: f32) void {
    _ = @atomicRmw(f32, p, .Add, v, .monotonic);
}

/// Gradient of squared loss / 2 for rows order[start..start+count], added into gr with
/// atomics (fm.Model.grad)
export fn fm_grad(
    p: [*]const f32,
    gr: [*]f32,
    ex: [*]const fm.Example,
    order: [*]const u32,
    start: u32,
    count: u32,
    l: *const fm.Layout,
) callconv(.kernel) void {
    const i = globalId();
    if (i >= count) return;
    const e = &ex[order[start + i]];
    const r = fm.predict(p, l, e) - e.y;
    atomicAdd(&gr[l.b + e.me], r);
    if (l.kind == 0) return;
    atomicAdd(&gr[l.pl + e.platform * 5 + e.role], r);
    for (e.enemies) |x| atomicAdd(&gr[l.a + x * 5 + e.role], r);
    for (e.allies) |x| atomicAdd(&gr[l.g + x * 5 + e.role], r);
    if (l.kind == 1) return;
    for (e.enemies, e.enemy_roles) |x, rx| {
        if (l.kind == 2 and !fm.laneMates(e.role, rx)) continue;
        const wi = l.w + e.role * 5 + rx;
        var dot: f32 = 0;
        for (0..l.dim) |k| dot += p[l.u + e.me * l.dim + k] * p[l.v + x * l.dim + k];
        atomicAdd(&gr[wi], r * dot);
        const wr = r * p[wi];
        for (0..l.dim) |k| {
            atomicAdd(&gr[l.u + e.me * l.dim + k], wr * p[l.v + x * l.dim + k]);
            atomicAdd(&gr[l.v + x * l.dim + k], wr * p[l.u + e.me * l.dim + k]);
        }
    }
}

/// Adam with L2 over all n parameters (fm.fit's update)
export fn fm_adam(
    p: [*]f32,
    gr: [*]const f32,
    m1: [*]f32,
    m2: [*]f32,
    n: u32,
    lr: f32,
    l2: f32,
    scale: f32,
    c1: f32,
    c2: f32,
) callconv(.kernel) void {
    const i = globalId();
    if (i >= n) return;
    const b1: f32 = 0.9;
    const b2: f32 = 0.999;
    const g = gr[i] * scale + l2 * p[i];
    m1[i] = b1 * m1[i] + (1 - b1) * g;
    m2[i] = b2 * m2[i] + (1 - b2) * g * g;
    p[i] -= lr * (m1[i] / c1) / (@sqrt(m2[i] / c2) + 1e-8);
}

const dn = @import("draftnet_layout.zig");

/// e^x: the backend has no exp libcall, so PTX's base-2 exponential
fn exp(x: f32) f32 {
    return asm ("ex2.approx.f32 %[r], %[a];"
        : [r] "=f" (-> f32),
        : [a] "f" (x * 1.4426950408889634),
    );
}

fn barrier() void {
    asm volatile ("bar.sync 0;" ::: .{ .memory = true });
}

const tile_m = 64;
const tile_n = 64;
const tile_k = 16;
var tile_a: [tile_k][tile_m]f32 addrspace(.shared) = undefined;
var tile_b: [tile_k][tile_n]f32 addrspace(.shared) = undefined;

/// c[i*n + j] = sum over l of a[i*sai + l*sak] * b[l*sbk + j*sbj], for i < m, j < n, l < k.
/// Strides give every transpose the draft net needs. 256 threads per 64x64 tile of c,
/// 4x4 outputs each; grid (ceil(n/64), ceil(m/64))
export fn gemm(
    a: [*]const f32,
    b: [*]const f32,
    c: [*]f32,
    m: u32,
    n: u32,
    k: u32,
    sai: u32,
    sak: u32,
    sbk: u32,
    sbj: u32,
) callconv(.kernel) void {
    const t = special("tid.x");
    const bi = special("ctaid.y") * tile_m;
    const bj = special("ctaid.x") * tile_n;
    const ty = t / 16;
    const tx = t % 16;
    var acc: [4][4]f32 = @splat(@splat(0));
    var k0: u32 = 0;
    while (k0 < k) : (k0 += tile_k) {
        for (0..4) |r| {
            const e = t + @as(u32, @intCast(r)) * 256;
            const ii = e / tile_k;
            const kk = e % tile_k;
            const gi = bi + ii;
            const gk = k0 + kk;
            tile_a[kk][ii] = if (gi < m and gk < k) a[gi * sai + gk * sak] else 0;
            const jj = e % tile_n;
            const kb = e / tile_n;
            const gj = bj + jj;
            const gkb = k0 + kb;
            tile_b[kb][jj] = if (gj < n and gkb < k) b[gkb * sbk + gj * sbj] else 0;
        }
        barrier();
        inline for (0..tile_k) |kk| {
            var av: [4]f32 = undefined;
            var bv: [4]f32 = undefined;
            for (0..4) |x| {
                av[x] = tile_a[kk][ty * 4 + x];
                bv[x] = tile_b[kk][tx * 4 + x];
            }
            for (0..4) |x| for (0..4) |y| {
                acc[x][y] = @mulAdd(f32, av[x], bv[y], acc[x][y]);
            };
        }
        barrier();
    }
    for (0..4) |x| for (0..4) |y| {
        const i = bi + ty * 4 + @as(u32, @intCast(x));
        const j = bj + tx * 4 + @as(u32, @intCast(y));
        if (i < m and j < n) c[i * n + j] = acc[x][y];
    };
}

/// Batch row i (game order[start + i/2]; odd rows swap the sides) of the net's input:
/// each slot's champion-role embedding plus its role's
export fn dn_gather(
    p: [*]const f32,
    games: [*]const dn.Game,
    order: [*]const u32,
    start: u32,
    rows: u32,
    e_off: u32,
    r_off: u32,
    x: [*]f32,
) callconv(.kernel) void {
    const t = globalId();
    if (t >= rows * dn.input) return;
    const i = t / dn.input;
    const col = t % dn.input;
    const slot = col / dn.emb;
    const kk = col % dn.emb;
    const g = &games[order[start + i / 2]];
    const src = if (i % 2 == 1) (slot + 5) % 10 else slot;
    x[t] = p[e_off + g.ids[src] * dn.emb + kk] + p[r_off + (slot % 5) * dn.emb + kk];
}

/// z += bias; h = relu(z) through dropout (layer 1 or 2); dropout off when seed is 0
export fn dn_act(
    z: [*]f32,
    p: [*]const f32,
    b_off: u32,
    h: [*]f32,
    rows: u32,
    n: u32,
    seed: u32,
    step: u32,
    layer: u32,
) callconv(.kernel) void {
    const t = globalId();
    if (t >= rows * n) return;
    const j = t % n;
    const v = z[t] + p[b_off + j];
    z[t] = v;
    h[t] = if (v > 0 and (seed == 0 or dn.kept(seed, step, layer, t / n, j)))
        v / (if (seed == 0) 1 else dn.keep)
    else
        0;
}

/// Logistic loss per game on the antisymmetric logit (f(blue, red) - f(red, blue)) / 2
/// plus the platform's intercept: df for both rows, and c's gradient into gr
export fn dn_loss(
    f: [*]const f32,
    p: [*]const f32,
    games: [*]const dn.Game,
    order: [*]const u32,
    start: u32,
    count: u32,
    c_off: u32,
    a_off: u32,
    df: [*]f32,
    gr: [*]f32,
) callconv(.kernel) void {
    const g = globalId();
    if (g >= count) return;
    const game = &games[order[start + g]];
    const logit = (f[2 * g] - f[2 * g + 1]) / 2 + p[c_off + game.platform] + p[a_off] * game.off;
    const dl = (1 / (1 + exp(-logit)) - game.y) / @as(f32, @floatFromInt(count));
    df[2 * g] = dl / 2;
    df[2 * g + 1] = -dl / 2;
    atomicAdd(&gr[c_off + game.platform], dl);
    if (game.off != 0) atomicAdd(&gr[a_off], dl * game.off);
}

/// dh becomes dz: through relu and the same dropout as dn_act
export fn dn_actback(dh: [*]f32, z: [*]const f32, rows: u32, n: u32, seed: u32, step: u32, layer: u32) callconv(.kernel) void {
    const t = globalId();
    if (t >= rows * n) return;
    dh[t] = if (z[t] > 0 and dn.kept(seed, step, layer, t / n, t % n)) dh[t] / dn.keep else 0;
}

/// out[j] = sum over rows of dz[i, j] (a bias gradient)
export fn dn_colsum(dz: [*]const f32, rows: u32, n: u32, out: [*]f32) callconv(.kernel) void {
    const j = globalId();
    if (j >= n) return;
    var s: f32 = 0;
    for (0..rows) |i| s += dz[i * n + j];
    out[j] = s;
}

/// The input's gradient back into the embeddings it was gathered from
export fn dn_scatter(
    dx: [*]const f32,
    games: [*]const dn.Game,
    order: [*]const u32,
    start: u32,
    rows: u32,
    e_off: u32,
    r_off: u32,
    gr: [*]f32,
) callconv(.kernel) void {
    const t = globalId();
    if (t >= rows * dn.input) return;
    const i = t / dn.input;
    const col = t % dn.input;
    const slot = col / dn.emb;
    const kk = col % dn.emb;
    const g = &games[order[start + i / 2]];
    const src = if (i % 2 == 1) (slot + 5) % 10 else slot;
    atomicAdd(&gr[e_off + g.ids[src] * dn.emb + kk], dx[t]);
    atomicAdd(&gr[r_off + (slot % 5) * dn.emb + kk], dx[t]);
}

/// AdamW: decoupled weight decay on parameters from decay_from on
export fn dn_adamw(
    p: [*]f32,
    gr: [*]const f32,
    m1: [*]f32,
    m2: [*]f32,
    n: u32,
    lr: f32,
    wd: f32,
    decay_from: u32,
    c1: f32,
    c2: f32,
) callconv(.kernel) void {
    const i = globalId();
    if (i >= n) return;
    const g = gr[i];
    m1[i] = 0.9 * m1[i] + 0.1 * g;
    m2[i] = 0.999 * m2[i] + 0.001 * g * g;
    const decay: f32 = if (i >= decay_from) wd * p[i] else 0;
    p[i] -= lr * ((m1[i] / c1) / (@sqrt(m2[i] / c2) + 1e-8) + decay);
}
