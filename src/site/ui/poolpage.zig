//! The pool page (pool.html, docs/plan/ui/pool.md): up to five champions, main first,
//! the main's hard lanes against them (HeatGrid) and what to add (CandidateList: hard
//! lanes, when banned, also played). Empty by default: the picker is the page. The main's
//! lanes come from its file (data/pool/<slug>.bin, ui.pooldata), fetched by
//! ui-pool.wasm; the pool rides in the URL (#pool=86-122) and localStorage
const std = @import("std");
const tree = @import("tree.zig");
const card = @import("card.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const rolepicker = @import("rolepicker.zig");
const segmented = @import("segmented.zig");
const champsearch = @import("champsearch.zig");
const poolslots = @import("poolslots.zig");
const heatgrid = @import("heatgrid.zig");
const candlist = @import("candlist.zig");
const pd = @import("pooldata.zig");
const phrase = @import("phrase.zig");
const url = @import("url.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Role = role.Role;
const Why = pd.File.Why;

pub const name = "PoolPage";
pub const scope = .{".c-poolpage"};
pub const sel = "[data-island=pool]";

/// Champions in a pool
pub const max = 5;
/// Columns the grid suggests after the pool
const grid_options = 3;
/// What to add rows (product rule: 3-5 options)
const list_options = 5;
/// By role icons before "All"
const role_shown = 24;

const W = struct {
    pub const title = plain("Champion pool");
    pub const lead = plain("Your champions, their weak lanes, what to add");
    pub const choose = plain("Choose your pool");
    pub const choose_sub = plain("up to 5, main first");
    pub const add_champs = plain("Add champions");
    pub const of_max = Phrase("{n:int} of 5");
    pub const any = plain("Any champion");
    pub const by_role = plain("By role");
    pub const all = Phrase("All {n:int}");
    pub const weak = plain("Weak lanes");
    pub const covered = Phrase("{a:int} of {b:int} covered");
    pub const vs = plain("vs");
    pub const best = plain("Best answer");
    pub const add = Phrase("Add {c:text}");
    pub const add_short = plain("+ Add");
    pub const press = plain("Press a cell for its games");
    pub const read = Phrase("{a:text} into {b:text} {v:text} · {g:text} games");
    pub const read_none = Phrase("{a:text} into {b:text}: no games");
    pub const what = plain("What to add");
    pub const why_label = plain("Reason");
    pub const why_hard = plain("Weak lanes");
    pub const why_banned = plain("Banned");
    pub const why_also = plain("Also played");
    pub const loading = plain("Loading lanes…");
    pub const failed = plain("The lanes didn't load. Reload the page to try again.");
    pub const few = Phrase("Too few {c:text} mains yet for lanes.");
    pub const nothing = plain("Nothing to add for these lanes yet.");
};

pub const Champ = struct {
    id: u16,
    name: []const u8,
    /// Data Dragon's
    key: []const u8,
    slug: []const u8,
};

/// A champion with a pool file
pub const Main = struct {
    /// Champ's index
    c: u16,
    role: Role,
    players: u32,
};

pub const Data = struct {
    ddragon: []const u8,
    /// By name
    champs: []const Champ,
    /// Most players first
    mains: []const Main,
};

pub const Page = struct {
    d: *const Data,
    search: champsearch.ChampSearch,
    /// Champion ids, main first
    pool: [max]u16 = @splat(0),
    n: u8 = 0,
    why: Why = .hard,
    /// The pressed grid cell (row, column)
    cell: ?[2]u8 = null,
    /// By role's tab
    role: Role = .top,
    /// By role shows every main
    all: bool = false,
    /// The main's file once fetched; another champion's after the main changed
    file: ?*const pd.File = null,
    /// The champion whose fetch failed
    failed: u16 = 0,
    /// The server's render: Data as ui.data, base64, for the island
    bin: []const u8 = "",

    const P = @This();

    pub const Url = struct { pool: url.Str(32) = .{}, why: Why = .hard };

    pub const Msg = union(enum) { picked, add: u16, remove: u8, why: Why, cell: [2]u8, role: Role, all, focus };

    /// Builds the search's index over `d.champs`, in `a`
    pub fn init(a: std.mem.Allocator, d: *const Data) !P {
        const entries = try a.alloc(champsearch.Entry, d.champs.len);
        for (entries, d.champs, 0..) |*e, c, i| e.* = .{
            .name = c.name,
            .src = try a.print(icon_fmt, .{ d.ddragon, c.key }),
            .roles = if (mainOf(d, i)) |m| try a.dupe(Role, &.{m.role}) else &.{},
        };
        const ix = try a.create(champsearch.Index);
        ix.* = try .init(a, entries);
        return .{ .d = d, .search = .{ .index = ix, .id = "pool-pick", .mode = .pick, .label = W.any } };
    }

    pub fn ids(p: *const P) []const u16 {
        return p.pool[0..p.n];
    }

    /// The champion whose file the page needs and lacks: the main, when it has one
    pub fn need(p: *const P) ?u16 {
        if (p.n == 0) return null;
        const id = p.pool[0];
        if (p.mainFile() != null or p.failed == id) return null;
        const c = indexOf(p.d, id) orelse return null;
        return if (mainOf(p.d, c) != null) id else null;
    }

    /// The fetch for `id` ended: its file, or null when it failed
    pub fn loaded(p: *P, id: u16, f: ?*const pd.File) void {
        if (f) |x| {
            if (x.id != id or !x.valid()) return p.loaded(id, null);
            p.file = x;
            p.cell = null;
        } else p.failed = id;
    }

    fn mainFile(p: *const P) ?*const pd.File {
        const f = p.file orelse return null;
        return if (p.n > 0 and f.id == p.pool[0]) f else null;
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .picked => {
                const e = p.search.chosen orelse return;
                p.search.chosen = null;
                if (e < p.d.champs.len) p.add(p.d.champs[e].id);
                ev.after = .{ .op = .focus, .ref = "input" };
            },
            .add => |id| p.add(id),
            .remove => |i| {
                if (i >= p.n) return;
                std.mem.copyForwards(u16, p.pool[i .. p.n - 1], p.pool[i + 1 .. p.n]);
                p.n -= 1;
                p.cell = null;
            },
            .why => |w| p.why = w,
            .cell => |c| p.cell = if (p.cell != null and p.cell.?[0] == c[0] and p.cell.?[1] == c[1]) null else c,
            .role => |r| p.role = r,
            .all => p.all = !p.all,
            .focus => {
                ev.after = .{ .op = .focus, .ref = "input" };
                return;
            },
        }
        ev.push = m != .cell;
    }

    fn add(p: *P, id: u16) void {
        if (p.n == max or std.mem.findScalar(u16, p.ids(), id) != null) return;
        p.pool[p.n] = id;
        p.n += 1;
        p.cell = null;
    }

    /// The pool as the URL and localStorage hold it: ids joined by "-"
    pub fn write(p: *const P, w: *std.Io.Writer) std.Io.Writer.Error!void {
        for (p.ids(), 0..) |id, i| try w.print("{s}{d}", .{ if (i > 0) "-" else "", id });
    }

    /// Ids of known champions, repeats and the rest past five dropped
    pub fn read(p: *P, s: []const u8) void {
        p.n = 0;
        p.cell = null;
        var it = std.mem.tokenizeScalar(u8, s, '-');
        while (it.next()) |x| {
            const id = std.fmt.parseInt(u16, x, 10) catch continue;
            if (indexOf(p.d, id) != null) p.add(id);
        }
    }

    pub fn toUrl(p: *const P) Url {
        var u: Url = .{ .why = p.why };
        var buf: [32]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        p.write(&w) catch {};
        u.pool.set(w.buffered());
        return u;
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.read(u.pool.slice());
        p.why = u.why;
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{ .class = "c-poolpage", .data_island = "pool", .data_bin = if (p.bin.len > 0) p.bin else null }, .{
            h.div(.{ .class = "top" }, .{
                h.el(.h1, .{}, .{W.title}),
                h.p(.{ .class = "lead" }, .{W.lead}),
            }),
            if (p.n > 0) p.slots(h) else null,
            if (p.n == 0) p.picker(h, W.choose, W.choose_sub) else h.div(.{ .class = "cols" }, .{
                h.div(.{ .class = "body" }, .{ p.weak(h), p.what(h) }),
                if (p.n < max) p.picker(h, W.add_champs, W.of_max.with(h, .{ .n = p.n })) else null,
            }),
        });
    }

    fn icon(p: *const P, h: *H, id: u16) champ.Champ {
        const c = indexOf(p.d, id) orelse return .{ .name = "?", .src = "" };
        const x = p.d.champs[c];
        return .{ .name = x.name, .src = h.fmt(icon_fmt, .{ p.d.ddragon, x.key }) };
    }

    fn slots(p: *P, h: *H) N {
        const ss = h.mem.alloc(poolslots.Slot, p.n) catch {
            h.oom = true;
            return .none;
        };
        for (ss, p.ids(), 0..) |*s, id, i| s.* = .{
            .champ = p.icon(h, id),
            .role = if (indexOf(p.d, id)) |c| if (mainOf(p.d, c)) |m| m.role else null else null,
            .on_remove = h.on(p, .{ .remove = @intCast(i) }),
        };
        return poolslots.view(h, .{ .slots = ss, .max = max, .on_add = h.on(p, .focus) });
    }

    fn picker(p: *P, h: *H, title: tree.Text, sub: tree.Text) N {
        var items: [Role.all.len]rolepicker.Item = undefined;
        for (Role.all, &items) |r, *it| it.* = .{ .role = r, .current = r == p.role, .on = h.on(p, .{ .role = r }) };
        p.search.on_pick = h.on(p, .picked);
        var icons = h.list();
        var n: u32 = 0;
        for (p.d.mains) |m| {
            if (m.role != p.role or m.c >= p.d.champs.len) continue;
            const id = p.d.champs[m.c].id;
            if (std.mem.findScalar(u16, p.ids(), id) != null) continue;
            n += 1;
            if (!p.all and n > role_shown) continue;
            const c = p.icon(h, id);
            icons.add(h.button(.{ .key = id, .type = "button", .class = "pk", .aria_label = W.add.with(h, .{ .c = c.name }), .on_click = h.on(p, .{ .add = id }) }, .{
                champ.view(h, c, .{ .px = .@"40", .named = false }),
            }));
        }
        return card.view(h, .{ .label = title }, &.{
            card.head(h, title, sub, &.{}),
            h.div(.{ .class = "pick" }, .{
                p.search.view(h),
                h.div(.{ .class = "roles" }, .{
                    h.div(.{ .class = "rh" }, .{
                        h.span(.{ .class = "lab" }, .{W.by_role}),
                        rolepicker.view(h, .{ .v = .compact, .label = W.by_role }, &items),
                    }),
                    h.div(.{ .class = "icons" }, .{icons.done()}),
                    if (n > role_shown) h.button(.{ .type = "button", .aria_expanded = p.all, .on_click = h.on(p, .all) }, .{W.all.with(h, .{ .n = n })}) else null,
                }),
            }),
        });
    }

    fn status(p: *const P, h: *H) tree.Text {
        const id = p.pool[0];
        const c = indexOf(p.d, id) orelse return W.few.with(h, .{ .c = "?" });
        if (mainOf(p.d, c) == null) return W.few.with(h, .{ .c = p.d.champs[c].name });
        return if (p.failed == id) W.failed else W.loading;
    }

    fn weak(p: *P, h: *H) N {
        const f = p.mainFile() orelse return card.view(h, .{ .label = W.weak }, &.{
            card.head(h, W.weak, null, &.{}),
            h.p(.{ .class = "none" }, .{p.status(h)}),
        });
        const have = f.covered(p.ids());
        var opts_buf: [grid_options]pd.File.Option = undefined;
        const opts = f.options(p.ids(), .hard, &opts_buf);
        const rows = h.mem.alloc(heatgrid.Head, f.hard.len) catch return oom(h);
        for (rows, f.hard, 0..) |*r, l, k| {
            const c = p.icon(h, l.id);
            r.* = .{ .champ = c, .label = .{ .s = c.name }, .flag = have & bit(k) == 0 };
        }
        const cols = h.mem.alloc(heatgrid.Head, p.n + opts.len) catch return oom(h);
        // Each column's index in the file; null: a pool champion not playing the role
        const at = h.mem.alloc(?usize, cols.len) catch return oom(h);
        for (p.ids(), 0..) |id, j| {
            const c = p.icon(h, id);
            cols[j] = .{ .champ = c, .label = .{ .s = c.name } };
            at[j] = f.col(id);
        }
        for (opts, p.n..) |o, j| {
            const id = f.cols[o.col].id;
            const c = p.icon(h, id);
            cols[j] = .{ .champ = c, .state = .add, .gap = j == p.n, .under = addButton(p, h, id, c.name) };
            at[j] = o.col;
        }
        const cells = h.mem.alloc(?heatgrid.Cell, rows.len * cols.len) catch return oom(h);
        const on = h.mem.alloc(tree.Handler, cells.len) catch return oom(h);
        for (0..rows.len) |i| for (0..cols.len) |j| {
            cells[i * cols.len + j] = if (at[j]) |c| raw(f, c, i) else null;
            on[i * cols.len + j] = h.on(p, .{ .cell = .{ @intCast(i), @intCast(j) } });
        };
        const s = p.cell;
        const shown = if (s) |x| x[0] < rows.len and x[1] < cols.len else false;
        const readout: N = if (shown) blk: {
            const x = s.?;
            const a = cols[x[1]].champ.name;
            const b = rows[x[0]].champ.name;
            break :blk h.span(.{}, .{if (cells[@as(usize, x[0]) * cols.len + x[1]]) |v| W.read.with(h, .{
                .a = a,
                .b = b,
                .v = phrase.num(h, .points, v.pp).s,
                .g = phrase.num(h, .count, v.games).s,
            }) else W.read_none.with(h, .{ .a = a, .b = b })});
        } else h.span(.{}, .{W.press});
        const count = W.covered.with(h, .{ .a = @popCount(have), .b = f.hard.len });
        return card.view(h, .{ .label = W.weak }, &.{
            card.head(h, W.weak, count, &.{}),
            h.div(.{ .class = "weak" }, .{
                heatgrid.view(h, .{
                    .corner = W.vs,
                    .rows = rows,
                    .cols = cols,
                    .cells = cells,
                    .sel = if (shown) s else null,
                    .on = on,
                    .readout = readout,
                }),
                p.best(h, f, have),
            }),
        });
    }

    /// Each lane the pool leaves open: the champion outside it best into that enemy
    fn best(p: *P, h: *H, f: *const pd.File, have: u8) ?N {
        var list = h.list();
        var n: usize = 0;
        for (f.hard, 0..) |l, k| {
            if (have & bit(k) != 0) continue;
            var top: ?usize = null;
            var top_pp: i16 = pd.min_pp - 1;
            for (f.cols, 0..) |c, i| {
                if (std.mem.findScalar(u16, p.ids(), c.id) != null) continue;
                const x = f.cell(i, k) orelse continue;
                if (x.pp > top_pp) {
                    top = i;
                    top_pp = x.pp;
                }
            }
            const i = top orelse continue;
            const id = f.cols[i].id;
            const c = p.icon(h, id);
            n += 1;
            list.add(h.li(.{ .key = l.id }, .{
                champ.view(h, p.icon(h, l.id), .{}),
                h.span(.{ .class = "to", .aria_hidden = true }, .{"→"}),
                champ.view(h, c, .{ .state = .add, .named = false }),
                h.span(.{ .class = "nm" }, .{c.name}),
                h.b(.{}, .{phrase.num(h, .points, @as(f32, @floatFromInt(top_pp)) / 10)}),
                addButton(p, h, id, c.name),
            }));
        }
        if (n == 0) return null;
        return h.div(.{ .class = "best" }, .{
            h.span(.{ .class = "lab" }, .{W.best}),
            h.ul(.{}, .{list.done()}),
        });
    }

    fn what(p: *P, h: *H) ?N {
        const f = p.mainFile() orelse return null;
        const whys = [_]struct { Why, tree.Text }{ .{ .hard, W.why_hard }, .{ .banned, W.why_banned }, .{ .also, W.why_also } };
        var items: [whys.len]segmented.Item = undefined;
        for (whys, &items) |w, *it| it.* = .{ .label = w[1], .selected = p.why == w[0], .on = h.on(p, .{ .why = w[0] }) };
        var buf: [list_options]pd.File.Option = undefined;
        const opts = f.options(p.ids(), p.why, &buf);
        const rows = h.mem.alloc(candlist.Row, opts.len) catch return oom(h);
        for (rows, opts, 1..) |*r, o, rank| {
            const id = f.cols[o.col].id;
            r.* = .{
                .champ = p.icon(h, id),
                .rank = @intCast(rank),
                .reasons = p.reasons(h, f, o),
                .on = h.on(p, .{ .add = id }),
            };
        }
        return card.view(h, .{ .label = W.what }, &.{
            card.head(h, W.what, null, &.{segmented.view(h, .{ .s = .s, .label = W.why_label }, &items)}),
            if (rows.len == 0) h.p(.{ .class = "none" }, .{W.nothing}) else candlist.view(h, .{ .rows = rows }),
        });
    }

    /// The lanes an option covers, best first: hard lanes, or good ones when banned
    fn reasons(p: *const P, h: *H, f: *const pd.File, o: pd.File.Option) []const candlist.Reason {
        const from = if (p.why == .banned) f.hard.len else 0;
        const lanes = if (p.why == .banned) f.good else f.hard;
        var out = h.mem.alloc(candlist.Reason, @popCount(o.lanes)) catch {
            h.oom = true;
            return &.{};
        };
        var n: usize = 0;
        for (lanes, 0..) |l, k| {
            if (o.lanes & bit(k) == 0 or n == out.len) continue;
            const x = f.cell(o.col, from + k) orelse continue;
            out[n] = .{ .text = .{ .s = p.icon(h, l.id).name }, .pp = @as(f32, @floatFromInt(x.pp)) / 10 };
            n += 1;
        }
        out = out[0..n];
        // Best first; at most 8 lanes
        for (1..n) |i| {
            var j = i;
            while (j > 0 and out[j - 1].pp < out[j].pp) : (j -= 1) std.mem.swap(candlist.Reason, &out[j - 1], &out[j]);
        }
        return out;
    }
};

