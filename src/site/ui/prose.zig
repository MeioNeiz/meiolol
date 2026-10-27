//! Prose: a markdown doc (learned.md, model.md, the eval report) as nodes. parse() runs
//! server side and gives a Doc that data.zig encodes, so ui.wasm carries the view and no
//! parser. The subset the docs use: # headings, paragraphs, bullets (one nested level),
//! pipe tables, ``` fences, inline `code` and **bold**; anything else stays literal text.
//! The root carries data-prose: check.zig holds quoted docs to no label or word budget
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const H = tree.H;
const N = tree.N;
const Allocator = std.mem.Allocator;

pub const name = "Prose";
pub const scope = .{".c-prose"};

pub const Run = struct {
    kind: enum { plain, code, bold } = .plain,
    s: []const u8,
};

/// Runs of one line of text: a paragraph, a list item, a table cell
pub const Line = []const Run;

pub const Item = struct { line: Line, sub: []const Line = &.{} };

/// `id`: the text's slug, unique in the doc ("lane-model", a second one "lane-model-2")
pub const Heading = struct { level: u8, line: Line, id: []const u8 = "" };

/// `head` empty when the table has no separator row
pub const Table = struct { head: []const Line, rows: []const []const Line };

pub const Block = union(enum) {
    heading: Heading,
    para: Line,
    list: []const Item,
    table: Table,
    code: []const u8,
};

pub const Doc = struct { blocks: []const Block };

/// Strings point into `src` or `a`: parse into an arena that outlives the Doc
pub fn parse(a: Allocator, src: []const u8) Allocator.Error!Doc {
    var p: Parser = .{ .a = a, .lines = std.mem.splitScalar(u8, src, '\n') };
    var blocks: std.ArrayList(Block) = .empty;
    while (p.peek()) |raw| {
        const l = std.mem.trimEnd(u8, raw, ws);
        const lead = l.len - std.mem.trimStart(u8, l, ws).len;
        const t = l[lead..];
        if (t.len == 0) {
            p.skip();
        } else if (std.mem.startsWith(u8, t, "```")) {
            try blocks.append(a, .{ .code = try p.fence() });
        } else if (headingLevel(t)) |n| {
            p.skip();
            try blocks.append(a, .{ .heading = .{ .level = n, .line = try inline_(a, std.mem.trim(u8, t[n..], " #")) } });
        } else if (p.tableAhead(t)) {
            try blocks.append(a, .{ .table = try p.table() });
        } else if (bullet(t) != null) {
            try blocks.append(a, .{ .list = try p.list() });
        } else {
            try blocks.append(a, .{ .para = try inline_(a, try p.para()) });
        }
    }
    try slugs(a, blocks.items);
    return .{ .blocks = blocks.items };
}

fn slugs(a: Allocator, blocks: []Block) Allocator.Error!void {
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    for (blocks) |*b| if (b.* == .heading) {
        var w: std.ArrayList(u8) = .empty;
        for (b.heading.line) |r| for (r.s) |c| {
            if (std.ascii.isAlphanumeric(c)) {
                try w.append(a, std.ascii.toLower(c));
            } else if (w.items.len > 0 and w.items[w.items.len - 1] != '-') try w.append(a, '-');
        };
        const base = std.mem.trimEnd(u8, w.items, "-");
        var id = if (base.len > 0) base else "s";
        var n: usize = 2;
        while (seen.contains(id)) : (n += 1) id = try a.print("{s}-{d}", .{ base, n });
        try seen.put(a, id, {});
        b.heading.id = id;
    };
}

