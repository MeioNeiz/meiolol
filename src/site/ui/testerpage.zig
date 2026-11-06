//! The Draft tester page (docs/plan/ui/draft-tester.md, /private/tester): build a draft,
//! see blue's win chance under a named model, each seat's term and the model's checks. A
//! model from a Select of ModelBadges, "vs" a second one to compare (a second split under
//! the first and the gap in points, a column in the candidate panel); the board is
//! DraftBoard's full variant, a click choosing the seat the candidate panel
//! (testercand.zig, its own island and wasm) fills; Random game and Fill empty draw seats
//! by play share, Undo takes the last draw back. Board | Terms | Files under it. The
//! models, board, seat and tab are the URL fragment's (Url), which the panel shares.
//! Models are draft-model.bin files the page's code fetches (testerdata.zig); champion
//! keys and names come inline (data-bin)
const std = @import("std");
const tree = @import("tree.zig");
const ds = @import("core").draftscore;
const td = @import("testerdata.zig");
const champ = @import("champ.zig");
const champsearch = @import("champsearch.zig");
const draftboard = @import("draftboard.zig");
const modelbadge = @import("modelbadge.zig");
const role = @import("role.zig");
const segmented = @import("segmented.zig");
const reasons = @import("reasons.zig");
const select = @import("select.zig");
const split = @import("split.zig");
const button = @import("button.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const fmt = @import("fmt.zig");
const url = @import("url.zig");
const tl = @import("testerlane.zig");
const tsn = @import("testersetnet.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "TesterPage";
pub const scope = .{".c-tester"};
pub const sel = "[data-island=tester]";

const n_role = ds.n_role;
/// Both teams' in one list, as champ select's ten: left out of the candidates
pub const n_ban = 10;
/// The fills draw only champions with this share of the role's games or more on the
/// share patch (the old tester's)
const min_share = 0.01;

comptime {
    std.debug.assert(@typeInfo(role.Role).@"enum".field_names.len == n_role);
}

const W = struct {
    pub const title = plain("Draft tester");
    pub const model = plain("Model");
    pub const vs = plain("vs");
    pub const none = plain("none");
    pub const clear = plain("Clear");
    pub const random = plain("Random game");
    pub const fill = plain("Fill empty");
    pub const undo = plain("Undo");
    pub const ban = plain("Ban a champion");
    pub const bans = plain("Bans");
    pub const unban = Phrase("Remove the ban on {c:text}");
    pub const loading = plain("Loading the model…");
    pub const failed = plain("Could not load the model file: choose it again to retry");
    pub const bad_file = plain("The model file is damaged");
    pub const not_loaded = plain("not loaded");
    pub const blue = plain("Blue");
    pub const red = plain("Red");
    pub const board = plain("Board");
    pub const terms = plain("Terms");
    pub const files = plain("Files");
    pub const seat_pts = Phrase("{p:points} vs average");
    pub const seat_avg = plain("average");
    pub const seat_why = Phrase("{p:points} · {why:text}");
    pub const seat_lean = Phrase("{t:text} · {l:text}");
    pub const at_level = Phrase("Level at {m:int}");
    pub const at_ahead = Phrase("{s:text} ahead at {m:int}");
    pub const from_level = Phrase(", level from {m:int}");
    pub const from_strong = Phrase(", {s:text} stronger from {m:int}");
    pub const lean_nums = Phrase(" · Blue {g:signed} gold ({gl:signed} to {gh:signed}), {w:points} pts ({wl:points} to {wh:points})");
    pub const lean_how = plain("Each pick's own lean, summed: not the draft model");
    pub const early = plain("early");
    pub const late = plain("late");
    pub const strong = Phrase("strong {r:text}");
    pub const weak = Phrase("weak {r:text}");
    pub const into_l = Phrase("into {n:text}");
    pub const with_l = Phrase("with {n:text}");
    pub const gap_more = Phrase("{n:text} gives Blue {d:dec} pts more");
    pub const gap_less = Phrase("{n:text} gives Blue {d:dec} pts less");
    pub const agree = Phrase("{n:text} agrees within 1 pt");
    pub const why_draft = Phrase("Why {side:text} {p:rate}");
    pub const average_draft = plain("Every seat an average pick");
    pub const this_draft = plain("Blue, this draft");
    pub const strong_part = Phrase("{n:text} strong {r:text}");
    pub const weak_part = Phrase("{n:text} weak {r:text}");
    pub const ally_part = Phrase("{a:text} with {b:text}");
    pub const more_parts = Phrase("{n:int} smaller picks and pairs");
    pub const enemy_part = Phrase("{a:text} into {b:text}");
    pub const comp_part = plain("Damage mix and team shape");
    pub const why_gap = Phrase("Why {a:text} and {b:text} differ");
    pub const both = Phrase("{w:text}: {a:text} {x:points}, {b:text} {y:points}");
    pub const only = Phrase("{w:text}: {m:text} only");
    pub const both_avg = Phrase("{w:text}: {a:text} {x:rate}, {b:text} {y:rate}");
    pub const facts = Phrase("{kind:text} · {g:kilo} games · {lo:text} to {hi:text} · {acc:rate} on {n:kilo} held out");
    pub const from = Phrase("{where:text} {date:text}");
    pub const ok = Phrase("✓ {file:text}: {n:int} reference drafts match");
    pub const bad = Phrase("✗ {file:text}: {n:int} reference drafts, worst {gap:text} off");
    pub const no_refs = Phrase("✗ {file:text}: no reference drafts");
    pub const empty_terms = plain("Pick champions to see their terms");
    pub const side = plain("Side");
    pub const champion = plain("Champion");
    pub const term = plain("Term");
    pub const games = plain("Games");
    pub const pts = plain("Points");
};

/// The page's inline data: what the model files leave out
pub const Head = struct {
    /// Data Dragon version for icons
    ddragon: []const u8,
    /// By name: the search's entries, so a pick's index is a champion's
    champs: []const Champ,
    /// lean.tsv's champion-roles with enough games; empty without the file
    lean: []const LeanCell = &.{},
    lean_at: LeanAt = .{},
};

pub const Champ = struct { id: u32, key: []const u8, name: []const u8 };

/// A champfacts.LeanRow, rounded: gold whole, win in hundredths of a point; its lean
/// by Learn's rule (learnbuild.leanClear)
pub const LeanCell = struct { id: u16, role: u8, gold: i16, gold_sd: u16, win: i16, win_sd: u16, lean: Lean };

pub const Lean = enum(u8) { none, early, late };

/// champfacts' minutes and clear_z and Learn's sizes, so the island needn't import them
pub const LeanAt = struct { gold_minute: u8 = 14, win_minute: u8 = 20, z: f32 = 2, min_gold: u16 = 200, min_win: u8 = 3 };

fn leanOf(head: *const Head, id: u32, r: usize) ?LeanCell {
    for (head.lean) |c| if (c.id == id and c.role == r) return c;
    return null;
}

const TeamLean = struct { gold: f64 = 0, gold_sd: f64 = 0, win: f64 = 0, win_sd: f64 = 0 };

/// Blue minus red: gold at gold_minute and win points from an even game at win_minute,
/// summed over the picks with lean rows, sds by root sum of squares; null without one
fn teamLean(head: *const Head, teams: [2][n_role]u32) ?TeamLean {
    var t: TeamLean = .{};
    var n: usize = 0;
    for (0..2) |side| for (0..n_role) |r| {
        const c = leanOf(head, teams[side][r], r) orelse continue;
        const sign: f64 = if (side == 0) 1 else -1;
        const gsd: f64 = @floatFromInt(c.gold_sd);
        const wsd = @as(f64, @floatFromInt(c.win_sd)) / 100;
        t.gold += sign * @as(f64, @floatFromInt(c.gold));
        t.gold_sd += gsd * gsd;
        t.win += sign * @as(f64, @floatFromInt(c.win)) / 100;
        t.win_sd += wsd * wsd;
        n += 1;
    };
    if (n == 0) return null;
    t.gold_sd = @sqrt(t.gold_sd);
    t.win_sd = @sqrt(t.win_sd);
    return t;
}

/// The side ahead on one measure, blue minus red: Learn's sizes (learnbuild.leanClear),
/// clear at z sds; null when level
fn edge(x: f64, sd: f64, min: f64, z: f64) ?u1 {
    if (@abs(x) < z * sd or @abs(x) < min) return null;
    return if (x > 0) 0 else 1;
}

/// The models the page offers, in the Select's order (names: plan, Jacob 25 Oct)
pub const Which = enum(u8) { live, comp };

pub const Info = struct {
    name: tree.Text,
    short: tree.Text,
    /// In a compared Why's lines: "Live +5.5, Comp +1.2"
    word: tree.Text,
    /// Where the model's numbers show today (from the code, draft-tester.md)
    used_in: []const tree.Text,
    where: tree.Text,
    /// On the private site
    file: []const u8,
};

pub const infos = std.enums.EnumArray(Which, Info).init(.{
    .live = .{ .name = plain("Live draft model"), .short = plain("Live model"), .word = plain("Live"), .used_in = &.{ plain("Daily"), plain("App") }, .where = plain("Box"), .file = "/private/models/draft-model.bin" },
    .comp = .{ .name = plain("Comp model"), .short = plain("Comp model"), .word = plain("Comp"), .used_in = &.{}, .where = plain("Lab"), .file = "/private/lab/draft-model.bin" },
});

/// A model file, decoded, with its scorer and self-check
pub const Loaded = struct {
    m: td.Model,
    sc: ds.Scorer,
    check: td.Check,

    pub fn init(a: std.mem.Allocator, bytes: []const u8) !Loaded {
        const m = try td.Model.decode(a, bytes);
        var l: Loaded = .{ .m = m, .sc = undefined, .check = undefined };
        l.sc = try l.m.scorer(a);
        l.check = l.m.check(&l.sc);
        return l;
    }
};

/// The seat the candidate panel fills: the chosen one, else the first empty; null when
/// the board is full
pub fn shownSeat(teams: [2][n_role]u32, seat: ?u8) ?u8 {
    if (seat) |i| if (i < 2 * n_role) return i;
    for (0..2 * n_role) |i| if (teams[i / n_role][i % n_role] == 0) return @intCast(i);
    return null;
}

/// `teams` with champions the head lacks (removed since) or seen on an earlier seat
/// emptied
pub fn clean(head: *const Head, teams: [2][n_role]u32) [2][n_role]u32 {
    var out = teams;
    var seen: [2 * n_role]u32 = undefined;
    var n: usize = 0;
    for (&out) |*team| for (team) |*x| {
        if (x.* == 0) continue;
        if (champOf(head, x.*) == null or std.mem.findScalar(u32, seen[0..n], x.*) != null) {
            x.* = 0;
            continue;
        }
        seen[n] = x.*;
        n += 1;
    };
    return out;
}

/// `bans` with champions the head lacks, repeats and gaps dropped, and none on `teams`
pub fn cleanBans(head: *const Head, bans: [n_ban]u32, teams: [2][n_role]u32) [n_ban]u32 {
    var out: [n_ban]u32 = @splat(0);
    var n: usize = 0;
    for (bans) |id| {
        if (champOf(head, id) == null or std.mem.findScalar(u32, out[0..n], id) != null) continue;
        if (onBoard(teams, id)) continue;
        out[n] = id;
        n += 1;
    }
    return out;
}

fn onBoard(teams: [2][n_role]u32, id: u32) bool {
    for (teams) |team| if (std.mem.findScalar(u32, &team, id) != null) return true;
    return false;
}

/// The ban box's entries: the head's champions in its order, so an entry's index is a
/// champion's
pub fn searchIndex(a: std.mem.Allocator, head: *const Head) !champsearch.Index {
    const entries = try a.alloc(champsearch.Entry, head.champs.len);
    for (entries, head.champs) |*e, c| e.* = .{ .name = c.name, .src = try std.fmt.allocPrint(a, champ.icon_fmt, .{ head.ddragon, c.key }) };
    return .init(a, entries);
}

pub fn champOf(head: *const Head, id: u32) ?*const Champ {
    if (id == 0) return null;
    for (head.champs) |*c| if (c.id == id) return c;
    return null;
}

/// `failed`: not fetched (a network error, no file); `bad`: fetched, didn't decode or score
pub const Load = union(enum) { none, loading, failed, bad, ready: *const Loaded };

pub const Tab = enum(u8) { board, terms, files };

pub const Page = struct {
    head: *const Head,
    which: Which = .live,
    /// The model compared with `which`, never it
    vs: ?Which = null,
    loads: std.enums.EnumArray(Which, Load) = .initFill(.none),
    /// The lane model, for the candidate panel's Gold column: fetched once, whatever the
    /// draft model
    lane: tl.Load = .none,
    /// The lab's set net, on the Comp model: fetched once that is in
    net: tsn.Load = .none,
    /// By side (0 blue) and role; 0 empty
    teams: [2][n_role]u32 = @splat(@splat(0)),
    /// The seat being filled: side * n_role + role, side 0 blue; null: the first empty
    seat: ?u8 = null,
    /// Filled from the front; 0 empty
    bans: [n_ban]u32 = @splat(0),
    /// The board before the last fill, for Undo; any other change of it drops this
    undo: ?[2][n_role]u32 = null,
    /// The fills' draws; the page's code seeds it
    rng: std.Random.DefaultPrng = .init(0),
    /// The ban box; shown once `useIndex` gave it the champions
    search: champsearch.ChampSearch = .{ .index = undefined, .id = "tester-ban", .mode = .pick, .label = W.ban },
    has_index: bool = false,
    tab: Tab = .board,
    /// The server's render: Head as ui.data, base64
    bin: []const u8 = "",
    /// Set when the model or the board changed: the page's code saves them
    dirty: bool = false,

    /// The state both islands read and write: `b` blue's and `r` red's champions by role
    /// (0 empty), `s` the seat being filled (side * n_role + role; null: the first empty),
    /// `n` the bans, `v` the model compared
    pub const Url = struct {
        m: Which = .live,
        v: ?Which = null,
        b: [n_role]u32 = @splat(0),
        r: [n_role]u32 = @splat(0),
        s: ?u8 = null,
        t: Tab = .board,
        n: [n_ban]u32 = @splat(0),
    };

    /// `unban`: the ban's index
    pub const Msg = union(enum) { model: Which, vs: ?Which, tab: Tab, seat: u8, clear, ban, unban: u8, random, fill, undo };

    pub fn useIndex(p: *Page, ix: *const champsearch.Index) void {
        p.search.index = ix;
        p.has_index = true;
    }

    pub fn init(head: *const Head) Page {
        return .{ .head = head };
    }

    pub fn toUrl(p: *const Page) Url {
        return .{ .m = p.which, .v = p.vs, .b = p.teams[0], .r = p.teams[1], .s = p.seat, .t = p.tab, .n = p.bans };
    }

    /// The other island's change (a pick) or Back: saved again when it moved the board
    pub fn fromUrl(p: *Page, u: Url) void {
        const teams = clean(p.head, .{ u.b, u.r });
        const bans = cleanBans(p.head, u.n, teams);
        if (!std.meta.eql(teams, p.teams)) p.undo = null;
        if (u.m != p.which or !std.meta.eql(teams, p.teams) or !std.meta.eql(bans, p.bans)) p.dirty = true;
        p.which = u.m;
        p.vs = if (u.v == u.m) null else u.v;
        p.teams = teams;
        p.bans = bans;
        p.seat = if (u.s) |i| (if (i < 2 * n_role) i else null) else null;
        p.tab = u.t;
    }

    pub fn update(p: *Page, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .model => |w| {
                if (p.vs == w) p.vs = p.which;
                p.which = w;
                p.retry(w);
                p.dirty = true;
            },
            .vs => |w| {
                p.vs = if (w == p.which) null else w;
                if (w) |x| p.retry(x);
            },
            .tab => |t| p.tab = t,
            .seat => |i| {
                if (i >= 2 * n_role) return;
                p.seat = if (p.seat == i) null else i;
            },
            .clear => {
                p.teams = @splat(@splat(0));
                p.bans = @splat(0);
                p.seat = null;
                p.undo = null;
                p.dirty = true;
            },
            .random, .fill => {
                const l = p.ready() orelse return;
                const before = p.teams;
                // Emptied first, so a champion on a later seat isn't kept off an earlier one
                if (m == .random) p.teams = @splat(@splat(0));
                fill(&l.m, p.head, &p.teams, p.bans, p.rng.random());
                if (std.meta.eql(before, p.teams)) return;
                p.undo = before;
                p.dirty = true;
            },
            .undo => {
                p.teams = p.undo orelse return;
                p.undo = null;
                p.dirty = true;
            },
            .ban => {
                const e = p.search.chosen orelse return;
                p.search.chosen = null;
                ev.after = .{ .op = .focus, .ref = "input" };
                if (e >= p.head.champs.len) return;
                const id = p.head.champs[e].id;
                p.undo = null;
                // Banned off the board: a seat can't hold a banned champion
                for (&p.teams) |*team| for (team) |*x| {
                    if (x.* == id) x.* = 0;
                };
                const n = std.mem.findScalar(u32, &p.bans, 0) orelse return;
                if (std.mem.findScalar(u32, p.bans[0..n], id) != null) return;
                p.bans[n] = id;
                p.dirty = true;
            },
            .unban => |i| {
                if (i >= n_ban) return;
                std.mem.copyForwards(u32, p.bans[i .. n_ban - 1], p.bans[i + 1 ..]);
                p.bans[n_ban - 1] = 0;
                p.dirty = true;
            },
        }
    }

    /// Chosen again after a failure: the page's code fetches it again
    fn retry(p: *Page, w: Which) void {
        switch (p.loads.get(w)) {
            .failed, .bad => p.loads.set(w, .none),
            else => {},
        }
    }

    /// The model the page shows, once fetched
    pub fn ready(p: *const Page) ?*const Loaded {
        return p.readyOf(p.which);
    }

    /// The model compared, once fetched
    pub fn vsReady(p: *const Page) ?*const Loaded {
        return p.readyOf(p.vs orelse return null);
    }

    fn readyOf(p: *const Page, w: Which) ?*const Loaded {
        return switch (p.loads.get(w)) {
            .ready => |l| l,
            else => null,
        };
    }

    fn icon(p: *const Page, h: *H, id: u32) ?champ.Champ {
        const c = champOf(p.head, id) orelse return null;
        return .{ .name = c.name, .src = h.fmt(champ.icon_fmt, .{ p.head.ddragon, c.key }) };
    }

    pub fn view(p: *Page, h: *H) N {
        return h.div(.{ .class = "c-tester", .data_island = "tester", .data_bin = if (p.bin.len > 0) p.bin else null }, .{
            h.div(.{ .class = "top" }, .{
                h.el(.h1, .{}, .{W.title}),
                p.models(h),
            }),
            p.chance(h),
            p.leanLine(h),
            if (p.netOn()) |n| tsn.line(h, n.net, &n.l.sc, p.teams) else null,
            segmented.view(h, .{ .s = .s }, &.{
                .{ .label = W.board, .selected = p.tab == .board, .on = h.on(p, .{ .tab = .board }) },
                .{ .label = W.terms, .selected = p.tab == .terms, .on = h.on(p, .{ .tab = .terms }) },
                .{ .label = W.files, .selected = p.tab == .files, .on = h.on(p, .{ .tab = .files }) },
            }),
            switch (p.tab) {
                .board => p.board(h),
                .terms => p.termsView(h),
                .files => p.filesView(h),
            },
        });
    }

    fn badge(p: *const Page, h: *H, w: Which) modelbadge.Model {
        const i = infos.get(w);
        const l: ?*const Loaded = switch (p.loads.get(w)) {
            .ready => |x| x,
            else => null,
        };
        return .{
            .name = i.name,
            .short = i.short,
            .used_in = i.used_in,
            .from = if (l) |x| W.from.with(h, .{ .where = i.where.s, .date = shortDate(h, x.m.meta.newest_game) }) else i.where,
            .facts = if (l) |x| W.facts.with(h, .{
                .kind = x.m.params.kind,
                .g = x.m.meta.training_games,
                .lo = x.m.meta.oldest_patch,
                .hi = x.m.meta.newest_patch,
                .acc = 100 * x.m.meta.dev.accuracy,
                .n = x.m.meta.dev.games,
            }) else null,
        };
    }

    fn models(p: *Page, h: *H) N {
        const o: select.Opts = .{ .id = "tester-model", .label = W.model };
        var items: [std.enums.values(Which).len]select.Item = undefined;
        for (&items, std.enums.values(Which)) |*it, w| {
            const b = p.badge(h, w);
            it.* = .{ .label = b.name, .node = modelbadge.option(h, b), .selected = w == p.which, .on = h.on(p, .{ .model = w }) };
        }
        const shown = h.mem.dupe(select.Item, &items) catch {
            h.oom = true;
            return h.div(.{}, .{});
        };
        const parts = select.view(h, o, p.badge(h, p.which).short, shown);
        const vs = p.vsModel(h);
        return h.div(.{ .class = "model" }, .{ parts[0], parts[1], vs[0], vs[1] });
    }

    /// "none" and the models other than the shown one
    fn vsModel(p: *Page, h: *H) [2]N {
        var items: [std.enums.values(Which).len]select.Item = undefined;
        items[0] = .{ .label = W.none, .selected = p.vs == null, .on = h.on(p, .{ .vs = null }) };
        var n: usize = 1;
        for (std.enums.values(Which)) |w| {
            if (w == p.which) continue;
            const b = p.badge(h, w);
            items[n] = .{ .label = b.name, .node = modelbadge.option(h, b), .selected = w == p.vs, .on = h.on(p, .{ .vs = w }) };
            n += 1;
        }
        const shown = h.mem.dupe(select.Item, items[0..n]) catch {
            h.oom = true;
            return .{ .none, .none };
        };
        const value = if (p.vs) |w| infos.get(w).short else W.none;
        return select.view(h, .{ .id = "tester-vs", .label = W.vs }, value, shown);
    }

    fn chance(p: *Page, h: *H) N {
        const l = p.ready() orelse return h.p(.{ .class = "wait" }, .{switch (p.loads.get(p.which)) {
            .failed => W.failed,
            .bad => W.bad_file,
            else => W.loading,
        }});
        const c = l.sc.blue(p.teams);
        const one = splitOf(h, c);
        const x = p.vsReady() orelse return one;
        const b = x.sc.blue(p.teams);
        const d = 100 * (b.p - c.p);
        const n = infos.get(p.vs.?).short.s;
        // Same size bars, so the two splits line up on one scale
        return h.div(.{ .class = "two" }, .{
            h.span(.{}, .{infos.get(p.which).short}),
            one,
            h.span(.{}, .{infos.get(p.vs.?).short}),
            splitOf(h, b),
            h.p(.{}, .{if (@abs(d) < 1)
                W.agree.with(h, .{ .n = n })
            else if (d > 0)
                W.gap_more.with(h, .{ .n = n, .d = d })
            else
                W.gap_less.with(h, .{ .n = n, .d = -d })}),
        });
    }

    fn splitOf(h: *H, c: anytype) N {
        return split.view(h, .{ .p = @floatCast(100 * c.p), .lo = @floatCast(100 * c.lo), .hi = @floatCast(100 * c.hi), .s = .l });
    }

    /// The draft's timing from its picks' leans, once both teams have one
    fn leanLine(p: *const Page, h: *H) ?N {
        if (p.ready() == null) return null;
        for (p.teams) |t| if (std.mem.allEqual(u32, &t, 0)) return null;
        const t = teamLean(p.head, p.teams) orelse return null;
        const at = p.head.lean_at;
        const z: f64 = at.z;
        return h.p(.{ .class = "lean", .title = W.lean_how }, .{
            // Each minute on its own: a team sum isn't a champion's lean, where early means
            // ahead at 14 and weaker from even
            h.b(.{}, .{
                if (edge(t.gold, t.gold_sd, @floatFromInt(at.min_gold), z)) |x| W.at_ahead.with(h, .{ .s = sideName(x), .m = at.gold_minute }) else W.at_level.with(h, .{ .m = at.gold_minute }),
                if (edge(t.win, t.win_sd, @floatFromInt(at.min_win), z)) |x| W.from_strong.with(h, .{ .s = sideName(x), .m = at.win_minute }) else W.from_level.with(h, .{ .m = at.win_minute }),
            }),
            W.lean_nums.with(h, .{
                .g = whole(t.gold),
                .gl = whole(t.gold - z * t.gold_sd),
                .gh = whole(t.gold + z * t.gold_sd),
                .w = t.win,
                .wl = t.win - z * t.win_sd,
                .wh = t.win + z * t.win_sd,
            }),
        });
    }

    fn board(p: *Page, h: *H) N {
        const l = p.ready();
        var lanes: [n_role]draftboard.Lane = undefined;
        var on: [n_role][2]?tree.Handler = undefined;
        for (&lanes, &on, 0..) |*lane, *o, r| {
            lane.* = .{ .role = role.Role.all[r], .us = p.seatOf(h, l, 0, r), .them = p.seatOf(h, l, 1, r) };
            o.* = .{ h.on(p, .{ .seat = @intCast(r) }), h.on(p, .{ .seat = @intCast(n_role + r) }) };
        }
        return h.div(.{ .class = "bd" }, .{
            draftboard.fullOn(h, .{ .v = .full, .lanes = &lanes }, &on),
            if (l) |x| p.draftWhy(h, x, p.vsReady()) else null,
            p.bansRow(h),
            h.div(.{ .class = "acts" }, .{
                button.view(h, .{ .s = .s, .disabled = l == null, .on = h.on(p, .random) }, .{W.random}),
                button.view(h, .{ .s = .s, .disabled = l == null, .on = h.on(p, .fill) }, .{W.fill}),
                if (p.undo != null) button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .undo) }, .{W.undo}) else null,
                button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .clear) }, .{W.clear}),
            }),
        });
    }

    /// Each ban a button that lifts it, then the box while there is room
    fn bansRow(p: *Page, h: *H) N {
        var chips = h.list();
        for (p.bans, 0..) |id, i| {
            if (id == 0) break;
            const c = p.icon(h, id) orelse continue;
            chips.add(h.button(.{ .key = id, .type = "button", .class = "ban", .aria_label = W.unban.with(h, .{ .c = c.name }), .on_click = h.on(p, .{ .unban = @intCast(i) }) }, .{
                champ.view(h, c, .{ .px = .@"20", .state = .banned, .named = false }),
            }));
        }
        p.search.on_pick = h.on(p, .ban);
        const room = p.has_index and std.mem.findScalar(u32, &p.bans, 0) != null;
        return h.div(.{ .class = "bans" }, .{
            h.span(.{ .class = "line" }, .{W.bans}),
            chips.done(),
            if (room) p.search.view(h) else null,
        });
    }

    fn seatOf(p: *const Page, h: *H, l: ?*const Loaded, side: u1, r: usize) draftboard.Seat {
        const id = p.teams[side][r];
        return .{
            .champ = p.icon(h, id),
            .state = if (id != 0) .locked else .empty,
            .sub = if (l) |x| (if (id != 0) p.seatLine(h, x, side, r) else .{ .s = "" }) else .{ .s = "" },
            .sel = if (shownSeat(p.teams, p.seat)) |i| i == @as(usize, side) * n_role + r else false,
        };
    }

    /// The seat's points over the role's average pick and its largest named part in words
    /// ("+2.6 · into Darius"); the points alone when nothing is named
    fn seatLine(p: *const Page, h: *H, l: *const Loaded, side: u1, r: usize) tree.Text {
        const line = p.seatWhy(h, l, side, r);
        const c = leanOf(p.head, p.teams[side][r], r) orelse return line;
        return switch (c.lean) {
            .none => line,
            .early => W.seat_lean.with(h, .{ .t = line.s, .l = W.early.s }),
            .late => W.seat_lean.with(h, .{ .t = line.s, .l = W.late.s }),
        };
    }

    fn seatWhy(p: *const Page, h: *H, l: *const Loaded, side: u1, r: usize) tree.Text {
        const w = l.sc.why(p.teams, side, r, p.teams[side][r]);
        var top: ?ds.Part = null;
        for (w.parts()) |x| {
            if (top == null or @abs(x.pp) > @abs(top.?.pp)) top = x;
        }
        const alone = if (@abs(w.total()) < 0.05) W.seat_avg else W.seat_pts.with(h, .{ .p = w.total() });
        const x = top orelse return alone;
        if (!(@abs(x.pp) >= min_part)) return alone;
        const rl: []const u8 = @tagName(role.Role.all[r]);
        const why: tree.Text = switch (x.kind) {
            .base => if (x.pp > 0) W.strong.with(h, .{ .r = rl }) else W.weak.with(h, .{ .r = rl }),
            .enemy => W.into_l.with(h, .{ .n = p.nameOf(x.other) }),
            .ally => W.with_l.with(h, .{ .n = p.nameOf(x.other) }),
        };
        return W.seat_why.with(h, .{ .p = w.total(), .why = why.s });
    }

    fn nameOf(p: *const Page, id: u32) []const u8 {
        return if (champOf(p.head, id)) |c| c.name else "?";
    }

    /// The full board's chance from the empty board's, part by part: the largest named,
    /// the others summed as the rest. Compared (`e` the other model's): from the shown
    /// model's chance to the other's, each line the gap between the two on one part, the
    /// baselines' gap first. Only while the panel has no seat to fill
    fn draftWhy(p: *const Page, h: *H, l: *const Loaded, vs: ?*const Loaded) ?N {
        if (shownSeat(p.teams, p.seat) != null) return null;
        const d = l.sc.draftWhy(p.teams);
        const e: ?ds.DraftWhy = if (vs) |x| x.sc.draftWhy(p.teams) else null;
        var buf: [2 * ds.max_draft_parts]Gap = undefined;
        const g = gaps(&d, if (e) |*x| x else null, &buf);
        std.sort.pdq(Gap, g, {}, Gap.larger);
        var n: usize = 0;
        while (n < @min(g.len, max_lines) and @abs(g[n].pp) >= min_part) n += 1;
        const wa = if (vs != null) infos.get(p.which).word.s else "";
        const wb = if (vs != null) infos.get(p.vs.?).word.s else "";
        const ec = if (e) |x| x.comp else 0;
        const dc = if (e != null) ec - d.comp else d.comp;
        const comp = @abs(dc) >= min_part;
        var small: f64 = 0;
        for (g) |x| small += x.pp;
        const terms = h.mem.alloc(reasons.Term, n + @intFromBool(comp) + 2) catch {
            h.oom = true;
            return null;
        };
        var k: usize = 0;
        if (e) |x| {
            terms[0] = .{ .pp = @floatCast(100 * (x.empty.p - d.empty.p)), .label = W.both_avg.with(h, .{ .w = W.average_draft.s, .a = wa, .x = 100 * d.empty.p, .b = wb, .y = 100 * x.empty.p }) };
            k = 1;
        }
        var named: f64 = 0;
        for (g[0..n]) |x| {
            named += x.pp;
            const part = x.a orelse x.b.?;
            const w = p.partLabel(h, part);
            terms[k] = .{ .pp = @floatCast(x.pp), .games = part.games, .label = if (vs == null) w else gapLabel(h, w, if (x.a) |y| y.pp else null, if (x.b) |y| y.pp else null, wa, wb) };
            k += 1;
        }
        if (comp) {
            terms[k] = .{ .pp = @floatCast(dc), .label = if (vs == null) W.comp_part else gapLabel(h, W.comp_part, if (d.comp == 0) null else d.comp, if (ec == 0) null else ec, wa, wb) };
            k += 1;
        }
        small -= named;
        const n_small = g.len - n;
        // Factor terms, and whatever is too small for a line of its own
        var rest = (if (e) |x| x.rest - d.rest else d.rest) + (if (comp) 0 else dc);
        if (n_small > 0 and @abs(small) >= 0.05) {
            terms[k] = .{ .pp = @floatCast(small), .label = W.more_parts.with(h, .{ .n = n_small }) };
            k += 1;
        } else rest += small;
        const to = if (e) |x| x.with else d.with;
        return h.div(.{ .class = "why", .data_gap = vs != null }, .{
            h.el(.h2, .{}, .{if (vs != null)
                W.why_gap.with(h, .{ .a = infos.get(p.which).short.s, .b = infos.get(p.vs.?).short.s })
            else
                W.why_draft.with(h, .{ .side = W.blue.s, .p = 100 * d.with.p })}),
            reasons.view(h, .{
                .base_label = if (vs != null) infos.get(p.which).short else W.average_draft,
                .base = @floatCast(100 * (if (vs != null) d.with.p else d.empty.p)),
                .terms = terms[0..k],
                .rest = if (@abs(rest) >= 0.05) @floatCast(rest) else null,
                .total_label = if (vs != null) infos.get(p.vs.?).short else W.this_draft,
                .low = @floatCast(100 * to.lo),
                .high = @floatCast(100 * to.hi),
                .tip_id = "tester-why-rest",
            }, .points),
        });
    }

    /// A draft part in words: a pick's strength by its own side's sign, or a pair
    fn partLabel(p: *const Page, h: *H, x: ds.DraftPart) tree.Text {
        // Blue's points: a red pick weaker than average is a plus
        const own = if (x.side == 0) x.pp else -x.pp;
        const r: []const u8 = @tagName(role.Role.all[x.ra]);
        return switch (x.kind) {
            .base => if (own > 0) W.strong_part.with(h, .{ .n = p.nameOf(x.a), .r = r }) else W.weak_part.with(h, .{ .n = p.nameOf(x.a), .r = r }),
            .ally => W.ally_part.with(h, .{ .a = p.nameOf(x.a), .b = p.nameOf(x.b) }),
            .enemy => W.enemy_part.with(h, .{ .a = p.nameOf(x.a), .b = p.nameOf(x.b) }),
        };
    }

    /// The set net with the Comp model it corrects, when both are in and match
    fn netOn(p: *const Page) ?struct { net: *const tsn.Loaded, l: *const Loaded } {
        if (p.which != .comp) return null;
        const l = p.ready() orelse return null;
        return switch (p.net) {
            .ready => |n| if (n.shown()) .{ .net = n, .l = l } else null,
            else => null,
        };
    }

    fn termsView(p: *Page, h: *H) N {
        const terms = p.termsTable(h);
        const n = p.netOn() orelse return terms;
        return h.div(.{ .class = "bd" }, .{ terms, tsn.breakdown(h, n.net, &n.l.sc, p.teams, p.head, 8) });
    }

    fn termsTable(p: *Page, h: *H) N {
        const l = p.ready() orelse return h.p(.{ .class = "wait" }, .{W.loading});
        var rows = h.list();
        for (0..2) |side| for (0..n_role) |r| {
            const id = p.teams[side][r];
            const c = champOf(p.head, id) orelse continue;
            const s = l.sc.slot(id, r);
            const games: u32 = if (l.sc.terms.get(ds.termKey(id, r))) |i| l.m.params.terms[i].games else 0;
            rows.add(h.tr(.{ .key = side * n_role + r }, .{
                h.td(.{}, .{if (side == 0) W.blue else W.red}),
                h.td(.{}, .{role.view(h, role.Role.all[r], .{ .s = .s })}),
                h.td(.{ .class = "l" }, .{c.name}),
                h.td(.{}, .{fixed(h, s.b, 3)}),
                h.td(.{}, .{phrase.num(h, .count, games)}),
                h.td(.{}, .{phrase.num(h, .points, seatPoints(l, p.teams, @intCast(side), r))}),
            }));
        };
        const body = rows.done();
        if (body.len == 0) return h.p(.{ .class = "wait" }, .{W.empty_terms});
        return h.table(.{ .class = "c-table" }, .{
            h.thead(.{}, .{h.tr(.{}, .{
                h.th(.{}, .{W.side}),
                h.th(.{}, .{}),
                h.th(.{ .class = "l" }, .{W.champion}),
                h.th(.{}, .{W.term}),
                h.th(.{}, .{W.games}),
                h.th(.{ .data_answer = true }, .{W.pts}),
            })}),
            h.tbody(.{}, .{body}),
        });
    }

    fn filesView(p: *Page, h: *H) N {
        var lines = h.list();
        for (std.enums.values(Which)) |w| {
            const i = infos.get(w);
            lines.add(h.li(.{ .key = @backingInt(w) }, .{switch (p.loads.get(w)) {
                .ready => |l| blk: {
                    if (l.check.drafts == 0) break :blk W.no_refs.with(h, .{ .file = i.file });
                    if (l.check.ok()) break :blk W.ok.with(h, .{ .file = i.file, .n = l.check.drafts });
                    break :blk W.bad.with(h, .{ .file = i.file, .n = l.check.drafts, .gap = fixed(h, l.check.worst, 9) });
                },
                .failed => tree.Text{ .s = h.fmt("{s}: {s}", .{ i.file, W.failed.s }) },
                .bad => tree.Text{ .s = h.fmt("{s}: {s}", .{ i.file, W.bad_file.s }) },
                .loading => tree.Text{ .s = h.fmt("{s}: …", .{i.file}) },
                .none => tree.Text{ .s = h.fmt("{s}: {s}", .{ i.file, W.not_loaded.s }) },
            }}));
        }
        lines.add(h.li(.{ .key = 100 }, .{tl.fileLine(h, p.lane)}));
        if (p.net != .none) lines.add(h.li(.{ .key = 101 }, .{tsn.fileLine(h, p.net)}));
        return h.ul(.{ .class = "files" }, .{lines.done()});
    }
};

