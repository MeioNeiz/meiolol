//! The app's page from the poller's state: ui.app.Data in the shell's words for its
//! edition, rendered to HTML for the first load and encoded (ui.data) as app.bin for the
//! island's patches. The public edition gets words, no win chances (docs/production-key.md).
//! All on the UI thread: refresh() on each tick or poller wake, get() from requests

const std = @import("std");
const ui = @import("ui");
const desktop = @import("desktop");
const core = desktop.core;
const poller = desktop.poller;
const state = desktop.state;
const board = desktop.board;
const lanecard = desktop.lanecard;
const files = @import("files.zig");
const app = ui.app;
const Allocator = std.mem.Allocator;

pub const css = ui.css.head ++ ui.css.join(.{ ui.badge, ui.chip, ui.card, ui.role, ui.champ, ui.draftboard, ui.champselect, ui.app });

const Page = struct {
    arena: std.heap.ArenaAllocator,
    html: []const u8,
    bin: []const u8,
};

var page: ?Page = null;
var seq: u32 = 0;

/// The rendered page or app.bin as of the last refresh(); valid until the next
pub fn get(path: []const u8) ?[]const u8 {
    const p = page orelse return null;
    if (std.mem.eql(u8, path, files.start_page)) return p.html;
    if (std.mem.eql(u8, path, "app.bin")) return p.bin;
    return null;
}

/// A champion icon at icon/<id>.png, copied: the poller may drop it
pub fn icon(gpa: Allocator, path: []const u8) ?[]u8 {
    if (!std.mem.startsWith(u8, path, "icon/") or !std.mem.endsWith(u8, path, ".png")) return null;
    const id = std.fmt.parseInt(u32, path["icon/".len .. path.len - ".png".len], 10) catch return null;
    const s = poller.lock();
    defer poller.unlock();
    return gpa.dupe(u8, s.icons.get(id) orelse return null) catch null;
}

/// Rebuilds from the poller, or without it (`live` false: --self-test) as if no client
/// ran; the new seq when what the page shows changed, else null
pub fn refresh(gpa: Allocator, live: bool) ?u32 {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const next = (build(arena.allocator(), live) catch null) orelse {
        arena.deinit();
        return null;
    };
    if (page) |*old| old.arena.deinit();
    page = .{ .arena = arena, .html = next.html, .bin = next.bin };
    return seq;
}

pub fn deinit() void {
    if (page) |*p| p.arena.deinit();
    page = null;
}

const Next = struct { html: []const u8, bin: []const u8 };

fn build(a: Allocator, live: bool) !?Next {
    if (!live) return finish(a, try data(a, .{ .stats = null, .icons = null, .private = false }, .no_client, .none));
    const s = poller.lock();
    defer poller.unlock();
    return finish(a, try data(a, .{ .stats = s.stats, .icons = s.icons, .private = s.edition == .private }, s.status, s.note));
}

/// Encoded and rendered into `a`, so nothing points into the poller's memory once it
/// unlocks; null when what shows is as before
fn finish(a: Allocator, shown: app.Data) !?Next {
    var d = shown;
    d.seq = seq + 1;
    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, app.Data, d, &bin);
    // Past the fingerprint and seq: the rest is what shows
    if (page) |old| if (std.mem.eql(u8, old.bin[8..], bin.items[8..])) return null;
    seq += 1;
    return .{ .html = try render(a, d), .bin = bin.items };
}

/// The page as of now with what it loads into `dir`/<seq>/, for a look without a window
/// (mac.zig --dump: serve the folder, open it in a browser)
pub fn dump(io: std.Io, gpa: Allocator, dir: []const u8) !void {
    const p = page orelse return;
    const sub = try std.fmt.allocPrint(gpa, "{s}/{d}", .{ dir, seq });
    defer gpa.free(sub);
    const own = [_]struct { []const u8, []const u8 }{ .{ files.start_page, p.html }, .{ "app.bin", p.bin } };
    for (own) |f| try dumpFile(io, gpa, sub, f[0], f[1]);
    for ([_][]const u8{ "app.css", "ui-app.js", "ui-app.wasm" }) |f| try dumpFile(io, gpa, sub, f, files.get(f).?);
    var rest = p.html;
    while (std.mem.find(u8, rest, "\"icon/")) |i| {
        rest = rest[i + 1 ..];
        const end = std.mem.findScalar(u8, rest, '"') orelse break;
        const png = icon(gpa, rest[0..end]) orelse continue;
        defer gpa.free(png);
        try dumpFile(io, gpa, sub, rest[0..end], png);
    }
}

