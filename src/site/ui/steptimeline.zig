//! StepTimeline: one deploy (a push to main) as a folding row: its state, short sha,
//! subject and when, then one pill per step in the order they ran (glyph and colour for
//! the state, the time it took, "so far" while running), the detail of a step that has
//! one below, and the commits it carried. The page derives the steps from deploys.tsv
//! and writes the times (UK clock) into `when`
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "StepTimeline";
pub const scope = .{".c-steps"};

pub const State = enum { live, running, failed, skipped, superseded, refused };

pub const StepState = enum { done, running, waiting, failed, skipped, pending, none };

pub const Step = struct {
    name: tree.Text,
    /// What the step does, its pill's title
    what: []const u8 = "",
    state: StepState,
    /// Seconds, when started: the whole step once ended, so far while running
    took: ?u32 = null,
    /// The usual time of a running step, from past deploys
    usual: ?u32 = null,
    detail: []const u8 = "",
};

pub const Deploy = struct {
    state: State,
    sha: []const u8,
    subject: []const u8,
    /// "pushed 14:02, live at 14:09 after 7:12"
    when: tree.Text,
    steps: []const Step = &.{},
    /// "sha subject" each
    commits: []const []const u8 = &.{},
    /// The page owns it (opens the newest and a running one, keeps what the viewer folded)
    open: bool = false,
    on_toggle: ?tree.Handler = null,
    /// A failure the viewer should hear: a deploy that failed while the page was open.
    /// Otherwise a failed step's detail is plain text, so history doesn't announce itself
    alert: bool = false,
};

const W = struct {
    pub const live = plain("Live");
    pub const running = plain("Deploying");
    pub const failed = plain("Failed");
    pub const skipped = plain("Skipped");
    pub const superseded = plain("Superseded");
    pub const refused = plain("Push refused");
    pub const no_subject = plain("(no commit message recorded)");
    pub const steps = plain("Steps");
    pub const so_far = phrase.Phrase("{t:time} so far");
    pub const so_far_usual = phrase.Phrase("{t:time} so far, usually {u:time}");
    pub const commits = phrase.Phrase("{n:count} commits");
    pub const one_commit = plain("1 commit");
};

fn stateWord(s: State) tree.Text {
    return switch (s) {
        .live => W.live,
        .running => W.running,
        .failed => W.failed,
        .skipped => W.skipped,
        .superseded => W.superseded,
        .refused => W.refused,
    };
}

fn stepWord(s: StepState) tree.Text {
    return switch (s) {
        .done => plain("done"),
        .running => plain("running"),
        .waiting => plain("waiting"),
        .failed => plain("failed"),
        .skipped => plain("skipped"),
        .pending => plain("pending"),
        .none => plain("not reached"),
    };
}

fn glyph(s: StepState) []const u8 {
    return switch (s) {
        .done => "✓",
        .running => "●",
        .waiting => "…",
        .failed => "✕",
        .skipped => "–",
        .pending, .none => "○",
    };
}

