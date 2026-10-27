//! The Draft tester page (docs/plan/ui/draft-tester.md, /p/tester.html, private): build a
//! draft, see blue's win chance under a named model, each seat's term and the model's
//! checks. One model at a time from a Select of ModelBadges; the board is DraftBoard's
//! full variant, a seat chosen by a click and filled from ChampSearch. Board | Terms | Files under it. Models are draft-model.bin files the
//! page's code fetches (testerdata.zig); champion keys and names come inline (data-bin)
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
const select = @import("select.zig");
const split = @import("split.zig");
const button = @import("button.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "TesterPage";
pub const scope = .{".c-tester"};
pub const sel = "[data-island=tester]";

const n_role = ds.n_role;

comptime {
    std.debug.assert(@typeInfo(role.Role).@"enum".field_names.len == n_role);
}

const W = struct {
    pub const title = plain("Draft tester");
    pub const model = plain("Model");
    pub const clear = plain("Clear");
    pub const loading = plain("Loading the model…");
    pub const missing = plain("No model file here yet");
    pub const not_loaded = plain("not loaded");
    pub const pick = Phrase("{side:text} {role:text}: pick a champion");
    pub const blue = plain("Blue");
    pub const red = plain("Red");
    pub const board = plain("Board");
    pub const terms = plain("Terms");
    pub const files = plain("Files");
    pub const seat_pts = Phrase("{p:points} vs average");
    pub const facts = Phrase("{kind:text} · {g:kilo} games · {lo:text} to {hi:text} · {acc:rate} on {n:kilo} held out");
    pub const from = Phrase("{where:text} {date:text}");
    pub const ok = Phrase("✓ {file:text}: {n:int} reference drafts match");
    pub const bad = Phrase("✗ {file:text}: {n:int} reference drafts, worst {gap:text} off");
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
};

pub const Champ = struct { id: u32, key: []const u8, name: []const u8 };

/// The models the page offers, in the Select's order (names: plan, Jacob 25 Oct)
pub const Which = enum(u8) { live, comp };

pub const Info = struct {
    name: tree.Text,
    short: tree.Text,
    /// Where the model's numbers show today (from the code, draft-tester.md)
    used_in: []const tree.Text,
    where: tree.Text,
    /// Relative to /p/
    file: []const u8,
};

pub const infos = std.enums.EnumArray(Which, Info).init(.{
    .live = .{ .name = plain("Live draft model"), .short = plain("Live model"), .used_in = &.{ plain("Daily"), plain("App") }, .where = plain("Box"), .file = "models/draft-model.bin" },
    .comp = .{ .name = plain("Comp model"), .short = plain("Comp model"), .used_in = &.{}, .where = plain("Lab"), .file = "lab/draft-model.bin" },
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

pub const Load = union(enum) { none, loading, missing, ready: *const Loaded };

pub const Tab = enum(u8) { board, terms, files };

pub const Page = struct {
    head: *const Head,
    index: *const champsearch.Index,
    which: Which = .live,
    loads: std.enums.EnumArray(Which, Load) = .initFill(.none),
    /// By side (0 blue) and role; 0 empty
    teams: [2][n_role]u32 = @splat(@splat(0)),
    /// The seat being filled: side * n_role + role, side 0 blue
    seat: ?u8 = null,
    tab: Tab = .board,
    search: champsearch.ChampSearch,
    /// The server's render: Head as ui.data, base64
    bin: []const u8 = "",
    /// Set when the model or the board changed: the page's code saves them
    dirty: bool = false,

    pub const Msg = union(enum) { model: Which, tab: Tab, seat: u8, picked, clear };

    pub fn init(head: *const Head, ix: *const champsearch.Index) Page {
        return .{ .head = head, .index = ix, .search = .{ .index = ix, .id = "tester-pick", .mode = .pick, .in_flow = true } };
    }

    pub fn update(p: *Page, m: Msg, _: *tree.Event) void {
        switch (m) {
            .model => |w| {
                p.which = w;
                p.dirty = true;
            },
            .tab => |t| p.tab = t,
            .seat => |i| {
                if (i >= 2 * n_role) return;
                p.seat = if (p.seat == i) null else i;
                p.search.chosen = null;
                p.search.q = .{};
            },
            .picked => {
                const i = p.seat orelse return;
                const e = p.search.chosen orelse return;
                if (e >= p.head.champs.len) return;
                const id = p.head.champs[e].id;
                // A champion plays one seat a draft
                for (&p.teams) |*team| for (team) |*x| {
                    if (x.* == id) x.* = 0;
                };
                p.teams[i / n_role][i % n_role] = id;
                p.seat = null;
                p.search.chosen = null;
                p.dirty = true;
            },
            .clear => {
                p.teams = @splat(@splat(0));
                p.seat = null;
                p.dirty = true;
            },
        }
    }

    /// The model the page shows, once fetched
    pub fn ready(p: *const Page) ?*const Loaded {
        return switch (p.loads.get(p.which)) {
            .ready => |l| l,
            else => null,
        };
    }

    fn champOf(p: *const Page, id: u32) ?*const Champ {
        if (id == 0) return null;
        for (p.head.champs) |*c| if (c.id == id) return c;
        return null;
    }

    fn icon(p: *const Page, h: *H, id: u32) ?champ.Champ {
        const c = p.champOf(id) orelse return null;
        return .{ .name = c.name, .src = h.fmt(champ.icon_fmt, .{ p.head.ddragon, c.key }) };
    }

    pub fn view(p: *Page, h: *H) N {
        return h.div(.{ .class = "c-tester", .data_island = "tester", .data_bin = if (p.bin.len > 0) p.bin else null }, .{
            h.div(.{ .class = "top" }, .{
                h.el(.h1, .{}, .{W.title}),
                p.models(h),
            }),
            p.chance(h),
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
        return h.div(.{ .class = "model" }, .{ parts[0], parts[1] });
    }

    fn chance(p: *Page, h: *H) N {
        const l = p.ready() orelse return h.p(.{ .class = "wait" }, .{switch (p.loads.get(p.which)) {
            .missing => W.missing,
            else => W.loading,
        }});
        const c = l.sc.blue(p.teams);
        return split.view(h, .{ .p = @floatCast(100 * c.p), .lo = @floatCast(100 * c.lo), .hi = @floatCast(100 * c.hi), .s = .l });
    }

    fn board(p: *Page, h: *H) N {
        const l = p.ready();
        var lanes: [n_role]draftboard.Lane = undefined;
        var on: [n_role][2]?tree.Handler = undefined;
        for (&lanes, &on, 0..) |*lane, *o, r| {
            lane.* = .{ .role = role.Role.all[r], .us = p.seatOf(h, l, 0, r), .them = p.seatOf(h, l, 1, r) };
            o.* = .{ h.on(p, .{ .seat = @intCast(r) }), h.on(p, .{ .seat = @intCast(n_role + r) }) };
        }
        p.search.on_pick = h.on(p, .picked);
        const s = p.seat;
        return h.div(.{ .class = "bd" }, .{
            draftboard.fullOn(h, .{ .v = .full, .lanes = &lanes }, &on),
            if (s) |i| h.div(.{ .class = "pick" }, .{
                h.p(.{}, .{W.pick.with(h, .{ .side = (if (i < n_role) W.blue else W.red).s, .role = role.Role.all[i % n_role].label().s })}),
                p.search.view(h),
            }) else null,
            button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .clear) }, .{W.clear}),
        });
    }

    fn seatOf(p: *const Page, h: *H, l: ?*const Loaded, side: u1, r: usize) draftboard.Seat {
        const id = p.teams[side][r];
        const pts: ?f64 = if (l) |x| (if (id != 0) seatPoints(x, p.teams, side, r) else null) else null;
        return .{
            .champ = p.icon(h, id),
            .state = if (id != 0) .locked else .empty,
            .sub = if (pts) |x| W.seat_pts.with(h, .{ .p = x }) else .{ .s = "" },
            .sel = if (p.seat) |i| i == @as(usize, side) * n_role + r else false,
        };
    }

    fn termsView(p: *Page, h: *H) N {
        const l = p.ready() orelse return h.p(.{ .class = "wait" }, .{W.loading});
        var rows = h.list();
        for (0..2) |side| for (0..n_role) |r| {
            const id = p.teams[side][r];
            const c = p.champOf(id) orelse continue;
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
                    if (l.check.ok()) break :blk W.ok.with(h, .{ .file = i.file, .n = l.check.drafts });
                    break :blk W.bad.with(h, .{ .file = i.file, .n = l.check.drafts, .gap = fixed(h, l.check.worst, 9) });
                },
                .missing => tree.Text{ .s = h.fmt("{s}: {s}", .{ i.file, W.missing.s }) },
                .loading => tree.Text{ .s = h.fmt("{s}: …", .{i.file}) },
                .none => tree.Text{ .s = h.fmt("{s}: {s}", .{ i.file, W.not_loaded.s }) },
            }}));
        }
        return h.ul(.{ .class = "files" }, .{lines.done()});
    }
};