fn dumpFile(io: std.Io, gpa: Allocator, dir: []const u8, name: []const u8, bytes: []const u8) !void {
    const path = try std.fs.path.join(gpa, &.{ dir, name });
    defer gpa.free(path);
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, std.fs.path.dirname(path).?);
    try cwd.writeFile(io, .{ .sub_path = path, .data = bytes });
}

pub fn render(a: Allocator, d: app.Data) ![]const u8 {
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    const body = app.page(&h, d);
    if (h.oom) return error.OutOfMemory;
    var out: std.Io.Writer.Allocating = .init(a);
    try out.writer.writeAll(
        \\<!doctype html><html lang="en"><head><meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>meiolol</title><link rel="stylesheet" href="app.css"></head>
        \\<body class="ui">
    );
    try ui.html.write(&t, body, &out.writer);
    try out.writer.writeAll("\n<script src=\"ui-app.js\" data-wasm=\"ui-app.wasm\" defer></script></body></html>\n");
    return out.written();
}

pub const Ctx = struct {
    stats: ?*const core.Stats,
    icons: ?*const desktop.Icons,
    private: bool,

    fn champ(c: Ctx, a: Allocator, id: u32) !?ui.champ.Champ {
        if (id == 0) return null;
        const stats = c.stats orelse return null;
        const has = if (c.icons) |i| i.get(id) != null else false;
        return .{ .name = stats.nameOf(id), .src = if (has) try a.print("icon/{d}.png", .{id}) else "" };
    }
};

pub fn data(a: Allocator, c: Ctx, status: state.Status, note: state.Note) !app.Data {
    return .{
        .seq = 0,
        .private = c.private,
        .where = switch (status) {
            .no_data => "No data",
            .no_client => "Client closed",
            .client_error => "Client error",
            .waiting => |phase| phase,
            .no_role => "Champ select",
            .select => |s| try a.print("Champ select · {s}", .{s.board.stage}),
            .loading => "Loading",
            .in_game => "In game",
            .post_game => "Post game",
        },
        .screen = switch (status) {
            .no_data => .{ .note = switch (note) {
                .downloading => .{ .title = "Downloading champion statistics from meio.lol" },
                .failed => |e| .{
                    .title = "Could not download champion statistics from meio.lol",
                    .text = try a.print("{s}; trying again in 5 minutes.", .{e}),
                },
                .none, .restart => .{ .title = "No stats file found", .text = "Put stats-*.bin and recent-curves.bin next to the app." },
            } },
            .no_client => .{ .note = .{ .title = "Waiting for the League client to start" } },
            .client_error => |e| .{ .note = .{ .title = "League client not reachable", .text = try a.print("{s}; retrying.", .{e}) } },
            .waiting => .{ .note = .{ .title = "The board shows in champ select", .text = "Both teams, your lane, options and bans." } },
            .no_role => .{ .note = .{ .title = "No lane to show", .text = "This champ select has no assigned positions." } },
            .select => |s| .{ .select = try select(a, c, s) },
            .loading, .in_game, .post_game => .{ .note = .{ .title = "The board comes back in your next champ select" } },
        },
    };
}

