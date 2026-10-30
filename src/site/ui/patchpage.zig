//! Patch changes (/patch; docs/plan/ui/patch.md): what Riot changed this patch, next
//! to what moved. PatchHead, filter chips with their counts and the role in place,
//! then every champion role with enough games on both patches in one DataTable:
//! Riot's badge, both rates, the change drawn with its range, the lane lead, its
//! matchups that moved. A row opens what Riot changed and its matchup moves. The
//! items and runes Riot changed sit over the table as chips, one open at a time.
//!
//! The server renders the default state from the same Data the view's data file
//! (data/patch.bin) carries; ui-patch.wasm decodes that file and adopts the page
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const table = @import("table.zig");
const card = @import("card.zig");
const chip = @import("chip.zig");
const rolepicker = @import("rolepicker.zig");
const role = @import("role.zig");
const delta = @import("delta.zig");
const badge = @import("badge.zig");
const champ = @import("champ.zig");
const art = @import("art.zig");
const changeline = @import("changeline.zig");
const patchhead = @import("patchhead.zig");
const tiers = @import("tiers.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "PatchPage";
pub const scope = .{".c-patch"};

pub const sel = "[data-island=patch]";

/// core.Role's order (site/patch.zig checks it)
pub const Role = tiers.Role;
pub const stamp = tiers.stamp;

/// Half-widths of the drawn ranges: the listing's z, so a whisker clear of 0 is a
/// coloured row (patchday.Options.z)
pub const z = 2.58;

pub const Data = struct {
    cur_patch: []const u8,
    prev_patch: []const u8,
    /// PatchHead's ‹ ›, hrefs from the page
    older: ?patchhead.Pair = null,
    newer: ?patchhead.Pair = null,
    /// An older pair's page: cur_patch is over, its games all in
    finished: bool = false,
    /// The region's games on the current patch so far
    games: u32,
    /// Games a champion role needs on both patches (patchday.Options.min_role_games)
    min_games: u32,
    /// The minute "lane lead" is at (curvesfile.lane_minute)
    lane_minute: u8,
    ddragon: []const u8,
    /// The patch view's query: champion and matchup pages on this patch's numbers
    patch_query: []const u8,
    /// Riot's notes page, "" without
    notes: []const u8,
    /// Riot's changes are known (Data Dragon read): else no Riot column or filter
    riot: bool,
    champs: []const Champ,
    /// Champions Riot changed (Change.id: champs index)
    changes: []const Change,
    /// By change in win rate, biggest rise first
    rows: []const Row,
    /// The items and runes Riot changed
    items: []const Kit = &.{},
    runes: []const Kit = &.{},
};

/// A changed item or rune (Change.id: Data Dragon's) and the champions using it most
pub const Kit = struct {
    change: Change,
    icon: []const u8,
    users: []const User,
};

/// `share`: the biggest of three: of a champion role's players who finished three items,
/// those with the item among them; of those with boots, as their boots; of those with a
/// start, in it. A floor, as the builds file keeps the commonest only. Or of all its
/// players, those with the rune on their page. `row`: its Data.rows index
pub const User = struct { champ: u16, role: Role, share: f32, row: ?u16 };

pub const Champ = struct {
    name: []const u8,
    /// Data Dragon's
    key: []const u8,
    slug: []const u8,
};

/// Games and wins
pub const Count = [2]u32;

pub const Status = enum { changed, new, gone };

pub const Change = struct {
    id: u32,
    name: []const u8,
    status: Status = .changed,
    tone: badge.Tone,
    /// The badge's text, "Q, W, stats"
    slots: []const u8,
    lines: []const changeline.Line,
};

pub const Row = struct {
    champ: u16,
    role: Role,
    prev: Count,
    cur: Count,
    /// Too big a change to be luck (patchday's z, enough games on both)
    clear: bool,
    /// Games ahead in lane gold at lane_minute
    lane: ?Lane,
    /// Index into changes
    change: ?u16,
    /// Its matchups that moved clearly, then its biggest other moves, from its side
    moves: []const Move,
};

pub const Lane = struct { prev: Count, cur: Count, clear: bool };

pub const Move = struct {
    them: u16,
    prev: Count,
    cur: Count,
    clear: bool,
    /// Its gold lead moved clearly
    gold: ?Gold = null,
    /// Its page in the patch view's directory, from its side
    path: []const u8 = "",

    fn moved(m: Move) bool {
        return m.clear or m.gold != null;
    }
};

/// The minute a matchup's median gold lead moved most, among clear moves
pub const Gold = struct { minute: u8, prev: i16, cur: i16, games: u32 };

const W = struct {
    pub const up = phrase.Phrase("▲{n:count}");
    pub const down = phrase.Phrase("▼{n:count}");
    pub const moved = plain("Moved clearly");
    pub const moved_says = Phrase("Moved clearly: win rate {u:count} up, {d:count} down; {o:count} more in lane or matchups");
    pub const all = plain("All");
    pub const role_label = plain("Role");
    pub const show = plain("Show");
    pub const champion = plain("Champion");
    pub const riot = plain("Riot");
    pub const last = plain("Last patch");
    pub const this = plain("This patch");
    pub const change = plain("Change");
    pub const lane = plain("Lane lead");
    pub const games = plain("Games");
    pub const mus = plain("Matchups");
    pub const mus_note = plain("Its lane matchups whose win rate or gold lead moved clearly, biggest first.");
    pub const more = Phrase("+{n:int}");
    pub const listed = plain(std.fmt.comptimePrint("Every champion role with {d}+ games on both patches, and the main role of each champion Riot changed.", .{role_games}));
    pub const riot_note = plain("What Riot changed in the champion this patch, from Riot's data files.");
    pub const change_note = plain("Win rate this patch minus last, in points. The line is where the real change likely is; coloured when too big to be luck.");
    pub const lane_note = plain("Games ahead in lane gold, this patch minus last, in points.");
    pub const points = Phrase("{d:points} points");
    pub const likely = Phrase("Likely between {lo:points} and {hi:points}. {n:count} games on {p:text} so far.");
    pub const likely_done = Phrase("Likely between {lo:points} and {hi:points}. {n:count} games on {p:text}.");
    pub const luck = plain(" Could be luck.");
    pub const ahead = Phrase("Ahead in {a:rate} of games, then {b:rate}.");
    pub const at = Phrase(" at {m:int}′");
    pub const gold_short = Phrase("gold {a:signed} → {b:signed}");
    pub const changed = plain("Riot changed");
    pub const unchanged = plain("Nothing in Riot's data.");
    pub const pair = Phrase("{r:text}, {a:text} → {b:text}");
    pub const won = Phrase("Won {a:rate} of {an:count} → {b:rate} of {bn:count}");
    pub const ahead_at = Phrase("Ahead at {m:int}: {a:rate} → {b:rate}");
    pub const its = plain("Its matchups");
    pub const no_moves = Phrase("None with {n:count} games on both patches.");
    pub const on = Phrase("{n:text} on {p:text} ›");
    pub const new = plain("new");
    pub const gone = plain("removed");
    pub const items = plain("Items");
    pub const runes = plain("Runes");
    pub const bought = plain("Bought most by");
    pub const taken = plain("Taken most by");
    pub const none = plain("Nothing listed here yet.");
    pub const buffed = plain("buffed");
    pub const nerfed = plain("nerfed");
};

pub const Shown = enum { all, top, jungle, mid, bot, support };

fn roleOf(s: Shown) ?Role {
    return if (s == .all) null else @fromBackingInt(@intCast(@backingInt(s) - 1));
}

fn inRole(s: Shown, r: Role) bool {
    const want = roleOf(s) orelse return true;
    return want == r;
}

fn share(c: Count) f64 {
    return @as(f64, @floatFromInt(c[1])) / @as(f64, @floatFromInt(@max(c[0], 1)));
}

/// Points, b minus a
fn points(a: Count, b: Count) f64 {
    return 100 * (share(b) - share(a));
}

/// `z` standard errors of a difference of two rates, in points
fn halfWidth(a: Count, b: Count) f64 {
    const pa = share(a);
    const pb = share(b);
    const na: f64 = @floatFromInt(@max(a[0], 1));
    const nb: f64 = @floatFromInt(@max(b[0], 1));
    return 100 * z * @sqrt(pa * (1 - pa) / na + pb * (1 - pb) / nb);
}

fn icon(h: *H, d: *const Data, c: u16) N {
    const x = d.champs[c];
    return champ.view(h, .{ .name = x.name, .src = h.fmt(champ.icon_fmt, .{ d.ddragon, x.key }) }, .{ .named = false, .px = .@"20" });
}

/// One champion row: the data's with what its cells need
pub const Line = struct {
    d: *const Data,
    i: u16,
    href: []const u8,
    /// From the page to the site root
    base: []const u8,
    /// The bars' edge, every row's
    span: f32,

    fn row(l: *const Line) *const Row {
        return &l.d.rows[l.i];
    }

    fn moved(l: *const Line) bool {
        const r = l.row();
        return r.clear or (if (r.lane) |x| x.clear else false) or l.mus() > 0;
    }

    /// Its matchups that moved clearly (Row.moves' first)
    fn mus(l: *const Line) usize {
        var n: usize = 0;
        for (l.row().moves) |m| n += @intFromBool(m.moved());
        return n;
    }
};

fn nameOf(l: *const Line) []const u8 {
    return l.d.champs[l.row().champ].name;
}
fn riotOf(l: *const Line) f64 {
    const c = l.row().change orelse return 0;
    return @floatFromInt(l.d.changes[c].lines.len + 1);
}
fn prevOf(l: *const Line) f64 {
    return share(l.row().prev);
}
fn curOf(l: *const Line) f64 {
    return share(l.row().cur);
}
fn changeOf(l: *const Line) f64 {
    return points(l.row().prev, l.row().cur);
}
fn laneOf(l: *const Line) f64 {
    const x = l.row().lane orelse return -99;
    return points(x.prev, x.cur);
}
fn gamesOf(l: *const Line) f64 {
    return @floatFromInt(l.row().cur[0]);
}

fn who(h: *H, l: *const Line) N {
    const r = l.row();
    return h.a(.{ .class = "who", .href = l.href }, .{
        icon(h, l.d, r.champ),
        h.span(.{ .class = "nm" }, .{nameOf(l)}),
        role.view(h, r.role.ui(), .{}),
    });
}

fn riotBadge(h: *H, c: Change) N {
    return switch (c.status) {
        .new => badge.view(h, .accent, .{W.new}),
        .gone => badge.view(h, .neutral, .{W.gone}),
        .changed => badge.riot(h, c.tone, c.slots),
    };
}

fn riotCell(h: *H, l: *const Line) N {
    const c = l.row().change orelse return .none;
    return riotBadge(h, l.d.changes[c]);
}

fn rate(h: *H, c: Count) N {
    return h.span(.{ .class = "r" }, .{phrase.num(h, .rate, 100 * share(c))});
}

fn prevCell(h: *H, l: *const Line) N {
    return rate(h, l.row().prev);
}
fn curCell(h: *H, l: *const Line) N {
    return rate(h, l.row().cur);
}

/// The change drawn with its range, and its number
fn moveCell(h: *H, a: Count, b: Count, clear: bool, span: f32) N {
    const m = moveOf(a, b);
    return h.span(.{ .class = "mv", .data_clear = clear }, .{
        delta.bar(h, .{ .d = m.d, .ci = m.ci, .span = span }),
        moveText(h, m, clear),
    });
}

const Shift = struct { d: f32, ci: f32 };

fn moveOf(a: Count, b: Count) Shift {
    return .{ .d = @floatCast(points(a, b)), .ci = @floatCast(halfWidth(a, b)) };
}

/// The change's number, grey when it could be luck
fn moveText(h: *H, m: Shift, clear: bool) N {
    return delta.view(h, .{ .d = m.d, .ci = if (clear) null else @max(m.ci, @abs(m.d) + 0.01) });
}

fn changeCell(h: *H, l: *const Line) N {
    const r = l.row();
    return moveCell(h, r.prev, r.cur, r.clear, l.span);
}

fn rangeTip(h: *H, d: *const Data, a: Count, b: Count, clear: bool) table.Tip {
    const c = points(a, b);
    const w = halfWidth(a, b);
    const args = .{ .lo = c - w, .hi = c + w, .n = b[0], .p = d.cur_patch };
    const likely = if (d.finished) W.likely_done.with(h, args) else W.likely.with(h, args);
    return .{
        .title = W.points.with(h, .{ .d = c }),
        .note = if (clear) likely else .{ .s = h.fmt("{s}{s}", .{ likely.s, W.luck.s }) },
    };
}

fn changeTip(h: *H, l: *const Line) table.Tip {
    const r = l.row();
    return rangeTip(h, l.d, r.prev, r.cur, r.clear);
}

fn laneCell(h: *H, l: *const Line) N {
    const x = l.row().lane orelse return h.span(.{ .class = "c-delta", .data_state = "unclear" }, .{"·"});
    return moveCell(h, x.prev, x.cur, x.clear, l.span);
}

fn laneTip(h: *H, l: *const Line) table.Tip {
    const x = l.row().lane orelse return .{ .title = W.lane, .note = W.none };
    const c = points(x.prev, x.cur);
    const ahead = W.ahead.with(h, .{ .a = 100 * share(x.prev), .b = 100 * share(x.cur) });
    return .{
        .title = W.points.with(h, .{ .d = c }),
        .note = if (x.clear) ahead else .{ .s = h.fmt("{s}{s}", .{ ahead.s, W.luck.s }) },
    };
}

fn musOf(l: *const Line) f64 {
    return @floatFromInt(l.mus());
}

/// How many moved, and the two biggest: the opponent and its change
fn musCell(h: *H, l: *const Line) N {
    const n = l.mus();
    if (n == 0) return h.span(.{ .class = "c-delta", .data_state = "unclear" }, .{"·"});
    var top = h.list();
    for (l.row().moves[0..@min(n, 2)], 0..) |m, k| top.add(h.span(.{ .key = k, .class = "mo" }, .{
        icon(h, l.d, m.them),
        moveText(h, moveOf(m.prev, m.cur), m.clear),
    }));
    return h.span(.{ .class = "mus" }, .{
        h.span(.{ .class = "k" }, .{phrase.num(h, .count, n)}),
        top.done(),
        if (n > 2) h.span(.{ .class = "mo more" }, .{W.more.with(h, .{ .n = n - 2 })}) else null,
    });
}

fn gamesCell(h: *H, l: *const Line) N {
    return h.span(.{ .class = "gm" }, .{phrase.num(h, .count, l.row().cur[0])});
}

/// Under a tapped row: what Riot changed, both patches' numbers, its biggest matchup
/// moves, and its page on this patch
fn detail(h: *H, l: *const Line) N {
    const d = l.d;
    const r = l.row();
    var moves = h.list();
    for (r.moves, 0..) |m, k| moves.add(h.li(.{ .key = k }, .{
        icon(h, d, m.them),
        if (m.path.len > 0) h.a(.{ .class = "nm", .href = h.fmt("{s}{s}", .{ m.path, d.patch_query }) }, .{d.champs[m.them].name}) else h.span(.{ .class = "nm" }, .{d.champs[m.them].name}),
        moveCell(h, m.prev, m.cur, m.clear, l.span),
        if (m.gold) |g| h.span(.{ .class = "gd" }, .{ W.gold_short.with(h, .{ .a = g.prev, .b = g.cur }), h.small(.{}, .{W.at.with(h, .{ .m = g.minute })}) }) else null,
    }));
    return h.div(.{ .class = "rd" }, .{
        if (d.riot) h.div(.{ .class = "blk" }, .{
            card.label(h, W.changed),
            if (r.change) |c| changeline.view(h, d.changes[c].lines) else h.p(.{ .class = "x" }, .{W.unchanged}),
        }) else null,
        h.div(.{ .class = "blk" }, .{
            card.label(h, W.pair.with(h, .{ .r = r.role.name(), .a = d.prev_patch, .b = d.cur_patch })),
            h.p(.{}, .{W.won.with(h, .{ .a = 100 * share(r.prev), .an = r.prev[0], .b = 100 * share(r.cur), .bn = r.cur[0] })}),
            if (r.lane) |x| h.p(.{}, .{W.ahead_at.with(h, .{ .m = d.lane_minute, .a = 100 * share(x.prev), .b = 100 * share(x.cur) })}) else null,
            h.a(.{ .href = l.href }, .{W.on.with(h, .{ .n = nameOf(l), .p = d.cur_patch })}),
        }),
        h.div(.{ .class = "blk" }, .{
            card.label(h, W.its),
            if (r.moves.len > 0) h.ul(.{ .class = "mvs" }, .{moves.done()}) else h.p(.{ .class = "x" }, .{W.no_moves.with(h, .{ .n = pair_games })}),
        }),
    });
}

/// Games a champion role needs on both patches to be listed (patchday.Options.min_role_games)
pub const role_games = 300;

/// Games a matchup needs on both patches (patchday.Options.min_pair_games)
pub const pair_games = 400;

pub const Table = table.DataTable(Line, .{
    .title = W.champion,
    .columns = &.{
        .{ .label = W.champion, .cell = who, .name = nameOf, .num = false, .tip = W.listed, .key = "ch" },
        .{ .label = W.riot, .cell = riotCell, .sort = riotOf, .num = false, .tip = W.riot_note, .key = "ri" },
        .{ .label = W.last, .cell = prevCell, .sort = prevOf, .priority = 3, .key = "pv" },
        .{ .label = W.this, .cell = curCell, .sort = curOf, .priority = 2, .key = "cu" },
        .{ .label = W.change, .cell = changeCell, .sort = changeOf, .answer = true, .tip = W.change_note, .row_tip = changeTip, .key = "dl" },
        .{ .label = W.lane, .cell = laneCell, .sort = laneOf, .priority = 2, .tip = W.lane_note, .row_tip = laneTip, .key = "ln" },
        .{ .label = W.mus, .cell = musCell, .sort = musOf, .num = false, .priority = 2, .tip = W.mus_note, .key = "mu" },
        .{ .label = W.games, .cell = gamesCell, .sort = gamesOf, .priority = 3, .key = "gm" },
    },
    .default_sort = 4,
    .search = nameOf,
    .detail = detail,
    .bare = true,
});

/// Every row's Line, made once; the shown ones are copied into `shown` per filter
pub const Lines = struct {
    rows: []const Line,
    shown: []Line,
};

/// Its champion page on this patch's numbers, open on `r`
fn champHref(a: std.mem.Allocator, d: *const Data, base: []const u8, c: u16, r: Role) ![]const u8 {
    return a.print("{s}champions/{s}/{s}{s}", .{ base, d.champs[c].slug, Role.slugs[@backingInt(r)], d.patch_query });
}

/// `base`: from the page to the site root
pub fn prepare(a: std.mem.Allocator, d: *const Data, base: []const u8) !Lines {
    // Every bar shares one edge: the biggest clear move, at least 4 points
    var span: f64 = 4;
    for (d.rows) |r| if (r.clear) {
        span = @max(span, @abs(points(r.prev, r.cur)));
    };
    for (d.rows) |r| for (r.moves) |m| if (m.clear) {
        span = @max(span, @abs(points(m.prev, m.cur)));
    };
    const edge: f32 = @floatCast(@ceil(span));
    const rows = try a.alloc(Line, d.rows.len);
    for (rows, d.rows, 0..) |*l, r, i| l.* = .{
        .d = d,
        .i = @intCast(i),
        .href = try champHref(a, d, base, r.champ, r.role),
        .base = base,
        .span = edge,
    };
    return .{ .rows = rows, .shown = try a.alloc(Line, rows.len) };
}

pub const Page = struct {
    d: *const Data,
    lines: Lines,
    table: Table,
    role: Shown = .all,
    /// The chips: neither is All
    moved: bool = true,
    riot: bool = true,
    /// The item or rune open over the table: Data.items' index, then runes' after them
    kit: ?u16 = null,
    /// From the page to the site root; the data file from the page and its hash (stamp)
    base: []const u8 = "",
    src: []const u8 = "",
    stamp: u32 = 0,

    const P = @This();

    pub fn init(d: *const Data, lines: Lines) P {
        var p: P = .{ .d = d, .lines = lines, .table = .{ .rows = &.{}, .id = "pc" }, .riot = d.riot };
        p.refilter();
        return p;
    }

    pub const Msg = union(enum) { role: Shown, moved, riot, all, kit: u16 };

    pub const Url = struct {
        role: Shown = .all,
        moved: bool = true,
        riot: bool = true,
        sort: u8 = 4,
        desc: bool = true,
    };

    pub fn toUrl(p: *const P) Url {
        return .{
            .role = p.role,
            .moved = p.moved,
            .riot = p.riot or !p.d.riot,
            .sort = p.table.sort,
            .desc = p.table.desc,
        };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.role = u.role;
        p.moved = u.moved;
        p.riot = u.riot and p.d.riot;
        p.table.fromUrl(.{ .sort = u.sort, .desc = u.desc });
        p.refilter();
    }

    fn keep(p: *const P, l: *const Line) bool {
        const r = l.row();
        if (!inRole(p.role, r.role)) return false;
        if (!p.moved and !p.riot) return true;
        return (p.moved and l.moved()) or (p.riot and r.change != null);
    }

    /// A copy's own shown rows, so filtering it leaves the original's alone
    pub fn own(p: *P, a: std.mem.Allocator) !void {
        p.lines.shown = try a.alloc(Line, p.lines.rows.len);
        p.refilter();
    }

    /// The tables' rows for the filters; an open row or tip closes
    fn refilter(p: *P) void {
        var n: usize = 0;
        for (p.lines.rows) |*l| if (p.keep(l)) {
            p.lines.shown[n] = l.*;
            n += 1;
        };
        p.table.rows = p.lines.shown[0..n];
        p.table.open = null;
        p.table.tip = null;
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .role => |s| p.role = s,
            .moved => p.moved = !p.moved,
            .riot => p.riot = !p.riot,
            .all => {
                p.moved = false;
                p.riot = false;
            },
            .kit => |k| {
                p.kit = if (p.kit == k) null else k;
                return;
            },
        }
        ev.push = true;
        p.refilter();
    }

    const Counts = struct { up: u32 = 0, down: u32 = 0, others: u32 = 0, riot: u32 = 0, all: u32 = 0 };

    /// The role's rows each chip shows: moved (win rate each way, then lane or matchups
    /// only), Riot changed, every row
    fn counts(p: *const P) Counts {
        var c: Counts = .{};
        for (p.lines.rows) |*l| {
            const r = l.row();
            if (!inRole(p.role, r.role)) continue;
            c.all += 1;
            if (r.clear) {
                if (points(r.prev, r.cur) > 0) c.up += 1 else c.down += 1;
            } else if (l.moved()) c.others += 1;
            if (r.change != null) c.riot += 1;
        }
        return c;
    }

    pub fn view(p: *P, h: *H) N {
        const d = p.d;
        const c = p.counts();
        var roles: [Role.names.len + 1]rolepicker.Item = undefined;
        for (&roles, 0..) |*it, k| {
            const s: Shown = @fromBackingInt(@intCast(k));
            it.* = .{ .role = if (roleOf(s)) |r| r.ui() else null, .current = p.role == s, .on = h.on(p, .{ .role = s }) };
        }
        return h.div(.{
            .class = "c-patch",
            .data_island = "patch",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = p.stamp,
            .data_base = p.base,
            .data_riot = d.riot,
        }, .{
            patchhead.view(h, .{
                .pair = .{ .cur = d.cur_patch, .prev = d.prev_patch },
                .older = d.older,
                .newer = d.newer,
                .games = d.games,
                .finished = d.finished,
                .notes = if (d.notes.len > 0) d.notes else null,
            }),
            p.kits(h),
            card.view(h, .{ .flush = true }, &.{
                card.toolbar(h, &.{
                    h.div(.{ .class = "chips" }, .{
                        // ▲▼ win rate moves, +N the rows only their lane or matchups moved
                        chip.view(h, .{ .pressed = p.moved, .label = W.moved_says.with(h, .{ .u = c.up, .d = c.down, .o = c.others }), .on = h.on(p, .moved) }, .{
                            // The leading spaces part the badge from the words for the label
                            // check; a flex item's line drops them
                            W.moved,
                            h.span(.{ .class = "n", .data_d = "up" }, .{ " ", W.up.with(h, .{ .n = c.up }) }),
                            h.span(.{ .class = "n", .data_d = "down" }, .{ " ", W.down.with(h, .{ .n = c.down }) }),
                            if (c.others > 0) h.span(.{ .class = "n" }, .{ " ", W.more.with(h, .{ .n = c.others }) }) else null,
                        }),
                        if (d.riot) chip.view(h, .{ .pressed = p.riot, .on = h.on(p, .riot) }, .{ W.changed, h.span(.{ .class = "n" }, .{phrase.num(h, .count, c.riot)}) }) else null,
                        chip.view(h, .{ .pressed = !p.moved and !p.riot, .on = h.on(p, .all) }, .{ W.all, h.span(.{ .class = "n" }, .{phrase.num(h, .count, c.all)}) }),
                    }),
                    rolepicker.view(h, .{ .v = .compact, .label = W.role_label }, &roles),
                }),
                if (p.table.rows.len > 0) p.table.view(h) else h.p(.{ .class = "empty" }, .{W.none}),
            }),
        });
    }

    /// Items then runes Riot changed, a chip each; the open one's lines and who uses it
    /// under them
    fn kits(p: *P, h: *H) N {
        const d = p.d;
        if (d.items.len + d.runes.len == 0) return .none;
        const open: ?Kit = if (p.kit) |k| (if (k < d.items.len) d.items[k] else d.runes[k - d.items.len]) else null;
        const rune = if (p.kit) |k| k >= d.items.len else false;
        return h.div(.{ .class = "kits" }, .{
            p.kitRow(h, W.items, d.items, 0),
            p.kitRow(h, W.runes, d.runes, @intCast(d.items.len)),
            if (open) |k| h.div(.{ .class = "kd" }, .{
                h.div(.{ .class = "blk" }, .{ h.b(.{}, .{k.change.name}), changeline.view(h, k.change.lines) }),
                users(h, d, k.users, if (rune) W.taken else W.bought, p.base),
            }) else null,
        });
    }

    fn kitRow(p: *P, h: *H, title: tree.Text, list: []const Kit, first: u16) ?N {
        if (list.len == 0) return null;
        var l = h.list();
        for (list, 0..) |k, i| {
            const at: u16 = first + @as(u16, @intCast(i));
            // One of the list to read, as Select's menu: names, not action labels
            l.add(h.button(.{
                .key = i,
                .class = "c-chip",
                .type = "button",
                .role = "option",
                .aria_selected = p.kit == at,
                .on_click = h.on(p, .{ .kit = at }),
            }, .{
                art.view(h, .{ .name = k.change.name, .src = k.icon }, .{ .px = .@"20", .named = false }),
                k.change.name,
                toneMark(h, k.change),
            }));
        }
        return h.div(.{ .class = "kr" }, .{
            card.label(h, title),
            h.div(.{ .class = "chips", .role = "listbox", .aria_label = title }, .{l.done()}),
        });
    }
};

