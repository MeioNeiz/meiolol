//! LogView: the tail of one of the box's logs on an ops page. A row of files, each with
//! its error and warning counts; a filter (case-insensitive, matches marked); "n of m
//! lines"; Follow and Reload; then the lines in a box that opens at its bottom (column-
//! reverse, no script), error and warning lines coloured. The page fetches the text,
//! counts with `level` and keeps the filter
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "LogView";
pub const scope = .{".c-log"};

pub const File = struct {
    name: []const u8,
    errors: u32 = 0,
    warnings: u32 = 0,
    on: ?tree.Handler = null,
};

pub const State = enum { loading, ready, failed };

pub const Log = struct {
    files: []const File,
    /// Index into files
    shown: usize = 0,
    state: State = .ready,
    /// Oldest first
    lines: []const []const u8 = &.{},
    filter: []const u8 = "",
    on_filter: ?tree.Handler = null,
    follow: bool = false,
    on_follow: ?tree.Handler = null,
    on_reload: ?tree.Handler = null,
};

pub const Level = enum { none, warn, err };

const W = struct {
    pub const files = plain("Log files");
    pub const filter = plain("Filter");
    pub const follow = plain("Follow");
    pub const reload = plain("Reload");
    pub const loading = plain("Loading…");
    pub const failed = phrase.Phrase("Could not load {file:text}");
    pub const empty = plain("Empty");
    pub const no_match = plain("No lines match");
    pub const shown = phrase.Phrase("{n:count} of {m:count} lines");
    pub const errors = phrase.Phrase("{n:count} errors");
    pub const warnings = phrase.Phrase("{n:count} warnings");
};

/// A line's std.log level after its stamp, backup's FAILED and health's "problem:"; an
/// info line that says "rms error" is neither
pub fn level(line: []const u8) Level {
    const rest = std.mem.trimStart(u8, line[stampLen(line)..], " ");
    if (std.mem.startsWith(u8, rest, "error(") or std.mem.startsWith(u8, rest, "error:")) return .err;
    if (std.mem.find(u8, rest, "FAILED") != null) return .err;
    if (std.mem.startsWith(u8, rest, "warning(") or std.mem.startsWith(u8, rest, "warning:")) return .warn;
    if (std.mem.find(u8, rest, " problem:") != null) return .warn;
    return .none;
}

/// "2026-10-17 18:52:27", "2026-10-17T18:52:14Z" or Python's "…,823" at the start; 0 for none
fn stampLen(l: []const u8) usize {
    if (l.len < 19) return 0;
    for (l[0..19], "0000-00-00T00:00:00") |c, want| switch (want) {
        '0' => if (!std.ascii.isDigit(c)) return 0,
        'T' => if (c != 'T' and c != ' ') return 0,
        else => if (c != want) return 0,
    };
    var n: usize = 19;
    if (n < l.len and l[n] == 'Z') {
        n += 1;
    } else if (n < l.len and l[n] == ',') {
        n += 1;
        while (n < l.len and std.ascii.isDigit(l[n])) n += 1;
    }
    return n;
}

pub fn view(h: *H, o: Log) N {
    var tabs = h.list();
    for (o.files, 0..) |f, i| tabs.add(h.button(.{
        .key = i,
        .type = "button",
        .aria_pressed = i == o.shown,
        .on_click = f.on,
    }, .{
        f.name,
        if (f.errors > 0) h.span(.{ .class = "n", .data_k = Level.err, .title = W.errors.with(h, .{ .n = f.errors }).s }, .{phrase.num(h, .count, f.errors)}) else null,
        if (f.warnings > 0) h.span(.{ .class = "n", .data_k = Level.warn, .title = W.warnings.with(h, .{ .n = f.warnings }).s }, .{phrase.num(h, .count, f.warnings)}) else null,
    }));
    var rows = h.list();
    var n: u32 = 0;
    if (o.state == .ready) for (o.lines, 0..) |l, i| {
        if (o.filter.len > 0 and std.ascii.findIgnoreCase(l, o.filter) == null) continue;
        n += 1;
        const k = level(l);
        rows.add(h.div(.{ .key = i, .data_k = if (k == .none) null else k }, .{marked(h, l, o.filter)}));
    };
    const file = if (o.shown < o.files.len) o.files[o.shown].name else "";
    return h.div(.{ .class = "c-log" }, .{
        h.div(.{ .class = "files", .role = "group", .aria_label = W.files }, .{tabs.done()}),
        h.div(.{ .class = "bar" }, .{
            h.input(.{
                .type = "search",
                .placeholder = W.filter,
                .aria_label = W.filter,
                .autocomplete = "off",
                .spellcheck = "false",
                .value = o.filter,
                .on_input = o.on_filter,
            }),
            if (o.state == .ready and o.lines.len > 0) h.span(.{ .class = "count", .role = "status" }, .{W.shown.with(h, .{ .n = n, .m = o.lines.len })}) else null,
            h.button(.{ .class = "c-btn", .type = "button", .data_s = "s", .aria_pressed = o.follow, .on_click = o.on_follow }, .{W.follow}),
            h.button(.{ .class = "c-btn", .type = "button", .data_s = "s", .disabled = o.state == .loading, .on_click = o.on_reload }, .{W.reload}),
        }),
        switch (o.state) {
            .loading => h.p(.{ .class = "note", .role = "status" }, .{W.loading}),
            .failed => h.p(.{ .class = "note", .role = "alert" }, .{W.failed.with(h, .{ .file = file })}),
            .ready => if (o.lines.len == 0)
                h.p(.{ .class = "note" }, .{W.empty})
            else if (n == 0)
                h.p(.{ .class = "note" }, .{W.no_match})
            else
                h.div(.{ .class = "tail", .tabindex = 0, .aria_label = file }, .{h.div(.{ .class = "lines" }, .{rows.done()})}),
        },
    });
}

