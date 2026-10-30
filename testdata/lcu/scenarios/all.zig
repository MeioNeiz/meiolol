//! Every scenario embedded, for the app review pages (src/site/appreview.zig; build.zig
//! gives the backend this file as `scenarios`). A new scenario goes here too, in the
//! order the review index lists them
pub const champions = @embedFile("champions.json");

pub const list = [_]struct { []const u8, []const u8 }{
    .{ "full-game", @embedFile("full-game.json") },
    .{ "laner-locked-first", @embedFile("laner-locked-first.json") },
    .{ "trade", @embedFile("trade.json") },
    .{ "dodge", @embedFile("dodge.json") },
    .{ "blind-normal", @embedFile("blind-normal.json") },
    .{ "aram", @embedFile("aram.json") },
};
