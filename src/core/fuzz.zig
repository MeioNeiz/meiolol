//! Inputs for fuzz tests (std.testing.fuzz): `zig build test` runs each once, `zig build
//! desktop-fuzz --fuzz=N` searches (deploy/desktop-release.sh)

const std = @import("std");

/// A copy of `valid` with a few bytes changed and maybe cut short. Starting from a good
/// file gets past the magic and version checks, which random bytes almost never do
pub fn mutate(s: *std.testing.Smith, arena: std.mem.Allocator, valid: []const u8) ![]u8 {
    var out = try arena.dupe(u8, valid);
    if (out.len == 0) return out;
    for (0..s.valueRangeAtMost(u8, 0, 8)) |_| {
        const at = s.index(out.len);
        out[at] = switch (s.valueRangeAtMost(u8, 0, 3)) {
            0 => s.value(u8),
            1 => out[at] +% 1,
            2 => 0xff,
            else => 0,
        };
    }
    if (s.boolWeighted(7, 1)) return out;
    return out[0..s.index(out.len)];
}
