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
const Private = html.Private;
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
        \\{print}<link rel="icon" href="{icon}" type="image/svg+xml">
        \\{robots}{canonical}</head>
        \\<body class="ui">
        \\{header}
        \\{look}{tip_esc}{remember}{meio_view}{admin}
        \\{subbar}{login}{account}{banner}<main class="{main}">
        \\
    , .{
        .csp = tpl.trusted(csp_meta),
        .title = p.title,
        .description = p.description,
        .css = tpl.trusted(sheets.slot),
        // traffic.sh counts people by it: not the private pages' loads
        .print = tpl.when(p.private == null, tpl.trusted("<link rel=\"stylesheet\" href=\"/print.css\" media=\"print\">\n")),
        .icon = toSite("favicon.svg"),
        .robots = tpl.when(!p.public or !p.index, tpl.trusted("<meta name=\"robots\" content=\"noindex\">\n")),
        .canonical = if (p.public and p.index) if (p.canonical) |url|
            tpl.t("<link rel=\"canonical\" href=\"{url}\">\n", .{ .url = url })
        else
            null else null,
        .header = SiteHeader{ .p = p },
        .look = tpl.trusted(search_loader),
        .tip_esc = tpl.trusted(tip_esc),
        // /admin's island draws its own (ui.site.mainbar)
        .subbar = tpl.when(p.nav.inChampions() or p.nav.inYour() or p.counterparts != null or (p.private != null and p.private != .admin), Subbar{ .p = p }),
        // Remembered so shared pages link back into this view
        .remember = if (p.view) |v| tpl.t("<script data-v=\"{v}\">" ++ remember ++ "</script>\n", .{ .v = v.query() }) else null,
        .meio_view = tpl.when(p.view == null, tpl.trusted(meio_view)),
        .admin = tpl.when(p.private == null, tpl.trusted(admin_link)),
        // After the subbar, whose admin tabs it shows
        .account = tpl.trusted(if (p.private != null) "<script data-private>" ++ account_js ++ "</script>\n" else "<script>" ++ account_js ++ "</script>\n"),
        .login = if (p.private) |pr| tpl.trusted(if (adminOnly(pr)) admin_mark else private_mark) else null,
        .banner = tpl.when(!p.public and p.private == null, Preview{}),
        .main = ui.site.main_class,
    });
}

/// The page's CSP (csp.zig): the inline scripts here; its <style> is added at delivery
const csp_meta = csp.meta(&.{ search_loader, tip_esc, admin_link, "<script>" ++ account_js ++ "</script>", private_mark, admin_mark, meio_view, "<script>" ++ remember ++ "</script>" }, &.{});

/// Its view (data-v): the hash is one for every view
const remember = "try{localStorage.setItem(\"view\",document.currentScript.dataset.v)}catch(e){}";