const Parser = struct {
    a: Allocator,
    lines: std.mem.SplitIterator(u8, .scalar),

    fn peek(p: *Parser) ?[]const u8 {
        return p.lines.peek();
    }

    fn skip(p: *Parser) void {
        _ = p.lines.next();
    }

    /// The lines between the fences, as they are; an unclosed fence runs to the end
    fn fence(p: *Parser) ![]const u8 {
        p.skip();
        var w: std.ArrayList(u8) = .empty;
        while (p.lines.next()) |raw| {
            const l = std.mem.trimEnd(u8, raw, "\r");
            if (std.mem.startsWith(u8, std.mem.trimStart(u8, l, " "), "```")) break;
            if (w.items.len > 0) try w.append(p.a, '\n');
            try w.appendSlice(p.a, l);
        }
        return w.items;
    }

    fn table(p: *Parser) !Table {
        var rows: std.ArrayList([]const Line) = .empty;
        var head: []const Line = &.{};
        while (p.peek()) |raw| {
            const l = std.mem.trim(u8, raw, ws);
            if (l.len == 0 or l[0] != '|') break;
            p.skip();
            if (isSeparator(l)) {
                if (rows.items.len == 1 and head.len == 0) {
                    head = rows.items[0];
                    rows.clearRetainingCapacity();
                }
                continue;
            }
            try rows.append(p.a, try p.cells(l));
        }
        // Rows as wide as the head, as GitHub draws them: a short one padded, a long one cut
        if (head.len > 0) for (rows.items) |*r| if (r.len != head.len) {
            const fit = try p.a.alloc(Line, head.len);
            for (fit, 0..) |*c, i| c.* = if (i < r.len) r.*[i] else &.{};
            r.* = fit;
        };
        return .{ .head = head, .rows = rows.items };
    }

    /// A row's cells: split on | outside `code`, `\|` kept as |. A lone backtick pairs
    /// with the next one as in inline_, so the split and the cell's runs agree
    fn cells(p: *Parser, l: []const u8) ![]const Line {
        var out: std.ArrayList(Line) = .empty;
        var start: usize = 1;
        var in_code = false;
        var i: usize = 1;
        while (i < l.len) : (i += 1) switch (l[i]) {
            '\\' => if (i + 1 < l.len and l[i + 1] == '|') {
                i += 1;
            },
            '`' => in_code = !in_code,
            '|' => if (!in_code) {
                try out.append(p.a, try p.cell(l[start..i]));
                start = i + 1;
            },
            else => {},
        };
        if (std.mem.trim(u8, l[start..], ws).len > 0) try out.append(p.a, try p.cell(l[start..]));
        return out.items;
    }

    fn cell(p: *Parser, raw: []const u8) !Line {
        const t = std.mem.trim(u8, raw, ws);
        if (std.mem.find(u8, t, "\\|") == null) return inline_(p.a, t);
        return inline_(p.a, try std.mem.replaceOwned(u8, p.a, t, "\\|", "|"));
    }

    /// A | line opens a table only above a separator row: the docs wrap at 90, so a
    /// wrapped line may start with one ("|mean| <= 0.0015")
    fn tableAhead(p: *const Parser, t: []const u8) bool {
        if (t[0] != '|') return false;
        var it = p.lines;
        _ = it.next();
        const next = it.next() orelse return false;
        return isSeparator(std.mem.trim(u8, next, ws));
    }

    fn interrupts(p: *const Parser, t: []const u8) bool {
        return std.mem.startsWith(u8, t, "```") or p.tableAhead(t);
    }

    /// Items start at "- " or "* "; indented ones nest under the item before; any
    /// other line up to a blank or a new block continues the last item
    fn list(p: *Parser) ![]const Item {
        const Open = struct { text: std.ArrayList(u8) = .empty, sub: std.ArrayList(std.ArrayList(u8)) = .empty };
        var items: std.ArrayList(Open) = .empty;
        while (p.peek()) |raw| {
            const l = std.mem.trimEnd(u8, raw, ws);
            const t = std.mem.trimStart(u8, l, ws);
            // A heading ends a list only from the margin: a wrapped "# of games" is indented
            if (t.len == 0 or p.interrupts(t) or (l.len == t.len and headingLevel(t) != null)) break;
            p.skip();
            const nested = l.len - t.len >= 2 and items.items.len > 0;
            if (bullet(t)) |rest| {
                if (nested) {
                    var s: std.ArrayList(u8) = .empty;
                    try s.appendSlice(p.a, rest);
                    try items.items[items.items.len - 1].sub.append(p.a, s);
                } else {
                    try items.append(p.a, .{});
                    try items.items[items.items.len - 1].text.appendSlice(p.a, rest);
                }
                continue;
            }
            // A continuation line before any bullet can't happen: list() starts on one
            const last = &items.items[items.items.len - 1];
            const into = if (last.sub.items.len > 0) &last.sub.items[last.sub.items.len - 1] else &last.text;
            try into.append(p.a, ' ');
            try into.appendSlice(p.a, t);
        }
        const out = try p.a.alloc(Item, items.items.len);
        for (items.items, out) |*o, *it| {
            const sub = try p.a.alloc(Line, o.sub.items.len);
            for (o.sub.items, sub) |s, *x| x.* = try inline_(p.a, s.items);
            it.* = .{ .line = try inline_(p.a, o.text.items), .sub = sub };
        }
        return out;
    }

    /// Lines up to a blank, a list, a fence or a table, joined by spaces (the docs wrap at
    /// 90). A heading needs the blank before it: a wrapped line may start "# of games"
    fn para(p: *Parser) ![]const u8 {
        var w: std.ArrayList(u8) = .empty;
        while (p.peek()) |raw| {
            const t = std.mem.trim(u8, raw, ws);
            if (t.len == 0 or (w.items.len > 0 and (p.interrupts(t) or bullet(t) != null))) break;
            p.skip();
            if (w.items.len > 0) try w.append(p.a, ' ');
            try w.appendSlice(p.a, t);
        }
        return w.items;
    }
};

