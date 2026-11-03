//! AppBar: the desktop app's top bar, the site's header (site.zig) with the app's links:
//! the live screen first, named for the phase, then the site's pages (on meio.lol, opened
//! in the app's window), Practice (private edition) and the settings popover. Static HTML
//! before the app's island (no ui-app.wasm bytes): the shell renders it with the page
//! and reloads the page when it changes. Clicks that ask the shell for something carry
//! their message as JSON in data-shell, which bridge.js sends
const tree = @import("tree.zig");
const site = @import("site.zig");
const badge = @import("badge.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "AppBar";
pub const scope = .{ ".c-appbar", ".c-appset" };

pub const Bar = struct {
    /// The site's address its links start with ("https://meio.lol"); "" on the site itself
    site: []const u8,
    /// The live screen's address: the shell's start page, the review page itself
    live: []const u8 = "/",
    /// The phase, the live link's label ("Lobby", "Champ select")
    phase: []const u8,
    private: bool,
    /// Private edition: practice on or off; null offers none
    practice: ?bool = null,
    /// Options weigh the player's mastery points
    mastery: bool = true,
    /// A working sign-in
    signed_in: bool = true,
};

pub const Page = struct { label: []const u8, path: []const u8 };

/// The site's bar links, in its order (site/shell.zig nav_items; a test there keeps them
/// the same)
pub const pages = [_]Page{
    .{ .label = "Your games", .path = "/your" },
    .{ .label = "Champions", .path = "/champions" },
    .{ .label = "Matchups", .path = "/matchups" },
    .{ .label = "Daily Draft", .path = "/daily" },
    .{ .label = "Learn", .path = "/learn" },
};

/// The menu's: each section's pages past the one in the bar
pub const more = [_]Page{
    .{ .label = "Patch changes", .path = "/patch" },
    .{ .label = "Rankings", .path = "/rankings" },
    .{ .label = "Champion pool", .path = "/pool" },
    .{ .label = "Squads", .path = "/squad" },
};

const tester: Page = .{ .label = "Draft tester", .path = "/private/tester" };

const W = struct {
    const settings = plain("Settings");
    const practice = plain("Practice");
    const private = plain("private");
    const mastery = plain("Use mastery");
    const mastery_why = plain("Options lean towards champions you have played a lot");
    const signed_in = plain("Signed in: updates and data download");
    const signed_out = plain("Not signed in: no updates");
    const more = plain("More on meio.lol");
    const download = plain("Download page");
    const privacy = plain("Privacy");
    const terms = plain("Terms");
};

pub fn view(h: *H, b: Bar) N {
    var bar: [pages.len + 2]site.Link = undefined;
    bar[0] = .{ .label = .{ .s = b.phase }, .href = b.live, .current = true };
    for (pages, bar[1 .. pages.len + 1]) |p, *l| l.* = link(h, b, p);
    const n: usize = if (b.private) pages.len + 2 else pages.len + 1;
    if (b.private) bar[n - 1] = link(h, b, tester);
    var menu: [more.len]site.Link = undefined;
    for (more, &menu) |p, *l| l.* = link(h, b, p);
    const opts: site.Opts = .{
        .home = b.live,
        .links = h.mem.dupe(site.Link, bar[0..n]) catch return oom(h),
        .groups = h.mem.dupe(site.Group, &.{.{ .label = W.more, .links = h.mem.dupe(site.Link, &menu) catch return oom(h) }}) catch return oom(h),
        .account = false,
        .menu_id = "app-menu",
        .end = h.div(.{ .class = "c-appbar" }, .{
            if (b.private) badge.view(h, .accent, .{W.private}) else null,
            if (b.practice) |on| h.button(.{
                .class = "c-chip",
                .type = "button",
                .aria_pressed = on,
                .data_shell = if (on) "{\"practice\":{\"on\":false}}" else "{\"practice\":{\"on\":true}}",
            }, .{W.practice}) else null,
            h.button(.{ .class = "c-btn set", .type = "button", .data_v = "icon", .popovertarget = "app-settings", .aria_label = W.settings, .title = W.settings }, .{gear(h)}),
            settings(h, b, false),
        }),
    };
    return site.view(h, opts);
}

fn oom(h: *H) N {
    h.oom = true;
    return .none;
}

fn link(h: *H, b: Bar, p: Page) site.Link {
    const href = h.mem.alloc(u8, b.site.len + p.path.len) catch {
        h.oom = true;
        return .{ .label = .{ .s = p.label }, .href = p.path };
    };
    @memcpy(href[0..b.site.len], b.site);
    @memcpy(href[b.site.len..], p.path);
    return .{ .label = .{ .s = p.label }, .href = href };
}

/// The popover; `open`: drawn in place, for the gallery
pub fn settings(h: *H, b: Bar, open: bool) N {
    return h.div(.{
        .class = if (open) "c-sitemenu c-appset static" else "c-sitemenu c-appset",
        .id = if (open) null else "app-settings",
        .popover = if (open) null else "",
        .role = "dialog",
        .aria_label = W.settings,
    }, .{
        h.button(.{
            .class = "opt",
            .type = "button",
            .role = "switch",
            .aria_checked = b.mastery,
            .title = W.mastery_why,
            .data_shell = if (b.mastery) "{\"mastery\":false}" else "{\"mastery\":true}",
        }, .{ h.span(.{ .class = "sw", .aria_hidden = true }, .{}), W.mastery }),
        h.p(.{ .class = "line", .data_off = !b.signed_in }, .{if (b.signed_in) W.signed_in else W.signed_out}),
        h.a(.{ .href = link(h, b, .{ .label = "", .path = "/" }).href }, .{W.more}),
        h.a(.{ .href = link(h, b, .{ .label = "", .path = "/download" }).href }, .{W.download}),
        h.a(.{ .href = link(h, b, .{ .label = "", .path = "/privacy" }).href }, .{W.privacy}),
        h.a(.{ .href = link(h, b, .{ .label = "", .path = "/terms" }).href }, .{W.terms}),
    });
}

fn gear(h: *H) N {
    return h.svg(.{ .viewBox = "0 0 24 24", .aria_hidden = true }, .{
        h.circle(.{ .cx = 12, .cy = 12, .r = 3 }, .{}),
        h.path(.{ .d = "M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1" }, .{}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-appbar { display: flex; align-items: center; justify-content: flex-end; gap: var(--sp-2); }
    \\  .c-appbar .set svg { width: 18px; height: 18px; fill: none; stroke: currentColor; stroke-width: 2; stroke-linecap: round; }
    \\  .c-appset { width: 280px; }
    \\  .c-appset > .opt { display: flex; align-items: center; gap: var(--sp-2); min-height: var(--ctl-l); padding: 0 12px;
    \\    border: 0; border-radius: var(--r-ctl); background: none; color: var(--text); font: inherit; font-weight: var(--w-m);
    \\    text-align: left; cursor: pointer; }
    \\  .c-appset > .opt:hover { background: var(--ctl-bg-2); }
    \\  .c-appset .sw { position: relative; flex: none; width: 28px; height: 16px; border-radius: 8px; background: var(--ctl-line); }
    \\  .c-appset .sw::after { content: ""; position: absolute; top: 2px; left: 2px; width: 12px; height: 12px; border-radius: 50%;
    \\    background: var(--text); transition: left 0.12s; }
    \\  .c-appset [aria-checked="true"] .sw { background: var(--brand); }
    \\  .c-appset [aria-checked="true"] .sw::after { left: 14px; background: var(--on-brand); }
    \\  .c-appset > .line { margin: 0; padding: var(--sp-2) 12px; border-top: 1px solid var(--line); border-bottom: 1px solid var(--line);
    \\    font-size: var(--fs-s); color: var(--t2); }
    \\  .c-appset > .line[data-off] { color: var(--warn, var(--lo2)); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("public, lobby", view(h, .{ .site = "https://meio.lol", .phase = "Lobby", .private = false }));
    g.addFill("private, champ select, practice off", view(h, .{ .site = "https://meio.lol", .phase = "Champ select", .private = true, .practice = false }));
    g.add("settings open, signed out", settings(h, .{ .site = "", .phase = "Lobby", .private = false, .mastery = false, .signed_in = false }, true));
}