fn sideName(x: u1) []const u8 {
    return (if (x == 0) W.blue else W.red).s;
}

fn whole(x: f64) i64 {
    return @intFromFloat(@round(x));
}

/// Rounded as shown, so a part a hair under 0 reads 0.0, not −0.0
fn tenth(x: f64) f64 {
    return @round(10 * x) / 10;
}

/// Lines of the full board's Why before the rest
const max_lines = 8;

/// One line of a Why: a pick or pair as the shown model (a) and, compared, the other (b)
/// price it; pp the line's points: a's, or compared b's less a's
pub const Gap = struct {
    a: ?ds.DraftPart,
    b: ?ds.DraftPart,
    pp: f64,

    fn larger(_: void, x: Gap, y: Gap) bool {
        return @abs(x.pp) > @abs(y.pp);
    }
};

/// A compared Why line's label: what each model (`wa`, `wb`) gives the part, or the one
/// that prices it
fn gapLabel(h: *H, what: tree.Text, a: ?f64, b: ?f64, wa: []const u8, wb: []const u8) tree.Text {
    const x = a orelse return W.only.with(h, .{ .w = what.s, .m = wb });
    const y = b orelse return W.only.with(h, .{ .w = what.s, .m = wa });
    return W.both.with(h, .{ .w = what.s, .a = wa, .x = tenth(x), .b = wb, .y = tenth(y) });
}