const icon_fmt = "https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png";

fn addButton(p: *Page, h: *H, id: u16, nm: []const u8) N {
    return h.button(.{ .type = "button", .class = "add", .aria_label = W.add.with(h, .{ .c = nm }), .on_click = h.on(p, .{ .add = id }) }, .{W.add_short});
}

/// Column `c` into lane `k` as the grid shows it: thin cells faded, not dropped
fn raw(f: *const pd.File, c: usize, k: usize) ?heatgrid.Cell {
    const x = f.cells[c * f.lanes() + k];
    if (x.games == 0) return null;
    return .{ .pp = @as(f32, @floatFromInt(x.pp)) / 10, .games = x.games };
}

fn bit(k: usize) u8 {
    return @as(u8, 1) << @intCast(k);
}

fn oom(h: *H) N {
    h.oom = true;
    return .none;
}

pub fn indexOf(d: *const Data, id: u16) ?usize {
    for (d.champs, 0..) |c, i| if (c.id == id) return i;
    return null;
}

pub fn mainOf(d: *const Data, c: usize) ?Main {
    for (d.mains) |m| if (m.c == c) return m;
    return null;
}

pub const css =
    \\@layer components {
    \\  .c-poolpage { container-type: inline-size; display: grid; gap: var(--sp-4); }
    \\  .c-poolpage > .top { display: flex; flex-wrap: wrap; align-items: baseline; gap: var(--sp-1) var(--sp-3); }
    \\  .c-poolpage > .top > h1 { margin: 0; }
    \\  .c-poolpage > .top > .lead { margin: 0; color: var(--muted); }
    \\  .c-poolpage .cols { display: grid; gap: var(--sp-4); }
    \\  .c-poolpage .body { display: grid; gap: var(--sp-4); min-width: 0; }
    \\  @container (min-width: 960px) {
    \\    .c-poolpage .cols { grid-template-columns: minmax(0, 1fr) 340px; align-items: start; }
    \\  }
    \\  .c-poolpage .none { margin: 0; color: var(--faint); }
    \\  .c-poolpage .lab { font-size: var(--fs-xs); font-weight: var(--w-m); text-transform: uppercase;
    \\    letter-spacing: 0.06em; color: var(--muted); }
    \\  .c-poolpage .pick { display: grid; gap: var(--sp-3); }
    \\  .c-poolpage .roles { display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-2); }
    \\  .c-poolpage .roles > .rh, .c-poolpage .icons { align-self: stretch; }
    \\  .c-poolpage .roles > .rh { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-2); }
    \\  .c-poolpage .icons { display: flex; flex-wrap: wrap; gap: var(--sp-1); }
    \\  .c-poolpage .icons > .pk { all: unset; cursor: pointer; border-radius: var(--r-ctl); }
    \\  .c-poolpage .icons > .pk:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-poolpage .icons > .pk:hover { filter: brightness(1.15); }
    \\  .c-poolpage .weak { display: flex; flex-wrap: wrap; gap: var(--sp-4); align-items: flex-start; }
    \\  .c-poolpage .weak > .c-heat { flex: 1 1 340px; width: auto; }
    \\  .c-poolpage .best { flex: 1 1 220px; display: grid; gap: var(--sp-2); min-width: 0; }
    \\  .c-poolpage .best > ul { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--sp-2); }
    \\  .c-poolpage .best li { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-poolpage .best .to { color: var(--faint); }
    \\  .c-poolpage .best .nm { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-poolpage .best b { color: var(--hi2); font-variant-numeric: tabular-nums; }
    \\  .c-poolpage .best .add { margin-left: auto; }
    \\  .c-poolpage .add { min-height: 28px; padding: 0 var(--sp-2); border: 1px solid var(--line);
    \\    border-radius: var(--r-ctl); background: var(--panel-2); color: var(--t2); font: inherit;
    \\    font-size: var(--fs-xs); cursor: pointer; white-space: nowrap; }
    \\  .c-poolpage .c-heat .add { min-height: 22px; padding: 0 3px; }
    \\  .c-poolpage .add:hover { color: var(--t1); border-color: var(--sel-line); }
    \\}
    \\
;

pub const Demo = struct {
    pub const champs = [_]Champ{
        .{ .id = 1, .name = "Darius", .key = "Darius", .slug = "darius" },
        .{ .id = 4, .name = "Dr. Mundo", .key = "DrMundo", .slug = "drmundo" },
        .{ .id = 10, .name = "Fiora", .key = "Fiora", .slug = "fiora" },
        .{ .id = 2, .name = "Garen", .key = "Garen", .slug = "garen" },
        .{ .id = 3, .name = "Jax", .key = "Jax", .slug = "jax" },
        .{ .id = 20, .name = "Teemo", .key = "Teemo", .slug = "teemo" },
        .{ .id = 11, .name = "Yone", .key = "Yone", .slug = "yone" },
        .{ .id = 30, .name = "Ahri", .key = "Ahri", .slug = "ahri" },
    };
    pub const data: Data = .{
        .ddragon = "16.21.1",
        .champs = &champs,
        .mains = &.{
            .{ .c = 0, .role = .top, .players = 400 },
            .{ .c = 3, .role = .top, .players = 310 },
            .{ .c = 4, .role = .top, .players = 120 },
            .{ .c = 7, .role = .mid, .players = 520 },
        },
    };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, []const u16, bool }{
        .{ "empty: the picker is the page", &.{}, false },
        .{ "Darius and Garen: weak lanes, what to add, the picker beside", &.{ 1, 2 }, true },
        .{ "a main with no file: too few mains", &.{20}, false },
    };
    for (states, 0..) |st, k| {
        const p = h.mem.create(Page) catch {
            h.oom = true;
            return;
        };
        p.* = Page.init(h.mem, &Demo.data) catch {
            h.oom = true;
            return;
        };
        p.search.id = h.fmt("{s}-{d}", .{ g.id("pool-pick"), k });
        for (st[1]) |id| p.add(id);
        if (st[2]) p.file = &pd.demo;
        g.addFill(st[0], p.view(h));
    }
}

