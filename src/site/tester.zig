//! The new Draft tester page (/p/tester.html, ui.testerpage): its HTML with the champion
//! list inline, its stylesheet and ui-tester.wasm, written into the private site's dir
//! beside the old page (admin.private) by `meiolol admin --private-out`. Never public:
//! nginx serves /p/ to view_private logins only
const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const assets = @import("assets.zig");
const style = @import("style.zig");

const Io = std.Io;
const tp = ui.testerpage;

/// What the public stylesheet leaves out (ui.components): it is linked first
pub const css = ui.css.join(.{ ui.select, ui.split, ui.draftboard, ui.modelbadge, ui.testerpage });
pub const css_file = assets.hashed("tester.css", css);

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
    return .{ .ddragon = version, .champs = list.items };
}

pub fn page(a: std.mem.Allocator, h: *const tp.Head) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, tp.Head, h.*, &raw);
    const e = std.base64.standard.Encoder;
    const ix = try a.create(ui.champsearch.Index);
    ix.* = try tp.index(a, h);
    var p: tp.Page = .init(h, ix);
    p.bin = e.encode(try a.alloc(u8, e.calcSize(raw.items.len)), raw.items);
    var t: ui.Tree = .{};
    var hh: ui.H = .init(a, &t);
    t.root = p.view(&hh);
    if (hh.oom) return error.OutOfMemory;
    var out: Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="robots" content="noindex">
        \\<title>Draft tester</title>
        \\<link rel="stylesheet" href="/{s}">
        \\<link rel="stylesheet" href="{s}">
        \\</head>
        \\<body>
        \\<main class="wrap">
        \\
    , .{ style.file.path, css_file.path });
    try ui.html.write(&t, t.root, w);
    try w.print(
        \\
        \\</main>
        \\<script src="{s}" data-wasm="{s}" defer></script>
        \\</body>
        \\</html>
        \\
    , .{ assets.tester_js.path, assets.tester_wasm.path });
    return out.written();
}

/// tester.html, its stylesheet and code into `out_dir`, each with a .gz (gzip_static)
pub fn write(gpa: std.mem.Allocator, io: Io, out_dir: []const u8, db: store.Db) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const h = try head(a, db);
    var dir = try Io.Dir.cwd().openDir(io, out_dir, .{});
    defer dir.close(io);
    const files = [_]struct { []const u8, []const u8 }{
        .{ "tester.html", try page(a, &h) },
        .{ css_file.path, css_file.data },
        .{ assets.tester_js.path, assets.tester_js.data },
        .{ assets.tester_wasm.path, assets.tester_wasm.data },
    };
    for (files) |f| {
        try dir.writeFile(io, .{ .sub_path = f[0], .data = f[1] });
        try dir.writeFile(io, .{ .sub_path = try std.mem.concat(a, u8, &.{ f[0], ".gz" }), .data = try store.raw.compress(a, f[1]) });
    }
}