fn select(a: Allocator, c: Ctx, s: *const state.Select) !ui.champselect.Screen {
    const b = &s.board;
    const bans_us = try a.alloc(ui.champ.Champ, b.my_bans.len);
    for (bans_us, b.my_bans) |*x, id| x.* = (try c.champ(a, id)) orelse .{ .name = "", .src = "" };
    const bans_them = try a.alloc(ui.champ.Champ, b.their_bans.len);
    for (bans_them, b.their_bans) |*x, id| x.* = (try c.champ(a, id)) orelse .{ .name = "", .src = "" };
    const ban_options = try a.alloc(ui.champselect.BanOption, b.ban_options.len);
    for (ban_options, b.ban_options) |*x, o| x.* = .{
        .champ = (try c.champ(a, o.champion)).?,
        .role = uiRole(o.role),
        .mine = o.my_lane,
        .why = if (c.private)
            try a.print("{f} won, {f} of games, +{d:.0} wins per 10k", .{ rate(o.win), rate(o.pick_rate), o.impact })
        else
            try a.print("wins often and is picked a lot in {s}", .{o.role.label()}),
    };
    return .{
        .board = .{ .lanes = try lanes(a, c, b), .bans_us = bans_us, .bans_them = bans_them },
        .lane = try lane(a, c, &s.card, b.mode),
        .ban_options = ban_options,
        .banning = b.turn == .ban,
        .draft = if (c.private) if (b.draft) |d| @floatCast(100 * d.win) else null else null,
    };
}

/// A row per role in draft order; a seat without a role takes the first row its side
/// left empty
fn lanes(a: Allocator, c: Ctx, b: *const board.Board) ![]const ui.draftboard.Lane {
    var rows: [5]ui.draftboard.Lane = undefined;
    for (&rows, ui.role.Role.all) |*r, role| r.* = .{ .role = role };
    var filled: [2][5]bool = @splat(@splat(false));
    for ([_][]const board.Seat{ b.allies, b.enemies }, 0..) |seats, side| {
        for (seats) |s| if (s.role) |r| {
            const i = @backingInt(r);
            if (filled[side][i]) continue;
            filled[side][i] = true;
            setSeat(&rows[i], side, try seat(a, c, s));
        };
        for (seats) |s| if (s.role == null) for (&rows, 0..) |*row, i| if (!filled[side][i]) {
            filled[side][i] = true;
            setSeat(row, side, try seat(a, c, s));
            break;
        };
    }
    return a.dupe(ui.draftboard.Lane, &rows);
}

fn setSeat(row: *ui.draftboard.Lane, side: usize, s: ui.draftboard.Seat) void {
    if (side == 0) row.us = s else row.them = s;
}

fn seat(a: Allocator, c: Ctx, s: board.Seat) !ui.draftboard.Seat {
    const sl = s.slot;
    const ideas = try a.alloc(ui.champ.Champ, s.ideas.len);
    for (ideas, s.ideas) |*x, id| x.* = (try c.champ(a, id)).?;
    var out: ui.draftboard.Seat = .{
        .champ = try c.champ(a, sl.champion),
        .state = switch (sl.state) {
            .empty => .empty,
            .intent => .intent,
            .hover => .hover,
            .locked => .locked,
        },
        .you = sl.me,
        .picking = sl.picking,
        .guessed = s.guessed,
        .ideas = ideas,
    };
    // How the champion does in the role: a number for testers, words for everyone
    if (sl.champion != 0 and s.games > 0) if (s.role) |r| {
        if (c.private) {
            out.fact = try a.print("{f} in {s} · {f} games", .{ rate(s.win), r.label(), count(s.games) });
            out.lean = if (s.win >= 0.515) .good else if (s.win <= 0.485) .bad else .none;
        } else if (s.win >= 0.515) {
            out.fact = try a.print("strong in {s} now", .{r.label()});
            out.lean = .good;
        } else if (s.win <= 0.485) {
            out.fact = try a.print("weak in {s} now", .{r.label()});
            out.lean = .bad;
        }
    };
    return out;
}

