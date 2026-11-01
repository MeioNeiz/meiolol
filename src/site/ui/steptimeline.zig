//! StepTimeline: one deploy (a push to main) as a folding row. Folded: its state, short
//! sha, subject, a strip of its steps as long as its time against the longest row's, and
//! that time. Open: while running, a bar of the time so far against the usual; then a
//! waterfall, one row per step in the order they ran on the deploy's time axis (glyph and
//! colour for the state, its bar from its start, its time), a running step's usual time
//! as a ghost behind its bar, a step's detail under its row; the commits it carried. The
//! page derives the steps from deploys.tsv and writes the times (UK clock) into `when`
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
    /// When it started, seconds after the deploy's first step did
    at: ?u32 = null,
    /// The step's usual time, from past deploys
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
    /// Seconds from the push: to live, to its last step's end, or so far while running
    took: ?u32 = null,
    /// The usual `took` of a live deploy, from past ones
    usual: ?u32 = null,
    /// The push, seconds after the first step began (the push check runs before it)
    pushed_at: u32 = 0,
    /// The longest `took` among the rows shown: the folded strip's full length
    scale: u32 = 0,
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
    pub const of_usual = phrase.Phrase("{t:time} of ~{u:time}");
    pub const over = phrase.Phrase("{t:time}, {o:time} over");
    pub const usually = phrase.Phrase("usually {u:time}");
    pub const deploy_of = phrase.Phrase("{t:time} of usually {u:time}");
    pub const deploy_over = phrase.Phrase("{t:time}: {o:time} over the usual {u:time}");
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

/// A done step this much slower than usual reads as slow
fn slow(took: u32, usual: u32) bool {
    return took >= usual + 30 and took * 2 >= usual * 3;
}

fn pct(x: u32, of: u32) f64 {
    if (of == 0) return 0;
    return @min(100, 100 * @as(f64, @floatFromInt(x)) / @as(f64, @floatFromInt(of)));
}

/// A step's time: plain once ended; against its usual while it runs. Empty without one,
/// so each row fills the grid's 4 columns
fn stepTime(h: *H, s: Step) N {
    const t = s.took orelse return h.span(.{ .class = "t" }, .{});
    return switch (s.state) {
        .running, .waiting => if (s.usual) |u|
            (if (t > u) h.span(.{ .class = "t", .data_over = true }, .{W.over.with(h, .{ .t = t, .o = t - u })}) else h.span(.{ .class = "t" }, .{W.of_usual.with(h, .{ .t = t, .u = u })}))
        else
            h.span(.{ .class = "t" }, .{W.so_far.with(h, .{ .t = t })}),
        else => if (s.usual) |u| if (s.state == .done and slow(t, u))
            h.span(.{ .class = "t", .data_over = true, .title = W.usually.with(h, .{ .u = u }).s }, .{phrase.num(h, .time, t)})
        else
            h.span(.{ .class = "t" }, .{phrase.num(h, .time, t)}) else h.span(.{ .class = "t" }, .{phrase.num(h, .time, t)}),
    };
}

/// The waterfall's axis: to the last step's end, and for a running deploy on to when it
/// usually goes live
fn axisOf(d: Deploy) u32 {
    var end: u32 = 0;
    for (d.steps) |s| if (s.at) |a| {
        end = @max(end, a + (s.took orelse 0));
        if (s.state == .running or s.state == .waiting) if (s.usual) |u| {
            end = @max(end, a + u);
        };
    };
    if (d.state == .running) if (d.usual) |u| {
        end = @max(end, d.pushed_at + u);
    };
    return end;
}

