//! Notes: Jacob's notes on the live site, an island ui-notes.wasm adds to a page for the
//! admin login only (nothing in the page itself). The Note button, picking an element
//! (the glue outlines what is under the pointer and blocks the page's own handlers),
//! the form, and pins for the page's open notes. Every child of the root is keyed: pins
//! and the outline come and go while the form is open, and its textarea must stay the
//! same node. Positions are the document's, CSS px,
//! measured by the glue; the root spans the page's width at its top, clipping sideways so
//! a pin at the edge never widens the page
const std = @import("std");
const tree = @import("tree.zig");
const button = @import("button.zig");
const segmented = @import("segmented.zig");
const nd = @import("notesdata.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Notes";
pub const scope = .{".c-notes"};
pub const sel = "[data-island=notes]";

pub const Rect = struct { x: f32, y: f32, w: f32, h: f32 };

/// An open note where its element is now; `moved` when the element wasn't found (the pin
/// then sits at the page's top)
pub const Pin = struct { note: nd.Note, x: f32, y: f32, moved: bool = false };

pub const Mode = enum { idle, picking, form, saving };

/// What the glue does after an event, then sets back to none
pub const Want = enum { none, pick, stop, save, wider, narrower, outline };

pub const Tool = struct {
    mode: Mode = .idle,
    pins: []const Pin = &.{},
    /// The pin whose note shows
    open: ?u32 = null,
    /// The outline: what is under the pointer, the picked element, or an open pin's
    hl: ?Rect = null,
    /// The picked element, in words ("c-tierrow > span", its text); "" for the whole page
    what: []const u8 = "",
    /// The picked element sits in a component, so "everywhere" can apply
    component: bool = false,
    scope: nd.Scope = .page,
    failed: bool = false,
    /// The textarea was empty at Save
    empty: bool = false,
    want: Want = .none,
    /// Laid out in its container, not over the page (the gallery)
    static: bool = false,

    pub const Msg = union(enum) { note, whole, cancel, scope: nd.Scope, save, wider, narrower, pin: u32, close };

    pub fn update(t: *Tool, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .note => {
                t.open = null;
                t.mode = .picking;
                t.want = .pick;
            },
            .whole => {
                t.mode = .form;
                t.what = "";
                t.component = false;
                t.scope = .page;
                t.hl = null;
                t.want = .stop;
                ev.after = .{ .op = .focus, .ref = "text" };
            },
            .cancel, .close => t.reset(),
            .scope => |s| t.scope = if (s == .everywhere and !t.component) .page else s,
            .save => if (t.mode == .form) {
                t.mode = .saving;
                t.failed = false;
                t.empty = false;
                t.want = .save;
            },
            .wider => t.want = .wider,
            .narrower => t.want = .narrower,
            .pin => |i| if (i < t.pins.len) {
                t.open = if (t.open == i) null else i;
                t.want = .outline;
            },
        }
    }

    /// Back to the Note button; the glue drops the pick and its listeners
    pub fn reset(t: *Tool) void {
        t.mode = .idle;
        t.open = null;
        t.hl = null;
        t.what = "";
        t.component = false;
        t.scope = .page;
        t.failed = false;
        t.empty = false;
        t.want = .stop;
    }

    pub fn view(t: *Tool, h: *H) N {
        var pins = h.list();
        for (t.pins, 0..) |p, i| pins.add(h.button(.{
            .key = p.note.id,
            .class = "pin",
            .type = "button",
            .data_moved = p.moved,
            .aria_label = h.fmt("Note {d}", .{i + 1}),
            .aria_expanded = t.open == @as(u32, @intCast(i)),
            .style = h.vars(.{ .x = p.x, .y = p.y }),
            .on_click = h.on(t, .{ .pin = @intCast(i) }),
        }, .{i + 1}));
        return h.div(.{ .class = "c-notes", .data_island = "notes", .data_static = t.static }, .{
            if (t.hl) |r| h.div(.{ .key = "hl", .class = "hl", .style = h.vars(.{ .x = r.x, .y = r.y, .w = r.w, .h = r.h }) }, .{}) else null,
            pins.done(),
            if (t.open) |i| if (i < t.pins.len) card(t, h, t.pins[i]) else null else null,
            switch (t.mode) {
                .idle => h.div(.{ .key = "bar", .class = "bar" }, .{button.view(h, .{ .v = .primary, .on = h.on(t, .note) }, .{
                    "Note",
                    if (t.pins.len > 0) h.span(.{ .class = "n" }, .{t.pins.len}) else null,
                })}),
                .picking => h.div(.{ .key = "bar", .class = "bar" }, .{
                    h.span(.{ .class = "hint" }, .{"Tap what to note"}),
                    button.view(h, .{ .s = .s, .on = h.on(t, .whole) }, .{"Whole page"}),
                    button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(t, .cancel) }, .{"Cancel"}),
                }),
                .form, .saving => form(t, h),
            },
        });
    }

    fn form(t: *Tool, h: *H) N {
        const saving = t.mode == .saving;
        const picked = t.what.len > 0;
        return h.div(.{ .key = "form", .class = "form", .role = "dialog", .aria_label = "New note" }, .{
            h.div(.{ .class = "row" }, .{
                h.span(.{ .class = "what" }, .{if (picked) t.what else "Whole page"}),
                if (picked) button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(t, .wider) }, .{"Wider"}) else null,
                if (picked) button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(t, .narrower) }, .{"Narrower"}) else null,
            }),
            // Uncontrolled (the glue reads it at Save): keyed, so no re-render replaces it
            h.el(.textarea, .{
                .key = "text",
                .data_ref = "text",
                .rows = 4,
                .maxlength = nd.max_text,
                .placeholder = "What to change",
                .aria_label = "Note",
                .disabled = saving,
            }, .{}),
            if (t.component) segmented.view(h, .{ .s = .s, .label = plain("Applies to") }, &.{
                .{ .label = plain("This page"), .selected = t.scope == .page, .on = h.on(t, .{ .scope = .page }) },
                .{ .label = plain("Everywhere"), .selected = t.scope == .everywhere, .on = h.on(t, .{ .scope = .everywhere }) },
            }) else null,
            if (t.failed) h.p(.{ .class = "err" }, .{"Not saved. Try again."}) else null,
            if (t.empty) h.p(.{ .class = "err" }, .{"Write the note first."}) else null,
            h.div(.{ .class = "row" }, .{
                button.view(h, .{ .v = .primary, .disabled = saving, .on = h.on(t, .save) }, .{if (saving) "Saving" else "Save"}),
                button.view(h, .{ .v = .quiet, .on = h.on(t, .cancel) }, .{"Cancel"}),
            }),
        });
    }

    fn card(t: *Tool, h: *H, p: Pin) N {
        const n = p.note;
        return h.div(.{ .key = "card", .class = "card", .role = "dialog", .aria_label = "Note", .style = h.vars(.{ .x = p.x, .y = p.y }) }, .{
            h.p(.{ .class = "text" }, .{n.text}),
            h.p(.{ .class = "meta" }, .{
                if (n.scope == .everywhere) h.fmt("Everywhere: {s}", .{n.target.component()}) else "This page",
                if (p.moved) " (moved)" else "",
            }),
            button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(t, .close) }, .{"Close"}),
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-notes { position: absolute; left: 0; top: 0; width: 100%; height: 0; overflow-x: clip; pointer-events: none;
    \\    z-index: calc(var(--z-pop) + 10); font-size: var(--fs-s); }
    \\  .c-notes > * { pointer-events: auto; }
    \\  .c-notes[data-static] { position: relative; height: auto; min-height: 64px; }
    \\  .c-notes .hl { position: absolute; left: calc(var(--x) * 1px); top: calc(var(--y) * 1px);
    \\    width: calc(var(--w) * 1px); height: calc(var(--h) * 1px); pointer-events: none; border-radius: var(--r-s);
    \\    outline: 2px solid var(--focus); outline-offset: 1px; background: color-mix(in srgb, var(--focus) 12%, transparent); }
    \\  .c-notes .pin { position: absolute; left: calc(var(--x) * 1px - 11px); top: calc(var(--y) * 1px - 11px);
    \\    min-width: 22px; height: 22px; padding: 0 6px; border: 0; border-radius: var(--r-pill); cursor: pointer;
    \\    background: var(--brand); color: var(--on-brand); font: var(--w-b) var(--fs-xs) / 22px var(--font);
    \\    box-shadow: var(--shadow-pop); }
    \\  .c-notes .pin::after { content: ""; position: absolute; left: 50%; top: 50%; width: var(--hit); height: var(--hit);
    \\    transform: translate(-50%, -50%); }
    \\  .c-notes .pin[data-moved] { background: var(--muted); color: var(--bg); }
    \\  .c-notes .card { position: absolute; top: calc(var(--y) * 1px + 16px);
    \\    left: clamp(8px, calc(var(--x) * 1px - 140px), calc(100vw - 296px)); width: min(280px, calc(100vw - 16px));
    \\    display: grid; gap: var(--sp-2); justify-items: start; padding: var(--sp-3); }
    \\  .c-notes .card, .c-notes .bar, .c-notes .form { background: var(--panel-2); border: 1px solid var(--line-2);
    \\    border-radius: var(--r-l); box-shadow: var(--shadow-pop); }
    \\  .c-notes .text { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; }
    \\  .c-notes .meta, .c-notes .what, .c-notes .hint { margin: 0; color: var(--t2); overflow-wrap: anywhere; }
    \\  .c-notes .bar, .c-notes .form { position: fixed; right: var(--sp-4); bottom: var(--sp-4); padding: var(--sp-2); }
    \\  .c-notes .bar { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-notes .hint { padding: 0 var(--sp-1); }
    \\  .c-notes .form { display: grid; gap: var(--sp-2); width: min(360px, calc(100vw - 2 * var(--sp-4))); box-sizing: border-box; }
    \\  .c-notes[data-static] .bar, .c-notes[data-static] .form { position: static; width: auto; }
    \\  .c-notes[data-static]:has(.pin, .hl) { min-height: 112px; }
    \\  .c-notes[data-static]:has(.card) { min-height: 220px; }
    \\  .c-notes .row { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\  .c-notes .what { flex: 1 1 140px; }
    \\  .c-notes textarea { box-sizing: border-box; width: 100%; min-height: 96px; resize: vertical; padding: var(--sp-2);
    \\    font: inherit; font-size: var(--fs-m); color: var(--text); background: var(--ctl-bg); border: 1px solid var(--ctl-line);
    \\    border-radius: var(--r-ctl); }
    \\  .c-notes .n { margin-left: 6px; min-width: 18px; padding: 0 5px; border-radius: var(--r-pill);
    \\    background: var(--on-brand); color: var(--brand); font-size: var(--fs-xs); line-height: 18px; }
    \\  .c-notes .err { margin: 0; color: var(--bad); }
    \\}
    \\
;

fn fixture(n: u32, text: []const u8, scope_: nd.Scope) nd.Note {
    return .{
        .id = n,
        .created = 0,
        .updated = 0,
        .author = "jacob",
        .path = "/tier/",
        .hash = "",
        .scope = scope_,
        .target = .{ .kind = .component, .name = "c-tierrow", .snippet = "Ahri 52.3%" },
        .vw = 390,
        .vh = 844,
        .theme = .dark,
        .text = text,
        .status = .open,
        .reply = "",
    };
}

const gallery_pins = [_]Pin{
    .{ .note = fixture(1, "Row too tall on a phone", .page), .x = 40, .y = 84 },
    .{ .note = fixture(2, "Every tier row: the win rate first, then the pick rate", .everywhere), .x = 120, .y = 84 },
    .{ .note = fixture(3, "Was on the old header", .page), .x = 200, .y = 84, .moved = true },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, Tool }{
        .{ "no notes", .{ .static = true } },
        .{ "pins and count", .{ .static = true, .pins = &gallery_pins } },
        .{ "a pin open", .{ .static = true, .pins = &gallery_pins, .open = 1, .hl = .{ .x = 8, .y = 68, .w = 140, .h = 32 } } },
        .{ "picking", .{ .static = true, .mode = .picking, .hl = .{ .x = 8, .y = 64, .w = 160, .h = 40 } } },
        .{ "form, a component", .{ .static = true, .mode = .form, .what = "c-tierrow > span: Ahri 52.3%", .component = true } },
        .{ "form, whole page", .{ .static = true, .mode = .form } },
        .{ "form, not saved", .{ .static = true, .mode = .form, .what = "[data-island=top] > div", .failed = true } },
        .{ "saving", .{ .static = true, .mode = .saving, .what = "c-card > h2: Builds" } },
    };
    for (states) |s| {
        const t = h.mem.create(Tool) catch {
            h.oom = true;
            return;
        };
        t.* = s[1];
        g.add(s[0], t.view(h));
    }
}

test "notes: picking, the form and back" {
    var t: Tool = .{};
    var ev: tree.Event = .{ .kind = .click };
    t.update(.note, &ev);
    try std.testing.expectEqual(Mode.picking, t.mode);
    try std.testing.expectEqual(Want.pick, t.want);
    t.update(.whole, &ev);
    try std.testing.expectEqual(Mode.form, t.mode);
    try std.testing.expectEqual(Want.stop, t.want);
    // No component picked: "everywhere" can't apply
    t.update(.{ .scope = .everywhere }, &ev);
    try std.testing.expectEqual(nd.Scope.page, t.scope);
    t.update(.save, &ev);
    try std.testing.expectEqual(Mode.saving, t.mode);
    try std.testing.expectEqual(Want.save, t.want);
    // A second Save while one is out does nothing
    t.want = .none;
    t.update(.save, &ev);
    try std.testing.expectEqual(Want.none, t.want);
    t.update(.cancel, &ev);
    try std.testing.expectEqual(Mode.idle, t.mode);
    try std.testing.expectEqual(Want.stop, t.want);
    // A pin past the list is ignored
    t.update(.{ .pin = 3 }, &ev);
    try std.testing.expectEqual(null, t.open);
}
