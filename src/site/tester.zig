//! The new Draft tester page (/private/tester, ui.testerpage and ui.testercand): its HTML
//! with the champion list and its CSS inline (sheets.zig), ui-tester.wasm and the candidate panel's
//! ui-testercand.wasm (which ui-tester.wasm loads), written into the private site's dir
//! beside the old page (admin.private) by `meiolol admin --private-out`. Never public:
//! nginx serves /private to view_private logins only
const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const assets = @import("assets.zig");
const style = @import("style.zig");
const csp = @import("csp.zig");
const sheets = @import("sheets.zig");

const Io = std.Io;
const tp = ui.testerpage;

/// Champion keys, names and the Data Dragon version, from the champions table
pub fn head(a: std.mem.Allocator, db: store.Db) !tp.Head {
    var list: std.ArrayList(tp.Champ) = .empty;
    var version: []const u8 = "";
    var q = try db.prepare("SELECT id, key, name, ddragon_version FROM champions ORDER BY name");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const r = q.row(struct { id: u32, key: []const u8, name: []const u8, ddragon_version: []const u8 });
        try list.append(a, .{ .id = r.id, .key = try a.dupe(u8, r.key), .name = try a.dupe(u8, r.name) });
        if (version.len == 0) version = try a.dupe(u8, r.ddragon_version);
    }
    // Icons need the version; an empty page would hide a broken champions table
    if (list.items.len == 0 or version.len == 0) return error.NoChampions;
    return .{ .ddragon = version, .champs = list.items };
}

pub fn page(a: std.mem.Allocator, h: *const tp.Head) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, tp.Head, h.*, &raw);
    const e = std.base64.standard.Encoder;
    var p: tp.Page = .init(h);
    p.bin = e.encode(try a.alloc(u8, e.calcSize(raw.items.len)), raw.items);
    const ix = try tp.searchIndex(a, h);
    p.useIndex(&ix);
    var c: ui.testercand.Panel = .init(h);
    c.js = assets.testercand_js.path;
    c.wasm = assets.testercand_wasm.path;
    var t: ui.Tree = .{};
    var hh: ui.H = .init(a, &t);
    const top = p.view(&hh);
    const panel = c.view(&hh);
    if (hh.oom) return error.OutOfMemory;
    var out: Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\{s}<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="robots" content="noindex">
        \\<title>Draft tester</title>
        \\<link rel="stylesheet" href="/{s}">
        \\</head>
        \\<body class="ui">
        \\<main class="c-sitemain">
        \\
    , .{ csp.files_only, style.file.path });
    try ui.html.write(&t, top, w);
    try ui.html.write(&t, panel, w);
    try w.print(
        \\
        \\</main>
        \\<script src="{s}" data-wasm="{s}" defer></script>
        \\</body>
        \\</html>
        \\
    , .{ assets.tester_js.path, assets.tester_wasm.path });
    return sheets.deliverWith(a, out.written(), &.{ assets.tester_wasm, assets.testercand_wasm });
}

/// tester.html and its code into `out_dir`, each with a .gz (gzip_static)
pub fn write(gpa: std.mem.Allocator, io: Io, out_dir: []const u8, db: store.Db) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const h = try head(a, db);
    var dir = try Io.Dir.cwd().openDir(io, out_dir, .{});
    defer dir.close(io);
    const files = [_]struct { []const u8, []const u8 }{
        .{ "tester.html", try page(a, &h) },
        .{ assets.tester_js.path, assets.tester_js.data },
        .{ assets.tester_wasm.path, assets.tester_wasm.data },
        .{ assets.testercand_js.path, assets.testercand_js.data },
        .{ assets.testercand_wasm.path, assets.testercand_wasm.data },
    };
    for (files) |f| {
        try dir.writeFile(io, .{ .sub_path = f[0], .data = f[1] });
        try dir.writeFile(io, .{ .sub_path = try std.mem.concat(a, u8, &.{ f[0], ".gz" }), .data = try store.raw.compress(a, f[1]) });
    }
}
