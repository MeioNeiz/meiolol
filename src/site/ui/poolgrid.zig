//! PoolGrid: the pool page's sections, one per role in the pool (docs/plan/ui/pool.md
//! v2): the role's lane opponents against your champions there (HeatGrid), worst first
//! or most met, and what to add from the role's main file (CandidateList). Its own
//! island, ui-poolgrid.wasm: ui-pool.wasm tells it the pool and adds what it asks for.
//! Lanes files (data/pool/lanes/<slug>.bin) and mains' files (data/pool/<slug>.bin) are
//! fetched as the pool needs them
const std = @import("std");
const tree = @import("tree.zig");
const card = @import("card.zig");
const champ = @import("champ.zig");
const segmented = @import("segmented.zig");
const heatgrid = @import("heatgrid.zig");
const candlist = @import("candlist.zig");
const role = @import("role.zig");
const pd = @import("pooldata.zig");
const pp = @import("poolpage.zig");
const urls = @import("urls.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Role = role.Role;
const Why = pd.File.Why;

pub const name = "PoolGrid";
pub const scope = .{".c-poolgrid"};
pub const sel = "[data-island=poolgrid]";

/// Lanes shown before "All": the most met
const lanes_shown = 20;
/// What to add rows (product rule: 3-5 options)
const list_options = 5;
/// Files kept, more than a pool's: a champion taken out and put back isn't fetched again
const kept = 16;

const W = struct {
    pub const covered = Phrase("{a:int} of {b:int} lanes covered");
    pub const sort = plain("Sort");
    pub const worst = plain("Worst first");
    pub const met = plain("Most met");
    pub const vs = plain("vs");
    pub const all = Phrase("All {n:int}");
    pub const fewer = plain("Fewer");
    pub const press = plain("Points of win rate vs the two champions' usual. Press a cell for its games");
    pub const read = Phrase("{a:text} into {b:text}: {v:text} points vs usual · {g:text} games");
    pub const read_none = Phrase("{a:text} into {b:text}: no games");
    pub const gold = Phrase("{v:text} gold at 14");
    pub const matchup = plain("Matchup");
    pub const what = plain("What to add");
    pub const why_label = plain("Reason");
    pub const why_hard = plain("Weak lanes");
    pub const why_banned = plain("Banned");
    pub const why_also = plain("Also played");
    pub const champion = plain("Champion");
    pub const mains_play = plain("Mains");
    pub const blank = plain("");
    pub const loading = plain("Loading lanes…");
    pub const failed = plain("The lanes didn't load. Reload the page to try again.");
    pub const no_lanes = plain("No lanes for these champions in this role yet.");
    pub const no_main = Phrase("Add a champion whose main role is {r:text} for what covers its lanes.");
    pub const few = Phrase("Too few {c:text} mains yet for what to add.");
    pub const nothing = plain("Nothing to add for these lanes yet.");
    pub const harder = plain("harder to pick up");
    pub const easier = plain("easier to pick up");
    pub const add = Phrase("Add {c:text}");
    pub const weak = plain("Weak spots");
    pub const no_answer = plain("No answer to");
    pub const met_in = Phrase("met in {n:pct} of games");
    pub const thin_more = Phrase("{n:int} more with too few games to tell");
    pub const unclear = Phrase("No clear gap; {n:int} lanes with too few games to tell");
    pub const answered = plain("No lane your whole pool clearly loses");
    pub const alone = Phrase("{c:text} alone: one ban or counter-pick and you're off your pool");
    pub const covers = Phrase("covers {n:int}");
    pub const banned = Phrase("One of them banned in {n:pct} of games");
    pub const banned_one = Phrase("banned in {n:pct} of games");
    pub const all_early = plain("All lean early: ahead at 14, weaker than usual from an even game at 20");
    pub const all_late = plain("All lean late: behind at 14, stronger than usual from an even game at 20");
};

/// No lane icons past this in a weak spot line
const weak_shown = 5;
/// Games a ban takes one of the role's champions in, ‰, before it is a weak spot
const ban_clear = 50;

fn Got(comptime T: type) type {
    return struct { id: u16 = 0, f: ?*const T = null, failed: bool = false };
}

/// An opponent of the role, merged over the columns
pub const Lane = struct {
    id: u16,
    /// Summed over the columns
    games: u32,
    /// The pool's best points into it (tenths) among cells with enough games
    best: ?i16 = null,

    fn covered(l: Lane) bool {
        return if (l.best) |b| b >= pd.min_pp else false;
    }
};

pub const Page = struct {
    d: *const pp.Data,
    pool: [pp.max]pp.Pick = undefined,
    n: u8 = 0,
    lanes: [kept]Got(pd.Lanes) = @splat(.{}),
    mains: [kept]Got(pd.File) = @splat(.{}),
    sort: Sort = .worst,
    why: Why = .hard,
    /// Roles showing every lane, a bit each
    open: u8 = 0,
    cell: ?Sel = null,
    /// A champion to add, for the wasm to hand ui-pool.wasm
    adding: ?pp.Pick = null,

    const P = @This();

    pub const Sort = enum(u8) { worst, met };
    pub const Sel = struct { role: Role, row: u8, col: u8 };
    pub const Msg = union(enum) { sort: Sort, why: Why, all: Role, cell: Sel, add: pp.Pick };
    /// A file the page lacks: a champion's lanes, or a main's pool file
    pub const Need = struct { main: bool, id: u16 };

    pub fn picks(p: *const P) []const pp.Pick {
        return p.pool[0..p.n];
    }

    /// The pool as ui-pool.wasm hands it over ("86t-122j")
    pub fn setPool(p: *P, s: []const u8) void {
        p.n = pp.read(p.d, s, &p.pool);
        p.cell = null;
    }

    pub fn need(p: *const P) ?Need {
        for (p.picks()) |x| if (find(pd.Lanes, &p.lanes, x.id) == null) return .{ .main = false, .id = x.id };
        for (Role.all) |r| if (p.mainFor(r)) |id| if (find(pd.File, &p.mains, id) == null) return .{ .main = true, .id = id };
        return null;
    }

    /// A lanes fetch ended: the file, or null when it failed
    pub fn loadedLanes(p: *P, id: u16, f: ?*const pd.Lanes) void {
        const ok = if (f) |x| x.id == id else false;
        p.keep(pd.Lanes, &p.lanes, id, if (ok) f else null);
    }

    /// A main's fetch ended: its file, or null when it failed
    pub fn loadedMain(p: *P, id: u16, f: ?*const pd.File) void {
        const ok = if (f) |x| x.id == id and x.valid() else false;
        p.keep(pd.File, &p.mains, id, if (ok) f else null);
    }

    /// Into its slot, a free one, or one the pool no longer uses (its file stays in the
    /// wasm's memory: a few KB, rarely)
    fn keep(p: *const P, comptime T: type, list: *[kept]Got(T), id: u16, f: ?*const T) void {
        const i = for (list, 0..) |g, i| {
            if (g.id == id or g.id == 0) break i;
        } else for (list, 0..) |g, i| {
            if (!p.uses(g.id)) break i;
        } else return;
        list[i] = .{ .id = id, .f = f, .failed = f == null };
    }

    fn uses(p: *const P, id: u16) bool {
        for (p.picks()) |x| if (x.id == id) return true;
        return false;
    }

    /// The role's main: its first champion whose pool file is that role
    fn mainFor(p: *const P, r: Role) ?u16 {
        for (p.picks()) |x| {
            if (x.role != r) continue;
            const c = pp.indexOf(p.d, x.id) orelse continue;
            if (pp.mainOf(p.d, c)) |m| if (m.role == r) return x.id;
        }
        return null;
    }

    pub fn update(p: *P, m: Msg, _: *tree.Event) void {
        switch (m) {
            .sort => |s| p.sort = s,
            .why => |w| p.why = w,
            .all => |r| p.open ^= bit(@backingInt(r)),
            .cell => |c| p.cell = if (p.cell) |x| (if (std.meta.eql(x, c)) null else c) else c,
            .add => |x| p.adding = x,
        }
    }

    pub fn view(p: *P, h: *H) N {
        var ss = h.list();
        for (Role.all) |r| {
            for (p.picks()) |x| {
                if (x.role == r) break;
            } else continue;
            ss.add(p.section(h, r));
        }
        return h.div(.{ .class = "c-poolgrid", .data_island = "poolgrid" }, .{ss.done()});
    }

    fn section(p: *P, h: *H, r: Role) N {
        var ids: [pp.max]u16 = undefined;
        var files: [pp.max]?*const pd.LaneRole = undefined;
        var k: usize = 0;
        var waiting = false;
        var failed = false;
        for (p.picks()) |x| {
            if (x.role != r) continue;
            ids[k] = x.id;
            files[k] = null;
            if (find(pd.Lanes, &p.lanes, x.id)) |g| {
                if (g.f) |f| files[k] = f.of(r) else failed = true;
            } else waiting = true;
            k += 1;
        }
        const lanes = lanesOf(h, files[0..k]);
        // Before grid() sorts the shown lanes: weak spots list them most met first
        const weak: N = if (waiting or failed or lanes.len == 0) .none else p.weakSpots(h, r, ids[0..k], files[0..k], lanes);
        const total = @min(lanes.len, lanes_shown);
        var cov: u32 = 0;
        for (lanes[0..total]) |l| cov += @intFromBool(l.covered());
        const sorts = [_]struct { Sort, tree.Text }{ .{ .worst, W.worst }, .{ .met, W.met } };
        var items: [sorts.len]segmented.Item = undefined;
        for (sorts, &items) |s, *it| it.* = .{ .label = s[1], .selected = p.sort == s[0], .on = h.on(p, .{ .sort = s[0] }) };
        const label = r.label();
        const body: N = if (lanes.len == 0) h.p(.{ .class = "none" }, .{if (waiting) W.loading else if (failed) W.failed else W.no_lanes}) else p.grid(h, r, ids[0..k], files[0..k], lanes);
        return card.view(h, .{ .label = label }, &.{
            card.head(h, label, if (lanes.len > 0) W.covered.with(h, .{ .a = cov, .b = total }) else null, &.{
                if (lanes.len > 1) segmented.view(h, .{ .s = .s, .label = W.sort }, &items) else .none,
            }),
            weak,
            h.div(.{ .class = "sec" }, .{ h.div(.{ .class = "lanes" }, .{body}), p.what(h, r, ids[0..k]) }),
        });
    }

    /// What the whole pool shares in the role (note 50): lanes it has no answer to, by
    /// how often they are met, bans taking one of its champions often, every champion
    /// leaning early or late, and a role on one champion; each with its fix when the
    /// role main's file has one
    fn weakSpots(p: *P, h: *H, r: Role, ids: []const u16, files: []const ?*const pd.LaneRole, lanes: []const Lane) N {
        var met: u64 = 0;
        for (files) |f| met += if (f) |x| x.games else 0;
        var none: [weak_shown]u16 = undefined;
        var n: usize = 0;
        var n_all: u32 = 0;
        var thin: u32 = 0;
        var none_games: u64 = 0;
        for (lanes) |l| switch (answer(files, l.id)) {
            .some => {},
            .thin => thin += 1,
            .none => {
                if (n < none.len) {
                    none[n] = l.id;
                    n += 1;
                }
                n_all += 1;
                none_games += l.games;
            },
        };
        var lines = h.list();
        if (n_all > 0) {
            var icons = h.list();
            for (none[0..n]) |id| icons.add(champ.view(h, pp.iconOf(p.d, h, id), .{ .px = .@"20" }));
            const pct: u32 = if (met > 0) @intCast((100 * none_games + met / 2) / met) else 0;
            lines.add(h.el(.li, .{}, .{
                h.span(.{ .class = "wt" }, .{ W.no_answer, h.span(.{ .class = "ic" }, .{icons.done()}), h.span(.{ .class = "m" }, .{W.met_in.with(h, .{ .n = pct })}) }),
                if (thin > 0) h.span(.{ .class = "m" }, .{W.thin_more.with(h, .{ .n = thin })}) else null,
                p.coverFix(h, r, ids, none[0..n]),
            }));
        }
        const banned = p.banExposure(ids);
        if (ids.len > 1 and banned >= ban_clear) lines.add(p.bansLine(h, r, ids, banned));
        if (ids.len > 1) if (p.allLean(r, ids)) |t| lines.add(h.el(.li, .{}, .{h.span(.{ .class = "wt" }, .{t})}));
        if (ids.len == 1) lines.add(h.el(.li, .{}, .{
            h.span(.{ .class = "wt" }, .{W.alone.with(h, .{ .c = pp.iconOf(p.d, h, ids[0]).name })}),
            if (pctOf(banned) > 0) h.span(.{ .class = "m" }, .{W.banned_one.with(h, .{ .n = pctOf(banned) })}) else null,
            p.optionFix(h, r, ids, .also),
        }));
        // "No lane..." alone reads as filler beside a real weak spot: only as the sole line
        if (n_all == 0 and (thin > 0 or lines.items.items.len == 0)) lines.add(h.el(.li, .{ .data_ok = true }, .{if (thin > 0) W.unclear.with(h, .{ .n = thin }) else W.answered}));
        return h.div(.{ .class = "weak" }, .{ h.el(.h3, .{}, .{W.weak}), h.el(.ul, .{}, .{lines.done()}) });
    }

    fn mainFile(p: *const P, r: Role) ?*const pd.File {
        const g = find(pd.File, &p.mains, p.mainFor(r) orelse return null) orelse return null;
        return g.f;
    }

    /// The option covering most of `lanes` among the main's hard lanes
    fn coverFix(p: *P, h: *H, r: Role, ids: []const u16, lanes: []const u16) N {
        const f = p.mainFile(r) orelse return .none;
        var buf: [list_options]pd.File.Option = undefined;
        var best: ?pd.File.Option = null;
        var most: u32 = 0;
        for (f.options(ids, .hard, &buf)) |o| {
            var c: u32 = 0;
            for (f.hard, 0..) |l, k| {
                if (o.lanes & bit(k) != 0 and std.mem.findScalar(u16, lanes, l.id) != null) c += 1;
            }
            if (c > most) {
                most = c;
                best = o;
            }
        }
        const o = best orelse return .none;
        return h.span(.{ .class = "wt" }, .{ p.fix(h, r, f.cols[o.col].id), h.span(.{ .class = "m" }, .{W.covers.with(h, .{ .n = most })}) });
    }

    /// Games a ban takes at least one of `ids` in, ‰; bans taken as independent, close
    /// enough at these rates
    fn banExposure(p: *const P, ids: []const u16) u32 {
        var left: f32 = 1;
        for (ids) |id| left *= 1 - @as(f32, @floatFromInt(p.banOf(id))) / 1000;
        return @intFromFloat(@round(1000 * (1 - left)));
    }

    fn banOf(p: *const P, id: u16) u16 {
        return if (pp.indexOf(p.d, id)) |c| p.d.champs[c].ban else 0;
    }

    /// The figure, then each champion a ban takes, most banned first
    fn bansLine(p: *P, h: *H, r: Role, ids: []const u16, banned: u32) N {
        var by: [pp.max]u16 = undefined;
        @memcpy(by[0..ids.len], ids);
        std.sort.insertion(u16, by[0..ids.len], @as(*const P, p), moreBanned);
        var each = h.list();
        for (by[0..ids.len]) |id| {
            const b = pctOf(p.banOf(id));
            if (b == 0) break;
            each.add(h.span(.{ .class = "wt" }, .{
                champ.view(h, pp.iconOf(p.d, h, id), .{ .px = .@"20" }),
                h.span(.{ .class = "m" }, .{phrase.num(h, .pct, b)}),
            }));
        }
        return h.el(.li, .{}, .{
            h.span(.{ .class = "wt" }, .{ W.banned.with(h, .{ .n = pctOf(banned) }), each.done() }),
            p.optionFix(h, r, ids, .banned),
        });
    }

    /// Every champion in the role clearly leans the same way: advice, no fix
    fn allLean(p: *const P, r: Role, ids: []const u16) ?tree.Text {
        const b = bit(@backingInt(r));
        var early = true;
        var late = true;
        for (ids) |id| {
            const c = p.d.champs[pp.indexOf(p.d, id) orelse return null];
            early = early and c.early & b != 0;
            late = late and c.late & b != 0;
        }
        return if (early) W.all_early else if (late) W.all_late else null;
    }

    fn moreBanned(p: *const P, a: u16, b: u16) bool {
        return p.banOf(a) > p.banOf(b);
    }

    /// The role main's file's first option: what its players also play most, or what
    /// stands in when it is banned
    fn optionFix(p: *P, h: *H, r: Role, ids: []const u16, why: Why) N {
        const f = p.mainFile(r) orelse return .none;
        var buf: [1]pd.File.Option = undefined;
        const os = f.options(ids, why, &buf);
        if (os.len == 0) return .none;
        return p.fix(h, r, f.cols[os[0].col].id);
    }

    fn fix(p: *P, h: *H, r: Role, id: u16) N {
        const c = pp.iconOf(p.d, h, id);
        // The name shows, "+" before it (CSS): "Add Dr. Mundo" is over a label's 2 words
        return h.button(.{ .type = "button", .class = "fix", .aria_label = W.add.with(h, .{ .c = c.name }), .on_click = h.on(p, .{ .add = .{ .id = id, .role = r } }) }, .{
            champ.view(h, c, .{ .px = .@"20", .named = false }),
            c.name,
        });
    }

    fn grid(p: *P, h: *H, r: Role, ids: []const u16, files: []const ?*const pd.LaneRole, all: []Lane) N {
        const open = p.open & bit(@backingInt(r)) != 0;
        const lanes = all[0..if (open) all.len else @min(all.len, lanes_shown)];
        if (p.sort == .worst) std.sort.insertion(Lane, lanes, {}, worstFirst);
        var met: u64 = 0;
        for (files) |f| met += if (f) |x| x.games else 0;
        const rows = h.mem.alloc(heatgrid.Head, lanes.len) catch return oom(h);
        for (rows, lanes) |*x, l| {
            const c = pp.iconOf(p.d, h, l.id);
            const met_pct: u32 = if (met > 0) @intCast((100 * @as(u64, l.games) + met / 2) / met) else 0;
            x.* = .{ .champ = c, .label = .{ .s = c.name }, .flag = !l.covered(), .tail = phrase.num(h, .pct, met_pct) };
        }
        const cols = h.mem.alloc(heatgrid.Head, ids.len) catch return oom(h);
        for (cols, ids) |*x, id| {
            const c = pp.iconOf(p.d, h, id);
            x.* = .{ .champ = c, .label = .{ .s = c.name } };
        }
        const cells = h.mem.alloc(?heatgrid.Cell, rows.len * cols.len) catch return oom(h);
        const on = h.mem.alloc(tree.Handler, cells.len) catch return oom(h);
        for (lanes, 0..) |l, i| for (files, 0..) |f, j| {
            const o = if (f) |x| opp(x, l.id) else null;
            cells[i * cols.len + j] = if (o) |x| .{
                .pp = @as(f32, @floatFromInt(x.pp)) / 10,
                .games = x.games,
                .best = l.covered() and x.games >= pd.min_games and x.pp == l.best.?,
            } else null;
            on[i * cols.len + j] = h.on(p, .{ .cell = .{ .role = r, .row = @intCast(i), .col = @intCast(j) } });
        };
        const s: ?[2]u8 = if (p.cell) |c| (if (c.role == r and c.row < rows.len and c.col < cols.len) .{ c.row, c.col } else null) else null;
        const readout: N = if (s) |x| blk: {
            const o = if (files[x[1]]) |f| opp(f, lanes[x[0]].id) else null;
            const a = cols[x[1]].champ.name;
            const b = rows[x[0]].champ.name;
            const v = o orelse break :blk h.span(.{}, .{W.read_none.with(h, .{ .a = a, .b = b })});
            break :blk h.span(.{}, .{
                W.read.with(h, .{ .a = a, .b = b, .v = phrase.num(h, .points, @as(f32, @floatFromInt(v.pp)) / 10).s, .g = phrase.num(h, .count, v.games).s }),
                if (v.gold) |g| h.span(.{}, .{
                    " · ",
                    W.gold.with(h, .{ .v = phrase.num(h, .signed, g).s }),
                    " · ",
                    h.a(.{ .href = h.fmt("/matchups/{s}/{s}-vs-{s}{s}", .{ @tagName(r), p.slug(ids[x[1]]), p.slug(lanes[x[0]].id), urls.view_queries[p.d.view] }) }, .{W.matchup}),
                }) else null,
            });
        } else h.span(.{}, .{W.press});
        return h.div(.{}, .{
            heatgrid.view(h, .{ .corner = W.vs, .rows = rows, .cols = cols, .cells = cells, .sel = s, .on = on, .readout = readout }),
            if (all.len > lanes_shown) h.button(.{ .type = "button", .aria_expanded = open, .on_click = h.on(p, .{ .all = r }) }, .{if (open) W.fewer else W.all.with(h, .{ .n = all.len })}) else null,
        });
    }

    fn slug(p: *const P, id: u16) []const u8 {
        return if (pp.indexOf(p.d, id)) |c| p.d.champs[c].slug else "";
    }

    /// What covers the role main's hard lanes (CandidateList), from its pool file
    fn what(p: *P, h: *H, r: Role, ids: []const u16) N {
        const main = p.mainFor(r) orelse return p.whatNote(h, if (ids.len > 0 and p.fewMains(ids)) W.few.with(h, .{ .c = pp.iconOf(p.d, h, ids[0]).name }) else W.no_main.with(h, .{ .r = r.label().s }));
        const g = find(pd.File, &p.mains, main) orelse return p.whatNote(h, W.loading);
        const f = g.f orelse return p.whatNote(h, W.failed);
        const whys = [_]struct { Why, tree.Text }{ .{ .hard, W.why_hard }, .{ .banned, W.why_banned }, .{ .also, W.why_also } };
        var items: [whys.len]segmented.Item = undefined;
        for (whys, &items) |w, *it| it.* = .{ .label = w[1], .selected = p.why == w[0], .on = h.on(p, .{ .why = w[0] }) };
        var buf: [list_options]pd.File.Option = undefined;
        const opts = f.options(ids, p.why, &buf);
        const rows = h.mem.alloc(candlist.Row, opts.len) catch return oom(h);
        for (rows, opts, 1..) |*x, o, rank| {
            const id = f.cols[o.col].id;
            const c = pp.iconOf(p.d, h, id);
            x.* = .{
                .champ = c,
                .rank = @intCast(rank),
                .win = if (p.why == .also) share(f, f.cols[o.col].together) else null,
                .reasons = p.reasons(h, f, o),
                .tag = if (pp.indexOf(p.d, id)) |i| switch (p.d.champs[i].pickup) {
                    .usual => null,
                    .harder => W.harder,
                    .easier => W.easier,
                } else null,
                .label = W.add.with(h, .{ .c = c.name }),
                .on = h.on(p, .{ .add = .{ .id = id, .role = r } }),
            };
        }
        return h.div(.{ .class = "what" }, .{
            h.div(.{ .class = "wh" }, .{
                h.el(.h3, .{}, .{W.what}),
                segmented.view(h, .{ .s = .s, .label = W.why_label }, &items),
            }),
            if (rows.len == 0) h.p(.{ .class = "none" }, .{W.nothing}) else candlist.view(h, .{
                .rows = rows,
                .head = if (p.why == .also) .{ W.champion, W.mains_play, W.blank } else null,
            }),
        });
    }

    /// The role's champions are mains elsewhere or of nothing
    fn fewMains(p: *const P, ids: []const u16) bool {
        for (ids) |id| if (pp.indexOf(p.d, id)) |c| if (pp.mainOf(p.d, c) != null) return false;
        return true;
    }

    fn whatNote(_: *const P, h: *H, t: tree.Text) N {
        return h.div(.{ .class = "what" }, .{ h.el(.h3, .{}, .{W.what}), h.p(.{ .class = "none" }, .{t}) });
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
            out[n] = .{ .text = .{ .s = pp.iconOf(p.d, h, l.id).name }, .pp = @as(f32, @floatFromInt(x.pp)) / 10 };
            n += 1;
        }
        out = out[0..n];
        // Best first; at most 8 lanes
        if (n > 1) for (1..n) |i| {
            var j = i;
            while (j > 0 and out[j - 1].pp < out[j].pp) : (j -= 1) std.mem.swap(candlist.Reason, &out[j - 1], &out[j]);
        };
        return out;
    }
};

