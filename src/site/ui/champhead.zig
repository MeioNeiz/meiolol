//! ChampHeader: a champion page's first row: the portrait, the name as the page's h1 and
//! a line under it (role, patch), the role picker, the opponent search and the headline
//! figures. Wraps in its container: on a phone each part takes a row, the strip last.
//! With `pair` filled it heads the matchup page: both portraits, the swap between them
//! (the other side's page) and ⊗ on the opponent back to the champion page (lolalytics'
//! VS slot: the two pages are one with the slot empty or filled)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const button = @import("button.zig");
const phrase = @import("phrase.zig");
const rolepicker = @import("rolepicker.zig");
const champsearch = @import("champsearch.zig");
const strip = @import("strip.zig");
const fmt = @import("fmt.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "ChampHeader";
pub const scope = .{".c-champhead"};

pub const Opts = struct {
    champ: champ.Champ,
    /// Under the name: "Top · 16.21"
    sub: ?tree.Text = null,
    /// RolePicker
    roles: ?N = null,
    /// ChampSearch, link mode: an opponent opens the matchup page
    vs: ?N = null,
    /// StatStrip
    strip: ?N = null,
    /// The matchup page's opponent
    pair: ?Pair = null,
};

pub const Pair = struct {
    champ: champ.Champ,
    /// The other side's page
    swap: []const u8,
    /// The champion page, same role
    clear: []const u8,
};

pub fn view(h: *H, o: Opts) N {
    const pic = champ.view(h, o.champ, .{ .px = .@"56", .named = false, .eager = true });
    return h.div(.{ .class = "c-champhead" }, .{
        h.div(.{ .class = "id" }, .{
            if (o.pair) |p| h.div(.{ .class = "pair" }, .{
                pic,
                button.view(h, .{ .s = .s, .v = .icon, .href = p.swap, .label = W.swap.with(h, .{ .y = p.champ.name, .x = o.champ.name }) }, .{"⇄"}),
                h.span(.{ .class = "y" }, .{
                    champ.view(h, p.champ, .{ .px = .@"56", .named = false, .eager = true }),
                    h.a(.{ .class = "clear", .href = p.clear, .aria_label = W.clear.with(h, .{ .y = p.champ.name }) }, .{"×"}),
                }),
            }) else pic,
            h.div(.{}, .{
                if (o.pair) |p| h.el(.h1, .{}, .{ o.champ.name, h.span(.{ .class = "and" }, .{W.vs_word}), p.champ.name }) else h.el(.h1, .{}, .{o.champ.name}),
                if (o.sub) |s| h.span(.{ .class = "sub" }, .{s}) else null,
            }),
        }),
        o.roles,
        if (o.vs) |v| h.div(.{ .class = "vs" }, .{v}) else null,
        o.strip,
    });
}

pub const css =
    \\@layer components {
    \\  .c-champhead { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-3) var(--sp-5);
    \\    container: champhead / inline-size; }
    \\  .c-champhead > .id { display: flex; align-items: center; gap: var(--sp-3); min-width: 0; }
    \\  .c-champhead > .id h1 { white-space: nowrap; }
    \\  .c-champhead > .id > .pair ~ div h1 { white-space: normal; }
    \\  .c-champhead h1 > .and { margin: 0 0.3em; font-weight: var(--w-m); color: var(--muted); }
    \\  .c-champhead .pair { display: flex; align-items: center; gap: var(--sp-2); flex: none; }
    \\  .c-champhead .pair > .y { position: relative; display: flex; }
    \\  .c-champhead .pair .clear { position: absolute; top: -6px; right: -6px; display: grid; place-items: center;
    \\    width: 20px; height: 20px; border-radius: 50%; background: var(--panel-3); color: var(--t2);
    \\    box-shadow: 0 0 0 2px var(--panel); font-size: var(--fs-m); line-height: 1; text-decoration: none; }
    \\  .c-champhead .pair .clear::after { content: ""; position: absolute; inset: calc((20px - var(--hit)) / 2); }
    \\  .c-champhead .pair .clear:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-champhead > .id .sub { display: block; margin-top: 2px; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-champhead > .vs { flex: 1 1 200px; max-width: 240px; }
    \\  .c-champhead > .c-strip { margin-left: auto; }
    \\  @container champhead (max-width: 1000px) { .c-champhead > .c-strip { margin-left: 0; } }
    \\  @container champhead (max-width: 480px) {
    \\    .c-champhead > .vs { max-width: none; }
    \\    .c-champhead .pair .c-champ { --sz: 40px; }
    \\  }
    \\}
    \\
;

const W = struct {
    pub const swap = phrase.Phrase("From {y:text}'s side: {y:text} vs {x:text}");
    pub const clear = phrase.Phrase("Clear {y:text}: every opponent");
    pub const vs_word = plain("vs");
    pub const sub = plain("Top · 16.21");
    pub const vs = plain("vs opponent");
    pub const roles = plain("Darius roles");
    pub const won = plain("Win rate");
    pub const rank = plain("44th of 59");
    pub const patch = plain("16.21");
    pub const patch_v = plain("+2.6");
    pub const patch_ci = plain("±1.4");
    pub const pick = plain("Pick");
    pub const ban = plain("Ban");
    pub const games = plain("Games");
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const ix = h.mem.create(champsearch.Index) catch {
        h.oom = true;
        return;
    };
    ix.* = champsearch.Index.init(h.mem, &champsearch.Demo.entries) catch {
        h.oom = true;
        return;
    };
    const s = h.mem.create(champsearch.ChampSearch) catch {
        h.oom = true;
        return;
    };
    s.* = .{ .index = ix, .id = g.id("ch-vs"), .label = W.vs };
    const agg = fmt.win_cuts;
    const o: Opts = .{
        .champ = champ.demo("Darius", "Darius"),
        .sub = W.sub,
        .roles = rolepicker.view(h, .{ .label = W.roles }, &.{
            .{ .role = .top, .share = 86.2, .href = "#", .current = true },
            .{ .role = .jungle, .share = 13.6, .href = "#" },
            .{ .role = .mid, .share = 0.1, .href = "#" },
            .{ .role = .bot, .href = "#", .disabled = true },
            .{ .role = .support, .href = "#", .disabled = true },
        }),
        .vs = s.view(h),
        .strip = strip.view(h, &.{
            .{ .label = W.won, .value = plain("49.3%"), .ctx = W.rank, .step = .of(-0.7, agg), .answer = true },
            .{ .label = W.patch, .value = W.patch_v, .ctx = W.patch_ci, .step = .of(2.6, agg) },
            .{ .label = W.pick, .value = plain("7.7%") },
            .{ .label = W.ban, .value = plain("16.5%") },
            .{ .label = W.games, .value = plain("31,257") },
        }),
    };
    g.addFill("a champion page's head", view(h, o));
    g.addFill("name only", view(h, .{ .champ = champ.demo("Ahri", "Ahri") }));
    g.addFill("a matchup page's head: the opponent's slot filled", view(h, .{
        .champ = champ.demo("Darius", "Darius"),
        .sub = plain("Top · 16.21"),
        .pair = .{ .champ = champ.demo("Garen", "Garen"), .swap = "#", .clear = "#" },
        .strip = strip.view(h, &.{
            .{ .label = plain("Darius wins"), .value = plain("49.9%"), .step = .of(-0.1, agg), .answer = true },
            .{ .label = plain("Vs usual"), .value = plain("+1.2"), .ctx = plain("48.2% usually"), .step = .of(1.2, agg) },
            .{ .label = plain("Gold at 14"), .value = plain("+382") },
            .{ .label = plain("Games"), .value = plain("1,788") },
        }),
    }));
}
