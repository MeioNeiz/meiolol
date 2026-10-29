//! Champions (champions.html, role/<slug>.html; docs/plan/ui/champions.md): every
//! champion in every role on one board, a role at a time, and which way each moved this
//! patch. A head card (role picked in place, search, the view's toolbar, the Games
//! floor), then the movers band and a DataTable sorted by the rate shown.
//!
//! The server renders the default state from the same Data the view's data file
//! (data/tiers.bin) carries; ui-stats.wasm decodes that file and adopts the page. A view
//! (region, period) is its own page: the toolbar links to it, keeping the fragment. A
//! rank above Platinum+ is picked in place: the view's rank file (rank_paths) is fetched
//! on the first pick and the board shown faded until it is in
const std = @import("std");
const tree = @import("tree.zig");
const url = @import("url.zig");
const phrase = @import("phrase.zig");
const table = @import("table.zig");
const card = @import("card.zig");
const segmented = @import("segmented.zig");
const filterbar = @import("filterbar.zig");
const rolepicker = @import("rolepicker.zig");
const chip = @import("chip.zig");
const stat = @import("stat.zig");
const delta = @import("delta.zig");
const bar = @import("bar.zig");
const badge = @import("badge.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const violin = @import("violin.zig");
const champpage = @import("champpage.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "Champions";
pub const scope = .{".c-tiers"};

/// core.Role's order (tierlist.zig checks it)
pub const Role = enum(u8) {
    top,
    jungle,
    middle,
    bottom,
    utility,

    pub const names = [_][]const u8{ "Top", "Jungle", "Mid", "Bot", "Support" };
    pub const slugs = [_][]const u8{ "top", "jungle", "mid", "bot", "support" };

    pub fn name(r: Role) []const u8 {
        return names[@backingInt(r)];
    }

    pub fn ui(r: Role) role.Role {
        return role.Role.all[@backingInt(r)];
    }
};

/// spread.zig's shape: players near each point, every shape_step points from
/// -shape_reach to +shape_reach (tierlist.zig checks they match)
pub const shape_reach = 36;
pub const shape_step = 2;
pub const shape_points = 2 * shape_reach / shape_step + 1;

/// html.View.all's directories, by index (tierlist.zig checks they match)
pub const view_dirs = [_][]const u8{ "", "patch/", "all/", "all/patch/" };

/// Platinum+ (the view's data file), then RankData's groups; the champion page's, so a
/// link carries it
pub const Rank = champpage.Rank;
pub const n_groups = @import("champrank.zig").n_groups;

/// Each view's rank file, from the site root: the root view writes them all
pub const rank_paths = [_][]const u8{ "data/tiers-rank.bin", "data/tiers-rank-patch.bin", "data/tiers-rank-all.bin", "data/tiers-rank-all-patch.bin" };

/// Emerald+, Diamond+, Master+ (ui.champrank's groups), each a whole board without
/// spreads: per-player figures are thin at high ranks
pub const RankData = struct { groups: [n_groups]Data };

/// A data file's stamp: the page carries its file's, so ui.wasm adopts a page only with
/// the data it was rendered from (a cached page and a newer file would not match)
pub fn stamp(bytes: []const u8) u32 {
    return std.hash.Fnv1a_32.hash(bytes);
}

/// One view's champions table, all roles
pub const Data = struct {
    /// The view's games
    games: u32,
    /// The Games floor at first (min_games' index): bigger views start higher
    min: u8,
    /// Players with this many games on a champion count in its spread
    spread_min_games: u32,
    /// The patch change: "" without one
    cur_patch: []const u8,
    prev_patch: []const u8,
    /// "in EUW"
    region_in: []const u8,
    ddragon: []const u8,
    /// The view's query, for links to champion pages (html.View.query)
    query: []const u8,
    rank: Rank = .plat,
    champs: []const Champ,
    /// By win rate, ties most played first
    rows: []const Row,
};

pub const Champ = struct {
    name: []const u8,
    /// Data Dragon's
    key: []const u8,
    slug: []const u8,
    banned: u32,
};

pub const Row = struct {
    champ: u16,
    role: Role,
    games: u32,
    wins: u32,
    /// Of the champion's games, the share in this role
    share: f32,
    spread: ?Spread,
    patch: ?Patch,
    /// Pick and ban %, a rank group's (filters.Ranked's, as the champion page shows);
    /// null: from games and the champion's bans
    rates: ?[2]f32 = null,
};

pub const Spread = struct {
    players: u32,
    p25: u8,
    p75: u8,
    shape: [shape_points]u8,
};

pub const Patch = struct {
    /// Games and wins
    prev: [2]u32,
    cur: [2]u32,
    /// patchday.Rate.clear with the site's options
    clear: bool,
};

/// Under this share of a champion's games a role is off-role: behind the "+N" chip
pub const off_role = 0.1;
/// Movers each way in the band
const movers_each = 5;
/// Each role's column on the All board
const board_rows = 10;
/// The board's sort choices: Table's columns
const board_sorts = [_]u8{ 1, 2, 4, 5, 6 };
const board_labels = [_]tree.Text{ W.win, W.patch, W.pick, W.ban, W.games };

const W = struct {
    pub const title = plain("Champions");
    pub const scope_line = Phrase("{n:count} games {in:text}");
    pub const versus = Phrase(" · {cur:text} vs {prev:text}");
    pub const role_label = plain("Role");
    pub const region = plain("Region");
    pub const period = plain("Period");
    pub const rank_pick = plain("Rank");
    pub const regions = [_]tree.Text{ plain("EUW"), plain("All") };
    pub const days = plain("30 days");
    pub const ranks = [_]tree.Text{ plain("Plat+"), plain("Emerald+"), plain("Diamond+"), plain("Master+") };
    pub const picked = Phrase("{r:text} · {p:text} · {k:text}");
    pub const min_games = plain("Min games");
    pub const moved = Phrase("Moved in {p:text}");
    pub const patch_link = plain("Patch changes ›");
    pub const champion = plain("Champion");
    pub const win = plain("Win rate");
    pub const patch = plain("Patch");
    pub const players = plain("Players");
    pub const pick = plain("Pick");
    pub const ban = plain("Ban");
    pub const games = plain("Games");
    pub const off = plain("off-role");
    pub const clear = plain("Clear search");
    pub const sort_by = plain("Sort");
    pub const all_n = Phrase("All {n:int} ›");
    pub const win_note = plain("Faint under 1,000 games: could be luck.");
    pub const patch_note = plain("Change in win rate, in points. Coloured when clear, faint when it could be luck.");
    pub const players_note = plain("Each player's own win rate on it (10+ games), 25% to 75%. Thicker where more players are; the dot is the champion's. In 10-20 games luck alone moves a player by about 15 points.");
    pub const change = Phrase("{d:points} ±{ci:dec} points");
    pub const was = Phrase("{prev:text} {a:rate} of {an:count} → {cur:text} {b:rate} of {bn:count}");
    pub const luck = plain("Could be luck.");
    pub const spread = Phrase("{n:count} players");
    pub const middle = Phrase("Middle half win {lo:pct} to {hi:pct}; the champion {at:rate}.");
    pub const no_spread = plain("Too few players with 10+ games on it.");
    pub const plat_only = plain("Plat+ only: too few players with 10+ games on it at higher ranks.");
    pub const no_patch = plain("No games last patch.");
};

/// One row: the data's row with what its cells need, made once (prepare)
pub const Line = struct {
    d: *const Data,
    i: u16,
    icon: []const u8,
    href: []const u8,
    /// The violin's outline
    shape: ?[]const u8,
    /// Under All: the role icon beside the name
    all: bool,

    fn row(l: *const Line) *const Row {
        return &l.d.rows[l.i];
    }

    fn rate(l: *const Line) f64 {
        const r = l.row();
        return 100 * share(.{ r.games, r.wins });
    }

    /// This patch's rate minus the last one's, points
    fn change(l: *const Line) ?f64 {
        const p = l.row().patch orelse return null;
        return 100 * (share(p.cur) - share(p.prev));
    }
};

fn share(c: [2]u32) f64 {
    return @as(f64, @floatFromInt(c[1])) / @as(f64, @floatFromInt(@max(c[0], 1)));
}

/// 95% half-width of a difference of two rates, in points
fn ci(p: Patch) f64 {
    const a = share(p.prev);
    const b = share(p.cur);
    const na: f64 = @floatFromInt(@max(p.prev[0], 1));
    const nb: f64 = @floatFromInt(@max(p.cur[0], 1));
    return 196 * @sqrt(a * (1 - a) / na + b * (1 - b) / nb);
}

fn pctOf(n: u32, of: u32) f64 {
    return if (of == 0) 0 else 100 * @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(of));
}

fn nameOf(l: *const Line) []const u8 {
    return l.d.champs[l.row().champ].name;
}
fn gamesOf(l: *const Line) u32 {
    return l.row().games;
}
fn offRole(l: *const Line) bool {
    return l.row().share < off_role;
}
fn rateOf(l: *const Line) f64 {
    return l.rate();
}
fn changeOf(l: *const Line) f64 {
    return l.change() orelse -99;
}
fn middleOf(l: *const Line) f64 {
    const s = l.row().spread orelse return -1;
    return @as(f64, @floatFromInt(s.p75)) - @as(f64, @floatFromInt(s.p25));
}
fn pickOf(l: *const Line) f64 {
    if (l.row().rates) |r| return r[0];
    return pctOf(l.row().games, l.d.games);
}
fn banOf(l: *const Line) f64 {
    if (l.row().rates) |r| return r[1];
    return pctOf(l.d.champs[l.row().champ].banned, l.d.games);
}
fn gamesF(l: *const Line) f64 {
    return @floatFromInt(l.row().games);
}

fn who(h: *H, l: *const Line) N {
    const r = l.row();
    const c = l.d.champs[r.champ];
    return h.a(.{ .class = "who", .href = l.href }, .{
        champ.view(h, .{ .name = c.name, .src = l.icon }, .{ .named = false }),
        h.span(.{ .class = "nm" }, .{c.name}),
        if (r.share < off_role) badge.view(h, .few, .{W.off}) else null,
        if (l.all) role.view(h, r.role.ui(), .{}) else null,
    });
}

fn winCell(h: *H, l: *const Line) N {
    return stat.view(h, .{ .value = l.rate(), .scale = .aggregate, .ref = 50, .games = l.row().games });
}

fn patchCell(h: *H, l: *const Line) N {
    const p = l.row().patch orelse return h.span(.{ .class = "c-delta", .data_state = "unclear" }, .{"·"});
    return delta.view(h, .{ .d = @floatCast(l.change().?), .ci = if (p.clear) null else @floatCast(ci(p)) });
}

fn patchTip(h: *H, l: *const Line) table.Tip {
    const p = l.row().patch orelse return .{ .title = W.patch, .note = W.no_patch };
    const was = W.was.with(h, .{ .prev = l.d.prev_patch, .a = 100 * share(p.prev), .an = p.prev[0], .cur = l.d.cur_patch, .b = 100 * share(p.cur), .bn = p.cur[0] });
    return .{
        .title = W.change.with(h, .{ .d = l.change().?, .ci = ci(p) }),
        .note = if (p.clear) was else .{ .s = h.fmt("{s} {s}", .{ was.s, W.luck.s }) },
    };
}

fn playersCell(h: *H, l: *const Line) N {
    const s = l.row().spread;
    return violin.view(h, .{
        .path = l.shape,
        .lo = if (s) |x| @floatFromInt(x.p25) else 0,
        .hi = if (s) |x| @floatFromInt(x.p75) else 0,
        .at = @floatCast(l.rate()),
    });
}

fn playersTip(h: *H, l: *const Line) table.Tip {
    const s = l.row().spread orelse return .{ .title = W.players, .note = if (l.d.rank == .plat) W.no_spread else W.plat_only };
    return .{
        .title = W.spread.with(h, .{ .n = s.players }),
        .note = W.middle.with(h, .{ .lo = s.p25, .hi = s.p75, .at = l.rate() }),
    };
}

fn pickCell(h: *H, l: *const Line) N {
    const v = pickOf(l);
    return bar.view(h, v, 20, stat.figure(h, .rate, v));
}

fn banCell(h: *H, l: *const Line) N {
    const v = banOf(l);
    return bar.view(h, v, 40, stat.figure(h, .rate, v));
}

fn gamesCell(h: *H, l: *const Line) N {
    return h.span(.{ .class = "gm" }, .{phrase.num(h, .count, l.row().games)});
}

pub const min_games = [_]u32{ 500, 1500, 5000 };

/// The highest floor under 0.4% of the view's games (as many as the old minimum games)
pub fn defaultMin(games: u32) u8 {
    var k: u8 = 0;
    for (min_games, 0..) |g, i| if (@as(f64, @floatFromInt(g)) <= 0.004 * @as(f64, @floatFromInt(games))) {
        k = @intCast(i);
    };
    return k;
}

pub const Table = table.DataTable(Line, .{
    .title = W.title,
    .columns = &.{
        .{ .label = W.champion, .cell = who, .name = nameOf, .num = false, .key = "ch" },
        .{ .label = W.win, .cell = winCell, .sort = rateOf, .answer = true, .tip = W.win_note, .key = "wr" },
        .{ .label = W.patch, .cell = patchCell, .sort = changeOf, .tip = W.patch_note, .row_tip = patchTip, .key = "dl" },
        .{ .label = W.players, .cell = playersCell, .sort = middleOf, .num = false, .tip = W.players_note, .row_tip = playersTip, .wordless = true, .pick = true, .key = "pl" },
        .{ .label = W.pick, .cell = pickCell, .sort = pickOf, .pick = true, .key = "pk" },
        .{ .label = W.ban, .cell = banCell, .sort = banOf, .pick = true, .key = "bn" },
        .{ .label = W.games, .cell = gamesCell, .sort = gamesF, .pick = true, .key = "gm" },
    },
    .default_sort = 1,
    .search = nameOf,
    .games = gamesOf,
    .min_games = &min_games,
    .numbered = true,
    .bare = true,
    .rare = offRole,
    .rare_name = W.off,
});

/// The board's lines: All's (index 0), then each role's in Role's order
pub const Lines = [1 + Role.names.len][]const Line;

/// Every row's Line, made once: `base` from the page to the site root
pub fn prepare(a: std.mem.Allocator, d: *const Data, base: []const u8) !Lines {
    var out: Lines = undefined;
    const all = try a.alloc(Line, d.rows.len);
    var n: [Role.names.len]usize = @splat(0);
    for (d.rows, all, 0..) |x, *l, i| {
        const c = d.champs[x.champ];
        l.* = .{
            .d = d,
            .i = @intCast(i),
            .icon = try a.print(champ.icon_fmt, .{ d.ddragon, c.key }),
            // The row's role and rank: the champion page opens on them
            .href = try a.print("{s}champion/{s}.html{s}#role={s}{s}{s}", .{ base, c.slug, d.query, Role.slugs[@backingInt(x.role)], if (d.rank == .plat) "" else "&rank=", if (d.rank == .plat) "" else @tagName(d.rank) }),
            .shape = if (x.spread) |s| try violin.path(a, &s.shape, 100 * share(.{ x.games, x.wins }) - shape_reach, shape_step) else null,
            .all = true,
        };
        n[@backingInt(x.role)] += 1;
    }
    out[0] = all;
    for (0..Role.names.len) |k| {
        const mine = try a.alloc(Line, n[k]);
        var j: usize = 0;
        for (all) |l| if (@backingInt(l.row().role) == k) {
            mine[j] = l;
            mine[j].all = false;
            j += 1;
        };
        out[1 + k] = mine;
    }
    return out;
}

pub const Tiers = struct {
    /// The rank shown's (data.rank)
    data: *const Data,
    lines: Lines,
    table: Table,
    /// The page's own: Platinum+
    plat: *const Data,
    plat_lines: Lines,
    /// The rank picked: shown once its file is in (busy until then)
    want: Rank = .plat,
    /// The view's rank file, fetched on the first pick above Platinum+ (ui-stats.wasm);
    /// none: it failed (a build without the filter tally)
    ranks: ?*const RankData = null,
    none: bool = false,
    rank_lines: [n_groups]?Lines = @splat(null),
    /// The page's role (role/<slug>.html); null on champions.html
    page_role: ?Role = null,
    /// The role shown; null: All
    role: ?Role = null,
    /// From the page to the site root, the page's view (view_dirs' index) and its path in
    /// the view's directory: the toolbar's links to the other views
    base: []const u8 = "",
    view_index: u8 = 0,
    path: []const u8 = "champions.html",
    /// The data file, from the page, and its hash (stamp)
    src: []const u8 = "",
    stamp: u32 = 0,
    /// The toolbar's filters open (narrow screens)
    open: bool = false,

    const T = @This();

    pub fn init(d: *const Data, lines: Lines, page_role: ?Role) T {
        return .{
            .data = d,
            .lines = lines,
            .plat = d,
            .plat_lines = lines,
            .table = .{ .rows = lines[slot(page_role)], .id = "tl", .min = d.min },
            .page_role = page_role,
            .role = page_role,
        };
    }

    fn slot(r: ?Role) usize {
        return if (r) |x| 1 + @as(usize, @backingInt(x)) else 0;
    }

    /// The role picked: All, then Role's order
    pub const Shown = enum { all, top, jungle, mid, bot, support };

    fn shownOf(r: ?Role) Shown {
        return @fromBackingInt(@intCast(slot(r)));
    }

    fn roleOf(s: Shown) ?Role {
        return if (s == .all) null else @fromBackingInt(@intCast(@backingInt(s) - 1));
    }

    pub const Msg = union(enum) { role: Shown, rank: Rank, mover: u16, clear, sort: u8, filters };

    pub const Url = struct {
        /// Null: the page's own
        role: ?Shown = null,
        sort: u8 = 1,
        desc: bool = true,
        q: url.Str(24) = .{},
        /// Null: the data's own
        min: ?u8 = null,
        rank: Rank = .plat,
    };

    pub fn toUrl(t: *const T) Url {
        const u = t.table.toUrl();
        return .{
            .role = if (t.role == t.page_role) null else shownOf(t.role),
            .sort = u.sort,
            .desc = u.desc,
            .q = u.q,
            .min = if (u.min == t.data.min) null else u.min,
            .rank = t.want,
        };
    }

    pub fn fromUrl(t: *T, u: Url) void {
        t.setRole(if (u.role) |s| roleOf(s) else t.page_role);
        t.table.fromUrl(.{ .sort = u.sort, .desc = u.desc, .q = u.q, .min = u.min orelse t.data.min });
        t.want = u.rank;
    }

    /// The rank file is wanted and not yet asked for
    pub fn need(t: *const T) bool {
        return t.want != .plat and t.ranks == null and !t.none;
    }

    pub fn busy(t: *const T) bool {
        return t.want != t.data.rank;
    }

    /// The rank wanted, its file in (or failed: back to Platinum+)
    pub fn show(t: *T, a: std.mem.Allocator) !void {
        if (t.want != .plat and t.ranks == null) t.want = .plat;
        if (t.want == .plat) return t.setData(t.plat, t.plat_lines);
        const g = @backingInt(t.want) - 1;
        const d = &t.ranks.?.groups[g];
        if (t.rank_lines[g] == null) t.rank_lines[g] = try prepare(a, d, t.base);
        t.setData(d, t.rank_lines[g].?);
    }

    /// A Games floor left at the data's default moves to the new data's
    fn setData(t: *T, d: *const Data, lines: Lines) void {
        if (t.table.min == t.data.min) t.table.min = d.min;
        t.data = d;
        t.lines = lines;
        t.setRole(t.role);
    }

    fn setRole(t: *T, r: ?Role) void {
        t.role = r;
        t.table.rows = t.lines[slot(r)];
        t.table.tip = null;
        t.table.open = null;
    }

    pub fn update(t: *T, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .role => |s| {
                t.setRole(roleOf(s));
                ev.push = true;
            },
            .rank => |r| {
                t.want = r;
                ev.push = true;
            },
            // Pressed again: back to every champion
            .mover => |i| {
                const n = t.data.champs[t.data.rows[i].champ].name;
                t.table.q.set(if (t.isQuery(n)) "" else n);
                ev.push = true;
            },
            .clear => {
                t.table.q.set("");
                ev.push = true;
            },
            .sort => |i| t.table.update(.{ .sort = i }, ev),
            .filters => t.open = !t.open,
        }
    }

    fn isQuery(t: *const T, n: []const u8) bool {
        return std.ascii.eqlIgnoreCase(t.table.q.slice(), n);
    }

    /// The table's search with a × while it has text
    fn find(t: *T, h: *H) N {
        return h.span(.{ .class = "find" }, .{
            t.table.searchBox(h),
            if (t.table.q.slice().len > 0) h.button(.{ .type = "button", .class = "x", .aria_label = W.clear, .on_click = h.on(t, .clear) }, .{"×"}) else null,
        });
    }

    pub fn view(t: *T, h: *H) N {
        const d = t.data;
        const vs: ?tree.Text = if (d.cur_patch.len > 0 and d.prev_patch.len > 0) W.versus.with(h, .{ .cur = d.cur_patch, .prev = d.prev_patch }) else null;
        var roles: [1 + Role.names.len]rolepicker.Item = undefined;
        for (&roles, 0..) |*it, k| {
            const s: Shown = @fromBackingInt(@intCast(k));
            it.* = .{ .role = if (roleOf(s)) |r| r.ui() else null, .current = shownOf(t.role) == s, .on = h.on(t, .{ .role = s }) };
        }
        return h.div(.{
            .class = "c-tiers",
            .data_island = "tiers",
            .data_src = if (t.src.len > 0) t.src else null,
            .data_stamp = t.stamp,
            .data_base = t.base,
            .data_view = t.view_index,
            .data_path = t.path,
            .data_role = if (t.page_role) |r| Role.slugs[@backingInt(r)] else null,
            .data_busy = t.busy(),
        }, .{
            card.view(h, .{}, &.{
                h.div(.{ .class = "hd" }, .{
                    h.div(.{ .class = "ttl" }, .{
                        h.el(.h1, .{}, .{W.title}),
                        h.p(.{ .class = "sub" }, .{ W.scope_line.with(h, .{ .n = d.games, .in = d.region_in }), vs }),
                    }),
                    rolepicker.view(h, .{ .label = W.role_label }, &roles),
                    t.find(h),
                }),
                t.toolbar(h),
            }),
            card.view(h, .{ .flush = true }, &.{
                t.movers(h),
                if (t.onBoard()) t.board(h) else t.table.view(h),
            }),
            violin.defs(h),
        });
    }

    /// All with no search: each role's column side by side, not one long table
    fn onBoard(t: *const T) bool {
        return t.role == null and t.table.q.slice().len == 0;
    }

    fn board(t: *T, h: *H) N {
        var sorts: [board_sorts.len]segmented.Item = undefined;
        for (&sorts, board_sorts, board_labels) |*it, i, label| it.* = .{ .label = label, .selected = t.table.sort == i, .on = h.on(t, .{ .sort = i }) };
        var cols = h.list();
        for (0..Role.names.len) |k| {
            var tb = t.table;
            tb.rows = t.lines[1 + k];
            const order = tb.order(h.mem) catch {
                h.oom = true;
                return .none;
            };
            const r: Role = @fromBackingInt(@intCast(k));
            var rows = h.list();
            for (order[0..@min(order.len, board_rows)], 1..) |i, place| {
                const l = &tb.rows[i];
                const c = l.d.champs[l.row().champ];
                rows.add(h.li(.{ .key = l.i }, .{h.a(.{ .href = l.href }, .{
                    h.span(.{ .class = "n" }, .{place}),
                    champ.view(h, .{ .name = c.name, .src = l.icon }, .{ .named = false }),
                    h.span(.{ .class = "nm" }, .{c.name}),
                    winCell(h, l),
                    h.span(.{ .class = "sc" }, .{t.second(h, l)}),
                })}));
            }
            const to: Shown = @fromBackingInt(@intCast(k + 1));
            cols.add(h.div(.{ .key = k, .class = "col" }, .{
                h.button(.{ .type = "button", .class = "rh", .on_click = h.on(t, .{ .role = to }) }, .{ role.view(h, r.ui(), .{ .s = .s }), h.b(.{}, .{r.name()}), h.span(.{ .class = "ct" }, .{order.len}) }),
                h.el(.ol, .{}, .{rows.done()}),
                if (order.len > board_rows) h.button(.{ .type = "button", .class = "all", .on_click = h.on(t, .{ .role = to }) }, .{W.all_n.with(h, .{ .n = order.len })}) else null,
            }));
        }
        return h.div(.{ .class = "rb" }, .{
            h.div(.{ .class = "bs" }, .{ card.label(h, W.sort_by), segmented.view(h, .{ .s = .s, .label = W.sort_by }, &sorts) }),
            h.div(.{ .class = "cols" }, .{cols.done()}),
        });
    }

    /// The board row's second figure: the sorted column's, the patch change under Win rate
    fn second(t: *const T, h: *H, l: *const Line) N {
        return switch (t.table.sort) {
            4 => h.text(stat.figure(h, .rate, pickOf(l)).s),
            5 => h.text(stat.figure(h, .rate, banOf(l)).s),
            6 => gamesCell(h, l),
            else => patchCell(h, l),
        };
    }

    /// The same page in view `v`, keeping the fragment
    fn viewHref(t: *const T, h: *H, v: usize) []const u8 {
        var w: std.Io.Writer.Allocating = .init(h.mem);
        url.write(Url, t.toUrl(), &w.writer) catch {
            h.oom = true;
        };
        const frag = w.written();
        return h.fmt("{s}{s}{s}{s}{s}", .{ t.base, view_dirs[v], t.path, if (frag.len > 0) "#" else "", frag });
    }

    fn toolbar(t: *T, h: *H) N {
        const region = t.view_index / 2;
        const period = t.view_index % 2;
        const patch = if (t.data.cur_patch.len > 0) tree.Text{ .s = t.data.cur_patch } else W.patch;
        var ranks: [W.ranks.len]segmented.Item = undefined;
        for (&ranks, W.ranks, 0..) |*it, l, i| it.* = .{ .label = l, .selected = @backingInt(t.want) == i, .disabled = i > 0 and t.none, .on = h.on(t, .{ .rank = @fromBackingInt(@intCast(i)) }) };
        return card.toolbar(h, &.{
            filterbar.view(h, .{
                .summary = W.picked.with(h, .{ .r = W.regions[region].s, .p = if (period == 1) patch.s else W.days.s, .k = W.ranks[@backingInt(t.want)].s }),
                .open = t.open,
                .on_toggle = h.on(t, .filters),
            }, &.{
                segmented.view(h, .{ .label = W.region }, &.{
                    .{ .label = W.regions[0], .selected = region == 0, .href = t.viewHref(h, period) },
                    .{ .label = W.regions[1], .selected = region == 1, .href = t.viewHref(h, 2 + period) },
                }),
                segmented.view(h, .{ .label = W.period }, &.{
                    .{ .label = W.days, .selected = period == 0, .href = t.viewHref(h, 2 * region) },
                    .{ .label = patch, .selected = period == 1, .href = t.viewHref(h, 2 * region + 1) },
                }),
                segmented.view(h, .{ .label = W.rank_pick }, &ranks),
            }),
            filterbar.group(h, W.min_games, t.table.minPick(h).?),
        });
    }

    /// This patch's clearest moves in the role shown (not off-role): risers, then fallers
    fn movers(t: *T, h: *H) N {
        const d = t.data;
        if (d.cur_patch.len == 0) return .none;
        var up: [movers_each]?*const Line = @splat(null);
        var down: [movers_each]?*const Line = @splat(null);
        for (t.table.rows) |*l| {
            const p = l.row().patch orelse continue;
            if (!p.clear or l.row().share < off_role) continue;
            const c = l.change().?;
            if (c > 0) keep(&up, l, c) else if (c < 0) keep(&down, l, -c);
        }
        if (up[0] == null and down[0] == null) return .none;
        var chips = h.list();
        for ([_][]?*const Line{ &up, &down }, 0..) |side, k| {
            if (k == 1 and up[0] != null and down[0] != null) chips.add(h.span(.{ .class = "sep" }, .{}));
            for (side) |x| if (x) |l| chips.add(chip.view(h, .{ .on = h.on(t, .{ .mover = l.i }), .pressed = t.isQuery(nameOf(l)), .label = .{ .s = nameOf(l) } }, .{
                champ.view(h, .{ .name = nameOf(l), .src = l.icon }, .{ .px = .@"20" }),
                delta.view(h, .{ .d = @floatCast(l.change().?) }),
            }));
        }
        return h.div(.{ .class = "moved" }, .{
            card.label(h, W.moved.with(h, .{ .p = d.cur_patch })),
            h.div(.{ .class = "chips" }, .{chips.done()}),
            h.a(.{ .class = "more", .href = h.fmt("{s}{s}patch.html", .{ t.base, view_dirs[t.view_index] }) }, .{W.patch_link}),
        });
    }

    /// `l` into `best` (biggest `by` first) if it beats the smallest
    fn keep(best: []?*const Line, l: *const Line, by: f64) void {
        var at = best.len;
        while (at > 0) : (at -= 1) {
            const x = best[at - 1] orelse continue;
            if (@abs(x.change().?) >= by) break;
        }
        if (at == best.len) return;
        var k = best.len - 1;
        while (k > at) : (k -= 1) best[k] = best[k - 1];
        best[at] = l;
    }
};

