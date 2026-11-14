//! One of your games as the game page reads it (game-detail.md), and what the page works
//! out of it: moments (fights and lone epic objectives), the stat cells, the two teams'
//! totals and firsts, and a selection's summary for the inspector. The server and
//! ui-games.wasm share it, so a game picked in the strip derives the same as the first
//! render. Slots index `Game.seats`; seconds are game time
const std = @import("std");
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const data = @import("data.zig");
const timeline = @import("timeline.zig");
const art = @import("art.zig");
const fmt = @import("fmt.zig");

pub const ObjKind = enum { tower, inhibitor, dragon, elder, grubs, herald, baron, atakhan };

pub const no_slot = 255;

/// `Data.arts` index for none: an empty slot, or a summary that predates loadouts
pub const no_art = std.math.maxInt(u16);

pub const Seat = struct {
    /// Index into `Data.champs`
    champ: u16,
    /// Your team
    us: bool,
    role: ?role.Role = null,
    k: u16,
    d: u16,
    a: u16,
    /// As at the game; "" unknown
    riot_id: []const u8 = "",
    cs: u16 = 0,
    gold: u32 = 0,
    level: u8 = 0,
    damage: u32 = 0,
    taken: u32 = 0,
    /// Gold minus the lane opponent's at 14 min
    lane14: ?i32 = null,
    /// `Data.arts` indices; 6 the trinket
    items: [7]u16 = @splat(no_art),
    spells: [2]u16 = @splat(no_art),
    keystone: u16 = no_art,
    second: u16 = no_art,
    /// Null when the summary predates it
    vision: ?u16 = null,
};

pub const Kill = struct {
    t: u16,
    /// `no_slot`: a turret, minion or monster
    killer: u8,
    victim: u8,
    assists: []const u8 = &.{},
    /// Map units, blue's base at (0, 0), about 15k a side
    x: u16 = 0,
    y: u16 = 0,
    gold: u16 = 0,
    /// Kills close in time and place share one, numbered in time order
    fight: u16,
};

pub const Obj = struct { t: u16, ours: bool, kind: ObjKind, name: []const u8, you: bool = false };

pub const Best = struct { minute: u8, gold: i32 };

/// One of your purchases: `Data.arts` index
pub const Buy = struct { t: u16, item: u16 };

/// Your lane against your opponent's (api/game.zig LaneReport): index i is minute i + 1
pub const Lane = struct {
    /// You minus them
    gold: []const i16,
    xp: []const i16,
    cs: []const i16,
    /// Your CS at 10 min
    cs10: ?u16 = null,
    /// Before 14 min: kills you took part in, your deaths
    kills: u8 = 0,
    deaths: u8 = 0,
    /// Seconds, yours and theirs
    level6: [2]?u16 = .{ null, null },
    first_item: [2]?u16 = .{ null, null },
    /// Your biggest fall and rise against the typical line
    fall: ?Stretch = null,
    rise: ?Stretch = null,
    typical: ?Typical = null,

    pub const Stretch = struct { from: u8, to: u8, change: i32 };
};

/// The matchup's typical lane, minutes with enough games only
pub const Typical = struct {
    games: u32,
    /// "Gold to Emerald"; "All games" when yours was too thin
    bracket: []const u8,
    /// [p25, estimated mean, p75] from your side
    gold: []const [3]i16,
    xp: []const [3]i16,
    cs: []const [3]i16,
    /// Seconds, yours
    level6: ?u16 = null,
    first_item: ?u16 = null,
};

