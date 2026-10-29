//! GameArt: an item, rune, rune tree, stat shard or summoner spell icon. Items and spells
//! are rounded squares, runes and shards round; dim greys an option not taken (a rune
//! page's other runes). The name is its alt unless written beside it
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "GameArt";
pub const scope = .{".c-art"};

pub const Art = struct {
    name: []const u8,
    /// A `local` path, or a full URL (CommunityDragon for shards); "" draws an empty square
    src: []const u8,
};

pub const Kind = enum { item, rune, spell };
pub const Px = enum { @"16", @"20", @"22", @"28", @"36" };

pub const Opts = struct {
    k: Kind = .item,
    px: Px = .@"22",
    dim: bool = false,
    /// False when the name is written beside the icon
    named: bool = true,
};

pub fn view(h: *H, a: Art, o: Opts) N {
    const px: u8 = switch (o.px) {
        inline else => |p| comptime parse(@tagName(p)),
    };
    const alt = if (o.named) a.name else "";
    const k: ?Kind = if (o.k == .item) null else o.k;
    const px_attr: ?Px = if (o.px == .@"22") null else o.px;
    if (a.src.len == 0) return h.span(.{
        .class = "c-art",
        .data_k = k,
        .data_s = px_attr,
        .role = if (alt.len > 0) "img" else null,
        .aria_label = if (alt.len > 0) alt else null,
    }, .{});
    return h.img(.{
        .class = "c-art",
        .data_k = k,
        .data_s = px_attr,
        .data_state = if (o.dim) "dim" else null,
        .src = a.src,
        .alt = alt,
        .width = px,
        .height = px,
        .loading = "lazy",
    });
}

fn parse(comptime s: []const u8) u8 {
    var v: u8 = 0;
    for (s) |d| v = v * 10 + (d - '0');
    return v;
}

pub const css =
    \\@layer components {
    \\  .c-art { --sz: 22px; display: inline-block; flex: none; vertical-align: middle; width: var(--sz); height: var(--sz);
    \\    border-radius: var(--r-s); background: var(--panel-3); }
    \\  .c-art[data-s="16"] { --sz: 16px; }
    \\  .c-art[data-s="20"] { --sz: 20px; }
    \\  .c-art[data-s="28"] { --sz: 28px; }
    \\  .c-art[data-s="36"] { --sz: 36px; }
    \\  .c-art[data-k="rune"] { border-radius: 50%; background: none; }
    \\  .c-art[data-k="spell"] { border-radius: 3px; }
    \\  .c-art[data-state="dim"] { opacity: 0.3; filter: grayscale(1); }
    \\}
    \\
;

pub const demo_version = "16.21.1";
/// The patch of demo_version ("16.21"), whose art the site makes too
pub const demo_patch = demo_version[0..std.mem.findScalarLast(u8, demo_version, '.').?];

const dd = "https://ddragon.leagueoflegends.com/cdn/";
const site_dd = "/dd/";

/// Where the site serves Data Dragon's item, spell and rune `url` (src/icons.zig makes
/// them: a rune shrunk, items and spells as JPEG): /dd/ and the path under its cdn/; a
/// path not made yet redirects to `remote`'s. Any other URL as it is
pub fn local(a: std.mem.Allocator, url: []const u8) ![]const u8 {
    const rest = if (std.mem.startsWith(u8, url, dd)) url[dd.len..] else return url;
    if (!std.mem.endsWith(u8, rest, ".png")) return url;
    if (std.mem.startsWith(u8, rest, "img/perk-images/")) return std.mem.concat(a, u8, &.{ site_dd, rest });
    var parts = std.mem.splitScalar(u8, rest, '/');
    const version = parts.next().?;
    if (version.len == 0 or !std.ascii.isDigit(version[0]) or !std.mem.eql(u8, parts.next() orelse "", "img")) return url;
    const kind = parts.next() orelse return url;
    if (!std.mem.eql(u8, kind, "item") and !std.mem.eql(u8, kind, "spell")) return url;
    return std.mem.concat(a, u8, &.{ site_dd, rest[0 .. rest.len - 4], ".jpg" });
}