/// A kit chip's ▲▼ (new and removed as their badge); nothing for a mixed change
fn toneMark(h: *H, c: Change) ?N {
    if (c.status != .changed) return riotBadge(h, c);
    return switch (c.tone) {
        .buff => h.span(.{ .class = "tn", .data_dir = "buff", .aria_label = W.buffed }, .{"▲"}),
        .nerf => h.span(.{ .class = "tn", .data_dir = "nerf", .aria_label = W.nerfed }, .{"▼"}),
        .adjusted => null,
    };
}

fn users(h: *H, d: *const Data, list: []const User, used: tree.Text, base: []const u8) ?N {
    if (list.len == 0) return null;
    var l = h.list();
    for (list, 0..) |u, i| {
        const row = if (u.row) |x| &d.rows[x] else null;
        const href = champHref(h.mem, d, base, u.champ, u.role) catch blk: {
            h.oom = true;
            break :blk "";
        };
        l.add(h.li(.{ .key = i }, .{
            h.a(.{ .class = "who", .href = href }, .{
                icon(h, d, u.champ),
                h.span(.{ .class = "nm" }, .{d.champs[u.champ].name}),
                role.view(h, u.role.ui(), .{}),
            }),
            h.span(.{ .class = "r" }, .{phrase.num(h, .rate, 100 * u.share)}),
            if (row) |x| moveText(h, moveOf(x.prev, x.cur), x.clear) else null,
        }));
    }
    return h.div(.{ .class = "blk" }, .{
        card.label(h, used),
        h.ul(.{ .class = "us" }, .{l.done()}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-patch { display: grid; gap: var(--sp-4); min-width: 0; }
    \\  .c-patch .c-toolbar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: var(--sp-2) var(--sp-4); }
    \\  .c-patch .chips { display: flex; flex-wrap: wrap; gap: var(--sp-1); }
    \\  .c-patch .c-toolbar .n { margin-left: 2px; color: var(--muted); font-variant-numeric: tabular-nums; }
    \\  .c-patch .c-toolbar .n[data-d="up"] { color: var(--hi2); }
    \\  .c-patch .c-toolbar .n[data-d="down"] { color: var(--lo2); }
    \\  .c-patch .c-table-wrap { overflow-x: clip; }
    \\  .c-patch .c-table thead th { top: var(--header); }
    \\  .c-patch .who { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; color: inherit; text-decoration: none; }
    \\  .c-patch .nm { font-weight: var(--w-b); min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-patch .who .c-role { margin-left: auto; color: var(--muted); }
    \\  .c-patch .mus { display: flex; align-items: center; gap: var(--sp-3); white-space: nowrap; }
    \\  .c-patch .mus > .k { min-width: 1.2em; color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-patch .mo { display: inline-flex; align-items: center; gap: var(--sp-1); }
    \\  .c-patch .mo.more { color: var(--muted); font-size: var(--fs-s); }
    \\  .c-patch .kits { display: grid; gap: var(--sp-2); }
    \\  .c-patch .kr { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-1) var(--sp-2); }
    \\  .c-patch .kr > .lab { min-width: 4em; }
    \\  .c-patch .kr .c-chip { gap: 6px; }
    \\  .c-patch .tn { font-size: var(--fs-xs); }
    \\  .c-patch .tn[data-dir="buff"] { color: var(--good); }
    \\  .c-patch .tn[data-dir="nerf"] { color: var(--bad); }
    \\  .c-patch .kd { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, max-content)); gap: var(--sp-3) var(--sp-6); padding: var(--sp-3); border-radius: var(--r-m); background: var(--panel); border: 1px solid var(--line); }
    \\  .c-patch .r { color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-patch td.cu .r { color: var(--text); }
    \\  .c-patch .mv { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-patch .mv .c-dbar { flex: 1; min-width: 60px; }
    \\  .c-patch .mv .c-delta { min-width: 40px; text-align: right; }
    \\  .c-patch .mv:not([data-clear]) .c-dbar > i, .c-patch .mv:not([data-clear]) .c-dbar > s { background: var(--faint); }
    \\  .c-patch .gm { color: var(--muted); }
    \\  .c-patch .gd { font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-patch .gd small { color: var(--faint); }
    \\  .c-patch .dl { width: 280px; }
    \\  .c-patch .ln { width: 180px; }
    \\  .c-patch .rd { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: var(--sp-3) var(--sp-5); padding: var(--sp-2) var(--sp-2) var(--sp-3); }
    \\  .c-patch .blk { display: grid; gap: var(--sp-1); align-content: start; min-width: 0; }
    \\  .c-patch .blk p { margin: 0; font-size: var(--fs-s); }
    \\  .c-patch .blk > a { font-size: var(--fs-s); }
    \\  .c-patch .x, .c-patch .empty { color: var(--faint); }
    \\  .c-patch .empty { margin: 0; padding: var(--sp-4); }
    \\  .c-patch .mvs { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--sp-1); }
    \\  .c-patch .mvs li { display: grid; grid-template-columns: auto minmax(0, 8em) minmax(0, 1fr) auto; align-items: center; gap: var(--sp-2); font-size: var(--fs-s); }
    \\  .c-patch .us { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--sp-1); }
    \\  .c-patch .us li { display: grid; grid-template-columns: minmax(0, 1fr) auto 3.5em; align-items: center; gap: var(--sp-2); font-size: var(--fs-s); }
    \\  .c-patch .us .c-delta { text-align: right; }
    \\  .c-patch:not([data-riot]) .ri { display: none; }
    \\  @container (max-width: 620px) {
    \\    .c-patch .dl { width: 150px; }
    \\    .c-patch .ln { width: 120px; }
    \\    .c-patch .mus > .mo { display: none; }
    \\    .c-patch .mvs li { grid-template-columns: auto minmax(0, 1fr) minmax(0, 1fr); }
    \\    .c-patch .mvs .gd { grid-column: 2 / -1; }
    \\  }
    \\  @container (max-width: 300px) {
    \\    .c-patch .dl { width: 96px; }
    \\    .c-patch .mv .c-dbar { min-width: 40px; }
    \\    .c-patch td.ch .who { max-width: 92px; }
    \\    .c-patch td.ch .who .c-role { display: none; }
    \\  }
    \\}
    \\
;

fn demoChamp(comptime n: []const u8, comptime key: []const u8, comptime slug: []const u8) Champ {
    return .{ .name = n, .key = key, .slug = slug };
}

pub const demo: Data = .{
    .cur_patch = "16.21",
    .prev_patch = "16.20",
    .games = 79_549,
    .min_games = 300,
    .lane_minute = 14,
    .ddragon = "16.21.1",
    .patch_query = "?period=patch",
    .notes = "https://www.leagueoflegends.com/en-gb/news/game-updates/league-of-legends-patch-26-21-notes/",
    .riot = true,
    .champs = &.{
        demoChamp("Darius", "Darius", "darius"),
        demoChamp("Miss Fortune", "MissFortune", "missfortune"),
        demoChamp("Viktor", "Viktor", "viktor"),
        demoChamp("Jinx", "Jinx", "jinx"),
        demoChamp("Tristana", "Tristana", "tristana"),
        demoChamp("Orianna", "Orianna", "orianna"),
    },
    .changes = &.{
        .{ .id = 0, .name = "Darius", .tone = .buff, .slots = "Q", .lines = &.{
            .{ .key = "Q", .label = "Decimate cooldown", .old = "9/8/7/6/5", .new = "9/7.75/6.5/5.25/4", .dir = .buff },
        } },
        .{ .id = 2, .name = "Viktor", .tone = .nerf, .slots = "stats", .lines = &.{
            .{ .label = "Move speed", .old = "335", .new = "330", .dir = .nerf },
        } },
        .{ .id = 3, .name = "Jinx", .tone = .nerf, .slots = "stats", .lines = &.{
            .{ .label = "Health", .old = "630", .new = "610", .dir = .nerf },
        } },
        .{ .id = 5, .name = "Orianna", .tone = .adjusted, .slots = "Q", .lines = &.{
            .{ .key = "Q", .label = "Command: Attack", .dir = .blanked },
        } },
    },
    .rows = &.{
        .{ .champ = 0, .role = .top, .prev = .{ 23_166, 11_282 }, .cur = .{ 6_678, 3_426 }, .clear = true, .lane = .{ .prev = .{ 20_000, 10_920 }, .cur = .{ 6_000, 3_396 }, .clear = true }, .change = 0, .moves = &.{
            .{ .them = 2, .prev = .{ 900, 430 }, .cur = .{ 450, 250 }, .clear = false },
        } },
        .{ .champ = 1, .role = .bottom, .prev = .{ 30_000, 14_790 }, .cur = .{ 10_280, 5_284 }, .clear = true, .lane = null, .change = null, .moves = &.{
            .{ .them = 4, .prev = .{ 800, 386 }, .cur = .{ 520, 286 }, .clear = true, .gold = .{ .minute = 11, .prev = 40, .cur = 209, .games = 510 }, .path = "/matchups/bot/missfortune-vs-tristana" },
            .{ .them = 3, .prev = .{ 900, 465 }, .cur = .{ 864, 427 }, .clear = false, .path = "/matchups/bot/missfortune-vs-jinx" },
        } },
        .{ .champ = 5, .role = .middle, .prev = .{ 9_000, 4_122 }, .cur = .{ 3_029, 1_417 }, .clear = false, .lane = null, .change = 3, .moves = &.{} },
        .{ .champ = 3, .role = .bottom, .prev = .{ 40_000, 20_680 }, .cur = .{ 11_328, 5_800 }, .clear = false, .lane = .{ .prev = .{ 38_000, 19_000 }, .cur = .{ 11_000, 5_346 }, .clear = true }, .change = 2, .moves = &.{} },
        .{ .champ = 2, .role = .middle, .prev = .{ 15_000, 7_575 }, .cur = .{ 5_094, 2_407 }, .clear = true, .lane = null, .change = 1, .moves = &.{} },
        .{ .champ = 4, .role = .bottom, .prev = .{ 20_000, 10_280 }, .cur = .{ 7_484, 3_660 }, .clear = true, .lane = null, .change = null, .moves = &.{
            .{ .them = 1, .prev = .{ 800, 414 }, .cur = .{ 520, 234 }, .clear = true, .gold = .{ .minute = 11, .prev = -40, .cur = -209, .games = 510 }, .path = "/matchups/bot/tristana-vs-missfortune" },
            .{ .them = 2, .prev = .{ 700, 371 }, .cur = .{ 480, 216 }, .clear = true, .path = "/matchups/bot/tristana-vs-viktor" },
            .{ .them = 5, .prev = .{ 600, 288 }, .cur = .{ 420, 248 }, .clear = true, .path = "/matchups/bot/tristana-vs-orianna" },
        } },
    },
    .items = &.{
        .{ .change = .{ .id = 2520, .name = "Bastionbreaker", .tone = .nerf, .slots = "", .lines = &.{
            .{ .before = "", .old = "22", .new = "18", .after = "Lethality", .dir = .nerf },
        } }, .icon = "/dd/16.21.1/img/item/2520.jpg", .users = &.{
            .{ .champ = 1, .role = .bottom, .share = 0.62, .row = 1 },
            .{ .champ = 4, .role = .bottom, .share = 0.31, .row = 5 },
            .{ .champ = 0, .role = .top, .share = 0.08, .row = null },
        } },
        .{ .change = .{ .id = 9999, .name = "New Thing", .status = .new, .tone = .adjusted, .slots = "", .lines = &.{} }, .icon = "", .users = &.{} },
    },
    .runes = &.{
        .{ .change = .{ .id = 8005, .name = "Press the Attack", .tone = .adjusted, .slots = "", .lines = &.{
            .{ .before = "Deals", .old = "40", .new = "45", .after = "damage", .dir = .adjusted },
        } }, .icon = "/dd/img/perk-images/Styles/Precision/PressTheAttack/PressTheAttack.png", .users = &.{
            .{ .champ = 3, .role = .bottom, .share = 0.41, .row = 3 },
        } },
    },
};

/// The page on `d`, its first row open when `open`
pub fn shown(a: std.mem.Allocator, d: *const Data, open: bool) ?*Page {
    const p = a.create(Page) catch return null;
    p.* = .init(d, prepare(a, d, "") catch return null);
    if (open and p.table.rows.len > 0) p.table.open = 0;
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    if (shown(h.mem, &demo, true)) |p| g.addFill("moved clearly and changed by Riot, Darius open", p.view(h));
    if (shown(h.mem, &demo, false)) |p| {
        p.kit = 0;
        p.refilter();
        p.table.open = 1;
        g.addFill("Bastionbreaker open over the table, Miss Fortune open", p.view(h));
    }
    if (shown(h.mem, &demo, false)) |p| {
        p.role = .bot;
        p.moved = false;
        p.refilter();
        p.table.open = 0;
        g.addFill("bot, Riot changed only, Jinx open: no matchup moved", p.view(h));
    }
    var no_riot = demo;
    no_riot.riot = false;
    no_riot.items = &.{};
    no_riot.runes = &.{};
    const d = h.mem.create(Data) catch return;
    d.* = no_riot;
    if (shown(h.mem, d, false)) |p| {
        p.role = .support;
        p.refilter();
        g.addFill("without Riot's data; support: nothing listed", p.view(h));
    }
}