fn find(comptime T: type, list: *const [kept]Got(T), id: u16) ?*const Got(T) {
    for (list) |*g| if (g.id == id) return g;
    return null;
}

/// A lane is unanswered only when every pool champion is clearly below usual into it:
/// min_games or more and min_pp or more below. `thin` when it would be but for a cell
/// with too few games (or none)
const Answer = enum { some, none, thin };

fn answer(files: []const ?*const pd.LaneRole, id: u16) Answer {
    var below: usize = 0;
    var thin = false;
    for (files) |f| {
        const o = (if (f) |x| opp(x, id) else null) orelse {
            thin = true;
            continue;
        };
        if (o.games < pd.min_games) {
            thin = true;
            continue;
        }
        if (o.pp > -pd.min_pp) return .some;
        below += 1;
    }
    if (below == 0) return .some;
    return if (thin) .thin else .none;
}

fn opp(f: *const pd.LaneRole, id: u16) ?pd.Opp {
    for (f.opps) |o| if (o.id == id) return o;
    return null;
}

/// Each opponent of the columns once, most met first, with the pool's best answer
pub fn lanesOf(h: *H, files: []const ?*const pd.LaneRole) []Lane {
    var cap: usize = 0;
    for (files) |f| cap += if (f) |x| x.opps.len else 0;
    const out = h.mem.alloc(Lane, cap) catch {
        h.oom = true;
        return &.{};
    };
    var n: usize = 0;
    for (files) |f| for ((f orelse continue).opps) |o| {
        const l = for (out[0..n]) |*l| {
            if (l.id == o.id) break l;
        } else blk: {
            out[n] = .{ .id = o.id, .games = 0 };
            n += 1;
            break :blk &out[n - 1];
        };
        l.games += o.games;
        if (o.games >= pd.min_games and (l.best == null or o.pp > l.best.?)) l.best = o.pp;
    };
    std.sort.insertion(Lane, out[0..n], {}, mostMet);
    return out[0..n];
}