pub fn view(h: *H, d: Deploy) N {
    var pills = h.list();
    var notes = h.list();
    for (d.steps, 0..) |s, i| {
        const took: ?tree.Text = if (s.took) |t| switch (s.state) {
            .running, .waiting => if (s.usual) |u| W.so_far_usual.with(h, .{ .t = t, .u = u }) else W.so_far.with(h, .{ .t = t }),
            else => phrase.num(h, .time, t),
        } else null;
        pills.add(h.li(.{ .key = i, .data_state = s.state, .title = if (s.what.len > 0) s.what else null }, .{
            h.span(.{ .class = "g", .aria_hidden = true }, .{glyph(s.state)}),
            s.name,
            // The glyph is aria-hidden and colour isn't read
            h.span(.{ .class = "sr" }, .{ ", ", stepWord(s.state) }),
            if (took) |t| h.span(.{ .class = "t" }, .{t}) else null,
        }));
        if (s.detail.len > 0) notes.add(h.li(.{ .key = i, .data_state = s.state, .role = if (d.alert and s.state == .failed) "alert" else null }, .{
            h.b(.{}, .{s.name}),
            " ",
            s.detail,
        }));
    }
    const n_commits = d.commits.len;
    var commits = h.list();
    for (d.commits, 0..) |c, i| {
        const sp = std.mem.findScalar(u8, c, ' ') orelse c.len;
        commits.add(h.li(.{ .key = i }, .{
            h.span(.{ .class = "sha" }, .{c[0..sp]}),
            if (sp < c.len) c[sp..] else "",
        }));
    }
    return h.el(.details, .{ .class = "c-steps", .data_state = d.state, .open = d.open, .on_toggle = d.on_toggle }, .{
        h.el(.summary, .{}, .{
            h.span(.{ .class = "st" }, .{stateWord(d.state)}),
            h.span(.{ .class = "sha" }, .{d.sha}),
            h.b(.{ .title = if (d.subject.len > 0) d.subject else null }, .{if (d.subject.len > 0) tree.Text{ .s = d.subject } else W.no_subject}),
            h.span(.{ .class = "when" }, .{d.when}),
        }),
        if (d.steps.len > 0) h.el(.ol, .{ .class = "pills", .aria_label = W.steps }, .{pills.done()}) else null,
        if (notes.items.items.len > 0) h.el(.ul, .{ .class = "notes" }, .{notes.done()}) else null,
        if (n_commits > 0) h.el(.details, .{ .class = "commits" }, .{
            h.el(.summary, .{}, .{if (n_commits == 1) W.one_commit else W.commits.with(h, .{ .n = n_commits })}),
            h.el(.ul, .{}, .{commits.done()}),
        }) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-steps { min-width: 0; border-bottom: 1px solid var(--line); padding: var(--sp-2) 0; }
    \\  .c-steps > summary { display: flex; flex-wrap: wrap; align-items: baseline; gap: var(--sp-1) var(--sp-2);
    \\    cursor: pointer; font-size: var(--fs-s); }
    \\  .c-steps > summary::-webkit-details-marker { display: none; }
    \\  .c-steps > summary::before { content: "▸"; color: var(--muted); transition: transform var(--dur) var(--ease); }
    \\  .c-steps[open] > summary::before { transform: rotate(90deg); }
    \\  .c-steps > summary b { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    \\    flex: 1 1 12em; font-weight: var(--w-m); color: var(--text); }
    \\  .c-steps .st { font-weight: var(--w-b); color: var(--muted); }
    \\  .c-steps[data-state="live"] .st { color: var(--good); }
    \\  .c-steps[data-state="running"] .st { color: var(--turn); }
    \\  .c-steps[data-state="failed"] .st, .c-steps[data-state="refused"] .st { color: var(--lo3); }
    \\  .c-steps .sha { font: var(--fs-xs) ui-monospace, monospace; color: var(--t2); }
    \\  .c-steps .when { flex: 1 0 100%; color: var(--muted); }
    \\  .c-steps ol, .c-steps ul { list-style: none; margin: var(--sp-2) 0 0; padding: 0; }
    \\  .c-steps .pills { display: flex; flex-wrap: wrap; gap: var(--sp-1); }
    \\  .c-steps .pills li { display: inline-flex; align-items: center; gap: 6px; min-height: var(--ctl-s);
    \\    padding: 0 var(--sp-2); border: 1px solid var(--line-2); border-radius: var(--r-pill);
    \\    font-size: var(--fs-xs); color: var(--t2); }
    \\  .c-steps .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
    \\  .c-steps .pills .g { font-weight: var(--w-b); }
    \\  .c-steps .pills .t { color: var(--muted); font-variant-numeric: tabular-nums; }
    \\  .c-steps .pills [data-state="done"] .g { color: var(--good); }
    \\  .c-steps .pills [data-state="running"], .c-steps .pills [data-state="waiting"] { border-color: var(--turn-line); color: var(--text); }
    \\  .c-steps .pills [data-state="running"] .g, .c-steps .pills [data-state="waiting"] .g { color: var(--turn); }
    \\  .c-steps .pills [data-state="failed"] { border-color: var(--bad-line); color: var(--text); }
    \\  .c-steps .pills [data-state="failed"] .g { color: var(--lo3); }
    \\  .c-steps .pills [data-state="skipped"], .c-steps .pills [data-state="pending"],
    \\  .c-steps .pills [data-state="none"] { color: var(--muted); border-style: dashed; }
    \\  .c-steps .notes li { font-size: var(--fs-xs); color: var(--t2); overflow-wrap: anywhere; }
    \\  .c-steps .notes [data-state="failed"] { color: var(--lo3); }
    \\  .c-steps .commits { margin-top: var(--sp-2); font-size: var(--fs-xs); color: var(--t2); }
    \\  .c-steps .commits summary { cursor: pointer; color: var(--muted); }
    \\  .c-steps .commits ul { margin-top: var(--sp-1); }
    \\  .c-steps .commits li { overflow-wrap: anywhere; }
    \\}
    \\
;

const demo_steps = [_]Step{
    .{ .name = plain("Push check"), .what = "zig build ci on the Mac, before the push", .state = .done, .took = 214 },
    .{ .name = plain("Deploy"), .state = .done, .took = 2 },
    .{ .name = plain("Build and copy"), .state = .done, .took = 148 },
    .{ .name = plain("Web loop"), .state = .done, .took = 31, .detail = "signalled the running loop" },
    .{ .name = plain("Crawler restart"), .state = .skipped },
    .{ .name = plain("Site build"), .state = .running, .took = 95, .usual = 160 },
    .{ .name = plain("Upload"), .state = .pending },
    .{ .name = plain("Live on site"), .state = .pending },
};

const failed_steps = [_]Step{
    .{ .name = plain("Push check"), .state = .done, .took = 201 },
    .{ .name = plain("Deploy"), .state = .done, .took = 2 },
    .{ .name = plain("Build and copy"), .state = .failed, .took = 64, .detail = "zig build -Dtarget=aarch64-linux: error: expected type 'u32', found 'i64' (src/site/ui/admindata.zig:142)" },
    .{ .name = plain("Web loop"), .state = .none },
};

const demo_commits = [_][]const u8{
    "e80f952e Draft tester review fixes: restore checks champions, bad model files retry",
    "11b1467d game.html reads the default role's file, never list.bin; a failed request gets a 500",
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("running", view(h, .{ .state = .running, .sha = "e80f952e", .subject = demo_commits[0][9..], .when = plain("pushed 04:12, expected live around 04:21 (median 8:40 over the last 20 deploys)"), .steps = &demo_steps, .commits = &demo_commits, .open = true }));
    g.addFill("failed", view(h, .{ .state = .failed, .sha = "11b1467d", .subject = demo_commits[1][9..], .when = plain("pushed 03:58"), .steps = &failed_steps, .commits = demo_commits[1..], .open = true, .alert = true }));
    g.addFill("live, folded", view(h, .{ .state = .live, .sha = "459b807f", .subject = "Learn: Enter is the focused control's; digits choose and focus Lock in", .when = plain("pushed 03:30, live at 03:38 after 8:02"), .steps = demo_steps[0..4], .commits = demo_commits[0..1] }));
    g.addFill("skipped, no subject", view(h, .{ .state = .skipped, .sha = "6cdb1381", .subject = "", .when = plain("pushed 03:02, nothing on the box changed, so no round of its own") }));
    g.addFill("superseded", view(h, .{ .state = .superseded, .sha = "f034c7ef", .subject = "api --fixture: players in DIR/api-fixture.db, made afresh", .when = plain("pushed 02:40, replaced by a newer deploy before it went live"), .steps = demo_steps[0..3] }));
    g.addFill("push refused", view(h, .{ .state = .refused, .sha = "b88df73d", .subject = "Daily review fixes", .when = plain("pushed 02:12"), .steps = &.{.{ .name = plain("Push check"), .state = .failed, .took = 188, .detail = "zig build ci: 2 tests failed" }}, .open = true }));
}

const testing = std.testing;

const T = struct {
    arena: std.heap.ArenaAllocator,
    t: tree.Tree = .{},
    h: H = undefined,
    out: std.Io.Writer.Allocating = undefined,

    fn init(x: *T) void {
        x.* = .{ .arena = .init(testing.allocator) };
        x.h = .init(x.arena.allocator(), &x.t);
        x.out = .init(x.arena.allocator());
    }

    fn html(x: *T, d: Deploy) ![]const u8 {
        x.out.clearRetainingCapacity();
        const root = view(&x.h, d);
        try testing.expect(!x.h.oom);
        try @import("html.zig").write(&x.t, root, &x.out.writer);
        return x.out.written();
    }
};

fn has(s: []const u8, want: []const []const u8, not: []const []const u8) !void {
    for (want) |w| if (std.mem.find(u8, s, w) == null) {
        std.debug.print("missing {s} in {s}\n", .{ w, s });
        return error.TestExpectedEqual;
    };
    for (not) |w| if (std.mem.find(u8, s, w) != null) {
        std.debug.print("unwanted {s} in {s}\n", .{ w, s });
        return error.TestExpectedEqual;
    };
}

test "view: pills per step with times and state words, details and commits" {
    var x: T = undefined;
    x.init();
    defer x.arena.deinit();
    var s = try x.html(.{ .state = .running, .sha = "e80f952e", .subject = "Fix", .when = plain("pushed 04:12"), .steps = &demo_steps, .commits = &demo_commits, .open = true });
    try has(s, &.{
        "<details class=\"c-steps\" data-state=\"running\" open",
        ">Deploying<",
        "title=\"zig build ci on the Mac, before the push\"",
        ">3:34<",
        ">1:35 so far, usually 2:40<",
        "data-state=\"skipped\"",
        "<b>Web loop</b> signalled the running loop",
        "2 commits",
        "Build and copy<span class=\"sr\">, done</span>",
        "Upload<span class=\"sr\">, pending</span>",
        "<span class=\"sha\">11b1467d</span> game.html",
    }, &.{"role=\"alert\""});
    try testing.expectEqual(demo_steps.len, std.mem.count(u8, s, "<li data-state=") - 1);
    s = try x.html(.{ .state = .failed, .sha = "11b1467d", .subject = "", .when = plain("pushed 03:58"), .steps = &failed_steps, .commits = demo_commits[1..] });
    try has(s, &.{ "(no commit message recorded)", "<li data-state=\"failed\"><b>Build and copy</b>", "1 commit", ", not reached<" }, &.{ " open", "so far", "role=\"alert\"" });
    s = try x.html(.{ .state = .failed, .sha = "11b1467d", .subject = "", .when = plain("pushed 03:58"), .steps = &failed_steps, .alert = true });
    try has(s, &.{"role=\"alert\"><b>Build and copy</b>"}, &.{});
    // A running row the viewer folded stays folded
    s = try x.html(.{ .state = .running, .sha = "a", .subject = "b", .when = plain(""), .steps = &demo_steps });
    try has(s, &.{"data-state=\"running\">"}, &.{" open"});
    s = try x.html(.{ .state = .skipped, .sha = "6cdb1381", .subject = "Docs", .when = plain("pushed") });
    try has(s, &.{">Skipped<"}, &.{ "<ol", "<ul", "commit" });
    s = try x.html(.{ .state = .running, .sha = "a", .subject = "b", .when = plain(""), .steps = &.{.{ .name = plain("Upload"), .state = .waiting, .took = 5 }} });
    try has(s, &.{">0:05 so far<"}, &.{"usually"});
    s = try x.html(.{ .state = .live, .sha = "a", .subject = "b", .when = plain(""), .commits = &.{"nospace"} });
    try has(s, &.{"<span class=\"sha\">nospace</span></li>"}, &.{});
}
