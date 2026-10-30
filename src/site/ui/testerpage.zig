//! The Draft tester page (docs/plan/ui/draft-tester.md, /private/tester): build a
//! draft, see blue's win chance under a named model, each seat's term and the model's
//! checks. One model at a time from a Select of ModelBadges; the board is DraftBoard's
//! full variant, a click choosing the seat the candidate panel (testercand.zig, its own
//! island and wasm) fills. Board | Terms | Files under it. The model, board, seat and tab
//! are the URL fragment's (Url), which the panel shares. Models are draft-model.bin files
//! the page's code fetches (testerdata.zig); champion keys and names come inline (data-bin)
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
const fmt = @import("fmt.zig");
const url = @import("url.zig");
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

comptime {
    std.debug.assert(@typeInfo(role.Role).@"enum".field_names.len == n_role);
}

const W = struct {
    pub const title = plain("Draft tester");
    pub const model = plain("Model");
    pub const clear = plain("Clear");
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
    /// On the private site
    file: []const u8,
};

pub const infos = std.enums.EnumArray(Which, Info).init(.{
    .live = .{ .name = plain("Live draft model"), .short = plain("Live model"), .used_in = &.{ plain("Daily"), plain("App") }, .where = plain("Box"), .file = "/private/models/draft-model.bin" },
    .comp = .{ .name = plain("Comp model"), .short = plain("Comp model"), .used_in = &.{}, .where = plain("Lab"), .file = "/private/lab/draft-model.bin" },
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
    loads: std.enums.EnumArray(Which, Load) = .initFill(.none),
    /// By side (0 blue) and role; 0 empty
    teams: [2][n_role]u32 = @splat(@splat(0)),
    /// The seat being filled: side * n_role + role, side 0 blue; null: the first empty
    seat: ?u8 = null,
    /// Filled from the front; 0 empty
    bans: [n_ban]u32 = @splat(0),
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
    /// `n` the bans
    pub const Url = struct {
        m: Which = .live,
        b: [n_role]u32 = @splat(0),
        r: [n_role]u32 = @splat(0),
        s: ?u8 = null,
        t: Tab = .board,
        n: [n_ban]u32 = @splat(0),
    };

    /// `unban`: the ban's index
    pub const Msg = union(enum) { model: Which, tab: Tab, seat: u8, clear, ban, unban: u8 };

    pub fn useIndex(p: *Page, ix: *const champsearch.Index) void {
        p.search.index = ix;
        p.has_index = true;
    }

    pub fn init(head: *const Head) Page {
        return .{ .head = head };
    }

    pub fn toUrl(p: *const Page) Url {
        return .{ .m = p.which, .b = p.teams[0], .r = p.teams[1], .s = p.seat, .t = p.tab, .n = p.bans };
    }

    /// The other island's change (a pick) or Back: saved again when it moved the board
    pub fn fromUrl(p: *Page, u: Url) void {
        const teams = clean(p.head, .{ u.b, u.r });
        const bans = cleanBans(p.head, u.n, teams);
        if (u.m != p.which or !std.meta.eql(teams, p.teams) or !std.meta.eql(bans, p.bans)) p.dirty = true;
        p.which = u.m;
        p.teams = teams;
        p.bans = bans;
        p.seat = if (u.s) |i| (if (i < 2 * n_role) i else null) else null;
        p.tab = u.t;
    }

    pub fn update(p: *Page, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .model => |w| {
                p.which = w;
                // Chosen again after a failure: the page's code fetches it again
                switch (p.loads.get(w)) {
                    .failed, .bad => p.loads.set(w, .none),
                    else => {},
                }
                p.dirty = true;
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
                p.dirty = true;
            },
            .ban => {
                const e = p.search.chosen orelse return;
                p.search.chosen = null;
                ev.after = .{ .op = .focus, .ref = "input" };
                if (e >= p.head.champs.len) return;
                const id = p.head.champs[e].id;
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

    /// The model the page shows, once fetched
    pub fn ready(p: *const Page) ?*const Loaded {
        return switch (p.loads.get(p.which)) {
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
            .failed => W.failed,
            .bad => W.bad_file,
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
        return h.div(.{ .class = "bd" }, .{
            draftboard.fullOn(h, .{ .v = .full, .lanes = &lanes }, &on),
            p.bansRow(h),
            button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .clear) }, .{W.clear}),
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
        const pts: ?f64 = if (l) |x| (if (id != 0) seatPoints(x, p.teams, side, r) else null) else null;
        return .{
            .champ = p.icon(h, id),
            .state = if (id != 0) .locked else .empty,
            .sub = if (pts) |x| W.seat_pts.with(h, .{ .p = x }) else .{ .s = "" },
            .sel = if (shownSeat(p.teams, p.seat)) |i| i == @as(usize, side) * n_role + r else false,
        };
    }

    fn termsView(p: *Page, h: *H) N {
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
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    if (ymd.len != 10) return ymd;
    const m = std.fmt.parseInt(u8, ymd[5..7], 10) catch return ymd;
    const d = std.fmt.parseInt(u8, ymd[8..10], 10) catch return ymd;
    if (m < 1 or m > 12) return ymd;
    return h.fmt("{d} {s}", .{ d, months[m - 1] });
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
    try w.print("{d}", .{@backingInt(p.which)});
    for (p.teams, 0..) |team, s| for (team, 0..) |id, r| try w.print("{s}{d}", .{ if (s == 0 and r == 0) " " else ",", id });
    if (p.bans[0] != 0) for (p.bans, 0..) |id, i| try w.print("{s}{d}", .{ if (i == 0) " " else ",", id });
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
    while (it.next()) |kv| if (std.mem.startsWith(u8, kv, "m=")) return true;
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
