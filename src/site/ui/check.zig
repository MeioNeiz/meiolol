//! Test backend: lint a built tree in a plain `zig build test`, no browser. The
//! guardrails are direction, not law: each check has a level, warn by default, and a page
//! raises one to `err` (its test then fails) or turns it off
const std = @import("std");
const tree = @import("tree.zig");

pub const Level = enum { off, warn, err };

pub const Rules = struct {
    /// Every <button> and <a> has text or an aria-label
    button_name: Level = .warn,
    /// Every <img> has an alt (empty when the image only decorates)
    img_alt: Level = .warn,
    /// Column headers and buttons: at most label_chars and label_words
    label: Level = .warn,
    label_chars: usize = 16,
    label_words: usize = 2,
    /// Words on the page (text, aria-label, title, placeholder) within `word_budget`
    words: Level = .warn,
    word_budget: usize = 400,
    /// A table has exactly one column marked data-answer
    answer: Level = .warn,
};

pub const Finding = struct { level: Level, msg: []const u8 };

pub const Report = struct {
    a: std.mem.Allocator,
    findings: std.ArrayList(Finding) = .empty,
    words: usize = 0,

    fn add(r: *Report, level: Level, comptime f: []const u8, args: anytype) void {
        if (level == .off) return;
        const msg = r.a.print(f, args) catch return;
        r.findings.append(r.a, .{ .level = level, .msg = msg }) catch {};
    }

    pub fn errors(r: Report) usize {
        var n: usize = 0;
        for (r.findings.items) |f| n += @intFromBool(f.level == .err);
        return n;
    }

    pub fn has(r: Report, needle: []const u8) bool {
        for (r.findings.items) |f| if (std.mem.find(u8, f.msg, needle) != null) return true;
        return false;
    }
};

pub fn run(a: std.mem.Allocator, t: *const tree.Tree, rules: Rules) !Report {
    var r: Report = .{ .a = a };
    walk(&r, t, t.root, rules);
    if (r.words > rules.word_budget) r.add(rules.words, "{d} words, budget {d}", .{ r.words, rules.word_budget });
    return r;
}

fn textOf(r: *Report, t: *const tree.Tree, n: tree.N) []const u8 {
    var w: std.Io.Writer.Allocating = .init(r.a);
    t.textOf(n, &w.writer) catch {};
    return std.mem.trim(u8, w.written(), " ");
}

fn countWords(s: []const u8) usize {
    var it = std.mem.tokenizeAny(u8, s, " \n");
    var n: usize = 0;
    // Words have a letter: figures don't count toward a budget
    while (it.next()) |w| {
        for (w) |c| if (std.ascii.isAlphabetic(c)) {
            n += 1;
            break;
        };
    }
    return n;
}

fn hasAlt(t: *const tree.Tree, n: tree.N) bool {
    if (t.node(n).tag == .img) if (t.attr(n, "alt")) |alt| return alt.len > 0;
    for (t.kidsOf(n)) |k| if (hasAlt(t, k)) return true;
    return false;
}

fn walk(r: *Report, t: *const tree.Tree, n: tree.N, rules: Rules) void {
    const x = t.node(n);
    if (x.tag == .@"#text") {
        r.words += countWords(x.text);
        return;
    }
    for ([_][]const u8{ "aria-label", "title", "placeholder" }) |name| {
        if (t.attr(n, name)) |v| r.words += countWords(v);
    }
    switch (x.tag) {
        .button => {
            const label = t.attr(n, "aria-label") orelse textOf(r, t, n);
            if (label.len == 0) r.add(rules.button_name, "a button has no name (text or aria-label)", .{});
            // A listbox row (Select's menu) is a choice in a list, as a table cell, not an
            // action's label: it may carry a ModelBadge and its facts line
            const row = if (t.attr(n, "role")) |v| std.mem.eql(u8, v, "option") else false;
            if (!row and (label.len > rules.label_chars or countWords(label) > rules.label_words)) {
                // An aria-label may be longer than what shows; the visible text is the label
                const shown = textOf(r, t, n);
                if (shown.len > rules.label_chars or countWords(shown) > rules.label_words) {
                    r.add(rules.label, "label \"{s}\" over {d} chars or {d} words", .{ shown, rules.label_chars, rules.label_words });
                }
            }
        },
        .a => {
            const label = t.attr(n, "aria-label") orelse textOf(r, t, n);
            if (label.len == 0 and !hasAlt(t, n)) r.add(rules.button_name, "a link has no name (text, aria-label or an img alt)", .{});
        },
        .img => if (t.attr(n, "alt") == null) r.add(rules.img_alt, "an img has no alt", .{}),
        .table => {
            const answers = t.count(n, "data-answer");
            if (answers != 1) r.add(rules.answer, "table has {d} answer columns, not 1", .{answers});
        },
        else => {},
    }
    for (t.kidsOf(n)) |k| walk(r, t, k, rules);
}

const testing = std.testing;

test "a label over budget is a warning, not a failure; a raised rule fails" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: tree.H = .init(arena.allocator(), &t);
    t.root = h.div(.{}, .{
        h.button(.{}, .{"Show every champion role"}),
        h.button(.{ .aria_label = "Close" }, .{}),
        h.a(.{ .href = "/x" }, .{h.img(.{ .src = "a.png", .alt = "Ahri" })}),
        h.img(.{ .src = "b.png" }),
        h.button(.{}, .{}),
    });
    const r = try run(arena.allocator(), &t, .{});
    try testing.expect(r.has("over 16 chars"));
    try testing.expect(r.has("an img has no alt"));
    try testing.expect(!r.has("a link has no name"));
    try testing.expectEqual(@as(usize, 0), r.errors());
    try testing.expectEqual(@as(usize, 1), (try run(arena.allocator(), &t, .{ .button_name = .err })).errors());
    try testing.expectEqual(@as(usize, 5), r.words);
}

test "a listbox row may run past the label budget" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: tree.H = .init(arena.allocator(), &t);
    t.root = h.div(.{ .role = "listbox" }, .{h.button(.{ .role = "option" }, .{"Live draft model Daily App"})});
    try testing.expectEqual(@as(usize, 0), (try run(arena.allocator(), &t, .{ .label = .err })).findings.items.len);
}