const testing = std.testing;

fn render(a: std.mem.Allocator, p: *Page) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    t.root = p.view(&h);
    if (h.oom) return error.OutOfMemory;
    var w: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, t.root, &w.writer);
    return w.written();
}

test "pool page: empty is the picker; the URL's pool keeps known champions, five at most" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: Page = try .init(a, &Demo.data);
    const empty = try render(a, &p);
    try testing.expect(std.mem.find(u8, empty, "Choose your pool") != null);
    try testing.expect(std.mem.find(u8, empty, "c-slots") == null);
    // By role, top: Darius, Garen, Jax; Ahri plays mid
    try testing.expectEqual(3, std.mem.count(u8, empty, "class=\"pk\""));

    p.read("2-1-999-2-3-4-10-11");
    try testing.expectEqual(5, p.n);
    try testing.expectEqualSlices(u16, &.{ 2, 1, 3, 4, 10 }, p.ids());
    try testing.expectEqualStrings("2-1-3-4-10", p.toUrl().pool.slice());
    const full = try render(a, &p);
    try testing.expect(std.mem.find(u8, full, "Add champions") == null);
    p.read("");
    try testing.expectEqual(0, p.n);
}

test "pool page: the main's file, its need, the grid, the best answers and what to add" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: Page = try .init(a, &Demo.data);
    try testing.expectEqual(null, p.need());
    p.read("1");
    try testing.expectEqual(1, p.need());
    const loading = try render(a, &p);
    try testing.expect(std.mem.find(u8, loading, "Loading lanes") != null);
    p.loaded(1, null);
    try testing.expectEqual(null, p.need());
    try testing.expect(std.mem.find(u8, try render(a, &p), "load. Reload") != null);

    // Another champion's file never stands in for the main's
    var bad = pd.demo;
    bad.id = 2;
    p.failed = 0;
    p.loaded(1, &bad);
    try testing.expectEqual(null, p.file);

    p.loaded(1, &pd.demo);
    try testing.expectEqual(null, p.need());
    const out = try render(a, &p);
    try testing.expect(std.mem.find(u8, out, "0 of 2 covered") != null);
    // Add under the three suggested columns (Jax, Garen, Mundo), both best answers (Jax)
    // and PoolSlots' own
    try testing.expectEqual(6, std.mem.count(u8, out, "<button type=\"button\" class=\"add\""));
    try testing.expectEqual(2, std.mem.count(u8, out, "data-flag"));
    // Best answers: Jax into Fiora +2.5, Jax into Yone +1.8
    try testing.expect(std.mem.find(u8, out, "class=\"best\"") != null);
    try testing.expect(std.mem.find(u8, out, "aria-label=\"Add Jax\"") != null);
    try testing.expect(std.mem.find(u8, out, "class=\"c-cand\"") != null);

    p.add(3);
    const both = try render(a, &p);
    try testing.expect(std.mem.find(u8, both, "2 of 2 covered") != null);
    try testing.expect(std.mem.find(u8, both, "class=\"best\"") == null);
    try testing.expectEqual(0, std.mem.count(u8, both, "data-flag"));

    // A main without a file needs none and says so
    p.read("20");
    try testing.expectEqual(null, p.need());
    try testing.expect(std.mem.find(u8, try render(a, &p), "Too few Teemo mains yet") != null);
}
