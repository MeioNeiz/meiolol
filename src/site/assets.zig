//! Front-end files every page or island loads, linked by a name with their content's hash
//! (`search.1a2b3c4d.js`), which nginx serves as immutable for a year (docs/hosting.md).
//! A deploy changes the name, so a browser never revalidates them. The plain names stay
//! too (pages rendered before still link them); the web loop keeps old hashed names a
//! while for pages cached before a deploy
const std = @import("std");
const ui = @import("ui");

pub const Hashed = struct { plain: []const u8, path: []const u8, data: []const u8 };

pub const search_js = hashed("search.js", @embedFile("static/search.js"));
pub const stats_js = hashed("ui-stats.js", @embedFile("ui-stats.js"));
pub const stats_wasm = hashed("ui-stats.wasm", @embedFile("ui-stats.wasm"));
pub const champion_js = hashed("ui-champion.js", @embedFile("ui-champion.js"));
pub const champion_wasm = hashed("ui-champion.wasm", @embedFile("ui-champion.wasm"));
pub const champbuild_js = hashed("ui-champbuild.js", @embedFile("ui-champbuild.js"));
pub const champbuild_wasm = hashed("ui-champbuild.wasm", @embedFile("ui-champbuild.wasm"));
pub const champmore_js = hashed("ui-champmore.js", @embedFile("ui-champmore.js"));
pub const champmore_wasm = hashed("ui-champmore.wasm", @embedFile("ui-champmore.wasm"));

/// `plain` with 8 hex digits of `data`'s FNV-1a before its extension
pub fn hashed(comptime plain: []const u8, comptime data: []const u8) Hashed {
    const dot = comptime std.mem.findScalarLast(u8, plain, '.').?;
    return .{ .plain = plain, .path = comptime plain[0..dot] ++ "." ++ ui.css.version(data) ++ plain[dot..], .data = data };
}

test hashed {
    try std.testing.expectEqualStrings("ui-stats.fd0c5087.js", hashed("ui-stats.js", "x").path);
}
