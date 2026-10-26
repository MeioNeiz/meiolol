//! ChampList: a short list of champions, one line each: portrait, name (a badge after
//! it), the figure the list is ordered by, a faint note last (share, games). A row can
//! link to the champion's page. Two columns in a wide card (`cols`). A pair (`vs`): both
//! portraits, both names, the figure from the first's side
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const fmt = @import("fmt.zig");
const delta = @import("delta.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "ChampList";
pub const scope = .{".c-clist"};

pub const Row = struct {
    champ: champ.Champ,
    /// The opponent: a matchup row
    vs: ?champ.Champ = null,
    href: ?[]const u8 = null,
    role: ?role.Role = null,
    /// After the name: a Badge
    tag: ?N = null,
    /// The figure the list is ordered by
    value: ?N = null,
    /// Faint, last
    note: ?tree.Text = null,
};

pub const Opts = struct {
    /// Two columns where they fit
    cols: bool = false,
    label: ?tree.Text = null,
};

const W = struct {
    pub const vs = plain("vs ");
};

pub fn view(h: *H, o: Opts, rows: []const Row) N {
    var l = h.list();
    for (rows, 0..) |r, i| {
        const kids = .{
            champ.view(h, r.champ, .{ .named = false }),
            if (r.vs) |y| champ.view(h, y, .{ .named = false }) else null,
            h.span(.{ .class = "nm" }, .{ r.champ.name, if (r.vs) |y| h.span(.{ .class = "vs" }, .{ W.vs, y.name }) else null, r.tag }),
            if (r.role) |x| role.view(h, x, .{ .s = .s }) else null,
            if (r.value) |v| h.span(.{ .class = "v" }, .{v}) else null,
            if (r.note) |n| h.span(.{ .class = "g" }, .{n}) else null,
        };
        l.add(h.li(.{ .key = i }, .{if (r.href) |href| h.a(.{ .href = href }, kids) else h.div(.{}, kids)}));
    }
    return h.ul(.{ .class = "c-clist", .data_v = if (o.cols) "2" else null, .aria_label = o.label }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-clist { list-style: none; margin: 0; padding: 0; }
    \\  .c-clist li > * { display: flex; align-items: center; gap: var(--sp-2); height: var(--row); color: inherit; }
    \\  .c-clist li > a:hover { text-decoration: none; }
    \\  .c-clist li > a:hover .nm { color: var(--accent); }
    \\  .c-clist .nm { display: flex; align-items: center; gap: var(--sp-2); flex: 1; min-width: 0; overflow: hidden;
    \\    white-space: nowrap; }
    \\  .c-clist .nm > .vs { color: var(--t2); overflow: hidden; text-overflow: ellipsis; }
    \\  .c-clist .c-champ + .c-champ { margin-left: calc(-1 * var(--sp-2) - 2px); }
    \\  .c-clist .v { font-weight: var(--w-b); font-variant-numeric: tabular-nums; white-space: nowrap; color: var(--c, inherit); }
    \\  .c-clist .g { min-width: 36px; text-align: right; font-size: var(--fs-xs); color: var(--faint);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-clist[data-v="2"] { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); column-gap: var(--sp-5); }
    \\  .c-clist[data-v="2"]:has(.vs) { grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); }
    \\  .c-clist[data-v="2"] li > * { height: 36px; border-bottom: 1px solid var(--line); }
    \\}
    \\
;

const G = struct {
    pub const harder = plain("harder to pick up");
    pub const also = plain("Darius mains also play");
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const also = [_]struct { champ.Champ, tree.Text, tree.Text, bool }{
        .{ champ.demo("Sett", "Sett"), plain("×3.5"), plain("44%"), false },
        .{ champ.demo("Olaf", "Olaf"), plain("×3.4"), plain("22%"), false },
        .{ champ.demo("Mordekaiser", "Mordekaiser"), plain("×3.0"), plain("45%"), false },
        .{ champ.demo("Garen", "Garen"), plain("×2.9"), plain("49%"), true },
        .{ champ.demo("Aatrox", "Aatrox"), plain("×2.9"), plain("30%"), false },
    };
    var rows: [also.len]Row = undefined;
    for (also, 0..) |x, i| rows[i] = .{
        .champ = x[0],
        .href = "#",
        .tag = if (x[3]) badge.view(h, .neutral, .{G.harder}) else null,
        .value = h.span(.{}, .{x[1]}),
        .note = x[2],
    };
    g.addFill("mains also play: links, a badge", view(h, .{ .label = G.also }, &rows));
    g.addFill("two columns", view(h, .{ .cols = true, .label = G.also }, &rows));
    g.addFill("matchups: pairs, the figure coloured", view(h, .{ .cols = true }, &.{
        .{ .champ = champ.demo("Darius", "Darius"), .vs = champ.demo("Garen", "Garen"), .href = "#", .value = h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(1.2, fmt.win_cuts) }) }, .{plain("51.2%")}), .note = plain("1,788") },
        .{ .champ = champ.demo("Malphite", "Malphite"), .vs = champ.demo("Tryndamere", "Tryndamere"), .href = "#", .value = h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(4.4, fmt.win_cuts) }) }, .{plain("54.4%")}), .note = plain("1,204") },
        .{ .champ = champ.demo("Jax", "Jax"), .vs = champ.demo("Aatrox", "Aatrox"), .role = .top, .href = "#", .value = delta.view(h, .{ .d = 3.1 }), .note = plain("905") },
    }));
    g.addFill("with roles, no links", view(h, .{}, &.{
        .{ .champ = champ.demo("Ahri", "Ahri"), .role = .mid, .value = h.span(.{}, .{plain("+2.4")}), .note = plain("12,040") },
        .{ .champ = champ.demo("Jinx", "Jinx"), .role = .bot, .value = h.span(.{}, .{plain("−1.8")}), .note = plain("9,311") },
    }));
}