fn headingLevel(t: []const u8) ?u8 {
    var n: u8 = 0;
    while (n < t.len and n < 6 and t[n] == '#') n += 1;
    if (n == 0 or n >= t.len or t[n] != ' ') return null;
    return n;
}

fn bullet(t: []const u8) ?[]const u8 {
    if (t.len < 2 or (t[0] != '-' and t[0] != '*') or t[1] != ' ') return null;
    return std.mem.trimStart(u8, t[2..], " ");
}

/// Tabs count as spaces: a line of only tabs is blank
const ws = " \t\r";

/// Every cell :?-{3,}:?, so a data row of "-" (no figure) is not one
fn isSeparator(l: []const u8) bool {
    if (l.len == 0 or l[0] != '|') return false;
    var it = std.mem.splitScalar(u8, l[1..], '|');
    var n: usize = 0;
    while (it.next()) |raw| {
        const c = std.mem.trim(u8, raw, ws);
        if (c.len == 0) continue;
        const d = std.mem.trim(u8, c, ":");
        if (d.len < 3 or c.len - d.len > 2 or std.mem.trim(u8, d, "-").len > 0) return false;
        n += 1;
    }
    return n > 0;
}

/// `code` and **bold** spans; an unclosed marker is literal
fn inline_(a: Allocator, s: []const u8) Allocator.Error!Line {
    var out: std.ArrayList(Run) = .empty;
    var start: usize = 0;
    var i: usize = 0;
    while (i < s.len) {
        const mark: []const u8 = if (s[i] == '`') "`" else if (std.mem.startsWith(u8, s[i..], "**")) "**" else {
            i += 1;
            continue;
        };
        const end = std.mem.findPos(u8, s, i + mark.len, mark) orelse {
            i += mark.len;
            continue;
        };
        if (end == i + mark.len) {
            i = end + mark.len;
            continue;
        }
        if (i > start) try out.append(a, .{ .s = s[start..i] });
        try out.append(a, .{ .kind = if (mark.len == 1) .code else .bold, .s = s[i + mark.len .. end] });
        i = end + mark.len;
        start = i;
    }
    if (start < s.len) try out.append(a, .{ .s = s[start..] });
    return out.items;
}

pub const Opts = struct {
    /// The tag a `##` section heading gets: `#` one above, deeper ones step down to h4
    top: u3 = 2,
    /// Each `##` section in a <details>, closed: model.md runs to 6,000 lines
    fold: bool = false,
    /// With fold: the id of the section shown open (the URL's hash)
    open: []const u8 = "",
    /// Before each heading id, when a page shows two docs
    id_prefix: []const u8 = "",
};

const W = struct {
    pub const empty = phrase.plain("Nothing written yet");
    pub const loading = phrase.plain("Loading");
};

pub fn view(h: *H, d: Doc, o: Opts) N {
    if (d.blocks.len == 0) return h.div(.{ .class = "c-prose", .data_prose = {} }, .{h.p(.{ .class = "empty" }, .{W.empty})});
    if (!o.fold) return h.div(.{ .class = "c-prose", .data_prose = {} }, .{many(h, d.blocks, o)});
    const sp = split(h.mem, d) catch {
        h.oom = true;
        return .none;
    };
    const fs = h.mem.alloc(Fold, sp.sections.len) catch {
        h.oom = true;
        return .none;
    };
    for (sp.sections, fs) |s, *f| f.* = .{ .heading = s.heading, .body = s.body, .open = std.mem.eql(u8, s.heading.id, o.open) };
    return folded(h, sp.intro, fs, o);
}

