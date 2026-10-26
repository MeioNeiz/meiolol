//! The game page (game.html) from `meiolol your-example`'s file: each role's player's
//! games as ui.gamedata.Data (api/game.zig's Game with its Detail) in data/your/<role>.bin,
//! and the file again without the detail for the pages that read it whole (home,
//! your.html): twice the bytes otherwise
const std = @import("std");
const ui = @import("ui");
const game = @import("../api/game.zig");
const ddragon = @import("../ddragon.zig");
const Date = @import("../date.zig").Date;
const html = @import("html.zig");
const assets = @import("assets.zig");
const root = @import("root.zig");
const Champ = root.Champ;
const Site = root.Site;
const File = root.File;

const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const gd = ui.gamedata;
const log = std.log.scoped(.site);

pub const page_path = "game.html";
pub const example_path = "data/your-example.json";
const data_dir = "data/your/";
const roles = [_][]const u8{ "top", "jungle", "mid", "bot", "support" };

/// The example's files: itself stripped, then each role's games, the default role's
/// first (writePage reads that one; the views file keeps no other field for it)
pub fn files(site: *const Site, json: []const u8, out: *std.ArrayList(File)) !void {
    const a = site.arena;
    // Unreadable: as it is, for your.js to report
    try out.append(a, .{ .path = example_path, .data = stripped(a, json) catch json });
    const ex = parse(a, json) catch |err| return log.warn("your example: {t}", .{err});
    var order: [roles.len + 1][]const u8 = undefined;
    order[0] = ex.default;
    @memcpy(order[1..], &roles);
    for (order, 0..) |r, i| {
        if (i > 0 and std.mem.eql(u8, r, ex.default)) continue;
        const pl = ex.player(r) orelse continue;
        const report = pl.report orelse continue;
        const d = try data(a, site.champs, names(site), report.games, site, siteIcon);
        if (d.games.len == 0) continue;
        var bytes: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, gd.Data, d, &bytes);
        try out.append(a, .{ .path = try a.print(data_dir ++ "{s}.bin", .{r}), .data = bytes.items });
    }
}

/// Items, spells and runes from the view's builds file; none without one (icons then
/// draw empty)
fn names(site: *const Site) Names {
    const f = &(site.view_builds[site.view.index()] orelse return .{ .version = site.ddragon_version });
    return .{ .version = site.ddragon_version, .items = f.items, .spells = f.spells, .runes = f.runes };
}

fn siteIcon(site: *const Site, ch: Champ) anyerror![]const u8 {
    return site.icon(ch);
}

/// The default role's newest game; false without the example's files
pub fn writePage(site: *const Site, w: *Writer) !bool {
    const f = for (site.daily_files) |f| {
        if (std.mem.startsWith(u8, f.path, data_dir)) break f;
    } else return false;
    const a = site.arena;
    const d = try a.create(gd.Data);
    d.* = try ui.data.decode(a, gd.Data, f.data);
    if (d.games.len == 0) return false;
    var p = try site.sharedPage("Your game | meiolol", "One ranked game minute by minute: your team's win chance, the fights and objectives that moved it, and each player's part.", .your);
    p.index = false;
    try html.head(w, p);
    var gp: ui.gamepage.GamePage = try .init(a, d);
    gp.all = ui.gamepage.all_games;
    gp.src = f.path;
    gp.stamp = gd.stamp(f.data);
    var more: ui.gamepage.GameMore = .{
        .s = gp,
        .js = assets.gamemore_js.path,
        .wasm = assets.gamemore_wasm.path,
    };
    var lane: ui.gamepage.GameLane = .{
        .a = a,
        .data = d,
        .src = f.path,
        .stamp = gp.stamp,
        .js = assets.gamelane_js.path,
        .wasm = assets.gamelane_wasm.path,
    };
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    t.root = ui.gamepage.page(&h, gp.view(&h), more.view(&h), lane.view(&h));
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    // Only GamePage's: it loads GameMore's and GameLane's (ui/wasm/games.zig)
    try html.tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{
        .js = html.Link{ .root = "", .path = assets.games_js.path },
        .wasm = assets.games_wasm.path,
    });
    try html.foot(w, p);
    return true;
}

pub const Example = struct {
    default: []const u8,
    top: ?Player = null,
    jungle: ?Player = null,
    mid: ?Player = null,
    bot: ?Player = null,
    support: ?Player = null,

    /// No report: the role's player isn't ready
    pub const Player = struct { report: ?struct { games: []const game.Game } = null };

    pub fn player(e: Example, role: []const u8) ?Player {
        inline for (.{ "top", "jungle", "mid", "bot", "support" }) |r| {
            if (std.mem.eql(u8, role, r)) return @field(e, r);
        }
        return null;
    }
};