fn lane(a: Allocator, c: Ctx, card: *const lanecard.Card, mode: board.Mode) !ui.champselect.Lane {
    const options = try a.alloc(ui.champselect.Option, card.options.len);
    for (options, card.options) |*x, o| {
        const reasons = try a.alloc(ui.champselect.Reason, o.reasons.len);
        for (reasons, o.reasons, 0..) |*r, text, j| r.* = .{
            .text = text,
            .lean = if (j < o.tones.len) switch (o.tones[j]) {
                .neutral => .none,
                .good => .good,
                .bad => .bad,
            } else .none,
        };
        x.* = .{
            .champ = (try c.champ(a, o.champion)).?,
            .current = o.champion == card.me,
            .win = if (c.private) @floatCast(100 * o.win) else null,
            .lane = if (o.lane) |l| l.text else "",
            .lean = if (o.lane) |l| switch (l.lean) {
                .ahead => .good,
                .behind => .bad,
                .unclear => .none,
            } else .none,
            .faint = if (o.lane) |l| l.strength < 0.75 else false,
            .reasons = reasons,
        };
    }
    const them = card.opponent;
    return .{
        .role = uiRole(card.role),
        .me = try c.champ(a, card.me),
        .them = if (them) |o| try c.champ(a, o.champion) else null,
        .guessed = if (them) |o| o.guessed else false,
        .mode = switch (mode) {
            .blind => .blind,
            .counter => .counter,
            .locked => .locked,
        },
        .sentence = card.sentence,
        .thin = if (card.matchup) |m| m.thin else false,
        .options = options,
        .scope = if (card.period.len > 0) try a.print("EUW, {s}", .{card.period}) else "EUW",
    };
}

fn uiRole(r: core.Role) ui.role.Role {
    return @fromBackingInt(@as(u3, @backingInt(r)));
}

const Num = struct {
    v: f64,
    kind: enum { rate, count },

    pub fn format(n: Num, w: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (n.kind) {
            .rate => try ui.fmt.write(w, .rate, 100 * n.v),
            // 950, 9.4k, 26k: a seat's line is narrow
            .count => if (n.v < 1000)
                try w.print("{d}", .{n.v})
            else if (n.v < 10_000)
                try w.print("{d:.1}k", .{n.v / 1000})
            else
                try w.print("{d:.0}k", .{n.v / 1000}),
        }
    }
};

fn rate(v: f64) Num {
    return .{ .v = v, .kind = .rate };
}

fn count(n: u32) Num {
    return .{ .v = @floatFromInt(n), .kind = .count };
}

const testing = std.testing;

const ahri = 103;
const syndra = 134;
const galio = 3;

const Fixture = struct {
    bytes: []u8,
    stats: core.Stats,

    fn deinit(f: *Fixture) void {
        f.stats.deinit(testing.allocator);
        testing.allocator.free(f.bytes);
    }
};

fn fixture() !Fixture {
    const gpa = testing.allocator;
    var sb: core.statsfile.Builder = try .init(gpa, &.{
        .{ .id = ahri, .name = "Ahri" }, .{ .id = syndra, .name = "Syndra" }, .{ .id = galio, .name = "Galio" },
    });
    defer sb.deinit();
    for (0..40) |i| sb.addGame(.{ .{ 0, 0, ahri, 0, 0 }, .{ 0, 0, syndra, 0, 0 } }, @intCast(i % 2));
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try sb.write(&aw.writer, "test");
    const bytes = try aw.toOwnedSlice();
    errdefer gpa.free(bytes);
    return .{ .bytes = bytes, .stats = try .parse(gpa, bytes) };
}

