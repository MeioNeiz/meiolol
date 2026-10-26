//! MatchupStrip: a champion's lane opponents in one row that scrolls sideways, most
//! games first (op.gg's order, not by win rate): each a link with the portrait and the
//! champion's win rate against it, coloured on the scale; the page's opponent lit. The
//! search at the end hides the others (ChampSearch's filter mode, same matching).
//! matchup.md "MatchupGrid strip"
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const champ = @import("champ.zig");
const champsearch = @import("champsearch.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "MatchupStrip";
pub const scope = .{".c-mstrip"};

pub const Item = struct {
    champ: champ.Champ,
    /// The champion's win rate against it: "49.9"
    fig: tree.Text,
    colour: fmt.WrColour,
    href: []const u8,
    current: bool = false,
    thin: bool = false,
};

const W = struct {
    pub const search = plain("Opponent");
    pub const none = plain("No opponent by that name");
};

pub const MatchupStrip = struct {
    items: []const Item,
    /// Over `items`, in their order
    index: *const champsearch.Index,
    search: champsearch.ChampSearch,
    label: tree.Text,

    const S = @This();

    /// `id` unique on the page; `label` names the row ("Darius's Top opponents")
    pub fn init(a: std.mem.Allocator, items: []const Item, id: []const u8, label: tree.Text) !S {
        const entries = try a.alloc(champsearch.Entry, items.len);
        for (entries, items) |*e, it| e.* = .{ .name = it.champ.name, .src = it.champ.src, .href = it.href };
        const ix = try a.create(champsearch.Index);
        ix.* = try .init(a, entries);
        return .{ .items = items, .index = ix, .label = label, .search = .{ .index = ix, .id = id, .mode = .filter, .label = W.search } };
    }

    pub fn view(s: *S, h: *H) N {
        const shown = h.mem.alloc(bool, s.items.len) catch {
            h.oom = true;
            return .none;
        };
        const q = s.search.q.slice();
        @memset(shown, q.len == 0);
        var any = q.len == 0;
        if (q.len > 0) {
            const hits = h.mem.alloc(champsearch.Hit, s.items.len) catch {
                h.oom = true;
                return .none;
            };
            for (s.index.match(q, hits)) |hit| shown[hit.e] = true;
            any = std.mem.findScalar(bool, shown, true) != null;
        }
        var row = h.list();
        for (s.items, shown, 0..) |it, on, i| row.add(h.a(.{
            .key = i,
            .href = it.href,
            .aria_current = if (it.current) "page" else null,
            .data_state = if (it.thin) "thin" else null,
            .hidden = !on,
        }, .{
            champ.view(h, it.champ, .{ .px = .@"32" }),
            h.span(.{ .class = "v", .style = h.vars(.{ .c = it.colour }) }, .{it.fig}),
        }));
        return h.el(.nav, .{ .class = "c-mstrip", .aria_label = s.label }, .{h.div(.{ .class = "in" }, .{
            h.div(.{ .class = "row" }, .{ row.done(), if (!any) h.span(.{ .class = "none" }, .{W.none}) else null }),
            s.search.view(h),
        })});
    }
};

pub const css =
    \\@layer components {
    \\  .c-mstrip { container: mstrip / inline-size; }
    \\  .c-mstrip > .in { display: flex; align-items: center; gap: var(--sp-3); }
    \\  .c-mstrip .row { display: flex; align-items: center; gap: 2px; flex: 1; min-width: 0; overflow-x: auto;
    \\    scrollbar-width: thin; padding: 2px 0; }
    \\  .c-mstrip .row > a { flex: none; display: flex; flex-direction: column; align-items: center; gap: 2px;
    \\    padding: 3px 3px 2px; border-radius: var(--r-s); color: inherit; text-decoration: none; }
    \\  .c-mstrip .row > a:hover { background: var(--panel-2); }
    \\  .c-mstrip .row > a[aria-current="page"] { background: var(--accent-bg); box-shadow: inset 0 0 0 1.5px var(--accent); }
    \\  .c-mstrip .row > [data-state="thin"] { opacity: 0.55; }
    \\  .c-mstrip .row .c-champ { border-radius: var(--r-s); }
    \\  .c-mstrip .v { font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--c); font-variant-numeric: tabular-nums; }
    \\  .c-mstrip .none { padding: 0 var(--sp-2); font-size: var(--fs-s); color: var(--faint); }
    \\  .c-mstrip .c-search { flex: 0 0 160px; }
    \\  @container mstrip (max-width: 480px) {
    \\    .c-mstrip > .in { flex-direction: column; align-items: stretch; gap: var(--sp-2); }
    \\    .c-mstrip .c-search { flex: none; max-width: none; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const names = [_]struct { champ.Champ, []const u8, f64 }{
        .{ champ.demo("Garen", "Garen"), "49.9", -0.1 },
        .{ champ.demo("Sett", "Sett"), "47.4", -2.6 },
        .{ champ.demo("Jayce", "Jayce"), "51.8", 1.8 },
        .{ champ.demo("Mordekaiser", "Mordekaiser"), "50.2", 0.2 },
        .{ champ.demo("Aatrox", "Aatrox"), "45.9", -4.1 },
        .{ champ.demo("Olaf", "Olaf"), "48.0", -2 },
        .{ champ.demo("Malphite", "Malphite"), "47.1", -2.9 },
        .{ champ.demo("Fiora", "Fiora"), "53.3", 3.3 },
        .{ champ.demo("Camille", "Camille"), "49.8", -0.2 },
        .{ champ.demo("Ornn", "Ornn"), "51.5", 1.5 },
        .{ champ.demo("Riven", "Riven"), "52.1", 2.1 },
        .{ champ.demo("Teemo", "Teemo"), "50.9", 0.9 },
    };
    const items = h.mem.alloc(Item, names.len) catch {
        h.oom = true;
        return;
    };
    for (items, names, 0..) |*it, x, i| it.* = .{ .champ = x[0], .fig = .{ .s = x[1] }, .colour = .{ .pts = x[2] }, .href = "#", .current = i == 0, .thin = i == names.len - 1 };
    const states = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "the page's opponent lit, a thin one faded", "ms-a", "" },
        .{ "searched", "ms-b", "ri" },
        .{ "nothing found", "ms-c", "zzz" },
    };
    inline for (states) |st| {
        const s = h.mem.create(MatchupStrip) catch {
            h.oom = true;
            return;
        };
        s.* = MatchupStrip.init(h.mem, items, g.id(st[1]), plain("Darius's Top opponents")) catch {
            h.oom = true;
            return;
        };
        s.search.q.set(st[2]);
        g.addFill(st[0], s.view(h));
    }
}
