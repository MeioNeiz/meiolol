//! ProfileSummary: beside the Your games list (your-games.md "Structure"), what the
//! filtered games add up to: a win ring with the record and KDA, the top champions with
//! W-L and a win bar, a column per role sized by games. Pressing a champion or a role
//! sets the list's filter (pressed again: All); the rows ignore their own part of the
//! filter so the choices stay. Phones: the ring and the top 3 champions in one line
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const kda = @import("kda.zig");
const yl = @import("yourlist.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "ProfileSummary";
pub const scope = .{".c-psum"};

/// Champion rows shown; fewer games than `thin` greys a row
const top = 5;
const thin = 3;

const W = struct {
    pub const label = plain("Summary of the games shown");
    pub const rate = phrase.Phrase("{p:pct}");
    pub const wl = phrase.Phrase("{w:int}–{l:int}");
    pub const games = phrase.Phrase("{n:count} games");
    pub const champions = plain("Champions");
    pub const roles = plain("Roles");
    pub const role_tip = phrase.Phrase("{r:text}: {n:count} games, {w:int}–{l:int}");
    pub const champ_tip = phrase.Phrase("{c:text}: {n:count} games, {w:int}–{l:int}");
    pub const none = plain("No games");
};

pub const ProfileSummary = struct {
    filter: yl.Filter = .{},
    /// Called after a press changed `filter`
    on_change: ?tree.Handler = null,

    const S = @This();

    pub const Msg = union(enum) { champ: u16, role: Role };

    pub fn update(s: *S, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .champ => |c| s.filter.champ = if (s.filter.champ == c) null else c,
            .role => |r| s.filter.role = if (s.filter.role == r) null else r,
        }
        ev.push = true;
        if (s.on_change) |hd| hd.call(hd.target, &hd.msg, ev);
    }

    /// `games` newest first (List.games or a slice of it)
    pub fn view(s: *S, h: *H, l: *const yl.List, games: []const yl.Game) N {
        const t = yl.totals(games, s.filter);
        const champs = yl.byChamp(h.mem, games, s.filter) catch {
            h.oom = true;
            return .none;
        };
        const roles = yl.byRole(games, s.filter);
        var most: u16 = 1;
        for (roles) |r| most = @max(most, r.games);

        var rows = h.list();
        for (champs[0..@min(champs.len, top)], 0..) |c, i| rows.add(s.champRow(h, l, c, i < 3));
        var cols = h.list();
        for (Role.all) |r| {
            const rt = roles[@backingInt(r)];
            const pct: u32 = if (rt.games > 0) @as(u32, rt.wins) * 100 / rt.games else 50;
            cols.add(h.button(.{
                .type = "button",
                .class = "col",
                .disabled = rt.games == 0 and s.filter.role != r,
                .aria_pressed = s.filter.role == r,
                .title = W.role_tip.with(h, .{ .r = r.label().s, .n = rt.games, .w = rt.wins, .l = rt.losses() }),
                .on_click = h.on(s, .{ .role = r }),
            }, .{
                h.span(.{ .class = "fill", .style = h.vars(.{ .h = @as(u32, rt.games) * 100 / most, .c = fmt.wrColour(@as(f64, @floatFromInt(pct)) / 100, 0.25) }) }, .{}),
                role.view(h, r, .{}),
                h.span(.{ .class = "n" }, .{rt.games}),
            }));
        }
        const p: u32 = if (t.games > 0) @as(u32, t.wins) * 100 / t.games else 0;
        return h.section(.{ .class = "c-psum", .aria_label = W.label }, .{
            h.div(.{ .class = "head" }, .{
                h.div(.{ .class = "ring", .style = h.vars(.{ .p = p }), .data_none = t.games == 0 }, .{
                    h.b(.{}, .{if (t.games > 0) W.rate.with(h, .{ .p = p }) else W.none}),
                }),
                h.div(.{ .class = "rec" }, .{
                    h.b(.{}, .{W.wl.with(h, .{ .w = t.wins, .l = t.losses() })}),
                    kda.view(h, .{ .k = avg(t.k, t.games), .d = avg(t.d, t.games), .a = avg(t.a, t.games) }, .{}),
                    h.small(.{}, .{W.games.with(h, .{ .n = t.games })}),
                }),
            }),
            if (champs.len > 0) h.div(.{ .class = "champs", .role = "group", .aria_label = W.champions }, .{rows.done()}) else null,
            h.div(.{ .class = "roles", .role = "group", .aria_label = W.roles }, .{cols.done()}),
        });
    }

    fn champRow(s: *S, h: *H, l: *const yl.List, c: yl.ChampTotals, phone: bool) N {
        const ch = if (c.champ < l.champs.len) l.champs[c.champ] else champ.Champ{ .name = "", .src = "" };
        const pct: u32 = @as(u32, c.t.wins) * 100 / @max(c.t.games, 1);
        return h.button(.{
            .type = "button",
            .class = "row",
            .aria_pressed = s.filter.champ == c.champ,
            .data_state = if (c.t.games < thin) "thin" else null,
            .data_top = phone,
            .title = W.champ_tip.with(h, .{ .c = ch.name, .n = c.t.games, .w = c.t.wins, .l = c.t.losses() }),
            .on_click = h.on(s, .{ .champ = c.champ }),
        }, .{
            champ.view(h, ch, .{ .px = .@"24", .named = true }),
            h.span(.{ .class = "wl" }, .{
                W.wl.with(h, .{ .w = c.t.wins, .l = c.t.losses() }),
                h.span(.{ .class = "bar", .style = h.vars(.{ .p = pct }) }, .{}),
            }),
            kda.view(h, .{ .k = avg(c.t.k, c.t.games), .d = avg(c.t.d, c.t.games), .a = avg(c.t.a, c.t.games) }, .{}),
        });
    }
};