/// A doc cut at its `##` headings: the intro before the first, then each section
pub const Split = struct { intro: Doc, sections: []const Section };
pub const Section = struct { heading: Heading, body: Doc };

/// Slices of `d`, nothing copied, except the section list (`a`)
pub fn split(a: Allocator, d: Doc) Allocator.Error!Split {
    var secs: std.ArrayList(Section) = .empty;
    var i = firstSection(d.blocks);
    const intro: Doc = .{ .blocks = d.blocks[0..i] };
    while (i < d.blocks.len) {
        const j = i + 1 + firstSection(d.blocks[i + 1 ..]);
        try secs.append(a, .{ .heading = d.blocks[i].heading, .body = .{ .blocks = d.blocks[i + 1 .. j] } });
        i = j;
    }
    return .{ .intro = intro, .sections = secs.items };
}

fn firstSection(bs: []const Block) usize {
    for (bs, 0..) |b, i| if (b == .heading and b.heading.level == 2) return i;
    return bs.len;
}

/// A `##` section in a closed <details>. `body` null until the page has fetched it (one
/// .bin per section: model.md is 456 KB encoded, 13,600 nodes, as one doc); a closed
/// section builds nothing of its body
pub const Fold = struct {
    heading: Heading,
    body: ?Doc = null,
    open: bool = false,
    /// The page's: it fetches the body on the first open
    on_toggle: ?tree.Handler = null,
};

pub fn folded(h: *H, intro: Doc, secs: []const Fold, o: Opts) N {
    var out = h.list();
    for (secs) |f| out.add(h.el(.details, .{ .key = f.heading.id, .class = "sec", .open = f.open, .on_toggle = f.on_toggle }, .{
        h.el(.summary, .{}, .{block(h, .{ .heading = f.heading }, o)}),
        if (f.open) (if (f.body) |b| many(h, b.blocks, o) else null) else null,
        if (f.open and f.body == null) h.p(.{ .class = "empty" }, .{W.loading}) else null,
    }));
    return h.div(.{ .class = "c-prose", .data_prose = {} }, .{ many(h, intro.blocks, o), out.done() });
}

fn many(h: *H, bs: []const Block, o: Opts) []const N {
    var l = h.list();
    for (bs) |b| l.add(block(h, b, o));
    return l.done();
}

fn block(h: *H, b: Block, o: Opts) N {
    return switch (b) {
        .heading => |x| heading(h, std.math.clamp(@as(i16, o.top) + x.level - 2, 1, 4), if (x.id.len > 0) h.fmt("{s}{s}", .{ o.id_prefix, x.id }) else null, runs(h, x.line)),
        .para => |x| h.p(.{}, .{runs(h, x)}),
        .list => |items| blk: {
            var lis = h.list();
            for (items) |it| {
                var sub = h.list();
                for (it.sub) |s| sub.add(h.li(.{}, .{runs(h, s)}));
                lis.add(h.li(.{}, .{ runs(h, it.line), if (it.sub.len > 0) h.ul(.{}, .{sub.done()}) else null }));
            }
            break :blk h.ul(.{}, .{lis.done()});
        },
        .table => |t| blk: {
            var ths = h.list();
            for (t.head) |c| ths.add(h.th(.{ .class = if (isNum(c)) "num" else null }, .{runs(h, c)}));
            var trs = h.list();
            for (t.rows) |r| {
                var tds = h.list();
                for (r) |c| tds.add(h.td(.{ .class = if (isNum(c)) "num" else null }, .{runs(h, c)}));
                trs.add(h.tr(.{}, .{tds.done()}));
            }
            break :blk h.div(.{ .class = "tw" }, .{h.table(.{}, .{
                if (t.head.len > 0) h.thead(.{}, .{h.tr(.{}, .{ths.done()})}) else null,
                h.tbody(.{}, .{trs.done()}),
            })});
        },
        .code => |s| h.div(.{ .class = "code" }, .{s}),
    };
}

