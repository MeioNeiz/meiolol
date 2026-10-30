//! The layout every public page shares, around its body: the head, ui.site's header,
//! preview strip and subbar, the main column and the foot. `open` before the body,
//! `close` after

const std = @import("std");
const ui = @import("ui");
const html = @import("html.zig");
const sheets = @import("sheets.zig");
const assets = @import("assets.zig");
const csp = @import("csp.zig");
const Writer = std.Io.Writer;
const tpl = html.tpl;
const Page = html.Page;
const Link = html.Link;
const View = html.View;
const Nav = html.Nav;
const boilerplate = html.boilerplate;

fn toSite(path: []const u8) Link {
    return .{ .path = path };
}

/// no-referrer: Your games has a Riot ID in its URL, and the access log keeps Referer
pub fn open(w: *Writer, p: Page) Writer.Error!void {
    try tpl.renderPart(w,
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\{csp}<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<meta name="referrer" content="no-referrer">
        \\<title>{title}</title>
        \\<meta name="description" content="{description}">
        \\{css}
        \\<link rel="stylesheet" href="{print}" media="print">
        \\<link rel="icon" href="{icon}" type="image/svg+xml">
        \\{robots}{canonical}</head>
        \\<body class="ui">
        \\{header}
        \\{look}{remember}{meio_view}{admin}
        \\{subbar}{banner}<main class="{main}">
        \\
    , .{
        .csp = tpl.trusted(csp_meta),
        .title = p.title,
        .description = p.description,
        .css = tpl.trusted(sheets.slot),
        .print = toSite("print.css"),
        .icon = toSite("favicon.svg"),
        .robots = tpl.when(!p.public or !p.index, tpl.trusted("<meta name=\"robots\" content=\"noindex\">\n")),
        .canonical = if (p.public and p.index) if (p.canonical) |url|
            tpl.t("<link rel=\"canonical\" href=\"{url}\">\n", .{ .url = url })
        else
            null else null,
        .header = SiteHeader{ .p = p },
        .look = tpl.trusted(search_loader),
        .subbar = tpl.when(p.nav.inChampions() or p.counterparts != null, Subbar{ .p = p }),
        // Remembered so shared pages link back into this view
        .remember = if (p.view) |v| tpl.t("<script data-v=\"{v}\">" ++ remember ++ "</script>\n", .{ .v = v.query() }) else null,
        .meio_view = tpl.when(p.view == null, tpl.trusted(meio_view)),
        .admin = tpl.trusted(admin_link),
        .banner = tpl.when(!p.public, Preview{}),
        .main = ui.site.main_class,
    });
}

/// The page's CSP (csp.zig): the inline scripts here; its <style> is added at delivery
const csp_meta = csp.meta(&.{ search_loader, admin_link, meio_view, "<script>" ++ remember ++ "</script>" }, &.{});

/// Its view (data-v): the hash is one for every view
const remember = "try{localStorage.setItem(\"view\",document.currentScript.dataset.v)}catch(e){}";

/// ui.site's bar. Its search: ui.sitesearch's island; without JS a Riot ID lookup
const SiteHeader = struct {
    p: Page,

    pub fn render(x: SiteHeader, w: *Writer) Writer.Error!void {
        const p = x.p;
        var buf: [20 * 1024]u8 = undefined;
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        const a = fba.allocator();
        var t: ui.Tree = .{};
        var h: ui.H = .init(a, &t);
        var links: [nav_items.len]ui.site.Link = undefined;
        for (nav_items, &links) |it, *l| {
            const here = it.nav == p.nav or (it.nav == .champions and p.nav.inChampions());
            l.* = link(a, p, it, here) catch return error.WriteFailed;
        }
        var more: [champion_tabs.len - 1]ui.site.Link = undefined;
        for (champion_tabs[1..], &more) |it, *l| l.* = link(a, p, it, it.nav == p.nav) catch return error.WriteFailed;
        var search: ui.sitesearch.SiteSearch = .{
            .js = "/" ++ assets.sitesearch_js.path,
            .wasm = "/" ++ assets.sitesearch_wasm.path,
            .view_q = if (p.view) |v| v.query() else null,
        };
        const look = search.view(&h);
        t.root = ui.site.view(&h, .{
            .home = if (p.view) |v| std.mem.concat(a, u8, &.{ "/", v.query() }) catch return error.WriteFailed else "/",
            .home_view = p.view == null,
            .links = &links,
            .more = &more,
            .search = look,
        });
        if (h.oom) return error.WriteFailed;
        try ui.html.write(&t, t.root, w);
    }

    /// Pages in a view link within it; from a shared page, to the default view's, moved
    /// by the header script into the last one visited
    fn link(a: std.mem.Allocator, p: Page, it: NavItem, here: bool) !ui.site.Link {
        return .{
            .label = .{ .s = it.label },
            .href = try navHref(a, p, it),
            .current = here,
            .view = it.in_view and p.view == null,
        };
    }
};

