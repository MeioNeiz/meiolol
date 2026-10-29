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
    // A confirm with nothing to run would be a dead Run that only hides the popover
    const ask = a.confirm != null and a.on != null and !off;
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
        if (a.confirm) |c| if (ask) h.div(.{ .class = "c-tip ask", .id = a.id, .popover = "" }, .{
            h.p(.{}, .{c}),
            h.button(.{ .class = "c-btn", .type = "button", .data_v = "primary", .data_s = "s", .popovertarget = a.id, .popovertargetaction = "hide", .on_click = a.on }, .{W.run}),
            h.button(.{ .class = "c-btn", .type = "button", .data_s = "s", .popovertarget = a.id, .popovertargetaction = "hide" }, .{W.cancel}),
        }) else null else null,
        // Always there, so a screen reader hears the result when busy turns to ok or failed
        h.div(.{ .class = "live", .role = "status" }, .{result(h, a)}),
    });
}

fn result(h: *H, a: Action) ?N {
    const ok = switch (a.state) {
        .ok => true,
        .failed => false,
        .idle, .busy => return null,
    };
    const head = h.span(.{ .class = "res", .role = if (ok) null else "alert" }, .{
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
    \\  .c-action .live { display: contents; }
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

/// A gallery owner, so a confirm has something to run
const Demo = struct {
    runs: u32 = 0,

    pub const Msg = enum { run };

    pub fn update(d: *Demo, _: Msg, _: *tree.Event) void {
        d.runs += 1;
    }
};
var demo: Demo = .{};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const on = h.on(&demo, .run);
    g.add("idle, confirm first", view(h, .{ .id = g.id("act-restart"), .label = plain("Restart crawler"), .confirm = plain("Restart the crawler? It drops its in-flight calls."), .on = on }));
    g.add("idle, runs at once", view(h, .{ .id = g.id("act-health"), .label = plain("Health check"), .on = on }));
    g.add("busy", view(h, .{ .id = g.id("act-build"), .label = plain("Build site"), .state = .busy }));
    g.add("held by another", view(h, .{ .id = g.id("act-eval"), .label = plain("Run eval"), .disabled = true }));
    g.add("ok, output", view(h, .{ .id = g.id("act-ok"), .label = plain("Health check"), .state = .ok, .when = plain("2 min ago"), .output = plain("disk 41% used\ncrawler: 182 matches/min\nall units active") }));
    g.add("failed, long output", view(h, .{ .id = g.id("act-fail"), .label = plain("Build site"), .state = .failed, .when = plain("just now"), .output = plain("error: render@b did not answer on /healthz within 30 s; kept render@a serving; see web.log at 2026-10-27T01:12:44Z for the build's own output and the upload's rsync stats") }));
}

const T = struct {
    arena: std.heap.ArenaAllocator,
    t: tree.Tree = .{},
    h: H = undefined,
    out: std.Io.Writer.Allocating = undefined,
    root: N = .none,
    runs: u32 = 0,

    pub const Msg = enum { run };
    pub fn update(x: *T, _: Msg, _: *tree.Event) void {
        x.runs += 1;
    }

    fn init(x: *T) void {
        x.* = .{ .arena = .init(std.testing.allocator) };
        x.h = .init(x.arena.allocator(), &x.t);
        x.out = .init(x.arena.allocator());
    }

    fn html(x: *T, a: Action) ![]const u8 {
        x.out.clearRetainingCapacity();
        x.root = view(&x.h, a);
        try std.testing.expect(!x.h.oom);
        try @import("html.zig").write(&x.t, x.root, &x.out.writer);
        return x.out.written();
    }

    fn has(x: *T, a: Action, want: []const []const u8, not: []const []const u8) !void {
        const s = try x.html(a);
        for (want) |w| if (std.mem.find(u8, s, w) == null) {
            std.debug.print("missing {s} in {s}\n", .{ w, s });
            return error.TestExpectedEqual;
        };
        for (not) |w| if (std.mem.find(u8, s, w) != null) {
            std.debug.print("unwanted {s} in {s}\n", .{ w, s });
            return error.TestExpectedEqual;
        };
    }

    /// Clicks node `n` the way the runtime does: its click handler, if any
    fn click(x: *T, n: N) bool {
        const hd = x.t.handler(n, .click) orelse return false;
        var ev: tree.Event = .{ .kind = .click };
        hd.call(hd.target, &hd.msg, &ev);
        return true;
    }
};

test "confirm first: the trigger only opens the popover, Run runs" {
    var x: T = undefined;
    x.init();
    defer x.arena.deinit();
    const on = x.h.on(&x, .run);
    try x.has(.{ .id = "x", .label = plain("Restart"), .confirm = plain("Sure?"), .on = on }, &.{
        "popover=\"\"",
        "popovertargetaction=\"hide\"",
        "<div class=\"live\" role=\"status\"></div>",
    }, &.{"data-state"});
    try std.testing.expectEqual(3, std.mem.count(u8, x.out.written(), "popovertarget=\"x\""));
    const trigger = x.t.find(x.root, "popovertarget", "x").?;
    try std.testing.expect(!x.click(trigger));
    try std.testing.expect(x.click(x.t.find(x.root, "data-v", "primary").?));
    try std.testing.expectEqual(1, x.runs);
}

test "no confirm runs at once; a confirm without a handler drops the popover" {
    var x: T = undefined;
    x.init();
    defer x.arena.deinit();
    try x.has(.{ .id = "x", .label = plain("Health"), .on = x.h.on(&x, .run) }, &.{}, &.{ "popover", "disabled" });
    try std.testing.expect(x.click(x.t.find(x.root, "type", "button").?));
    try std.testing.expectEqual(1, x.runs);
    try x.has(.{ .id = "x", .label = plain("Health"), .confirm = plain("Sure?") }, &.{}, &.{ "popover", "Sure?" });
}

test "busy and disabled: the button off, no confirm, no handler" {
    var x: T = undefined;
    x.init();
    defer x.arena.deinit();
    const on = x.h.on(&x, .run);
    try x.has(.{ .id = "x", .label = plain("Restart"), .confirm = plain("Sure?"), .on = on, .state = .busy }, &.{
        "data-state=\"busy\"",
        "aria-busy=\"true\"",
        "disabled",
        "class=\"spin\"",
    }, &.{"popover"});
    try std.testing.expect(!x.click(x.t.find(x.root, "type", "button").?));
    try x.has(.{ .id = "x", .label = plain("Restart"), .confirm = plain("Sure?"), .on = on, .disabled = true }, &.{"disabled"}, &.{ "popover", "aria-busy=\"true\"", "spin" });
    try std.testing.expect(!x.click(x.t.find(x.root, "type", "button").?));
    try std.testing.expectEqual(0, x.runs);
}

test "result: ok folds its output, failed opens it and alerts, no output no details" {
    var x: T = undefined;
    x.init();
    defer x.arena.deinit();
    try x.has(.{ .id = "x", .label = plain("Build"), .state = .ok, .when = plain("2 min ago"), .output = plain("all fine") }, &.{
        "<details>",
        "Done",
        "2 min ago",
        "all fine",
        "✓",
    }, &.{ "<details open", "role=\"alert\"" });
    try x.has(.{ .id = "x", .label = plain("Build"), .state = .failed, .output = plain("boom") }, &.{
        "<details open",
        "Failed",
        "✕",
        "role=\"alert\"",
        "data-state=\"failed\"",
    }, &.{"class=\"when\">2"});
    try x.has(.{ .id = "x", .label = plain("Build"), .state = .ok }, &.{"Done"}, &.{ "<details", "class=\"when\"" });
    try x.has(.{ .id = "x", .label = plain("Build"), .state = .failed, .output = plain("") }, &.{ "Failed", "role=\"alert\"" }, &.{"<details"});
}