/// `a`'s parts, or with `b` the gap on each part either prices, matched by pick or pair.
/// The gaps with the baselines', comp and rest gaps sum to b's chance less a's
pub fn gaps(a: *const ds.DraftWhy, b: ?*const ds.DraftWhy, out: *[2 * ds.max_draft_parts]Gap) []Gap {
    var n: usize = 0;
    for (a.parts()) |x| {
        const y = if (b) |w| find(w, x) else null;
        out[n] = .{ .a = x, .b = y, .pp = if (b == null) x.pp else (if (y) |v| v.pp else 0) - x.pp };
        n += 1;
    }
    if (b) |w| for (w.parts()) |y| if (find(a, y) == null) {
        out[n] = .{ .a = null, .b = y, .pp = y.pp };
        n += 1;
    };
    return out[0..n];
}

fn find(w: *const ds.DraftWhy, x: ds.DraftPart) ?ds.DraftPart {
    for (w.parts()) |y| if (y.kind == x.kind and y.side == x.side and y.a == x.a and y.b == x.b and y.ra == x.ra and y.rb == x.rb) return y;
    return null;
}
/// A part under this many points says nothing the total doesn't
const min_part = 0.1;

/// What a seat adds to its team's chance over the role's average pick, in points
fn seatPoints(l: *const Loaded, teams: [2][n_role]u32, side: u1, r: usize) f64 {
    var without = teams;
    without[side][r] = 0;
    const d = l.sc.blue(teams).p - l.sc.blue(without).p;
    return 100 * if (side == 0) d else -d;
}