/// Per game, rounded
fn avg(sum: u32, games: u16) u16 {
    if (games == 0) return 0;
    return @intCast(@min((sum + games / 2) / games, std.math.maxInt(u16)));
}

pub const css =
    \\@layer components {
    \\  .c-psum { container-type: inline-size; display: grid; gap: var(--sp-4); padding: var(--sp-4);
    \\    background: var(--panel); border: 1px solid var(--line); border-radius: var(--r-l); }
    \\  .c-psum > .head { display: flex; align-items: center; gap: var(--sp-4); }
    \\  .c-psum .ring { --p: 0; flex: none; width: 72px; height: 72px; border-radius: 50%; display: grid; place-items: center;
    \\    background: conic-gradient(var(--us) calc(var(--p) * 1%), var(--them) 0); }
    \\  .c-psum .ring[data-none] { background: var(--line); }
    \\  .c-psum .ring > b { width: 76%; height: 76%; border-radius: 50%; display: grid; place-items: center;
    \\    background: var(--panel); font-size: var(--fs-l); font-variant-numeric: tabular-nums; }
    \\  .c-psum .rec { display: grid; gap: 2px; }
    \\  .c-psum .rec > b { font-size: var(--fs-xl); font-variant-numeric: tabular-nums; }
    \\  .c-psum .rec > small { font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-psum .champs { display: grid; margin: 0 calc(-1 * var(--sp-4)); }
    \\  .c-psum .row { display: grid; grid-template-columns: minmax(0, 1fr) auto auto; align-items: center; gap: var(--sp-3);
    \\    padding: 6px var(--sp-4); border: 0; background: none; color: inherit; font: inherit; text-align: left; cursor: pointer; }
    \\  .c-psum .row:hover { background: var(--ctl-bg); }
    \\  .c-psum .row[aria-pressed="true"] { background: var(--sel-bg); color: var(--sel-ink); }
    \\  .c-psum .row[data-state="thin"] { color: var(--muted); }
    \\  .c-psum .wl { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-s); font-variant-numeric: tabular-nums; }
    \\  .c-psum .bar { --p: 50; width: 48px; height: 6px; border-radius: 3px;
    \\    background: linear-gradient(90deg, var(--us) calc(var(--p) * 1%), var(--them) 0); }
    \\  .c-psum .row > .c-kda { font-size: var(--fs-s); }
    \\  .c-psum .roles { display: grid; grid-template-columns: repeat(5, 1fr); gap: var(--sp-1); }
    \\  .c-psum .col { --h: 0; display: grid; justify-items: center; align-content: end; gap: 4px; padding: 6px 0;
    \\    border: 0; border-radius: var(--r-m); background: none; color: inherit; font: inherit; cursor: pointer; }
    \\  .c-psum .col:hover { background: var(--ctl-bg); }
    \\  .c-psum .col[aria-pressed="true"] { background: var(--sel-bg); color: var(--sel-ink); }
    \\  .c-psum .col:disabled { opacity: .4; cursor: default; }
    \\  .c-psum .col > .fill { width: 14px; height: calc(40px * var(--h) / 100); min-height: 2px; border-radius: 2px; background: var(--c); }
    \\  .c-psum .col > .n { font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; }
    \\  @container (max-width: 420px) { .c-psum .row > .c-kda { display: none; } }
    \\  @media (max-width: 760px) {
    \\    .c-psum { grid-template-columns: auto minmax(0, 1fr); align-items: center; }
    \\    .c-psum .ring { width: 56px; height: 56px; }
    \\    .c-psum .ring > b { font-size: var(--fs-m); }
    \\    .c-psum .rec > b, .c-psum .rec > small, .c-psum .roles { display: none; }
    \\    .c-psum .champs { margin: 0; grid-auto-flow: column; justify-content: end; gap: var(--sp-2); }
    \\    .c-psum .row:not([data-top]) { display: none; }
    \\    .c-psum .row { grid-template-columns: auto; justify-items: center; padding: 4px; border-radius: var(--r-m); }
    \\    .c-psum .row .c-champ > :not(img), .c-psum .row .bar, .c-psum .row > .c-kda { display: none; }
    \\  }
    \\}
    \\
