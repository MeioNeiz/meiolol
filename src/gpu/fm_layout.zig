//! Data shared by the fm kernels (kernels.zig) and their host (lab/bench.zig): extern so
//! both sides agree byte for byte

/// One training row; fields as fm.Example, widened to u32
pub const Example = extern struct {
    me: u32,
    role: u32,
    platform: u32,
    enemies: [5]u32,
    enemy_roles: [5]u32,
    allies: [4]u32,
    y: f32,
};

/// Offsets of each parameter block in the flat parameter array (fm.Model.p)
pub const Layout = extern struct {
    b: u32,
    pl: u32,
    a: u32,
    g: u32,
    u: u32,
    v: u32,
    w: u32,
    /// fm.Kind as an integer: 0 base, 1 additive, 2 lane, 3 pairwise
    kind: u32,
    dim: u32,
    mu: f32,
};

/// fm.zig's laneMates
pub fn laneMates(mine: u32, theirs: u32) bool {
    return mine == theirs or (mine >= 3 and theirs >= 3);
}

/// fm.Model.predict over the flat parameters
pub fn predict(p: [*]const f32, l: *const Layout, e: *const Example) f32 {
    var s = l.mu + p[l.b + e.me];
    if (l.kind == 0) return s;
    s += p[l.pl + e.platform * 5 + e.role];
    for (e.enemies) |x| s += p[l.a + x * 5 + e.role];
    for (e.allies) |x| s += p[l.g + x * 5 + e.role];
    if (l.kind == 1) return s;
    for (e.enemies, e.enemy_roles) |x, rx| {
        if (l.kind == 2 and !laneMates(e.role, rx)) continue;
        var dot: f32 = 0;
        for (0..l.dim) |k| dot += p[l.u + e.me * l.dim + k] * p[l.v + x * l.dim + k];
        s += p[l.w + e.role * 5 + rx] * dot;
    }
    return s;
}
