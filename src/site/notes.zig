//! The notes tool's files (ui.notes, ui-notes.wasm) under /p/ at fixed names, and the tag
//! that loads them. nginx (deploy/nginx/meiolol.conf, @notes) or the dev server adds the
//! tag to a page only for a request carrying the marker cookie, which the API sets at an
//! admin's login: public pages hold none of it
const std = @import("std");
const ui = @import("ui");

pub const css = ui.css.join(.{ui.notes});

/// Fixed names, revalidated each load (/p/ is no-cache), so the tag nginx adds is one
/// string in its config
pub const files = [_]struct { []const u8, []const u8 }{
    .{ "notes.css", css },
    .{ "notes.js", @embedFile("ui-notes.js") },
    .{ "notes.wasm", @embedFile("ui-notes.wasm") },
};

pub const tag = "<link rel=\"stylesheet\" href=\"/p/notes.css\"><script src=\"/p/notes.js\" data-wasm=\"/p/notes.wasm\" defer></script>";

/// The marker; the dev server's has no __Host- prefix (that needs HTTPS)
pub const cookie = "__Host-meiolol_notes";
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

/// One of `files` by its name under /p/
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
