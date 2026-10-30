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
const loading = desktop.loading;
const comp = desktop.comp;
const ingame = desktop.ingame;
const postgame = desktop.postgame;
const files = @import("files.zig");
const practice = @import("practice.zig");
const channel = @import("channel.zig");
const app = ui.app;
const Allocator = std.mem.Allocator;

pub const css = ui.css.head ++ ui.css.join(.{ ui.badge, ui.chip, ui.card, ui.role, ui.champ, ui.draftboard, ui.champselect, ui.kda, ui.teamrows, ui.compview, ui.loadscreen, ui.chart, ui.lane, ui.gamescreen, ui.postgame, ui.button, ui.signin, ui.segmented, ui.practice, ui.app });

const Page = struct {
    arena: std.heap.ArenaAllocator,
    html: []const u8,
    bin: []const u8,
    /// ui-practice.wasm's practice.bin; "" while practice is off
    practice: []const u8,
    /// A fingerprint of the comp view under the island, 0 for none
    comp: u32,
};

var page: ?Page = null;
var seq: u32 = 0;

/// The rendered page or app.bin as of the last refresh(); valid until the next
pub fn get(path: []const u8) ?[]const u8 {
    const p = page orelse return null;
    if (std.mem.eql(u8, path, files.start_page)) return p.html;
    if (std.mem.eql(u8, path, "app.bin")) return p.bin;
    if (std.mem.eql(u8, path, "practice.bin") and p.practice.len > 0) return p.practice;
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

pub const Changed = struct {
    seq: u32,
    /// The comp view came, went or changed: static HTML, so not in app.bin's patches
    reload: bool,

    pub fn message(c: Changed) channel.ToPage {
        return if (c.reload) .{ .reload = c.seq } else .{ .app = c.seq };
    }
};

/// Rebuilds from the poller, or without it (`live` false: --self-test) as if no client
/// ran; null when what the page shows is as before
pub fn refresh(gpa: Allocator, live: bool) ?Changed {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const next = (build(arena.allocator(), live) catch null) orelse {
        arena.deinit();
        return null;
    };
    const reload = if (page) |old| old.comp != next.comp else false;
    if (page) |*old| old.arena.deinit();
    page = .{ .arena = arena, .html = next.html, .bin = next.bin, .practice = next.practice, .comp = next.comp };
    return .{ .seq = seq, .reload = reload };
}

pub fn deinit() void {
    if (page) |*p| p.arena.deinit();
    page = null;
}

const Next = struct { html: []const u8, bin: []const u8, practice: []const u8, comp: u32 };

fn build(a: Allocator, live: bool) !?Next {
    if (!live) return finish(a, try data(a, .{ .stats = null, .icons = null, .private = false }, .no_client, .none), null, null);
    const s = poller.lock();
    defer poller.unlock();
    const c: Ctx = .{
        .stats = s.stats,
        .icons = s.icons,
        .private = s.edition == .private,
        .practice = state.private_code and s.practicing and s.practice.* != null,
    };
    var d = try data(a, c, s.status, s.note);
    d.signin = signIn(s.signin, s.status);
    var bar: ?ui.practice.Data = null;
    if (state.private_code and practice.offered(s.edition, s.stats, s.practice.*, s.status)) {
        d.practice = s.practice.* != null;
        if (s.practice.*) |x| bar = try practice.data(a, c, x, s.practicing);
    }
    const under: ?ui.compview.Comp = switch (s.status) {
        .select => |x| if (x.comp) |cv| try compView(a, c, cv) else null,
        else => null,
    };
    return finish(a, d, bar, under);
}

/// The form while there is no working sign-in: the whole screen until there is data
fn signIn(s: ?*const state.SignIn, status: state.Status) ?ui.signin.SignIn {
    const x = s orelse return null;
    if (!x.needed) return null;
    return .{ .full = status == .no_data, .busy = x.busy, .message = x.message };
}

/// Encoded and rendered into `a`, so nothing points into the poller's memory once it
/// unlocks; null when what shows is as before
fn finish(a: Allocator, shown: app.Data, bar: ?ui.practice.Data, under: ?ui.compview.Comp) !?Next {
    var d = shown;
    d.seq = seq + 1;
    var comp_id: u32 = 0;
    if (under) |x| {
        var cbin: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, ui.compview.Comp, x, &cbin);
        comp_id = @as(u32, @truncate(std.hash.Wyhash.hash(0, cbin.items))) | 1;
    }
    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, app.Data, d, &bin);
    var pbin: std.ArrayList(u8) = .empty;
    var p = bar;
    if (p) |*x| {
        x.seq = d.seq;
        try ui.data.encode(a, ui.practice.Data, x.*, &pbin);
    }
    if (page) |old| if (std.mem.eql(u8, shows(old.bin), shows(bin.items)) and std.mem.eql(u8, shows(old.practice), shows(pbin.items)) and old.comp == comp_id) return null;
    seq += 1;
    return .{ .html = try render(a, d, p, under), .bin = bin.items, .practice = pbin.items, .comp = comp_id };
}

/// Past the fingerprint and seq: what shows
fn shows(bin: []const u8) []const u8 {
    return if (bin.len >= 8) bin[8..] else bin;
}