fn mostMet(_: void, a: Lane, b: Lane) bool {
    return a.games > b.games;
}

/// Lowest best answer first; lanes with no answer to judge last, most met first
fn worstFirst(_: void, a: Lane, b: Lane) bool {
    const x = a.best orelse return if (b.best == null) a.games > b.games else false;
    const y = b.best orelse return true;
    return if (x != y) x < y else a.games > b.games;
}

/// ‰ to a whole %
fn pctOf(permille: u32) u32 {
    return (permille + 5) / 10;
}

/// Of the main's players, %
fn share(f: *const pd.File, together: u32) ?f32 {
    if (f.players == 0) return null;
    return 100 * @as(f32, @floatFromInt(together)) / @as(f32, @floatFromInt(f.players));
}

fn bit(k: usize) u8 {
    return @as(u8, 1) << @intCast(k);
}

fn oom(h: *H) N {
    h.oom = true;
    return .none;
}

pub const css =
    \\@layer components {
    \\  .c-poolgrid { container-type: inline-size; display: grid; gap: var(--sp-4); min-width: 0; }
    \\  .c-poolgrid .sec { display: flex; flex-wrap: wrap; gap: var(--sp-4); align-items: flex-start; }
    \\  .c-poolgrid .lanes { flex: 1 1 380px; display: grid; gap: var(--sp-2); min-width: 0; }
    \\  .c-poolgrid .lanes .c-heat .rh { width: 150px; }
    \\  .c-poolgrid .what { flex: 1 1 320px; display: grid; gap: var(--sp-2); min-width: 0; }
    \\  .c-poolgrid .wh { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: var(--sp-2); }
    \\  .c-poolgrid .wh > h3 { margin: 0; font-size: var(--fs-m); }
    \\  .c-poolgrid .none { margin: 0; color: var(--faint); }
    \\  .c-poolgrid .lanes button[aria-expanded] { justify-self: start; min-height: 28px; padding: 0 var(--sp-2); border: 1px solid var(--line);
    \\    border-radius: var(--r-ctl); background: var(--panel-2); color: var(--t2); font: inherit;
    \\    font-size: var(--fs-xs); cursor: pointer; }
    \\  .c-poolgrid .lanes button[aria-expanded]:hover { color: var(--t1); border-color: var(--sel-line); }
    \\  .c-poolgrid .read a { margin-left: auto; }
    \\  .c-poolgrid .weak { display: grid; gap: var(--sp-2); padding-bottom: var(--sp-3); border-bottom: 1px solid var(--line); }
    \\  .c-poolgrid .weak > h3 { margin: 0; font-size: var(--fs-m); }
    \\  .c-poolgrid .weak ul { display: grid; gap: var(--sp-2); margin: 0; padding: 0; list-style: none; }
    \\  .c-poolgrid .weak li { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-1) var(--sp-3);
    \\    padding-left: var(--sp-3); border-left: 3px solid var(--them); }
    \\  .c-poolgrid .weak li[data-ok] { border-left-color: var(--us); color: var(--t2); }
    \\  .c-poolgrid .weak .wt { display: inline-flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\  .c-poolgrid .weak .ic { display: inline-flex; gap: 3px; }
    \\  .c-poolgrid .weak .m { color: var(--t2); font-size: var(--fs-xs); }
    \\  .c-poolgrid .weak .fix { display: inline-flex; align-items: center; gap: var(--sp-1); min-height: 28px; padding: 0 var(--sp-2) 0 6px;
    \\    border: 1px solid var(--line); border-radius: var(--r-ctl); background: var(--panel-2); color: var(--t1); font: inherit;
    \\    font-size: var(--fs-xs); cursor: pointer; }
    \\  .c-poolgrid .weak .fix:hover { border-color: var(--sel-line); }
    \\  .c-poolgrid .weak .fix::before { content: "+"; color: var(--t2); }
    \\  .c-poolgrid .weak .fix:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  @container (max-width: 480px) {
    \\    .c-poolgrid .lanes .c-heat .rh { width: auto; }
    \\  }
    \\}
    \\