pub const Game = struct {
    /// "23 Oct"
    day: []const u8,
    patch: []const u8,
    /// "Ranked solo"
    queue: []const u8,
    /// Seconds
    dur: u16,
    win: bool,
    you: u8,
    seats: []const Seat,
    /// Your team's win chance in % at each minute from 0
    wc: []const u8,
    /// Your team's gold lead at each minute from 0
    gold: []const i32 = &.{},
    kills: []const Kill = &.{},
    objs: []const Obj = &.{},
    /// The minute you earned most gold
    best: ?Best = null,
    /// Yours in time order, undone ones left out
    buys: []const Buy = &.{},
    /// The ability you levelled at each level: "QWEQQR..."
    skills: []const u8 = "",
    lane: ?Lane = null,

    pub fn me(g: *const Game) Seat {
        return g.seats[g.you];
    }

    /// Your lane opponent's slot
    pub fn opponent(g: *const Game) ?u8 {
        const r = g.me().role orelse return null;
        for (g.seats, 0..) |s, i| if (!s.us and s.role == r) return @intCast(i);
        return null;
    }
};

pub const Data = struct {
    /// Every champion the games name (Seat.champ indexes it)
    champs: []const champ.Champ,
    /// Newest first
    games: []const Game,
    /// Items, summoner spells and runes the games name (Seat.items and the like index it)
    arts: []const art.Art = &.{},

    pub fn artAt(d: *const Data, i: u16) ?art.Art {
        return if (i < d.arts.len) d.arts[i] else null;
    }
};

pub const stamp = @import("tiers.zig").stamp;

/// game.html#id=Name%23TAG&game=ms: a looked-up player's game (its start_ms in the Your
/// games report), which the API answers in place of the example's; &as=slot: from that
/// seat
pub const Lookup = struct {
    /// Percent-encoded as in the fragment
    id: []const u8,
    start: i64,
    /// 0-9
    as: ?u8 = null,

    pub fn ofHash(hash: []const u8) ?Lookup {
        return Ask.of(hash).look;
    }

    pub fn api(l: Lookup, buf: []u8) ?[]const u8 {
        var w: std.Io.Writer = .fixed(buf);
        write(&w, &.{ "/api/game?id=", l.id, "&start=" }, l.start) catch return null;
        const a = l.as orelse return w.buffered();
        return withAs(buf, w.end, a);
    }

    /// #id=<id>&game=<start> after `head`
    pub fn frag(l: Lookup, buf: []u8, head: []const u8) ?[]const u8 {
        var w: std.Io.Writer = .fixed(buf);
        write(&w, &.{ head, "#id=", l.id, "&game=" }, l.start) catch return null;
        return w.buffered();
    }

    /// The fragment for the same game from `slot`
    pub fn from(l: Lookup, buf: []u8, slot: u8) ?[]const u8 {
        const f = l.frag(buf, "") orelse return null;
        return withAs(buf, f.len, slot);
    }

    /// `parts` then `n`: std's {d} costs ui-games.wasm 535 B
    fn write(w: *std.Io.Writer, parts: []const []const u8, n: i64) !void {
        for (parts) |p| try w.writeAll(p);
        try fmt.write(w, .int, n);
    }

    pub fn eql(l: Lookup, o: Lookup) bool {
        return l.start == o.start and l.as == o.as and tree.eql(l.id, o.id);
    }

    /// buf[0..n] then &as=slot
    fn withAs(buf: []u8, n: usize, slot: u8) ?[]const u8 {
        const tail = [_]u8{ '&', 'a', 's', '=', '0' + slot };
        if (n + tail.len > buf.len) return null;
        @memcpy(buf[n..][0..tail.len], &tail);
        return buf[0 .. n + tail.len];
    }
};