/// The page as of now with what it loads into `dir`/<seq>/, for a look without a window
/// (mac.zig --dump: serve the folder, open it in a browser)
pub fn dump(io: std.Io, gpa: Allocator, dir: []const u8) !void {
    const p = page orelse return;
    const sub = try std.fmt.allocPrint(gpa, "{s}/{d}", .{ dir, seq });
    defer gpa.free(sub);
    const own = [_]struct { []const u8, []const u8 }{ .{ files.start_page, p.html }, .{ "app.bin", p.bin }, .{ "practice.bin", p.practice } };
    for (own) |f| if (f[1].len > 0) try dumpFile(io, gpa, sub, f[0], f[1]);
    for ([_][]const u8{ "app.css", "ui-app.js", "ui-app.wasm", "ui-practice.js", "ui-practice.wasm" }) |f|
        if (files.get(f)) |bytes| try dumpFile(io, gpa, sub, f, bytes);
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

/// With `bar`, practice's island above the app's and its file; with `under`, the comp
/// view after it
pub fn render(a: Allocator, d: app.Data, bar: ?ui.practice.Data, under: ?ui.compview.Comp) ![]const u8 {
    return renderIn(a, d, bar, under, .{});
}

/// What the page links and wraps it in: the shell's own files, or the review pages'
/// (src/site/appreview.zig)
pub const Frame = struct {
    css: []const u8 = "app.css",
    js: []const u8 = "ui-app.js",
    wasm: []const u8 = "ui-app.wasm",
    practice_js: []const u8 = "ui-practice.js",
    practice_wasm: []const u8 = "ui-practice.wasm",
    /// Before </head>
    head: []const u8 = "",
    /// After <body> and before the scripts
    top: []const u8 = "",
    end: []const u8 = "",
};

pub fn renderIn(a: Allocator, d: app.Data, bar: ?ui.practice.Data, under: ?ui.compview.Comp, f: Frame) ![]const u8 {
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    var island: app.App = .{ .data = d };
    const body = island.view(&h);
    var drill: ui.practice.Practice = undefined;
    const top: ?ui.N = if (bar) |x| blk: {
        drill = .{ .data = x };
        break :blk drill.view(&h);
    } else null;
    const comp_n: ?ui.N = if (under) |x| ui.compview.view(&h, x) else null;
    if (h.oom) return error.OutOfMemory;
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print(
        \\<!doctype html><html lang="en"><head><meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>meiolol</title><link rel="stylesheet" href="{s}">{s}</head>
        \\<body class="ui">{s}
    , .{ f.css, f.head, f.top });
    if (top) |n| try ui.html.write(&t, n, w);
    try ui.html.write(&t, body, w);
    if (comp_n) |n| try ui.html.write(&t, n, w);
    try w.print("{s}\n<script src=\"{s}\" data-wasm=\"{s}\" defer></script>", .{ f.end, f.js, f.wasm });
    if (top != null) try w.print("<script src=\"{s}\" data-wasm=\"{s}\" defer></script>", .{ f.practice_js, f.practice_wasm });
    try w.writeAll("</body></html>\n");
    return out.written();
}

pub const SiteIcons = struct {
    ddragon: []const u8,
    keys: *const std.AutoHashMapUnmanaged(u32, []const u8),
};

pub const Ctx = struct {
    stats: ?*const core.Stats,
    icons: ?*const desktop.Icons,
    private: bool,
    /// Practice shows: the board's seats and options carry practice's clicks
    practice: bool = false,
    /// The site's icons in place of the client's (the review pages)
    site: ?*const SiteIcons = null,

    pub fn champ(c: Ctx, a: Allocator, id: u32) !?ui.champ.Champ {
        if (id == 0) return null;
        const stats = c.stats orelse return null;
        if (c.site) |s| if (s.keys.get(id)) |key| return .{ .name = stats.nameOf(id), .src = try a.print(ui.champ.icon_fmt, .{ s.ddragon, key }) };
        const has = if (c.icons) |i| i.get(id) != null else false;
        return .{ .name = stats.nameOf(id), .src = if (has) try a.print("icon/{d}.png", .{id}) else "" };
    }

    /// Practice's click on a board element (data-act); "" while practice doesn't show
    fn act(c: Ctx, a: Allocator, x: ui.practice.Act) ![]const u8 {
        if (!state.private_code or !c.practice) return "";
        return a.print("{f}", .{x});
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
            .in_game => |g| if (c.private) try a.print("In game · {s}", .{ingame.clock(try a.alloc(u8, 16), g.time)}) else "In game",
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
            .loading => |l| .{ .loading = try loadScreen(a, c, l) },
            // The public edition gets the panel once the private one has proved it
            .in_game => |g| if (c.private) .{ .game = try game(a, c, g) } else .{ .note = .{ .title = "In game", .text = "The board comes back in your next champ select." } },
            .post_game => |p| .{ .post = try post(a, c, p) },
        },
        .restart = note == .restart,
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
        .act = try c.act(a, .{ .ban = o.champion }),
    };
    return .{
        .board = .{ .lanes = try lanes(a, c, b, if (s.ally) s.card.role else null), .bans_us = bans_us, .bans_them = bans_them },
        .lane = try lane(a, c, &s.card, board.modeOf(&s.card), s.ally),
        .ban_options = ban_options,
        .banning = b.turn == .ban,
        .draft = if (c.private) if (b.draft) |d| @floatCast(100 * d.win) else null else null,
    };
}

/// Words for everyone; the share, the mix's record, lean numbers and lane gold for
/// testers
pub fn compView(a: Allocator, c: Ctx, x: *const comp.Comp) !ui.compview.Comp {
    var teams: [2]ui.compview.Team = undefined;
    for (&teams, x.teams) |*out, t| {
        // champ-facts.tsv and the stats file ship apart: a champion only the facts know
        // gets no row
        var timing: std.ArrayList(ui.compview.Timing) = .empty;
        for (t.timing) |tm| {
            const champ = (try c.champ(a, tm.champion)) orelse continue;
            if (c.stats.?.index(tm.champion) == null) continue;
            try timing.append(a, .{
                .champ = champ,
                .late = tm.lean == .late,
                .gold = if (c.private) @intFromFloat(tm.gold) else null,
                .win = if (c.private) @floatCast(tm.win) else null,
            });
        }
        out.* = .{ .timing = timing.items };
        const d = t.damage orelse continue;
        out.damage = .{
            .magic = @floatCast(d.magic),
            .mix = switch (d.mix) {
                .physical => .physical,
                .mixed => .mixed,
                .magic => .magic,
            },
            .wins_less = d.wins_less,
            .share = c.private,
            .rate = if (c.private and d.teams.games > 0) @floatCast(100 * @as(f64, @floatFromInt(d.teams.wins)) / @as(f64, @floatFromInt(d.teams.games))) else null,
            .teams = d.teams.games,
        };
    }
    const rows = try a.alloc(ui.teamrows.Row, x.lanes.len);
    for (rows, x.lanes) |*r, l| {
        const words = comp.lines(try a.alloc(u8, 64), try a.alloc(u8, 64), l);
        r.* = .{
            .role = uiRole(l.role),
            .us = if (l.ours != 0) .{ .champ = try c.champ(a, l.ours), .you = l.me, .line = words[0] } else null,
            .them = if (l.theirs != 0) .{ .champ = try c.champ(a, l.theirs), .line = words[1] } else null,
        };
        const f = l.facts orelse continue;
        const g = f.gold orelse continue;
        if (!c.private) continue;
        r.gap = try a.print("{f}", .{gold(g.mean)});
        r.lean = switch (f.edge().?) {
            .ahead => .good,
            .behind => .bad,
            .even => .none,
        };
    }
    return .{
        .us = teams[0],
        .them = teams[1],
        .lanes = rows,
        .patch = x.patch,
        .gold_minute = core.champfacts.gold_minute,
        .win_minute = core.champfacts.win_minute,
        .lane_minute = core.curvesfile.lane_minute,
    };
}

