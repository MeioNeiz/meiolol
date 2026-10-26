//! BuildPanel: the champion's whole build in one panel, as an island. RuneTree on the
//! left; on the right the slot cells (Spells, Start, Boots / Core / Item 4, 5, 6 /
//! Skills) in a 3-column grid, pairs in a narrow container. Each cell lists its top 3
//! options as compact DataTable rows, most played first: pick share, win rate coloured
//! against the slot's own (which choice is better here, Jacob 25 Oct), the quieter
//! reading after it (the rate minus the champion's, wide cells only), games. The slot's
//! highest win rate on solid_games is marked "best", a 4th row when not in the top 3.
//! Most picked | Highest WR (lolalytics' build toggle, Jacob 26 Oct) re-sorts every cell
//! by win rate, options under solid_games after. Tap a cell's "all" to open it across
//! the panel: every option, named, sortable. One open at a time; it and the order in
//! the URL. The figures' names are said once, above the cells. Data is plain, so a page
//! can hand it builds filtered by a choice (contextual builds, builds.md answers) later
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const art = @import("art.zig");
const button = @import("button.zig");
const toggletip = @import("toggletip.zig");
const segmented = @import("segmented.zig");
const table = @import("table.zig");
const runetree = @import("runetree.zig");
const skillgrid = @import("skillgrid.zig");
const itempath = @import("itempath.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "BuildPanel";
pub const scope = .{".c-build"};

/// Under this many games an option shows no win rate (±10 points at 100 games)
pub const rate_games = 100;
/// Under this many games an option fades, can't be "best" and sorts after the others by
/// win rate
pub const solid_games = 400;
/// Options in a closed cell
pub const shown = 3;

pub const Kind = enum {
    spells,
    start,
    boots,
    core,
    item4,
    item5,
    item6,
    /// Skill priority: "QEW"
    skills,
    /// Levels 1 to 18: drawn as the SkillGrid in the Skills cell
    skill_path,

    fn title(k: Kind) tree.Text {
        return switch (k) {
            .spells => plain("Spells"),
            .start => plain("Start"),
            .boots => plain("Boots"),
            .core => plain("Core"),
            .item4 => plain("Item 4"),
            .item5 => plain("Item 5"),
            .item6 => plain("Item 6"),
            .skills, .skill_path => plain("Skills"),
        };
    }
};
const n_kinds = @typeInfo(Kind).@"enum".field_names.len;

/// The cells' order: most played or highest win rate first
pub const Order = enum { pick, win };

pub const Option = struct {
    /// Spells, items, a path's items
    art: []const art.Art = &.{},
    /// Skill orders: "QEW", or the level path "WQEQQRQEQEREEWWRWW"
    keys: []const u8 = "",
    /// Its name in the open cell ("Flash Ghost"); items and paths name themselves
    name: []const u8 = "",
    games: u32,
    wins: u32,
    /// Median minute each item was bought, 0 when unknown
    minutes: []const f32 = &.{},
};

pub const Slot = struct {
    kind: Kind,
    /// Players the slot counts (those who finished four items, for Item 4)
    games: u32,
    wins: u32,
    /// Most played first
    options: []const Option,
};

pub const Data = struct {
    runes: runetree.Data,
    /// Any order; a kind with no options draws no cell
    slots: []const Slot,
    champion: []const u8,
    /// The champion's win rate in the role, %: the quieter reading's middle
    own: f64,
};

const W = struct {
    pub const pick = plain("pick");
    pub const won = plain("won");
    pub const games = plain("games");
    pub const fewer = plain("fewer");
    pub const all = Phrase("all {n:int}");
    pub const own_term = Phrase("vs {r:rate}");
    pub const own_title = plain("The small figure");
    pub const own_note = Phrase("The choice's win rate minus {c:text}'s {r:rate}. Late items read high: games that reach them were often won already.");
    pub const min = plain("min");
    pub const best = plain("best");
    pub const order = plain("Order");
    pub const most_picked = plain("Most picked");
    pub const highest = plain("Highest WR");
};

/// Win rate, %
pub fn rate(games: u32, wins: u32) f64 {
    return 100 * @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(@max(games, 1)));
}

/// "49.7" coloured on the scale around `ref`, or a dot under rate_games
pub fn win(h: *H, games: u32, wins: u32, ref: f64) N {
    if (games < rate_games) return h.span(.{ .class = "w" }, .{"·"});
    const r = rate(games, wins);
    return h.span(.{ .class = "w", .style = h.vars(.{ .c = fmt.WrColour{ .pts = r - ref } }) }, .{phrase.num(h, .dec, r)});
}