pub fn parse(arena: Allocator, json: []const u8) !Example {
    var v = try std.json.parseFromSliceLeaky(std.json.Value, arena, json, .{});
    try fillNulls(Example, arena, &v);
    return std.json.parseFromValueLeaky(Example, arena, v, .{ .ignore_unknown_fields = true });
}

/// The example leaves null fields out (api/example.zig), and std.json wants every
/// field without a default
fn fillNulls(comptime T: type, arena: Allocator, v: *std.json.Value) Allocator.Error!void {
    switch (@typeInfo(T)) {
        .optional => |o| if (v.* != .null) try fillNulls(o.child, arena, v),
        .pointer => |p| if (p.size == .slice and p.child != u8 and v.* == .array) {
            for (v.array.items) |*x| try fillNulls(p.child, arena, x);
        },
        .@"struct" => |s| if (v.* == .object) inline for (s.field_names, s.field_types, s.field_attrs) |name, F, at| {
            if (v.object.getPtr(name)) |x| {
                try fillNulls(F, arena, x);
            } else if (@typeInfo(F) == .optional and at.default_value_ptr == null) {
                try v.object.put(arena, name, .null);
            }
        },
        else => {},
    }
}

/// `json` with every game's `detail` left out
pub fn stripped(arena: Allocator, json: []const u8) ![]u8 {
    const v = try std.json.parseFromSliceLeaky(std.json.Value, arena, json, .{});
    if (v != .object) return error.BadExample;
    for (v.object.values()) |p| {
        if (p != .object) continue;
        const r = p.object.get("report") orelse continue;
        if (r != .object) continue;
        const games = r.object.get("games") orelse continue;
        if (games != .array) continue;
        for (games.array.items) |*g| if (g.* == .object) {
            _ = g.object.orderedRemove("detail");
        };
    }
    return std.json.Stringify.valueAlloc(arena, v, .{});
}

const queues = [_]struct { i64, []const u8 }{
    .{ 420, "Ranked solo" }, .{ 440, "Ranked flex" }, .{ 400, "Draft" }, .{ 480, "Swiftplay" },
};

const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

/// Data Dragon's names and icons, sorted by id (ddragon.find)
pub const Names = struct {
    /// Data Dragon's version, for items the lists don't name (potions, wards, parts)
    version: []const u8 = "",
    items: []const ddragon.Named = &.{},
    spells: []const ddragon.Named = &.{},
    runes: []const ddragon.Named = &.{},
};

/// Data.arts, each item, spell and rune once
const Arts = struct {
    names: Names,
    list: std.ArrayList(ui.art.Art) = .empty,
    /// Kind in the high bits, so an item and a rune with one id stay apart
    keys: std.ArrayList(u64) = .empty,

    const Kind = enum(u2) { item, spell, rune };

    fn at(x: *Arts, a: Allocator, k: Kind, id: u32) !u16 {
        if (id == 0) return gd.no_art;
        const key = @as(u64, @backingInt(k)) << 32 | id;
        if (std.mem.findScalar(u64, x.keys.items, key)) |i| return @intCast(i);
        if (x.list.items.len >= gd.no_art) return gd.no_art;
        const list = switch (k) {
            .item => x.names.items,
            .spell => x.names.spells,
            .rune => x.names.runes,
        };
        var art: ui.art.Art = if (ddragon.find(list, id)) |v| .{ .name = v.name, .src = v.icon } else .{ .name = try a.print("#{d}", .{id}), .src = "" };
        if (art.src.len == 0 and k == .item and x.names.version.len > 0)
            art.src = try a.print("https://ddragon.leagueoflegends.com/cdn/{s}/img/item/{d}.png", .{ x.names.version, id });
        try x.list.append(a, art);
        try x.keys.append(a, key);
        return @intCast(x.list.items.len - 1);
    }
};