/// A row per role in draft order; a seat without a role takes the first row its side
/// left empty. `shown`: the ally whose lane the panel shows
fn lanes(a: Allocator, c: Ctx, b: *const board.Board, shown: ?core.Role) ![]const ui.draftboard.Lane {
    var rows: [5]ui.draftboard.Lane = undefined;
    for (&rows, ui.role.Role.all) |*r, role| r.* = .{ .role = role };
    var filled: [2][5]bool = @splat(@splat(false));
    // My seats in their own role's row: board.allyLane finds an ally by role
    var roled: [5]bool = @splat(false);
    for ([_][]const board.Seat{ b.allies, b.enemies }, 0..) |seats, side| {
        for (seats, 0..) |s, k| if (s.role) |r| {
            const i = @backingInt(r);
            if (filled[side][i]) continue;
            filled[side][i] = true;
            roled[i] = side == 0;
            setSeat(&rows[i], side, try seat(a, c, s, side, k));
        };
        for (seats, 0..) |s, k| if (s.role == null) for (&rows, 0..) |*row, i| if (!filled[side][i]) {
            filled[side][i] = true;
            setSeat(row, side, try seat(a, c, s, side, k));
            break;
        };
    }
    if (shown) |r| rows[@backingInt(r)].us.sel = true;
    // A click on an ally's seat shows their lane, on mine (while an ally's shows) mine
    // again (bridge.js sends the act); under practice the seats' clicks place champions
    if (!c.practice) for (&rows, roled, 0..) |*row, by_role, i| {
        if (row.us.you) {
            if (shown != null) row.us.act = try a.print("lane {d}", .{state.own_lane});
        } else if (by_role and !row.us.sel) row.us.act = try a.print("lane {d}", .{i});
    };
    return a.dupe(ui.draftboard.Lane, &rows);
}

fn setSeat(row: *ui.draftboard.Lane, side: usize, s: ui.draftboard.Seat) void {
    if (side == 0) row.us = s else row.them = s;
}

/// `k`: the seat's place in its side's list, practice's enemy seat
fn seat(a: Allocator, c: Ctx, s: board.Seat, side: usize, k: usize) !ui.draftboard.Seat {
    const sl = s.slot;
    const ideas = try a.alloc(ui.champ.Champ, s.ideas.len);
    for (ideas, s.ideas) |*x, id| x.* = (try c.champ(a, id)).?;
    // Practice: an ally's seat by role (none without one), its ideas into it
    const ally: ?u8 = if (side == 0) if (s.role) |r| @backingInt(r) else null else null;
    const idea_acts = try a.alloc([]const u8, if (ally != null) s.ideas.len else 0);
    for (idea_acts, s.ideas) |*x, id| x.* = try c.act(a, .{ .fill = .{ ally.?, id } });
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
        .act = if (side == 1)
            try c.act(a, .{ .seat = .{ .enemy = @intCast(k) } })
        else if (ally) |r| try c.act(a, .{ .seat = .{ .ally = r } }) else "",
        .idea_acts = idea_acts,
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

/// `ally`: an ally's lane, without my pool or mastery (a null `mastery` tells the panel)
fn lane(a: Allocator, c: Ctx, card: *const lanecard.Card, mode: board.Mode, ally: bool) !ui.champselect.Lane {
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
            .act = try c.act(a, .{ .take = o.champion }),
        };
    }
    const them = card.opponent;
    const me_champ = try c.champ(a, card.me);
    const them_champ = if (them) |o| try c.champ(a, o.champion) else null;
    const chart: ?ui.lane.Figures = if (card.matchup) |m| if (m.points.len >= 2) blk: {
        const cv = try curve(a, m);
        break :blk .{ .a = if (me_champ) |x| x.name else "You", .b = if (them_champ) |x| x.name else "Them", .band = cv.band, .line = cv.line };
    } else null else null;
    return .{
        .role = uiRole(card.role),
        .me = me_champ,
        .them = them_champ,
        .guessed = if (them) |o| o.guessed else false,
        .mode = switch (mode) {
            .blind => .blind,
            .counter => .counter,
            .locked => .locked,
        },
        .sentence = card.sentence,
        .thin = if (card.matchup) |m| m.thin else false,
        .chart = chart,
        .caption = if (card.matchup) |m| try a.print("Gold, {s} minus them: the line is the average, the band the middle half of {d} games ({s}, EUW, {s}).", .{
            if (ally) if (me_champ) |x| x.name else "them" else "you", m.games, m.bracket.label(), card.period,
        }) else "",
        .options = options,
        .mastery = if (ally) null else state.by_mastery.load(.acquire),
        .scope = if (card.period.len > 0) try a.print("EUW, {s}", .{card.period}) else "EUW",
    };
}

fn loadScreen(a: Allocator, c: Ctx, l: *const loading.Loading) !ui.loadscreen.Screen {
    var teams: [2][]ui.loadscreen.Card = undefined;
    for (&teams, l.teams) |*out, cards| {
        out.* = try a.alloc(ui.loadscreen.Card, cards.len);
        for (out.*, cards) |*x, card| {
            const pills = try a.alloc(ui.loadscreen.Pill, card.pills.len);
            for (pills, card.pills) |*p, q| p.* = .{ .text = q.text, .tone = switch (q.tone) {
                .neutral => .none,
                .good => .good,
                .bad => .bad,
                .caution => .caution,
            } };
            const shown = c.private and card.games > 0;
            x.* = .{
                .champ = try c.champ(a, card.champion),
                .role = if (card.role) |r| uiRole(r) else null,
                .guessed = card.guessed,
                .you = card.me,
                .fact = if (shown) try a.print("{f} · {f} games", .{ rate(card.win), count(card.games) }) else "",
                .lean = if (!shown) .none else if (card.win >= 0.515) .good else if (card.win <= 0.485) .bad else .none,
                .pills = pills,
            };
        }
    }
    return .{
        .us = teams[0],
        .them = teams[1],
        .draft = if (c.private) if (l.draft) |d| @floatCast(100 * d.win) else null else null,
    };
}