fn navHref(a: std.mem.Allocator, p: Page, it: NavItem) ![]const u8 {
    const q = if (it.in_view) if (p.view) |v| v.query() else "" else "";
    return std.mem.concat(a, u8, &.{ it.path, q });
}

/// The header search's file (ui-sitesearch.js) on the box's first use, so a page that
/// never searches loads none of it; "/" focuses the box. A submit before the island runs
/// (window.meioSearch) that isn't a Riot ID waits for it: meioSearchGo, its first option.
/// If the island fails (script error, or not running 8 s on) that submit and later ones go
/// as without JS. pagehide drops the 8 s timer: a page restored on Back resumes its timers
const search_loader =
    \\<script>{const f=document.querySelector("[data-island=search]");let on=false,bad=false,t;const own=()=>{bad=true;f.submit()};const go=()=>{if(on||!f)return;on=true;const s=document.createElement("script");
    \\s.src=f.dataset.js;s.dataset.wasm=f.dataset.wasm;s.onerror=()=>{bad=true;if(window.meioSearchGo)own()};document.head.append(s)};f?.addEventListener("focusin",go);f?.addEventListener("pointerdown",go);
    \\f?.addEventListener("submit",e=>{if(window.meioSearch||bad||f.querySelector("input").value.includes("#"))return;e.preventDefault();window.meioSearchGo=1;go();clearTimeout(t);t=setTimeout(()=>{if(!window.meioSearch)own()},8000)});addEventListener("pagehide",()=>clearTimeout(t));
    \\addEventListener("keydown",e=>{if(!f||e.key!="/"||e.ctrlKey||e.metaKey||e.altKey||e.target.closest?.("input,textarea,select,[contenteditable]"))return;e.preventDefault();go();f.querySelector("input").focus()})}</script>
    \\
;