/// Games with a timeline and its detail; `icon` makes a portrait URL
pub fn data(arena: Allocator, champs: []const Champ, nm: Names, games: []const game.Game, ctx: anytype, icon: fn (@TypeOf(ctx), Champ) anyerror![]const u8) !gd.Data {
    var used: std.ArrayList(ui.champ.Champ) = .empty;
    var ids: std.ArrayList(u32) = .empty;
    var arts: Arts = .{ .names = nm };
    var out: std.ArrayList(gd.Game) = .empty;
    for (games) |g| {
        const d = g.detail orelse continue;
        if (g.players.len != d.seats.len or g.players.len > 10 or g.win_chance.len < 2) continue;
        const you = for (g.players, 0..) |p, i| {
            if (p.you) break i;
        } else continue;
        const team = g.players[you].team;

        const seats = try arena.alloc(gd.Seat, g.players.len);
        for (g.players, d.seats, seats) |p, st, *o| {
            const at = std.mem.findScalar(u32, ids.items, p.champion) orelse blk: {
                const ch = for (champs) |c| {
                    if (c.id == p.champion) break c;
                } else return error.UnknownChampion;
                try ids.append(arena, p.champion);
                try used.append(arena, .{ .name = ch.name, .src = try icon(ctx, ch) });
                break :blk ids.items.len - 1;
            };
            o.* = .{
                .champ = @intCast(at),
                .us = p.team == team,
                .role = if (p.role) |r| std.meta.stringToEnum(ui.role.Role, r) else null,
                .k = @intCast(std.math.clamp(p.kills, 0, 999)),
                .d = @intCast(std.math.clamp(p.deaths, 0, 999)),
                .a = @intCast(std.math.clamp(p.assists, 0, 999)),
                .riot_id = p.riot_id orelse "",
                .cs = @intCast(@min(st.cs, std.math.maxInt(u16))),
                .gold = st.gold,
                .level = st.level,
                .damage = st.damage,
                .taken = st.taken,
                .lane14 = st.lane14,
            };
            const lo = p.loadout;
            for (lo.items, &o.items) |id, *x| x.* = try arts.at(arena, .item, id);
            for (lo.spells, &o.spells) |id, *x| x.* = try arts.at(arena, .spell, id);
            o.keystone = try arts.at(arena, .rune, lo.keystone);
            o.second = try arts.at(arena, .rune, lo.second);
            // All zero: a summary from before loadouts
            if (!std.meta.eql(lo, game.Loadout{})) o.vision = @intCast(@min(lo.vision, std.math.maxInt(u16)));
        }
        const buys = try arena.alloc(gd.Buy, d.buys.len);
        for (d.buys, buys) |b, *o| o.* = .{ .t = secs(b.t_s), .item = try arts.at(arena, .item, b.item) };
        const skills = try arena.alloc(u8, d.skills.len);
        for (d.skills, skills) |k, *o| o.* = if (k >= 1 and k <= 4) "QWER"[k - 1] else '?';

        const kills = try arena.alloc(gd.Kill, d.kills.len);
        for (d.kills, kills) |k, *o| {
            const assists = try arena.alloc(u8, k.assists.len);
            for (k.assists, assists) |x, *y| y.* = @intCast(@min(x, gd.no_slot));
            o.* = .{ .t = secs(k.t_s), .killer = k.killer, .victim = k.victim, .assists = assists, .x = k.x, .y = k.y, .gold = @intCast(@min(k.gold, std.math.maxInt(u16))), .fight = k.fight };
        }
        const objs = try arena.alloc(gd.Obj, d.objectives.len);
        for (d.objectives, objs) |o, *x| x.* = .{
            .t = secs(o.t_s),
            .ours = o.ours,
            .kind = std.meta.stringToEnum(gd.ObjKind, @tagName(o.kind)).?,
            .name = o.name,
            .you = o.you,
        };
        const wc = try arena.alloc(u8, g.win_chance.len);
        for (g.win_chance, wc) |v, *o| o.* = @intCast(@min(v, 100));
        // gold_lead has the game's last frame too; the page reads it by minute
        const gold = try arena.dupe(i32, d.gold_lead[0..@min(d.gold_lead.len, wc.len)]);

        const date: Date = .fromMs(g.start_ms);
        const queue = for (queues) |q| {
            if (q[0] == g.queue) break q[1];
        } else "Normal";
        try out.append(arena, .{
            .day = try arena.print("{d} {s}", .{ date.day, months[date.month - 1] }),
            .patch = g.patch,
            .queue = queue,
            .dur = secs(@intCast(@max(0, g.duration_s))),
            .win = g.win,
            .you = @intCast(you),
            .seats = seats,
            .wc = wc,
            .gold = gold,
            .kills = kills,
            .objs = objs,
            .best = if (g.best_minute) |b| .{ .minute = b.minute, .gold = b.gold } else null,
            .buys = buys,
            .skills = skills,
            .lane = if (g.lane) |l| laneOf(l) else null,
        });
    }
    return .{ .champs = used.items, .games = out.items, .arts = arts.list.items };
}

/// The curve's minutes with this many games; api/game.zig reads it the same way
const min_minute_games = 10;