fn game(a: Allocator, c: Ctx, g: *const ingame.InGame) !ui.gamescreen.Screen {
    const us = g.score[0];
    const them = g.score[1];
    const lines = [_]struct { []const u8, u32, u32 }{
        .{ "Kills", us.kills, them.kills },
        .{ "Towers", us.towers, them.towers },
        .{ "Dragons", us.dragons + us.elders, them.dragons + them.elders },
        .{ "Grubs", us.grubs, them.grubs },
        .{ "Heralds", us.heralds, them.heralds },
        .{ "Barons", us.barons, them.barons },
        .{ "Inhibitors", us.inhibitors, them.inhibitors },
    };
    var score: std.ArrayList(ui.gamescreen.Score) = .empty;
    for (lines, 0..) |l, i| {
        // Objectives nobody has taken yet only add noise
        if (i > 1 and l[1] == 0 and l[2] == 0) continue;
        try score.append(a, .{ .what = l[0], .us = @intCast(@min(l[1], 999)), .them = @intCast(@min(l[2], 999)) });
    }
    const diff = @as(i64, us.item_gold) - them.item_gold;
    const now = g.sample();
    const timers = try a.alloc(ui.gamescreen.Timer, g.timers.len);
    for (timers, g.timers) |*x, t| x.* = .{
        .what = t.what,
        .at = ingame.clock(try a.alloc(u8, 16), t.back),
        .in = ingame.clock(try a.alloc(u8, 16), t.back - g.time),
    };
    var rows: [5]ui.teamrows.Row = undefined;
    for (&rows, g.rows) |*x, r| {
        var seats: [2]?ui.teamrows.Seat = .{ null, null };
        for (&seats, [_]?ingame.Seat{ r.ours, r.theirs }) |*out, seat_or| {
            const s = seat_or orelse continue;
            out.* = .{
                .champ = try c.champ(a, s.champion),
                .you = s.me,
                .dead = if (s.dead) @intFromFloat(@min(999, @ceil(@max(0, s.respawn)))) else null,
                .kda = kda(s.kills, s.deaths, s.assists),
                .line = try a.print("Lv {d} · {d} cs", .{ s.level, s.cs }),
            };
        }
        x.* = try teamRow(a, r.role, seats, r.goldDiff());
    }
    return .{
        .score = score.items,
        .gold = .{
            .us = try a.print("{f}", .{count(us.item_gold)}),
            .them = try a.print("{f}", .{count(them.item_gold)}),
            .gap = try a.print("{f} item gold", .{gold(diff)}),
            .lean = if (diff > 0) .good else if (diff < 0) .bad else .none,
            .share = @floatCast(@as(f64, @floatFromInt(us.item_gold)) / @as(f64, @floatFromInt(@max(1, us.item_gold + them.item_gold)))),
        },
        .rows = try a.dupe(ui.teamrows.Row, &rows),
        .lane = if (g.lane) |l| try gameLane(a, c, g, l, now) else null,
        .lane_note = g.lane_note,
        .timers = timers,
        .team = try perMinute(a, g.history, now, .team),
    };
}

fn gameLane(a: Allocator, c: Ctx, g: *const ingame.InGame, l: ingame.Lane, now: ingame.Sample) !ui.gamescreen.Lane {
    var compare: std.ArrayList(ui.gamescreen.Compare) = .empty;
    if (l.minute) |m| for ([_]struct { []const u8, ?ingame.Compare }{ .{ "CS", l.cs }, .{ "Item gold", l.gold } }) |x| {
        const cmp = x[1] orelse continue;
        const t = cmp.typical;
        try compare.append(a, .{
            .what = x[0],
            .now = try a.print("{f}", .{signed(cmp.now)}),
            .lean = switch (cmp.standing) {
                .far_behind, .behind => .bad,
                .typical => .none,
                .ahead, .far_ahead => .good,
            },
            .text = try a.print("{s} at {d} min (middle half {f} to {f})", .{ cmp.standing.words(), m, signed(t.p25), signed(t.p75) }),
        });
    };
    const mu = l.matchup;
    const cv = try curve(a, mu);
    const me = try c.champ(a, l.me);
    const them = try c.champ(a, l.opponent);
    return .{
        .me = me,
        .them = them,
        .compare = compare.items,
        .note = if (l.minute == null) try a.print("The lane curve covers minutes 1 to {d}.", .{mu.points.len}) else "",
        .chart = .{
            .a = if (me) |x| x.name else "You",
            .b = if (them) |x| x.name else "Them",
            .you = try perMinute(a, g.history, now, .lane),
            .band = cv.band,
            .line = cv.line,
        },
        .caption = try a.print("Item gold, you minus them: the band is the middle half of {d} games ({s}, EUW, {s}), the line their average; yours from items.", .{ mu.games, mu.bracket.label(), g.period }),
    };
}

/// The matchup's gold by minute as a chart's band (middle half) and line (average). The
/// points start at minute 1; index i is minute i, both 0 at the start
fn curve(a: Allocator, mu: lanecard.Matchup) !struct { band: [][2]f32, line: []f32 } {
    var n: usize = 0;
    for (mu.points) |p| n = @max(n, @as(usize, p.minute) + 1);
    const band = try a.alloc([2]f32, n);
    const line = try a.alloc(f32, n);
    @memset(band, .{ 0, 0 });
    @memset(line, 0);
    for (mu.points) |p| {
        band[p.minute] = .{ @floatFromInt(p.p25), @floatFromInt(p.p75) };
        line[p.minute] = @floatFromInt(p.mean);
    }
    return .{ .band = band, .line = line };
}