/// What game.html's fragment shows in place of the default role's example: a
/// looked-up player's game, else #example=<role>: that role's example, its file beside
/// the page's data-src
pub const Ask = struct {
    look: ?Lookup = null,
    /// A plain lowercase word, else null
    example: ?[]const u8 = null,

    pub fn of(hash: []const u8) Ask {
        var id: ?[]const u8 = null;
        var start: ?i64 = null;
        var as: ?u8 = null;
        var ex: ?[]const u8 = null;
        var it = std.mem.tokenizeScalar(u8, if (hash.len > 0 and hash[0] == '#') hash[1..] else hash, '&');
        while (it.next()) |kv| {
            const eq = std.mem.findScalar(u8, kv, '=') orelse continue;
            const k = kv[0..eq];
            const v = kv[eq + 1 ..];
            if (tree.eql(k, "id")) id = v;
            if (tree.eql(k, "game")) start = ms(v);
            // Slots 0-9 by hand: a second parseInt costs ui-games.wasm 250 B
            if (tree.eql(k, "as") and v.len == 1 and std.ascii.isDigit(v[0])) as = v[0] - '0';
            if (tree.eql(k, "example") and word(v)) ex = v;
        }
        if (id) |i| if (start) |s| if (i.len > 0 and std.mem.findAny(u8, i, " ?") == null) {
            return .{ .look = .{ .id = i, .start = s, .as = as } };
        };
        return .{ .example = ex };
    }

    pub fn eql(a: Ask, b: Ask) bool {
        if (a.look) |l| return b.look != null and l.eql(b.look.?);
        if (b.look != null) return false;
        const x = a.example orelse return b.example == null;
        return b.example != null and tree.eql(x, b.example.?);
    }

    /// By hand: std's parseInt(i64) costs ui-games.wasm 330 B
    fn ms(v: []const u8) ?i64 {
        if (v.len == 0 or v.len > 18) return null;
        var n: i64 = 0;
        for (v) |c| {
            if (c < '0' or c > '9') return null;
            n = n * 10 + (c - '0');
        }
        return n;
    }

    fn word(v: []const u8) bool {
        if (v.len == 0 or v.len > 12) return false;
        for (v) |c| if (c < 'a' or c > 'z') return false;
        return true;
    }
};

test Ask {
    try std.testing.expectEqualStrings("jungle", Ask.of("#example=jungle&g=2").example.?);
    try std.testing.expectEqualStrings("top", Ask.of("g=0&example=top").example.?);
    try std.testing.expectEqual(null, Ask.of("#g=2").example);
    try std.testing.expectEqual(null, Ask.of("#example=").example);
    try std.testing.expectEqual(null, Ask.of("#example=../x").example);
    // A lookup wins
    const l = Ask.of("#example=top&id=A%231&game=5");
    try std.testing.expectEqual(null, l.example);
    try std.testing.expect(l.look != null);
    try std.testing.expect(Ask.of("#example=top&g=1").eql(Ask.of("#g=4&example=top")));
    try std.testing.expect(!Ask.of("#example=top").eql(Ask.of("#example=mid")));
    try std.testing.expect(!Ask.of("#example=top").eql(.{}));
    try std.testing.expect(!l.eql(Ask.of("#example=top")));
}

/// Purchases this close to the one before are the same shop visit
pub const back_gap_s = 45;

/// Your purchases split by shop visit: each is `buys[from..to]`
pub fn backs(a: std.mem.Allocator, buys: []const Buy) ![][2]u16 {
    var out: std.ArrayList([2]u16) = .empty;
    for (buys, 0..) |b, i| {
        if (i == 0 or b.t > buys[i - 1].t + back_gap_s) try out.append(a, .{ @intCast(i), @intCast(i) });
        out.items[out.items.len - 1][1] = @intCast(i + 1);
    }
    return out.toOwnedSlice(a);
}

/// A moment: a fight, or an epic objective away from any fight
pub const Moment = struct {
    t: u16,
    end: u16,
    /// Enemies and allies that died
    us: u8 = 0,
    them: u8 = 0,
    /// The fight's number (Kill.fight); null for an objective alone
    fight: ?u16 = null,
    /// The objective alone (Game.objs index)
    obj: ?u16 = null,
    /// You killed, helped or died
    you: bool = false,
    died: bool = false,
    /// Kill gold to your team minus to theirs
    gold: i32 = 0,
    /// Objectives taken during it or within `after_s` of its end
    objs: bool = false,
};

/// An objective this soon after a fight is that fight's outcome
pub const after_s = 60;

