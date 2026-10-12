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