/// The line with each match of `q` in a <mark>
fn marked(h: *H, l: []const u8, q: []const u8) N {
    if (q.len == 0) return h.text(l);
    var parts = h.list();
    var at: usize = 0;
    var k: u32 = 0;
    while (std.ascii.findIgnoreCasePos(l, at, q)) |i| : (k += 1) {
        if (i > at) parts.add(h.text(l[at..i]));
        parts.add(h.el(.mark, .{ .key = k }, .{l[i .. i + q.len]}));
        at = i + q.len;
    }
    if (at < l.len) parts.add(h.text(l[at..]));
    return h.span(.{}, .{parts.done()});
}

pub const css =
    \\@layer components {
    \\  .c-log { display: grid; gap: var(--sp-2); min-width: 0; }
    \\  .c-log .files { display: flex; flex-wrap: wrap; gap: var(--sp-1); }
    \\  .c-log .files button { display: inline-flex; align-items: center; gap: 6px; min-height: var(--ctl-s);
    \\    padding: 0 var(--sp-2); border: 1px solid var(--line-2); border-radius: var(--r-pill);
    \\    background: none; color: var(--t2); font: inherit; font-size: var(--fs-s); cursor: pointer; }
    \\  .c-log .files button[aria-pressed="true"] { border-color: var(--accent); color: var(--text); }
    \\  .c-log .n { font-size: var(--fs-xs); font-variant-numeric: tabular-nums; }
    \\  .c-log .n[data-k="err"] { color: var(--lo3); }
    \\  .c-log .n[data-k="warn"] { color: var(--turn); }
    \\  .c-log .bar { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\  .c-log .bar input { flex: 1 1 12em; min-width: 0; height: var(--ctl-s); padding: 0 var(--sp-2);
    \\    border: 1px solid var(--line-2); border-radius: var(--r-s); background: var(--panel-2); color: var(--text); font: inherit; }
    \\  .c-log .count { color: var(--muted); font-size: var(--fs-s); font-variant-numeric: tabular-nums; }
    \\  .c-log .note { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-log .note[role="alert"] { color: var(--lo3); }
    \\  .c-log .tail { display: flex; flex-direction: column-reverse; max-height: 28em; overflow: auto;
    \\    padding: var(--sp-2); border-radius: var(--r-s); background: var(--panel-2); }
    \\  .c-log .lines { font: var(--fs-xs)/1.5 ui-monospace, monospace; color: var(--t2);
    \\    white-space: pre-wrap; overflow-wrap: anywhere; }
    \\  .c-log .lines [data-k="err"] { color: var(--lo3); }
    \\  .c-log .lines [data-k="warn"] { color: var(--turn); }
    \\  .c-log mark { background: var(--turn-line); color: var(--text); border-radius: 2px; }
    \\}
    \\
;

const demo_lines = [_][]const u8{
    "2026-10-27T01:10:02Z info(crawl): EUW1 182 matches/min, queue 41,203",
    "2026-10-27T01:10:31Z warning(riot): 429 on match-v5, backing off 4 s",
    "2026-10-27T01:11:02Z info(crawl): EUW1 179 matches/min, queue 41,180",
    "2026-10-27T01:11:40Z error(store): disk write took 2.4 s (fsync), kept going",
    "2026-10-27T01:12:02Z info(crawl): lane model rms error 0.31",
    "2026-10-27T01:12:44Z info(web): round done, 3,412 files, uploaded in 41 s to render@b after its /healthz answered",
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const files = [_]File{
        .{ .name = "crawl", .errors = 1, .warnings = 12 },
        .{ .name = "web", .warnings = 2 },
        .{ .name = "backup" },
        .{ .name = "health" },
    };
    const fs = h.mem.dupe(File, &files) catch {
        h.oom = true;
        return;
    };
    g.addFill("tail", view(h, .{ .files = fs, .lines = &demo_lines }));
    g.addFill("filtered, following", view(h, .{ .files = fs, .lines = &demo_lines, .filter = "crawl", .follow = true }));
    g.addFill("no match", view(h, .{ .files = fs, .lines = &demo_lines, .filter = "zzz" }));
    g.addFill("loading", view(h, .{ .files = fs, .shown = 1, .state = .loading }));
    g.addFill("could not load", view(h, .{ .files = fs, .shown = 2, .state = .failed }));
    g.addFill("empty", view(h, .{ .files = fs, .shown = 3 }));
}

const testing = std.testing;

test "level: the std.log level after the stamp, FAILED and problem lines" {
    try testing.expectEqual(.err, level("2026-10-27T01:11:40Z error(store): slow"));
    try testing.expectEqual(.err, level("2026-10-17 18:52:27,823 error: boom"));
    try testing.expectEqual(.err, level("backup FAILED: no space"));
    try testing.expectEqual(.warn, level("2026-10-27T01:10:31Z warning(riot): 429"));
    try testing.expectEqual(.warn, level("2026-10-27 01:10:31 health problem: disk 91%"));
    try testing.expectEqual(.none, level("2026-10-27T01:12:02Z info(crawl): rms error 0.31"));
    try testing.expectEqual(.none, level(""));
    try testing.expectEqual(.err, level("error: no stamp"));
    try testing.expectEqual(19, stampLen("2026-10-17 18:52:27 x"));
    try testing.expectEqual(20, stampLen("2026-10-17T18:52:27Z"));
    try testing.expectEqual(23, stampLen("2026-10-17 18:52:27,823"));
    try testing.expectEqual(0, stampLen("2026-10-17x18:52:27"));
}

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

    fn html(x: *T, o: Log) ![]const u8 {
        x.out.clearRetainingCapacity();
        const root = view(&x.h, o);
        try testing.expect(!x.h.oom);
        try @import("html.zig").write(&x.t, root, &x.out.writer);
        return x.out.written();
    }
};

test "view: filter marks matches, counts, colours by level; states" {
    var x: T = undefined;
    x.init();
    defer x.arena.deinit();
    const files = [_]File{ .{ .name = "crawl", .errors = 1, .warnings = 12 }, .{ .name = "web" } };
    var s = try x.html(.{ .files = &files, .lines = &demo_lines, .filter = "EUW1" });
    try testing.expectEqual(2, std.mem.count(u8, s, "<mark>EUW1</mark>"));
    try testing.expect(std.mem.find(u8, s, "2 of 6 lines") != null);
    try testing.expect(std.mem.find(u8, s, "aria-pressed=\"true\">crawl") != null);
    try testing.expect(std.mem.find(u8, s, "title=\"12 warnings\"") != null);
    s = try x.html(.{ .files = &files, .lines = &demo_lines, .filter = "euw1 18" });
    try testing.expectEqual(1, std.mem.count(u8, s, "<mark>EUW1 18</mark>2"));
    s = try x.html(.{ .files = &files, .lines = &demo_lines });
    try testing.expect(std.mem.find(u8, s, "6 of 6 lines") != null);
    try testing.expectEqual(1, std.mem.count(u8, s, "data-k=\"err\">2026"));
    try testing.expectEqual(1, std.mem.count(u8, s, "data-k=\"warn\">2026"));
    try testing.expect(std.mem.find(u8, s, "<mark>") == null);
    s = try x.html(.{ .files = &files, .lines = &demo_lines, .filter = "zzz" });
    try testing.expect(std.mem.find(u8, s, "No lines match") != null);
    s = try x.html(.{ .files = &files, .shown = 1, .state = .failed });
    try testing.expect(std.mem.find(u8, s, "Could not load web") != null);
    try testing.expect(std.mem.find(u8, s, " of ") == null);
    s = try x.html(.{ .files = &files, .state = .loading });
    try testing.expect(std.mem.find(u8, s, "Loading") != null);
    try testing.expect(std.mem.find(u8, s, "disabled") != null);
    s = try x.html(.{ .files = &files, .shown = 9 });
    try testing.expect(std.mem.find(u8, s, "Empty") != null);
    try testing.expect(std.mem.find(u8, s, " of ") == null);
}
