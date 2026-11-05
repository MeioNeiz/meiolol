//! uilint: guards over src/site/ui that a component's own tests can't see. Each rule
//! counts breaks per file; uilint-debt.txt holds today's counts, which may only go down.
//! root.zig's test fails when a file breaks more than its line allows, or less (then
//! `zig build uilint -- --write` shrinks the line). Raising or adding a line needs
//! Jacob's ok (`--grow`, and the diff shows it). docs/frontend.md "Working agreements"
const std = @import("std");
const css_mod = @import("css.zig");
const register = @import("register.zig");

pub const debt_path = "src/site/ui/uilint-debt.txt";
pub const register_path = "docs/plan/ui/components.md";

pub const Rule = enum {
    /// css.unscoped and css.lint, on pages too (expectSound covers gallery components)
    css,
    /// Another component's scope class in a class value: use its view or extend it.
    /// "c-chart" beside the file's own class is a chart preset's frame
    markup,
    /// A `title` on an element that isn't an icon or a wrapper naming the picture it
    /// starts with: phones never show it, Tip does
    title,
    /// `attr(data-tip)` in CSS outside tip.zig: tips come through Tip
    tip,
    /// A page's CSS rules (no gallery, a name ending "page", or `more_pages`): pages lay
    /// out cards, anything styled is a component or a variant
    pagecss,
    /// A scope class another file declared first: one owner per class
    scope,
};

/// Pages that keep a gallery
const more_pages = [_][]const u8{ "app", "finder" };

/// A scope class's file, and the second file declaring it if any
const Owner = struct { file: []const u8, also: ?[]const u8 = null };
const Owners = std.StringHashMapUnmanaged(Owner);

pub const Count = struct { file: []const u8, rule: Rule, n: u32 };

/// Every rule's breaks in `mods` (ui.all ++ ui.pages), files with none left out
pub fn counts(a: std.mem.Allocator, comptime mods: anytype) ![]const Count {
    @setEvalBranchQuota(100_000);
    var out: std.ArrayList(Count) = .empty;
    var owners: Owners = .empty;
    inline for (mods) |C| {
        const file = comptime register.fileName(C);
        var dup: usize = 0;
        inline for (C.scope) |s| {
            const got = try owners.getOrPut(a, s[1..]);
            if (!got.found_existing) {
                got.value_ptr.* = .{ .file = file };
            } else {
                got.value_ptr.also = file;
                dup += 1;
            }
        }
        try add(a, &out, file, .scope, dup);
    }
    inline for (mods) |C| {
        const file = comptime register.fileName(C);
        const unscoped = try css_mod.unscoped(a, C.css, &C.scope);
        const found = try css_mod.lint(a, C.css, .{});
        try add(a, &out, file, .css, unscoped.len + found.len);
        const src = try code(a, @embedFile(file ++ ".zig"));
        try add(a, &out, file, .markup, markup(src, file, &C.scope, owners));
        try add(a, &out, file, .title, titles(src));
        if (!std.mem.eql(u8, file, "tip")) try add(a, &out, file, .tip, std.mem.count(u8, C.css, "attr(data-tip)"));
        if (!@hasDecl(C, "gallery") or std.mem.endsWith(u8, file, "page") or inList(&more_pages, file)) {
            var rules: css_mod.Rules = .{ .css = C.css };
            var n: usize = 0;
            while (rules.next()) |_| n += 1;
            try add(a, &out, file, .pagecss, n);
        }
    }
    std.mem.sort(Count, out.items, {}, lessThan);
    return out.items;
}

fn add(a: std.mem.Allocator, out: *std.ArrayList(Count), file: []const u8, rule: Rule, n: usize) !void {
    if (n > 0) try out.append(a, .{ .file = file, .rule = rule, .n = @intCast(n) });
}

/// `src` up to its first test, without comment lines or multiline strings (its CSS)
fn code(a: std.mem.Allocator, src: []const u8) ![]const u8 {
    const end = std.mem.find(u8, src, "\ntest \"") orelse src.len;
    var out: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, src[0..end], '\n');
    while (lines.next()) |l| {
        const t = std.mem.trimStart(u8, l, " ");
        if (std.mem.startsWith(u8, t, "//") or std.mem.startsWith(u8, t, "\\\\")) continue;
        try out.appendSlice(a, l);
        try out.append(a, '\n');
    }
    return out.items;
}

fn isWord(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == '_';
}

fn inList(list: []const []const u8, x: []const u8) bool {
    for (list) |l| if (std.mem.eql(u8, l, x)) return true;
    return false;
}