pub fn view(h: *H, d: Deploy) N {
    const axis = axisOf(d);
    var rows = h.list();
    var strip = h.list();
    for (d.steps, 0..) |s, i| {
        // A step a deploy that ended left running stopped: no usual to run against
        const running = d.state == .running and (s.state == .running or s.state == .waiting);
        const bar: ?N = if (s.at) |a| h.span(.{ .class = "track", .aria_hidden = true }, .{
            if (running) if (s.usual) |u| h.el(.i, .{ .class = "ghost", .style = h.vars(.{ .x = pct(a, axis), .w = pct(u, axis) }) }, .{}) else null else null,
            h.el(.i, .{ .class = "bar", .style = h.vars(.{ .x = pct(a, axis), .w = pct(s.took orelse 0, axis) }) }, .{}),
        }) else h.span(.{ .class = "track" }, .{});
        rows.add(h.li(.{ .key = i, .data_state = s.state, .title = if (s.what.len > 0) s.what else null }, .{
            h.span(.{ .class = "g", .aria_hidden = true }, .{glyph(s.state)}),
            h.span(.{ .class = "n" }, .{
                s.name,
                // The glyph is aria-hidden and colour isn't read
                h.span(.{ .class = "sr" }, .{ ", ", stepWord(s.state) }),
            }),
            bar,
            stepTime(h, s),
            if (s.detail.len > 0) h.p(.{ .class = "d", .role = if (d.alert and s.state == .failed) "alert" else null }, .{s.detail}) else null,
        }));
        // The folded strip runs from the push: the push check before it has none
        const el = d.took orelse 0;
        if (s.at) |a| if (el > 0 and a + (s.took orelse 0) > d.pushed_at) {
            const from = @max(a, d.pushed_at) - d.pushed_at;
            const len = a + (s.took orelse 0) - d.pushed_at - from;
            strip.add(h.el(.i, .{ .key = i, .data_state = s.state, .style = h.vars(.{ .x = pct(from, el), .w = pct(len, el) }) }, .{}));
        };
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
    const progress: ?N = if (d.state == .running) if (d.took) |t| if (d.usual) |u| h.div(.{ .class = "prog", .data_over = t > u }, .{
        h.span(.{ .class = "track", .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{ .w = if (t > u) 100 else @min(99, pct(t, u)) }) }, .{})}),
        h.span(.{}, .{if (t > u) W.deploy_over.with(h, .{ .t = t, .o = t - u, .u = u }) else W.deploy_of.with(h, .{ .t = t, .u = u })}),
    }) else null else null else null;
    return h.el(.details, .{ .class = "c-steps", .data_state = d.state, .open = d.open, .on_toggle = d.on_toggle }, .{
        h.el(.summary, .{}, .{
            h.span(.{ .class = "st" }, .{stateWord(d.state)}),
            h.span(.{ .class = "sha" }, .{d.sha}),
            h.b(.{ .title = if (d.subject.len > 0) d.subject else null }, .{if (d.subject.len > 0) tree.Text{ .s = d.subject } else W.no_subject}),
            if (d.took) |t| h.span(.{ .class = "mini" }, .{
                h.span(.{ .class = "strip", .aria_hidden = true, .style = h.vars(.{ .w = pct(t, @max(t, d.scale)) }) }, .{strip.done()}),
                h.span(.{ .class = "tt" }, .{phrase.num(h, .time, t)}),
            }) else null,
            h.span(.{ .class = "when" }, .{d.when}),
        }),
        progress,
        if (d.steps.len > 0) h.el(.ol, .{ .class = "fall", .aria_label = W.steps }, .{rows.done()}) else null,
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
    \\  .c-steps .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
    \\  .c-steps .mini { display: inline-flex; align-items: center; gap: var(--sp-2); flex: 0 0 auto; }
    \\  .c-steps .mini .strip { position: relative; display: block; width: calc(var(--w) * 1.2px); min-width: 4px; height: 6px;
    \\    border-radius: 3px; background: var(--bar-track); overflow: hidden; }
    \\  .c-steps .mini .strip i { position: absolute; inset: 0 auto 0 calc(var(--x) * 1%); width: max(1px, calc(var(--w) * 1%));
    \\    background: var(--good); box-shadow: inset -1px 0 0 var(--bg); }
    \\  .c-steps .mini .strip i[data-state="running"], .c-steps .mini .strip i[data-state="waiting"] { background: var(--turn); }
    \\  .c-steps .mini .strip i[data-state="failed"] { background: var(--lo3); }
    \\  .c-steps .tt { min-width: 3.2em; text-align: end; color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-steps ol, .c-steps ul { list-style: none; margin: var(--sp-2) 0 0; padding: 0; }
    \\  .c-steps .prog { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-1) var(--sp-3); margin-top: var(--sp-2);
    \\    font-size: var(--fs-s); color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-steps .prog .track { position: relative; flex: 1 1 12rem; max-width: 32rem; height: 8px; border-radius: 4px;
    \\    background: var(--bar-track); overflow: hidden; }
    \\  .c-steps .prog .track i { position: absolute; inset: 0 auto 0 0; width: calc(var(--w) * 1%); border-radius: 4px;
    \\    background: var(--turn); transition: width 1s linear; }
    \\  .c-steps .prog[data-over] { color: var(--turn); }
    \\  .c-steps .fall { display: grid; grid-template-columns: 1.2em minmax(7rem, max-content) minmax(4rem, 1fr) auto;
    \\    gap: 2px var(--sp-2); align-items: center; font-size: var(--fs-xs); }
    \\  .c-steps .fall li { display: contents; }
    \\  .c-steps .fall .g { font-weight: var(--w-b); text-align: center; color: var(--muted); }
    \\  .c-steps .fall .n { color: var(--t2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    \\  .c-steps .fall .t { color: var(--muted); font-variant-numeric: tabular-nums; text-align: end; white-space: nowrap; }
    \\  .c-steps .fall .t[data-over] { color: var(--turn); }
    \\  .c-steps .fall .track { position: relative; height: 10px; border-radius: 2px; background: var(--bar-track); }
    \\  .c-steps .fall .track i { position: absolute; inset: 0 auto 0 calc(var(--x) * 1%); width: max(2px, calc(var(--w) * 1%));
    \\    border-radius: 2px; background: var(--good); }
    \\  .c-steps .fall .track .ghost { background: none; border: 1px dashed var(--turn-line); box-sizing: border-box; }
    \\  .c-steps .fall .d { grid-column: 2 / -1; margin: 0 0 var(--sp-1); color: var(--t2); overflow-wrap: anywhere; }
    \\  .c-steps .fall [data-state="done"] .g { color: var(--good); }
    \\  .c-steps .fall :is([data-state="running"], [data-state="waiting"]) :is(.g, .n) { color: var(--turn); }
    \\  .c-steps .fall :is([data-state="running"], [data-state="waiting"]) .track .bar { background: repeating-linear-gradient(-45deg,
    \\    var(--turn) 0 6px, var(--turn-line) 6px 12px); background-size: 17px 100%; animation: c-steps-run 1s linear infinite; }
    \\  .c-steps .fall [data-state="failed"] :is(.g, .n, .d) { color: var(--lo3); }
    \\  .c-steps .fall [data-state="failed"] .track .bar { background: var(--lo3); }
    \\  .c-steps .fall :is([data-state="skipped"], [data-state="pending"], [data-state="none"]) .n { color: var(--muted); }
    \\  @keyframes c-steps-run { to { background-position: 17px 0; } }
    \\  @media (prefers-reduced-motion: reduce) { .c-steps .fall .track .bar { animation: none; } .c-steps .prog .track i { transition: none; } }
    \\  .c-steps .commits { margin-top: var(--sp-2); font-size: var(--fs-xs); color: var(--t2); }
    \\  .c-steps .commits summary { cursor: pointer; color: var(--muted); }
    \\  .c-steps .commits ul { margin-top: var(--sp-1); }
    \\  .c-steps .commits li { overflow-wrap: anywhere; }
    \\}
    \\
;

const demo_steps = [_]Step{
    .{ .name = plain("Push check"), .what = "zig build ci on the Mac, before the push", .state = .done, .took = 214, .at = 0, .usual = 205 },
    .{ .name = plain("Deploy"), .state = .done, .took = 2, .at = 216, .usual = 2 },
    .{ .name = plain("Build and copy"), .state = .done, .took = 248, .at = 218, .usual = 150, .detail = "" },
    .{ .name = plain("Web loop"), .state = .done, .took = 31, .at = 466, .usual = 30, .detail = "signalled the running loop" },
    .{ .name = plain("Crawler restart"), .state = .skipped },
    .{ .name = plain("Site build"), .state = .running, .took = 95, .at = 497, .usual = 160 },
    .{ .name = plain("Upload"), .state = .pending },
    .{ .name = plain("Live on site"), .state = .pending },
};

const failed_steps = [_]Step{
    .{ .name = plain("Push check"), .state = .done, .took = 201, .at = 0 },
    .{ .name = plain("Deploy"), .state = .done, .took = 2, .at = 203 },
    .{ .name = plain("Build and copy"), .state = .failed, .took = 64, .at = 205, .detail = "zig build -Dtarget=aarch64-linux: error: expected type 'u32', found 'i64' (src/site/ui/admindata.zig:142)" },
    .{ .name = plain("Web loop"), .state = .none },
};

const live_steps = [_]Step{
    .{ .name = plain("Push check"), .state = .done, .took = 190, .at = 0 },
    .{ .name = plain("Deploy"), .state = .done, .took = 2, .at = 192 },
    .{ .name = plain("Build and copy"), .state = .done, .took = 151, .at = 194 },
    .{ .name = plain("Web loop"), .state = .done, .took = 30, .at = 345 },
    .{ .name = plain("Site build"), .state = .done, .took = 158, .at = 375 },
    .{ .name = plain("Upload"), .state = .done, .took = 40, .at = 533 },
    .{ .name = plain("Live on site"), .state = .done, .took = 3, .at = 573 },
};

const demo_commits = [_][]const u8{
    "e80f952e Draft tester review fixes: restore checks champions, bad model files retry",
    "11b1467d game.html reads the default role's file, never list.bin; a failed request gets a 500",
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("running, past one step's usual", view(h, .{ .state = .running, .sha = "e80f952e", .subject = demo_commits[0][9..], .when = plain("pushed 04:12, expected live around 04:21 (median 6:30 over the last 20 deploys)"), .steps = &demo_steps, .commits = &demo_commits, .open = true, .took = 376, .usual = 390, .pushed_at = 216, .scale = 520 }));
    g.addFill("running, over the usual", view(h, .{ .state = .running, .sha = "e80f952e", .subject = demo_commits[0][9..], .when = plain("pushed 04:12, taking longer than usual (median 4:30 over the last 20 deploys)"), .steps = &demo_steps, .open = true, .took = 376, .usual = 270, .pushed_at = 216, .scale = 520 }));
    g.addFill("failed", view(h, .{ .state = .failed, .sha = "11b1467d", .subject = demo_commits[1][9..], .when = plain("pushed 03:58"), .steps = &failed_steps, .commits = demo_commits[1..], .open = true, .alert = true, .took = 66, .pushed_at = 203, .scale = 520 }));
    g.addFill("live, open", view(h, .{ .state = .live, .sha = "459b807f", .subject = "Learn: Enter is the focused control's; digits choose and focus Lock in", .when = plain("pushed 03:30, live at 03:36 after 6:24"), .steps = &live_steps, .commits = demo_commits[0..1], .open = true, .took = 384, .pushed_at = 192, .scale = 520 }));
    g.addFill("live, folded", view(h, .{ .state = .live, .sha = "459b807f", .subject = "Learn: Enter is the focused control's; digits choose and focus Lock in", .when = plain("pushed 03:30, live at 03:36 after 6:24"), .steps = &live_steps, .commits = demo_commits[0..1], .took = 384, .pushed_at = 192, .scale = 520 }));
    g.addFill("skipped, no subject", view(h, .{ .state = .skipped, .sha = "6cdb1381", .subject = "", .when = plain("pushed 03:02, nothing on the box changed, so no round of its own") }));
    g.addFill("superseded", view(h, .{ .state = .superseded, .sha = "f034c7ef", .subject = "api --fixture: players in DIR/api-fixture.db, made afresh", .when = plain("pushed 02:40, replaced by a newer deploy before it went live"), .steps = demo_steps[0..3], .took = 250, .pushed_at = 216, .scale = 520 }));
    g.addFill("push refused", view(h, .{ .state = .refused, .sha = "b88df73d", .subject = "Daily review fixes", .when = plain("pushed 02:12"), .steps = &.{.{ .name = plain("Push check"), .state = .failed, .took = 188, .at = 0, .detail = "zig build ci: 2 tests failed" }}, .open = true }));
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

test "view: a waterfall row per step with times against the usual, details and commits" {
    var x: T = undefined;
    x.init();
    defer x.arena.deinit();
    var s = try x.html(.{ .state = .running, .sha = "e80f952e", .subject = "Fix", .when = plain("pushed 04:12"), .steps = &demo_steps, .commits = &demo_commits, .open = true, .took = 376, .usual = 390, .pushed_at = 216, .scale = 520 });
    try has(s, &.{
        "<details class=\"c-steps\" data-state=\"running\" open",
        ">Deploying<",
        "title=\"zig build ci on the Mac, before the push\"",
        ">3:34<",
        ">1:35 of ~2:40<",
        // Build and copy: 4:08 against a usual 2:30
        "data-over=\"\" title=\"usually 2:30\">4:08<",
        "class=\"ghost\"",
        ">6:16 of usually 6:30<",
        "data-state=\"skipped\"",
        "<p class=\"d\">signalled the running loop</p>",
        "2 commits",
        "Build and copy<span class=\"sr\">, done</span>",
        "Upload<span class=\"sr\">, pending</span>",
        "<span class=\"sha\">11b1467d</span> game.html",
        "class=\"tt\">6:16<",
    }, &.{"role=\"alert\""});
    try testing.expectEqual(demo_steps.len, std.mem.count(u8, s, "<li data-state="));
    // The folded strip starts at the push: no segment for the push check
    try testing.expectEqual(4, std.mem.count(u8, s, "<i data-state="));
    s = try x.html(.{ .state = .running, .sha = "a", .subject = "b", .when = plain(""), .steps = &demo_steps, .open = true, .took = 400, .usual = 300 });
    try has(s, &.{ ">6:40: 1:40 over the usual 5:00<", "class=\"prog\" data-over=\"\"" }, &.{});
    s = try x.html(.{ .state = .failed, .sha = "11b1467d", .subject = "", .when = plain("pushed 03:58"), .steps = &failed_steps, .commits = demo_commits[1..] });
    try has(s, &.{ "(no commit message recorded)", "<p class=\"d\">zig build", "1 commit", ", not reached<" }, &.{ " open", "so far", "role=\"alert\"", "class=\"prog\"" });
    s = try x.html(.{ .state = .failed, .sha = "11b1467d", .subject = "", .when = plain("pushed 03:58"), .steps = &failed_steps, .alert = true });
    try has(s, &.{"<p class=\"d\" role=\"alert\">zig build"}, &.{});
    // A running row the viewer folded stays folded
    s = try x.html(.{ .state = .running, .sha = "a", .subject = "b", .when = plain(""), .steps = &demo_steps });
    try has(s, &.{"data-state=\"running\">"}, &.{" open"});
    s = try x.html(.{ .state = .skipped, .sha = "6cdb1381", .subject = "Docs", .when = plain("pushed") });
    try has(s, &.{">Skipped<"}, &.{ "<ol", "<ul", "commit", "class=\"mini\"" });
    s = try x.html(.{ .state = .running, .sha = "a", .subject = "b", .when = plain(""), .steps = &.{.{ .name = plain("Upload"), .state = .waiting, .took = 5, .at = 0 }} });
    try has(s, &.{">0:05 so far<"}, &.{ "usually", "ghost" });
    s = try x.html(.{ .state = .running, .sha = "a", .subject = "b", .when = plain(""), .steps = &.{.{ .name = plain("Upload"), .state = .running, .took = 50, .at = 0, .usual = 40 }} });
    try has(s, &.{">0:50, 0:10 over<"}, &.{});
    s = try x.html(.{ .state = .live, .sha = "a", .subject = "b", .when = plain(""), .commits = &.{"nospace"} });
    try has(s, &.{"<span class=\"sha\">nospace</span></li>"}, &.{});
}
