//! Chip: a small pill that toggles a filter (pressed or not), removes a choice, or opens
//! the rest of a list (expand). Scope and reason chips are labels, not controls: flat,
//! no hover (Badge's family)
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "Chip";
pub const scope = .{".c-chip"};

pub const Variant = enum {
    toggle,
    /// "+134 rare": shows what a filter hides
    expand,
    /// What the numbers cover ("Patch 16.21"): not pressable
    scope,
    /// A reason with its signed weight: not pressable
    reason,
};

pub const Opts = struct {
    v: Variant = .toggle,
    pressed: bool = false,
    /// Shown but not choosable
    disabled: bool = false,
    /// A × after the content: pressing removes it
    remove: bool = false,
    label: ?tree.Text = null,
    on: ?tree.Handler = null,
};

pub fn view(h: *H, o: Opts, kids: anytype) N {
    const x: ?N = if (o.remove) h.span(.{ .class = "x", .aria_hidden = true }, .{"×"}) else null;
    if (o.v == .scope or o.v == .reason or o.disabled) {
        return h.span(.{ .class = "c-chip", .data_v = if (o.disabled) null else o.v, .aria_disabled = if (o.disabled) true else null }, kids ++ .{x});
    }
    return h.button(.{
        .class = "c-chip",
        .type = "button",
        .data_v = if (o.v == .toggle) null else o.v,
        .aria_pressed = if (o.v == .toggle and !o.remove) o.pressed else null,
        .aria_label = o.label,
        .on_click = o.on,
    }, kids ++ .{x});
}

pub const css =
    \\@layer components {
    \\  .c-chip { display: inline-flex; align-items: center; gap: 6px; height: var(--ctl-s);
    \\    padding: 0 12px; border: 1px solid var(--ctl-line); border-radius: var(--r-pill);
    \\    background: var(--ctl-bg); color: var(--t2); font-size: var(--fs-s); font-weight: var(--w-m);
    \\    white-space: nowrap; cursor: pointer; position: relative; min-height: 0;
    \\    transition: background var(--dur) var(--ease), color var(--dur) var(--ease); }
    \\  .c-chip:hover { color: var(--text); background: var(--ctl-bg-2); }
    \\  .c-chip[aria-pressed="true"] { color: var(--sel-ink); background: var(--sel-bg); border-color: var(--sel-line); }
    \\  .c-chip[aria-disabled="true"] { color: var(--faint); cursor: default; background: none; }
    \\  .c-chip .x { margin-right: -4px; color: var(--muted); font-size: var(--fs-l); line-height: 1; }
    \\  .c-chip[data-v="expand"] { border-style: dashed; color: var(--muted); background: none; }
    \\  .c-chip[data-v="scope"] { cursor: default; background: none; color: var(--muted); border-color: var(--line); }
    \\  .c-chip[data-v="reason"] { cursor: default; background: var(--wash); border-color: transparent;
    \\    border-radius: var(--r-s); height: auto; padding: 2px 6px; font-weight: var(--w-r); }
    \\  .c-chip[data-v="reason"]:hover { background: var(--wash); color: var(--t2); }
    \\  .c-chip::after { content: ""; position: absolute; left: 0; right: 0; top: 50%;
    \\    height: max(100%, var(--hit)); transform: translateY(-50%); }
    \\  .c-chip:is(span)::after { content: none; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("toggle", view(h, .{}, .{"Fights"}));
    g.add("pressed", view(h, .{ .pressed = true }, .{"Objectives"}));
    g.add("disabled", view(h, .{ .disabled = true }, .{"Herald"}));
    g.add("removable", view(h, .{ .remove = true, .label = plain("Remove Darius") }, .{"Darius"}));
    g.add("expand", view(h, .{ .v = .expand }, .{"+134 rare"}));
    g.add("scope", view(h, .{ .v = .scope }, .{"Patch 16.21"}));
    g.add("reason", view(h, .{ .v = .reason }, .{ "strong bot ", h.b(.{ .class = "hi1" }, .{"+1.7"}) }));
    g.add("a filter row", h.div(.{ .class = "g-row" }, .{
        view(h, .{ .pressed = true }, .{"All"}),
        view(h, .{}, .{"Yours"}),
        view(h, .{}, .{"Fights"}),
        view(h, .{}, .{"Objectives"}),
        view(h, .{}, .{"Deaths"}),
    }));
}