fn epic(k: ObjKind) bool {
    return switch (k) {
        .tower, .inhibitor => false,
        else => true,
    };
}

fn involved(k: Kill, slot: u8) bool {
    return k.killer == slot or std.mem.findScalar(u8, k.assists, slot) != null;
}

/// In time order
pub fn moments(a: std.mem.Allocator, g: *const Game) ![]Moment {
    var out: std.ArrayList(Moment) = .empty;
    var nf: usize = 0;
    for (g.kills) |k| nf = @max(nf, @as(usize, k.fight) + 1);
    try out.ensureTotalCapacity(a, nf + g.objs.len);
    for (0..nf) |_| out.appendAssumeCapacity(.{ .t = std.math.maxInt(u16), .end = 0 });
    for (g.kills) |k| {
        const m = &out.items[k.fight];
        m.fight = k.fight;
        m.t = @min(m.t, k.t);
        m.end = @max(m.end, k.t);
        const ours = g.seats[k.victim].us;
        if (ours) m.them += 1 else m.us += 1;
        m.gold += if (ours) -@as(i32, k.gold) else k.gold;
        m.you = m.you or k.victim == g.you or involved(k, g.you);
        m.died = m.died or k.victim == g.you;
    }
    for (g.objs, 0..) |o, i| {
        const in_fight = for (out.items[0..nf]) |*m| {
            if (o.t >= m.t and o.t <= m.end + after_s) break m;
        } else null;
        if (in_fight) |m| {
            m.objs = true;
            continue;
        }
        if (!epic(o.kind)) continue;
        // Voidgrubs a few seconds apart are one moment
        if (out.items.len > nf) {
            const last = &out.items[out.items.len - 1];
            const lo = g.objs[last.obj.?];
            if (lo.kind == o.kind and lo.ours == o.ours and o.t <= last.end + after_s) {
                last.end = o.t;
                last.you = last.you or o.you;
                continue;
            }
        }
        out.appendAssumeCapacity(.{ .t = o.t, .end = o.t, .obj = @intCast(i), .you = o.you, .objs = true });
    }
    // Insertion: a few dozen moments, and std.mem.sort's block sort costs ~3.5 KB gz
    std.sort.insertion(Moment, out.items, {}, struct {
        fn earlier(_: void, x: Moment, y: Moment) bool {
            return x.t < y.t;
        }
    }.earlier);
    return out.toOwnedSlice(a);
}

/// A one-minute move of the win chance, between minute - 1 and minute
pub const Move = struct { minute: u8, from: u8, to: u8 };

/// The biggest one-minute move (the turn), and the biggest the other way
pub fn turns(wc: []const u8) struct { ?Move, ?Move } {
    var turn: ?Move = null;
    for (1..wc.len) |i| {
        const m: Move = .{ .minute = @intCast(i), .from = wc[i - 1], .to = wc[i] };
        if (turn == null or size(m) > size(turn.?)) turn = m;
    }
    const t = turn orelse return .{ null, null };
    var other: ?Move = null;
    for (1..wc.len) |i| {
        const m: Move = .{ .minute = @intCast(i), .from = wc[i - 1], .to = wc[i] };
        if ((signed(m) > 0) == (signed(t) > 0) or signed(m) == 0) continue;
        if (other == null or size(m) > size(other.?)) other = m;
    }
    return .{ t, other };
}

pub fn signed(m: Move) i16 {
    return @as(i16, m.to) - m.from;
}

fn size(m: Move) u16 {
    return @abs(signed(m));
}

pub const Extreme = struct { minute: u8, v: u8 };

pub const Swings = struct {
    turn: ?Move,
    other: ?Move,
    peak: ?Extreme,
    low: ?Extreme,
    /// The longest unbroken run of minutes over 50%, as its last minute (`Move.minute`'s
    /// sense: minute m is m - 1 to m) and length
    lead: Run = .{},
};

pub const Run = struct { end: u8 = 0, len: u8 = 0 };