/// fmt.fixed's, "?" for NaN or infinity
fn fixed(h: *H, x: f64, comptime places: u4) []const u8 {
    if (!std.math.isFinite(x)) return "?";
    var out: std.Io.Writer.Allocating = .init(h.mem);
    fmt.fixed(&out.writer, x, places, false) catch {
        h.oom = true;
    };
    return out.written();
}

/// "2026-10-24" as "24 Oct"
fn shortDate(h: *H, ymd: []const u8) []const u8 {
    if (ymd.len != 10) return ymd;
    const m = std.fmt.parseInt(u8, ymd[5..7], 10) catch return ymd;
    const d = std.fmt.parseInt(u8, ymd[8..10], 10) catch return ymd;
    if (m < 1 or m > 12) return ymd;
    return h.fmt("{d} {s}", .{ d, fmt.months_short[m - 1] });
}

/// Each empty seat of `teams` drawn by play share in its role on the share patch, from
/// the champions the candidates list with min_share or more, not banned, not on another
/// seat; a role with none left stays empty
pub fn fill(m: *const td.Model, head: *const Head, teams: *[2][n_role]u32, bans: [n_ban]u32, rnd: std.Random) void {
    for (teams) |*team| for (team, 0..) |*seat, r| {
        if (seat.* != 0) continue;
        var sum: f64 = 0;
        for (m.cells) |c| if (drawable(m, head, teams.*, bans, c, r)) {
            sum += c.patch_share;
        };
        var x = rnd.float(f64) * sum;
        var pick: u32 = 0;
        // The last one drawable when rounding leaves x above 0
        for (m.cells) |c| {
            if (!drawable(m, head, teams.*, bans, c, r)) continue;
            pick = c.champion;
            x -= c.patch_share;
            if (x <= 0) break;
        }
        seat.* = pick;
    };
}

