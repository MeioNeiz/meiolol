//! SkillGrid: a skill order as the 4 x 18 grid of levels (Q, W, E, R rows, the level's
//! number lit in the row of the ability taken), with the order's pick share, win rate and
//! games under it. All 18 levels at any width: cells shrink to 13 px, never cut to 8
const tree = @import("tree.zig");
const bp = @import("buildpanel.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "SkillGrid";
pub const scope = .{".c-skills"};

pub const Path = struct {
    /// The ability taken at each level, up to 18: "WQEQQRQEQEREEWWRWW"
    keys: []const u8,
    games: u32,
    wins: u32,
    /// Share of the slot's players, %
    share: f64,
};

const rows = "QWER";

/// `ref`: the slot's win rate, %, the colour's middle
pub fn view(h: *H, p: Path, ref: f64) N {
    return h.div(.{ .class = "c-skills" }, .{ grid(h, p.keys), figures(h, p.share, p.games, p.wins, ref) });
}

/// One game's order: the grid alone
pub fn order(h: *H, keys: []const u8) N {
    return h.div(.{ .class = "c-skills" }, .{grid(h, keys)});
}

fn grid(h: *H, keys: []const u8) N {
    var cells = h.list();
    for (rows) |key| {
        cells.add(h.b(.{}, .{h.fmt("{c}", .{key})}));
        for (0..18) |i| {
            const on = i < keys.len and keys[i] == key;
            cells.add(h.el(.i, .{ .data_on = if (!on) null else if (key == 'R') "r" else "" }, .{if (on) @as(?u64, i + 1) else null}));
        }
    }
    return h.div(.{ .class = "grid", .role = "img", .aria_label = keys }, .{cells.done()});
}

/// "39% 50.1 10.4k" under the grid
fn figures(h: *H, share: f64, games: u32, wins: u32, ref: f64) N {
    return h.div(.{ .class = "under", .data_state = if (games < bp.solid_games) "thin" else null }, .{
        h.span(.{ .class = "p" }, .{bp.pickText(h, share)}),
        bp.win(h, games, wins, ref),
        h.span(.{ .class = "g" }, .{bp.shortCount(h, games)}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-skills { display: flex; flex-direction: column; gap: var(--sp-1); min-width: 0; }
    \\  .c-skills > .grid { display: grid; grid-template-columns: 14px repeat(18, minmax(0, 1fr)); gap: 2px 1px;
    \\    font-size: var(--fs-xs); font-variant-numeric: tabular-nums; }
    \\  .c-skills > .grid > b { color: var(--t2); font-weight: var(--w-b); display: flex; align-items: center; }
    \\  .c-skills > .grid > i { min-width: 13px; height: 18px; border-radius: 3px; background: var(--panel-2); font-style: normal;
    \\    display: flex; align-items: center; justify-content: center; color: var(--text); overflow: hidden; }
    \\  .c-skills > .grid > i[data-on] { background: var(--accent-bg); box-shadow: inset 0 0 0 1px var(--focus); }
    \\  .c-skills > .grid > i[data-on="r"] { background: color-mix(in oklab, var(--turn) 18%, transparent); box-shadow: inset 0 0 0 1px var(--turn-line); }
    \\  .c-skills > .under { display: flex; justify-content: flex-end; align-items: baseline; gap: var(--sp-2);
    \\    font-size: var(--fs-s); font-variant-numeric: tabular-nums; }
    \\  .c-skills > .under > .p { color: var(--t2); }
    \\  .c-skills > .under > .w { font-weight: var(--w-b); color: var(--c, var(--faint)); min-width: 34px; text-align: right; }
    \\  .c-skills > .under > .g { color: var(--faint); font-size: var(--fs-xs); min-width: 30px; text-align: right; }
    \\  .c-skills > .under[data-state="thin"] > * { opacity: 0.55; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("most played order", view(h, .{ .keys = "WQEQQRQEQEREEWWRWW", .games = 10381, .wins = 5200, .share = 39 }, 50.6));
    g.add("thin: under 400 games", view(h, .{ .keys = "QWEQQRQWQWRWWEEREE", .games = 237, .wins = 106, .share = 0.9 }, 50.6));
    g.add("one game's order", order(h, "QEWQQRQEQERE"));
    g.add("game ended before 18", view(h, .{ .keys = "QEWQQRQEQER", .games = 1200, .wins = 640, .share = 5 }, 50.6));
}
