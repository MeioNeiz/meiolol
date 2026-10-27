//! Button: the pressable shape. Primary is a view's one action, quiet sits in a band,
//! icon is square and named by its label; s fits a row or a chart head. With `href` it
//! is a link that looks like a button
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "Button";
pub const scope = .{".c-btn"};

pub const Variant = enum { default, primary, quiet, icon };
pub const Size = enum { m, s };

pub const Opts = struct {
    v: Variant = .default,
    s: Size = .m,
    disabled: bool = false,
    /// What it does, when the content doesn't say (an icon button needs one)
    label: ?tree.Text = null,
    on: ?tree.Handler = null,
    href: ?[]const u8 = null,
    /// data-ref, for ev.after (focus after a patch)
    ref: ?[]const u8 = null,
    /// Sends its form
    submit: bool = false,
};

pub fn view(h: *H, o: Opts, kids: anytype) N {
    const v: ?Variant = if (o.v == .default) null else o.v;
    const s: ?Size = if (o.s == .m) null else o.s;
    if (o.href) |href| return h.a(.{ .class = "c-btn", .href = href, .data_v = v, .data_s = s, .aria_label = o.label, .data_ref = o.ref }, kids);
    return h.button(.{
        .class = "c-btn",
        .type = if (o.submit) "submit" else "button",
        .data_v = v,
        .data_s = s,
        .disabled = o.disabled,
        .aria_label = o.label,
        .data_ref = o.ref,
        .on_click = if (o.disabled) null else o.on,
    }, kids);
}

pub const css =
    \\@layer components {
    \\  .c-btn { position: relative; }
    \\  .c-btn[href] { display: inline-flex; align-items: center; justify-content: center; gap: 6px; min-height: var(--ctl);
    \\    padding: 0 14px; border: 1px solid var(--ctl-line); border-radius: var(--r-ctl); background: var(--ctl-bg);
    \\    color: var(--text); font-weight: var(--w-m); white-space: nowrap;
    \\    transition: background var(--dur) var(--ease), color var(--dur) var(--ease); }
    \\  .c-btn[href]:hover { background: var(--ctl-bg-2); text-decoration: none; }
    \\  .c-btn[data-v="primary"] { background: var(--brand); border-color: transparent; color: var(--on-brand);
    \\    box-shadow: var(--shadow-btn); }
    \\  .c-btn[data-v="primary"]:hover { background: var(--accent); color: var(--bg); }
    \\  .c-btn[data-v="quiet"] { background: none; border-color: transparent; color: var(--t2); }
    \\  .c-btn[data-v="quiet"]:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-btn[data-v="icon"] { width: var(--ctl); padding: 0; }
    \\  .c-btn[data-s="s"] { min-height: var(--ctl-s); padding: 0 10px; font-size: var(--fs-s); }
    \\  .c-btn[data-s="s"][data-v="icon"] { width: var(--ctl-s); }
    \\  .c-btn[data-s="s"]::after { content: ""; position: absolute; left: 0; right: 0; top: 50%;
    \\    height: max(100%, var(--hit)); transform: translateY(-50%); }
    \\  .c-btn:disabled { opacity: 0.45; cursor: default; transform: none; }
    \\  .c-btn:disabled:hover { background: var(--ctl-bg); }
    \\  .c-btn[data-v="primary"]:disabled:hover { background: var(--brand); color: var(--on-brand); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("primary", view(h, .{ .v = .primary }, .{"Lock in"}));
    g.add("default", view(h, .{}, .{"Open matchup"}));
    g.add("quiet", view(h, .{ .v = .quiet }, .{"Clear"}));
    g.add("disabled", view(h, .{ .v = .primary, .disabled = true }, .{"Lock in"}));
    g.add("icon", view(h, .{ .v = .icon, .label = plain("Refresh") }, .{"↻"}));
    g.add("link", view(h, .{ .href = "#" }, .{"Open game"}));
    g.add("small, in a row", h.div(.{ .class = "g-row" }, .{
        view(h, .{ .s = .s }, .{"Pick"}),
        view(h, .{ .s = .s, .v = .primary }, .{"Lock in"}),
        view(h, .{ .s = .s, .v = .quiet }, .{"Esc"}),
        view(h, .{ .s = .s, .v = .icon, .label = plain("Swap") }, .{"⇄"}),
    }));
}
