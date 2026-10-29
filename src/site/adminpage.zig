//! The new admin page (/admin/new.html, ui.adminpage): an empty shell ui-admin.wasm fills
//! from admin.bin, api/live.bin and /auth/ (the chart tabs: ui.admincharts in
//! ui-admincharts.wasm, Traffic: ui.admintraffic in ui-admintraffic.wasm, Deploys and Logs:
//! ui.adminops in ui-adminops.wasm, Models: ui.adminmodels in ui-adminmodels.wasm, all of
//! which it loads), its stylesheet and code, written into the admin dir beside the old page
//! by `meiolol admin`. Never public: nginx serves /admin/ to view_admin logins only
const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const assets = @import("assets.zig");
const style = @import("style.zig");

const Io = std.Io;

/// What the public stylesheet leaves out (ui.components): it is linked first
pub const css = ui.css.join(.{ ui.alertband, ui.actionbutton, ui.adminpage, ui.timechart, ui.admincharts, ui.admintraffic, ui.steptimeline, ui.logview, ui.adminops, ui.adminmodels });
pub const css_file = assets.hashed("admin.css", css);
pub const js = assets.built("ui-admin.js", @embedFile("ui-admin.js"));
pub const wasm = assets.built("ui-admin.wasm", @embedFile("ui-admin.wasm"));
pub const charts_js = assets.built("ui-admincharts.js", @embedFile("ui-admincharts.js"));
pub const charts_wasm = assets.built("ui-admincharts.wasm", @embedFile("ui-admincharts.wasm"));
pub const traffic_js = assets.built("ui-admintraffic.js", @embedFile("ui-admintraffic.js"));
pub const traffic_wasm = assets.built("ui-admintraffic.wasm", @embedFile("ui-admintraffic.wasm"));
pub const ops_js = assets.built("ui-adminops.js", @embedFile("ui-adminops.js"));
pub const ops_wasm = assets.built("ui-adminops.wasm", @embedFile("ui-adminops.wasm"));
pub const models_js = assets.built("ui-adminmodels.js", @embedFile("ui-adminmodels.js"));
pub const models_wasm = assets.built("ui-adminmodels.wasm", @embedFile("ui-adminmodels.wasm"));

pub fn page(a: std.mem.Allocator) ![]const u8 {
    var p: ui.adminpage.Page = .{};
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const n = p.view(&h);
    var c: ui.admincharts.Charts = .{ .js = charts_js.path, .wasm = charts_wasm.path };
    const cn = c.view(&h);
    var tr: ui.admintraffic.Traffic = .{ .js = traffic_js.path, .wasm = traffic_wasm.path };
    const tn = tr.view(&h);
    var ops: ui.adminops.Ops = .{ .js = ops_js.path, .wasm = ops_wasm.path };
    const on = ops.view(&h);
    var mo: ui.adminmodels.Models = .{ .js = models_js.path, .wasm = models_wasm.path };
    const mn = mo.view(&h);
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
    try ui.html.write(&t, on, w);
    try ui.html.write(&t, mn, w);
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
    for ([_]assets.Hashed{ css_file, js, wasm, charts_js, charts_wasm, traffic_js, traffic_wasm, ops_js, ops_wasm, models_js, models_wasm }) |f| if (std.mem.eql(u8, f.path, name)) return f.data;
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
        .{ ops_js.path, ops_js.data },
        .{ ops_wasm.path, ops_wasm.data },
        .{ models_js.path, models_js.data },
        .{ models_wasm.path, models_wasm.data },
    };
    for (files) |f| {
        try dir.writeFile(io, .{ .sub_path = f[0], .data = f[1] });
        try dir.writeFile(io, .{ .sub_path = try std.mem.concat(a, u8, &.{ f[0], ".gz" }), .data = try store.raw.compress(a, f[1]) });
    }
}
