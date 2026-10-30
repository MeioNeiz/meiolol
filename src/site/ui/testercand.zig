//! The Draft tester's candidate panel (docs/plan/ui/draft-tester.md "First screen"):
//! every champion the shown seat could take under the page's model, as a RankStrip and a
//! CandidateList in points mode, sorted by Win (the low end of its 95% range) or Fit (the
//! change less the champion's own strength). A row's chips and, opened, its
//! ReasonBreakdown are draftscore's Scorer.why parts; Pick fills the seat. The search
//! keeps the rows whose name holds it, Enter picks the first. Its own island and wasm
//! (ui-testercand.wasm, which ui-tester.wasm loads) with no model of its own, so it fits
//! its budget: the two share the board through the URL fragment (testerpage.Page.Url),
//! and ui-tester.wasm, which holds the model, hands it the seat's options (Feed)
const std = @import("std");
const tree = @import("tree.zig");
const ds = @import("core").draftscore;
const tp = @import("testerpage.zig");
const champ = @import("champ.zig");
const candlist = @import("candlist.zig");
const reasons = @import("reasons.zig");
const rankstrip = @import("rankstrip.zig");
const role = @import("role.zig");
const segmented = @import("segmented.zig");
const url = @import("url.zig");
const tl = @import("testerlane.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "TesterCand";
pub const scope = .{".c-tcand"};
pub const sel = "[data-island=testercand]";

const n_role = ds.n_role;
/// Rows shown before a search, the seat's own champion added below them
const max_rows = 30;
/// Chips: a part under this many points says nothing a row's number doesn't
const min_chip_pp = 0.1;
/// Lane gold at 14 over many games: the old page's ±50 for a colour, up from there
const gold_cuts: [4]f32 = .{ 50, 150, 300, 500 };

const W = struct {
    pub const seat = Phrase("{side:text} {r:text}");
    pub const picks = Phrase("{n:int} picks");
    pub const search = plain("Search");
    pub const sort = plain("Sort");
    pub const win = plain("Win");
    pub const fit = plain("Fit");
    pub const chance = Phrase("{side:text}'s win chance");
    pub const with_ = plain("with");
    pub const vs_avg = plain("vs average");
    pub const fit_h = plain("fit");
    pub const average = Phrase("Average {r:text}");
    pub const strength = Phrase("{r:text} strength");
    pub const into_l = Phrase("into {n:text}");
    pub const with_l = Phrase("with {n:text}");
    pub const into = Phrase("Into {n:text}");
    pub const with = Phrase("With {n:text}");
    pub const side_with = Phrase("{side:text} with {n:text}");
    pub const why = Phrase("Why {n:text}");
    pub const pick = Phrase("Pick {n:text}");
    pub const gold = plain("Gold");
    pub const gold_h = plain("gold 14");
    pub const lane_into = Phrase("Lane into {n:text}: {g:signed} gold at 14 ({lo:signed} to {hi:signed}), {cs:int} CS at 10, {d:dec} deaths before 15; {m:count} games of the matchup");
    pub const lane_new = Phrase("Lane into {n:text}: {g:signed} gold at 14 ({lo:signed} to {hi:signed}), {cs:int} CS at 10, {d:dec} deaths before 15; no games of the matchup yet, champion averages only");
    pub const lane_blind = Phrase("Blind lane: {g:signed} gold at 14 over likely opponents ({lo:signed} to {hi:signed}); hardest common one {n:text}, {hg:signed}");
    pub const in_seat = plain("in seat");
    pub const every = Phrase("Every pick for {side:text} {r:text}");
    pub const full = plain("Every seat is filled: choose one to change it");
    pub const none = plain("No pick matches");
    pub const loading = plain("Loading the model…");
    pub const failed = plain("Could not load the model file");
    pub const bad = plain("The model file is damaged");
    pub const blue = plain("Blue");
    pub const red = plain("Red");
};

/// Gold: the lane model's gold at 14, low end first; without it, as Win
pub const Sort = enum(u8) { win, fit, gold };

/// The shown seat's options under the shown model for one board: what ui-tester.wasm
/// hands the panel (ui.data). Unsorted; the panel sorts
pub const Feed = struct {
    which: tp.Which,
    teams: [2][n_role]u32,
    bans: [tp.n_ban]u32 = @splat(0),
    seat: u8,
    load: Status = .loading,
    /// The seat's side's chance with the role's average pick, %
    empty: f32 = 50,
    opts: []const Opt = &.{},
    /// The options have lane gold (addLane): into `opp`, or blind when it is 0
    lane: bool = false,
    opp: u32 = 0,

    /// For this board, bans, model and seat
    pub fn of(f: *const Feed, which: tp.Which, teams: [2][n_role]u32, bans: [tp.n_ban]u32, seat: u8) bool {
        return f.which == which and f.seat == seat and std.meta.eql(f.teams, teams) and std.meta.eql(f.bans, bans);
    }
};

pub const Status = enum(u8) { loading, failed, bad, ready };

/// One champion the seat could take, and why (Scorer.why)
pub const Opt = struct {
    id: u32,
    /// The seat's side's chance with it and its 95% range, %
    p: f32,
    lo: f32,
    hi: f32,
    parts: []const Part,
    rest: f32,
    gold: ?tl.Gold = null,

    /// Points over the role's average pick
    fn total(o: *const Opt, f: *const Feed) f32 {
        return o.p - f.empty;
    }

    /// What the draft adds: the total less the champion's own strength
    fn fit(o: *const Opt, f: *const Feed) f32 {
        var x = o.total(f);
        for (o.parts) |q| if (q.kind == .base) {
            x -= q.pp;
        };
        return x;
    }
};

pub const Part = struct {
    kind: ds.Kind,
    other: u32,
    pp: f32,
    games: u32,
};

/// The feed for a board: the seat's options are champions with min_games or more in its
/// role, in the head, not on another seat, not banned
pub fn feed(a: std.mem.Allocator, head: *const tp.Head, load: tp.Load, which: tp.Which, teams: [2][n_role]u32, bans: [tp.n_ban]u32, seat: u8) !Feed {
    var f: Feed = .{ .which = which, .teams = teams, .bans = bans, .seat = seat };
    const l = switch (load) {
        .ready => |x| x,
        .failed => return .{ .which = which, .teams = teams, .bans = bans, .seat = seat, .load = .failed },
        .bad => return .{ .which = which, .teams = teams, .bans = bans, .seat = seat, .load = .bad },
        .none, .loading => return f,
    };
    f.load = .ready;
    if (seat >= 2 * n_role) return f;
    const side: u1 = @intCast(seat / n_role);
    const r = seat % n_role;
    f.empty = @floatCast(100 * l.sc.why(teams, side, r, 0).empty.p);
    var out: std.ArrayList(Opt) = .empty;
    for (l.m.cells) |cell| {
        if (cell.role != r or cell.games < l.m.min_games) continue;
        const c = tp.champOf(head, cell.champion) orelse continue;
        if (elsewhere(teams, seat, c.id) or std.mem.findScalar(u32, &bans, c.id) != null) continue;
        const w = l.sc.why(teams, side, r, c.id);
        const parts = try a.alloc(Part, w.n);
        for (parts, w.parts()) |*o, x| o.* = .{ .kind = x.kind, .other = x.other, .pp = @floatCast(x.pp), .games = x.games };
        try out.append(a, .{
            .id = c.id,
            .p = @floatCast(100 * w.with.p),
            .lo = @floatCast(100 * w.with.lo),
            .hi = @floatCast(100 * w.with.hi),
            .parts = parts,
            .rest = @floatCast(w.rest),
        });
    }
    f.opts = out.items;
    return f;
}

/// The lane model's gold for each option where the seat's role has a lane line (top,
/// mid, bot): into the seat's lane opponent, else blind over the role's likely picks
pub fn addLane(a: std.mem.Allocator, f: *Feed, load: tp.Load, sc: *const tl.Scorer) !void {
    const l = switch (load) {
        .ready => |x| x,
        else => return,
    };
    if (f.load != .ready or f.seat >= 2 * n_role) return;
    const side = f.seat / n_role;
    const r: u8 = f.seat % n_role;
    if (!tl.shown(r)) return;
    const opp = f.teams[1 - side][r];
    var field: std.ArrayList(tl.Opp) = .empty;
    if (opp == 0) for (l.m.cells) |cell| {
        if (cell.role != r or !(cell.patch_share > 0)) continue;
        if (elsewhere(f.teams, f.seat, cell.champion) or std.mem.findScalar(u32, &f.bans, cell.champion) != null) continue;
        try field.append(a, .{ .id = cell.champion, .w = @floatCast(cell.patch_share) });
    };
    const opts = try a.dupe(Opt, f.opts);
    for (opts) |*o| o.gold = tl.gold(sc, r, o.id, opp, field.items);
    f.opts = opts;
    f.lane = true;
    f.opp = opp;
}

fn elsewhere(teams: [2][n_role]u32, seat: u8, id: u32) bool {
    for (0..2 * n_role) |i| if (i != seat and teams[i / n_role][i % n_role] == id) return true;
    return false;
}

/// Win: the low end of the range first (a sure small gain over an unsure bigger one);
/// Fit: the change less the champion's strength; ties by champion id
fn before(f: *const Feed, sort: Sort, x: *const Opt, y: *const Opt) bool {
    const kx = key(f, sort, x);
    const ky = key(f, sort, y);
    if (kx != ky) return kx > ky;
    return x.id < y.id;
}

fn key(f: *const Feed, sort: Sort, x: *const Opt) f32 {
    return switch (sort) {
        .win => x.lo,
        .fit => x.fit(f),
        .gold => if (x.gold) |g| g.lo else x.lo,
    };
}

/// The feed's options best first. Insertion: a role's ~150 options, and std's sort costs
/// a wasm a few KB
pub fn sorted(a: std.mem.Allocator, f: *const Feed, sort: Sort) ![]*const Opt {
    const xs = try a.alloc(*const Opt, f.opts.len);
    for (xs, f.opts) |*x, *o| x.* = o;
    for (1..@max(xs.len, 1)) |i| {
        const x = xs[i];
        var j = i;
        while (j > 0 and before(f, sort, x, xs[j - 1])) : (j -= 1) xs[j] = xs[j - 1];
        xs[j] = x;
    }
    return xs;
}

/// `champion` holds `q`, case and punctuation ignored ("ksa" finds K'Sante). Not
/// ChampSearch's index: its aliases and typos would put the panel's wasm over budget
pub fn matches(champion: []const u8, q: []const u8) bool {
    var nb: [32]u8 = undefined;
    var qb: [32]u8 = undefined;
    return std.mem.find(u8, fold(&nb, champion), fold(&qb, q)) != null;
}

fn fold(buf: []u8, s: []const u8) []const u8 {
    var n: usize = 0;
    for (s) |c| {
        if (n == buf.len) break;
        if (c < 0x80 and !std.ascii.isAlphanumeric(c)) continue;
        buf[n] = std.ascii.toLower(c);
        n += 1;
    }
    return buf[0..n];
}

pub const Panel = struct {
    head: *const tp.Head,
    which: tp.Which = .live,
    teams: [2][n_role]u32 = @splat(@splat(0)),
    seat: ?u8 = null,
    tab: tp.Tab = .board,
    bans: [tp.n_ban]u32 = @splat(0),
    sort: Sort = .win,
    /// The champion whose breakdown is open; 0 for none
    open: u32 = 0,
    q: url.Str(24) = .{},
    /// ui-tester.wasm's latest; stale while a new board is on its way
    feed: ?*const Feed = null,
    /// ui-testercand.js and .wasm, for ui-tester.wasm to load (dom.lazyLoad)
    js: []const u8 = "",
    wasm: []const u8 = "",

    /// testerpage.Page.Url's fields, which the tester island writes too, and the sort
    pub const Url = struct {
        m: tp.Which = .live,
        b: [n_role]u32 = @splat(0),
        r: [n_role]u32 = @splat(0),
        s: ?u8 = null,
        t: tp.Tab = .board,
        n: [tp.n_ban]u32 = @splat(0),
        o: Sort = .win,
    };

    comptime {
        for (std.meta.fieldNames(tp.Page.Url)) |f| std.debug.assert(@FieldType(Url, f) == @FieldType(tp.Page.Url, f));
    }

    pub const Msg = union(enum) { sort: Sort, open: u32, pick: u32, input, key };

    pub fn init(head: *const tp.Head) Panel {
        return .{ .head = head };
    }

    pub fn toUrl(p: *const Panel) Url {
        return .{ .m = p.which, .b = p.teams[0], .r = p.teams[1], .s = p.seat, .t = p.tab, .n = p.bans, .o = p.sort };
    }

    pub fn fromUrl(p: *Panel, u: Url) void {
        const teams = tp.clean(p.head, .{ u.b, u.r });
        const bans = tp.cleanBans(p.head, u.n, teams);
        const seat: ?u8 = if (u.s) |i| (if (i < 2 * n_role) i else null) else null;
        if (!std.meta.eql(teams, p.teams) or !std.meta.eql(bans, p.bans) or seat != p.seat) p.open = 0;
        p.which = u.m;
        p.teams = teams;
        p.bans = bans;
        p.seat = seat;
        p.tab = u.t;
        p.sort = u.o;
    }

    pub fn update(p: *Panel, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .sort => |s| {
                p.sort = s;
                ev.push = true;
            },
            .open => |id| p.open = if (p.open == id) 0 else id,
            .pick => |id| p.place(id),
            .input => {
                p.q.set(ev.text);
                p.open = 0;
            },
            .key => {
                if (std.mem.eql(u8, ev.text, "Escape") and p.q.len > 0) {
                    p.q.set("");
                    ev.handled = true;
                } else if (std.mem.eql(u8, ev.text, "Enter")) {
                    ev.handled = true;
                    if (p.first()) |o| p.place(o.id);
                }
            },
        }
    }

    /// Only an option of the current feed: a pick from a stale list would land in the
    /// wrong seat
    fn place(p: *Panel, id: u32) void {
        const f = p.current() orelse return;
        for (f.opts) |o| if (o.id == id) {
            tp.place(&p.teams, f.seat, id);
            p.seat = null;
            p.open = 0;
            p.q.set("");
            return;
        };
    }

    /// The first row the search keeps
    fn first(p: *const Panel) ?*const Opt {
        const f = p.current() orelse return null;
        var best: ?*const Opt = null;
        for (f.opts) |*o| {
            if (!matches(p.nameOf(o.id), p.q.slice())) continue;
            if (best) |b| if (!before(f, p.sort, o, b)) continue;
            best = o;
        }
        return best;
    }

    /// The feed for the shown board, once it is in
    pub fn current(p: *const Panel) ?*const Feed {
        const f = p.feed orelse return null;
        const seat = tp.shownSeat(p.teams, p.seat) orelse return null;
        return if (f.of(p.which, p.teams, p.bans, seat)) f else null;
    }

    /// The last feed under the shown model, while ui-tester computes the shown board's
    pub fn stale(p: *const Panel) ?*const Feed {
        const f = p.feed orelse return null;
        return if (f.which == p.which and f.load == .ready) f else null;
    }

    pub fn view(p: *Panel, h: *H) N {
        const shown = tp.shownSeat(p.teams, p.seat);
        const cur = p.current();
        const attrs = .{
            .class = "c-tcand",
            .data_island = "testercand",
            .data_js = if (p.js.len > 0) p.js else null,
            .data_wasm = if (p.wasm.len > 0) p.wasm else null,
            .hidden = p.tab != .board,
            .aria_busy = shown != null and cur == null,
        };
        const seat = shown orelse return h.div(attrs, .{h.p(.{ .class = "wait" }, .{W.full})});
        const side = if (seat < n_role) W.blue else W.red;
        const r = role.Role.all[seat % n_role];
        // Between a board change and the next feed the last list stays, without Pick, so
        // the panel doesn't collapse and refill on every pick
        const f = cur orelse p.stale() orelse return p.waiting(h, attrs, side, r, .loading);
        if (f.load != .ready) return p.waiting(h, attrs, side, r, f.load);
        const all = sorted(h.mem, f, p.sort) catch {
            h.oom = true;
            return h.div(attrs, .{});
        };
        const in_seat = f.teams[f.seat / n_role][f.seat % n_role];
        const rows = p.rowsOf(h, f, all, in_seat, cur != null);
        return h.div(attrs, .{
            p.top(h, side, r, all.len, f.lane),
            p.strip(h, all, side, r, in_seat),
            if (rows.len > 0) candlist.withPick(h, .{
                .rows = rows,
                .head = .{ W.chance.with(h, .{ .side = side.s }), W.with_, if (p.sort == .fit) W.fit_h else W.vs_avg },
                .ref_label = W.in_seat,
                .base = if (p.q.len == 0) .{ .label = W.average.with(h, .{ .r = roleName(r) }), .win = f.empty } else null,
                .extra = if (f.lane) .{ .head = W.gold_h, .cuts = gold_cuts } else null,
            }) else h.p(.{ .class = "wait" }, .{W.none}),
        });
    }

    fn waiting(p: *Panel, h: *H, attrs: anytype, side: tree.Text, r: role.Role, s: Status) N {
        return h.div(attrs, .{
            p.top(h, side, r, null, false),
            h.p(.{ .class = "wait" }, .{switch (s) {
                .failed => W.failed,
                .bad => W.bad,
                else => W.loading,
            }}),
        });
    }

    /// Gold only where the seat has a lane line; a Gold sort without one sorts as Win
    fn top(p: *Panel, h: *H, side: tree.Text, r: role.Role, n: ?usize, lane: bool) N {
        const sorts = [_]segmented.Item{
            .{ .label = W.win, .selected = p.sort == .win or (p.sort == .gold and !lane), .on = h.on(p, .{ .sort = .win }) },
            .{ .label = W.fit, .selected = p.sort == .fit, .on = h.on(p, .{ .sort = .fit }) },
            .{ .label = W.gold, .selected = p.sort == .gold, .on = h.on(p, .{ .sort = .gold }) },
        };
        return h.div(.{ .class = "hd" }, .{
            role.view(h, r, .{ .s = .s }),
            h.b(.{}, .{W.seat.with(h, .{ .side = side.s, .r = r.label().s })}),
            if (n) |x| h.span(.{ .class = "n" }, .{W.picks.with(h, .{ .n = x })}) else null,
            h.input(.{
                .type = "search",
                .placeholder = W.search,
                .aria_label = W.search,
                .autocomplete = "off",
                .spellcheck = "false",
                .value = p.q.slice(),
                .data_ref = "input",
                .on_input = h.on(p, .input),
                .on_keydown = h.on(p, .key),
            }),
            segmented.view(h, .{ .s = .s, .label = W.sort }, sorts[0..if (lane) 3 else 2]),
        });
    }

    fn strip(p: *Panel, h: *H, all: []const *const Opt, side: tree.Text, r: role.Role, in_seat: u32) N {
        const dots = h.mem.alloc(rankstrip.Dot, all.len) catch {
            h.oom = true;
            return .none;
        };
        for (dots, all, 0..) |*d, o, i| d.* = .{
            .champ = p.icon(h, o.id),
            .win = o.p,
            .star = i == 0,
            .ref = o.id == in_seat,
            .chosen = o.id == p.open,
            .on = h.on(p, .{ .open = o.id }),
        };
        return rankstrip.view(h, .{ .dots = dots, .label = W.every.with(h, .{ .side = side.s, .r = r.label().s }) });
    }

    /// The first max_rows and the seat's own champion below them, or every row the search
    /// keeps
    fn rowsOf(p: *Panel, h: *H, f: *const Feed, all: []const *const Opt, in_seat: u32, live: bool) []const candlist.Row {
        var rows: std.ArrayList(candlist.Row) = .empty;
        const searching = p.q.len > 0;
        var last: usize = 0;
        for (all, 0..) |o, i| {
            const keep = if (searching) matches(p.nameOf(o.id), p.q.slice()) else i < max_rows or o.id == in_seat;
            if (!keep) continue;
            rows.append(h.mem, p.row(h, f, o, i, in_seat, !searching and i > last + 1, live)) catch {
                h.oom = true;
                return &.{};
            };
            last = i;
        }
        return rows.items;
    }

    fn row(p: *Panel, h: *H, f: *const Feed, o: *const Opt, i: usize, in_seat: u32, gap: bool, live: bool) candlist.Row {
        const open = p.open == o.id;
        const nm = p.nameOf(o.id);
        return .{
            .champ = p.icon(h, o.id),
            .rank = @intCast(i + 1),
            .star = i == 0,
            .ref = o.id == in_seat,
            .win = o.p,
            .vs = if (p.sort == .fit) o.fit(f) else o.total(f),
            .reasons = p.chips(h, o, f.seat),
            .gap = gap,
            .open = open,
            .x = if (o.gold) |g| g.v else null,
            .detail = if (open) p.breakdown(h, f, o) else null,
            .note = if (open) p.laneLine(h, f, o) else null,
            .label = W.why.with(h, .{ .n = nm }),
            .id = h.fmt("tc-{d}", .{o.id}),
            .on = h.on(p, .{ .open = o.id }),
            .pick = if (live and o.id != in_seat) h.on(p, .{ .pick = o.id }) else null,
            .pick_label = W.pick.with(h, .{ .n = nm }),
        };
    }

    fn laneLine(p: *const Panel, h: *H, f: *const Feed, o: *const Opt) ?tree.Text {
        const g = o.gold orelse return null;
        if (f.opp == 0) return W.lane_blind.with(h, .{ .g = whole(g.v), .lo = whole(g.lo), .hi = whole(g.hi), .n = p.nameOf(g.hardest), .hg = whole(g.hardest_gold) });
        if (g.pair_games == 0) return W.lane_new.with(h, .{ .n = p.nameOf(f.opp), .g = whole(g.v), .lo = whole(g.lo), .hi = whole(g.hi), .cs = whole(g.cs10), .d = g.deaths15 });
        return W.lane_into.with(h, .{ .n = p.nameOf(f.opp), .g = whole(g.v), .lo = whole(g.lo), .hi = whole(g.hi), .cs = whole(g.cs10), .d = g.deaths15, .m = g.pair_games });
    }

    fn nameOf(p: *const Panel, id: u32) []const u8 {
        return if (tp.champOf(p.head, id)) |c| c.name else "?";
    }

    fn icon(p: *const Panel, h: *H, id: u32) champ.Champ {
        const c = tp.champOf(p.head, id) orelse return .{ .name = "?", .src = "" };
        return .{ .name = c.name, .src = h.fmt(champ.icon_fmt, .{ p.head.ddragon, c.key }) };
    }

    /// Up to three of the largest named parts
    fn chips(p: *const Panel, h: *H, o: *const Opt, seat: u8) []const candlist.Reason {
        var idx: [3]usize = undefined;
        var n: usize = 0;
        for (o.parts, 0..) |x, i| {
            if (!(@abs(x.pp) >= min_chip_pp)) continue;
            var at = n;
            while (at > 0 and @abs(o.parts[idx[at - 1]].pp) < @abs(x.pp)) : (at -= 1) {
                if (at < 3) idx[at] = idx[at - 1];
            }
            if (at < 3) idx[at] = i;
            n = @min(n + 1, 3);
        }
        const out = h.mem.alloc(candlist.Reason, n) catch {
            h.oom = true;
            return &.{};
        };
        for (out, idx[0..n]) |*c, i| {
            const x = o.parts[i];
            c.* = .{ .pp = x.pp, .text = switch (x.kind) {
                .base => W.strength.with(h, .{ .r = role.Role.all[seat % n_role].label().s }),
                .enemy => W.into_l.with(h, .{ .n = p.nameOf(x.other) }),
                .ally => W.with_l.with(h, .{ .n = p.nameOf(x.other) }),
            } };
        }
        return out;
    }

    fn breakdown(p: *const Panel, h: *H, f: *const Feed, o: *const Opt) reasons.Breakdown {
        const r = role.Role.all[f.seat % n_role];
        const terms = h.mem.alloc(reasons.Term, o.parts.len) catch {
            h.oom = true;
            return .{ .base_label = W.average.with(h, .{ .r = roleName(r) }), .base = f.empty, .terms = &.{}, .total_label = W.with_ };
        };
        for (terms, o.parts) |*t, x| t.* = .{
            .label = switch (x.kind) {
                .base => W.strength.with(h, .{ .r = r.label().s }),
                .enemy => W.into.with(h, .{ .n = p.nameOf(x.other) }),
                .ally => W.with.with(h, .{ .n = p.nameOf(x.other) }),
            },
            .pp = x.pp,
            .games = x.games,
        };
        return .{
            .base_label = W.average.with(h, .{ .r = roleName(r) }),
            .base = f.empty,
            .terms = terms,
            // Without factor or comp terms the rest is rounding: no line for it
            .rest = if (@abs(o.rest) >= 0.05) o.rest else null,
            .total_label = W.side_with.with(h, .{ .side = (if (f.seat < n_role) W.blue else W.red).s, .n = p.nameOf(o.id) }),
            .low = o.lo,
            .high = o.hi,
            .tip_id = h.fmt("tr-{d}", .{o.id}),
        };
    }
};