fn heading(h: *H, tag: i16, id: ?[]const u8, kids: []const N) N {
    return switch (tag) {
        1 => h.el(.h1, .{ .id = id }, .{kids}),
        2 => h.el(.h2, .{ .id = id }, .{kids}),
        3 => h.el(.h3, .{ .id = id }, .{kids}),
        else => h.el(.h4, .{ .id = id }, .{kids}),
    };
}

fn runs(h: *H, line: Line) []const N {
    var l = h.list();
    for (line) |r| l.add(switch (r.kind) {
        .plain => h.text(r.s),
        .code => h.span(.{ .class = "c" }, .{r.s}),
        .bold => h.strong(.{}, .{r.s}),
    });
    return l.done();
}

/// A figure, a signed one or a dash for none: right-aligned in its column
fn isNum(line: Line) bool {
    if (line.len != 1 or line[0].kind != .plain) return false;
    const s = line[0].s;
    if (std.mem.eql(u8, s, "-")) return true;
    const d = if (s.len > 1 and (s[0] == '-' or s[0] == '+')) s[1..] else s;
    return d.len > 0 and std.ascii.isDigit(d[0]);
}

pub const css =
    \\@layer components {
    \\  .c-prose { max-width: 72ch; color: var(--t2); font-size: var(--fs-s); line-height: var(--lh); }
    \\  .c-prose > * + *, .c-prose .sec > * + * { margin-block-start: var(--sp-2); }
    \\  .c-prose :is(h1, h2, h3, h4) { margin: var(--sp-3) 0 0; color: var(--text); font-size: var(--fs-m);
    \\    font-weight: var(--w-b); line-height: var(--lh-tight); }
    \\  .c-prose h1 { font-size: var(--fs-l); }
    \\  .c-prose h4 { font-size: var(--fs-s); }
    \\  .c-prose p, .c-prose ul { margin: 0; }
    \\  .c-prose ul { padding-inline-start: 1.25em; }
    \\  .c-prose li + li { margin-block-start: var(--sp-1); }
    \\  .c-prose strong { color: var(--text); font-weight: var(--w-b); }
    \\  .c-prose .c, .c-prose .code { font-family: ui-monospace, monospace; font-size: var(--fs-xs); }
    \\  .c-prose .c { padding: 0 2px; border-radius: 2px; background: var(--panel-2); overflow-wrap: anywhere; }
    \\  .c-prose .code { padding: var(--sp-2); border-radius: var(--r-s); background: var(--panel-2);
    \\    white-space: pre; overflow-x: auto; }
    \\  .c-prose .tw { overflow-x: auto; }
    \\  .c-prose table { border-collapse: collapse; font-size: var(--fs-xs); }
    \\  .c-prose :is(th, td) { padding: var(--sp-1) var(--sp-2); border-bottom: 1px solid var(--line);
    \\    text-align: start; vertical-align: top; }
    \\  .c-prose th { color: var(--muted); font-weight: var(--w-m); }
    \\  .c-prose .num { text-align: end; font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-prose .sec { border-top: 1px solid var(--line); }
    \\  .c-prose .sec > summary { cursor: pointer; }
    \\  .c-prose .sec > summary > * { display: inline; }
    \\  .c-prose .empty { color: var(--muted); }
    \\}
    \\
;

const demo_learned =
    \\# What we have learnt
    \\
    \\Plain findings, newest last. Each line is a **final** result of a model or a data
    \\check, with the run that showed it.
    \\
    \\## Draft
    \\
    \\- Lane gold at 14 minutes predicts the result better than any pick feature: log loss
    \\  0.652 vs 0.681 on held-out games (`eval --lane`)
    \\- Champion pairs add little over each champion's own rate:
    \\  - same team: +0.002 log loss on 41,000 games
    \\  - against the lane opponent: +0.004, within the interval
    \\- Off-role picks lose 3.1 points of win rate below Emerald
;

const demo_eval =
    \\## Full draft, held-out games
    \\
    \\| model | games | log loss | AUC | vs base |
    \\| --- | --- | --- | --- | --- |
    \\| base rates | 18,204 | 0.6912 | 0.541 | - |
    \\| eb | 18,204 | 0.6870 | 0.566 | -0.0042 |
    \\| joint `--pairs` | 18,204 | 0.6851 | 0.578 | -0.0061 |
;

const demo_code =
    \\Rerun on the gpu-box:
    \\
    \\```
    \\deploy/lab-run.sh eval --history data/eval-history.tsv
    \\  --blocks dev --split random:1
    \\```
;

const demo_folded =
    \\Model quality on held-out games. Start here, then one section.
    \\
    \\## Start here
    \\
    \\The draft model ranks picks; the lane model explains them.
    \\
    \\## Lane model
    \\
    \\### Features
    \\
    \\- gold14: total gold at frame 14
    \\- lanediff14: gold14 minus the lane opponent's
;

fn demo(g: *Gallery, caption: []const u8, src: []const u8, o: Opts) void {
    const d = parse(g.h.mem, src) catch {
        g.h.oom = true;
        return;
    };
    g.add(caption, view(g.h, d, o));
}

/// A section opened before the page has fetched its body
fn loading(g: *Gallery) !void {
    const sp = try split(g.h.mem, try parse(g.h.mem, demo_folded));
    const fs = try g.h.mem.alloc(Fold, sp.sections.len);
    for (sp.sections, fs, 0..) |x, *f, i| f.* = .{ .heading = x.heading, .open = i == 0 };
    g.add("a section opened, its body loading", folded(g.h, sp.intro, fs, .{ .top = 3 }));
}

pub fn gallery(g: *Gallery) void {
    demo(g, "learned.md: bullets, nested, code, bold", demo_learned, .{ .top = 3 });
    demo(g, "eval report table", demo_eval, .{ .top = 3 });
    demo(g, "fenced code", demo_code, .{});
    demo(g, "model.md folded, a section open from the hash", demo_folded, .{ .top = 3, .fold = true, .open = "lane-model" });
    loading(g) catch {
        g.h.oom = true;
    };
    g.add("empty", view(g.h, .{ .blocks = &.{} }, .{}));
}

const testing = std.testing;

fn render(a: Allocator, src: []const u8, o: Opts) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const n = view(&h, try parse(a, src), o);
    try testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, n, &out.writer);
    return out.written();
}