/// A menu link to the Draft tester for logins that opened it: the admin page (/admin) or the
/// private one (/private) stores it in this origin's localStorage, so visitors' pages carry
/// neither link nor path. Those browsers also load the private numbers (site/pv.zig), which
/// nginx serves to private logins only: for anyone else they are the login page's HTML,
/// which never runs or styles
const admin_link =
    \\<script>try{const l=JSON.parse(localStorage.getItem("admin-link"));if(l&&typeof l.href=="string"&&/^\/(admin|private)[/#]/.test(l.href)){const a=document.createElement("a");
    \\a.href=l.href;a.textContent=l.label;document.querySelector("header .links").append(a);const c=document.createElement("link");c.rel="stylesheet";c.href="/private/pv.css";
    \\const s=document.createElement("script");s.src="/private/pv.js";s.dataset.wasm="/private/pv.wasm";document.head.append(c,s)}}catch(e){}</script>
    \\
;

/// On shared and champion pages: moves data-view links into the last view visited (its
/// query, View.query); meioView(v) again from the champion page's filters, which move
/// between views
const meio_view =
    \\<script>function meioView(v){try{if(v==null)v=localStorage.getItem("view");else localStorage.setItem("view",v)}catch(e){}
    \\if(!["?period=patch","?region=all","?region=all&period=patch"].includes(v))v="";for(const a of document.querySelectorAll("a[data-view]")){
    \\a.href=(a.dataset.base??=a.getAttribute("href"))+v}}meioView()</script>
    \\
;

const NavItem = struct { nav: Nav, path: []const u8, label: []const u8, in_view: bool };

/// The menu: the player's own games first; the stats pages sit under Champions
const nav_items = [_]NavItem{
    .{ .nav = .your, .path = "/your", .label = "Your games", .in_view = false },
    .{ .nav = .squad, .path = "/squad", .label = "Squads", .in_view = false },
    .{ .nav = .daily, .path = "/daily", .label = "Daily Draft", .in_view = false },
    .{ .nav = .learn, .path = "/learn", .label = "Learn", .in_view = false },
    .{ .nav = .champions, .path = "/champions", .label = "Champions", .in_view = true },
};

/// Tabs on the pages under Champions
const champion_tabs = [_]NavItem{
    .{ .nav = .champions, .path = "/champions", .label = "Champions", .in_view = true },
    .{ .nav = .matchups, .path = "/matchups", .label = "Matchups", .in_view = true },
    .{ .nav = .patch, .path = "/patch", .label = "Patch changes", .in_view = true },
    .{ .nav = .pool, .path = "/pool", .label = "Champion pool", .in_view = true },
};

/// Under the header on the Champions pages: the section's tabs and, with counterparts,
/// the view picks
const Subbar = struct {
    p: Page,

    pub fn render(x: Subbar, w: *Writer) Writer.Error!void {
        const p = x.p;
        var buf: [16 * 1024]u8 = undefined;
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        const a = fba.allocator();
        var t: ui.Tree = .{};
        var h: ui.H = .init(a, &t);
        var tabs: [champion_tabs.len]ui.site.Link = undefined;
        for (champion_tabs, &tabs) |it, *l| l.* = SiteHeader.link(a, p, it, it.nav == p.nav) catch return error.WriteFailed;
        t.root = ui.site.subbar(&h, .{
            .tabs = if (p.nav.inChampions()) &tabs else &.{},
            .picks = if (p.counterparts) |c| picks(p, c) else null,
        });
        if (h.oom) return error.WriteFailed;
        try ui.html.write(&t, t.root, w);
        try w.writeByte('\n');
    }

    fn picks(p: Page, c: [View.count][]const u8) ui.site.Picks {
        const v = p.view orelse View.all[0];
        const at = struct {
            fn f(cs: [View.count][]const u8, cur: View, to: View) ui.site.Pick {
                return .{ .href = cs[to.index()], .current = to.index() == cur.index() };
            }
        }.f;
        return .{
            .home = html.platformName(p.home),
            .region = .{ at(c, v, .{ .region = .euw, .period = v.period }), at(c, v, .{ .region = .all, .period = v.period }) },
            .period = .{ at(c, v, .{ .region = v.region, .period = .days30 }), at(c, v, .{ .region = v.region, .period = .patch }) },
            .patch = p.patch,
            .rank_off = p.rank_off,
        };
    }
};

pub fn close(w: *Writer, p: Page) Writer.Error!void {
    try w.writeAll("</main>\n");
    var buf: [8 * 1024]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    var t: ui.Tree = .{};
    var h: ui.H = .init(fba.allocator(), &t);
    t.root = ui.site.foot(&h, .{ .data = p.data, .legal = boilerplate });
    if (h.oom) return error.WriteFailed;
    try ui.html.write(&t, t.root, w);
    try w.writeAll("\n</body>\n</html>\n");
}

/// ui.site's preview strip, on every page until the production key
const Preview = struct {
    pub fn render(_: Preview, w: *Writer) Writer.Error!void {
        var buf: [2 * 1024]u8 = undefined;
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        var t: ui.Tree = .{};
        var h: ui.H = .init(fba.allocator(), &t);
        t.root = ui.site.preview(&h);
        if (h.oom) return error.WriteFailed;
        try ui.html.write(&t, t.root, w);
        try w.writeByte('\n');
    }
};

test "open: its CSP allows each inline script it writes" {
    for ([_]?View{ null, View.all[3] }) |v| {
        var out: Writer.Allocating = .init(std.testing.allocator);
        defer out.deinit();
        try open(&out.writer, .{ .title = "t", .description = "d", .patch = "16.21", .data = "", .public = true, .view = v, .nav = .champions });
        try close(&out.writer, .{ .title = "t", .description = "d", .patch = "16.21", .data = "", .public = true });
        try csp.check(out.written());
    }
}