pub fn swings(g: *const Game) Swings {
    const turn, const other = turns(g.wc);
    var s: Swings = .{ .turn = turn, .other = other, .peak = null, .low = null };
    var run: u8 = 0;
    // 0:00 is the draft, before anything happened: not a peak, low or lead
    for (g.wc[@min(1, g.wc.len)..], 1..) |v, i| {
        const m: u8 = @intCast(i);
        if (s.peak == null or v > s.peak.?.v) s.peak = .{ .minute = m, .v = v };
        if (s.low == null or v < s.low.?.v) s.low = .{ .minute = m, .v = v };
        run = if (v > 50) run + 1 else 0;
        if (run > s.lead.len) s.lead = .{ .end = m, .len = run };
    }
    return s;
}

/// The fight with most deaths, the bigger gold swing on a tie; null under two deaths
pub fn biggestFight(ms: []const Moment) ?u8 {
    var best: ?u8 = null;
    for (ms, 0..) |m, i| {
        if (m.fight == null or m.us + m.them < 2) continue;
        if (best) |b| {
            const o = ms[b];
            const n = m.us + m.them;
            if (n < o.us + o.them or (n == o.us + o.them and @abs(m.gold) <= @abs(o.gold))) continue;
        }
        best = @intCast(i);
    }
    return best;
}

/// One objective kind's count per side and who took the first
pub const Tally = struct { us: u16 = 0, them: u16 = 0, first: ?First = null };
pub const First = struct { t: u16, ours: bool };

pub const Teams = struct {
    kills: Tally = .{},
    gold: [2]u32 = .{ 0, 0 },
    towers: Tally = .{},
    dragons: Tally = .{},
    grubs: Tally = .{},
    herald: Tally = .{},
    baron: Tally = .{},
    inhibitors: Tally = .{},
};

fn add(t: *Tally, ours: bool, at: u16) void {
    if (ours) t.us += 1 else t.them += 1;
    if (t.first == null) t.first = .{ .t = at, .ours = ours };
}

pub fn teams(g: *const Game) Teams {
    var out: Teams = .{};
    for (g.seats) |s| out.gold[@intFromBool(!s.us)] += s.gold;
    for (g.kills) |k| add(&out.kills, !g.seats[k.victim].us, k.t);
    for (g.objs) |o| add(switch (o.kind) {
        .tower => &out.towers,
        .inhibitor => &out.inhibitors,
        .dragon, .elder => &out.dragons,
        .grubs => &out.grubs,
        .herald => &out.herald,
        .baron => &out.baron,
        // One a game at most, folded in with Baron's side of the map
        .atakhan => continue,
    }, o.ours, o.t);
    return out;
}

/// Seconds a..b, both ends in
pub const Span = struct { a: u16, b: u16 };

pub fn minuteSpan(minute: u8) Span {
    const m: u16 = minute;
    return .{ .a = (m -| 1) * 60, .b = m * 60 };
}

/// Per seat, what it did in a selection
pub const SeatIn = struct { k: u8 = 0, d: u8 = 0, a: u8 = 0, gold: u16 = 0 };

pub const Summary = struct {
    span: Span,
    /// Win chance and gold lead at the minute before and after
    wc: [2]u8,
    gold: ?[2]i32,
    /// Enemies and allies that died
    us: u8 = 0,
    them: u8 = 0,
    seats: [10]SeatIn = @splat(.{}),
    /// Game.objs indexes, in time order
    objs: [16]u16 = undefined,
    n_objs: u8 = 0,
};

/// The minute frame at or before `s`, and the one at or after `e`
fn frames(len: usize, s: Span) [2]usize {
    const last = len -| 1;
    return .{ @min(last, s.a / 60), @min(last, (s.b + 59) / 60) };
}

