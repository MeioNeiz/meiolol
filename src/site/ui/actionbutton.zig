//! ActionButton: a Button that runs something on the server (restart the crawler, build
//! the site). A confirm popover first when the action costs something (no script: the
//! popover API), busy while it runs, then a result line under it: ok or failed, when,
//! and the output folded in a <details>
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "ActionButton";
pub const scope = .{".c-action"};

pub const State = enum { idle, busy, ok, failed };

pub const Action = struct {
    /// The confirm popover's id, unique on the page
    id: []const u8,
    label: tree.Text,
    /// Asked before running ("Restart the crawler?"); null runs at once
    confirm: ?tree.Text = null,
    state: State = .idle,
    /// Another action holds the server (one at a time)
    disabled: bool = false,
    on: ?tree.Handler = null,
    /// The last run's: how long ago, and what it printed
    when: ?tree.Text = null,
    output: ?tree.Text = null,
};

const W = struct {
    pub const run = plain("Run");
    pub const cancel = plain("Cancel");
    pub const ok = plain("Done");
    pub const failed = plain("Failed");
    pub const output = plain("Output");
};

pub fn view(h: *H, a: Action) N {
    const busy = a.state == .busy;
    const off = busy or a.disabled;
    const ask = a.confirm != null and !off;
    return h.div(.{ .class = "c-action", .data_state = if (a.state == .idle) null else a.state }, .{
        h.button(.{
            .class = "c-btn",
            .type = "button",
            .data_s = "s",
            .disabled = off,
            .aria_busy = busy,
            .popovertarget = if (ask) a.id else null,
            .on_click = if (off or ask) null else a.on,
        }, .{ a.label, if (busy) h.span(.{ .class = "spin", .aria_hidden = true }, .{}) else null }),
        if (ask) h.div(.{ .class = "c-tip ask", .id = a.id, .popover = "" }, .{
            h.p(.{}, .{a.confirm.?}),
            h.button(.{ .class = "c-btn", .type = "button", .data_v = "primary", .data_s = "s", .popovertarget = a.id, .popovertargetaction = "hide", .on_click = a.on }, .{W.run}),
            h.button(.{ .class = "c-btn", .type = "button", .data_s = "s", .popovertarget = a.id, .popovertargetaction = "hide" }, .{W.cancel}),
        }) else null,
        result(h, a),
    });
}

fn result(h: *H, a: Action) ?N {
    const ok = switch (a.state) {
        .ok => true,
        .failed => false,
        .idle, .busy => return null,
    };
    const head = h.span(.{ .class = "res" }, .{
        h.span(.{ .class = "g", .aria_hidden = true }, .{if (ok) "✓" else "✕"}),
        if (ok) W.ok else W.failed,
        if (a.when) |w| h.span(.{ .class = "when" }, .{w}) else null,
    });
    const out = a.output orelse return head;
    if (out.s.len == 0) return head;
    return h.el(.details, .{ .open = !ok }, .{
        h.el(.summary, .{}, .{ head, h.span(.{ .class = "when" }, .{W.output}) }),
        h.div(.{ .class = "out" }, .{out}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-action { display: inline-flex; flex-direction: column; align-items: flex-start; gap: var(--sp-1); min-width: 0; max-width: 100%; }
    \\  .c-action .spin { width: 10px; height: 10px; border: 2px solid var(--line-2); border-top-color: var(--text);
    \\    border-radius: 50%; animation: c-action-spin 0.8s linear infinite; }
    \\  @keyframes c-action-spin { to { transform: rotate(1turn); } }
    \\  @media (prefers-reduced-motion: reduce) { .c-action .spin { animation: none; } }
    \\  .c-action .ask p { margin: 0 0 var(--sp-2); color: var(--text); }
    \\  .c-action .ask .c-btn + .c-btn { margin-left: var(--sp-1); }
    \\  .c-action .res { display: inline-flex; align-items: center; gap: 6px; font-size: var(--fs-s); color: var(--t2); }
    \\  .c-action .res .g { font-weight: var(--w-b); color: var(--good); }
    \\  .c-action[data-state="failed"] .res .g { color: var(--lo3); }
    \\  .c-action .when { color: var(--muted); }
    \\  .c-action details { max-width: 100%; }
    \\  .c-action summary { display: flex; gap: var(--sp-2); cursor: pointer; }
    \\  .c-action .out { margin-top: var(--sp-1); padding: var(--sp-2); max-height: 16em; overflow: auto;
    \\    border-radius: var(--r-s); background: var(--panel-2); color: var(--t2); font: var(--fs-xs)/1.4 ui-monospace, monospace;
    \\    white-space: pre-wrap; overflow-wrap: anywhere; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("idle, confirm first", view(h, .{ .id = g.id("act-restart"), .label = plain("Restart crawler"), .confirm = plain("Restart the crawler? It drops its in-flight calls.") }));
    g.add("idle, runs at once", view(h, .{ .id = g.id("act-health"), .label = plain("Health check") }));
    g.add("busy", view(h, .{ .id = g.id("act-build"), .label = plain("Build site"), .state = .busy }));
    g.add("held by another", view(h, .{ .id = g.id("act-eval"), .label = plain("Run eval"), .disabled = true }));
    g.add("ok, output", view(h, .{ .id = g.id("act-ok"), .label = plain("Health check"), .state = .ok, .when = plain("2 min ago"), .output = plain("disk 41% used\ncrawler: 182 matches/min\nall units active") }));
    g.add("failed, long output", view(h, .{ .id = g.id("act-fail"), .label = plain("Build site"), .state = .failed, .when = plain("just now"), .output = plain("error: render@b did not answer on /healthz within 30 s; kept render@a serving; see web.log at 2026-10-27T01:12:44Z for the build's own output and the upload's rsync stats") }));
}

test "confirm, busy and result" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    const html = @import("html.zig");

    try html.write(&t, view(&h, .{ .id = "x", .label = plain("Restart"), .confirm = plain("Sure?") }), &out.writer);
    try std.testing.expectEqual(3, std.mem.count(u8, out.written(), "popovertarget=\"x\""));
    out.clearRetainingCapacity();
    // Busy: no confirm, the button off
    try html.write(&t, view(&h, .{ .id = "x", .label = plain("Restart"), .confirm = plain("Sure?"), .state = .busy }), &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "popover") == null);
    try std.testing.expect(std.mem.find(u8, out.written(), "disabled") != null);
    out.clearRetainingCapacity();
    // Failed output opens; an empty one has no <details>
    try html.write(&t, view(&h, .{ .id = "x", .label = plain("Build"), .state = .failed, .output = plain("boom") }), &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "<details open") != null);
    out.clearRetainingCapacity();
    try html.write(&t, view(&h, .{ .id = "x", .label = plain("Build"), .state = .ok, .output = plain("") }), &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "<details") == null);
    try std.testing.expect(std.mem.find(u8, out.written(), "Done") != null);
}
