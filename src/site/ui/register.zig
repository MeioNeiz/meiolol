//! The components register (docs/plan/ui/components.md), written from the code: each
//! component's name, file, scope classes, doc comment, gallery states and the components
//! that import it, after a contents grouped by job. `zig build uilint -- --write`
//! rewrites it; root.zig's test fails when the checked-in copy is stale, so it can't
//! drift from src/site/ui again
const std = @import("std");
const tree = @import("tree.zig");
const gallery = @import("gallery.zig");

const width = 90;

/// `files`: file names, space separated
const Group = struct { name: []const u8, files: []const u8 };

/// The contents' groups, by job. A component in none fails the test below; a
/// name with no component yet (one still uncommitted) is skipped
const groups = [_]Group{
    .{
        .name = "Controls",
        .files = "button chip scopechip segmented tabs select toggletip tip " ++
            "rolepicker filterbar champsearch sitesearch champrolepicker lockbar " ++
            "idlookup guess actionbutton",
    },
    .{
        .name = "Labels and icons",
        .files = "badge modelbadge alertband role champ art objicon",
    },
    .{
        .name = "Figures",
        .files = "stat rate delta bar kda strip split dmgsplit versus resultstrip spark",
    },
    .{
        .name = "Charts",
        .files = "chart dotplot trend timechart histogram aucchart lane timeline violin " ++
            "minimap heatgrid matchgrid rankstrip draftflow reasons",
    },
    .{
        .name = "Cards, tables and text",
        .files = "card table today prose",
    },
    .{
        .name = "Champions and builds",
        .files = "champhead matchbrief matchstrip champlist hardagainst skillgrid itempath runetree " ++
            "buildpanel candlist poolslots changeline patchhead",
    },
    .{
        .name = "Games and drafts",
        .files = "draftboard teamrows gamestrip inspector gamehead gamerow scoreboard " ++
            "laneduel itemrow dayhead playerbar profilesum recordtile highlights " ++
            "gametrend puzzle choice dailyseat dailydays",
    },
    .{
        .name = "App screens",
        .files = "app appbar champselect compview lobby apphome gamebuild loadscreen " ++
            "gamescreen postgame signin practice picks",
    },
    .{
        .name = "Pages and their sections",
        .files = "site textpage homepage champpage matchpage tiers finder ranking " ++
            "learnpage dailypage patchpage poolpage poolgrid gamepage yourpage " ++
            "yourviews yourtime yourlookup yourfriends squad forget apply account " ++
            "testerpage testercand",
    },
    .{
        .name = "Admin and ops",
        .files = "pv meionotes meionoteslist adminpage admincharts admintraffic adminops " ++
            "adminmodels adminlab adminruns logview steptimeline",
    },
};

fn groupOf(file: []const u8) ?usize {
    for (groups, 0..) |g, i| {
        var files = std.mem.tokenizeScalar(u8, g.files, ' ');
        while (files.next()) |f| if (std.mem.eql(u8, f, file)) return i;
    }
    return null;
}

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
    try w.writeAll("## Contents\n");
    for (groups, 0..) |g, gi| {
        try w.print("\n**{s}**\n", .{g.name});
        inline for (every) |C| if (groupOf(comptime fileName(C)) == gi) {
            try w.print("{s}\n", .{try summary(a, C.name, @embedFile(comptime fileName(C) ++ ".zig"))});
        };
    }
    var loose = false;
    inline for (every) |C| if (groupOf(comptime fileName(C)) == null) {
        if (!loose) try w.writeAll("\n**No group yet** (register.zig groups)\n");
        loose = true;
        try w.print("{s}\n", .{try summary(a, C.name, @embedFile(comptime fileName(C) ++ ".zig"))});
    };
    try w.writeAll("\n");
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

/// `- Name: ` and the doc comment's first sentence, cut at a space to fit `width`
fn summary(a: std.mem.Allocator, name: []const u8, src: []const u8) ![]const u8 {
    var doc = try docComment(a, src);
    if (std.mem.startsWith(u8, doc, name) and std.mem.startsWith(u8, doc[name.len..], ": ")) doc = doc[name.len + 2 ..];
    if (std.mem.find(u8, doc, ". ")) |end| doc = doc[0..end];
    doc = std.mem.trimEnd(u8, doc, ".");
    const line = if (doc.len == 0) try std.fmt.allocPrint(a, "- {s}", .{name}) else try std.fmt.allocPrint(a, "- {s}: {s}", .{ name, doc });
    if (line.len <= width) return line;
    const cut = std.mem.findScalarLast(u8, line[0 .. width - 3], ' ') orelse width - 3;
    return std.fmt.allocPrint(a, "{s}...", .{std.mem.trimEnd(u8, line[0..cut], ",;:")});
}

test summary {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("- Button: the pressable shape", try summary(a, "Button", "//! Button: the pressable shape. Primary is\n//! one action\n"));
    try std.testing.expectEqualStrings("- Chart: The one chart system", try summary(a, "Chart", "//! The one chart system.\n"));
    try std.testing.expectEqualStrings("- Site", try summary(a, "Site", "const std = @import(\"std\");\n"));
    const long = "//! word word word word word word word word word word word word word word word word word word word word\n";
    const got = try summary(a, "X", long);
    try std.testing.expect(got.len <= width and std.mem.endsWith(u8, got, "word..."));
}

test "contents: every module in ui.all and ui.pages has a group" {
    const ui = @import("root.zig");
    inline for (ui.all ++ ui.pages) |C| if (groupOf(comptime fileName(C)) == null) {
        std.debug.print("{s}.zig has no group in register.zig groups\n", .{comptime fileName(C)});
        return error.TestUnexpectedResult;
    };
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