fn post(a: Allocator, c: Ctx, p: *const postgame.PostGame) !ui.postgame.Screen {
    const awards = try a.alloc(ui.postgame.Award, p.awards.len);
    for (awards, p.awards) |*x, w| x.* = .{ .what = w.what, .champ = try c.champ(a, w.champion), .side = if (w.ours) .us else .them };
    var rows: [5]ui.teamrows.Row = undefined;
    var damage: std.ArrayList(ui.postgame.Damage) = .empty;
    for (&rows, p.rows) |*x, r| {
        var seats: [2]?ui.teamrows.Seat = .{ null, null };
        for (&seats, [_]?postgame.Seat{ r.ours, r.theirs }) |*out, seat_or| {
            const s = seat_or orelse continue;
            out.* = .{
                .champ = try c.champ(a, s.champion),
                .you = s.me,
                .kda = kda(s.kills, s.deaths, s.assists),
                .line = try a.print("{d} cs · {f} dmg", .{ s.cs, count(s.damage) }),
            };
        }
        x.* = try teamRow(a, r.role, seats, r.goldDiff());
    }
    for ([_]bool{ true, false }) |ours| for (p.rows) |r| {
        const s = (if (ours) r.ours else r.theirs) orelse continue;
        try damage.append(a, .{
            .champ = try c.champ(a, s.champion),
            .side = if (ours) .us else .them,
            .you = s.me,
            .value = s.damage,
            .text = try a.print("{f}", .{count(s.damage)}),
        });
    };
    return .{
        .win = p.win,
        .verdict = p.verdict,
        .kills = .{ @intCast(@min(p.kills[0], 9999)), @intCast(@min(p.kills[1], 9999)) },
        .story = p.story,
        .lane = p.lane,
        .awards = awards,
        .rows = try a.dupe(ui.teamrows.Row, &rows),
        .damage = damage.items,
        .team = if (p.history.len > 0) try perMinute(a, p.history, p.history[p.history.len - 1], .team) else &.{},
    };
}

/// Our seat and theirs with the gold gap between, quiet under 300
fn teamRow(a: Allocator, role: core.Role, seats: [2]?ui.teamrows.Seat, diff: ?i64) !ui.teamrows.Row {
    return .{
        .role = uiRole(role),
        .us = seats[0],
        .them = seats[1],
        .gap = if (diff) |d| try a.print("{f}", .{gold(d)}) else "",
        .lean = if (diff) |d| if (@abs(d) < 300) .none else if (d > 0) .good else .bad else .none,
    };
}

fn kda(k: u32, d: u32, as: u32) ui.kda.Kda {
    return .{ .k = @intCast(@min(k, 999)), .d = @intCast(@min(d, 999)), .a = @intCast(@min(as, 999)) };
}

/// The game so far by minute (index i is minute i) up to `now`: the last sample at or
/// before each minute, `now` for the last
fn perMinute(a: Allocator, history: []const ingame.Sample, now: ingame.Sample, comptime what: enum { team, lane }) ![]const f32 {
    const n: usize = @intFromFloat(@max(0, now.time) / 60);
    if (n < 1) return &.{};
    const out = try a.alloc(f32, n + 1);
    var i: usize = 0;
    var last: f32 = 0;
    for (out, 0..) |*v, m| {
        while (i < history.len and history[i].time <= @as(f32, @floatFromInt(m * 60))) : (i += 1) last = value(history[i], what) orelse last;
        v.* = if (m == 0) 0 else last;
    }
    out[n] = value(now, what) orelse last;
    return out;
}

fn value(s: ingame.Sample, comptime what: anytype) ?f32 {
    return switch (what) {
        .team => @floatFromInt(s.team),
        .lane => if (s.lane) |l| @floatFromInt(l) else null,
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

/// "+1.2k", "−800", "even": a gold gap
const Gold = struct {
    n: i64,

    pub fn format(g: Gold, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (g.n == 0) return w.writeAll("even");
        try w.writeAll(if (g.n > 0) "+" else "\u{2212}");
        try count(@intCast(@min(@abs(g.n), std.math.maxInt(u32)))).format(w);
    }
};

fn gold(n: i64) Gold {
    return .{ .n = n };
}

/// "+8", "−420"
const Signed = struct {
    n: i64,

    pub fn format(s: Signed, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try ui.fmt.write(w, .signed, s.n);
    }
};

fn signed(n: i64) Signed {
    return .{ .n = n };
}

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

pub const Fixture = struct {
    bytes: []u8,
    stats: core.Stats,

    pub fn deinit(f: *Fixture) void {
        f.stats.deinit(testing.allocator);
        testing.allocator.free(f.bytes);
    }
};

/// Three champions, Ahri and Syndra with mid games (practice.zig's tests too)
pub fn fixture() !Fixture {
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
        const points = [_]lanecard.Point{ .{ .minute = 1, .mean = -10, .p25 = -60, .p75 = 40 }, .{ .minute = 2, .mean = -20, .p25 = -100, .p75 = 70 } };
        const ban_options = [_]board.BanOption{.{ .champion = galio, .role = .middle, .impact = 31, .pick_rate = 0.08, .win = 0.53, .my_lane = true }};
    };
    return .{
        .card = .{
            .role = .middle,
            .me = ahri,
            .locked = false,
            .opponent = .{ .champion = syndra, .guessed = true },
            .matchup = .{ .bracket = .all, .games = 1204, .gold = .{}, .range = .{ -900, 700 }, .lane_games = 1204, .ahead = 500, .thin = false, .points = &S.points },
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
    try testing.expectEqualSlices([2]f32, &.{ .{ 0, 0 }, .{ -60, 40 }, .{ -100, 70 } }, ps.lane.chart.?.band);
    try testing.expectEqualStrings("Syndra", ps.lane.chart.?.b);
    try testing.expectEqualStrings("Gold, you minus them: the line is the average, the band the middle half of 1204 games (All games, EUW, last 30 days).", ps.lane.caption);

    var d = try data(a, .{ .stats = stats, .icons = null, .private = false }, .{ .select = &sel }, .none);
    const s = d.screen.select;
    try testing.expectEqual(null, s.draft);
    try testing.expectEqual(null, s.lane.options[0].win);
    try testing.expectEqualStrings("wins often and is picked a lot in mid", s.ban_options[0].why);
    try testing.expectEqualStrings("strong in mid now", s.board.lanes[2].us.fact);
    d.seq = 7;
    const html = try render(a, d, null, null);
    try testing.expect(std.mem.find(u8, html, "data-seq=\"7\"") != null);
    try testing.expect(std.mem.find(u8, html, "ui-app.wasm") != null);
    try testing.expect(std.mem.find(u8, html, "%") == null);

    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, app.Data, d, &bin);
    const back = try ui.data.decode(a, app.Data, bin.items);
    try testing.expectEqualStrings("Syndra", back.screen.select.lane.them.?.name);
}

test "an ally's lane: their seat marked, no mastery toggle, their name in the caption" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    sel.ally = true;
    sel.card.role = .top;
    sel.card.me = galio;
    const allies = [_]board.Seat{
        sel.board.allies[0],
        .{ .slot = .{ .champion = galio, .role = .top, .state = .locked }, .role = .top, .guessed = false, .games = 900, .win = 0.5 },
        .{ .slot = .{ .champion = syndra, .role = .jungle, .state = .locked }, .role = .jungle, .guessed = false, .games = 9, .win = 0.5 },
    };
    sel.board.allies = &allies;
    const s = (try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none)).screen.select;
    try testing.expectEqual(null, s.lane.mastery);
    try testing.expect(s.board.lanes[0].us.sel and !s.board.lanes[2].us.sel);
    // Seats send their lane (bridge.js): the shown one none, mine back to mine, an
    // empty row none
    try testing.expectEqualStrings("", s.board.lanes[0].us.act);
    try testing.expectEqualStrings("lane 1", s.board.lanes[1].us.act);
    try testing.expectEqualStrings("lane 255", s.board.lanes[2].us.act);
    try testing.expectEqualStrings("", s.board.lanes[3].us.act);
    const html = try render(a, try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none), null, null);
    try testing.expect(std.mem.find(u8, html, "data-act=\"lane 1\"") != null);
    try testing.expect(std.mem.find(u8, html, "Your lane</button>") != null);
    try testing.expect(std.mem.startsWith(u8, s.lane.caption, "Gold, Galio minus them"));
    // The board's mode is still mine; the panel's is the card's
    try testing.expectEqual(.counter, s.lane.mode);
    // Still to lock: options as for my lane
    try testing.expect(std.mem.find(u8, html, "Options into them") != null);
    try testing.expect(std.mem.find(u8, html, "<ol class=\"opts\"") != null);
}

