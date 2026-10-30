//! The notes tool's files (ui.notes, ui-notes.wasm) under /private/ at fixed names, and the tag
//! that loads them. nginx (deploy/nginx/meiolol.conf, @notes and @notes_private) or the dev
//! server adds the tag to a page only for a request carrying the marker cookie, which the
//! API sets at an admin's login: public pages hold none of it
const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const csp = @import("csp.zig");
const sheets = @import("sheets.zig");
const shell = @import("shell.zig");

/// With every public component: a page inlines only those it uses (sheets.zig), and the
/// tag comes after; repeated whole, the cascade stays the one sheet's
pub const css = ui.css.join(ui.components) ++ ui.css.join(.{ ui.notes, ui.noteslist });

/// Fixed names, revalidated each load (/private/ is no-cache), so the tag nginx adds is one
/// string in its config
pub const files = [_]struct { []const u8, []const u8 }{
    .{ "notes.css", css },
    .{ "notes.js", @embedFile("ui-notes.js") },
    .{ "notes.wasm", @embedFile("ui-notes.wasm") },
};

/// deploy/nginx/meiolol.conf's @notes and @notes_private hold this verbatim
pub const tag = "<link rel=\"stylesheet\" href=\"/private/notes.css\"><script src=\"/private/notes.js\" data-wasm=\"/private/notes.wasm\" defer></script>";

/// The marker; the dev server's has no __Host- prefix (that needs HTTPS)
pub const cookie = ui.notesdata.marker;
pub const dev_cookie = "meiolol_notes";

/// A Cookie header's value holds the marker (either name) set to 1
pub fn marked(header: []const u8) bool {
    var it = std.mem.tokenizeScalar(u8, header, ';');
    while (it.next()) |kv| {
        const t = std.mem.trim(u8, kv, " ");
        for ([_][]const u8{ cookie, dev_cookie }) |name| {
            if (t.len == name.len + 2 and std.mem.startsWith(u8, t, name) and std.mem.endsWith(u8, t, "=1")) return true;
        }
    }
    return false;
}

/// /admin/notes: every note (ui.noteslist) in the site shell, the same ui-notes.wasm in list
/// mode, its CSS inline
pub fn adminPage(a: std.mem.Allocator) ![]const u8 {
    var l: ui.noteslist.List = .{};
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const n = l.view(&h);
    if (h.oom) return error.OutOfMemory;
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    const page: @import("html.zig").Page = .{ .title = "Notes | meiolol", .description = "Every note on the site", .patch = "", .data = "", .public = false, .private = .notes };
    try shell.open(w, page);
    try ui.html.write(&t, n, w);
    try w.writeAll("\n<script src=\"/private/notes.js\" data-wasm=\"/private/notes.wasm\" defer></script>\n");
    try shell.close(w, page);
    return sheets.deliverWith(a, out.written(), &.{.{ .plain = "notes.wasm", .path = "notes.wasm", .data = file("notes.wasm").? }});
}

/// The tool's files into the private site's dir (`meiolol admin --private-out`), each with
/// a .gz (gzip_static)
pub fn writeFiles(gpa: std.mem.Allocator, io: std.Io, dir_path: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{});
    defer dir.close(io);
    for (files) |f| try writeGz(arena.allocator(), io, dir, f[0], f[1]);
}

/// notes.html into the admin page's dir (`meiolol admin --out`)
pub fn writeAdmin(gpa: std.mem.Allocator, io: std.Io, dir_path: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{});
    defer dir.close(io);
    try writeGz(a, io, dir, "notes.html", try adminPage(a));
}

fn writeGz(a: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, name: []const u8, data: []const u8) !void {
    try dir.writeFile(io, .{ .sub_path = name, .data = data });
    try dir.writeFile(io, .{ .sub_path = try std.mem.concat(a, u8, &.{ name, ".gz" }), .data = try store.raw.compress(a, data) });
}

/// One of `files` by its name under /private/
pub fn file(name: []const u8) ?[]const u8 {
    for (files) |f| if (std.mem.eql(u8, f[0], name)) return f[1];
    return null;
}

test marked {
    try std.testing.expect(marked("a=b; __Host-meiolol_notes=1"));
    try std.testing.expect(marked("meiolol_notes=1;a=b"));
    try std.testing.expect(!marked("__Host-meiolol_notes=0"));
    try std.testing.expect(!marked("x__Host-meiolol_notes=1"));
    try std.testing.expect(!marked("__Host-meiolol=1"));
    try std.testing.expect(!marked(""));
}

test file {
    try std.testing.expect(file("notes.wasm") != null);
    try std.testing.expect(file("tester.wasm") == null);
    try std.testing.expect(std.mem.find(u8, css, ".c-notes") != null);
}

test adminPage {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const page = try adminPage(arena.allocator());
    try std.testing.expect(std.mem.find(u8, page, "data-island=\"noteslist\"") != null);
    try std.testing.expect(std.mem.find(u8, page, "/private/notes.wasm") != null);
    try std.testing.expect(std.mem.find(u8, page, "stylesheet") == null);
    try csp.check(page);
}

test writeFiles {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.mem.concat(std.testing.allocator, u8, &.{ ".zig-cache/tmp/", &tmp.sub_path });
    defer std.testing.allocator.free(path);
    try writeFiles(std.testing.allocator, std.testing.io, path);
    try writeAdmin(std.testing.allocator, std.testing.io, path);
    for ([_][]const u8{ "notes.css", "notes.js", "notes.wasm", "notes.wasm.gz", "notes.html", "notes.html.gz" }) |f| {
        _ = try tmp.dir.statFile(std.testing.io, f, .{});
    }
}