fn drawable(m: *const td.Model, head: *const Head, teams: [2][n_role]u32, bans: [n_ban]u32, c: td.Cell, r: usize) bool {
    if (c.role != r or c.games < m.min_games or !(c.patch_share >= min_share)) return false;
    return champOf(head, c.champion) != null and !onBoard(teams, c.champion) and std.mem.findScalar(u32, &bans, c.champion) == null;
}

/// `id` into seat `i` (side * n_role + role): a champion plays one seat a draft
pub fn place(teams: *[2][n_role]u32, i: u8, id: u32) void {
    if (i >= 2 * n_role) return;
    for (teams) |*team| for (team) |*x| {
        if (x.* == id) x.* = 0;
    };
    teams[i / n_role][i % n_role] = id;
}

/// The board as saved: "w t0,..,t9[ b0,..,b9]", w the model's index, t the seats, b the
/// bans when there are any
pub fn saved(p: *const Page, w: *std.Io.Writer) !void {
    try fmt.write(w, .int, @backingInt(p.which));
    for (p.teams, 0..) |team, s| for (team, 0..) |id, r| {
        try w.writeAll(if (s == 0 and r == 0) " " else ",");
        try fmt.write(w, .int, id);
    };
    if (p.bans[0] != 0) for (p.bans, 0..) |id, i| {
        try w.writeAll(if (i == 0) " " else ",");
        try fmt.write(w, .int, id);
    };
}

