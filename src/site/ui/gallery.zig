//! The gallery (docs/plan/ui/README.md Tooling): every component in each of its states,
//! from the component's own `gallery` function, so the page, the tests and qa.sh see the
//! same fixtures. Each component's states sit in containers 320 and 390 px wide and one
//! taking the rest of the row: components size to their container, and qa.sh checks
//! none overflows. `meiolol dev` serves it at /gallery (src/site/gallery.zig)
const std = @import("std");
const tree = @import("tree.zig");
const css_mod = @import("css.zig");
const check = @import("check.zig");
const html = @import("html.zig");
const H = tree.H;
const N = tree.N;

pub const State = struct { caption: []const u8, node: N, fill: bool = false };

/// What a component's `pub fn gallery(g: *Gallery) void` adds its states to, once per
/// frame
pub const Gallery = struct {
    h: *H,
    /// The frame's width in px, 0 for the wide one
    width: u16,
    states: std.ArrayList(State) = .empty,

    pub fn add(g: *Gallery, caption: []const u8, n: N) void {
        g.states.append(g.h.mem, .{ .caption = caption, .node = n }) catch {
            g.h.oom = true;
        };
    }

    /// A state that takes its container's width (a Card)
    pub fn addFill(g: *Gallery, caption: []const u8, n: N) void {
        g.states.append(g.h.mem, .{ .caption = caption, .node = n, .fill = true }) catch {
            g.h.oom = true;
        };
    }

    /// An id unique on the page: each state is drawn once per frame
    pub fn id(g: *Gallery, comptime base: []const u8) []const u8 {
        return g.h.fmt(base ++ "-{d}", .{g.width});
    }
};

pub const widths = [_]u16{ 320, 390, 0 };

/// Component C's states in the frame `width`
pub fn states(h: *H, comptime C: type, width: u16) []const State {
    var g: Gallery = .{ .h = h, .width = width };
    C.gallery(&g);
    return g.states.items;
}

/// The gallery's body: a section per component in `all` (ui.all)
pub fn page(h: *H, comptime all: anytype) N {
    // A branch per component unrolled: the default 1000 runs out near a hundred
    @setEvalBranchQuota(4000);
    var toc = h.list();
    var secs = h.list();
    inline for (all) |C| {
        toc.add(h.a(.{ .href = "#" ++ C.scope[0][1..] }, .{C.name}));
        var frames = h.list();
        for (widths) |w| {
            var figs = h.list();
            for (states(h, C, w)) |s| figs.add(h.div(.{ .class = "g-state", .data_fill = s.fill }, .{ s.node, h.span(.{ .class = "g-cap" }, .{s.caption}) }));
            frames.add(h.div(.{
                .class = "g-frame",
                .data_w = if (w == 0) null else w,
                .style = if (w == 0) null else h.vars(.{ .w = w }),
            }, .{figs.done()}));
        }
        secs.add(h.section(.{ .class = "g-sec", .id = C.scope[0][1..] }, .{
            h.h2(.{}, .{ C.name, h.span(.{ .class = "g-scope" }, .{comptime scopeList(C.scope)}) }),
            h.div(.{ .class = "g-frames" }, .{frames.done()}),
        }));
    }
    return h.div(.{ .class = "g-page" }, .{
        h.el(.h1, .{}, .{"Components"}),
        h.el(.nav, .{ .class = "g-toc" }, .{toc.done()}),
        secs.done(),
    });
}

fn scopeList(comptime scope: anytype) []const u8 {
    var s: []const u8 = "";
    for (scope, 0..) |x, i| s = s ++ (if (i == 0) "" else " ") ++ x;
    return s;
}

/// The gallery page's own layout (never shipped to the site)
pub const css =
    \\.g-page { max-width: 1400px; margin: 0 auto; padding: var(--sp-5) var(--gutter); }
    \\.g-toc { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-3); margin: var(--sp-2) 0 var(--sp-5); font-size: var(--fs-s); }
    \\.g-sec { margin-bottom: var(--sp-6); }
    \\.g-sec h2 { display: flex; align-items: baseline; gap: var(--sp-3); margin-bottom: var(--sp-2); }
    \\.g-scope { font: var(--fs-xs) / 1 ui-monospace, monospace; color: var(--faint); }
    \\.g-frames { display: flex; gap: var(--sp-4); align-items: flex-start; flex-wrap: wrap; }
    \\.g-frame { container-type: inline-size; flex: 1 1 360px; min-width: 0; display: flex; flex-direction: column; gap: var(--sp-4);
    \\  padding: var(--sp-3); border: 1px dashed var(--line-2); border-radius: var(--r-m); }
    \\.g-frame:not([data-w]) { flex-basis: 100%; }
    \\.g-frame[data-w] { flex: none; width: calc(var(--w) * 1px); }
    \\.g-frame[data-w]::before { content: attr(data-w) " px"; font-size: var(--fs-xs); color: var(--faint); }
    \\.g-state { display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-1); min-width: 0; }
    \\.g-state > :first-child { max-width: 100%; }
    \\.g-state[data-fill] { align-items: stretch; }
    \\.g-state:has([aria-modal="true"]) { contain: layout; min-height: 600px; }
    \\.g-cap { font-size: var(--fs-xs); color: var(--faint); }
    \\.g-col { display: flex; flex-direction: column; gap: var(--sp-2); }
    \\.g-row { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\
;

const testing = std.testing;

/// Every component in `all`: CSS scoped to its classes and clean under the lint, each
/// state clean under check.zig, and every class its CSS names emitted by some state (a
/// rule no state uses is dead, or a state is missing from the gallery)
pub fn expectSound(comptime all: anytype) !void {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    inline for (all) |C| {
        errdefer std.debug.print("component {s}\n", .{C.name});
        const bad = try css_mod.unscoped(a, C.css, &C.scope);
        for (bad) |s| std.debug.print("unscoped selector: {s}\n", .{s});
        try testing.expectEqual(@as(usize, 0), bad.len);
        const found = try css_mod.lint(a, C.css, .{});
        for (found) |f| std.debug.print("css: {s}\n", .{f.msg});
        try testing.expectEqual(@as(usize, 0), found.len);

        var t: tree.Tree = .{};
        var h: H = .init(a, &t);
        var out: std.Io.Writer.Allocating = .init(a);
        for (widths) |w| for (states(&h, C, w)) |s| {
            try testing.expect(!h.oom);
            t.root = s.node;
            const r = try check.run(a, &t, .{});
            for (r.findings.items) |f| std.debug.print("{s}: {s}\n", .{ s.caption, f.msg });
            try testing.expectEqual(@as(usize, 0), r.findings.items.len);
            try html.write(&t, s.node, &out.writer);
        };
        const written = out.written();
        for (try css_mod.classes(a, C.css)) |c| {
            if (!hasClass(written, c)) {
                std.debug.print("class .{s} in the CSS, in no state\n", .{c});
                return error.DeadClass;
            }
        }
    }
}

fn hasClass(markup: []const u8, c: []const u8) bool {
    var rest = markup;
    while (std.mem.find(u8, rest, "class=\"")) |at| {
        const start = at + "class=\"".len;
        const end = std.mem.findScalarPos(u8, rest, start, '"') orelse return false;
        var it = std.mem.tokenizeScalar(u8, rest[start..end], ' ');
        while (it.next()) |x| if (std.mem.eql(u8, x, c)) return true;
        rest = rest[end..];
    }
    return false;
}
