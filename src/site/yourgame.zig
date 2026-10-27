//! The game page (game.html) from `meiolol your-example`'s file: each role's player's
//! games as ui.gamedata.Data (api/game.zig's Game with its Detail) in data/your/<role>.bin,
//! and the file again without the detail for the pages that read it whole (home,
//! your.html): twice the bytes otherwise
const std = @import("std");
const ui = @import("ui");
const game = @import("../api/game.zig");
const html = @import("html.zig");
const assets = @import("assets.zig");
const root = @import("root.zig");
const pagedata = @import("../api/pagedata.zig");
const Site = root.Site;
const File = root.File;

const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const gd = ui.gamedata;
const log = std.log.scoped(.site);

pub const page_path = "game.html";
pub const example_path = "data/your-example.json";
const data_dir = "data/your/";
pub const list_path = data_dir ++ "list.bin";
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
        const d = try pagedata.data(a, names(site), report.games, site, siteChamp);
        if (d.games.len == 0) continue;
        var bytes: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, gd.Data, d, &bytes);
        try out.append(a, .{ .path = try a.print(data_dir ++ "{s}.bin", .{r}), .data = bytes.items });
    }
    // After the role files: writePage reads the first file in data_dir
    if (ex.player(ex.default)) |pl| if (pl.report) |report| {
        const l = try pagedata.list(a, pl.player orelse .{}, report.games, names(site), site, siteChamp);
        var bytes: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, ui.yourlist.List, l, &bytes);
        try out.append(a, .{ .path = list_path, .data = bytes.items });
    };
}

/// Items, spells and runes from the view's builds file; none without one (icons then
/// draw empty)
fn names(site: *const Site) pagedata.Names {
    const f = &(site.view_builds[site.view.index()] orelse return .{ .version = site.ddragon_version });
    return .{ .version = site.ddragon_version, .items = f.items, .spells = f.spells, .runes = f.runes };
}

fn siteChamp(site: *const Site, id: u32) anyerror!ui.champ.Champ {
    const ch = for (site.champs) |c| {
        if (c.id == id) break c;
    } else return error.UnknownChampion;
    return .{ .name = ch.name, .src = try site.icon(ch) };
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
    pub const Player = struct {
        player: ?Who = null,
        report: ?struct { games: []const game.Game } = null,
    };

    pub const Who = pagedata.Who;

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

const testing = std.testing;

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
