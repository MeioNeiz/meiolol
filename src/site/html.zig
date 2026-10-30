//! HTML helpers: escaping, links and what a page is (Page); site/shell.zig writes the
//! layout every page shares

const std = @import("std");
const core = @import("core");
const Writer = std.Io.Writer;
pub const tpl = @import("tpl");
const ui = @import("ui");

pub const product = "meiolol";

pub const boilerplate = core.boilerplate;

pub const Nav = enum {
    home,
    your,
    matchups,
    patch,
    daily,
    learn,
    pool,
    champions,
    method,
    none,

    /// Pages under Champions in the menu, with its tabs and the view picks
    pub fn inChampions(n: Nav) bool {
        return n == .champions or n == .matchups or n == .patch or n == .pool;
    }
};

pub const Region = enum {
    euw,
    all,

    /// "ranked solo/duo {in}"
    pub fn in(r: Region) []const u8 {
        return switch (r) {
            .euw => "in EUW",
            .all => "across all regions",
        };
    }
};

pub const Period = enum { days30, patch };

/// The site's stats views, as lolalytics' filters: EUW over the last 30 days by default,
/// the rest picked by the URL's query (View.query; docs/plan/urls.md). Stats pages exist
/// in each, but champion pages: one per champion and role in the default view, whose
/// filters pick the view. Shared pages (Daily Draft, Learn, legal: EUW, current patch)
/// once
pub const View = struct {
    region: Region,
    period: Period,

    pub const all = [_]View{
        .{ .region = .euw, .period = .days30 },
        .{ .region = .euw, .period = .patch },
        .{ .region = .all, .period = .days30 },
        .{ .region = .all, .period = .patch },
    };
    pub const count = all.len;
    /// Where shared pages get their numbers
    pub const shared: View = all[1];

    pub fn index(v: View) usize {
        return 2 * @as(usize, @backingInt(v.region)) + @backingInt(v.period);
    }

    /// Its pages' and data's tree under the site root, never in a page's URL: nginx maps
    /// the query to it (deploy/nginx/meiolol.conf $meiolol_view)
    pub fn dir(v: View) []const u8 {
        return ui.urls.view_dirs[v.index()];
    }

    /// Picks this view: ui.urls.Data spelt, "" for the default. Raw: escape it in HTML
    pub fn query(v: View) []const u8 {
        return ui.urls.view_queries[v.index()];
    }
};

pub const Page = struct {
    title: []const u8,
    description: []const u8,
    /// View the page belongs to; null for shared pages and champion pages
    view: ?View = null,
    /// This page's href in each view (View.index) for the subbar's picks: usually its URL
    /// with that view's query. Null: no picks
    counterparts: ?[View.count][]const u8 = null,
    nav: Nav = .none,
    /// Current patch, for the period pick
    patch: []const u8,
    /// The platform of the root view (EUW)
    home: []const u8 = "EUW1",
    /// Footer: "in EUW, last 30 days, 5,123 games"
    data: []const u8,
    /// Preview: unlisted for search engines, with a banner saying so
    public: bool,
    /// Absolute URL search engines should file the page under (Options.origin); only
    /// written when public
    canonical: ?[]const u8 = null,
    /// False: noindex even when public (thin matchups, Options.index_min_games)
    index: bool = true,
    /// Why the rank picks past Plat+ are greyed, on pages with a view
    rank_off: []const u8 = "Champion pages and the champions board only",
};

/// `path` under the site root, root-relative: for href and src holes
pub const Link = struct {
    path: []const u8,

    pub fn render(l: Link, w: *Writer) Writer.Error!void {
        try w.writeByte('/');
        try w.writeAll(l.path);
    }
};

/// "EUW1" -> "EUW", "EUN1" -> "EUNE"
pub fn platformName(p: []const u8) []const u8 {
    const names = [_][2][]const u8{ .{ "EUN1", "EUNE" }, .{ "LA1", "LAN" }, .{ "LA2", "LAS" }, .{ "OC1", "OCE" } };
    for (names) |n| if (std.mem.eql(u8, n[0], p)) return n[1];
    return std.mem.trimEnd(u8, p, "0123456789");
}

test {
    _ = tpl;
}
