//! The Your games list (games.html, unlisted): the example player's list
//! (yourgame.list_path) as ui.yourviews.YourViews (the head), ui.yourtime.YourTime (Over
//! time, hidden until chosen) and ui.yourpage.YourList, its rows opening game.html; a
//! URL's id is looked up in its place (ui.yourlookup). Remove my data at the foot
//! (ui.forget)
const std = @import("std");
const ui = @import("ui");
const html = @import("html.zig");
const assets = @import("assets.zig");
const root = @import("root.zig");
const yourgame = @import("yourgame.zig");
const Site = root.Site;

const Writer = std.Io.Writer;
const log = std.log.scoped(.site);

pub const page_path = "/games";

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
    // The lookup's status line above the list; ui-your loads its file for a URL's id
    var look: ui.yourlookup.YourLookup = .{ .js = assets.yourlookup_js.path, .wasm = assets.yourlookup_wasm.path };
    var v: ui.yourviews.YourViews = .{ .l = l, .game = yourgame.page_path };
    var o: ui.yourtime.YourTime = .{ .l = l, .game = yourgame.page_path, .js = assets.yourtime_js.path, .wasm = assets.yourtime_wasm.path };
    var y: ui.yourpage.YourList = .{ .l = l, .bin = enc.encode(bin, f.data), .game = yourgame.page_path };
    var fg: ui.forget.Forget = .{ .js = assets.forget_js.path, .wasm = assets.forget_wasm.path, .ddragon = site.ddragon_version };
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    for ([_]ui.N{ look.view(&h), v.view(&h), o.view(&h), y.view(&h), fg.view(&h) }) |n| {
        if (h.oom) return error.OutOfMemory;
        try ui.html.write(&t, n, w);
    }
    try html.tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\<script src="{vjs}" data-wasm="{vwasm}" defer></script>
        \\
    , .{
        .js = html.Link{ .path = assets.your_js.path },
        .wasm = assets.your_wasm.path,
        .vjs = html.Link{ .path = assets.yourviews_js.path },
        .vwasm = assets.yourviews_wasm.path,
    });
    try html.foot(w, p);
    return true;
}