fn expectRuns(want: []const Run, got: Line) !void {
    try testing.expectEqual(want.len, got.len);
    for (want, got) |w, x| {
        try testing.expectEqual(w.kind, x.kind);
        try testing.expectEqualStrings(w.s, x.s);
    }
}

test "parse: each block kind, wrapped lines joined, the rest literal" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const d = try parse(a,
        \\# Title #
        \\
        \\One line
        \\wrapped, with `x|y` and **bold**.
        \\#hashtag stays text, as does 1. a number
        \\- first item
        \\  wraps here
        \\  - nested one
        \\    wraps too
        \\* second, `unclosed
        \\### Three
        \\| a | b |
        \\|---|---:|
        \\| `p|q` | 1.5 |
        \\| no sep |
        \\```zig
        \\  keep  indent
        \\
        \\```
        \\| only | rows |
        \\
        \\```
        \\unclosed fence
    );
    const bs = d.blocks;
    try testing.expectEqual(@as(usize, 8), bs.len);
    try testing.expectEqual(@as(u8, 1), bs[0].heading.level);
    try expectRuns(&.{.{ .s = "Title" }}, bs[0].heading.line);
    try expectRuns(&.{
        .{ .s = "One line wrapped, with " },
        .{ .kind = .code, .s = "x|y" },
        .{ .s = " and " },
        .{ .kind = .bold, .s = "bold" },
        .{ .s = ". #hashtag stays text, as does 1. a number" },
    }, bs[1].para);
    const items = bs[2].list;
    try testing.expectEqual(@as(usize, 2), items.len);
    try expectRuns(&.{.{ .s = "first item wraps here" }}, items[0].line);
    try testing.expectEqual(@as(usize, 1), items[0].sub.len);
    try expectRuns(&.{.{ .s = "nested one wraps too" }}, items[0].sub[0]);
    try expectRuns(&.{.{ .s = "second, `unclosed" }}, items[1].line);
    try testing.expectEqual(@as(u8, 3), bs[3].heading.level);
    const t = bs[4].table;
    try testing.expectEqual(@as(usize, 2), t.head.len);
    try testing.expectEqual(@as(usize, 2), t.rows.len);
    try expectRuns(&.{.{ .kind = .code, .s = "p|q" }}, t.rows[0][0]);
    try expectRuns(&.{.{ .s = "1.5" }}, t.rows[0][1]);
    try testing.expectEqual(@as(usize, 2), t.rows[1].len);
    try testing.expectEqualStrings("  keep  indent\n", bs[5].code);
    try expectRuns(&.{.{ .s = "| only | rows |" }}, bs[6].para);
    try testing.expectEqualStrings("unclosed fence", bs[7].code);
}

