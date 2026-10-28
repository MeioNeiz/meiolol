//! /learn: Learn (ui.learnpage), chapters of puzzles (learnbuild.zig) in the island's
//! data-bin. Rendered on request, so a hand edit of learnfixed.zig is live after a deploy
const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const assets = @import("assets.zig");
const learnbuild = @import("learnbuild.zig");
const ui = @import("ui");
const ld = ui.learndata;

const Writer = std.Io.Writer;
const Site = root.Site;
const tpl = html.tpl;

pub fn write(site: *const Site, w: *Writer) !void {
    const a = site.arena;
    const p = try site.sharedPage(
        "Learn from real games | meiolol",
        "League of Legends puzzles from real ranked games: guess, then see the numbers.",
        .learn,
    );
    try html.head(w, p);
    const d = try a.create(ld.Data);
    d.* = try learnbuild.data(site);
    var page: ui.learnpage.Page = .init(a, d);
    page.bin = try bin(a, d.*);
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    t.root = page.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    try tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{ .js = html.Link{ .path = assets.learn_js.path }, .wasm = assets.learn_wasm.path });
    try html.foot(w, p);
}

/// `v` as ui.data, base64: the island root's data-bin
fn bin(a: std.mem.Allocator, v: ld.Data) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, ld.Data, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
}
