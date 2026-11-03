//! Picks: the app's Options panel in champ select (docs/plan/ui/app-options.md), its own
//! island (ui-picks.wasm, picks.bin): ui-app.wasm has no room. The champions played in
//! the lane panel's role as a CandidateList, each with its effects (the role, an ally
//! pair, an enemy matchup) as the other champion's icon and its points, a click opens
//! the ReasonBreakdown. The private edition: 20 rows with numbers; the public one: 5 more
//! past the lane panel's own, words mode (product rules: 3 to 5, no numbers). The shell
//! renders it after the app's island and keeps its Data at picks.bin (src/shell/screens.zig)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const candlist = @import("candlist.zig");
const reasons = @import("reasons.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "Picks";
pub const scope = .{".c-picks"};
pub const sel = "[data-island=picks]";

pub const Data = struct {
    /// The shell's count of changes, as app.Data's
    seq: u32,
    /// Private edition: points and win chances
    private: bool,
    role: role.Role,
    /// The lane opponent's name, for the gold column; "" none
    them: []const u8 = "",
    rows: []const Row,
    /// "EUW, last 30 days"
    scope: []const u8 = "",
};

pub const Row = struct {
    champ: champ.Champ,
    /// 1 = the recommender's first among every champion in the role
    rank: u32,
    /// My team's win chance with it, %; and with an average champion here (the
    /// breakdown's start). Private only
    win: ?f32 = null,
    base: f32 = 50,
    /// Gold at 14 min against the lane opponent; private only
    gold: ?f32 = null,
    /// One of the player's most-played champions
    pool: bool = false,
    /// Their hover or lock
    current: bool = false,
    effects: []const Effect = &.{},
    /// The points the effects leave (smaller pairs summed); private only
    rest: f32 = 0,
    /// Practice's click (ui/practice.zig Act); "" for none
    act: []const u8 = "",
    /// Most picked in the role, no win rates (learned.md: what you set doesn't
    /// detectably change your chance): keystone and second tree ("Electrocute +
    /// Sorcery") and summoners ("Flash, Ignite"); "" unknown. Shown in the open row
    runes: []const u8 = "",
    spells: []const u8 = "",
    /// Their share of the champion's games in the role, %; private only
    runes_pct: ?f32 = null,
    spells_pct: ?f32 = null,
};

pub const Kind = enum { strength, with, into };

pub const Effect = struct {
    kind: Kind,
    /// The other champion; null for strength in the role
    other: ?champ.Champ = null,
    /// Points it gives my team; the public edition only its sign (+1, -1)
    pp: f32,
    games: u32 = 0,
};

pub const Picks = struct {
    data: Data,
    /// Rows open to their breakdown, by rank (0 none)
    open: [2]u32 = .{ 0, 0 },

    pub const Msg = union(enum) { open: u32 };

    pub fn update(p: *Picks, m: Msg, _: *tree.Event) void {
        switch (m) {
            .open => |r| if (p.open[0] == r) {
                p.open = .{ p.open[1], 0 };
            } else if (p.open[1] == r) {
                p.open[1] = 0;
            } else {
                p.open = .{ r, p.open[0] };
            },
        }
    }

    pub fn view(p: *Picks, h: *H) N {
        const d = p.data;
        const attrs = .{ .class = "c-picks", .data_island = "picks", .data_seq = d.seq };
        const rows = h.mem.alloc(candlist.Row, d.rows.len) catch {
            h.oom = true;
            return .none;
        };
        const mode: candlist.Mode = if (d.private) .points else .words;
        const ref: ?f32 = for (d.rows) |r| {
            if (r.current) break r.win;
        } else null;
        for (rows, d.rows) |*o, r| o.* = p.row(h, d, r, ref, mode);
        return h.section(attrs, .{
            h.div(.{ .class = "hd" }, .{
                h.h3(.{}, .{if (d.private) W.all.with(h, .{ .r = d.role.label().s }) else W.more.with(h, .{ .r = d.role.label().s })}),
                if (d.scope.len > 0) h.span(.{ .class = "scope" }, .{d.scope}) else null,
            }),
            candlist.view(h, .{
                .rows = rows,
                .mode = mode,
                .head = if (d.private) .{ W.team, W.with_, if (ref != null) W.vs_yours else W.vs_first } else null,
                .ref_label = W.yours,
                .extra = if (d.private and d.them.len > 0) .{ .head = W.gold_h, .cuts = gold_cuts } else null,
            }),
        });
    }

    fn row(p: *Picks, h: *H, d: Data, r: Row, ref: ?f32, mode: candlist.Mode) candlist.Row {
        const chips = h.mem.alloc(candlist.Reason, r.effects.len) catch {
            h.oom = true;
            return .{ .champ = r.champ };
        };
        for (chips, r.effects) |*c, e| c.* = .{
            .pp = e.pp,
            .text = label(h, d.role, e, false),
            .pic = if (e.other) |o|
                champ.view(h, o, .{ .px = .@"20", .side = if (e.kind == .with) .us else .them, .named = false })
            else
                role.view(h, d.role, .{ .s = .s, .named = false }),
        };
        const open = p.open[0] == r.rank or p.open[1] == r.rank;
        const first = if (d.rows.len > 0) d.rows[0].win else null;
        const against = ref orelse first;
        return .{
            .champ = r.champ,
            .rank = r.rank,
            .ref = r.current,
            .win = r.win,
            .vs = if (r.current) null else if (r.win) |w| if (against) |a| w - a else null else null,
            .x = r.gold,
            .reasons = chips,
            .mark = if (r.pool and !r.current) W.pool else null,
            .open = open,
            .detail = if (open) breakdown(h, d, r, mode) else null,
            .note = if (open) build(h, r) else null,
            .label = W.why.with(h, .{ .n = r.champ.name }),
            .on = if (r.act.len > 0) null else h.on(p, .{ .open = r.rank }),
            .act = r.act,
        };
    }
};

fn label(h: *H, r: role.Role, e: Effect, head: bool) tree.Text {
    const n = if (e.other) |o| o.name else "?";
    return switch (e.kind) {
        .strength => W.strength.with(h, .{ .r = r.label().s }),
        .with => if (head) W.with.with(h, .{ .n = n }) else W.with_l.with(h, .{ .n = n }),
        .into => if (head) W.into.with(h, .{ .n = n }) else W.into_l.with(h, .{ .n = n }),
    };
}

fn breakdown(h: *H, d: Data, r: Row, mode: candlist.Mode) reasons.Breakdown {
    const terms = h.mem.alloc(reasons.Term, r.effects.len) catch {
        h.oom = true;
        return .{ .base_label = W.average, .base = r.base, .terms = &.{}, .total_label = W.average };
    };
    for (terms, r.effects) |*t, e| t.* = .{ .label = label(h, d.role, e, true), .pp = e.pp, .games = if (mode == .points) e.games else null };
    return .{
        .base_label = W.avg_role.with(h, .{ .r = d.role.label().s }),
        .base = r.base,
        .terms = terms,
        .rest = if (mode == .points and r.rest != 0) r.rest else null,
        .total_label = W.with_you.with(h, .{ .n = r.champ.name }),
    };
}

/// "Most picked: Electrocute + Sorcery (58%), Flash, Ignite (91%)"
fn build(h: *H, r: Row) ?tree.Text {
    if (r.runes.len == 0 and r.spells.len == 0) return null;
    const runes = if (r.runes_pct) |p| W.pct.with(h, .{ .t = r.runes, .p = p }).s else r.runes;
    const spells = if (r.spells_pct) |p| W.pct.with(h, .{ .t = r.spells, .p = p }).s else r.spells;
    if (r.runes.len == 0) return W.picked.with(h, .{ .x = spells });
    if (r.spells.len == 0) return W.picked.with(h, .{ .x = runes });
    return W.picked2.with(h, .{ .x = runes, .y = spells });
}

const gold_cuts: [4]f32 = .{ 50, 150, 300, 500 };

const W = struct {
    const all = Phrase("Every {r:text} option");
    const more = Phrase("More {r:text} options");
    const team = plain("Team win");
    const with_ = plain("with");
    const vs_yours = plain("vs yours");
    const vs_first = plain("vs first");
    const yours = plain("yours");
    const pool = plain("pool");
    const gold_h = plain("gold 14");
    const why = Phrase("Why {n:text}");
    const strength = Phrase("{r:text} strength");
    const into_l = Phrase("into {n:text}");
    const with_l = Phrase("with {n:text}");
    const into = Phrase("Into {n:text}");
    const with = Phrase("With {n:text}");
    const average = plain("Average pick");
    const avg_role = Phrase("Average {r:text} pick");
    const with_you = Phrase("Your team with {n:text}");
    const picked = Phrase("Most picked: {x:text}");
    const picked2 = Phrase("Most picked: {x:text}, {y:text}");
    const pct = Phrase("{t:text} ({p:rate})");
};

pub const css =
    \\@layer components {
    \\  .c-picks { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; padding: 0 var(--sp-4) var(--sp-4); }
    \\  .c-picks > .hd { display: flex; align-items: baseline; justify-content: space-between; gap: var(--sp-2); flex-wrap: wrap; }
    \\  .c-picks h3 { margin: 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-picks .scope { font-size: var(--fs-xs); color: var(--faint); }
    \\}
    \\
;

pub const sample: Data = .{
    .seq = 1,
    .private = true,
    .role = .mid,
    .them = "Syndra",
    .scope = "EUW, last 30 days",
    .rows = &.{
        .{ .champ = champ.demo("Galio", "Galio"), .rank = 1, .win = 54.1, .base = 50.4, .gold = -40, .pool = true, .rest = 0.4, .runes = "Aftershock + Sorcery", .spells = "Flash, Teleport", .runes_pct = 61, .spells_pct = 88, .effects = &.{
            .{ .kind = .into, .other = champ.demo("Syndra", "Syndra"), .pp = 1.6, .games = 1840 },
            .{ .kind = .with, .other = champ.demo("JarvanIV", "Jarvan IV"), .pp = 0.9, .games = 620 },
            .{ .kind = .strength, .pp = 0.8, .games = 21_400 },
        } },
        .{ .champ = champ.demo("Ahri", "Ahri"), .rank = 2, .win = 52.1, .base = 50.4, .gold = -150, .current = true, .pool = true, .effects = &.{
            .{ .kind = .strength, .pp = 1.0, .games = 25_551 },
            .{ .kind = .into, .other = champ.demo("Syndra", "Syndra"), .pp = 0.3, .games = 2210 },
            .{ .kind = .with, .other = champ.demo("Darius", "Darius"), .pp = 0.4, .games = 410 },
        } },
        .{ .champ = champ.demo("Orianna", "Orianna"), .rank = 3, .win = 51.6, .base = 50.4, .gold = 210, .effects = &.{
            .{ .kind = .into, .other = champ.demo("Zed", "Zed"), .pp = -0.6, .games = 980 },
            .{ .kind = .with, .other = champ.demo("JarvanIV", "Jarvan IV"), .pp = 1.2, .games = 540 },
        } },
    },
};

/// The public edition's: words, no numbers
pub fn public(h: *H, d: Data) Data {
    var x = d;
    x.private = false;
    const rows = h.mem.alloc(Row, d.rows.len) catch return d;
    for (rows, d.rows) |*o, r| {
        o.* = r;
        o.win = null;
        o.gold = null;
        o.rest = 0;
        o.runes_pct = null;
        o.spells_pct = null;
        const es = h.mem.alloc(Effect, r.effects.len) catch return d;
        for (es, r.effects) |*e, f| e.* = .{ .kind = f.kind, .other = f.other, .pp = if (f.pp > 0) 1 else -1 };
        o.effects = es;
    }
    x.rows = rows;
    return x;
}

pub fn page(h: *H, d: Data, open: u32) N {
    const p = h.mem.create(Picks) catch {
        h.oom = true;
        return .none;
    };
    p.* = .{ .data = d, .open = .{ open, 0 } };
    return p.view(h);
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("private, one open", page(h, sample, 1));
    g.addFill("public, words", page(h, public(h, sample), 2));
}