/// "52%", "<1%"
pub fn pickText(h: *H, share: f64) tree.Text {
    if (share < 1) return plain("<1%");
    return phrase.num(h, .pct, @as(u32, @intFromFloat(@round(share))));
}

/// A count in a narrow column: 950, 9.5k, 14k
pub fn shortCount(h: *H, n: u32) tree.Text {
    if (n < 1000) return phrase.num(h, .int, n);
    var out: std.Io.Writer.Allocating = .init(h.mem);
    if (n < 10_000) fmt.fixed(&out.writer, @as(f64, @floatFromInt(n)) / 1000, 1, true) catch {} else out.writer.print("{d}", .{n / 1000}) catch {};
    out.writer.writeByte('k') catch {
        h.oom = true;
    };
    return .{ .s = out.written() };
}

/// A cell's rows share their slot's figures
const Ctx = struct {
    kind: Kind,
    games: u32,
    /// The slot's win rate: the colour's middle
    ref: f64,
    own: f64,
    open: bool = false,
    /// Core: the most played path, whose items dim in the others
    top: []const art.Art = &.{},
    /// The highest win rate of two or more options on solid_games
    best: ?*const Option = null,
};

/// The highest win rate on solid_games, when two or more options have that many
fn bestOf(options: []const Option) ?*const Option {
    var best: ?*const Option = null;
    var solid: usize = 0;
    for (options) |*o| {
        if (o.games < solid_games) continue;
        solid += 1;
        if (best == null or rate(o.games, o.wins) > rate(best.?.games, best.?.wins)) best = o;
    }
    return if (solid >= 2) best else null;
}

pub const Row = struct {
    o: *const Option,
    c: *const Ctx,

    fn share(r: *const Row) f64 {
        return 100 * @as(f64, @floatFromInt(r.o.games)) / @as(f64, @floatFromInt(@max(r.c.games, 1)));
    }
    fn games(r: *const Row) u32 {
        return r.o.games;
    }
    fn gamesF(r: *const Row) f64 {
        return @floatFromInt(r.o.games);
    }
    fn winSort(r: *const Row) f64 {
        return if (r.o.games < solid_games) -1 else rate(r.o.games, r.o.wins);
    }

    fn what(h: *H, r: *const Row) N {
        const o = r.o;
        const open = r.c.open;
        return switch (r.c.kind) {
            .core => h.span(.{ .class = "what" }, .{ itempath.view(h, o.art, .{ .minutes = o.minutes, .top = if (r.c.top.ptr == o.art.ptr) null else r.c.top }), bestMark(h, r) }),
            .skills => h.span(.{ .class = "what" }, .{ h.span(.{ .class = "keys" }, .{keys(h, o.keys, true)}), bestMark(h, r) }),
            .skill_path => h.span(.{ .class = "keys", .data_v = "path" }, .{keys(h, o.keys, false)}),
            else => blk: {
                var icons = h.list();
                for (o.art) |a| icons.add(art.view(h, a, .{ .k = if (r.c.kind == .spells) .spell else .item, .named = !open }));
                const label: ?[]const u8 = if (!open) null else if (o.name.len > 0) o.name else if (o.art.len == 1) o.art[0].name else null;
                const minute: ?N = if (open and o.minutes.len == 1 and o.minutes[0] > 0)
                    h.span(.{ .class = "min" }, .{ phrase.num(h, .int, @as(u32, @intFromFloat(@round(o.minutes[0])))), " ", W.min })
                else
                    null;
                break :blk h.span(.{ .class = "what" }, .{ icons.done(), if (label) |l| h.span(.{ .class = "nm" }, .{l}) else null, minute, bestMark(h, r) });
            },
        };
    }

    fn bestMark(h: *H, r: *const Row) ?N {
        return if (r.c.best == r.o) h.span(.{ .class = "best" }, .{W.best}) else null;
    }

    /// "Q › E › W", or the level path with R bold
    fn keys(h: *H, s: []const u8, arrows: bool) []const N {
        var out = h.list();
        for (s, 0..) |k, i| {
            if (arrows and i > 0) out.add(h.span(.{ .class = "ar" }, .{"›"}));
            const t = h.fmt("{c}", .{k});
            out.add(if (k == 'R') h.b(.{}, .{t}) else h.text(t));
        }
        return out.done();
    }

    fn pickCell(h: *H, r: *const Row) N {
        return h.span(.{}, .{pickText(h, r.share())});
    }

    fn wonCell(h: *H, r: *const Row) N {
        const own: ?N = if (r.o.games < rate_games) null else h.span(.{ .class = "own" }, .{phrase.num(h, .points, rate(r.o.games, r.o.wins) - r.c.own)});
        return h.span(.{ .class = "won" }, .{ win(h, r.o.games, r.o.wins, r.c.ref), own });
    }

    fn gamesCell(h: *H, r: *const Row) N {
        return h.span(.{}, .{shortCount(h, r.o.games)});
    }
};

