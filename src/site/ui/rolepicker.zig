//! RolePicker: the role a page shows, in Segmented's well: each role's icon with its
//! share of the champion's games under it, the chosen one filled. Links (aria-current)
//! when each role is its own URL (a link's click is always the browser's), else buttons
//! (aria-pressed) whose handler switches in place. "All" for lists across roles; a role
//! with no games is shown but not choosable. Compact: icons only, a row's height
const tree = @import("tree.zig");
const role = @import("role.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "RolePicker";
pub const scope = .{".c-roles"};

pub const Item = struct {
    /// Null: All
    role: ?role.Role,
    /// % of the champion's games in this role
    share: ?f32 = null,
    /// A link to the role's page; `on` is then unused
    href: ?[]const u8 = null,
    on: ?tree.Handler = null,
    current: bool = false,
    /// No games in this role
    disabled: bool = false,
};

pub const Opts = struct {
    v: enum { default, compact } = .default,
    /// What it picks for ("Ahri's roles"), for screen readers
    label: ?tree.Text = null,
};

const W = struct {
    pub const all = plain("All");
    pub const rare = plain("<1%");
};

pub fn view(h: *H, o: Opts, items: []const Item) N {
    var l = h.list();
    var links = false;
    for (items, 0..) |it, i| {
        links = links or it.href != null;
        const share: ?tree.Text = if (it.share) |s| (if (s < 0.5) W.rare else phrase.num(h, .pct, @as(u32, @intFromFloat(@round(s))))) else null;
        // With a share the icon names the role; without, the control's label does
        const icon: ?N = if (it.role) |r| role.view(h, r, .{ .on = it.current, .named = share != null }) else null;
        const label: ?tree.Text = if (share == null) (if (it.role) |r| r.label() else null) else null;
        const kids = .{ icon, if (it.role == null) W.all else null, if (share) |s| h.span(.{ .class = "n" }, .{s}) else null };
        l.add(if (it.href) |href| h.a(.{
            .key = i,
            .href = if (it.disabled) null else href,
            .aria_current = if (it.current) "page" else null,
            .aria_disabled = if (it.disabled) true else null,
            .aria_label = label,
        }, kids) else h.button(.{
            .key = i,
            .type = "button",
            .aria_pressed = it.current,
            .aria_disabled = if (it.disabled) true else null,
            .aria_label = label,
            .on_click = if (it.disabled) null else it.on,
        }, kids));
    }
    const v = if (o.v == .default) null else o.v;
    if (links) return h.el(.nav, .{ .class = "c-roles", .data_v = v, .aria_label = o.label }, .{l.done()});
    return h.div(.{ .class = "c-roles", .role = "group", .data_v = v, .aria_label = o.label }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-roles { display: inline-flex; gap: 2px; padding: 3px; border-radius: calc(var(--r-ctl) + 3px); max-width: 100%;
    \\    background: var(--bg); box-shadow: inset 0 0 0 1px var(--ctl-line); flex: none; overflow-x: auto; scrollbar-width: none; }
    \\  .c-roles > :is(a, button) { all: unset; position: relative; display: flex; flex-direction: column; align-items: center;
    \\    justify-content: center; gap: 2px; min-width: 48px; height: var(--ctl-l); padding: 0 6px; box-sizing: border-box;
    \\    border-radius: var(--r-ctl); color: var(--t2); font-size: var(--fs-xs); font-weight: var(--w-m);
    \\    font-variant-numeric: tabular-nums; cursor: pointer; transition: background var(--dur) var(--ease); }
    \\  .c-roles > :is(a, button) > .c-role { color: var(--t2); }
    \\  .c-roles > :is(a, button):hover { color: var(--text); background: var(--ctl-bg-2); text-decoration: none; }
    \\  .c-roles > :is(a, button):focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-roles > :is([aria-current="page"], [aria-pressed="true"]) { background: var(--sel-bg); color: var(--sel-ink);
    \\    box-shadow: inset 0 0 0 1px var(--sel-line), var(--shadow-ctl); }
    \\  .c-roles > :is([aria-current="page"], [aria-pressed="true"]) > .c-role { color: var(--sel-ink); }
    \\  .c-roles > [aria-disabled="true"] { opacity: 0.35; cursor: default; background: none; }
    \\  .c-roles .n { color: var(--muted); }
    \\  .c-roles > :is([aria-current="page"], [aria-pressed="true"]) .n { color: var(--accent); }
    \\  .c-roles[data-v="compact"] > :is(a, button) { flex-direction: row; height: calc(var(--ctl) - 6px); min-width: 36px; gap: 4px; }
    \\  .c-roles[data-v="compact"] .c-role { width: 18px; height: 18px; }
    \\  .c-roles > :is(a, button)::after { content: ""; position: absolute; left: 0; right: 0; top: 50%;
    \\    height: max(100%, var(--hit)); transform: translateY(-50%); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("a champion's roles, links", view(h, .{ .label = plain("Ahri roles") }, &.{
        .{ .role = .mid, .share = 86.4, .href = "#", .current = true },
        .{ .role = .top, .share = 9.2, .href = "#" },
        .{ .role = .support, .share = 0.3, .href = "#" },
        .{ .role = .jungle, .href = "#", .disabled = true },
    }));
    g.add("every role and All", view(h, .{}, &.{
        .{ .role = null, .current = true },
        .{ .role = .top },
        .{ .role = .jungle },
        .{ .role = .mid },
        .{ .role = .bot },
        .{ .role = .support },
    }));
    g.add("compact", view(h, .{ .v = .compact, .label = plain("Opponent role") }, &.{
        .{ .role = .top },
        .{ .role = .jungle },
        .{ .role = .mid, .current = true },
        .{ .role = .bot },
        .{ .role = .support },
    }));
}
