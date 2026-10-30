//! SiteHeader: every page's top bar: the logo, the page links, the search. Under 760 px
//! of header the links give way to a menu button whose popover lists them and the pages
//! under Champions, the current one selected (popovertarget: no script). Also every
//! page's foot (`foot`), the preview strip under the header (`preview`), on the
//! Champions pages the bar under it (`subbar`: the section's tabs and the view picks), the
//! page's main column (`main_class`) and a one-line notice in it (`note`)
const tree = @import("tree.zig");
const tabs = @import("tabs.zig");
const segmented = @import("segmented.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "SiteHeader";
pub const scope = .{ ".c-site", ".c-sitemenu", ".c-sitefoot", ".c-preview", ".c-subbar", ".c-sitemain", ".c-sitenote" };

/// The page's <main>, written by the page shell (site/shell.zig) around the page's body
pub const main_class = "c-sitemain";

pub const Link = struct {
    label: tree.Text,
    href: []const u8,
    current: bool = false,
    /// Moved into the last view visited by the page's script (html.zig meioView)
    view: bool = false,
};

pub const Opts = struct {
    home: []const u8,
    /// The logo's link moves into the last view visited, as Link.view
    home_view: bool = false,
    /// The pages, in the bar and the menu
    links: []const Link,
    /// In the menu only, under a Champions label
    more: []const Link = &.{},
    /// The page's search box
    search: ?N = null,
    menu_id: []const u8 = "site-menu",
};

const W = struct {
    pub const product = plain("meiolol");
    pub const pages = plain("Pages");
    pub const menu = plain("Menu");
    pub const champions = plain("Champions");
    pub const data = phrase.Phrase("Ranked solo/duo {d:text}. Updated daily.");
    pub const legal_pages = plain("Site");
    /// Riot: a personal key may not serve the public while a production key is in review
    pub const preview = plain("Preview: this site is in review for a Riot Games production API key and is not yet open to the public.");
    pub const region = plain("Region");
    pub const all_regions = plain("All regions");
    pub const period = plain("Period");
    pub const days = plain("30 days");
    pub const patch = phrase.Phrase("Patch {p:text}");
    pub const rank = plain("Rank");
    pub const ranks = [_]tree.Text{ plain("Plat+"), plain("Emerald+"), plain("Diamond+"), plain("Master+") };
    pub const plat = "Every game we crawl: Platinum IV+ players' lobbies";
};

pub const Foot = struct {
    /// Where the page's numbers are from: "in EUW, last 30 days, 5,123 games"
    data: []const u8,
    links: []const Link = &foot_links,
    /// Riot's legal line, quoted as given
    legal: []const u8,
};

pub const foot_links = [_]Link{
    .{ .label = plain("Privacy"), .href = "/privacy" },
    .{ .label = plain("Terms"), .href = "/terms" },
    .{ .label = plain("Method"), .href = "/method" },
    .{ .label = plain("Desktop app"), .href = "/download" },
};

pub fn foot(h: *H, f: Foot) N {
    return h.el(.footer, .{ .class = "c-sitefoot" }, .{h.div(.{ .class = "in" }, .{
        h.p(.{}, .{W.data.with(h, .{ .d = f.data })}),
        h.el(.nav, .{ .aria_label = W.legal_pages }, .{links(h, f.links)}),
        h.p(.{ .class = "legal", .data_prose = {} }, .{tree.Text{ .s = f.legal }}),
    })});
}

pub const Subbar = struct {
    /// The Champions section's pages; empty: none
    tabs: []const Link = &.{},
    picks: ?Picks = null,
};

/// Region and period: links to this page in each view. Rank: Plat+ only, the rest greyed
pub const Picks = struct {
    /// The root view's region ("EUW"), then all regions
    home: []const u8,
    region: [2]Pick,
    /// Last 30 days, then the patch
    period: [2]Pick,
    patch: []const u8,
    /// Why the ranks past Plat+ are greyed
    rank_off: []const u8,
};

pub const Pick = struct { href: []const u8, current: bool = false };

pub fn subbar(h: *H, o: Subbar) N {
    const items = h.mem.alloc(tabs.Item, o.tabs.len) catch {
        h.oom = true;
        return .none;
    };
    for (o.tabs, items) |x, *it| it.* = .{ .label = x.label, .href = x.href, .selected = x.current, .view = x.view };
    return h.div(.{ .class = "c-subbar" }, .{h.div(.{ .class = "in" }, .{
        if (o.tabs.len > 0) tabs.view(h, W.champions, items, &.{}) else null,
        if (o.picks) |p| picks(h, p) else null,
    })});
}

fn picks(h: *H, p: Picks) N {
    var ranks: [W.ranks.len]segmented.Item = undefined;
    for (&ranks, W.ranks, 0..) |*it, l, i| it.* = if (i == 0)
        .{ .label = l, .selected = true, .href = "", .title = W.plat }
    else
        .{ .label = l, .disabled = true, .href = "", .title = p.rank_off };
    return h.div(.{ .class = "picks" }, .{
        segmented.view(h, .{ .s = .s, .label = W.region }, &.{
            .{ .label = .{ .s = p.home }, .href = p.region[0].href, .selected = p.region[0].current },
            .{ .label = W.all_regions, .href = p.region[1].href, .selected = p.region[1].current },
        }),
        segmented.view(h, .{ .s = .s, .label = W.period }, &.{
            .{ .label = W.days, .href = p.period[0].href, .selected = p.period[0].current },
            .{ .label = W.patch.with(h, .{ .p = p.patch }), .href = p.period[1].href, .selected = p.period[1].current },
        }),
        segmented.view(h, .{ .s = .s, .label = W.rank }, &ranks),
    });
}

/// "Early data: 1,234 games so far.", "No puzzle today."
pub fn note(h: *H, text: tree.Text) N {
    return h.p(.{ .class = "c-sitenote" }, .{text});
}

pub fn preview(h: *H) N {
    return h.div(.{ .class = "c-preview" }, .{h.p(.{}, .{W.preview})});
}

pub fn view(h: *H, o: Opts) N {
    return h.el(.header, .{ .class = "c-site ui" }, .{h.div(.{ .class = "bar" }, .{
        h.a(.{ .class = "logo", .href = o.home, .data_view = o.home_view }, .{ logo(h), W.product }),
        h.el(.nav, .{ .class = "links", .aria_label = W.pages }, .{links(h, o.links)}),
        o.search,
        h.button(.{ .class = "c-btn menu", .type = "button", .data_v = "icon", .popovertarget = o.menu_id, .aria_label = W.menu }, .{
            h.svg(.{ .viewBox = "0 0 24 24", .aria_hidden = true }, .{h.path(.{ .d = "M4 7h16M4 12h16M4 17h16" }, .{})}),
        }),
        menu(h, o, false),
    })});
}

/// The phone menu; `open`: drawn in place, for the gallery
pub fn menu(h: *H, o: Opts, open: bool) N {
    return h.el(.nav, .{
        .class = if (open) "c-sitemenu static" else "c-sitemenu",
        .id = if (open) null else o.menu_id,
        .popover = if (open) null else "",
        .aria_label = W.pages,
    }, .{
        links(h, o.links),
        if (o.more.len > 0) h.span(.{ .class = "lab" }, .{W.champions}) else null,
        links(h, o.more),
    });
}

fn links(h: *H, ls: []const Link) []const N {
    var l = h.list();
    for (ls) |x| l.add(h.a(.{ .href = x.href, .aria_current = if (x.current) "page" else null, .data_view = x.view }, .{x.label}));
    return l.done();
}

fn logo(h: *H) N {
    return h.svg(.{ .width = 22, .height = 22, .viewBox = "0 0 32 32", .aria_hidden = true }, .{
        h.rect(.{ .width = 32, .height = 32, .rx = 8, .class = "bg" }, .{}),
        h.path(.{ .d = "M6 21.5 11.5 14l5 4.5L26 7", .class = "ln" }, .{}),
        h.circle(.{ .cx = 16.5, .cy = 18.5, .r = 2.6, .class = "dot" }, .{}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-site { position: sticky; top: 0; z-index: var(--z-header); container: site / inline-size;
    \\    background: color-mix(in srgb, var(--bg) 90%, transparent); backdrop-filter: blur(8px);
    \\    border-bottom: 1px solid var(--line); }
    \\  .c-site > .bar { display: flex; align-items: center; gap: var(--sp-5); height: var(--header);
    \\    padding: 0 var(--gutter); box-sizing: border-box; }
    \\  .c-site .logo { display: flex; align-items: center; gap: var(--sp-2); flex: none; font-size: var(--fs-l);
    \\    font-weight: var(--w-b); color: var(--text); text-decoration: none; }
    \\  .c-site .logo .bg { fill: var(--brand); }
    \\  .c-site .logo .ln { fill: none; stroke: var(--on-brand); stroke-width: 3; stroke-linecap: round; stroke-linejoin: round; }
    \\  .c-site .logo .dot { fill: var(--brand-dot); }
    \\  .c-site .links { display: flex; gap: 2px; }
    \\  .c-site .links > a { display: flex; align-items: center; height: var(--ctl); padding: 0 10px; border-radius: var(--r-ctl);
    \\    color: var(--t2); font-weight: var(--w-m); white-space: nowrap; text-decoration: none; }
    \\  .c-site .links > a:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-site .links > a[aria-current="page"] { color: var(--text); background: var(--ctl-bg); }
    \\  .c-site .bar > :not(.logo, .links, .menu, .c-sitemenu) { margin-left: auto; max-width: 300px; flex: 1; }
    \\  .c-site .menu { display: none; flex: none; }
    \\  .c-site .menu svg { width: 18px; height: 18px; fill: none; stroke: currentColor; stroke-width: 2; stroke-linecap: round; }
    \\  @container site (max-width: 760px) {
    \\    .c-site > .bar { gap: var(--sp-2); }
    \\    .c-site .links { display: none; }
    \\    .c-site .bar > :not(.logo, .links, .menu, .c-sitemenu) { max-width: none; }
    \\    .c-site .menu { display: inline-flex; margin-left: auto; }
    \\    .c-site .bar > :not(.logo, .links, .menu, .c-sitemenu) + .menu { margin-left: 0; }
    \\    .c-site input { font-size: var(--fs-l); }
    \\  }
    \\  .c-sitemenu { margin: 0; position: fixed; inset: calc(var(--header) + 4px) var(--sp-2) auto auto;
    \\    width: min(264px, calc(100vw - 16px)); padding: 4px; box-sizing: border-box; border: 1px solid var(--line-2);
    \\    border-radius: var(--r-l); background: var(--panel-2); box-shadow: var(--shadow-pop); color: var(--text); }
    \\  .c-sitemenu:popover-open { display: grid; gap: 2px; }
    \\  .c-sitemenu.static { position: static; display: grid; gap: 2px; box-shadow: none; }
    \\  .c-sitemenu > a { display: flex; align-items: center; gap: var(--sp-2); min-height: var(--ctl-l); padding: 0 12px;
    \\    border-radius: var(--r-ctl); color: var(--t2); font-weight: var(--w-m); text-decoration: none; }
    \\  .c-sitemenu > a:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-sitemenu > a[aria-current="page"] { background: var(--sel-bg); color: var(--sel-ink); }
    \\  .c-sitemenu > .lab { padding: var(--sp-2) 12px 2px; margin-top: 2px; border-top: 1px solid var(--line);
    \\    font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--faint); text-transform: uppercase; letter-spacing: 0.06em; }
    \\  .c-sitefoot { margin-top: var(--sp-5); border-top: 1px solid var(--line); font-size: var(--fs-s); color: var(--faint); }
    \\  .c-sitefoot > .in { max-width: var(--wrap); margin: 0 auto; padding: 20px var(--gutter) 36px; }
    \\  .c-sitefoot p { margin: 0 0 var(--sp-3); }
    \\  .c-sitefoot nav { display: flex; flex-wrap: wrap; margin: 0 0 var(--sp-3); }
    \\  .c-sitefoot nav > a { color: var(--muted); }
    \\  .c-sitefoot nav > a + a::before { content: "·"; display: inline-block; padding: 0 0.35em; color: var(--faint); }
    \\  .c-sitefoot .legal { max-width: 720px; margin: 0; }
    \\  .c-preview { background: var(--panel); border-bottom: 1px solid var(--line); color: var(--muted);
    \\    font-size: var(--fs-s); line-height: 1.55; }
    \\  .c-preview > p { max-width: var(--wrap); margin: 0 auto; padding: var(--sp-2) var(--gutter); }
    \\  .c-subbar { border-bottom: 1px solid var(--line); }
    \\  .c-subbar > .in { display: flex; flex-wrap: wrap; align-items: center; gap: 0 var(--sp-4); max-width: var(--wrap);
    \\    margin: 0 auto; padding: 0 var(--gutter); }
    \\  .c-subbar .c-tabs { height: var(--ctl); box-shadow: none; margin-left: calc(-1 * var(--sp-3)); }
    \\  .c-sitemain { max-width: var(--wrap); margin: 0 auto; padding: var(--sp-4) var(--gutter) var(--sp-6); }
    \\  .c-sitenote { margin: var(--sp-2) 0 var(--sp-3); padding: var(--sp-2) var(--sp-3); border: 1px solid var(--line);
    \\    border-radius: var(--r-m); background: var(--panel); color: var(--muted); }
    \\  .c-subbar .picks { display: flex; flex-wrap: wrap; gap: var(--sp-2); max-width: 100%; margin-left: auto; padding: var(--sp-1) 0; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const o: Opts = .{
        .home = "#",
        .links = &.{
            .{ .label = plain("Your games"), .href = "#" },
            .{ .label = plain("Daily Draft"), .href = "#", .current = true },
            .{ .label = plain("Learn"), .href = "#" },
            .{ .label = plain("Champions"), .href = "#", .view = true },
        },
        .more = &.{
            .{ .label = plain("Matchups"), .href = "#", .view = true },
            .{ .label = plain("Patch changes"), .href = "#", .view = true },
            .{ .label = plain("Champion pool"), .href = "#", .view = true },
        },
        .menu_id = g.id("site-menu"),
    };
    var with_search = o;
    with_search.search = h.input(.{ .type = "search", .placeholder = plain("Champion or Riot ID"), .aria_label = plain("Search") });
    g.addFill("the bar; a menu button under 760 px", view(h, with_search));
    g.add("menu open, the current page selected", menu(h, o, true));
    g.addFill("the preview strip", preview(h));
    const view_picks: Picks = .{
        .home = "EUW",
        .region = .{ .{ .href = "#", .current = true }, .{ .href = "#" } },
        .period = .{ .{ .href = "#" }, .{ .href = "#", .current = true } },
        .patch = "16.21",
        .rank_off = "Champion pages and the champions board only",
    };
    g.addFill("the subbar: Champions tabs and the view picks; they wrap under the tabs when narrow", subbar(h, .{ .tabs = o.more, .picks = view_picks }));
    g.addFill("the subbar, tabs only", subbar(h, .{ .tabs = o.more }));
    g.addFill("the main column, a notice in it", h.div(.{ .class = main_class }, .{note(h, plain("Early data: 1,234 games so far."))}));
    g.addFill("the foot", foot(h, .{
        .data = "in EUW, last 30 days, 23,210 games",
        .legal = "meiolol isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties.",
    }));
}
