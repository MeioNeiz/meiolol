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
};

pub const Count = struct { file: []const u8, rule: Rule, n: u32 };

/// Every rule's breaks in `mods` (ui.all ++ ui.pages), files with none left out
pub fn counts(a: std.mem.Allocator, comptime mods: anytype) ![]const Count {
    @setEvalBranchQuota(100_000);
    var out: std.ArrayList(Count) = .empty;
    inline for (mods) |C| {
        const file = comptime register.fileName(C);
        const unscoped = try css_mod.unscoped(a, C.css, &C.scope);
        const found = try css_mod.lint(a, C.css, .{});
        try add(a, &out, file, .css, unscoped.len + found.len);
    }
    std.mem.sort(Count, out.items, {}, lessThan);
    return out.items;
}

fn add(a: std.mem.Allocator, out: *std.ArrayList(Count), file: []const u8, rule: Rule, n: usize) !void {
    if (n > 0) try out.append(a, .{ .file = file, .rule = rule, .n = @intCast(n) });
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
