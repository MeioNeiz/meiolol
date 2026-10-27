//! TodayCard: a Card with a one-line title, real content and one action (home's Today;
//! the desktop's between games panel). Bodies: `draft` (Daily Draft's teams lane by lane,
//! blue over red, the hidden seat a dashed ?, your marks once played) and `changes` (a
//! patch's biggest win rate moves: champion and role, before and after, DeltaBar, Delta)
const std = @import("std");
const tree = @import("tree.zig");
const card = @import("card.zig");
const button = @import("button.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const delta = @import("delta.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "TodayCard";
pub const scope = .{".c-today"};

const W = struct {
    pub const hidden = plain("Hidden seat");
    pub const marks = plain("Your answers");
    pub const right = plain("right");
    pub const wrong = plain("wrong");
    pub const pick = phrase.Phrase("Pick {r:text}, winner {w:text}");
    pub const from_to = phrase.Phrase("{a:rate} → {b:rate}");
    pub const range = phrase.Phrase("±{c:dec}");
};

pub const Head = struct {
    title: tree.Text,
    count: ?tree.Text = null,
    action: tree.Text,
    href: []const u8,
};

pub fn view(h: *H, hd: Head, extra: ?N, body: N) N {
    return card.view(h, .{}, &.{
        card.head(h, hd.title, hd.count, &.{ extra orelse .none, button.view(h, .{ .s = .s, .href = hd.href }, .{hd.action}) }),
        body,
    });
}

/// [blue, red], by role; null: the hidden seat
pub const Teams = [2][5]?champ.Champ;

/// Daily Draft's two answers once played
pub const Marks = struct { pick: bool, side: bool };

pub fn draft(h: *H, teams: *const Teams) N {
    var cols = h.list();
    for (std.enums.values(Role), 0..) |r, i| cols.add(h.div(.{ .key = i }, .{
        seat(h, teams[0][i], .us),
        role.view(h, r, .{ .s = .s }),
        seat(h, teams[1][i], .them),
    }));
    return h.div(.{ .class = "c-today", .data_v = "draft" }, .{cols.done()});
}

fn seat(h: *H, c: ?champ.Champ, side: @FieldType(champ.Opts, "side")) N {
    return champ.view(h, c, .{ .px = .@"40", .side = side, .label = if (c == null) W.hidden else null });
}

/// Your answers as two squares, for the head
pub fn marks(h: *H, m: Marks) N {
    const word = struct {
        fn f(ok: bool) tree.Text {
            return if (ok) W.right else W.wrong;
        }
    }.f;
    return h.span(.{
        .class = "c-today",
        .data_v = "marks",
        .role = "img",
        .aria_label = W.pick.with(h, .{ .r = word(m.pick).s, .w = word(m.side).s }),
    }, .{ h.el(.i, .{ .data_ok = m.pick }, .{}), h.el(.i, .{ .data_ok = m.side }, .{}) });
}

pub const Change = struct {
    champ: champ.Champ,
    role: Role,
    href: ?[]const u8 = null,
    /// Win rates, percent
    from: f32,
    to: f32,
    /// 95% half-width of to - from, points
    ci: f32,
};

pub fn changes(h: *H, rows: []const Change) N {
    var span: f32 = 2;
    for (rows) |r| span = @max(span, @abs(r.to - r.from) + r.ci);
    var l = h.list();
    for (rows, 0..) |r, i| {
        const d = r.to - r.from;
        const kids = .{
            champ.view(h, r.champ, .{ .px = .@"32", .role = r.role, .named = false }),
            h.span(.{ .class = "nm" }, .{ h.b(.{}, .{r.champ.name}), h.small(.{}, .{W.from_to.with(h, .{ .a = r.from, .b = r.to })}) }),
            delta.bar(h, .{ .d = d, .ci = r.ci, .span = span }),
            h.span(.{ .class = "end" }, .{ delta.view(h, .{ .d = d, .ci = r.ci }), h.small(.{}, .{W.range.with(h, .{ .c = r.ci })}) }),
        };
        l.add(h.li(.{ .key = i }, .{if (r.href) |href| h.a(.{ .href = href }, kids) else h.div(.{}, kids)}));
    }
    return h.ul(.{ .class = "c-today", .data_v = "changes" }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-today[data-v="draft"] { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: var(--sp-1);
    \\    padding-block: var(--sp-1); }
    \\  .c-today[data-v="draft"] > div { display: flex; flex-direction: column; align-items: center; gap: 6px; }
    \\  .c-today[data-v="draft"] > div > .c-role { color: var(--faint); }
    \\  .c-today .c-champ[data-state="empty"] { border-color: var(--them); box-shadow: none; }
    \\  .c-today .c-champ[data-state="empty"]::before { content: "?"; display: grid; place-items: center; height: 100%;
    \\    color: var(--accent); font-weight: var(--w-b); font-size: var(--fs-l); }
    \\  .c-today[data-v="marks"] { display: inline-flex; gap: 3px; }
    \\  .c-today[data-v="marks"] > i { width: 14px; height: 14px; border-radius: 3px; background: var(--them); }
    \\  .c-today[data-v="marks"] > i[data-ok] { background: var(--good); }
    \\  .c-today[data-v="changes"] { list-style: none; margin: 0; padding: 0; }
    \\  .c-today[data-v="changes"] li > * { display: grid; grid-template-columns: 32px minmax(0, auto) minmax(56px, 1fr) auto;
    \\    align-items: center; gap: var(--sp-2) var(--sp-3); padding: 6px 0; color: inherit; }
    \\  .c-today[data-v="changes"] li > a:hover { text-decoration: none; }
    \\  .c-today[data-v="changes"] li > a:hover b { color: var(--accent); }
    \\  .c-today .nm { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
    \\  .c-today .nm > b { font-weight: var(--w-m); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-today small { font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-today .end { text-align: right; }
    \\  .c-today .end > .c-delta { font-weight: var(--w-b); }
    \\  .c-today .end > small { margin-left: 3px; }
    \\  .c-today .c-dbar { min-width: 0; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const d = champ.demo;
    const teams: Teams = .{
        .{ d("Darius", "Darius"), d("LeeSin", "Lee Sin"), d("Ahri", "Ahri"), d("Jinx", "Jinx"), d("Thresh", "Thresh") },
        .{ d("Garen", "Garen"), d("Vi", "Vi"), d("Syndra", "Syndra"), null, d("Nami", "Nami") },
    };
    const head: Head = .{ .title = plain("Daily Draft"), .count = plain("#14"), .action = plain("Guess"), .href = "#" };
    g.addFill("draft", view(h, head, null, draft(h, &teams)));
    var done = head;
    done.action = plain("Open");
    g.addFill("draft, played", view(h, done, marks(h, .{ .pick = true, .side = false }), draft(h, &teams)));
    const rows = [_]Change{
        .{ .champ = d("Darius", "Darius"), .role = .top, .href = "#", .from = 48.7, .to = 51.3, .ci = 1.4 },
        .{ .champ = d("Khazix", "Kha'Zix"), .role = .jungle, .href = "#", .from = 48.8, .to = 51.4, .ci = 1.5 },
        .{ .champ = d("Renata", "Renata Glasc"), .role = .support, .href = "#", .from = 51.2, .to = 46.7, .ci = 2.8 },
        .{ .champ = d("Viktor", "Viktor"), .role = .mid, .from = 50.5, .to = 47.3, .ci = 1.5 },
    };
    g.addFill("changes", view(h, .{ .title = plain("Patch 16.21"), .count = plain("vs 16.20"), .action = plain("All changes"), .href = "#" }, null, changes(h, &rows)));
}

test "the hidden seat, marks and signed changes" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const d = champ.demo;
    var teams: Teams = @splat(@splat(d("Ahri", "Ahri")));
    teams[1][3] = null;
    const rows = [_]Change{
        .{ .champ = d("Darius", "Darius"), .role = .top, .href = "c/darius", .from = 48.7, .to = 51.3, .ci = 1.4 },
        .{ .champ = d("Viktor", "Viktor"), .role = .mid, .from = 50.5, .to = 47.3, .ci = 1.5 },
    };
    const head: Head = .{ .title = plain("Daily Draft"), .action = plain("Open"), .href = "daily.html" };
    const n = h.div(.{}, .{
        view(&h, head, marks(&h, .{ .pick = true, .side = false }), draft(&h, &teams)),
        changes(&h, &rows),
    });
    try std.testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, n, &out.writer);
    const s = out.written();
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, s, "Hidden seat"));
    try std.testing.expect(std.mem.find(u8, s, "Pick right, winner wrong") != null);
    try std.testing.expect(std.mem.find(u8, s, "href=\"daily.html\"") != null);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, s, "href=\"c/darius\""));
    try std.testing.expect(std.mem.find(u8, s, "±1.4") != null);
}