pub const Table = table.DataTable(Row, .{
    .title = plain("Options"),
    .columns = &.{
        .{ .label = plain(""), .cell = Row.what, .num = false },
        // Under 150 px (320 phones) games stay, pick gives way
        .{ .label = plain("Pick"), .cell = Row.pickCell, .sort = Row.share, .priority = 2 },
        .{ .label = plain("Won"), .cell = Row.wonCell, .sort = Row.winSort, .answer = true },
        .{ .label = plain("Games"), .cell = Row.gamesCell, .sort = Row.gamesF },
    },
    .default_sort = 1,
    .games = Row.games,
    .thin = solid_games,
    .compact = true,
});

pub const BuildPanel = struct {
    data: *const Data,
    runes: runetree.RuneTree,
    /// The cell open across the panel
    open: ?Kind = null,
    order: Order = .pick,
    /// Unique on the page: the note's id starts with it
    id: []const u8 = "build",
    ctx: [n_kinds]Ctx = undefined,
    rows: [n_kinds][]Row = @splat(&.{}),
    tables: [n_kinds]Table = undefined,

    pub const Msg = union(enum) { open: Kind, key, order: Order };

    pub const Url = struct {
        slot: ?Kind = null,
        order: Order = .pick,
    };

    pub fn toUrl(p: *const BuildPanel) Url {
        return .{ .slot = p.open, .order = p.order };
    }

    pub fn fromUrl(p: *BuildPanel, u: Url) void {
        p.open = if (u.slot) |k| (if (p.rows[@backingInt(k)].len > 0 and k != .skill_path) k else null) else null;
        p.setOrder(u.order);
    }

    /// The Table column an order sorts by
    fn column(o: Order) u8 {
        return switch (o) {
            .pick => 1,
            .win => 2,
        };
    }

    fn setOrder(p: *BuildPanel, o: Order) void {
        p.order = o;
        for (&p.tables) |*t| {
            t.sort = column(o);
            t.desc = true;
        }
    }

    /// In place: the rows point into the panel
    pub fn init(p: *BuildPanel, a: std.mem.Allocator, data: *const Data) !void {
        p.* = .{ .data = data, .runes = .{ .data = &data.runes } };
        for (&p.ctx, 0..) |*c, i| c.* = .{ .kind = @fromBackingInt(@intCast(i)), .games = 0, .ref = 50, .own = data.own };
        for (data.slots) |s| {
            const i = @backingInt(s.kind);
            p.ctx[i] = .{
                .kind = s.kind,
                .games = s.games,
                .ref = rate(s.games, s.wins),
                .own = data.own,
                .top = if (s.options.len > 0) s.options[0].art else &.{},
                .best = bestOf(s.options),
            };
            const rows = try a.alloc(Row, s.options.len);
            for (rows, s.options) |*r, *o| r.* = .{ .o = o, .c = &p.ctx[i] };
            p.rows[i] = rows;
        }
        for (&p.tables, 0..) |*t, i| t.* = .{ .rows = p.rows[i], .head = false };
    }

    pub fn update(p: *BuildPanel, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .open => |k| {
                p.open = if (p.open == k) null else k;
                const t = &p.tables[@backingInt(k)];
                t.sort = column(p.order);
                t.desc = true;
                ev.push = true;
            },
            .order => |o| {
                if (p.order == o) return;
                p.setOrder(o);
                ev.push = true;
            },
            // Escape in the open cell closes it, focus back on its "all"
            .key => {
                const k = p.open orelse return;
                if (!std.mem.eql(u8, ev.text, "Escape")) return;
                p.open = null;
                ev.push = true;
                ev.handled = true;
                ev.after = .{ .op = .focus, .ref = allRef(k) };
            },
        }
    }

    pub fn view(p: *BuildPanel, h: *H) N {
        var cells = h.list();
        for ([_]Kind{ .spells, .start, .boots, .core, .item4, .item5, .item6 }) |k| if (p.cell(h, k)) |c| cells.add(c);
        if (p.skillsCell(h)) |c| cells.add(c);
        const tip = toggletip.view(h, h.fmt("{s}-own", .{p.id}), .{W.own_term.with(h, .{ .r = p.data.own })}, W.own_title, W.own_note.with(h, .{ .c = p.data.champion, .r = p.data.own }));
        return h.div(.{ .class = "c-build" }, .{h.div(.{ .class = "in" }, .{
            h.div(.{ .class = "runes" }, .{p.runes.view(h)}),
            h.div(.{ .class = "slots" }, .{
                h.div(.{ .class = "names" }, .{
                    segmented.view(h, .{ .s = .s, .label = W.order }, &.{
                        .{ .label = W.most_picked, .selected = p.order == .pick, .on = h.on(p, .{ .order = .pick }) },
                        .{ .label = W.highest, .selected = p.order == .win, .on = h.on(p, .{ .order = .win }) },
                    }),
                    h.span(.{}, .{W.pick}),
                    h.span(.{ .class = "w" }, .{W.won}),
                    h.span(.{ .class = "own" }, .{&tip}),
                    h.span(.{ .class = "g" }, .{W.games}),
                }),
                h.div(.{ .class = "cells" }, .{cells.done()}),
            }),
        })});
    }

    fn allRef(k: Kind) []const u8 {
        return switch (k) {
            inline else => |c| "all-" ++ @tagName(c),
        };
    }

    /// A cell's head band: its title and, with more options than shown, all / fewer
    fn head(p: *BuildPanel, h: *H, k: Kind, total: usize) N {
        const open = p.open == k;
        return h.div(.{ .class = "sh" }, .{
            h.h3(.{}, .{k.title()}),
            if (total > shown) button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .{ .open = k }), .ref = allRef(k) }, .{if (open) W.fewer else W.all.with(h, .{ .n = total })}) else null,
        });
    }

    fn tableFor(p: *BuildPanel, h: *H, k: Kind, open: bool, max: usize) N {
        const i = @backingInt(k);
        p.ctx[i].open = open;
        const t = &p.tables[i];
        if (open) {
            t.rows = p.rows[i];
        } else {
            t.rows = p.closed(h, k, max);
            t.sort = column(p.order);
            t.desc = true;
        }
        t.head = open;
        t.id = h.fmt("{s}-{s}", .{ p.id, @tagName(k) });
        return t.view(h);
    }

    /// A closed cell's rows: the top `max` by pick and the best when not among them, or
    /// the top `max` by win rate
    fn closed(p: *BuildPanel, h: *H, k: Kind, max: usize) []Row {
        const rows = p.rows[@backingInt(k)];
        const n = @min(max, rows.len);
        if (p.order == .win) {
            const out = h.mem.dupe(Row, rows) catch {
                h.oom = true;
                return rows[0..n];
            };
            std.sort.insertion(Row, out, {}, struct {
                fn f(_: void, x: Row, y: Row) bool {
                    return x.winSort() > y.winSort();
                }
            }.f);
            return out[0..n];
        }
        const best = p.ctx[@backingInt(k)].best orelse return rows[0..n];
        for (rows[0..n]) |r| if (r.o == best) return rows[0..n];
        const out = h.mem.alloc(Row, n + 1) catch {
            h.oom = true;
            return rows[0..n];
        };
        @memcpy(out[0..n], rows[0..n]);
        for (rows[n..]) |r| if (r.o == best) {
            out[n] = r;
        };
        return out;
    }

    /// The level path the grid draws: the most played, or the best by win rate
    fn shownPath(p: *BuildPanel) *const Row {
        const paths = p.rows[@backingInt(Kind.skill_path)];
        if (p.order == .win) if (p.ctx[@backingInt(Kind.skill_path)].best) |b| {
            for (paths) |*r| if (r.o == b) return r;
        };
        return &paths[0];
    }

    fn cell(p: *BuildPanel, h: *H, k: Kind) ?N {
        const rows = p.rows[@backingInt(k)];
        if (rows.len == 0) return null;
        return h.div(.{
            .class = "slot",
            .key = @backingInt(k),
            .data_k = k,
            .data_open = p.open == k,
            .on_keydown = if (p.open == k) h.on(p, .key) else null,
        }, .{ p.head(h, k, rows.len), p.tableFor(h, k, p.open == k, shown) });
    }

    /// Priorities as rows, the most played level path as the SkillGrid; open: every
    /// priority and every path
    fn skillsCell(p: *BuildPanel, h: *H) ?N {
        const pri = p.rows[@backingInt(Kind.skills)];
        const paths = p.rows[@backingInt(Kind.skill_path)];
        if (pri.len == 0 and paths.len == 0) return null;
        const open = p.open == .skills;
        const path_c = &p.ctx[@backingInt(Kind.skill_path)];
        return h.div(.{ .class = "slot", .key = @backingInt(Kind.skills), .data_k = Kind.skills, .data_open = open, .on_keydown = if (open) h.on(p, .key) else null }, .{
            p.head(h, .skills, @max(pri.len, paths.len)),
            if (pri.len > 0) p.tableFor(h, .skills, open, 1) else null,
            if (paths.len > 0) skillgrid.view(h, .{
                .keys = p.shownPath().o.keys,
                .games = p.shownPath().o.games,
                .wins = p.shownPath().o.wins,
                .share = p.shownPath().share(),
            }, path_c.ref) else null,
            if (open and paths.len > 0) p.tableFor(h, .skill_path, true, paths.len) else null,
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-build { container-type: inline-size; min-width: 0; }
    \\  .c-build > .in { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-4) var(--sp-5); }
    \\  @container (min-width: 900px) { .c-build > .in { grid-template-columns: minmax(0, 600px) minmax(0, 1fr); } }
    \\  .c-build > .in > * { min-width: 0; }
    \\  .c-build .slots { container-type: inline-size; display: flex; flex-direction: column; }
    \\  .c-build .slots > .names { display: flex; justify-content: flex-end; align-items: center; gap: var(--sp-2);
    \\    margin-bottom: var(--sp-2); font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-build .names > .c-seg { margin-right: auto; }
    \\  .c-build .names > .c-seg + span { color: var(--muted); }
    \\  .c-build .names > .w { color: var(--t2); font-weight: var(--w-b); }
    \\  .c-build .slots > .cells { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--sp-3) var(--sp-4); }
    \\  @container (max-width: 520px) { .c-build .slots > .cells { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--sp-3); } }
    \\  .c-build .slot { display: flex; flex-direction: column; min-width: 0; }
    \\  .c-build .slot[data-k="core"], .c-build .slot[data-k="skills"], .c-build .slot[data-open] { grid-column: 1 / -1; }
    \\  .c-build .slot > .sh { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-2);
    \\    height: var(--ctl-s); border-bottom: 1px solid var(--line); }
    \\  .c-build .slot > .sh > h3 { margin: 0; font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--muted);
    \\    text-transform: uppercase; letter-spacing: 0.06em; }
    \\  .c-build .slot > .sh > .c-btn { margin-right: -10px; }
    \\  .c-build .slot .c-table td { border-bottom-color: var(--line); }
    \\  .c-build .what { display: flex; align-items: center; gap: 3px; min-width: 0; }
    \\  .c-build .what > .nm { margin-left: 6px; color: var(--t2); overflow: hidden; text-overflow: ellipsis; }
    \\  .c-build .what > .min, .c-build .won > .own { color: var(--faint); font-size: var(--fs-xs); }
    \\  .c-build .what > .min { margin-left: var(--sp-2); }
    \\  .c-build .won { display: inline-flex; align-items: baseline; justify-content: flex-end; gap: 5px; }
    \\  .c-build .won > .w { font-weight: var(--w-b); color: var(--c, var(--faint)); min-width: 30px; text-align: right; }
    \\  .c-build .won > .own { min-width: 28px; text-align: right; }
    \\  .c-build .keys { font-family: ui-monospace, monospace; letter-spacing: 0.06em; color: var(--t2); }
    \\  .c-build .keys > b { color: var(--text); }
    \\  .c-build .keys > .ar { color: var(--faint); margin: 0 3px; font-family: var(--font); }
    \\  .c-build .slot > .c-skills { margin: var(--sp-2) 0 var(--sp-1); }
    \\  .c-build .what > .best { margin-left: 4px; font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--accent); }
    \\  @container (max-width: 260px) { .c-build .won > .own { display: none; } }
    \\  @container (max-width: 200px) {
    \\    .c-build .what > .best { flex: none; width: 6px; height: 6px; margin-left: 5px; border-radius: 50%;
    \\      overflow: hidden; color: transparent; background: var(--accent); }
    \\    .c-build .c-table[data-v="compact"] :is(th, td) { padding: 0 2px; }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const demo = @import("build_demo.zig");
    const states = [_]struct { []const u8, ?Kind }{
        .{ "Darius top: whole build, most played first", null },
        .{ "Item 4 open: every option, named, sortable", .item4 },
        .{ "Skills open: every order and level path", .skills },
    };
    for (states) |s| {
        const p = h.mem.create(BuildPanel) catch {
            h.oom = true;
            return;
        };
        p.init(h.mem, &demo.darius) catch {
            h.oom = true;
            return;
        };
        p.open = s[1];
        p.id = h.fmt("build{d}-{d}", .{ @backingInt(s[1] orelse .skill_path), g.width });
        p.runes.id = p.id;
        g.addFill(s[0], p.view(h));
    }
}

test {
    _ = @import("build_test.zig");
}
