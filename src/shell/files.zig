//! What the shell serves its webview: files embedded in the exe, or with `--dir` a
//! folder on disk (the dev loop: deploy/dev.sh's output, mocks). Both shells serve one
//! made-up origin from memory (https://meiolol.app/ on Windows, meiolol://app/ on the
//! Mac); nothing leaves the machine to load a page.

const std = @import("std");
const screens = @import("screens.zig");

pub const bridge_js = @embedFile("web/bridge.js");

pub const start_page = "index.html";

/// Beside these, screens.zig serves the page, its data and the champion icons
const embedded = [_]struct { []const u8, []const u8 }{
    .{ "app.css", screens.css },
    .{ "ui-app.js", @embedFile("ui-app.js") },
    .{ "ui-app.wasm", @embedFile("ui-app.wasm") },
};

pub fn get(path: []const u8) ?[]const u8 {
    for (embedded) |f| if (std.mem.eql(u8, f[0], path)) return f[1];
    return null;
}

/// The file path in a request's URL path, or null for one that could leave the folder
/// (`..`, a drive, a backslash) or isn't plain. "" is the start page
pub fn clean(url_path: []const u8) ?[]const u8 {
    var p = url_path;
    if (std.mem.indexOfAny(u8, p, "?#")) |i| p = p[0..i];
    while (p.len > 0 and p[0] == '/') p = p[1..];
    if (p.len == 0) return start_page;
    if (p.len > 200) return null;
    for (p) |ch| switch (ch) {
        'a'...'z', 'A'...'Z', '0'...'9', '-', '_', '.', '/' => {},
        else => return null,
    };
    var it = std.mem.splitScalar(u8, p, '/');
    while (it.next()) |seg| if (seg.len == 0 or seg[0] == '.') return null;
    return p;
}

pub fn mime(path: []const u8) []const u8 {
    const types = [_][2][]const u8{
        .{ ".html", "text/html; charset=utf-8" }, .{ ".css", "text/css" },
        .{ ".js", "text/javascript" },            .{ ".wasm", "application/wasm" },
        .{ ".png", "image/png" },                 .{ ".svg", "image/svg+xml" },
        .{ ".webp", "image/webp" },               .{ ".woff2", "font/woff2" },
        .{ ".json", "application/json" },
    };
    for (types) |t| if (std.mem.endsWith(u8, path, t[0])) return t[1];
    return "application/octet-stream";
}

/// Embedded files and icons change only with the exe, so all but pages and data may stay
/// cached: without it the webview refetched every icon on each DOM swap (3x the CPU of a
/// push, spike)
pub fn immutable(path: []const u8) bool {
    return !std.mem.endsWith(u8, path, ".html") and !std.mem.endsWith(u8, path, ".bin");
}

test "clean: plain paths in the folder only" {
    const t = std.testing;
    try t.expectEqualStrings("index.html", clean("/").?);
    try t.expectEqualStrings("index.html", clean("").?);
    try t.expectEqualStrings("draft.html", clean("/draft.html?x=1#top").?);
    try t.expectEqualStrings("icons/champ/Ahri.png", clean("/icons/champ/Ahri.png").?);
    for ([_][]const u8{
        "/../secret",     "/a/../../b", "/.git/config", "/C:/Windows", "/a\\b",
        "/a//b",          "/%2e%2e/x",  "/a b",         "/a/",         "/\x00",
        "/icons/.hidden",
    }) |bad| try t.expect(clean(bad) == null);
}

test "embedded: the island and its CSS, mime by extension" {
    try std.testing.expect(get("ui-app.wasm") != null and get("ui-app.js") != null);
    try std.testing.expect(std.mem.find(u8, get("app.css").?, ".c-cs") != null);
    try std.testing.expect(get("nope.html") == null);
    try std.testing.expectEqualStrings("application/wasm", mime("ui.wasm"));
    try std.testing.expect(!immutable("index.html") and !immutable("app.bin") and immutable("ui.wasm"));
}
