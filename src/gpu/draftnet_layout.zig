//! Shared by the draft net kernels (kernels.zig) and their host (lab/draftnet.zig): shapes,
//! the game row and the dropout mask, so both devices train the same function

pub const emb = 32;
pub const slots = 10;
pub const input = slots * emb;
pub const h1 = 512;
pub const h2 = 256;
pub const keep: f32 = 0.9;

/// Champion-role ids, blue's five by role then red's; y 1 when blue won
pub const Game = extern struct {
    ids: [slots]u32,
    platform: u32,
    y: f32,
};

/// Dropout: whether unit j of batch row i survives at this step and layer. A hash, not an
/// RNG stream, so CPU and GPU drop the same units whatever the thread order
pub fn kept(seed: u32, step: u32, layer: u32, i: u32, j: u32) bool {
    var h = seed ^ (step *% 0x9e3779b1) ^ (layer *% 0x85ebca77);
    h = (h ^ i) *% 0xc2b2ae3d;
    h = (h ^ (h >> 15) ^ j) *% 0x27d4eb2f;
    h ^= h >> 13;
    h *%= 0x165667b1;
    h ^= h >> 16;
    return @as(f32, @floatFromInt(h >> 8)) < keep * (1 << 24);
}

/// Parameter offsets in the flat array. c and the biases get no weight decay: they come
/// first, decayed from `decay`
pub const Layout = struct {
    c: u32,
    b1: u32,
    b2: u32,
    decay: u32,
    e: u32,
    r: u32,
    w1: u32,
    w2: u32,
    w3: u32,
    len: u32,

    pub fn init(n_ids: u32, n_platforms: u32) Layout {
        var l: Layout = undefined;
        l.c = 0;
        l.b1 = n_platforms;
        l.b2 = l.b1 + h1;
        l.decay = l.b2 + h2;
        l.e = l.decay;
        l.r = l.e + n_ids * emb;
        l.w1 = l.r + 5 * emb;
        l.w2 = l.w1 + h1 * input;
        l.w3 = l.w2 + h2 * h1;
        l.len = l.w3 + h2;
        return l;
    }
};