/// Classes another file's scope owns, in `.class =` values' string literals
fn markup(src: []const u8, file: []const u8, own: []const []const u8, owners: Owners) usize {
    var n: usize = 0;
    var i: usize = 0;
    while (std.mem.findPos(u8, src, i, ".class =")) |at| {
        i = at + ".class =".len;
        // The value: up to a comma or closing bracket outside its own brackets
        var e = i;
        var depth: usize = 0;
        var quoted = false;
        while (e < src.len) : (e += 1) switch (src[e]) {
            '"' => quoted = !quoted,
            '\\' => e += 1,
            '(', '{', '[' => if (!quoted) {
                depth += 1;
            },
            ')', '}', ']' => if (!quoted) {
                if (depth == 0) break;
                depth -= 1;
            },
            ',' => if (!quoted and depth == 0) break,
            else => {},
        };
        var lits = std.mem.splitScalar(u8, src[i..e], '"');
        var k: usize = 0;
        while (lits.next()) |lit| : (k += 1) if (k % 2 == 1) {
            var framed = false;
            for (own) |o| framed = framed or hasWord(lit, o[1..]);
            var words = std.mem.tokenizeScalar(u8, lit, ' ');
            while (words.next()) |w| {
                const owner = owners.get(w) orelse continue;
                if (std.mem.eql(u8, owner.file, file)) continue;
                if (owner.also) |also| if (std.mem.eql(u8, also, file)) continue;
                if (framed and std.mem.eql(u8, w, "c-chart")) continue;
                n += 1;
            }
        };
    }
    return n;
}

fn hasWord(text: []const u8, word: []const u8) bool {
    var words = std.mem.tokenizeScalar(u8, text, ' ');
    while (words.next()) |w| if (std.mem.eql(u8, w, word)) return true;
    return false;
}

/// `.title =` set in an element's attributes (`h.span(.{ ... })`), icons left out: a
/// literal naming "icon", or an svg or img element
fn titles(src: []const u8) usize {
    var n: usize = 0;
    var i: usize = 0;
    while (std.mem.findPos(u8, src, i, ".title =")) |at| {
        i = at + 1;
        const open = enclosing(src, at) orelse continue;
        if (open == 0 or src[open - 1] != '.') continue;
        const before = std.mem.trimEnd(u8, src[0 .. open - 1], " \n");
        if (before.len == 0 or before[before.len - 1] != '(') continue;
        const call = before[0 .. before.len - 1];
        var s = call.len;
        while (s > 0 and (std.ascii.isAlphanumeric(call[s - 1]) or call[s - 1] == '_')) s -= 1;
        if (s < 2 or !std.mem.eql(u8, call[s - 2 .. s], "h.")) continue;
        const tag = call[s..];
        if (std.mem.eql(u8, tag, "svg") or std.mem.eql(u8, tag, "img")) continue;
        const close = closing(src, open + 1) orelse continue;
        if (std.mem.find(u8, src[open..close], "icon") != null) continue;
        if (names(src[at + ".title =".len .. close], src[close + 1 ..])) continue;
        n += 1;
    }
    return n;
}

/// The title names the picture its element starts with: an objective icon's, or a
/// champion's, item's or role's `.name`
fn names(value: []const u8, rest: []const u8) bool {
    var r = std.mem.trimStart(u8, rest, " \n,");
    if (!std.mem.startsWith(u8, r, ".{")) return false;
    r = std.mem.trimStart(u8, r[2..], " \n");
    if (std.mem.startsWith(u8, r, "objicon.")) return true;
    const v = std.mem.trim(u8, value[0 .. std.mem.findScalar(u8, value, ',') orelse value.len], " \n");
    if (!std.mem.endsWith(u8, v, "name")) return false;
    for ([_][]const u8{ "champ.", "art.", "role." }) |p| if (std.mem.startsWith(u8, r, p)) return true;
    return false;
}

/// The `{` of the literal `at` sits in
fn enclosing(src: []const u8, at: usize) ?usize {
    var depth: usize = 0;
    var j = at;
    while (j > 0) {
        j -= 1;
        switch (src[j]) {
            '}', ')', ']' => depth += 1,
            '{', '(', '[' => if (depth == 0) return if (src[j] == '{') j else null else {
                depth -= 1;
            },
            else => {},
        }
    }
    return null;
}

/// The bracket closing the one open before `from`
fn closing(src: []const u8, from: usize) ?usize {
    var depth: usize = 0;
    for (src[from..], from..) |c, j| switch (c) {
        '{', '(', '[' => depth += 1,
        '}', ')', ']' => if (depth == 0) return j else {
            depth -= 1;
        },
        else => {},
    };
    return null;
}

fn lessThan(_: void, x: Count, y: Count) bool {
    return switch (std.mem.order(u8, x.file, y.file)) {
        .lt => true,
        .gt => false,
        .eq => @backingInt(x.rule) < @backingInt(y.rule),
    };
}

/// The debt file's counts: `file rule n` lines, `#` comments
pub fn parse(a: std.mem.Allocator, text: []const u8) ![]const Count {
    var out: std.ArrayList(Count) = .empty;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |l| {
        if (l[0] == '#') continue;
        var f = std.mem.tokenizeScalar(u8, l, ' ');
        const file = f.next() orelse return error.BadDebtLine;
        const rule = std.meta.stringToEnum(Rule, f.next() orelse return error.BadDebtLine) orelse return error.BadDebtLine;
        const n = try std.fmt.parseInt(u32, f.next() orelse return error.BadDebtLine, 10);
        try out.append(a, .{ .file = file, .rule = rule, .n = n });
    }
    return out.items;
}

