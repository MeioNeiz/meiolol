//! The components register (docs/plan/ui/components.md), written from the code: each
//! component's name, file, scope classes, doc comment, gallery states and the components
//! that import it. `zig build uilint -- --write` rewrites it; root.zig's test fails when
//! the checked-in copy is stale, so it can't drift from src/site/ui again
const std = @import("std");
const tree = @import("tree.zig");
const gallery = @import("gallery.zig");

const width = 90;

/// The register for `comps` (with galleries) then `pages` (none)
pub fn write(a: std.mem.Allocator, w: *std.Io.Writer, comptime comps: anytype, comptime pages: anytype, comptime site: anytype) !void {
    @setEvalBranchQuota(200_000);
    const every = comps ++ pages;
    try w.writeAll(
        \\# Components register
        \\
        \\Written by `zig build uilint -- --write` from src/site/ui (ui.all, then ui.pages):
        \\don't edit by hand; a test fails when it is stale. Search here before building
        \\anything, and extend a component rather than copy it. Hand notes (rules that span
        \\components): docs/plan/ui/README.md. Each entry: file, scope classes, "site" when
        \\its CSS ships to the site, the gallery's states, and the components importing it.
        \\
        \\
    );
    const names, const sources = comptime blk: {
        var n: [every.len][]const u8 = undefined;
        var src: [every.len][]const u8 = undefined;
        for (every, 0..) |U, k| {
            n[k] = fileName(U);
            src[k] = @embedFile(n[k] ++ ".zig");
        }
        break :blk .{ n, src };
    };
    var t: tree.Tree = .{};
    var h: tree.H = .init(a, &t);
    inline for (every, 0..) |C, i| {
        const file = comptime fileName(C);
        if (i == comps.len) try w.writeAll("## Pages (no gallery)\n\n");
        try w.print("### {s}\n", .{C.name});
        var line: std.Io.Writer.Allocating = .init(a);
        try line.writer.print("`{s}.zig`", .{file});
        inline for (C.scope) |s| try line.writer.print(" `{s}`", .{s});
        if (comptime inTuple(site, C)) try line.writer.writeAll(" site");
        try wrap(w, line.written());
        try wrap(w, try docComment(a, @embedFile(file ++ ".zig")));
        if (i < comps.len) {
            const st = gallery.states(&h, C, 0);
            var caps: std.Io.Writer.Allocating = .init(a);
            try caps.writer.writeAll("States:");
            for (st, 0..) |s, k| try caps.writer.print("{s} {s}", .{ if (k == 0) "" else ";", s.caption });
            try wrap(w, caps.written());
        }
        var users: std.Io.Writer.Allocating = .init(a);
        const needle = comptime "@import(\"" ++ file ++ ".zig\")";
        for (sources, names) |src, u| if (std.mem.find(u8, src, needle) != null) {
            try users.writer.print("{s} {s}", .{ if (users.written().len == 0) "Used by:" else ",", u });
        };
        if (users.written().len > 0) try wrap(w, users.written());
        try w.writeByte('\n');
    }
}

fn inTuple(comptime list: anytype, comptime C: type) bool {
    for (list) |L| if (L == C) return true;
    return false;
}

/// `card` for ui.card
pub fn fileName(comptime C: type) []const u8 {
    @setEvalBranchQuota(10_000);
    const t = @typeName(C);
    return t[(std.mem.findScalarLast(u8, t, '.') orelse return t) + 1 ..];
}

/// The file's leading `//!` lines as one paragraph
fn docComment(a: std.mem.Allocator, src: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, src, '\n');
    while (lines.next()) |l| {
        if (!std.mem.startsWith(u8, l, "//!")) break;
        const text = std.mem.trim(u8, l[3..], " ");
        if (text.len == 0) continue;
        if (out.items.len > 0) try out.append(a, ' ');
        try out.appendSlice(a, text);
    }
    return out.items;
}

/// `text` in lines of at most `width`, breaking at spaces
fn wrap(w: *std.Io.Writer, text: []const u8) !void {
    var words = std.mem.tokenizeScalar(u8, text, ' ');
    var col: usize = 0;
    while (words.next()) |word| {
        if (col > 0 and col + 1 + word.len > width) {
            try w.writeByte('\n');
            col = 0;
        }
        if (col > 0) {
            try w.writeByte(' ');
            col += 1;
        }
        try w.writeAll(word);
        col += word.len;
    }
    if (col > 0) try w.writeByte('\n');
}

test wrap {
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    // 45 one-letter words fill 89 columns: the 46th goes to the next line
    const nine = "a a a a a a a a a";
    const line = nine ++ " " ++ nine ++ " " ++ nine ++ " " ++ nine ++ " " ++ nine;
    try wrap(&out.writer, line ++ " b b");
    try std.testing.expectEqualStrings(line ++ "\nb b\n", out.written());
}