/// What a seat adds to its team's chance over the role's average pick, in points
fn seatPoints(l: *const Loaded, teams: [2][n_role]u32, side: u1, r: usize) f64 {
    var without = teams;
    without[side][r] = 0;
    const d = l.sc.blue(teams).p - l.sc.blue(without).p;
    return 100 * if (side == 0) d else -d;
}

/// `x` with `digits` decimals, by integers: std's float printing would add kilobytes to
/// the wasm. "?" when out of range
fn fixed(h: *H, x: f64, comptime digits: u8) []const u8 {
    const scale = comptime std.math.pow(f64, 10, digits);
    if (!std.math.isFinite(x) or @abs(x) >= 1e6) return "?";
    const n: u64 = @intFromFloat(@round(@abs(x) * scale));
    const one: u64 = @intFromFloat(scale);
    return h.fmt("{s}{d}.{d:0>[3]}", .{ if (x < 0 and n > 0) "-" else "", n / one, n % one, digits });
}

/// "2026-10-24" as "24 Oct"
fn shortDate(h: *H, ymd: []const u8) []const u8 {
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    if (ymd.len != 10) return ymd;
    const m = std.fmt.parseInt(u8, ymd[5..7], 10) catch return ymd;
    const d = std.fmt.parseInt(u8, ymd[8..10], 10) catch return ymd;
    if (m < 1 or m > 12) return ymd;
    return h.fmt("{d} {s}", .{ d, months[m - 1] });
}