test "an ally's lane: once they lock the matchup only, nothing rates their pick" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    sel.ally = true;
    sel.card.role = .top;
    sel.card.me = galio;
    sel.card.locked = true;
    // As lanecard builds it for a locked ally
    sel.card.options = &.{};
    sel.card.sentence = "Galio usually trails Syndra.";
    const allies = [_]board.Seat{
        sel.board.allies[0],
        .{ .slot = .{ .champion = galio, .role = .top, .state = .locked }, .role = .top, .guessed = false, .games = 900, .win = 0.5 },
    };
    sel.board.allies = &allies;
    // Their list is an <ol class="opts"> too
    sel.board.ban_options = &.{};
    for ([_]bool{ false, true }) |private| {
        const c: Ctx = .{ .stats = &f.stats, .icons = null, .private = private };
        const s = (try data(a, c, .{ .select = &sel }, .none)).screen.select;
        try testing.expectEqual(.locked, s.lane.mode);
        try testing.expectEqual(0, s.lane.options.len);
        const html = try render(a, try data(a, c, .{ .select = &sel }, .none), null, null);
        try testing.expect(std.mem.find(u8, html, "Galio usually trails Syndra.") != null);
        try testing.expect(std.mem.find(u8, html, "Your lane</button>") != null);
        for ([_][]const u8{ "Other options", "<ol class=\"opts\"", "enough games", "team win" }) |no|
            try testing.expect(std.mem.find(u8, html, no) == null);
    }
    // Still to pick, nothing with enough games: not "you can pick"
    sel.card.locked = false;
    sel.card.me = 0;
    const html = try render(a, try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none), null, null);
    try testing.expect(std.mem.find(u8, html, "No champion has enough games in this role.") != null);
}

test "role-less seats: no lane click (an ally's lane is found by role)" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    const allies = [_]board.Seat{
        .{ .slot = .{ .champion = ahri, .state = .hover, .me = true }, .role = null, .guessed = false, .games = 0, .win = 0.5 },
        .{ .slot = .{ .champion = galio, .state = .locked }, .role = null, .guessed = false, .games = 0, .win = 0.5 },
    };
    sel.board.allies = &allies;
    const s = (try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none)).screen.select;
    for (s.board.lanes) |row| try testing.expectEqualStrings("", row.us.act);
    try testing.expect(s.board.lanes[1].us.champ != null);
}

test "comp view: once all ten are locked, words for everyone and numbers for testers" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var sel = testSelect();
    var rows: [5]comp.Lane = undefined;
    for (&rows, core.Role.all) |*l, r| l.* = .{ .role = r, .ours = 0, .theirs = 0, .me = false, .facts = null };
    rows[2] = .{ .role = .middle, .ours = ahri, .theirs = syndra, .me = true, .facts = .{ .games = 900, .gold = .{ .mean = -420, .se = 100 }, .level6 = 40, .first_item = null } };
    const c: comp.Comp = .{
        .teams = .{
            .{
                .damage = .{ .magic = 0.81, .mix = .magic, .teams = .{ .games = 6_000, .wins = 2_850 }, .wins_less = true },
                .timing = &.{
                    .{ .champion = ahri, .role = .middle, .lean = .late, .gold = -394, .win = 3.1 },
                    // Newer than the stats file: no row
                    .{ .champion = 999_999, .role = .top, .lean = .early, .gold = 300, .win = -2 },
                },
            },
            .{ .damage = null, .timing = &.{} },
        },
        .lanes = rows,
        .patch = "15.21",
    };
    sel.comp = &c;

    const priv = try compView(a, .{ .stats = &f.stats, .icons = null, .private = true }, sel.comp.?);
    try testing.expectApproxEqAbs(@as(f32, 47.5), priv.us.damage.?.rate.?, 0.01);
    try testing.expectEqual(-394, priv.us.timing[0].gold.?);
    try testing.expectEqual(1, priv.us.timing.len);
    const mid = priv.lanes[2];
    try testing.expectEqualStrings("behind in lane, level 6 later", mid.us.?.line);
    try testing.expectEqualStrings("ahead in lane, level 6 sooner", mid.them.?.line);
    try testing.expectEqualStrings("\u{2212}420", mid.gap);
    try testing.expectEqual(.bad, mid.lean);
    try testing.expectEqual(null, priv.lanes[0].us);

    const public = try compView(a, .{ .stats = &f.stats, .icons = null, .private = false }, sel.comp.?);
    try testing.expect(!public.us.damage.?.share and public.us.damage.?.rate == null and public.us.damage.?.wins_less);
    try testing.expectEqual(null, public.us.timing[0].win);
    try testing.expectEqualStrings("", public.lanes[2].gap);
    const d = try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .select = &sel }, .none);
    const html = try render(a, d, null, public);
    // Static, after the app's island: not inside what ui-app.wasm adopts
    try testing.expect(std.mem.find(u8, html, "data-island=\"app\"").? < std.mem.find(u8, html, "class=\"c-comp\"").?);
    try testing.expect(std.mem.find(u8, try render(a, d, null, null), "c-comp") == null);
    try testing.expect(std.mem.find(u8, html, "Mostly magic damage") != null);
    try testing.expect(std.mem.find(u8, html, "Ahri leans late") != null);
    try testing.expect(std.mem.find(u8, html, "%") == null);
}

