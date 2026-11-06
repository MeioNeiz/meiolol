//! Meio under a champion page's lock stack, from the lock server (site/locks.zig): the
//! champion page's Meio period at champpage.lockPath's "meio" island
const std = @import("std");
const fmt = @import("fmt.zig");
const Role = @import("role.zig").Role;

/// Meio's number for a cell (src/meio.zig Estimate): p, its 80% range, and the games in
/// the cell's own slice (the newest patch, this region and rank)
pub const Est = struct {
    p: f32,
    lo: f32,
    hi: f32,
    own: u32,

    /// The games a binomial rate at p needs for an 80% range as narrow as this one
    pub fn worth(e: Est) u32 {
        // A branch, not @max: that pulls compiler_rt's fmax into the island
        const w: f64 = (e.hi - e.lo) / 2;
        const half = if (w < 0.0005) 0.0005 else w;
        const p: f64 = e.p;
        const z = 1.2816 / half;
        const n = p * (1 - p) * z * z;
        return if (n > 1e8) 100_000_000 else @intFromFloat(n + 0.5);
    }
};

/// A keystone, finished item or lane opponent beside the lock stack: its games and wins
/// under the stack and the page's view, Meio's number for the stack with it. `gold`:
/// lane gold at 14 against an opponent, under no lock or an opponent lock only
pub const Choice = struct { id: u32, name: []const u8, games: u32, wins: u32, meio: ?Est, gold: ?Est = null };

/// The champion's Meio win rate in a role, no locks (the role tiles)
pub const RoleEst = struct { role: Role, meio: Est };

/// Why Meio has no number for the stack
pub const Gap = enum {
    none,
    /// The renderer has no fitted model (data/export/meio.bin)
    no_model,
    /// Master+: its bracket is wider than the pick, so raw only
    master,
    /// A lock Meio doesn't model (rune page, spells, a core path, ...)
    kind,
    /// More than two locks it models: no three-way terms
    deep,
};

/// Meio under a champion page's lock stack (site/locks.zig meio), at meioPath
pub const Meio = struct {
    gap: Gap,
    /// An item lock counts as built in any slot: the slot isn't modelled
    any_slot: bool,
    /// The stack's games and wins under the page's view
    games: u32,
    wins: u32,
    stack: ?Est,
    /// Lane gold at 14, in gold: under no lock or an opponent lock only
    gold: ?Est,
    keystones: []const Choice,
    items: []const Choice,
    /// Every lane opponent in the view, not cut to the others' length (Matchups)
    opponents: []const Choice,
    /// Each role the model has the champion in; empty with a gap
    roles: []const RoleEst = &.{},
};

/// `lk` as lockanswer.Locks.format writes it, "" for none; `view` html.View's index
pub fn meioPath(a: std.mem.Allocator, view: u8, id: u32, r: Role, rank: []const u8, lk: []const u8) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.writeAll("/private/meio/");
    try fmt.write(w, .int, view);
    try w.writeByte('/');
    try fmt.write(w, .int, id);
    try w.print("/{t}/{s}/{s}.bin", .{ r, rank, if (lk.len == 0) no_locks else lk });
    return out.toOwnedSlice();
}

pub const no_locks = "none";
