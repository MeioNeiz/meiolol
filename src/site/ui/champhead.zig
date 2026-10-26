//! ChampHeader: a champion page's first row: the portrait, the name as the page's h1 and
//! a line under it (role, patch), the role picker, the opponent search and the headline
//! figures. Wraps in its container: on a phone each part takes a row, the strip last
const tree = @import("tree.zig");
const champ = @import("champ.zig");
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
};

pub fn view(h: *H, o: Opts) N {
    return h.div(.{ .class = "c-champhead" }, .{
        h.div(.{ .class = "id" }, .{
            champ.view(h, o.champ, .{ .px = .@"56", .named = false, .eager = true }),
            h.div(.{}, .{
                h.el(.h1, .{}, .{o.champ.name}),
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
    \\  .c-champhead > .id .sub { display: block; margin-top: 2px; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-champhead > .vs { flex: 1 1 200px; max-width: 240px; }
    \\  .c-champhead > .c-strip { margin-left: auto; }
    \\  @container champhead (max-width: 1000px) { .c-champhead > .c-strip { margin-left: 0; } }
    \\  @container champhead (max-width: 480px) { .c-champhead > .vs { max-width: none; } }
    \\}
    \\
;

const W = struct {
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
}