;

/// Darius and Garen top, Vi jungle: Darius's and Garen's lanes into Fiora, Yone, Teemo
pub const Demo = struct {
    pub const darius: pd.Lanes = .{ .id = 1, .roles = &.{.{ .role = .top, .games = 4000, .opps = &.{
        .{ .id = 10, .games = 900, .pp = -26, .gold = -310 },
        .{ .id = 11, .games = 700, .pp = -17 },
        .{ .id = 20, .games = 800, .pp = 21, .gold = 420 },
        .{ .id = 2, .games = 300, .pp = 4 },
    } }} };
    pub const garen: pd.Lanes = .{ .id = 2, .roles = &.{.{ .role = .top, .games = 3000, .opps = &.{
        .{ .id = 10, .games = 600, .pp = 15 },
        .{ .id = 11, .games = 500, .pp = 3 },
        .{ .id = 20, .games = 20, .pp = 30 },
        .{ .id = 1, .games = 300, .pp = -4 },
    } }} };
    pub const vi: pd.Lanes = .{ .id = 40, .roles = &.{.{ .role = .jungle, .games = 5000, .opps = &.{
        .{ .id = 3, .games = 700, .pp = 12 },
        .{ .id = 4, .games = 400, .pp = -8 },
    } }} };
};

pub fn demoPage(h: *H, pool: []const u8) ?*Page {
    const p = h.mem.create(Page) catch {
        h.oom = true;
        return null;
    };
    p.* = .{ .d = &pp.Demo.data };
    p.setPool(pool);
    p.loadedLanes(1, &Demo.darius);
    p.loadedLanes(2, &Demo.garen);
    p.loadedLanes(40, &Demo.vi);
    p.loadedMain(1, &pd.demo);
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const p = demoPage(h, "1t-2t-40j") orelse return;
    p.cell = .{ .role = .top, .row = 0, .col = 0 };
    g.addFill("Darius and Garen top, Vi jungle: lanes worst first, what to add for top; jungle has no main's file", p.view(h));
    const alone = demoPage(h, "1t") orelse return;
    g.addFill("Darius alone top: weak spots, no answer to Fiora and Yone, a role on one champion", alone.view(h));
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

test "pool grid: lanes merged over the role's champions, the best answer, worst first" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const lanes = lanesOf(&h, &.{ Demo.darius.of(.top), Demo.garen.of(.top) });
    try testing.expectEqual(5, lanes.len);
    // Fiora 1,500 games, Yone 1,200, Teemo 820, Darius 300, Garen 300
    try testing.expectEqual(10, lanes[0].id);
    try testing.expectEqual(1500, lanes[0].games);
    try testing.expectEqual(15, lanes[0].best.?);
    // Garen's +3.0 into Teemo is thin: Darius's +2.1 answers it
    try testing.expectEqual(21, lanes[2].best.?);
    std.sort.insertion(Lane, lanes, {}, worstFirst);
    // Darius's row (Garen answers it -0.4), Yone +0.3, Garen +0.4, Fiora, Teemo
    try testing.expectEqual(1, lanes[0].id);
    try testing.expectEqual(20, lanes[4].id);
}