/// The saved board on a page opened with none (`p` as the URL `fragment` set it,
/// `server` its default): true if it took it. A link's board and model win over the
/// saved ones
pub fn restoreSaved(p: *Page, server: *const Page, fragment: []const u8, s: []const u8) bool {
    if (!std.meta.eql(p.teams, server.teams) or !std.meta.eql(p.bans, server.bans)) return false;
    const linked = p.which;
    restore(p, s);
    if (linksModel(fragment)) p.which = linked;
    return true;
}

/// The fragment names a model, the default one too
fn linksModel(fragment: []const u8) bool {
    var it = std.mem.tokenizeScalar(u8, std.mem.trimStart(u8, fragment, "#"), '&');
    while (it.next()) |kv| if (tree.startsWith(kv, "m=")) return true;
    return false;
}

/// Back from `saved` (bans optional: older saves have none); anything malformed leaves
/// the page as it is. A champion the head lacks (removed since) or seen on an earlier
/// seat leaves its seat empty
pub fn restore(p: *Page, s: []const u8) void {
    var it = std.mem.tokenizeAny(u8, s, " ,");
    const w = std.fmt.parseInt(u8, it.next() orelse return, 10) catch return;
    const which = std.enums.fromInt(Which, w) orelse return;
    var teams: [2][n_role]u32 = undefined;
    for (&teams) |*team| for (team) |*x| {
        x.* = std.fmt.parseInt(u32, it.next() orelse return, 10) catch return;
    };
    var bans: [n_ban]u32 = @splat(0);
    if (it.peek() != null) for (&bans) |*x| {
        x.* = std.fmt.parseInt(u32, it.next() orelse return, 10) catch return;
    };
    if (it.next() != null) return;
    p.which = which;
    p.teams = clean(p.head, teams);
    p.bans = cleanBans(p.head, bans, p.teams);
}