fn testSelect() state.Select {
    const S = struct {
        const options = [_]lanecard.Option{
            .{ .champion = ahri, .mastery = 0, .win = 0.521, .lane = .{ .text = "-150 gold at 14 min vs Syndra", .lean = .behind }, .reasons = &.{"your most played"} },
            .{ .champion = galio, .mastery = 0, .win = 0.54, .lane = null, .reasons = &.{ "120k mastery", "strong in mid now" }, .tones = &.{ .neutral, .good } },
        };
        const allies = [_]board.Seat{.{ .slot = .{ .champion = ahri, .role = .middle, .state = .hover, .me = true }, .role = .middle, .guessed = false, .games = 25_551, .win = 0.55 }};
        const enemies = [_]board.Seat{.{ .slot = .{ .champion = syndra, .state = .locked }, .role = null, .guessed = true, .games = 20, .win = 0.45 }};
        const ban_options = [_]board.BanOption{.{ .champion = galio, .role = .middle, .impact = 31, .pick_rate = 0.08, .win = 0.53, .my_lane = true }};
    };
    return .{
        .card = .{
            .role = .middle,
            .me = ahri,
            .locked = false,
            .opponent = .{ .champion = syndra, .guessed = true },
            .matchup = null,
            .sentence = "Ahri usually trails Syndra.",
            .options = &S.options,
            .period = "last 30 days",
        },
        .board = .{
            .allies = &S.allies,
            .enemies = &S.enemies,
            .my_bans = &.{},
            .their_bans = &.{galio},
            .turn = .ban,
            .stage = "Bans",
            .mode = .{ .counter = .{ .champion = syndra, .guessed = true } },
            .ban_options = &S.ban_options,
            .draft = .{ .win = 0.534, .se = 0.1, .picks = .{ 1, 1 }, .hovers = 1 },
        },
    };
}

test "champ select: the private edition's numbers, the public one's words" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const stats = &f.stats;
    const sel = testSelect();

    const priv = try data(a, .{ .stats = stats, .icons = null, .private = true }, .{ .select = &sel }, .none);
    try testing.expectEqualStrings("Champ select · Bans", priv.where);
    const ps = priv.screen.select;
    try testing.expectApproxEqAbs(@as(f32, 53.4), ps.draft.?, 0.01);
    try testing.expect(ps.banning);
    try testing.expectEqualStrings("53.0% won, 8.0% of games, +31 wins per 10k", ps.ban_options[0].why);
    try testing.expectEqualStrings("55.0% in mid · 26k games", ps.board.lanes[2].us.fact);
    // Syndra has no role: she takes the first empty enemy row
    try testing.expectEqualStrings("Syndra", ps.board.lanes[0].them.champ.?.name);
    try testing.expect(ps.board.lanes[2].us.you);
    try testing.expect(ps.lane.options[0].current and ps.lane.options[0].lean == .bad);
    try testing.expectEqual(.good, ps.lane.options[1].reasons[1].lean);
    try testing.expectEqualStrings("EUW, last 30 days", ps.lane.scope);
    try testing.expectEqualStrings("", ps.lane.me.?.src);

    var d = try data(a, .{ .stats = stats, .icons = null, .private = false }, .{ .select = &sel }, .none);
    const s = d.screen.select;
    try testing.expectEqual(null, s.draft);
    try testing.expectEqual(null, s.lane.options[0].win);
    try testing.expectEqualStrings("wins often and is picked a lot in mid", s.ban_options[0].why);
    try testing.expectEqualStrings("strong in mid now", s.board.lanes[2].us.fact);
    d.seq = 7;
    const html = try render(a, d);
    try testing.expect(std.mem.find(u8, html, "data-seq=\"7\"") != null);
    try testing.expect(std.mem.find(u8, html, "ui-app.wasm") != null);
    try testing.expect(std.mem.find(u8, html, "%") == null);

    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, app.Data, d, &bin);
    const back = try ui.data.decode(a, app.Data, bin.items);
    try testing.expectEqualStrings("Syndra", back.screen.select.lane.them.?.name);
}

test "notes while there is no board" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const c: Ctx = .{ .stats = null, .icons = null, .private = false };
    try testing.expectEqualStrings("Lobby", (try data(a, c, .{ .waiting = "Lobby" }, .none)).where);
    const e = try data(a, c, .{ .client_error = "ConnectionRefused" }, .none);
    try testing.expectEqualStrings("ConnectionRefused; retrying.", e.screen.note.text);
    const f = try data(a, c, .no_data, .{ .failed = "Timeout" });
    try testing.expectEqualStrings("Timeout; trying again in 5 minutes.", f.screen.note.text);
}