test "practice: the board's clicks while it shows, its island and file above the app" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const sel = testSelect();
    const c: Ctx = .{ .stats = &f.stats, .icons = null, .private = true, .practice = true };
    var d = try data(a, c, .{ .select = &sel }, .none);
    const s = d.screen.select;
    try testing.expectEqualStrings("seat ally 2", s.board.lanes[2].us.act);
    try testing.expectEqualStrings("seat enemy 0", s.board.lanes[0].them.act);
    try testing.expectEqualStrings("", s.board.lanes[1].us.act);
    try testing.expectEqualStrings("take 103", s.lane.options[0].act);
    try testing.expectEqualStrings("ban 3", s.ban_options[0].act);
    const off = try data(a, .{ .stats = &f.stats, .icons = null, .private = true }, .{ .select = &sel }, .none);
    try testing.expectEqualStrings("", off.screen.select.board.lanes[2].us.act);

    d.practice = true;
    d.seq = 4;
    const bar = try practice.data(a, c, .{}, true);
    const html = try render(a, d, bar, null);
    const top = std.mem.find(u8, html, "data-island=\"practice\"").?;
    try testing.expect(top < std.mem.find(u8, html, "data-island=\"app\"").?);
    try testing.expect(std.mem.find(u8, html, "data-act=\"seat enemy 0\"") != null);
    try testing.expect(std.mem.find(u8, html, "src=\"ui-practice.js\"") != null);
    try testing.expect(std.mem.find(u8, try render(a, d, null, null), "ui-practice") == null);
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
    try testing.expect((try data(a, c, .{ .waiting = "Lobby" }, .restart)).restart);
}

test "sign-in: the form is the screen until there is data; what pages send parses" {
    const needed: state.SignIn = .{ .needed = true, .message = "Refused." };
    try testing.expect(signIn(&needed, .no_data).?.full);
    const line = signIn(&needed, .no_client).?;
    try testing.expect(!line.full);
    try testing.expectEqualStrings("Refused.", line.message);
    try testing.expectEqual(null, signIn(&.{}, .no_data));
    try testing.expectEqual(null, signIn(null, .no_data));

    const old = ui.toshell.out;
    defer ui.toshell.out = old;
    ui.toshell.out = hear;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    ui.toshell.send(.signin, .{ .username = "ann", .password = "p\"w" });
    const m = try channel.read(arena.allocator(), heard[0..heard_len]);
    try testing.expectEqualStrings("ann", m.signin.username);
    try testing.expectEqualStrings("p\"w", m.signin.password);
    ui.toshell.practice(.place, .{ .at = .{ .enemy = 3 }, .champion = ahri, .locked = true });
    try testing.expectEqual(3, (try channel.read(arena.allocator(), heard[0..heard_len])).practice.place.at.enemy);
}

var heard: [256]u8 = undefined;
var heard_len: usize = 0;

fn hear(s: []const u8) void {
    @memcpy(heard[0..s.len], s);
    heard_len = s.len;
}

test "loading: the role's numbers private only" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const ours = [_]loading.Card{.{ .champion = ahri, .role = .middle, .guessed = false, .me = true, .games = 12_400, .win = 0.521, .pills = &.{.{ .text = "few games", .tone = .caution }} }};
    const theirs = [_]loading.Card{.{ .champion = syndra, .role = .middle, .guessed = true, .me = false, .games = 0, .win = 0, .pills = &.{} }};
    const l: loading.Loading = .{ .teams = .{ &ours, &theirs }, .draft = .{ .win = 0.534, .se = 0.1, .picks = .{ 5, 5 }, .hovers = 0 } };

    const priv = (try data(a, .{ .stats = &f.stats, .icons = null, .private = true }, .{ .loading = &l }, .none)).screen.loading;
    try testing.expectEqualStrings("52.1% · 12k games", priv.us[0].fact);
    try testing.expectEqual(.good, priv.us[0].lean);
    try testing.expectEqual(.caution, priv.us[0].pills[0].tone);
    try testing.expect(priv.them[0].guessed and priv.them[0].fact.len == 0);
    try testing.expectApproxEqAbs(@as(f32, 53.4), priv.draft.?, 0.01);

    var d = try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .loading = &l }, .none);
    try testing.expectEqual(null, d.screen.loading.draft);
    try testing.expectEqualStrings("", d.screen.loading.us[0].fact);
    d.seq = 1;
    try testing.expect(std.mem.find(u8, try render(a, d, null, null), "%") == null);
}