pub const css =
    \\@layer components {
    \\  .c-tester { display: grid; gap: var(--sp-3); container-type: inline-size; width: 100%; }
    \\  .c-tester > .top { display: flex; align-items: center; gap: var(--sp-3); flex-wrap: wrap; }
    \\  .c-tester > .top h1 { margin: 0; font-size: var(--fs-l); }
    \\  .c-tester .model { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-tester .wait { color: var(--muted); margin: 0; }
    \\  .c-tester .bd { display: grid; gap: var(--sp-2); justify-items: start; }
    \\  .c-tester .bd > .c-draft { width: 100%; }
    \\  .c-tester .bans { display: flex; align-items: center; gap: var(--sp-1); flex-wrap: wrap; }
    \\  .c-tester .bans > .line { color: var(--muted); font-size: var(--fs-s); margin-right: var(--sp-1); }
    \\  .c-tester .bans > .ban { padding: 0; border: 0; background: none; cursor: pointer; }
    \\  .c-tester .acts { display: flex; gap: var(--sp-1); flex-wrap: wrap; }
    \\  .c-tester > .two { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: var(--sp-1) var(--sp-3); align-items: start; }
    \\  .c-tester > .two > span { font-size: var(--fs-s); color: var(--muted); font-weight: var(--w-m); padding-top: 0.55em; }
    \\  .c-tester > .two > p { grid-column: 2; margin: 0; font-weight: var(--w-m); }
    \\  @container (max-width: 480px) { .c-tester > .two { grid-template-columns: minmax(0, 1fr); } .c-tester > .two > p { grid-column: 1; } }
    \\  .c-tester .lean { margin: 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-tester .lean > b { color: var(--text); font-weight: var(--w-m); }
    \\  .c-tester .why[data-gap] .lab { white-space: normal; }
    \\  .c-tester .why { display: grid; gap: var(--sp-1); width: 100%; max-width: 720px; }
    \\  .c-tester .why > h2 { margin: 0; font-size: inherit; font-weight: var(--w-b); }
    \\  .c-tester .files { margin: 0; padding: 0; list-style: none; display: grid; gap: var(--sp-1); font-size: var(--fs-s); }
    \\}
    \\
;

/// Hand-made data for the gallery and tests: two champions, one model
pub const Demo = struct {
    pub const head: Head = .{ .ddragon = "16.21.1", .champs = &.{ .{ .id = 266, .key = "Aatrox", .name = "Aatrox" }, .{ .id = 122, .key = "Darius", .name = "Darius" } } };

    /// The gallery's full board: the demo's two and eight more without terms
    const full_head: Head = .{ .ddragon = "16.21.1", .champs = head.champs ++ &[_]Champ{
        .{ .id = 64, .key = "LeeSin", .name = "Lee Sin" },
        .{ .id = 254, .key = "Vi", .name = "Vi" },
        .{ .id = 103, .key = "Ahri", .name = "Ahri" },
        .{ .id = 61, .key = "Orianna", .name = "Orianna" },
        .{ .id = 222, .key = "Jinx", .name = "Jinx" },
        .{ .id = 51, .key = "Caitlyn", .name = "Caitlyn" },
        .{ .id = 117, .key = "Lulu", .name = "Lulu" },
        .{ .id = 412, .key = "Thresh", .name = "Thresh" },
    }, .lean = &.{
        .{ .id = 266, .role = 0, .gold = 280, .gold_sd = 20, .win = -390, .win_sd = 30, .lean = .early },
        .{ .id = 122, .role = 0, .gold = 60, .gold_sd = 25, .win = -10, .win_sd = 30, .lean = .none },
        .{ .id = 64, .role = 1, .gold = 240, .gold_sd = 15, .win = -320, .win_sd = 20, .lean = .early },
        .{ .id = 222, .role = 3, .gold = -260, .gold_sd = 20, .win = 410, .win_sd = 30, .lean = .late },
        .{ .id = 61, .role = 2, .gold = -40, .gold_sd = 20, .win = 30, .win_sd = 25, .lean = .none },
    } };

    const terms = [_]ds.Term{
        .{ .champion = 266, .role = 0, .games = 500, .b = 0.2, .sd = 0.1 },
        .{ .champion = 122, .role = 0, .games = 400, .b = -0.1, .sd = 0.1 },
    };

    pub fn model() td.Model {
        return .{
            .meta = .{ .name = "demo", .run = "r", .snapshot = "s", .newest_game = "2026-10-24", .training_games = 1_700_000, .patch = "16.21", .patch_games = 500, .oldest_patch = "16.19", .newest_patch = "16.21", .platform = "EUW1", .dev = .{ .games = 173_000, .log_loss = 0.68, .baseline_log_loss = 0.69, .accuracy = 0.554, .auc = 0.57 } },
            .min_games = 100,
            .champions = &.{ .{ .id = 266, .name = "Aatrox" }, .{ .id = 122, .name = "Darius" } },
            .cells = &.{ .{ .champion = 266, .role = 0, .games = 500, .patch_share = 0.6 }, .{ .champion = 122, .role = 0, .games = 400, .patch_share = 0.4 } },
            .params = .{ .kind = "draft", .dim = 0, .intercept = &.{0.02}, .w = @splat(0), .z = @splat(0), .terms = &terms },
            .refs = &.{},
        };
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const l = a.create(Loaded) catch return;
    l.* = .{ .m = Demo.model(), .sc = undefined, .check = .{ .drafts = 0, .worst = 0 } };
    l.sc = l.m.scorer(a) catch return;
    const states = [_][]const u8{ "loading", "a draft", "a seat chosen", "terms", "files", "a ban" };
    for (states, 0..) |caption, i| {
        const p = a.create(Page) catch return;
        p.* = .init(&Demo.head);
        if (i > 0) p.loads.set(.live, .{ .ready = l });
        p.loads.set(.comp, .failed);
        p.teams[0][0] = 266;
        if (i != 2 and i != 5) p.teams[1][0] = 122;
        if (i == 5) p.bans[0] = 122;
        if (i == 2) p.seat = n_role;
        p.tab = switch (i) {
            3 => .terms,
            4 => .files,
            else => .board,
        };
        g.add(caption, p.view(g.h));
    }
    const p = a.create(Page) catch return;
    p.* = .init(&Demo.full_head);
    p.loads.set(.live, .{ .ready = l });
    p.loads.set(.comp, .failed);
    p.teams = .{ .{ 266, 64, 103, 222, 117 }, .{ 122, 254, 61, 51, 412 } };
    g.add("every seat picked: why blue's chance", p.view(g.h));
    const c = a.create(Loaded) catch return;
    c.* = .{ .m = Demo.model(), .sc = undefined, .check = .{ .drafts = 0, .worst = 0 } };
    c.m.params.intercept = &.{0.4};
    c.sc = c.m.scorer(a) catch return;
    const q = a.create(Page) catch return;
    q.* = p.*;
    q.vs = .comp;
    q.loads.set(.comp, .{ .ready = c });
    g.add("Comp model compared: two splits, the gap", q.view(g.h));
}

const testing = std.testing;

test "tester page: a placed champion leaves its other seat; seats, the URL both ways; scores" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var l: Loaded = .{ .m = Demo.model(), .sc = undefined, .check = undefined };
    l.sc = try l.m.scorer(a);
    var p: Page = .init(&Demo.head);
    p.loads.set(.live, .{ .ready = &l });
    place(&p.teams, 0, 266);
    try testing.expectEqual(266, p.teams[0][0]);
    place(&p.teams, n_role, 266);
    // Aatrox moved to red top
    try testing.expectEqual(0, p.teams[0][0]);
    try testing.expectEqual(266, p.teams[1][0]);
    place(&p.teams, 2 * n_role, 122);
    try testing.expectEqual(0, p.teams[0][0] + p.teams[0][1]);
    try testing.expectEqual(0, shownSeat(p.teams, null));
    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .seat = 2 * n_role }, &ev);
    try testing.expect(p.seat == null);
    p.update(.{ .seat = 3 }, &ev);
    p.update(.{ .seat = 3 }, &ev);
    try testing.expect(p.seat == null);
    p.update(.{ .seat = 3 }, &ev);
    try testing.expectEqual(3, shownSeat(p.teams, p.seat));
    var full: [2][n_role]u32 = @splat(@splat(1));
    try testing.expect(shownSeat(full, null) == null);
    full[1][4] = 0;
    try testing.expectEqual(9, shownSeat(full, null));
    try testing.expectEqual(2, shownSeat(full, 2));
    // To the URL and back; a stranger's link: unknown, repeated, out-of-range values
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try url.write(Page.Url, p.toUrl(), &w);
    try testing.expectEqualStrings("r=266-0-0-0-0&s=3", w.buffered());
    var q: Page = .init(&Demo.head);
    q.fromUrl(url.read(Page.Url, w.buffered()));
    try testing.expectEqual(p.teams, q.teams);
    try testing.expect(q.dirty);
    try testing.expectEqual(3, q.seat);
    q.fromUrl(url.read(Page.Url, "#m=comp&b=266-7-266-122&r=266-0-0-0-99999999999&s=10&t=files"));
    try testing.expectEqual(Which.comp, q.which);
    try testing.expectEqual([2][n_role]u32{ @splat(0), @splat(0) }, q.teams);
    try testing.expect(q.seat == null);
    try testing.expectEqual(Tab.files, q.tab);
    q.fromUrl(url.read(Page.Url, "#b=266-7-266-122-0&r=122-0-0-0-0&s=9"));
    try testing.expectEqual([2][n_role]u32{ .{ 266, 0, 0, 122, 0 }, @splat(0) }, q.teams);
    try testing.expectEqual(9, q.seat);
    // Red Aatrox (0.2) over the share-weighted average 0.6 * 0.2 + 0.4 * -0.1 = 0.08
    const red = seatPoints(&l, p.teams, 1, 0);
    const with: f64 = 0.02 + 0.08 - 0.2;
    const want = 100 * (1 / (1 + @exp(@as(f64, -0.02))) - 1 / (1 + @exp(-with)));
    try testing.expectApproxEqAbs(want, red, 1e-4);
    var out: std.Io.Writer.Allocating = .init(a);
    try saved(&p, &out.writer);
    try testing.expectEqualStrings("0 0,0,0,0,0,266,0,0,0,0", out.written());
    q = .init(&Demo.head);
    restore(&q, out.written());
    try testing.expectEqual(266, q.teams[1][0]);
    restore(&q, "9 1,2");
    try testing.expectEqual(266, q.teams[1][0]);
}

