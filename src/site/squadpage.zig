//! Squads (/squad): ui.squad.Squad's start view; its island loads the squad named by
//! the fragment (#s=TOKEN, the invite link's secret, so never in a request for the
//! page). Never indexed and not in the sitemap: a squad's page is for its link's holders
const std = @import("std");
const ui = @import("ui");
const html = @import("html.zig");
const shell = @import("shell.zig");
const assets = @import("assets.zig");
const root = @import("root.zig");
const Site = root.Site;

const Writer = std.Io.Writer;

pub fn writePage(site: *const Site, w: *Writer) !void {
    const a = site.arena;
    var p = try site.sharedPage("Squads | meiolol", "Friends who join a squad see the games they played together.", .squad);
    p.index = false;
    try shell.open(w, p);
    var s: ui.squad.Squad = .{ .action = .create, .js = assets.squad_js.path, .wasm = assets.squad_wasm.path, .ddragon = site.ddragon_version };
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const n = s.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, n, w);
    try html.tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{ .js = html.Link{ .path = assets.squad_js.path }, .wasm = assets.squad_wasm.path });
    try shell.close(w, p);
}
