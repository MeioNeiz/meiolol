//! HeatGrid: champions against champions as a grid of points vs usual. Rows and columns
//! are champions (icons, a name when there's room); a cell is the column's champion into
//! the row's, on the fill scale, faded when thin and "·" with no games. A gap can split
//! the columns (a pool, then suggestions), a row can be flagged (a lane nothing covers),
//! a column head can carry a control (Add). Cells can be pressed: both heads light and
//! the host gives one readout line. Pool's weak lanes first; the draft tester's pair
//! square (wip/tester.patch) is rows = columns = seats with a gap between teams
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const champ = @import("champ.zig");
const button = @import("button.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "HeatGrid";
pub const scope = .{".c-heat"};

const W = struct {
    pub const none = plain("·");
    pub const cell = phrase.Phrase("{a:text} into {b:text} {v:text}, {g:text} games");
    pub const empty = phrase.Phrase("{a:text} into {b:text}, no games");
    pub const add = phrase.Phrase("Add {c:text}");
};

pub const Head = struct {
    champ: champ.Champ,
    /// A column's under its icon (a short name), a row's beside it; null: icon only
    label: ?tree.Text = null,
    /// .add: a suggestion, not yet the player's
    state: champ.State = .normal,
    /// Under a column head in place of the label (an Add button)
    under: N = .none,
    /// A row the host flags (a lane nothing covers): its name in the low ink
    flag: bool = false,
    /// A gap before this column
    gap: bool = false,
};

pub const Cell = struct { pp: f32, games: u32 };

pub const Grid = struct {
    /// Over the row heads ("vs")
    corner: ?tree.Text = null,
    rows: []const Head,
    cols: []const Head,
    /// rows.len * cols.len, row-major: the column's champion into the row's; null: no games
    cells: []const ?Cell,
    /// The pressed cell (row, column)
    sel: ?[2]u8 = null,
    /// A handler per cell, same layout; empty: cells aren't pressable
    on: []const tree.Handler = &.{},
    /// Under the grid: the pressed cell's line, or a prompt
    readout: ?N = null,
};

pub fn view(h: *H, g: Grid) N {
    var head = h.list();
    head.add(h.span(.{ .class = "rh" }, .{if (g.corner) |c| h.span(.{ .class = "nm" }, .{c}) else null}));
    for (g.cols, 0..) |c, j| {
        if (c.gap) head.add(h.span(.{ .key = 100 + j, .class = "gap" }, .{}));
        head.add(h.span(.{ .key = j, .class = "ch", .data_lit = lit(g, 1, j) }, .{
            champ.view(h, c.champ, .{ .px = .@"32", .state = c.state, .named = c.label == null }),
            if (c.under != .none) c.under else if (c.label) |l| h.span(.{ .class = "nm" }, .{l}) else null,
        }));
    }
    var rows = h.list();
    rows.add(h.div(.{ .key = 1000, .class = "r hd" }, .{head.done()}));
    for (g.rows, 0..) |r, i| {
        var cs = h.list();
        cs.add(h.span(.{ .class = "rh", .data_lit = lit(g, 0, i), .data_flag = r.flag }, .{
            champ.view(h, r.champ, .{ .state = r.state, .named = r.label == null }),
            if (r.label) |l| h.span(.{ .class = "nm" }, .{l}) else null,
        }));
        for (g.cols, 0..) |c, j| {
            if (c.gap) cs.add(h.span(.{ .key = 100 + j, .class = "gap" }, .{}));
            cs.add(cell(h, g, i, j));
        }
        rows.add(h.div(.{ .key = i, .class = "r" }, .{cs.done()}));
    }
    return h.div(.{ .class = "c-heat" }, .{
        h.div(.{ .class = "m" }, .{rows.done()}),
        if (g.readout) |r| h.p(.{ .class = "read" }, .{r}) else null,
    });
}

/// Whether head `i` of the rows (axis 0) or columns (1) is in the pressed cell
fn lit(g: Grid, axis: u1, i: usize) bool {
    const s = g.sel orelse return false;
    return s[axis] == i;
}

fn cell(h: *H, g: Grid, i: usize, j: usize) N {
    const at = i * g.cols.len + j;
    const a = g.cols[j].champ.name;
    const b = g.rows[i].champ.name;
    const x = (if (at < g.cells.len) g.cells[at] else null) orelse
        return h.span(.{ .key = j, .class = "c", .data_k = "none", .role = "img", .aria_label = W.empty.with(h, .{ .a = a, .b = b }) }, .{W.none});
    const num = phrase.num(h, .points, x.pp);
    const label = W.cell.with(h, .{ .a = a, .b = b, .v = num.s, .g = phrase.num(h, .count, x.games).s });
    const thin = x.games < fmt.thin_games;
    const style = if (thin) null else h.vars(.{ .f = fmt.Step.of(x.pp, fmt.win_cuts).fill() });
    const k: ?[]const u8 = if (thin) "thin" else null;
    if (at >= g.on.len) return h.span(.{ .key = j, .class = "c", .data_k = k, .style = style, .role = "img", .aria_label = label }, .{num});
    const pressed = if (g.sel) |s| s[0] == i and s[1] == j else false;
    return h.button(.{ .key = j, .class = "c", .type = "button", .data_k = k, .style = style, .aria_pressed = pressed, .aria_label = label, .on_click = g.on[at] }, .{num});
}

pub const css =
    \\@layer components {
    \\  .c-heat { container-type: inline-size; width: 100%; min-width: 0; }
    \\  .c-heat .m { display: flex; flex-direction: column; gap: 2px; overflow-x: auto; }
    \\  .c-heat .r { display: flex; gap: 2px; align-items: center; }
    \\  .c-heat .r.hd { align-items: flex-start; margin-bottom: 2px; }
    \\  .c-heat .r.hd > .rh { align-self: flex-end; }
    \\  .c-heat .rh { flex: none; display: flex; align-items: center; gap: 6px; width: 104px; min-width: 0;
    \\    font-size: var(--fs-s); color: var(--t2); }
    \\  .c-heat .rh > .nm { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-heat .r.hd .rh > .nm { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-heat .rh[data-flag] > .nm { color: var(--lo2); font-weight: var(--w-m); }
    \\  .c-heat .ch { flex: none; display: flex; flex-direction: column; align-items: center; gap: 4px; width: 44px; }
    \\  .c-heat .ch > .nm { max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    \\    font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-heat .ch > .c-btn { min-width: 44px; padding: 0 4px; }
    \\  .c-heat .c { box-sizing: border-box; flex: none; display: inline-flex; align-items: center; justify-content: center;
    \\    width: 44px; height: 28px; border: 0; border-radius: var(--r-s); background: var(--f, var(--f-0));
    \\    color: var(--text); font: inherit; font-size: var(--fs-s); font-weight: var(--w-m);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-heat button.c { min-height: 0; cursor: pointer; }
    \\  .c-heat button.c:focus-visible { outline: 2px solid var(--focus); outline-offset: 1px; }
    \\  .c-heat .c[data-k="thin"] { color: var(--muted); }
    \\  .c-heat .c[data-k="none"] { background: none; color: var(--faint); box-shadow: inset 0 0 0 1px var(--line); }
    \\  .c-heat .c[aria-pressed="true"] { box-shadow: 0 0 0 2px var(--text); }
    \\  .c-heat [data-lit] > .c-champ { box-shadow: 0 0 0 2px var(--bg), 0 0 0 3.5px var(--text); }
    \\  .c-heat .gap { flex: none; width: 8px; }
    \\  .c-heat .read { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-1) var(--sp-2);
    \\    margin: var(--sp-2) 0 0; font-size: var(--fs-s); color: var(--t2); }
    \\  @container (max-width: 480px) {
    \\    .c-heat .rh { width: auto; }
    \\    .c-heat .rh > .nm { display: none; }
    \\    .c-heat :is(.ch, .c) { width: 38px; }
    \\    .c-heat .ch > .c-btn { min-width: 38px; }
    \\    .c-heat .gap { width: 4px; }
    \\  }
    \\}
    \\
;

/// Ornn's weak lanes in top: Ornn, Sion and Dr. Mundo, then three suggestions
const demo_rows = [_]struct { []const u8, []const u8, bool }{
    .{ "Fiora", "Fiora", true },
    .{ "Yone", "Yone", true },
    .{ "Garen", "Garen", true },
    .{ "Yorick", "Yorick", false },
    .{ "Darius", "Darius", false },
};
const demo_cols = [_]struct { []const u8, []const u8, []const u8 }{
    .{ "Ornn", "Ornn", "Ornn" },
    .{ "Sion", "Sion", "Sion" },
    .{ "DrMundo", "Dr. Mundo", "Mundo" },
    .{ "Darius", "Darius", "" },
    .{ "Malphite", "Malphite", "" },
    .{ "Kayle", "Kayle", "" },
};
const demo_cells = [30]?Cell{
    .{ .pp = -2.6, .games = 2104 }, .{ .pp = 0, .games = 640 },    .{ .pp = 0, .games = 512 },    .{ .pp = 2.6, .games = 1310 }, .{ .pp = 1.7, .games = 880 },  .{ .pp = 1.5, .games = 702 },
    .{ .pp = -1.7, .games = 1888 }, .{ .pp = -3.5, .games = 590 }, .{ .pp = -2.4, .games = 431 }, .{ .pp = 1.5, .games = 1022 }, .{ .pp = 1.2, .games = 760 },  .{ .pp = -1.9, .games = 655 },
    .{ .pp = -1.4, .games = 1702 }, .{ .pp = 0.1, .games = 512 },  .{ .pp = -2.1, .games = 470 }, .{ .pp = 1.3, .games = 1505 }, .{ .pp = 1.5, .games = 690 },  .{ .pp = 2.3, .games = 610 },
    .{ .pp = -1.2, .games = 990 },  .{ .pp = 1.9, .games = 80 },   .{ .pp = -0.5, .games = 260 }, .{ .pp = -1.9, .games = 702 }, .{ .pp = 0, .games = 410 },    .{ .pp = -1.3, .games = 330 },
    .{ .pp = -0.5, .games = 1650 }, .{ .pp = -1.3, .games = 488 }, .{ .pp = 3.2, .games = 402 },  null,                          .{ .pp = -0.2, .games = 655 }, .{ .pp = 0.7, .games = 590 },
};

const Inert = struct {
    pub const Msg = u8;
    pub fn update(_: *@This(), _: u8, _: *tree.Event) void {}
    var it: @This() = .{};
};

fn demo(h: *H, rows: *[5]Head, cols: *[6]Head) void {
    inline for (rows, demo_rows) |*r, d| r.* = .{ .champ = champ.demo(d[0], d[1]), .label = .{ .s = d[1] }, .flag = d[2] };
    inline for (cols, demo_cols, 0..) |*c, d, j| {
        const add = j >= 3;
        c.* = .{
            .champ = champ.demo(d[0], d[1]),
            .label = if (add) null else .{ .s = d[2] },
            .state = if (add) .add else .normal,
            .under = if (add) button.view(h, .{ .s = .s, .label = W.add.with(h, .{ .c = d[1] }), .on = h.on(&Inert.it, 0) }, .{"+ Add"}) else .none,
            .gap = j == 3,
        };
    }
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const rows = h.mem.create([5]Head) catch {
        h.oom = true;
        return;
    };
    const cols = h.mem.create([6]Head) catch {
        h.oom = true;
        return;
    };
    demo(h, rows, cols);
    g.add("a pool's weak lanes, three to add", view(h, .{ .corner = plain("vs"), .rows = rows, .cols = cols, .cells = &demo_cells }));
    const on = h.mem.alloc(tree.Handler, demo_cells.len) catch {
        h.oom = true;
        return;
    };
    @memset(on, h.on(&Inert.it, 0));
    g.add("pressable, a cell pressed", view(h, .{
        .rows = rows,
        .cols = cols,
        .cells = &demo_cells,
        .sel = .{ 0, 1 },
        .on = on,
        .readout = h.span(.{}, .{plain("Sion into Fiora ±0.0 · 640 games")}),
    }));
}

const testing = std.testing;

test "heat grid: cells by row and column, thin faded, none dotted, gap before suggestions" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var rows: [5]Head = undefined;
    var cols: [6]Head = undefined;
    demo(&h, &rows, &cols);
    const on = try a.alloc(tree.Handler, demo_cells.len);
    @memset(on, h.on(&Inert.it, 0));
    const n = view(&h, .{ .rows = &rows, .cols = &cols, .cells = &demo_cells, .sel = .{ 4, 2 }, .on = on });
    var w: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, n, &w.writer);
    const out = w.written();
    try testing.expectEqual(29, std.mem.count(u8, out, "<button class=\"c\""));
    try testing.expectEqual(1, std.mem.count(u8, out, "data-k=\"none\""));
    try testing.expect(std.mem.find(u8, out, "Darius into Darius, no games") != null);
    // Sion into Yorick: 80 games
    try testing.expectEqual(1, std.mem.count(u8, out, "data-k=\"thin\""));
    try testing.expect(std.mem.find(u8, out, "aria-label=\"Dr. Mundo into Darius +3.2, 402 games\" aria-pressed=\"true\"") != null or
        std.mem.find(u8, out, "aria-pressed=\"true\" aria-label=\"Dr. Mundo into Darius +3.2, 402 games\"") != null);
    // One gap per row and the head row
    try testing.expectEqual(6, std.mem.count(u8, out, "class=\"gap\""));
    try testing.expectEqual(3, std.mem.count(u8, out, "data-flag"));
    try testing.expectEqual(2, std.mem.count(u8, out, "data-lit"));
}
