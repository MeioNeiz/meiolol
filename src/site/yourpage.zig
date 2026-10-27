//! The Your games list (games.html, unlisted): the example player's list
//! (yourgame.list_path) as ui.yourpage.YourList, its rows opening game.html
const std = @import("std");
const ui = @import("ui");
const html = @import("html.zig");
const assets = @import("assets.zig");
const root = @import("root.zig");
const yourgame = @import("yourgame.zig");
const Site = root.Site;

const Writer = std.Io.Writer;
const log = std.log.scoped(.site);

pub const page_path = "games.html";

/// False without the example's list
pub fn writePage(site: *const Site, w: *Writer) !bool {
    const f = for (site.daily_files) |x| {
        if (std.mem.eql(u8, x.path, yourgame.list_path)) break x;
    } else return false;
    const a = site.arena;
    const l = try a.create(ui.yourlist.List);
    l.* = ui.data.decode(a, ui.yourlist.List, f.data) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            log.warn("{s}: {t}", .{ f.path, err });
            return false;
        },
    };
    var p = try site.sharedPage("Your games | meiolol", "Your recent ranked games day by day: the result, your lane at 14 minutes and the win chance through each game, with your champions and roles beside them.", .your);
    p.index = false;
    try html.head(w, p);
    const enc = std.base64.standard.Encoder;
    const bin = try a.alloc(u8, enc.calcSize(f.data.len));
    var y: ui.yourpage.YourList = .{ .l = l, .bin = enc.encode(bin, f.data), .game = yourgame.page_path };
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    t.root = y.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    try html.tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{
        .js = html.Link{ .root = "", .path = assets.your_js.path },
        .wasm = assets.your_wasm.path,
    });
    try html.foot(w, p);
    return true;
}