;

const demo = struct {
    const champs = [_]champ.Champ{
        .{ .name = "Aurelion Sol", .src = "" }, .{ .name = "Karthus", .src = "" }, .{ .name = "Gragas", .src = "" },
        .{ .name = "Pyke", .src = "" },         .{ .name = "Orianna", .src = "" },
    };
    const games = blk: {
        // champ, role, result
        const spec = [_]struct { u16, Role, bool }{
            .{ 0, .mid, true },     .{ 0, .mid, true },  .{ 1, .jungle, true },  .{ 0, .mid, false },    .{ 1, .jungle, true },
            .{ 1, .jungle, false }, .{ 0, .mid, true },  .{ 2, .jungle, false }, .{ 3, .support, true }, .{ 4, .mid, true },
            .{ 1, .jungle, true },  .{ 0, .mid, false }, .{ 1, .jungle, true },
        };
        var gs: [spec.len]yl.Game = undefined;
        for (&gs, spec, 0..) |*x, sp, i| x.* = .{
            .start_ms = 0,
            .dur = 1800,
            .patch = "",
            .queue = .solo,
            .champ = sp[0],
            .role = sp[1],
            .win = sp[2],
            .k = 5 + i % 4,
            .d = 3,
            .a = 6 + i % 3,
        };
        break :blk gs;
    };
    const list: yl.List = .{ .player = .{ .name = "MeioNeiz" }, .champs = &champs, .games = &games };
    var all: ProfileSummary = .{};
    var jungle: ProfileSummary = .{ .filter = .{ .role = .jungle } };
    var empty: ProfileSummary = .{};
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("13 games, nothing chosen", demo.all.view(h, &demo.list, &demo.games));
    g.add("jungle chosen", demo.jungle.view(h, &demo.list, &demo.games));
    g.add("no games", demo.empty.view(h, &demo.list, &.{}));
}

const testing = std.testing;

test "the filter's set, rows by games, presses toggle the filter" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var s: ProfileSummary = .{};
    const n = s.view(&h, &demo.list, &demo.games);
    var buf: std.Io.Writer.Allocating = .init(arena.allocator());
    try t.textOf(t.find(n, "class", "rec").?, &buf.writer);
    try testing.expect(std.mem.startsWith(u8, buf.written(), "9–4"));
    // Karthus (5 games) over Aurelion Sol (5 games, fewer wins), then Gragas
    const first = t.find(n, "class", "row").?;
    try testing.expect(std.mem.startsWith(u8, t.attr(first, "title").?, "Karthus: 5 games, 4–1"));
    try testing.expectEqual(3, t.count(n, "data-state"));
    try testing.expectEqual(3, t.count(n, "data-top"));

    var ev: tree.Event = .{ .kind = .click };
    s.update(.{ .role = .jungle }, &ev);
    try testing.expectEqual(Role.jungle, s.filter.role.?);
    const j = s.view(&h, &demo.list, &demo.games);
    buf.clearRetainingCapacity();
    try t.textOf(t.find(j, "class", "rec").?, &buf.writer);
    try testing.expect(std.mem.startsWith(u8, buf.written(), "4–2"));
    // Rows follow the role: Karthus and Gragas played jungle
    try testing.expectEqual(2, t.count(j, "data-top"));
    s.update(.{ .role = .jungle }, &ev);
    try testing.expectEqual(null, s.filter.role);
    s.update(.{ .champ = 1 }, &ev);
    try testing.expectEqual(1, s.filter.champ.?);
    try testing.expect(!h.oom);
}