fn testGame(my_lane: ?ingame.Lane) ingame.InGame {
    var rows: [5]ingame.Row = undefined;
    for (&rows, core.Role.all) |*r, role| r.* = .{ .role = role };
    rows[2] = .{
        .role = .middle,
        .ours = .{ .champion = ahri, .level = 9, .kills = 2, .deaths = 1, .assists = 3, .cs = 101, .item_gold = 4200, .dead = false, .respawn = 0, .me = true },
        .theirs = .{ .champion = syndra, .level = 8, .kills = 1, .deaths = 2, .assists = 0, .cs = 90, .item_gold = 3000, .dead = true, .respawn = 12.3, .me = false },
    };
    const S = struct {
        const history = [_]ingame.Sample{
            .{ .time = 0, .team = 0, .lane = 0 },      .{ .time = 60, .team = 100, .lane = 50 },
            .{ .time = 120, .team = 300, .lane = 80 }, .{ .time = 180, .team = 250, .lane = null },
        };
        const timers = [_]ingame.Timer{.{ .what = "Dragon", .back = 300 }};
    };
    return .{
        .time = 230,
        .rows = rows,
        .score = .{ .{ .kills = 3, .item_gold = 9000 }, .{ .kills = 2, .towers = 0, .item_gold = 8100 } },
        .timers = &S.timers,
        .lane = my_lane,
        .lane_note = "No lane to compare.",
        .period = "last 30 days",
        .gold = 300,
        .history = &S.history,
    };
}

test "in game: the private panel, a note for the public edition" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    const points = [_]lanecard.Point{ .{ .minute = 1, .mean = 10, .p25 = -50, .p75 = 60 }, .{ .minute = 2, .mean = 20, .p25 = -90, .p75 = 110 } };
    const t: ingame.Typical = .{ .p10 = -300, .p25 = -100, .mean = 0, .p75 = 120, .p90 = 400 };
    const g = testGame(.{
        .role = .middle,
        .me = ahri,
        .opponent = syndra,
        .matchup = .{ .bracket = .all, .games = 412, .gold = .{}, .range = .{ -500, 500 }, .lane_games = 412, .ahead = 200, .thin = false, .points = &points },
        .minute = 3,
        .cs = .{ .now = 11, .typical = t, .standing = .typical },
        .gold = .{ .now = 1200, .typical = t, .standing = .far_ahead },
    });

    const d = try data(a, .{ .stats = &f.stats, .icons = null, .private = true }, .{ .in_game = &g }, .none);
    try testing.expectEqualStrings("In game · 3:50", d.where);
    const s = d.screen.game;
    // Kills and towers always; dragons and the rest once someone took one
    try testing.expectEqual(@as(usize, 2), s.score.len);
    try testing.expectEqualStrings("+900 item gold", s.gold.gap);
    try testing.expectEqualStrings("9.0k", s.gold.us);
    const mid = s.rows[2];
    try testing.expectEqualStrings("+1.2k", mid.gap);
    try testing.expectEqual(.good, mid.lean);
    try testing.expectEqual(@as(?u16, 13), mid.them.?.dead);
    try testing.expectEqualStrings("Lv 9 · 101 cs", mid.us.?.line);
    try testing.expect(s.rows[0].us == null and s.rows[0].gap.len == 0);
    const l = s.lane.?;
    try testing.expectEqualStrings("+11", l.compare[0].now);
    try testing.expectEqualStrings("about typical at 3 min (middle half \u{2212}100 to +120)", l.compare[0].text);
    try testing.expectEqual(.good, l.compare[1].lean);
    const c = l.chart.?;
    try testing.expectEqualSlices([2]f32, &.{ .{ 0, 0 }, .{ -50, 60 }, .{ -90, 110 } }, c.band);
    // Minutes 0..3; a sample without a lane keeps the last; the last is now
    try testing.expectEqualSlices(f32, &.{ 0, 50, 80, 1200 }, c.you);
    try testing.expectEqualSlices(f32, &.{ 0, 100, 300, 900 }, s.team);
    try testing.expectEqualStrings("5:00", s.timers[0].at);
    try testing.expectEqualStrings("1:10", s.timers[0].in);
    var shown = d;
    shown.seq = 1;
    const html = try render(a, shown, null, null);
    try testing.expect(std.mem.find(u8, html, "c-game") != null and std.mem.find(u8, html, "c-lane") != null);

    const p = try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .in_game = &testGame(null) }, .none);
    try testing.expectEqualStrings("In game", p.where);
    try testing.expectEqualStrings("In game", p.screen.note.title);
}

test "post game: lanes, damage ours then theirs, team gold by minute" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try fixture();
    defer f.deinit();
    var rows: [5]postgame.Row = undefined;
    for (&rows, core.Role.all) |*r, role| r.* = .{ .role = role };
    rows[2] = .{
        .role = .middle,
        .ours = .{ .champion = ahri, .kills = 7, .deaths = 2, .assists = 9, .cs = 231, .gold = 13_000, .damage = 24_600, .vision = 20, .level = 16, .me = true },
        .theirs = .{ .champion = syndra, .kills = 2, .deaths = 7, .assists = 3, .cs = 214, .gold = 13_200, .damage = 950, .vision = 12, .level = 15, .me = false },
    };
    const history = [_]ingame.Sample{ .{ .time = 0, .team = 0, .lane = 0 }, .{ .time = 60, .team = -100, .lane = 0 }, .{ .time = 120, .team = 400, .lane = 0 } };
    const p: postgame.PostGame = .{
        .win = true,
        .length = 1722,
        .verdict = "Victory in 28:42.",
        .story = "",
        .lane = "",
        .awards = &.{.{ .what = "Most damage", .champion = ahri, .ours = true }},
        .rows = rows,
        .kills = .{ 24, 17 },
        .gold = .{ 60_000, 52_000 },
        .history = &history,
    };
    var d = try data(a, .{ .stats = &f.stats, .icons = null, .private = false }, .{ .post_game = &p }, .none);
    const s = d.screen.post;
    try testing.expectEqualStrings("231 cs · 25k dmg", s.rows[2].us.?.line);
    try testing.expectEqualStrings("\u{2212}200", s.rows[2].gap);
    try testing.expectEqual(.none, s.rows[2].lean);
    try testing.expectEqual(.us, s.damage[0].side);
    try testing.expectEqualStrings("950", s.damage[1].text);
    try testing.expectEqualStrings("Ahri", s.awards[0].champ.?.name);
    try testing.expectEqualSlices(f32, &.{ 0, -100, 400 }, s.team);
    d.seq = 1;
    const html = try render(a, d, null, null);
    try testing.expect(std.mem.find(u8, html, "Victory in 28:42.") != null);
}