fn whole(x: f32) i64 {
    return if (std.math.isFinite(x)) @intFromFloat(@round(x)) else 0;
}

fn roleName(r: role.Role) []const u8 {
    return @tagName(r);
}

pub const css =
    \\@layer components {
    \\  .c-tcand { display: grid; gap: var(--sp-2); container-type: inline-size; width: 100%; min-width: 0; }
    \\  .c-tcand[hidden] { display: none; }
    \\  .c-tcand .hd { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
    \\  .c-tcand .hd .n { color: var(--muted); font-size: var(--fs-s); }
    \\  .c-tcand .hd input { flex: 1 1 140px; min-width: 0; max-width: 240px; }
    \\  .c-tcand .wait { color: var(--muted); margin: 0; }
    \\  .c-tcand[aria-busy="true"] > :not(.hd) { opacity: 0.55; transition: opacity 0.2s; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const l = a.create(tp.Loaded) catch return;
    l.* = .{ .m = tp.Demo.model(), .sc = undefined, .check = .{ .drafts = 0, .worst = 0 } };
    l.sc = l.m.scorer(a) catch return;
    const states = [_][]const u8{ "loading", "red top, a row open", "searched, nothing" };
    for (states, 0..) |caption, i| {
        const p = a.create(Panel) catch return;
        p.* = .init(&tp.Demo.head);
        p.teams[1][0] = 122;
        p.seat = n_role;
        if (i > 0) {
            const f = a.create(Feed) catch return;
            f.* = feed(a, &tp.Demo.head, .{ .ready = l }, .live, p.teams, p.bans, n_role) catch return;
            p.feed = f;
        }
        if (i == 1) p.open = 122;
        if (i == 2) p.q.set("zz");
        g.addFill(caption, p.view(g.h));
    }
}
