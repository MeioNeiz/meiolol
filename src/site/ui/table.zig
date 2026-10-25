//! DataTable: a real table where the data is a table, as an island. A page declares its
//! columns once (cell, sort value, priority, the one answer column) and the compiler
//! checks the guardrails; the same struct renders on the server (the default state) and
//! in ui.wasm (sorted, searched, cut by a minimum, a row's detail open), so server and
//! client order can't disagree. Rendered as a flush Card: a head band with the title,
//! the count shown, search and MinGames, then the table. Columns of priority 2 and 3
//! give way in narrow containers (420 and 560 px)
//!
//!     const Opp = ui.table.DataTable(Row, .{
//!         .title = plain("Lane opponents"),
//!         .columns = &.{
//!             .{ .label = plain("Champion"), .cell = who, .name = name, .num = false },
//!             .{ .label = plain("Win rate"), .cell = rate, .sort = wr, .answer = true },
//!         },
//!         .search = name,
//!         .games = games,
//!         .min_games = &.{ 0, 300, 1000 },
//!     });
const std = @import("std");
const tree = @import("tree.zig");
const url = @import("url.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const card = @import("card.zig");
const segmented = @import("segmented.zig");
const stat = @import("stat.zig");
const delta = @import("delta.zig");
const bar = @import("bar.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "DataTable";
pub const scope = .{ ".c-table-wrap", ".c-table" };

const W = struct {
    pub const find = plain("Find");
    pub const any = plain("Any");
    pub const min_games = plain("Min games");
};

pub fn Column(comptime Row: type) type {
    return struct {
        label: tree.Text,
        /// The cell's content
        cell: *const fn (*H, *const Row) N,
        /// A number to sort by, highest first; null and no `name`: not sortable
        sort: ?*const fn (*const Row) f64 = null,
        /// Text to sort by, A to Z first
        name: ?*const fn (*const Row) []const u8 = null,
        /// Right-aligned figures
        num: bool = true,
        /// 1 always shown; 2 hidden under 420 px of container, 3 under 560
        priority: u2 = 1,
        /// The column that answers the table's question (one per table)
        answer: bool = false,
    };
}

pub fn Spec(comptime Row: type) type {
    return struct {
        title: tree.Text,
        columns: []const Column(Row),
        /// The column sorted at first
        default_sort: u8 = 0,
        /// Text the search box matches, ignoring case
        search: ?*const fn (*const Row) []const u8 = null,
        /// The row's games: under the minimum the row hides, under fmt.thin_games it fades
        games: ?*const fn (*const Row) u32 = null,
        /// MinGames choices; 0 is Any (thin rows shown, faded)
        min_games: []const u32 = &.{},
        /// What opens under a row when it is tapped
        detail: ?*const fn (*H, *const Row) N = null,
    };
}

pub fn DataTable(comptime Row: type, comptime spec: Spec(Row)) type {
    comptime {
        var answers = 0;
        for (spec.columns) |c| {
            answers += @intFromBool(c.answer);
            if (c.label.s.len > 16) @compileError("column label \"" ++ c.label.s ++ "\" over 16 characters");
            var spaces = 0;
            for (c.label.s) |ch| spaces += @intFromBool(ch == ' ');
            if (spaces > 1) @compileError("column label \"" ++ c.label.s ++ "\" over 2 words");
        }
        if (answers != 1) @compileError(std.fmt.comptimePrint("{d} answer columns: mark exactly one .answer", .{answers}));
        const d = spec.columns[spec.default_sort];
        if (d.sort == null and d.name == null) @compileError("the default sort column has no sort value");
        if (spec.min_games.len > 0 and spec.games == null) @compileError("min_games needs .games");
    }
    const ncols = spec.columns.len;
    // Each column's td and th classes, with and without `sorted`, made once at compile time
    const classes = comptime blk: {
        var plain_c: [ncols][]const u8 = undefined;
        var sorted_c: [ncols][]const u8 = undefined;
        for (spec.columns, 0..) |c, i| {
            const base = (if (c.num) "num" else "") ++ (if (c.priority >= 2) (if (c.num) " " else "") ++ std.fmt.comptimePrint("p{d}", .{c.priority}) else "");
            plain_c[i] = base;
            sorted_c[i] = base ++ (if (base.len > 0) " " else "") ++ "sorted";
        }
        break :blk .{ plain_c, sorted_c };
    };

    return struct {
        rows: []const Row,
        sort: u8 = spec.default_sort,
        desc: bool = !isName(spec.default_sort),
        q: url.Str(24) = .{},
        /// Index into spec.min_games
        min: u8 = 0,
        /// The row whose detail is open (an index into rows)
        open: ?u32 = null,

        const T = @This();

        pub const Msg = union(enum) { sort: u8, search, min: u8, open: u32 };

        /// One DataTable per page writes these to the URL
        pub const Url = struct {
            sort: u8 = spec.default_sort,
            desc: bool = !isName(spec.default_sort),
            q: url.Str(24) = .{},
            min: u8 = 0,
        };

        pub fn toUrl(t: *const T) Url {
            return .{ .sort = t.sort, .desc = t.desc, .q = t.q, .min = t.min };
        }

        pub fn fromUrl(t: *T, u: Url) void {
            t.sort = if (u.sort < ncols and sortable(u.sort)) u.sort else spec.default_sort;
            t.desc = u.desc;
            t.q = u.q;
            t.min = if (u.min < spec.min_games.len) u.min else 0;
        }

        fn isName(i: u8) bool {
            return spec.columns[i].sort == null;
        }

        fn sortable(i: u8) bool {
            return spec.columns[i].sort != null or spec.columns[i].name != null;
        }

        pub fn update(t: *T, m: Msg, ev: *tree.Event) void {
            switch (m) {
                .sort => |i| {
                    t.desc = if (t.sort == i) !t.desc else !isName(i);
                    t.sort = i;
                    ev.push = true;
                },
                .search => t.q.set(ev.text),
                .min => |i| {
                    t.min = i;
                    ev.push = true;
                },
                .open => |i| t.open = if (t.open == i) null else i,
            }
        }

        fn minimum(t: *const T) u32 {
            return if (spec.min_games.len > 0) spec.min_games[t.min] else 0;
        }

        /// The rows shown, in order (indexes into rows)
        pub fn order(t: *const T, a: std.mem.Allocator) ![]u32 {
            var out: std.ArrayList(u32) = try .initCapacity(a, t.rows.len);
            const q = t.q.slice();
            const min = t.minimum();
            for (t.rows, 0..) |*r, i| {
                if (spec.games) |g| if (g(r) < min) continue;
                if (spec.search) |s| if (q.len > 0 and std.ascii.findIgnoreCase(s(r), q) == null) continue;
                out.appendAssumeCapacity(@intCast(i));
            }
            std.sort.pdq(u32, out.items, t, before);
            return out.items;
        }

        /// Ties keep the data's order, in either direction
        fn before(t: *const T, a: u32, b: u32) bool {
            const c = spec.columns;
            const x = &t.rows[a];
            const y = &t.rows[b];
            const ord: std.math.Order = inline for (c, 0..) |col, i| {
                if (t.sort == i) {
                    if (col.sort) |f| break std.math.order(f(x), f(y));
                    if (col.name) |f| break std.ascii.orderIgnoreCase(f(x), f(y));
                    break .eq;
                }
            } else .eq;
            if (ord == .eq) return a < b;
            return if (t.desc) ord == .gt else ord == .lt;
        }

        pub fn view(t: *T, h: *H) N {
            const shown = t.order(h.mem) catch {
                h.oom = true;
                return .none;
            };
            var ths = h.list();
            inline for (spec.columns, 0..) |col, i| {
                const sorted = t.sort == i;
                const cls = if (sorted) classes[1][i] else classes[0][i];
                const label = if (comptime col.sort != null or col.name != null)
                    h.button(.{ .type = "button", .on_click = h.on(t, .{ .sort = i }) }, .{col.label})
                else
                    h.text(col.label.s);
                ths.add(h.th(.{
                    .class = if (cls.len > 0) cls else null,
                    .aria_sort = if (sorted) (if (t.desc) "descending" else "ascending") else null,
                    .data_answer = col.answer,
                }, .{label}));
            }
            var trs = h.list();
            const min = t.minimum();
            for (shown) |ri| {
                const r = &t.rows[ri];
                var tds = h.list();
                inline for (spec.columns, 0..) |col, i| {
                    const cls = if (t.sort == i) classes[1][i] else classes[0][i];
                    tds.add(h.td(.{ .class = if (cls.len > 0) cls else null }, .{col.cell(h, r)}));
                }
                const thin = if (spec.games) |g| min == 0 and g(r) < fmt.thin_games else false;
                const open = t.open == ri;
                trs.add(h.tr(.{
                    .key = ri,
                    .data_state = if (thin) "thin" else null,
                    .aria_expanded = if (spec.detail != null) open else null,
                    .on_click = if (spec.detail != null) h.on(t, .{ .open = ri }) else null,
                }, .{tds.done()}));
                if (spec.detail) |d| if (open) trs.add(h.tr(.{ .key = ri | 0x8000_0000, .class = "detail" }, .{
                    h.td(.{ .colspan = ncols }, .{d(h, r)}),
                }));
            }
            var controls = h.list();
            if (spec.search != null) controls.add(h.input(.{
                .type = "search",
                .placeholder = W.find,
                .aria_label = W.find,
                .value = t.q.slice(),
                .on_input = h.on(t, .search),
            }));
            if (spec.min_games.len > 0) {
                var items: [spec.min_games.len]segmented.Item = undefined;
                for (spec.min_games, 0..) |g, i| items[i] = .{
                    .label = if (g == 0) W.any else minLabel(h, g),
                    .selected = t.min == i,
                    .on = h.on(t, .{ .min = @intCast(i) }),
                };
                controls.add(segmented.view(h, .{ .s = .s, .label = W.min_games }, &items));
            }
            return card.view(h, .{ .flush = true }, &.{
                card.head(h, spec.title, phrase.num(h, .count, shown.len), controls.done()),
                h.div(.{ .class = "c-table-wrap" }, .{h.table(.{ .class = "c-table" }, .{
                    h.thead(.{}, .{h.tr(.{}, .{ths.done()})}),
                    h.tbody(.{}, .{trs.done()}),
                })}),
            });
        }
    };
}

/// 300, 1k, 2.5k
fn minLabel(h: *H, g: u32) tree.Text {
    if (g < 1000) return phrase.num(h, .count, g);
    var out: std.Io.Writer.Allocating = .init(h.mem);
    fmt.fixed(&out.writer, @as(f64, @floatFromInt(g)) / 1000, 1, true) catch {
        h.oom = true;
    };
    out.writer.writeByte('k') catch {
        h.oom = true;
    };
    return .{ .s = out.written() };
}

pub const css =
    \\@layer components {
    \\  .c-table-wrap { container-type: inline-size; overflow-x: auto; }
    \\  .c-table { font-size: var(--fs-m); }
    \\  .c-table thead th { position: sticky; top: 0; z-index: 1; background: var(--th-bg); height: 32px;
    \\    border-bottom-color: var(--line-2); }
    \\  .c-table th > button { all: unset; cursor: pointer; user-select: none; }
    \\  .c-table th > button:hover { color: var(--text); }
    \\  .c-table th > button:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; border-radius: 2px; }
    \\  .c-table th[aria-sort] { color: var(--text); box-shadow: inset 0 calc(-1 * var(--tab-bar)) 0 var(--accent); }
    \\  .c-table th[aria-sort] > button::after { color: var(--accent); margin-left: 3px; font-size: var(--fs-xs); }
    \\  .c-table th[aria-sort="ascending"] > button::after { content: "▲"; }
    \\  .c-table th[aria-sort="descending"] > button::after { content: "▼"; }
    \\  .c-table td.sorted { background: var(--wash); }
    \\  .c-table tbody tr[aria-expanded] { cursor: pointer; }
    \\  .c-table tbody tr:hover > td { background: var(--panel-2); }
    \\  .c-table tbody tr[aria-expanded="true"] > td { background: var(--panel-2); border-bottom-color: transparent; }
    \\  .c-table tr[data-state="thin"] > td { color: var(--muted); }
    \\  .c-table tr[data-state="thin"] .c-stat > .v { opacity: 0.5; }
    \\  .c-table tr.detail > td { padding: 0 var(--sp-3) var(--sp-3); background: var(--panel-2); height: auto; white-space: normal; }
    \\  .c-table td:first-child, .c-table th:first-child { padding-left: var(--sp-3); }
    \\  .c-table td:last-child, .c-table th:last-child { padding-right: var(--sp-3); }
    \\  .c-table .c-bar { justify-content: flex-end; }
    \\  @container (max-width: 560px) { .c-table .p3 { display: none; } }
    \\  @container (max-width: 420px) { .c-table .p2 { display: none; } .c-table .c-bar > span { display: none; } }
    \\}
    \\
;

/// The gallery's fixture, and table_test.zig's
pub const Demo = struct {
    name: []const u8,
    role: []const u8,
    /// Win rate, %
    wr: f32,
    games: u32,
    /// Pick rate, %
    pick: f32,
    /// Points since last patch
    change: f32,

    pub const rows = [_]Demo{
        .{ .name = "Ahri", .role = "Mid", .wr = 51.2, .games = 44935, .pick = 11.1, .change = 0.4 },
        .{ .name = "Darius", .role = "Top", .wr = 51.3, .games = 23166, .pick = 8.2, .change = 2.6 },
        .{ .name = "Kha'Zix", .role = "Jungle", .wr = 51.4, .games = 20188, .pick = 7.5, .change = 2.6 },
        .{ .name = "Miss Fortune", .role = "Bot", .wr = 51.4, .games = 23287, .pick = 9.9, .change = 2.0 },
        .{ .name = "Renata Glasc", .role = "Support", .wr = 46.7, .games = 6017, .pick = 2.1, .change = -4.4 },
        .{ .name = "Viktor", .role = "Mid", .wr = 47.3, .games = 23444, .pick = 8.3, .change = -3.2 },
        .{ .name = "Qiyana", .role = "Mid", .wr = 45.4, .games = 4876, .pick = 1.7, .change = -3.1 },
        .{ .name = "Tristana", .role = "Bot", .wr = 48.9, .games = 36250, .pick = 12.8, .change = -2.5 },
        .{ .name = "Aurelion Sol", .role = "Mid", .wr = 53.8, .games = 274, .pick = 0.1, .change = 1.1 },
        .{ .name = "Zilean", .role = "Support", .wr = 49.5, .games = 61, .pick = 0.02, .change = 0 },
    };

    fn nameOf(r: *const Demo) []const u8 {
        return r.name;
    }
    fn gamesOf(r: *const Demo) u32 {
        return r.games;
    }
    fn wrOf(r: *const Demo) f64 {
        return r.wr;
    }
    fn gamesF(r: *const Demo) f64 {
        return @floatFromInt(r.games);
    }
    fn pickOf(r: *const Demo) f64 {
        return r.pick;
    }
    fn changeOf(r: *const Demo) f64 {
        return r.change;
    }
    fn who(h: *H, r: *const Demo) N {
        return h.b(.{}, .{r.name});
    }
    fn roleCell(h: *H, r: *const Demo) N {
        return h.span(.{ .class = "muted" }, .{r.role});
    }
    fn rate(h: *H, r: *const Demo) N {
        return stat.view(h, .{ .value = r.wr, .scale = .aggregate, .ref = 50 });
    }
    fn pickBar(h: *H, r: *const Demo) N {
        return bar.view(h, r.pick, 12.8, stat.figure(h, .rate, r.pick));
    }
    fn changeCell(h: *H, r: *const Demo) N {
        return delta.view(h, .{ .d = r.change, .arrow = true });
    }
    fn gamesCell(h: *H, r: *const Demo) N {
        return h.span(.{}, .{phrase.num(h, .count, r.games)});
    }
    fn detail(h: *H, r: *const Demo) N {
        return h.p(.{ .class = "muted" }, .{ r.name, " in ", r.role, ": the matchups and builds open here" });
    }

    pub const Table = DataTable(Demo, .{
        .title = plain("Champions"),
        .columns = &.{
            .{ .label = plain("Champion"), .cell = who, .name = nameOf, .num = false },
            .{ .label = plain("Role"), .cell = roleCell, .num = false, .priority = 3 },
            .{ .label = plain("Win rate"), .cell = rate, .sort = wrOf, .answer = true },
            .{ .label = plain("Patch"), .cell = changeCell, .sort = changeOf, .priority = 2 },
            .{ .label = plain("Pick"), .cell = pickBar, .sort = pickOf, .priority = 2 },
            .{ .label = plain("Games"), .cell = gamesCell, .sort = gamesF, .priority = 3 },
        },
        .default_sort = 2,
        .search = nameOf,
        .games = gamesOf,
        .min_games = &.{ 0, 300, 1000 },
        .detail = detail,
    });
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, Demo.Table }{
        .{ "default: win rate, thin rows faded", .{ .rows = &Demo.rows } },
        .{ "by games, fewest first", .{ .rows = &Demo.rows, .sort = 5, .desc = false } },
        .{ "searched", .{ .rows = &Demo.rows, .q = blk: {
            var q: url.Str(24) = .{};
            q.set("ri");
            break :blk q;
        } } },
        .{ "min 300 games, a row open", .{ .rows = &Demo.rows, .min = 1, .open = 0 } },
    };
    for (states) |s| {
        const t = h.mem.create(Demo.Table) catch {
            h.oom = true;
            return;
        };
        t.* = s[1];
        g.addFill(s[0], t.view(h));
    }
}