test "pool grid: needs lanes then mains, a section per role, what to add, add asks the pool" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: Page = .{ .d = &pp.Demo.data };
    try testing.expectEqual(null, p.need());
    try testing.expectEqualStrings("<div class=\"c-poolgrid\" data-island=\"poolgrid\"></div>", try render(a, &p));
    p.setPool("1t-2t-40j");
    try testing.expectEqual(Page.Need{ .main = false, .id = 1 }, p.need().?);
    const loading = try render(a, &p);
    // Each role's lanes and what to add
    try testing.expectEqual(4, std.mem.count(u8, loading, "Loading lanes"));
    p.loadedLanes(1, &Demo.garen); // not Darius's: a failure, never a stand-in
    try testing.expect(find(pd.Lanes, &p.lanes, 1).?.failed);
    p.lanes = @splat(.{});
    p.loadedLanes(1, &Demo.darius);
    p.loadedLanes(2, &Demo.garen);
    p.loadedLanes(40, &Demo.vi);
    // Darius is top's main; Vi's main role is jungle too
    try testing.expectEqual(Page.Need{ .main = true, .id = 1 }, p.need().?);
    p.loadedMain(1, &pd.demo);
    try testing.expectEqual(Page.Need{ .main = true, .id = 40 }, p.need().?);
    p.loadedMain(40, null);
    try testing.expectEqual(null, p.need());

    const out = try render(a, &p);
    try testing.expectEqual(2, std.mem.count(u8, out, "class=\"c-card\""));
    // Top: Fiora and Teemo covered; Yone (+0.3 at best), Garen and Darius open
    try testing.expect(std.mem.find(u8, out, "2 of 5 lanes covered") != null);
    // Garen into Fiora, Darius into Teemo, Vi into Jax
    try testing.expectEqual(3, std.mem.count(u8, out, "data-k=\"best\""));
    try testing.expect(std.mem.find(u8, out, "class=\"c-cand\"") != null);
    try testing.expect(std.mem.find(u8, out, "load. Reload") != null);

    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .cell = .{ .role = .top, .row = 0, .col = 1 } }, &ev);
    // Worst first: Darius's row
    try testing.expect(std.mem.find(u8, try render(a, &p), "Garen into Darius: −0.4 points vs usual · 300 games") != null);
    p.update(.{ .cell = .{ .role = .top, .row = 0, .col = 1 } }, &ev);
    try testing.expectEqual(null, p.cell);
    p.update(.{ .sort = .met }, &ev);
    p.update(.{ .cell = .{ .role = .top, .row = 0, .col = 0 } }, &ev);
    // Most met: Fiora, with gold and the matchup page
    const fiora = try render(a, &p);
    try testing.expect(std.mem.find(u8, fiora, "Darius into Fiora: −2.6 points vs usual · 900 games") != null);
    try testing.expect(std.mem.find(u8, fiora, " gold at 14 · <a href=\"/matchups/top/darius-vs-fiora\"") != null);

    p.update(.{ .add = .{ .id = 3, .role = .top } }, &ev);
    try testing.expectEqual(pp.Pick{ .id = 3, .role = .top }, p.adding.?);
}

