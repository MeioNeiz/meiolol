//! GameArt: an item, rune, rune tree, stat shard or summoner spell icon. Items and spells
//! are rounded squares, runes and shards round; dim greys an option not taken (a rune
//! page's other runes). The name is its alt unless written beside it
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "GameArt";
pub const scope = .{".c-art"};

pub const Art = struct {
    name: []const u8,
    /// Full URL (Data Dragon, CommunityDragon for shards); "" draws an empty square
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
const dd = "https://ddragon.leagueoflegends.com/cdn/";

/// Gallery icons from Data Dragon
pub fn item(comptime id: []const u8, comptime shown: []const u8) Art {
    return .{ .name = shown, .src = dd ++ demo_version ++ "/img/item/" ++ id ++ ".png" };
}

pub fn spell(comptime key: []const u8, comptime shown: []const u8) Art {
    return .{ .name = shown, .src = dd ++ demo_version ++ "/img/spell/Summoner" ++ key ++ ".png" };
}

/// `path` under perk-images/Styles/
pub fn rune(comptime path: []const u8, comptime shown: []const u8) Art {
    return .{ .name = shown, .src = dd ++ "img/perk-images/Styles/" ++ path ++ ".png" };
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