pub fn summary(g: *const Game, s: Span) Summary {
    const f = frames(g.wc.len, s);
    var out: Summary = .{
        .span = s,
        .wc = if (g.wc.len > 0) .{ g.wc[f[0]], g.wc[f[1]] } else .{ 50, 50 },
        .gold = if (g.gold.len == g.wc.len and g.gold.len > 0) .{ g.gold[f[0]], g.gold[f[1]] } else null,
    };
    for (g.kills) |k| {
        if (k.t < s.a or k.t > s.b) continue;
        if (g.seats[k.victim].us) out.them += 1 else out.us += 1;
        if (k.victim < out.seats.len) out.seats[k.victim].d +|= 1;
        if (k.killer < out.seats.len) {
            out.seats[k.killer].k +|= 1;
            out.seats[k.killer].gold +|= k.gold;
        }
        for (k.assists) |x| if (x < out.seats.len) {
            out.seats[x].a +|= 1;
        };
    }
    for (g.objs, 0..) |o, i| {
        if (o.t < s.a or o.t > s.b + after_s or out.n_objs == out.objs.len) continue;
        // After the span only as its fight's outcome: a lone objective must be inside
        if (o.t > s.b and !afterFight(g, s, o.t)) continue;
        out.objs[out.n_objs] = @intCast(i);
        out.n_objs += 1;
    }
    return out;
}

fn afterFight(g: *const Game, s: Span, t: u16) bool {
    var last: ?u16 = null;
    for (g.kills) |k| if (k.t >= s.a and k.t <= s.b) {
        last = @max(last orelse 0, k.t);
    };
    return if (last) |l| t <= l + after_s else false;
}

pub fn momentSpan(m: Moment) Span {
    return .{ .a = m.t, .b = m.end };
}

/// The game as TimelineChart draws it, its moments parallel to `ms`
pub fn chart(a: std.mem.Allocator, g: *const Game, champs: []const champ.Champ, ms: []const Moment) !timeline.Game {
    const wc = try a.alloc(f32, g.wc.len);
    for (g.wc, wc) |v, *o| o.* = @floatFromInt(v);
    const gold = try a.alloc(f32, g.gold.len);
    for (g.gold, gold) |v, *o| o.* = @floatFromInt(v);
    const tms = try a.alloc(timeline.Moment, ms.len);
    for (ms, tms) |m, *o| o.* = .{ .t = m.t, .us = m.us, .them = m.them, .objective = m.obj != null };
    const objs = try a.alloc(timeline.Objective, g.objs.len);
    for (g.objs, objs) |o, *x| x.* = .{ .t = o.t, .ours = o.ours, .name = o.name, .kind = switch (o.kind) {
        .tower => .tower,
        .inhibitor => .inhib,
        .dragon, .elder => .dragon,
        .grubs => .grubs,
        .herald => .herald,
        .baron, .atakhan => .baron,
    } };
    const deaths = try a.alloc(timeline.Death, g.kills.len);
    for (g.kills, deaths) |k, *d| d.* = .{ .t = k.t, .ours = g.seats[k.victim].us, .champ = champs[g.seats[k.victim].champ], .you = k.victim == g.you };
    const turn, _ = turns(g.wc);
    return .{
        .dur = g.dur,
        .wc = wc,
        .gold = gold,
        .turn = if (turn) |t| t.minute else null,
        .moments = tms,
        .objectives = objs,
        .deaths = deaths,
    };
}