test "tester page: dates and views" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    try testing.expectEqualStrings("24 Oct", shortDate(&h, "2026-10-24"));
    try testing.expectEqualStrings("bad", shortDate(&h, "bad"));
    try testing.expectEqualStrings("2026-13-01", shortDate(&h, "2026-13-01"));
    try testing.expectEqualStrings("0.200", fixed(&h, 0.2, 3));
    try testing.expectEqualStrings("-1.005", fixed(&h, -1.0049999, 3));
    try testing.expectEqualStrings("0.000", fixed(&h, -0.0001, 3));
    try testing.expectEqualStrings("0.000000002", fixed(&h, 2e-9, 9));
    try testing.expectEqualStrings("?", fixed(&h, std.math.nan(f64), 3));
}

test "timing: blue's gold and points summed with their ranges, a lean only when both clear; seats' own leans" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var l: Loaded = .{ .m = Demo.model(), .sc = undefined, .check = undefined };
    l.sc = try l.m.scorer(a);
    var p: Page = .init(&Demo.full_head);
    p.loads.set(.live, .{ .ready = &l });
    p.teams = .{ .{ 266, 64, 103, 222, 117 }, .{ 122, 254, 61, 51, 412 } };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, p.view(&h), &w.writer);
    const s = w.written();
    // Gold +240 clears 2 x 45 and 200; win -3.2 clears 2 x 0.61 and 3
    try testing.expect(tree.find(s, "Blue ahead at 14, Red stronger from 20") != null);
    try testing.expect(tree.find(s, "Blue +240 gold (+149 to +331)") != null);
    try testing.expect(tree.find(s, "· early") != null);
    try testing.expect(tree.find(s, "· late") != null);
    const t2 = teamLean(&Demo.full_head, .{ .{ 266, 64, 0, 0, 0 }, @splat(0) }).?;
    try testing.expectEqual(0, edge(t2.gold, t2.gold_sd, 200, 2));
    try testing.expectEqual(1, edge(t2.win, t2.win_sd, 3, 2));
    // Clear but small, and big but unclear: level
    try testing.expect(edge(150, 25, 200, 2) == null);
    try testing.expect(edge(-400, 250, 200, 2) == null);
    try testing.expectApproxEqAbs(25, t2.gold_sd, 1e-9);
    // Red alone: a pick each side needed for the line
    p.teams = .{ @splat(0), .{ 122, 0, 0, 0, 0 } };
    w.clearRetainingCapacity();
    try @import("html.zig").write(&t, p.view(&h), &w.writer);
    try testing.expect(tree.find(w.written(), "class=\"lean\"") == null);
}

test "gaps: two models' parts matched by pick or pair, adding up exactly to one chance less the other" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const Even = struct {
        pub fn patchShare(_: *const @This(), _: u32, _: usize) f64 {
            return 1;
        }
    };
    const groups = [_]ds.PairGroup{
        .{ .name = "", .kind = "ally", .r = 3, .q = 4, .sd = 0.1, .fitted = 1, .shipped = 1 },
        .{ .name = "", .kind = "matchup", .r = 0, .q = 0, .sd = 0.1, .fitted = 1, .shipped = 1 },
    };
    const ta = [_]ds.Term{
        .{ .champion = 10, .role = 0, .games = 500, .b = 0.3, .sd = 0.05 },
        .{ .champion = 11, .role = 0, .games = 400, .b = -0.3, .sd = 0.05 },
        .{ .champion = 30, .role = 3, .games = 300, .b = 0.1, .sd = 0.05 },
        .{ .champion = 40, .role = 4, .games = 200, .b = 0, .sd = 0.05 },
    };
    var tb = ta;
    tb[0].b = -0.1;
    tb[2].b = 0.4;
    // a has the duo only, b the top lane only
    const ca = [_]ds.PairCell{.{ .group = 0, .a = 30, .b = 40, .theta = 0.5, .games = 900 }};
    const cb = [_]ds.PairCell{.{ .group = 1, .a = 10, .b = 11, .theta = 0.4, .games = 800 }};
    const pa: ds.Params = .{ .kind = "ratings", .dim = 0, .intercept = &.{0.02}, .w = @splat(0), .z = @splat(0), .terms = &ta, .pairs = .{ .min_games = 0, .groups = &groups, .cells = &ca }, .temperature = 0.9 };
    var pb = pa;
    pb.intercept = &.{0.3};
    pb.terms = &tb;
    pb.pairs.?.cells = &cb;
    const sa = try ds.Scorer.init(a, pa, 0, &Even{});
    const sb = try ds.Scorer.init(a, pb, 0, &Even{});
    const teams: [2][n_role]u32 = .{ .{ 11, 0, 0, 30, 40 }, .{ 10, 0, 0, 0, 0 } };
    const da = sa.draftWhy(teams);
    const db = sb.draftWhy(teams);
    var buf: [2 * ds.max_draft_parts]Gap = undefined;
    const g = gaps(&da, &db, &buf);
    var sum = 100 * (db.empty.p - da.empty.p) + (db.comp - da.comp) + (db.rest - da.rest);
    var only_a: usize = 0;
    var only_b: usize = 0;
    for (g) |x| {
        sum += x.pp;
        only_a += @intFromBool(x.b == null);
        only_b += @intFromBool(x.a == null);
        if (x.a != null and x.b != null) try testing.expectApproxEqAbs(x.b.?.pp - x.a.?.pp, x.pp, 1e-12);
    }
    try testing.expectApproxEqAbs(100 * (db.with.p - da.with.p), sum, 1e-9);
    try testing.expect(@abs(db.with.p - da.with.p) > 0.01);
    try testing.expectEqual(1, only_a);
    try testing.expectEqual(1, only_b);
    // One model: its own parts
    const one = gaps(&da, null, &buf);
    try testing.expectEqual(da.n, one.len);
    for (one, da.parts()) |x, y| try testing.expectEqual(y.pp, x.pp);
}