/// The search's entries, in Head.champs' order (a pick's index is a champion's)
pub fn index(a: std.mem.Allocator, head: *const Head) !champsearch.Index {
    const entries = try a.alloc(champsearch.Entry, head.champs.len);
    for (entries, head.champs) |*e, c| e.* = .{ .name = c.name, .src = try a.print(champ.icon_fmt, .{ head.ddragon, c.key }) };
    return .init(a, entries);
}

/// The board as saved: "w t0,..,t9", w the model's index
pub fn saved(p: *const Page, w: *std.Io.Writer) !void {
    try w.print("{d}", .{@backingInt(p.which)});
    for (p.teams, 0..) |team, s| for (team, 0..) |id, r| try w.print("{s}{d}", .{ if (s == 0 and r == 0) " " else ",", id });
}

/// Back from `saved`; anything off leaves the page as it is
pub fn restore(p: *Page, s: []const u8) void {
    var it = std.mem.tokenizeAny(u8, s, " ,");
    const w = std.fmt.parseInt(u8, it.next() orelse return, 10) catch return;
    const which = std.enums.fromInt(Which, w) orelse return;
    var teams: [2][n_role]u32 = undefined;
    for (&teams) |*team| for (team) |*x| {
        x.* = std.fmt.parseInt(u32, it.next() orelse return, 10) catch return;
    };
    p.which = which;
    p.teams = teams;
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
    \\  .c-tester .pick { display: grid; gap: var(--sp-1); width: min(100%, 360px); }
    \\  .c-tester .pick p { margin: 0; font-size: var(--fs-s); }
    \\  .c-tester .files { margin: 0; padding: 0; list-style: none; display: grid; gap: var(--sp-1); font-size: var(--fs-s); }
    \\}
    \\