fn laneOf(l: game.LaneReport) gd.Lane {
    const stretch = struct {
        fn f(x: ?game.Stretch) ?gd.Lane.Stretch {
            const v = x orelse return null;
            return .{ .from = v.from, .to = v.to, .change = v.change };
        }
    }.f;
    var out: gd.Lane = .{
        .gold = l.gold,
        .xp = l.xp,
        .cs = l.cs,
        .cs10 = if (l.cs10) |c| @intCast(std.math.clamp(c, 0, std.math.maxInt(u16))) else null,
        .kills = @intCast(@min(l.lane_kills, 255)),
        .deaths = @intCast(@min(l.lane_deaths, 255)),
        .level6 = l.level6,
        .first_item = l.first_item,
        .fall = stretch(l.fall),
        .rise = stretch(l.rise),
    };
    const c = l.curve orelse return out;
    var m: usize = 0;
    while (m < c.n.len and c.n[m] >= min_minute_games) m += 1;
    if (m == 0) return out;
    out.typical = .{
        .games = c.games,
        .bracket = c.bracket,
        .gold = c.gold[0..@min(m, c.gold.len)],
        .xp = c.xp[0..@min(m, c.xp.len)],
        .cs = c.cs[0..@min(m, c.cs.len)],
        .level6 = c.level6[0],
        .first_item = c.first_item[0],
    };
    return out;
}

fn secs(s: u32) u16 {
    return @intCast(@min(s, std.math.maxInt(u16)));
}

const testing = std.testing;

test "a game with its detail maps every kill, objective and seat" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const raw = try @import("store").raw.decompress(arena, @embedFile("../riot/testdata/timeline.json.gz"));
    const t = try @import("../riot/root.zig").timeline.fromJson(arena, raw);
    const players = try arena.alloc(game.Summary.Player, 10);
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    var champs: [10]Champ = undefined;
    for (players, &champs, 0..) |*p, *c, i| {
        p.* = .{ .hash = "", .team = if (i < 5) 100 else 200, .position = positions[i % 5], .champion = @intCast(i + 1), .win = i < 5, .kills = 0, .deaths = 0, .assists = 0 };
        c.* = .{ .c = i, .id = @intCast(i + 1), .key = "Ahri", .name = "Ahri", .slug = "ahri", .banned = 0, .games = 0 };
    }
    const s: game.Summary = .{ .patch = "16.20", .queue = 420, .start_ms = 1791720000000, .duration_s = 1800, .remake = false, .players = players };
    const g = try game.analyse(arena, .{ .summary = s, .slot = 6, .timeline = t, .detail = true }, .{}, .{});
    const icon = struct {
        fn f(_: void, c: Champ) anyerror![]const u8 {
            return c.key;
        }
    }.f;
    const d = try data(arena, &champs, .{}, &.{ g, try game.analyse(arena, .{ .summary = s, .slot = 0, .timeline = null }, .{}, .{}) }, {}, icon);
    // The game without a timeline has no page
    try testing.expectEqual(@as(usize, 1), d.games.len);
    const p = d.games[0];
    try testing.expectEqual(@as(u8, 6), p.you);
    try testing.expectEqual(ui.role.Role.jungle, p.me().role.?);
    try testing.expectEqual(@as(?u8, 1), p.opponent());
    try testing.expect(!p.seats[0].us and p.seats[9].us);
    try testing.expectEqual(g.detail.?.kills.len, p.kills.len);
    try testing.expectEqual(g.detail.?.objectives.len, p.objs.len);
    try testing.expectEqual(p.wc.len, p.gold.len);
    try testing.expectEqual(g.detail.?.skills.len, p.skills.len);
    try testing.expectEqual(g.detail.?.buys.len, p.buys.len);
    try testing.expect(p.lane != null);
    // No loadout in this summary: empty slots, no vision
    try testing.expectEqual(gd.no_art, p.me().items[0]);
    try testing.expectEqual(@as(?u16, null), p.me().vision);
    try testing.expectEqual(@as(usize, 10), d.champs.len);
    try testing.expectEqualStrings("Ranked solo", p.queue);
    const turn, _ = gd.turns(p.wc);
    try testing.expectEqual(g.turning.?.minute, turn.?.minute);
}

test "stripped drops only the detail" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const json =
        \\{"default":"mid","mid":{"state":"ready","report":{"games":[{"win":true,"detail":{"kills":[]}}],"weeks":[]}}}
    ;
    try testing.expectEqualStrings(
        \\{"default":"mid","mid":{"state":"ready","report":{"games":[{"win":true}],"weeks":[]}}}
    , try stripped(arena, json));
}