test "parse: empty and odd input" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_][]const u8{ "", "\n\n", "\r\n", "|", "| |", "```", "#", "-", "- ", "**", "``", "|---|", "#######  x" }) |src| {
        _ = try render(a, src, .{ .fold = true });
    }
    try testing.expectEqual(@as(usize, 0), (try parse(a, "\n \n")).blocks.len);
    try expectRuns(&.{.{ .s = "**" }}, (try parse(a, "**")).blocks[0].para);
}

test "a Doc survives data.zig, so the page ships it without the parser" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const data = @import("data.zig");
    const d = try parse(a, demo_learned ++ "\n" ++ demo_eval ++ "\n" ++ demo_code);
    var bytes: std.ArrayList(u8) = .empty;
    try data.encode(a, Doc, d, &bytes);
    const back = try data.decode(a, Doc, bytes.items);
    try testing.expectEqualStrings(try render(a, demo_learned ++ "\n" ++ demo_eval ++ "\n" ++ demo_code, .{}), blk: {
        var t: tree.Tree = .{};
        var h: H = .init(a, &t);
        const n = view(&h, back, .{});
        var out: std.Io.Writer.Allocating = .init(a);
        try @import("html.zig").write(&t, n, &out.writer);
        break :blk out.written();
    });
}

test "view: heading tags from top, figures right, text escaped, sections folded" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const s = try render(a, demo_folded ++ "\n#### Deep\n\n| a | b | c | d | e | f |\n| --- | --- | --- | --- | --- | --- |\n| x | 2 | -0.1 | - | +3 | -x |\n\nw[<role>] & co\n", .{ .top = 3, .fold = true, .open = "lane-model" });
    for ([_][]const u8{
        "data-prose",
        "<p>Model quality on held-out games. Start here, then one section.</p><details class=\"sec\"><summary><h3 id=\"start-here\">Start here</h3></summary></details>",
        "<details class=\"sec\" open=\"\"><summary><h3 id=\"lane-model\">Lane model</h3></summary><h4 id=\"features\">Features</h4>",
        "<h4 id=\"deep\">Deep</h4>",
        "<td>x</td><td class=\"num\">2</td><td class=\"num\">-0.1</td><td class=\"num\">-</td><td class=\"num\">+3</td><td>-x</td>",
        "w[&lt;role&gt;] &amp; co",
    }) |w| if (std.mem.find(u8, s, w) == null) {
        std.debug.print("missing {s} in {s}\n", .{ w, s });
        return error.TestExpectedEqual;
    };
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, s, "<details"));
    const flat = try render(a, "# T\n\n## S\n", .{});
    try testing.expect(std.mem.find(u8, flat, "<h1 id=\"t\">T</h1><h2 id=\"s\">S</h2>") != null);
    try testing.expect(std.mem.find(u8, flat, "details") == null);
    try testing.expect(std.mem.find(u8, try render(a, "", .{}), "Nothing written yet") != null);
}

test "parse: wrapped lines stay text; \\| stays in its cell; a row of dashes is data" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const d = try parse(a,
        \\Controls (pre-declared:
        \\|mean| <= 0.0015 or an interval covering 0, else void)
        \\# of games is the other
        \\Reading:
        \\- a list after text
        \\  # of games, wrapped
        \\
        \\| model | vs ratings |
        \\| --- | --- |
        \\| ratings | -0.00002 \| +0.00006 |
        \\| none | - |
        \\| short |
        \\| long | 1 | 2 |
        \\| - | - |
    ++ "\n\t\n" ++
        \\| a |
        \\| -- |
    );
    const bs = d.blocks;
    try testing.expectEqual(@as(usize, 4), bs.len);
    try expectRuns(&.{.{ .s = "Controls (pre-declared: |mean| <= 0.0015 or an interval covering 0, else void) # of games is the other Reading:" }}, bs[0].para);
    try expectRuns(&.{.{ .s = "a list after text # of games, wrapped" }}, bs[1].list[0].line);
    const t = bs[2].table;
    try testing.expectEqual(@as(usize, 5), t.rows.len);
    for (t.rows) |r| try testing.expectEqual(@as(usize, 2), r.len);
    try expectRuns(&.{.{ .s = "-0.00002 | +0.00006" }}, t.rows[0][1]);
    try expectRuns(&.{}, t.rows[2][1]);
    try expectRuns(&.{.{ .s = "1" }}, t.rows[3][1]);
    try expectRuns(&.{.{ .s = "-" }}, t.rows[4][0]);
    try expectRuns(&.{.{ .s = "| a | | -- |" }}, bs[3].para);
}