test "weak spots: no answer only when every cell is clearly below, thin said apart" {
    const lr = struct {
        fn of(opps: []const pd.Opp) pd.LaneRole {
            return .{ .role = .top, .games = 1000, .opps = opps };
        }
    };
    const a = lr.of(&.{ .{ .id = 10, .games = 900, .pp = -26 }, .{ .id = 11, .games = 700, .pp = -17 }, .{ .id = 12, .games = 500, .pp = -9 } });
    const b = lr.of(&.{ .{ .id = 10, .games = 400, .pp = -12 }, .{ .id = 11, .games = 20, .pp = -30 } });
    const files = [_]?*const pd.LaneRole{ &a, &b };
    try testing.expectEqual(Answer.none, answer(&files, 10));
    // b's cell into 11 has 20 games
    try testing.expectEqual(Answer.thin, answer(&files, 11));
    // -0.9 is not clearly below
    try testing.expectEqual(Answer.some, answer(&files, 12));
    // Nobody has games into it: nothing to say
    try testing.expectEqual(Answer.some, answer(&files, 13));
}

test "weak spots: Darius alone top, no answer to Fiora and Yone, Jax covers both" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const p = demoPage(&h, "1t-40j").?;
    const out = try render(a, p);
    try testing.expectEqual(2, std.mem.count(u8, out, "Weak spots"));
    try testing.expect(std.mem.find(u8, out, "met in 40% of games") != null);
    try testing.expect(std.mem.find(u8, out, "covers 2") != null);
    try testing.expect(std.mem.find(u8, out, "Darius alone: one ban") != null);
    try testing.expect(std.mem.find(u8, out, "Vi alone: one ban") != null);
    // With Garen top every lane has an answer; said only when nothing else is
    const both = try render(a, demoPage(&h, "1t-2t").?);
    try testing.expect(std.mem.find(u8, both, " alone: ") == null);
    try testing.expect(std.mem.find(u8, both, "No lane your whole pool clearly loses") == null);
    // Darius banned 9.2%, Garen 4.1%: one of them in 13%; Mundo stands in, 50 games into Teemo
    try testing.expect(std.mem.find(u8, both, "One of them banned in 13% of games") != null);
    try testing.expect(std.mem.find(u8, both, "Add Dr. Mundo") != null);
    try testing.expect(std.mem.find(u8, out, "banned in 9% of games") != null);
    // Darius and Garen both lean early top; alone, Darius's lean is his own page's
    try testing.expect(std.mem.find(u8, both, "All lean early") != null);
    try testing.expect(std.mem.find(u8, out, "All lean") == null);
    // Bans at 2% each: 4%, under the 5% a weak spot needs; Garen not early: not all
    const q = demoPage(&h, "1t-2t").?;
    q.d = &quiet;
    const calm = try render(a, q);
    try testing.expect(std.mem.find(u8, calm, "One of them banned") == null);
    try testing.expect(std.mem.find(u8, calm, "All lean") == null);
    try testing.expect(std.mem.find(u8, calm, "No lane your whole pool clearly loses") != null);
}

/// The demo with low bans and no lean but Darius's
const quiet: pp.Data = blk: {
    var d = pp.Demo.data;
    var cs = pp.Demo.champs;
    for (&cs) |*c| {
        c.ban = @min(c.ban, 20);
        if (c.id != 1) c.early = 0;
    }
    const frozen = cs;
    d.champs = &frozen;
    break :blk d;
};