/// The fixture: a short made-up game, each case once
pub const demo: Game = .{
    .day = "23 Oct",
    .patch = "16.21",
    .queue = "Ranked solo",
    .dur = 600,
    .win = true,
    .you = 2,
    .seats = &.{
        .{ .champ = 0, .us = true, .role = .top, .k = 0, .d = 1, .a = 0, .gold = 3000 },
        .{ .champ = 1, .us = true, .role = .jungle, .k = 1, .d = 0, .a = 1, .gold = 3500 },
        .{ .champ = 2, .us = true, .role = .mid, .k = 1, .d = 0, .a = 1, .gold = 4000 },
        .{ .champ = 3, .us = false, .role = .mid, .k = 1, .d = 1, .a = 0, .gold = 3200 },
        .{ .champ = 4, .us = false, .role = .top, .k = 0, .d = 1, .a = 0, .gold = 2800 },
    },
    .wc = &.{ 50, 48, 46, 40, 44, 70, 72, 71, 80, 85, 90 },
    .gold = &.{ 0, -100, -200, -600, -400, 500, 600, 600, 900, 1200, 1500 },
    .kills = &.{
        .{ .t = 170, .killer = 3, .victim = 0, .gold = 400, .fight = 0 },
        .{ .t = 250, .killer = 2, .victim = 3, .assists = &.{1}, .gold = 300, .fight = 1 },
        .{ .t = 262, .killer = 1, .victim = 4, .assists = &.{2}, .gold = 300, .fight = 1 },
    },
    .objs = &.{
        .{ .t = 290, .ours = true, .kind = .dragon, .name = "Infernal dragon", .you = true },
        .{ .t = 400, .ours = true, .kind = .grubs, .name = "Voidgrub" },
        .{ .t = 410, .ours = true, .kind = .grubs, .name = "Voidgrub" },
        .{ .t = 500, .ours = false, .kind = .tower, .name = "Top outer tower" },
    },
    .best = .{ .minute = 5, .gold = 900 },
};

const testing = std.testing;

test "moments: fights by number, objectives after a fight fold in, grubs fold" {
    const ms = try moments(testing.allocator, &demo);
    defer testing.allocator.free(ms);
    try testing.expectEqual(@as(usize, 3), ms.len);
    try testing.expectEqual(@as(u16, 170), ms[0].t);
    try testing.expect(ms[0].them == 1 and ms[0].us == 0 and !ms[0].you and ms[0].gold == -400);
    try testing.expect(ms[1].us == 2 and ms[1].you and !ms[1].died and ms[1].objs and ms[1].end == 262);
    // The two grubs are one moment; the tower is nobody's moment
    try testing.expectEqual(@as(?u16, 1), ms[2].obj);
    try testing.expectEqual(@as(u16, 410), ms[2].end);
}

test "turns: the biggest move and the biggest the other way" {
    const t, const o = turns(demo.wc);
    try testing.expectEqual(@as(u8, 5), t.?.minute);
    try testing.expectEqual(@as(i16, 26), signed(t.?));
    try testing.expectEqual(@as(u8, 3), o.?.minute);
    const none = turns(&.{ 50, 60, 70 });
    try testing.expect(none[1] == null);
    const s = swings(&demo);
    try testing.expectEqual(@as(u8, 90), s.peak.?.v);
    try testing.expectEqual(@as(u8, 3), s.low.?.minute);
    try testing.expectEqual(Run{ .end = 10, .len = 6 }, s.lead);
    // A run broken at 50 restarts; the start's 60% is the draft, neither lead nor peak
    const g: Game = .{ .day = "", .patch = "", .queue = "", .dur = 360, .win = false, .you = 0, .seats = &.{}, .wc = &.{ 60, 55, 56, 50, 51, 52, 53 } };
    const b = swings(&g);
    try testing.expectEqual(Run{ .end = 6, .len = 3 }, b.lead);
    try testing.expectEqual(Extreme{ .minute = 3, .v = 50 }, b.low.?);
    try testing.expectEqual(Extreme{ .minute = 2, .v = 56 }, swings(&.{ .day = "", .patch = "", .queue = "", .dur = 120, .win = false, .you = 0, .seats = &.{}, .wc = &.{ 60, 55, 56 } }).peak.?);
}

test "biggestFight: most deaths, a lone kill is no fight" {
    const ms = try moments(testing.allocator, &demo);
    defer testing.allocator.free(ms);
    try testing.expectEqual(@as(?u8, 1), biggestFight(ms));
    try testing.expectEqual(@as(?u8, null), biggestFight(ms[0..1]));
    const tie = [_]Moment{ .{ .t = 0, .end = 0, .us = 1, .them = 1, .fight = 0, .gold = 100 }, .{ .t = 9, .end = 9, .us = 0, .them = 2, .fight = 1, .gold = -600 }, .{ .t = 20, .end = 20, .us = 2, .fight = 2, .gold = 600 } };
    try testing.expectEqual(@as(?u8, 1), biggestFight(&tie));
}

