//! The new admin page (/admin/new.html, ui.adminpage): an empty shell ui-admin.wasm fills
//! from admin.bin, api/live.bin and /auth/ (the chart tabs: ui.admincharts in
//! ui-admincharts.wasm, Traffic: ui.admintraffic in ui-admintraffic.wasm, both of which
//! it loads), its stylesheet and code, written into the admin dir beside the old page by
//! `meiolol admin`. Never public: nginx serves /admin/ to view_admin logins only
const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const assets = @import("assets.zig");
const style = @import("style.zig");

const Io = std.Io;

/// What the public stylesheet leaves out (ui.components): it is linked first
pub const css = ui.css.join(.{ ui.alertband, ui.actionbutton, ui.adminpage, ui.timechart, ui.admincharts, ui.admintraffic });
pub const css_file = assets.hashed("admin.css", css);
pub const js = assets.hashed("ui-admin.js", @embedFile("ui-admin.js"));
pub const wasm = assets.hashed("ui-admin.wasm", @embedFile("ui-admin.wasm"));
pub const charts_js = assets.hashed("ui-admincharts.js", @embedFile("ui-admincharts.js"));
pub const charts_wasm = assets.hashed("ui-admincharts.wasm", @embedFile("ui-admincharts.wasm"));
pub const traffic_js = assets.hashed("ui-admintraffic.js", @embedFile("ui-admintraffic.js"));
pub const traffic_wasm = assets.hashed("ui-admintraffic.wasm", @embedFile("ui-admintraffic.wasm"));

pub fn page(a: std.mem.Allocator) ![]const u8 {
    var p: ui.adminpage.Page = .{};
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const n = p.view(&h);
    var c: ui.admincharts.Charts = .{ .js = charts_js.path, .wasm = charts_wasm.path };
    const cn = c.view(&h);
    var tr: ui.admintraffic.Traffic = .{ .js = traffic_js.path, .wasm = traffic_wasm.path };
    const tn = tr.view(&h);
    if (h.oom) return error.OutOfMemory;
    var out: Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="robots" content="noindex">
        \\<title>meiolol admin</title>
        \\<link rel="icon" href="/favicon.svg" type="image/svg+xml">
        \\<link rel="stylesheet" href="/{s}">
        \\<link rel="stylesheet" href="{s}">
        \\</head>
        \\<body>
        \\<main class="wrap">
        \\
    , .{ style.file.path, css_file.path });
    try ui.html.write(&t, n, w);
    try ui.html.write(&t, cn, w);
    try ui.html.write(&t, tn, w);
    try w.print(
        \\
        \\</main>
        \\<script src="{s}" data-wasm="{s}" defer></script>
        \\</body>
        \\</html>
        \\
    , .{ js.path, wasm.path });
    return out.written();
}

/// One of the page's files by its name under /admin/ (the dev server)
pub fn file(name: []const u8) ?[]const u8 {
    for ([_]assets.Hashed{ css_file, js, wasm, charts_js, charts_wasm, traffic_js, traffic_wasm }) |f| if (std.mem.eql(u8, f.path, name)) return f.data;
    return null;
}

/// new.html, its stylesheet and code into `out_dir`, each with a .gz (gzip_static)
pub fn write(gpa: std.mem.Allocator, io: Io, out_dir: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var dir = try Io.Dir.cwd().openDir(io, out_dir, .{});
    defer dir.close(io);
    const files = [_]struct { []const u8, []const u8 }{
        .{ "new.html", try page(a) },
        .{ css_file.path, css_file.data },
        .{ js.path, js.data },
        .{ wasm.path, wasm.data },
        .{ charts_js.path, charts_js.data },
        .{ charts_wasm.path, charts_wasm.data },
        .{ traffic_js.path, traffic_js.data },
        .{ traffic_wasm.path, traffic_wasm.data },
    };
    for (files) |f| {
        try dir.writeFile(io, .{ .sub_path = f[0], .data = f[1] });
        try dir.writeFile(io, .{ .sub_path = try std.mem.concat(a, u8, &.{ f[0], ".gz" }), .data = try store.raw.compress(a, f[1]) });
    }
}
