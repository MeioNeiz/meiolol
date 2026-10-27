//! BuildPanel: the champion's whole build in one panel, as an island. RuneTree on the
//! left; on the right the slot cells (Spells, Start, Boots / Core / Item 4, 5, 6 /
//! Skills) in a 3-column grid, pairs in a narrow container. Each cell lists its top 3
//! options as compact DataTable rows, most played first: pick share, win rate coloured
//! against the slot's own (which choice is better here, Jacob 25 Oct), games; the
//! quieter reading (the rate minus the champion's) only in an open cell. The slot's
//! highest win rate on solid_games is marked "best", a 4th row when not in the top 3.
//! Most picked | Highest WR (lolalytics' build toggle, Jacob 26 Oct) re-sorts every cell
//! by win rate, options under solid_games after. A matchup's marks the champion's usual
//! choice "as usual" and dims a cell led by it. Tap a cell's "N more" to open it across
//! the panel: every option, named, sortable. One open at a time; it and the order in
//! the URL. Each cell's head names its columns over fixed widths, so they line up (one
//! legend for the panel read as a toggle, Jacob 27 Oct). Data is plain, so a page
//! can hand it builds filtered by a choice (contextual builds, builds.md answers) later
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const art = @import("art.zig");
const button = @import("button.zig");
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
    /// A matchup's: the option the champion plays most in all its games ("as usual")
    usual: ?u8 = null,
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
    pub const more = Phrase("{n:int} more");
    pub const own_note = plain("The option's win rate minus the champion's in the role. Late items read high: games that reach them were often won already.");
    pub const min = plain("min");
    pub const best = plain("best");
    pub const as_usual = plain("as usual");
    pub const sort = plain("Sort");
    pub const levels = plain("Levels");
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
    usual: ?*const Option = null,
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
    fn ownSort(r: *const Row) f64 {
        return if (r.o.games < rate_games) -100 else rate(r.o.games, r.o.wins) - r.c.own;
    }

    fn what(h: *H, r: *const Row) N {
        const o = r.o;
        const open = r.c.open;
        return switch (r.c.kind) {
            .core => h.span(.{ .class = "what" }, .{ itempath.view(h, o.art, .{ .minutes = o.minutes, .top = if (r.c.top.ptr == o.art.ptr) null else r.c.top }), bestMark(h, r), usualMark(h, r) }),
            .skills => h.span(.{ .class = "what" }, .{ h.span(.{ .class = "keys" }, .{keys(h, o.keys, true)}), bestMark(h, r), usualMark(h, r) }),
            .skill_path => h.span(.{ .class = "what" }, .{ h.span(.{ .class = "keys", .data_v = "path" }, .{keys(h, o.keys, false)}), usualMark(h, r) }),
            else => blk: {
                var icons = h.list();
                for (o.art) |a| icons.add(art.view(h, a, .{ .k = if (r.c.kind == .spells) .spell else .item, .named = !open }));
                const label: ?[]const u8 = if (!open) null else if (o.name.len > 0) o.name else if (o.art.len == 1) o.art[0].name else null;
                const minute: ?N = if (open and o.minutes.len == 1 and o.minutes[0] > 0)
                    h.span(.{ .class = "min" }, .{ phrase.num(h, .int, @as(u32, @intFromFloat(@round(o.minutes[0])))), " ", W.min })
                else
                    null;
                break :blk h.span(.{ .class = "what" }, .{ icons.done(), if (label) |l| h.span(.{ .class = "nm" }, .{l}) else null, minute, bestMark(h, r), usualMark(h, r) });
            },
        };
    }

    fn bestMark(h: *H, r: *const Row) ?N {
        return if (r.c.best == r.o) h.span(.{ .class = "best" }, .{W.best}) else null;
    }

    fn usualMark(h: *H, r: *const Row) ?N {
        return if (r.c.usual == r.o) h.span(.{ .class = "usual" }, .{W.as_usual}) else null;
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
        return win(h, r.o.games, r.o.wins, r.c.ref);
    }

    fn ownCell(h: *H, r: *const Row) N {
        if (r.o.games < rate_games) return h.span(.{ .class = "own" }, .{"·"});
        return h.span(.{ .class = "own" }, .{phrase.num(h, .points, rate(r.o.games, r.o.wins) - r.c.own)});
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
        .{ .label = plain("Pick"), .cell = Row.pickCell, .sort = Row.share, .priority = 2, .key = "p" },
        .{ .label = plain("Won"), .cell = Row.wonCell, .sort = Row.winSort, .answer = true, .key = "w" },
        // In an open cell only (css)
        .{ .label = plain("vs all"), .cell = Row.ownCell, .sort = Row.ownSort, .priority = 3, .tip = W.own_note, .key = "o" },
        .{ .label = plain("Games"), .cell = Row.gamesCell, .sort = Row.gamesF, .key = "g" },
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
                .usual = if (s.usual) |u| (if (u < s.options.len) &s.options[u] else null) else null,
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
        return h.div(.{ .class = "c-build" }, .{h.div(.{ .class = "in" }, .{
            h.div(.{ .class = "runes" }, .{p.runes.view(h)}),
            h.div(.{ .class = "slots" }, .{
                h.div(.{ .class = "sort" }, .{
                    h.span(.{ .aria_hidden = true }, .{W.sort}),
                    segmented.view(h, .{ .s = .s, .label = W.sort }, &.{
                        .{ .label = W.most_picked, .selected = p.order == .pick, .on = h.on(p, .{ .order = .pick }) },
                        .{ .label = W.highest, .selected = p.order == .win, .on = h.on(p, .{ .order = .win }) },
                    }),
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

    /// A cell's head band: its title, then its column heads; open, "fewer" instead (the
    /// open table heads its own columns)
    fn head(p: *BuildPanel, h: *H, k: Kind, title: tree.Text) N {
        if (p.open == k) return h.div(.{ .class = "sh" }, .{
            h.h3(.{}, .{title}),
            button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .{ .open = k }), .ref = allRef(k) }, .{W.fewer}),
        });
        return h.div(.{ .class = "sh" }, .{ h.h3(.{}, .{title}), heads(h) });
    }

    fn heads(h: *H) N {
        return h.span(.{ .class = "hd" }, .{
            h.span(.{ .class = "p" }, .{W.pick}),
            h.span(.{ .class = "w" }, .{W.won}),
            h.span(.{ .class = "g" }, .{W.games}),
        });
    }

    /// Under a closed cell with options it doesn't show: "7 more", which opens it
    fn more(p: *BuildPanel, h: *H, k: Kind, hidden: usize) ?N {
        if (p.open == k or hidden == 0) return null;
        return button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .{ .open = k }), .ref = allRef(k) }, .{W.more.with(h, .{ .n = hidden })});
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

    /// A matchup's cell whose most played is the champion's usual: dimmed, the others
    /// stand out
    fn asUsual(p: *const BuildPanel, k: Kind) bool {
        const rows = p.rows[@backingInt(k)];
        return rows.len > 0 and p.ctx[@backingInt(k)].usual == rows[0].o;
    }

    fn cell(p: *BuildPanel, h: *H, k: Kind) ?N {
        const rows = p.rows[@backingInt(k)];
        if (rows.len == 0) return null;
        const t = p.tableFor(h, k, p.open == k, shown);
        return h.div(.{
            .class = "slot",
            .key = @backingInt(k),
            .data_k = k,
            .data_open = p.open == k,
            .data_usual = p.open != k and p.asUsual(k),
            .on_keydown = if (p.open == k) h.on(p, .key) else null,
        }, .{ p.head(h, k, k.title()), t, p.more(h, k, rows.len - p.tables[@backingInt(k)].rows.len) });
    }

    /// Closed, two parts side by side: the priorities as rows, and the shown level path
    /// as the SkillGrid with its figures beside it, each under its own column heads.
    /// Open: every priority, the grid, every path, one under the other
    fn skillsCell(p: *BuildPanel, h: *H) ?N {
        const pri = p.rows[@backingInt(Kind.skills)];
        const paths = p.rows[@backingInt(Kind.skill_path)];
        if (pri.len == 0 and paths.len == 0) return null;
        const open = p.open == .skills;
        const pri_t: ?N = if (pri.len > 0) p.tableFor(h, .skills, open, shown) else null;
        const path: ?N = if (paths.len > 0) p.pathRow(h, p.shownPath()) else null;
        const attrs = .{ .class = "slot", .key = @backingInt(Kind.skills), .data_k = Kind.skills, .data_open = open, .data_usual = !open and p.asUsual(.skills), .on_keydown = if (open) h.on(p, .key) else null };
        if (open) return h.div(attrs, .{
            p.head(h, .skills, Kind.skills.title()),
            pri_t,
            path,
            if (paths.len > 0) p.tableFor(h, .skill_path, true, paths.len) else null,
        });
        const hidden = @max(pri.len -| p.tables[@backingInt(Kind.skills)].rows.len, paths.len -| 1);
        return h.div(attrs, .{
            h.div(.{ .class = "part" }, .{ p.head(h, .skills, Kind.skills.title()), pri_t, p.more(h, .skills, hidden) }),
            if (path) |x| h.div(.{ .class = "part" }, .{ h.div(.{ .class = "sh" }, .{ h.h3(.{}, .{W.levels}), heads(h) }), x }) else null,
        });
    }

    /// The level path's grid, then its pick, won and games in the cells' columns
    fn pathRow(p: *BuildPanel, h: *H, r: *const Row) N {
        const ref = p.ctx[@backingInt(Kind.skill_path)].ref;
        return h.div(.{ .class = "lp", .data_state = if (r.o.games < solid_games) "thin" else null }, .{
            skillgrid.order(h, r.o.keys),
            h.span(.{ .class = "p" }, .{pickText(h, r.share())}),
            win(h, r.o.games, r.o.wins, ref),
            h.span(.{ .class = "g" }, .{shortCount(h, r.o.games)}),
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-build { container-type: inline-size; min-width: 0; --cwp: 40px; --cww: 46px; --cwg: 42px; }
    \\  .c-build > .in { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--sp-4) var(--sp-5);
    \\    padding: var(--sp-3) var(--card-px) var(--card-px); }
    \\  @container (min-width: 900px) { .c-build > .in { padding: var(--sp-4) var(--sp-5) var(--sp-5); } }
    \\  @container (min-width: 900px) { .c-build > .in { grid-template-columns: minmax(0, 600px) minmax(0, 1fr); } }
    \\  @container (min-width: 1400px) { .c-build > .in { grid-template-columns: minmax(0, 660px) minmax(0, 1fr); } }
    \\  .c-build > .in > * { min-width: 0; }
    \\  .c-build .slots { container-type: inline-size; display: flex; flex-direction: column; }
    \\  .c-build .slots > .sort { display: flex; align-items: center; gap: var(--sp-2); margin-bottom: var(--sp-3);
    \\    font-size: var(--fs-s); color: var(--muted); }
    \\  .c-build .slots > .cells { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); grid-auto-flow: dense;
    \\    gap: var(--sp-4) var(--sp-5); }
    \\  .c-build .slots > .cells:has(> [data-open]) { grid-auto-flow: row; }
    \\  @container (max-width: 520px) { .c-build .slots > .cells { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--sp-4) var(--sp-3); } }
    \\  .c-build .slot, .c-build .part { container-type: inline-size; display: flex; flex-direction: column; min-width: 0; }
    \\  .c-build .slot[data-k="core"] { grid-column: span 2; }
    \\  .c-build .slot[data-k="skills"], .c-build .slot[data-open] { grid-column: 1 / -1; }
    \\  .c-build .slot[data-k="skills"]:not([data-open]) { display: contents; }
    \\  .c-build .slot[data-k="skills"] > .part + .part { grid-column: 1 / -1; }
    \\  .c-build .slots .sh { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-2);
    \\    height: var(--ctl-s); border-bottom: 1px solid var(--line); }
    \\  .c-build .slots .sh > h3 { margin: 0; font-size: var(--fs-s); font-weight: var(--w-b); color: var(--t2);
    \\    text-transform: uppercase; letter-spacing: 0.06em; white-space: nowrap; }
    \\  .c-build .slots .sh > .c-btn { margin-right: -10px; }
    \\  .c-build .slots .sh > .hd { display: flex; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-build .hd > *, .c-build .lp > :not(.c-skills) { box-sizing: border-box; text-align: right; padding: 0 3px; }
    \\  .c-build :is(.hd, .lp) > .p, .c-build .slot:not([data-open]) .c-table .p { width: var(--cwp); }
    \\  .c-build :is(.hd, .lp) > .w, .c-build .slot:not([data-open]) .c-table .w { width: var(--cww); }
    \\  .c-build :is(.hd, .lp) > .g, .c-build .slot:not([data-open]) .c-table .g { width: var(--cwg); padding-right: 0; }
    \\  .c-build .slot:not([data-open]) .c-table { table-layout: fixed; width: 100%; }
    \\  .c-build .slot:not([data-open]) .c-table .o { display: none; }
    \\  .c-build .slot .c-table[data-v="compact"] { font-size: var(--fs-m); }
    \\  .c-build .slot .c-table[data-v="compact"] td { height: 40px; }
    \\  .c-build .slot .c-table td { border-bottom-color: var(--line); }
    \\  .c-build .slot .c-table .g, .c-build .lp > .g { color: var(--muted); }
    \\  .c-build .slot > .c-btn, .c-build .part > .c-btn { align-self: flex-start; margin: 2px 0 0 -10px; color: var(--muted); }
    \\  .c-build .what { display: flex; align-items: center; gap: 4px; min-width: 0; }
    \\  .c-build .what .c-art { --sz: 30px; }
    \\  .c-build .what > .nm { margin-left: 6px; color: var(--t2); overflow: hidden; text-overflow: ellipsis; }
    \\  .c-build .what > .min, .c-build .own { color: var(--faint); font-size: var(--fs-s); }
    \\  .c-build .what > .min { margin-left: var(--sp-2); }
    \\  .c-build :is(td, .lp) > .w { font-weight: var(--w-b); color: var(--c, var(--faint)); }
    \\  .c-build .keys { font-family: ui-monospace, monospace; letter-spacing: 0.06em; color: var(--t2); }
    \\  .c-build .keys > b { color: var(--text); }
    \\  .c-build .keys > .ar { color: var(--faint); margin: 0 4px; font-family: var(--font); }
    \\  .c-build .lp { display: flex; align-items: center; gap: 0; min-height: 40px; padding: var(--sp-2) 0;
    \\    font-size: var(--fs-m); font-variant-numeric: tabular-nums; border-bottom: 1px solid var(--line); }
    \\  .c-build .lp > .c-skills { flex: 1; min-width: 0; margin-right: var(--sp-2); }
    \\  .c-build .lp > .c-skills > .grid { font-size: var(--fs-s); gap: 3px 2px; }
    \\  .c-build .lp > .c-skills > .grid > i { height: 22px; }
    \\  .c-build .lp > .p { color: var(--t2); }
    \\  .c-build .lp[data-state="thin"] > :not(.c-skills) { opacity: 0.55; }
    \\  .c-build .what > .best { margin-left: 4px; font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--accent); }
    \\  .c-build .what > .usual { margin-left: 4px; font-size: var(--fs-xs); color: var(--faint); white-space: nowrap; }
    \\  .c-build .slot[data-usual] > :not(.sh), .c-build .slot[data-usual] > .part > :not(.sh) { opacity: 0.55; }
    \\  @container (max-width: 200px) {
    \\    .c-build .what > .best { flex: none; width: 6px; height: 6px; margin-left: 5px; border-radius: 50%;
    \\      overflow: hidden; color: transparent; background: var(--accent); }
    \\    .c-build .c-table[data-v="compact"] :is(th, td) { padding: 0 2px; }
    \\    .c-build .what > .usual { display: none; }
    \\    .c-build .what > .c-art + .c-art { margin-left: -10px; box-shadow: -1.5px 0 0 var(--panel); }
    \\  }
    \\  @container (max-width: 260px) {
    \\    .c-build :is(.slot, .part) > * { --cwp: 32px; --cww: 36px; --cwg: 32px; }
    \\    .c-build .slot .c-table[data-v="compact"] { font-size: var(--fs-s); }
    \\    .c-build .what .c-art { --sz: 26px; }
    \\  }
    \\  @container (max-width: 170px) { .c-build .hd > .p, .c-build .slot:not([data-open]) .c-table .p { display: none; } }
    \\  @container (max-width: 420px) { .c-build .what > .c-path > .min { display: none; } }
    \\  @container (max-width: 480px) {
    \\    .c-build .lp { flex-wrap: wrap; }
    \\    .c-build .lp > .c-skills { flex-basis: 100%; margin: 0 0 var(--sp-1); }
    \\    .c-build .lp > .c-skills > .grid { font-size: var(--fs-xs); gap: 2px 1px; }
    \\    .c-build .lp > .c-skills > .grid > i { height: 18px; }
    \\    .c-build .lp > .p { margin-left: auto; }
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
    const vs = matchup(h, &demo.darius) catch {
        h.oom = true;
        return;
    };
    const p = h.mem.create(BuildPanel) catch {
        h.oom = true;
        return;
    };
    p.init(h.mem, vs) catch {
        h.oom = true;
        return;
    };
    p.id = h.fmt("build-vs-{d}", .{g.width});
    p.runes.id = p.id;
    g.addFill("a matchup's: spells and skills as usual (dimmed), boots' usual second", p.view(h));
}

/// `d` as a matchup's: the usual leads Spells and Skills, Boots' is its second
fn matchup(h: *H, d: *const Data) !*const Data {
    const slots = try h.mem.dupe(Slot, d.slots);
    for (slots) |*s| s.usual = switch (s.kind) {
        .spells, .skills, .skill_path => 0,
        .boots => if (s.options.len > 1) 1 else null,
        else => null,
    };
    const out = try h.mem.create(Data);
    out.* = d.*;
    out.slots = slots;
    return out;
}

test {
    _ = @import("build_test.zig");
}