test "teams count each side and the firsts" {
    const t = teams(&demo);
    try testing.expectEqual(Tally{ .us = 2, .them = 1, .first = .{ .t = 170, .ours = false } }, t.kills);
    try testing.expectEqual(@as(u16, 2), t.grubs.us);
    try testing.expect(!t.towers.first.?.ours);
    try testing.expectEqual([2]u32{ 10500, 6000 }, t.gold);
}

test "a summary takes the span's kills and its fight's objectives" {
    const s = summary(&demo, .{ .a = 240, .b = 270 });
    try testing.expectEqual([2]u8{ 44, 70 }, s.wc);
    try testing.expectEqual([2]i32{ -400, 500 }, s.gold.?);
    try testing.expect(s.us == 2 and s.them == 0);
    try testing.expectEqual(SeatIn{ .k = 1, .a = 1, .gold = 300 }, s.seats[2]);
    try testing.expectEqual(@as(u8, 1), s.seats[3].d);
    // The dragon 28 s after the fight is its outcome
    try testing.expectEqual(@as(u8, 1), s.n_objs);
    // A span with no fight takes no objective past its end
    try testing.expectEqual(@as(u8, 0), summary(&demo, .{ .a = 300, .b = 390 }).n_objs);
    try testing.expectEqual(Span{ .a = 240, .b = 300 }, minuteSpan(5));
}

test "data round trip" {
    const d: Data = .{ .champs = &.{champ.demo("Ahri", "Ahri")}, .games = &.{demo} };
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(testing.allocator);
    try data.encode(testing.allocator, Data, d, &bytes);
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const back = try data.decode(arena.allocator(), Data, bytes.items);
    try testing.expectEqual(demo.kills.len, back.games[0].kills.len);
    try testing.expectEqualStrings("Top outer tower", back.games[0].objs[3].name);
}

test "backs: purchases split where the gap passes 45 s" {
    const buys = [_]Buy{ .{ .t = 0, .item = 1 }, .{ .t = 2, .item = 2 }, .{ .t = 400, .item = 3 }, .{ .t = 440, .item = 4 }, .{ .t = 900, .item = 5 } };
    const b = try backs(std.testing.allocator, &buys);
    defer std.testing.allocator.free(b);
    try std.testing.expectEqualSlices([2]u16, &.{ .{ 0, 2 }, .{ 2, 4 }, .{ 4, 5 } }, b);
}

test "lookup: a looked-up game's fragment as its API call" {
    var buf: [128]u8 = undefined;
    const l = Lookup.ofHash("#m=300&id=Hide%20on%20bush%23KR1&game=1791720000000").?;
    try std.testing.expectEqualStrings("/api/game?id=Hide%20on%20bush%23KR1&start=1791720000000", l.api(&buf).?);
    const as = Lookup.ofHash("#id=A%231&game=5&as=3&g=0").?;
    try std.testing.expectEqualStrings("/api/game?id=A%231&start=5&as=3", as.api(&buf).?);
    try std.testing.expectEqualStrings("#id=A%231&game=5&as=7", as.from(&buf, 7).?);
    try std.testing.expect(!as.eql(l) and as.eql(Lookup.ofHash("#as=3&game=5&id=A%231").?));
    try std.testing.expectEqual(null, Lookup.ofHash("#g=2"));
    try std.testing.expectEqual(null, Lookup.ofHash("#id=A%231"));
    try std.testing.expectEqual(null, Lookup.ofHash("#id=A%231&game=x"));
    try std.testing.expectEqual(null, Lookup.ofHash("#id=&game=1"));
}
