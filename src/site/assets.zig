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
pub const matchup_js = hashed("ui-matchup.js", @embedFile("ui-matchup.js"));
pub const matchup_wasm = hashed("ui-matchup.wasm", @embedFile("ui-matchup.wasm"));
pub const matchmore_js = hashed("ui-matchmore.js", @embedFile("ui-matchmore.js"));
pub const matchmore_wasm = hashed("ui-matchmore.wasm", @embedFile("ui-matchmore.wasm"));
pub const games_js = hashed("ui-games.js", @embedFile("ui-games.js"));
pub const games_wasm = hashed("ui-games.wasm", @embedFile("ui-games.wasm"));
pub const gamemore_js = hashed("ui-gamemore.js", @embedFile("ui-gamemore.js"));
pub const gamemore_wasm = hashed("ui-gamemore.wasm", @embedFile("ui-gamemore.wasm"));
pub const gamelane_js = hashed("ui-gamelane.js", @embedFile("ui-gamelane.js"));
pub const gamelane_wasm = hashed("ui-gamelane.wasm", @embedFile("ui-gamelane.wasm"));
pub const finder_js = hashed("ui-finder.js", @embedFile("ui-finder.js"));
pub const finder_wasm = hashed("ui-finder.wasm", @embedFile("ui-finder.wasm"));
pub const findergrid_js = hashed("ui-findergrid.js", @embedFile("ui-findergrid.js"));
pub const findergrid_wasm = hashed("ui-findergrid.wasm", @embedFile("ui-findergrid.wasm"));
pub const learn_js = hashed("ui-learn.js", @embedFile("ui-learn.js"));
pub const learn_wasm = hashed("ui-learn.wasm", @embedFile("ui-learn.wasm"));
pub const patch_js = hashed("ui-patch.js", @embedFile("ui-patch.js"));
pub const patch_wasm = hashed("ui-patch.wasm", @embedFile("ui-patch.wasm"));
pub const pool_js = hashed("ui-pool.js", @embedFile("ui-pool.js"));
pub const pool_wasm = hashed("ui-pool.wasm", @embedFile("ui-pool.wasm"));

/// `plain` with 8 hex digits of `data`'s FNV-1a before its extension
pub fn hashed(comptime plain: []const u8, comptime data: []const u8) Hashed {
    const dot = comptime std.mem.findScalarLast(u8, plain, '.').?;
    return .{ .plain = plain, .path = comptime plain[0..dot] ++ "." ++ ui.css.version(data) ++ plain[dot..], .data = data };
}

test hashed {
    try std.testing.expectEqualStrings("ui-stats.fd0c5087.js", hashed("ui-stats.js", "x").path);
}