/// Data Dragon's URL for a `local` path, else null
pub fn remote(a: std.mem.Allocator, path: []const u8) !?[]const u8 {
    if (!std.mem.startsWith(u8, path, site_dd)) return null;
    const rest = path[site_dd.len..];
    if (!std.mem.endsWith(u8, rest, ".jpg") and !std.mem.endsWith(u8, rest, ".png")) return null;
    return try std.mem.concat(a, u8, &.{ dd, rest[0 .. rest.len - 4], ".png" });
}

/// Gallery icons from Data Dragon, as `local` makes them
pub fn item(comptime id: []const u8, comptime shown: []const u8) Art {
    return .{ .name = shown, .src = site_dd ++ demo_version ++ "/img/item/" ++ id ++ ".jpg" };
}

pub fn spell(comptime key: []const u8, comptime shown: []const u8) Art {
    return .{ .name = shown, .src = site_dd ++ demo_version ++ "/img/spell/Summoner" ++ key ++ ".jpg" };
}

/// `path` under perk-images/Styles/
pub fn rune(comptime path: []const u8, comptime shown: []const u8) Art {
    return .{ .name = shown, .src = site_dd ++ "img/perk-images/Styles/" ++ path ++ ".png" };
}

test "local and remote: item, spell and rune art one way and back; others as given" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cases = [_][2][]const u8{
        .{ dd ++ "16.21.1/img/item/1058.png", "/dd/16.21.1/img/item/1058.jpg" },
        .{ dd ++ "16.21.1/img/spell/SummonerFlash.png", "/dd/16.21.1/img/spell/SummonerFlash.jpg" },
        .{ dd ++ "img/perk-images/Styles/Sorcery/DeathfireTouch/DEATHFIRE_TOUCH_KEYSTONE.png", "/dd/img/perk-images/Styles/Sorcery/DeathfireTouch/DEATHFIRE_TOUCH_KEYSTONE.png" },
    };
    for (cases) |c| {
        try std.testing.expectEqualStrings(c[1], try local(a, c[0]));
        try std.testing.expectEqualStrings(c[0], (try remote(a, c[1])).?);
    }
    for ([_][]const u8{ dd ++ "16.21.1/img/champion/Ahri.png", dd ++ "16.21.1/img/profileicon/1.png", "https://raw.communitydragon.org/x.png", "" }) |u|
        try std.testing.expectEqualStrings(u, try local(a, u));
    try std.testing.expectEqualStrings(item("1058", "x").src, try local(a, dd ++ demo_version ++ "/img/item/1058.png"));
    try std.testing.expectEqual(null, try remote(a, "/icon/16.21.1/Ahri.jpg"));
    try std.testing.expectEqualStrings("16.21", demo_patch);
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("item 36, 28, 22, 20, 16", h.div(.{ .class = "g-row" }, .{
        view(h, item("3742", "Dead Man's Plate"), .{ .px = .@"36" }),
        view(h, item("3742", "Dead Man's Plate"), .{ .px = .@"28" }),
        view(h, item("3742", "Dead Man's Plate"), .{}),
        view(h, item("3742", "Dead Man's Plate"), .{ .px = .@"20" }),
        view(h, item("3742", "Dead Man's Plate"), .{ .px = .@"16" }),
    }));
    g.add("rune, tree, spell", h.div(.{ .class = "g-row" }, .{
        view(h, rune("Precision/Conqueror/Conqueror", "Conqueror"), .{ .k = .rune, .px = .@"36" }),
        view(h, rune("7201_Precision", "Precision"), .{ .k = .rune, .px = .@"20" }),
        view(h, spell("Flash", "Flash"), .{ .k = .spell }),
    }));
    g.add("dim, no icon", h.div(.{ .class = "g-row" }, .{
        view(h, rune("Precision/LethalTempo/LethalTempoTemp", "Lethal Tempo"), .{ .k = .rune, .px = .@"28", .dim = true }),
        view(h, .{ .name = "Armor", .src = "" }, .{ .k = .rune, .px = .@"20" }),
    }));
}
