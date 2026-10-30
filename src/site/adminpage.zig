//! The admin page (/admin, ui.adminpage): an empty shell ui-admin.wasm fills
//! from admin.bin, api/live.bin and /auth/ (the chart tabs: ui.admincharts in
//! ui-admincharts.wasm, Traffic: ui.admintraffic in ui-admintraffic.wasm, Deploys and Logs:
//! ui.adminops in ui-adminops.wasm, Models: ui.adminmodels in ui-adminmodels.wasm, its nets
//! and campaigns ui.adminlab in ui-adminlab.wasm and its runs ui.adminruns in
//! ui-adminruns.wasm, all of which it loads) with its CSS inline (sheets.zig), and its code,
//! written into the admin dir beside the data by `meiolol admin`. Never public: nginx serves /admin to
//! view_admin logins only
const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const assets = @import("assets.zig");
const csp = @import("csp.zig");
const sheets = @import("sheets.zig");

const Io = std.Io;

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
pub const lab_js = assets.built("ui-adminlab.js", @embedFile("ui-adminlab.js"));
pub const lab_wasm = assets.built("ui-adminlab.wasm", @embedFile("ui-adminlab.wasm"));
pub const runs_js = assets.built("ui-adminruns.js", @embedFile("ui-adminruns.js"));
pub const runs_wasm = assets.built("ui-adminruns.wasm", @embedFile("ui-adminruns.wasm"));

/// Absolute: the page is /admin, where a relative path would resolve at /
fn at(comptime f: assets.Hashed) []const u8 {
    return "/admin/" ++ f.path;
}

pub fn page(a: std.mem.Allocator) ![]const u8 {
    var p: ui.adminpage.Page = .{};
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const n = p.view(&h);
    var c: ui.admincharts.Charts = .{ .js = at(charts_js), .wasm = at(charts_wasm) };
    const cn = c.view(&h);
    var tr: ui.admintraffic.Traffic = .{ .js = at(traffic_js), .wasm = at(traffic_wasm) };
    const tn = tr.view(&h);
    var ops: ui.adminops.Ops = .{ .js = at(ops_js), .wasm = at(ops_wasm) };
    const on = ops.view(&h);
    var mo: ui.adminmodels.Models = .{ .js = at(models_js), .wasm = at(models_wasm) };
    const mn = mo.view(&h);
    var la: ui.adminlab.Lab = .{ .js = at(lab_js), .wasm = at(lab_wasm) };
    const ln = la.view(&h);
    var ru: ui.adminruns.Runs = .{ .js = at(runs_js), .wasm = at(runs_wasm) };
    const rn = ru.view(&h);
    if (h.oom) return error.OutOfMemory;
    var out: Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\{s}<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="robots" content="noindex">
        \\<title>meiolol admin</title>
        \\<link rel="icon" href="/favicon.svg" type="image/svg+xml">
        \\{s}
        \\</head>
        \\<body class="ui">
        \\<main class="c-sitemain">
        \\
    , .{ csp.files_only, sheets.slot });
    try ui.html.write(&t, n, w);
    try ui.html.write(&t, cn, w);
    try ui.html.write(&t, tn, w);
    try ui.html.write(&t, on, w);
    try ui.html.write(&t, mn, w);
    try ui.html.write(&t, ln, w);
    try ui.html.write(&t, rn, w);
    try w.print(
        \\
        \\</main>
        \\<script src="/admin/{s}" data-wasm="/admin/{s}" defer></script>
        \\</body>
        \\</html>
        \\
    , .{ js.path, wasm.path });
    return sheets.deliverWith(a, out.written(), &islands);
}

const islands = [_]assets.Hashed{ js, wasm, charts_js, charts_wasm, traffic_js, traffic_wasm, ops_js, ops_wasm, models_js, models_wasm, lab_js, lab_wasm, runs_js, runs_wasm };

/// One of the page's files by its name under /admin/ (the dev server)
pub fn file(name: []const u8) ?[]const u8 {
    for (islands) |f| if (std.mem.eql(u8, f.path, name)) return f.data;
    return null;
}

/// /admin/new, the page's URL while it was a preview, for bookmarks of it
const moved =
    \\<!DOCTYPE html><html lang="en-GB"><meta charset="utf-8">
    \\<meta name="robots" content="noindex"><meta http-equiv="refresh" content="0; url=/admin">
    \\<title>Admin</title><a href="/admin">Admin</a>
    \\
;

/// index.html and its code into `out_dir`, each with a .gz (gzip_static)
pub fn write(gpa: std.mem.Allocator, io: Io, out_dir: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var dir = try Io.Dir.cwd().openDir(io, out_dir, .{});
    defer dir.close(io);
    const files = [_]struct { []const u8, []const u8 }{
        .{ "index.html", try page(a) },
        .{ "new.html", moved },
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
        .{ lab_js.path, lab_js.data },
        .{ lab_wasm.path, lab_wasm.data },
        .{ runs_js.path, runs_js.data },
        .{ runs_wasm.path, runs_wasm.data },
    };
    for (files) |f| {
        try dir.writeFile(io, .{ .sub_path = f[0], .data = f[1] });
        try dir.writeFile(io, .{ .sub_path = try std.mem.concat(a, u8, &.{ f[0], ".gz" }), .data = try store.raw.compress(a, f[1]) });
    }
}

test "page: its CSS inline, allowed by its CSP" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const p = try page(arena.allocator());
    try std.testing.expect(std.mem.find(u8, p, "stylesheet") == null);
    try csp.check(p);
}
