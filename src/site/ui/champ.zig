//! ChampIcon: a champion's square portrait, 20 to 48 px, with the states a seat or a row
//! needs: thin data faded, banned struck, dead greyed with a cross, an empty seat dashed,
//! a suggestion not yet yours (dashed accent ring), a side's ring, the player's own ring,
//! a level, and a role badge in the corner
const tree = @import("tree.zig");
const role = @import("role.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "ChampIcon";
pub const scope = .{".c-champ"};

pub const Champ = struct {
    name: []const u8,
    /// The portrait's URL (Site.icon)
    src: []const u8,
};

pub const Px = enum { @"20", @"24", @"32", @"40", @"48", @"56" };

pub const State = enum { normal, thin, banned, dead, empty, add };

pub const Opts = struct {
    px: Px = .@"24",
    state: State = .normal,
    side: ?enum { us, them } = null,
    /// The player's own seat
    you: bool = false,
    level: ?u8 = null,
    role: ?role.Role = null,
    /// False when the champion's name is written beside the icon
    named: bool = true,
    /// What an empty seat stands for ("Hidden seat")
    label: ?tree.Text = null,
    /// Above the fold (a page's own champion): not lazy
    eager: bool = false,
};

/// `c` null: an empty seat
pub fn view(h: *H, c: ?Champ, o: Opts) N {
    const px: u8 = switch (o.px) {
        inline else => |p| comptime parse(@tagName(p)),
    };
    const pic: ?N = if (c) |x| h.img(.{
        .src = x.src,
        .alt = if (o.named) x.name else "",
        .width = px,
        .height = px,
        .loading = if (o.eager) null else "lazy",
    }) else null;
    const empty = c == null;
    return h.span(.{
        .class = "c-champ",
        .data_s = if (o.px == .@"24") null else o.px,
        .data_state = if (empty) @as(?State, .empty) else if (o.state == .normal) null else o.state,
        .data_side = o.side,
        .data_you = o.you,
        .role = if (empty and o.label != null) "img" else null,
        .aria_label = if (empty) o.label else null,
    }, .{
        pic,
        if (o.role) |r| role.view(h, r, .{ .named = false }) else null,
        if (o.level) |l| h.span(.{ .class = "lvl" }, .{l}) else null,
    });
}

fn parse(comptime s: []const u8) u8 {
    var v: u8 = 0;
    for (s) |d| v = v * 10 + (d - '0');
    return v;
}

pub const css =
    \\@layer components {
    \\  .c-champ { --sz: var(--icon); position: relative; display: inline-block; flex: none; vertical-align: middle;
    \\    width: var(--sz); height: var(--sz); border-radius: calc(var(--sz) / 6); background: var(--panel-3); }
    \\  .c-champ > img { display: block; width: 100%; height: 100%; border-radius: inherit; }
    \\  .c-champ[data-s="20"] { --sz: var(--icon-s); }
    \\  .c-champ[data-s="32"] { --sz: var(--icon-m); }
    \\  .c-champ[data-s="40"] { --sz: 40px; }
    \\  .c-champ[data-s="48"] { --sz: var(--icon-l); }
    \\  .c-champ[data-s="56"] { --sz: 56px; }
    \\  .c-champ[data-state="thin"] > img { opacity: 0.45; }
    \\  .c-champ[data-state="banned"] > img { opacity: 0.85; filter: saturate(0.35); }
    \\  .c-champ[data-state="banned"]::after { content: ""; position: absolute; inset: 0;
    \\    border-radius: inherit; box-shadow: inset 0 0 0 1.5px var(--lo3);
    \\    background: linear-gradient(to top right, transparent calc(50% - 1px), var(--lo3) calc(50% - 1px),
    \\      var(--lo3) calc(50% + 1px), transparent calc(50% + 1px)); }
    \\  .c-champ[data-state="dead"] > img { filter: grayscale(1) brightness(0.6); }
    \\  .c-champ[data-state="dead"]::after { content: ""; position: absolute; right: -3px; bottom: -3px;
    \\    width: 12px; height: 12px; border-radius: 50%; box-shadow: 0 0 0 1.5px var(--bg);
    \\    background: linear-gradient(45deg, transparent 43%, var(--text) 43% 57%, transparent 57%) center / 7px 7px no-repeat,
    \\      linear-gradient(-45deg, transparent 43%, var(--text) 43% 57%, transparent 57%) center / 7px 7px no-repeat, var(--them); }
    \\  .c-champ[data-state="empty"] { background: none; border: 1.5px dashed var(--line-2); box-sizing: border-box; }
    \\  .c-champ[data-state="add"] { outline: 1.5px dashed var(--accent); outline-offset: 2px; }
    \\  .c-champ[data-side="us"] { box-shadow: 0 0 0 2px var(--bg), 0 0 0 3.5px var(--us); }
    \\  .c-champ[data-side="them"] { box-shadow: 0 0 0 2px var(--bg), 0 0 0 3.5px var(--them); }
    \\  .c-champ[data-you] { box-shadow: 0 0 0 2px var(--bg), 0 0 0 3.5px var(--accent); }
    \\  .c-champ > .c-role { position: absolute; right: -3px; bottom: -3px; width: 45%; height: 45%;
    \\    min-width: 12px; min-height: 12px; border-radius: 3px; color: var(--text);
    \\    background: var(--bg); mask: none; }
    \\  .c-champ > .c-role::before { content: ""; position: absolute; inset: 1px; background: currentColor;
    \\    mask: var(--ri) center / contain no-repeat; }
    \\  .c-champ > .lvl { position: absolute; right: -4px; bottom: -4px; padding: 0 3px; border-radius: var(--r-pill);
    \\    background: var(--bg); border: 1px solid var(--line-2); font-size: var(--fs-xs); line-height: 1.2;
    \\    font-variant-numeric: tabular-nums; color: var(--t2); }
    \\}
    \\
;

pub const demo_version = "16.21.1";

/// A gallery portrait from Data Dragon
pub fn demo(comptime key: []const u8, comptime shown: []const u8) Champ {
    return .{ .name = shown, .src = "https://ddragon.leagueoflegends.com/cdn/" ++ demo_version ++ "/img/champion/" ++ key ++ ".png" };
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const ahri = demo("Ahri", "Ahri");
    var sizes = h.list();
    for ([_]Px{ .@"56", .@"48", .@"40", .@"32", .@"24", .@"20" }) |p| sizes.add(view(h, ahri, .{ .px = p }));
    g.add("56, 48, 40, 32, 24, 20", h.div(.{ .class = "g-row" }, .{sizes.done()}));
    g.add("role, sides, you and level", h.div(.{ .class = "g-row" }, .{
        view(h, ahri, .{ .px = .@"40", .role = .mid }),
        view(h, demo("Leblanc", "LeBlanc"), .{ .px = .@"40", .side = .us }),
        view(h, demo("Yasuo", "Yasuo"), .{ .px = .@"40", .side = .them }),
        view(h, demo("AurelionSol", "Aurelion Sol"), .{ .px = .@"40", .you = true, .level = 18 }),
    }));
    g.add("thin, banned, dead", h.div(.{ .class = "g-row" }, .{
        view(h, demo("Zilean", "Zilean"), .{ .px = .@"40", .state = .thin }),
        view(h, demo("Vex", "Vex"), .{ .px = .@"40", .state = .banned }),
        view(h, demo("Aurora", "Aurora"), .{ .px = .@"40", .state = .dead }),
    }));
    g.add("empty seat, a suggestion", h.div(.{ .class = "g-row" }, .{
        view(h, null, .{ .px = .@"40", .label = plain("Hidden seat") }),
        view(h, demo("Orianna", "Orianna"), .{ .px = .@"40", .state = .add }),
    }));
    g.add("beside its name", h.span(.{ .class = "g-row" }, .{ view(h, demo("Yone", "Yone"), .{ .px = .@"32", .named = false }), h.b(.{}, .{"Yone"}) }));
}