fn find(list: []const Count, file: []const u8, rule: Rule) u32 {
    for (list) |c| if (c.rule == rule and std.mem.eql(u8, c.file, file)) return c.n;
    return 0;
}

/// Writes what differs from the debt to `w`; true when nothing does
pub fn compare(have: []const Count, debt: []const Count, w: *std.Io.Writer) !bool {
    var ok = true;
    for (have) |c| {
        const allowed = find(debt, c.file, c.rule);
        if (c.n > allowed) {
            const msg = "{s}.zig {t}: {d} breaks, the debt allows {d}\n"; // fmt-ok: host only
            try w.print(msg, .{ c.file, c.rule, c.n, allowed });
            ok = false;
        }
    }
    for (debt) |d| {
        const n = find(have, d.file, d.rule);
        if (n < d.n) {
            const msg = "{s}.zig {t}: {d} breaks, the debt says {d}: `zig build uilint -- --write`\n"; // fmt-ok
            try w.print(msg, .{ d.file, d.rule, n, d.n });
            ok = false;
        }
    }
    return ok;
}

const header =
    \\# uilint debt (src/site/ui/uilint.zig): file rule breaks. Only goes down: after a fix,
    \\# `zig build uilint -- --write`. A line raised or added needs Jacob's ok (--grow)
    \\
;

/// The debt file for `have`: each count capped at the old debt's unless `grow`
pub fn debtText(a: std.mem.Allocator, have: []const Count, debt: []const Count, grow: bool) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    try out.writer.writeAll(header);
    for (have) |c| {
        const n = if (grow) c.n else @min(c.n, find(debt, c.file, c.rule));
        if (n > 0) try out.writer.print("{s} {t} {d}\n", .{ c.file, c.rule, n }); // fmt-ok
    }
    return out.written();
}

/// The register as uilint writes it
pub fn registerText(a: std.mem.Allocator, comptime comps: anytype, comptime pages: anytype, comptime site: anytype) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    try register.write(a, &out.writer, comps, pages, site);
    return out.written();
}

const testing = std.testing;

test "markup: another file's class in a class value counts; its own, a frame and text don't" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var owners: Owners = .empty;
    try owners.put(a, "c-btn", .{ .file = "button" });
    try owners.put(a, "c-pg", .{ .file = "page" });
    try owners.put(a, "c-chart", .{ .file = "chart" });
    try owners.put(a, "c-rank", .{ .file = "ranking", .also = "page" });
    const src = try code(a,
        \\// c-btn in a comment
        \\h.a(.{ .class = "c-btn go" }, .{}), h.div(.{ .class = "c-pg abc-btn c-btnx" }, .{});
        \\h.div(.{ .class = "c-chart c-pg", .key = 1 }, .{}), h.b(.{ .class = "c-rank" }, .{});
        \\h.i(.{ .class = h.cls("c-chart", .{ .on = f(x, "c-btn") }) }, .{});
        \\const what = "c-btn > span"; t.find(n, "class", "c-btn");
        \\pub const css =
        \\    \\.c-pg .c-btn { gap: 0 }
        \\;
        \\test "x" { "c-btn" }
    );
    try testing.expectEqual(3, markup(src, "page", &.{".c-pg"}, owners));
}

test "titles: an element's title counts; an icon's, an svg's and a struct field's don't" {
    const src =
        \\h.span(.{ .class = "t", .title = a }, .{x}),
        \\h.button(.{ .data_v = "icon", .title = W.set }, .{}),
        \\h.svg(.{ .title = n }, .{}),
        \\Bar.track(h, .{ .title = s }),
        \\h.li(.{ .key = i, .title = c.name }, .{
        \\    champ.view(h, c, .{}),
        \\}),
        \\h.li(.{ .title = W.tip.with(h, .{ .c = c.name }) }, .{champ.view(h, c, .{})}),
        \\h.td(.{
        \\    .class = h.cls("n", .{ .on = f(x) }),
        \\    .title = W.games,
        \\}, .{}),
    ;
    try testing.expectEqual(3, titles(src));
}

test "debt: over, under and a capped write" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const debt = try parse(a, header ++ "champpage css 3\ntiers css 2\n");
    var out: std.Io.Writer.Allocating = .init(a);
    try testing.expect(try compare(&.{ .{ .file = "champpage", .rule = .css, .n = 3 }, .{ .file = "tiers", .rule = .css, .n = 2 } }, debt, &out.writer));
    const have: []const Count = &.{ .{ .file = "champpage", .rule = .css, .n = 4 }, .{ .file = "tiers", .rule = .css, .n = 1 } };
    try testing.expect(!try compare(have, debt, &out.writer));
    try testing.expectEqualStrings(
        "champpage.zig css: 4 breaks, the debt allows 3\n" ++
            "tiers.zig css: 1 breaks, the debt says 2: `zig build uilint -- --write`\n",
        out.written(),
    );
    try testing.expectEqualStrings(header ++ "champpage css 3\ntiers css 1\n", try debtText(a, have, debt, false));
    try testing.expectEqualStrings(header ++ "champpage css 4\ntiers css 1\n", try debtText(a, have, debt, true));
}