;

/// Hand-made data for the gallery and tests: two champions, one model
pub const Demo = struct {
    pub const head: Head = .{ .ddragon = "16.21.1", .champs = &.{ .{ .id = 266, .key = "Aatrox", .name = "Aatrox" }, .{ .id = 122, .key = "Darius", .name = "Darius" } } };

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
    const ix = a.create(champsearch.Index) catch return;
    ix.* = index(a, &Demo.head) catch return;
    const l = a.create(Loaded) catch return;
    l.* = .{ .m = Demo.model(), .sc = undefined, .check = .{ .drafts = 0, .worst = 0 } };
    l.sc = l.m.scorer(a) catch return;
    const states = [_][]const u8{ "loading", "a draft", "picking", "terms", "files" };
    for (states, 0..) |caption, i| {
        const p = a.create(Page) catch return;
        p.* = .init(&Demo.head, ix);
        if (i > 0) p.loads.set(.live, .{ .ready = l });
        p.loads.set(.comp, .missing);
        p.teams[0][0] = 266;
        if (i != 2) p.teams[1][0] = 122;
        if (i == 2) p.seat = n_role;
        p.tab = switch (i) {
            3 => .terms,
            4 => .files,
            else => .board,
        };
        g.add(caption, p.view(g.h));
    }
}

const testing = std.testing;

test "tester page: a pick fills the seat, moves a champion off its other seat, scores" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const ix = try index(a, &Demo.head);
    var l: Loaded = .{ .m = Demo.model(), .sc = undefined, .check = undefined };
    l.sc = try l.m.scorer(a);
    var p: Page = .init(&Demo.head, &ix);
    p.loads.set(.live, .{ .ready = &l });
    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .seat = 0 }, &ev);
    p.search.chosen = 0;
    p.update(.picked, &ev);
    try testing.expectEqual(266, p.teams[0][0]);
    try testing.expect(p.seat == null);
    p.update(.{ .seat = n_role }, &ev);
    p.search.chosen = 0;
    p.update(.picked, &ev);
    // Aatrox moved to red top
    try testing.expectEqual(0, p.teams[0][0]);
    try testing.expectEqual(266, p.teams[1][0]);
    p.update(.{ .seat = 2 * n_role }, &ev);
    try testing.expect(p.seat == null);
    p.update(.{ .seat = 3 }, &ev);
    p.update(.{ .seat = 3 }, &ev);
    try testing.expect(p.seat == null);
    // Red Aatrox (0.2) over the share-weighted average 0.6 * 0.2 + 0.4 * -0.1 = 0.08
    const red = seatPoints(&l, p.teams, 1, 0);
    const with: f64 = 0.02 + 0.08 - 0.2;
    const want = 100 * (1 / (1 + @exp(@as(f64, -0.02))) - 1 / (1 + @exp(-with)));
    try testing.expectApproxEqAbs(want, red, 1e-4);
    var out: std.Io.Writer.Allocating = .init(a);
    try saved(&p, &out.writer);
    try testing.expectEqualStrings("0 0,0,0,0,0,266,0,0,0,0", out.written());
    var q: Page = .init(&Demo.head, &ix);
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