/// ui.site's bar. Its search: ui.sitesearch's island; without JS a Riot ID lookup
const SiteHeader = struct {
    p: Page,

    pub fn render(x: SiteHeader, w: *Writer) Writer.Error!void {
        const p = x.p;
        var buf: [32 * 1024]u8 = undefined;
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        const a = fba.allocator();
        var t: ui.Tree = .{};
        var h: ui.H = .init(a, &t);
        var links: [nav_items.len + header_private.len]ui.site.Link = undefined;
        for (nav_items, links[0..nav_items.len]) |it, *l| {
            const here = it.nav == p.nav or (it.nav == .champions and p.nav.inChampions() and p.nav != .matchups) or
                (it.nav == .your and p.nav.inYour());
            l.* = link(a, p, it, here) catch return error.WriteFailed;
        }
        // Public pages get them from admin_link's script
        if (p.private != null) for (header_private, links[nav_items.len..]) |it, *l| {
            l.* = privateLink(p, it, true);
        };
        // Each section's first tabs are in the bar already
        var your_more: [your_tabs.len - 1]ui.site.Link = undefined;
        for (your_tabs[1..], &your_more) |it, *l| l.* = link(a, p, it, it.nav == p.nav) catch return error.WriteFailed;
        var champ_more: [champion_tabs.len - 2]ui.site.Link = undefined;
        for (champion_tabs[2..], &champ_more) |it, *l| l.* = link(a, p, it, it.nav == p.nav) catch return error.WriteFailed;
        var search: ui.sitesearch.SiteSearch = .{
            .js = "/" ++ assets.sitesearch_js.path,
            .wasm = "/" ++ assets.sitesearch_wasm.path,
            .view_q = if (p.view) |v| v.query() else null,
        };
        const look = search.view(&h);
        t.root = ui.site.view(&h, .{
            .home = if (p.view) |v| std.mem.concat(a, u8, &.{ "/", v.query() }) catch return error.WriteFailed else "/",
            .home_view = p.view == null,
            .links = if (p.private != null) &links else links[0..nav_items.len],
            .groups = &.{
                .{ .label = .{ .s = your_tabs[0].label }, .links = &your_more },
                .{ .label = .{ .s = champion_tabs[0].label }, .links = &champ_more },
            },
            .search = look,
            .signed_in = p.private != null,
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
    \\<script>{const f=document.querySelector("[data-island=search]");let on=false,bad=false,t;const i=f?.querySelector("input[data-short]");if(i&&matchMedia("(max-width:860px)").matches)i.placeholder=i.dataset.short;const own=()=>{bad=true;f.submit()};const go=()=>{if(on||!f)return;on=true;const s=document.createElement("script");
    \\s.src=f.dataset.js;s.dataset.wasm=f.dataset.wasm;s.onerror=()=>{bad=true;if(window.meioSearchGo)own()};document.head.append(s)};f?.addEventListener("focusin",go);f?.addEventListener("pointerdown",go);
    \\f?.addEventListener("submit",e=>{if(window.meioSearch||bad||f.querySelector("input").value.includes("#"))return;e.preventDefault();window.meioSearchGo=1;go();clearTimeout(t);t=setTimeout(()=>{if(!window.meioSearch)own()},8000)});addEventListener("pagehide",()=>clearTimeout(t));
    \\addEventListener("keydown",e=>{if(!f||e.key!="/"||e.ctrlKey||e.metaKey||e.altKey||e.target.closest?.("input,textarea,select,[contenteditable]"))return;e.preventDefault();go();f.querySelector("input").focus()})}</script>
    \\
;

/// Escape shuts an open Tip (ui/tip.zig, class esc) where the pointer or focus has it,
/// without moving either (WCAG 1.4.13); leaving it lets it open again
const tip_esc =
    \\<script>addEventListener("keydown",e=>{if(e.key=="Escape")for(const t of document.querySelectorAll(".c-hint:is(:hover,:focus)")){t.classList.add("esc");const c=new AbortController,o=()=>{t.classList.remove("esc");c.abort()};t.addEventListener("pointerleave",o,c);t.addEventListener("focusout",o,c)}})</script>
    \\
;

/// Bar and menu links for private logins: Private, and Admin for an admin's; on /download
/// the tester zip's link above the apply form (ui/account.zig zip). Sign-in and the
/// private pages mark the login in this origin's localStorage ("login"), so visitors'
/// pages carry neither links nor paths
const admin_link =
    \\<script>try{const r=localStorage.getItem("login");if(r=="tester"||r=="admin"){const ls=[["/private","Private"]];if(r=="admin")ls.push(["/admin","Admin"]);
    \\for(const n of document.querySelectorAll("header .links,header .c-sitemenu"))for(const[h,t]of ls){const a=document.createElement("a");a.href=h;a.textContent=t;n.insertBefore(a,n.querySelector(":scope>.lab"))}
    \\addEventListener("DOMContentLoaded",()=>{const ap=document.querySelector(".c-apply");if(ap){const p=document.createElement("p"),a=document.createElement("a");a.href="/private/desktop/meiolol-desktop.zip";a.textContent="Download the tester build";p.append(a," (Windows, a zip: run meiolol-desktop.exe inside, it installs itself)");ap.before(p)}})}}catch(e){}</script>
    \\
;

/// The header's account slot: the chip named for a browser signed in (the account island
/// stores the username on sign-in, ui/wasm/account.zig shown_as; an email shows its part
/// before @), else Log in and Sign up, which the admin links' unhide skips (:not(.acct));
/// the chip's Log out; data-in on the root while signed in (the foot, written after this
/// runs, hides its Log in by CSS). A signed-in browser, and every private page, then asks
/// /auth/me: the session's name and role ("login": tester or admin, for admin_link and the hidden
/// admin links) come from it, so a browser marked by an older login catches up. A 401
/// signs the browser out here; anything else (the dev server's 404) keeps what it has.
/// data-private on private pages
const account_js =
    \\try{const L=localStorage,q=s=>document.querySelectorAll(s),m=document.getElementById("acct-menu");
    \\const show=u=>{document.documentElement.toggleAttribute("data-in",!!u);for(const a of q("header a.acct"))a.hidden=!!u;for(const b of q("header .acct.me")){b.hidden=!u;if(u){b.textContent=u.split("@")[0];b.title=u}}};
    \\const out=()=>{L.removeItem("account");L.removeItem("login");show("")};const u=L.getItem("account");if(u)show(u);
    \\m?.querySelector(".out")?.addEventListener("click",()=>fetch("/auth/logout",{method:"POST",headers:{"X-Meiolol-Action":"1"}}).finally(()=>{out();location.href="/"}));
    \\if(u||document.currentScript.hasAttribute("data-private"))fetch("/auth/me").then(r=>{if(r.status==401)out();return r.ok?r.json():null}).then(me=>{if(!me)return;
    \\const c=me.can||[],r=c.includes("view_admin")?"admin":c.includes("view_private")?"tester":"";L.setItem("account",me.username);if(r)L.setItem("login",r);else L.removeItem("login");show(me.username);
    \\if(r=="admin")for(const a of q("header a[hidden]:not(.acct),.c-subbar a[hidden]"))a.hidden=false}).catch(()=>{})}catch(e){}
;

/// On the private pages any private login opens: shows the admin links at once to a
/// browser marked an admin's (account_js checks the mark with /auth/me), else marks
/// it a tester's for admin_link
const private_mark =
    \\<script>try{if(localStorage.getItem("login")=="admin")for(const a of document.querySelectorAll("header a[hidden]:not(.acct),.c-subbar a[hidden]"))a.hidden=false;else localStorage.setItem("login","tester")}catch(e){}</script>
    \\
;

/// On the admin-only pages, which nginx serves to admin logins only
const admin_mark =
    \\<script>try{localStorage.setItem("login","admin")}catch(e){}</script>
    \\
;

const PrivateTab = struct { page: Private, href: []const u8, label: []const u8 };

/// The tabs under the header on the private pages but /admin, whose own sections are its
/// subbar. Admin is the bar's
const private_tabs = [_]PrivateTab{
    header_private[0],
    .{ .page = .tester, .href = "/private/tester", .label = "Draft tester" },
    .{ .page = .app, .href = "/private/app", .label = "App review" },
    .{ .page = .meionotes, .href = "/admin/meionotes", .label = "meionotes" },
};

/// The bar's: Private stands for the pages under its tabs, as Champions does
const header_private = [_]PrivateTab{
    .{ .page = .index, .href = "/private", .label = "Private" },
    .{ .page = .admin, .href = "/admin", .label = "Admin" },
};

/// nginx keeps these to admin logins
fn adminOnly(pr: Private) bool {
    return pr == .meionotes or pr == .admin;
}

/// Admin-only ones hidden on the other private pages until private_mark finds an admin's
/// browser: a tester gets no link that fails. `section`: Private current on the pages
/// under its tabs
fn privateLink(p: Page, it: PrivateTab, section: bool) ui.site.Link {
    const cur = p.private.?;
    const here = it.page == cur or (section and it.page == .index and cur != .admin);
    return .{ .label = .{ .s = it.label }, .href = it.href, .current = here, .hidden = adminOnly(it.page) and !adminOnly(cur) };
}

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

/// The menu: the site's two halves first, the player's own games and the stats (Champions
/// and Matchups), then Daily Draft and Learn; the rest as the sections' tabs
const nav_items = [_]NavItem{
    .{ .nav = .your, .path = "/your", .label = "Your games", .in_view = false },
    .{ .nav = .champions, .path = "/champions", .label = "Champions", .in_view = true },
    .{ .nav = .matchups, .path = "/matchups", .label = "Matchups", .in_view = true },
    .{ .nav = .daily, .path = "/daily", .label = "Daily Draft", .in_view = false },
    .{ .nav = .learn, .path = "/learn", .label = "Learn", .in_view = false },
};

/// Tabs on the pages under Champions
const champion_tabs = [_]NavItem{
    .{ .nav = .champions, .path = "/champions", .label = "Champions", .in_view = true },
    .{ .nav = .matchups, .path = "/matchups", .label = "Matchups", .in_view = true },
    .{ .nav = .patch, .path = "/patch", .label = "Patch changes", .in_view = true },
    .{ .nav = .rankings, .path = "/rankings", .label = "Rankings", .in_view = true },
};

/// Tabs on the pages under Your games
const your_tabs = [_]NavItem{
    .{ .nav = .your, .path = "/your", .label = "Your games", .in_view = false },
    .{ .nav = .pool, .path = "/pool", .label = "Champion pool", .in_view = true },
    .{ .nav = .squad, .path = "/squad", .label = "Squads", .in_view = false },
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
        if (p.private != null) {
            var tabs: [private_tabs.len]ui.site.Link = undefined;
            for (private_tabs, &tabs) |it, *l| l.* = privateLink(p, it, false);
            t.root = ui.site.subbar(&h, .{ .tabs = &tabs, .label = .{ .s = "Private" } });
        } else {
            const section: []const NavItem = if (p.nav.inChampions()) &champion_tabs else if (p.nav.inYour()) &your_tabs else &.{};
            var tabs: [@max(champion_tabs.len, your_tabs.len)]ui.site.Link = undefined;
            for (section, tabs[0..section.len]) |it, *l| l.* = SiteHeader.link(a, p, it, it.nav == p.nav) catch return error.WriteFailed;
            t.root = ui.site.subbar(&h, .{
                .tabs = tabs[0..section.len],
                .label = if (p.nav.inYour()) .{ .s = your_tabs[0].label } else null,
                .picks = if (p.counterparts) |c| picks(p, c) else null,
            });
        }
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

test "the app's bar links the site's pages in the site's order" {
    const app = ui.appbar;
    try std.testing.expectEqual(nav_items.len, app.pages.len);
    for (nav_items, app.pages) |n, p| {
        try std.testing.expectEqualStrings(n.label, p.label);
        try std.testing.expectEqualStrings(n.path, p.path);
    }
    const more = champion_tabs[2..] ++ your_tabs[1..];
    try std.testing.expectEqual(more.len, app.more.len);
    for (more, app.more) |n, p| try std.testing.expectEqualStrings(n.path, p.path);
}

test "open: the bar links the private pages on private pages, where admin_link isn't" {
    for ([_]?Private{ null, .tester, .meionotes, .admin }) |pr| {
        var out: Writer.Allocating = .init(std.testing.allocator);
        defer out.deinit();
        try open(&out.writer, .{ .title = "t", .description = "d", .patch = "16.21", .data = "", .public = false, .private = pr });
        const bar = out.written()[0..std.mem.indexOf(u8, out.written(), "</header>").?];
        const private = "<a href=\"/private\"";
        try std.testing.expectEqual(pr != null, std.mem.indexOf(u8, bar, private) != null);
        try std.testing.expectEqual(pr != null and pr != .admin, std.mem.indexOf(u8, bar, private ++ " aria-current=\"page\">Private</a>") != null);
        try std.testing.expect(std.mem.indexOf(u8, bar, "Draft tester") == null);
        try std.testing.expectEqual(pr != null, std.mem.indexOf(u8, bar, "<a href=\"/admin\"") != null);
    }
}

test "open: a tester's private pages hide the admin links until an admin's browser shows them" {
    const sub_class = "class=\"c-subbar\"";
    for ([_]Private{ .index, .tester, .app, .meionotes, .admin }) |pr| {
        var out: Writer.Allocating = .init(std.testing.allocator);
        defer out.deinit();
        try open(&out.writer, .{ .title = "t", .description = "d", .patch = "16.21", .data = "", .public = false, .private = pr });
        const page = out.written();
        const hidden = std.mem.count(u8, page, " hidden=\"\">Admin</a>") + std.mem.count(u8, page, " hidden=\"\">meionotes</a>");
        // The bar's and the menu's Admin, the tabs' meionotes
        try std.testing.expectEqual(@as(usize, if (adminOnly(pr)) 0 else 3), hidden);
        const mark = if (adminOnly(pr)) admin_mark else private_mark;
        try std.testing.expect(std.mem.indexOf(u8, page, mark) != null);
        // /admin's subbar is its island's
        if (std.mem.indexOf(u8, page, sub_class)) |sub| try std.testing.expect(std.mem.indexOf(u8, page, mark).? > sub);
        try std.testing.expectEqual(pr != .admin, std.mem.indexOf(u8, page, sub_class) != null);
    }
}

test "open: private pages ask /auth/me for the role; their CSP allows it" {
    for ([_]?Private{ null, .tester, .admin }) |pr| {
        var out: Writer.Allocating = .init(std.testing.allocator);
        defer out.deinit();
        try open(&out.writer, .{ .title = "t", .description = "d", .patch = "16.21", .data = "", .public = false, .private = pr });
        try close(&out.writer, .{ .title = "t", .description = "d", .patch = "16.21", .data = "", .public = false });
        try csp.check(out.written());
        try std.testing.expectEqual(pr != null, std.mem.indexOf(u8, out.written(), "<script data-private>") != null);
    }
}

test "open: Your games, Champion pool and Squads share a subbar; Champions' tabs lose the pool" {
    for ([_]Nav{ .your, .squad, .pool, .champions }) |nav| {
        var out: Writer.Allocating = .init(std.testing.allocator);
        defer out.deinit();
        try open(&out.writer, .{ .title = "t", .description = "d", .patch = "16.21", .data = "", .public = true, .nav = nav });
        const page = out.written();
        const sub = page[std.mem.indexOf(u8, page, "c-subbar").?..];
        try std.testing.expectEqual(nav != .champions, std.mem.indexOf(u8, sub, "href=\"/squad\"") != null);
        try std.testing.expectEqual(nav != .champions, std.mem.indexOf(u8, sub, "href=\"/pool\"") != null);
        try std.testing.expectEqual(nav == .champions, std.mem.indexOf(u8, sub, "href=\"/patch\"") != null);
        const bar = page[0..std.mem.indexOf(u8, page, "</header>").?];
        try std.testing.expectEqual(nav != .champions, std.mem.indexOf(u8, bar, "href=\"/your\" aria-current=\"page\"") != null);
    }
}