test "parse the real docs: fences paired, rows as wide as their head" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const io = testing.io;
    for ([_][]const u8{ "docs/learned.md", "docs/model.md" }) |path| {
        errdefer std.debug.print("{s}\n", .{path});
        const src = try std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(4 << 20));
        const d = try parse(a, src);
        var fences: usize = 0;
        var lines = std.mem.splitScalar(u8, src, '\n');
        while (lines.next()) |l| fences += @intFromBool(std.mem.startsWith(u8, l, "```"));
        var code: usize = 0;
        var heads: usize = 0;
        for (d.blocks) |b| switch (b) {
            .code => code += 1,
            .heading => heads += 1,
            .table => |t| for (t.rows) |r| try testing.expectEqual(t.head.len, r.len),
            else => {},
        };
        try testing.expectEqual(fences / 2, code);
        try testing.expect(heads > 4);
        var t: tree.Tree = .{};
        var h: H = .init(a, &t);
        _ = view(&h, d, .{ .fold = true });
        try testing.expect(!h.oom);
    }
}

test "heading ids: slugs, unique in the doc; split cuts at ##; a section builds only when open" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const d = try parse(a, "intro\n\n## Lane model: `gold14`\n\nx\n\n### Lane model gold14\n\n## Lane model -- gold14!\n\n## ***\n\n## C#\n");
    var ids: std.ArrayList([]const u8) = .empty;
    for (d.blocks) |b| if (b == .heading) try ids.append(a, b.heading.id);
    const want = [_][]const u8{ "lane-model-gold14", "lane-model-gold14-2", "lane-model-gold14-3", "s", "c" };
    try testing.expectEqual(want.len, ids.items.len);
    for (want, ids.items) |w, x| try testing.expectEqualStrings(w, x);

    const sp = try split(a, d);
    try testing.expectEqual(@as(usize, 1), sp.intro.blocks.len);
    try testing.expectEqual(@as(usize, 4), sp.sections.len);
    // The ### stays in its ## section's body
    try testing.expectEqual(@as(usize, 2), sp.sections[0].body.blocks.len);
    try testing.expectEqual(@as(usize, 0), sp.sections[3].body.blocks.len);

    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var out: std.Io.Writer.Allocating = .init(a);
    const fs = [_]Fold{
        .{ .heading = sp.sections[0].heading, .body = sp.sections[0].body },
        .{ .heading = sp.sections[1].heading, .open = true },
        .{ .heading = sp.sections[2].heading, .body = sp.sections[2].body, .open = true },
    };
    try @import("html.zig").write(&t, folded(&h, sp.intro, &fs, .{ .id_prefix = "m-" }), &out.writer);
    try testing.expect(!h.oom);
    const s = out.written();
    for ([_][]const u8{
        "<p>intro</p><details class=\"sec\"><summary><h2 id=\"m-lane-model-gold14\">Lane model: <span class=\"c\">gold14</span></h2></summary></details>",
        "<details class=\"sec\" open=\"\"><summary><h2 id=\"m-lane-model-gold14-3\">Lane model -- gold14!</h2></summary><p class=\"empty\">Loading</p></details>",
        "<summary><h2 id=\"m-s\">***</h2></summary></details>",
    }) |w| if (std.mem.find(u8, s, w) == null) {
        std.debug.print("missing {s} in {s}\n", .{ w, s });
        return error.TestExpectedEqual;
    };
    try testing.expect(std.mem.find(u8, s, "<p>x</p>") == null);
}