pub const css =
    \\@layer components {
    \\  .c-tiers { display: grid; gap: var(--sp-4); }
    \\  .c-tiers .hd { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-3) var(--sp-5); }
    \\  .c-tiers .ttl { margin-right: var(--sp-2); }
    \\  .c-tiers h1 { margin: 0; }
    \\  .c-tiers .sub { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-tiers .find { position: relative; display: flex; flex: 0 1 260px; margin-left: auto; }
    \\  .c-tiers .find > input { flex: 1; min-width: 0; padding-right: 32px; }
    \\  .c-tiers .find > input::-webkit-search-cancel-button { display: none; }
    \\  .c-tiers .find > .x { all: unset; position: absolute; right: 4px; top: 50%; transform: translateY(-50%);
    \\    width: 26px; height: 26px; display: grid; place-items: center; border-radius: 50%; cursor: pointer;
    \\    color: var(--muted); font-size: var(--fs-l); line-height: 1; }
    \\  .c-tiers .find > .x:hover { color: var(--text); background: var(--ctl-bg-2); }
    \\  .c-tiers .find > .x:focus-visible { outline: 2px solid var(--focus); }
    \\  .c-tiers .moved { position: relative; display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-2) var(--sp-4);
    \\    border-bottom: 1px solid var(--line); }
    \\  .c-tiers .moved:hover { background: var(--panel-2); }
    \\  .c-tiers .moved .more::after { content: ""; position: absolute; inset: 0; }
    \\  .c-tiers .moved .chips { position: relative; z-index: 1; }
    \\  .c-tiers .moved .chips { display: flex; flex-wrap: wrap; gap: var(--sp-1); align-items: center; }
    \\  .c-tiers .moved .sep { width: 1px; height: 20px; margin: 0 var(--sp-1); background: var(--line); }
    \\  .c-tiers .moved > .lab { white-space: nowrap; }
    \\  .c-tiers .moved .more { margin-left: auto; font-size: var(--fs-s); white-space: nowrap; }
    \\  .c-tiers .c-table-wrap { overflow-x: clip; }
    \\  .c-tiers .rb { container-type: inline-size; }
    \\  .c-tiers .bs { display: flex; align-items: center; gap: var(--sp-2); padding: var(--sp-2) var(--sp-4);
    \\    border-bottom: 1px solid var(--line); }
    \\  .c-tiers .rb .cols { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); }
    \\  .c-tiers .rb .col { min-width: 0; border-right: 1px solid var(--line); display: flex; flex-direction: column; }
    \\  .c-tiers .rb .col:last-child { border-right: 0; }
    \\  .c-tiers .rb .rh { all: unset; display: flex; align-items: center; gap: 6px; height: 36px; padding: 0 var(--sp-3);
    \\    background: var(--panel-2); border-bottom: 1px solid var(--line); cursor: pointer; font-size: var(--fs-s); }
    \\  .c-tiers .rb .rh:hover b { color: var(--accent); }
    \\  .c-tiers .rb .rh:focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-tiers .rb .rh > .c-role { color: var(--muted); }
    \\  .c-tiers .rb .rh > .ct { margin-left: auto; color: var(--faint); font-variant-numeric: tabular-nums; }
    \\  .c-tiers .rb ol { list-style: none; margin: 0; padding: 0; flex: 1; }
    \\  .c-tiers .rb li > a { display: grid; grid-template-columns: 18px 24px minmax(0, 1fr) auto 44px; gap: var(--sp-2);
    \\    align-items: center; height: 34px; padding: 0 var(--sp-3); color: inherit; border-bottom: 1px solid var(--line); }
    \\  .c-tiers .rb li > a:hover { background: var(--panel-2); text-decoration: none; }
    \\  .c-tiers .rb li > a:hover .nm { color: var(--accent); }
    \\  .c-tiers .rb .n { color: var(--faint); font-size: var(--fs-xs); text-align: right; font-variant-numeric: tabular-nums; }
    \\  .c-tiers .rb .nm { font-weight: var(--w-m); min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-tiers .rb .c-stat { font-weight: var(--w-b); }
    \\  .c-tiers .rb .sc { text-align: right; font-size: var(--fs-s); color: var(--muted); font-variant-numeric: tabular-nums; }
    \\  .c-tiers .rb .all { all: unset; padding: var(--sp-2) var(--sp-3); font-size: var(--fs-s); color: var(--accent); cursor: pointer; }
    \\  .c-tiers .rb .all:hover { text-decoration: underline; }
    \\  .c-tiers .rb .all:focus-visible { outline: 2px solid var(--focus); }
    \\  .c-tiers .rb .bs > .c-seg { min-width: 0; overflow-x: auto; scrollbar-width: none; }
    \\  @container (max-width: 420px) {
    \\    .c-tiers .rb .bs { padding-inline: var(--sp-3); }
    \\    .c-tiers .rb .bs > .lab { display: none; }
    \\  }
    \\  @container (max-width: 900px) {
    \\    .c-tiers .rb .cols { grid-template-columns: minmax(0, 1fr); }
    \\    .c-tiers .rb .col { border-right: 0; }
    \\    .c-tiers .rb li:nth-child(n+6) { display: none; }
    \\  }
    \\  .c-tiers[data-busy] .moved, .c-tiers[data-busy] .c-table { opacity: 0.55; transition: opacity 0.2s; }
    \\  .c-tiers .c-toolbar { container-type: inline-size; }
    \\  .c-tiers .c-toolbar > .grp { margin-left: auto; }
    \\  .c-tiers .pl .rt { display: block; width: 100%; }
    \\  .c-tiers .c-table thead th { top: var(--header); }
    \\  .c-tiers .who { display: flex; align-items: center; gap: var(--sp-2); color: inherit; text-decoration: none; }
    \\  .c-tiers .who .nm { font-weight: 600; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-tiers .who .c-role { margin-left: auto; color: var(--muted); }
    \\  .c-tiers .wr .c-stat { font-size: var(--fs-l); }
    \\  .c-tiers .gm { color: var(--muted); }
    \\  .c-tiers td.num.p3 { color: var(--faint); }
    \\  .c-tiers .num.p3 { width: 44px; }
    \\  .c-tiers .wr { width: 96px; }
    \\  .c-tiers .ch { width: 210px; }
    \\  .c-tiers .dl { width: 84px; }
    \\  .c-tiers .pk, .c-tiers .bn { width: 17%; }
    \\  .c-tiers .pl { width: 30%; }
    \\  .c-tiers td:is(.pk, .bn) .c-bar { display: flex; }
    \\  .c-tiers td:is(.pk, .bn) .c-bar > span { flex: 1; width: auto; height: 6px; border-radius: 3px; }
    \\  .c-tiers td:is(.pk, .bn) .c-bar > span > i { border-radius: 3px; }
    \\  .c-tiers .gm { width: 88px; }
    \\  @container (max-width: 520px) {
    \\    .c-tiers .c-toolbar > .grp > .lab { display: none; }
    \\    .c-tiers .c-filters[data-open] { flex-basis: 100%; }
    \\  }
    \\  @media (max-width: 620px) {
    \\    .c-tiers .hd > .find { flex-basis: 100%; margin-left: 0; }
    \\    .c-tiers .moved .chips { flex: 1; min-width: 0; flex-wrap: nowrap; overflow-x: auto; scrollbar-width: none; }
    \\    .c-tiers .moved .more { font-size: 0; }
    \\  }
    \\  @container (max-width: 620px) {
    \\    .c-tiers .ch { width: auto; }
    \\    .c-tiers .wr { width: 66px; }
    \\    .c-tiers .dl { width: 52px; }
    \\    .c-tiers .pl, .c-tiers .pk, .c-tiers .bn, .c-tiers .gm { width: 92px; }
    \\    .c-tiers .c-violin { min-width: 0; }
    \\    .c-tiers .who .c-badge { display: none; }
    \\    .c-tiers td.ch { max-width: 120px; }
    \\  }
    \\}
    \\
;
