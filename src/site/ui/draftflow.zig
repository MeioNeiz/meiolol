//! DraftFlow: a draft's 20 turns in order, as the four phases (6 bans, 6 picks, 4 bans,
//! 4 picks), each turn its champion with its side's bar under it, picks numbered 1-10.
//! The open turn (the puzzle's) pulses, or shows a chosen answer dashed.
//! Sits at the foot of Daily's DraftBoard: the board says who faces whom, this says when
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "DraftFlow";
pub const scope = .{".c-flow"};

pub const Side = enum { us, them };

pub const Turn = struct {
    /// Null: a skipped ban, or the open turn
    champ: ?champ.Champ = null,
    side: Side,
    /// The puzzle's turn
    open: bool = false,
    /// An answer chosen for the open turn, not locked in
    preview: ?champ.Champ = null,
};

/// Turns in draft order: 6 bans, 6 picks, 4 bans, 4 picks
pub const phases = [_]struct { ban: bool, n: u8 }{
    .{ .ban = true, .n = 6 },
    .{ .ban = false, .n = 6 },
    .{ .ban = true, .n = 4 },
    .{ .ban = false, .n = 4 },
};

/// Pro draft's sides by turn (blue first, red picks last)
pub const order = [20]Side{
    .us,   .them, .us,   .them, .us,   .them,
    .us,   .them, .them, .us,   .us,   .them,
    .them, .us,   .them, .us,   .them, .us,
    .us,   .them,
};

pub fn view(h: *H, turns: []const Turn) N {
    var groups = h.list();
    var at: usize = 0;
    var pick: u8 = 0;
    for (phases, 0..) |ph, pi| {
        var l = h.list();
        for (0..ph.n) |_| {
            if (at >= turns.len) break;
            const t = turns[at];
            if (!ph.ban) pick += 1;
            const shown = if (t.open) t.preview else t.champ;
            l.add(h.span(.{
                .key = at,
                .class = "t",
                .data_side = t.side,
                .data_ban = ph.ban,
                .data_open = t.open,
                .data_preview = t.open and t.preview != null,
            }, .{
                if (ph.ban) null else h.span(.{ .class = "n" }, .{pick}),
                champ.view(h, shown, .{
                    .px = if (ph.ban) .@"24" else .@"32",
                    .state = if (ph.ban and shown != null) .banned else .normal,
                    .label = if (t.open) W.open else W.none,
                }),
            }));
            at += 1;
        }
        groups.add(h.div(.{ .key = pi, .class = "ph" }, .{
            h.span(.{ .class = "lab" }, .{if (ph.ban) W.bans else W.picks}),
            h.div(.{ .class = "grp" }, .{l.done()}),
        }));
    }
    return h.div(.{ .class = "c-flow" }, .{groups.done()});
}

const W = struct {
    const bans = plain("Bans");
    const picks = plain("Picks");
    const open = plain("The hidden pick");
    const none = plain("No ban");
};

pub const css =
    \\@layer components {
    \\  .c-flow { display: flex; justify-content: center; align-items: flex-end; gap: var(--sp-3); flex-wrap: wrap; }
    \\  .c-flow .ph { display: grid; gap: 4px; }
    \\  .c-flow .lab { font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--faint); text-transform: uppercase;
    \\    letter-spacing: 0.06em; }
    \\  .c-flow .grp { display: flex; gap: 4px; align-items: flex-end; }
    \\  .c-flow .t { display: grid; justify-items: center; gap: 3px; }
    \\  .c-flow .t::after { content: ""; width: 100%; height: 3px; border-radius: 2px; background: var(--us); }
    \\  .c-flow .t[data-side="them"]::after { background: var(--them); }
    \\  .c-flow .t[data-ban]::after { opacity: 0.45; }
    \\  .c-flow .n { font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; line-height: 1; }
    \\  .c-flow .t[data-open] .n { color: var(--accent); font-weight: var(--w-b); }
    \\  .c-flow .t[data-open] .c-champ { box-shadow: inset 0 0 0 1.5px var(--accent); animation: c-flow-pulse 1.6s var(--ease) infinite; }
    \\  .c-flow .t[data-preview] .c-champ { animation: none; box-shadow: none; outline: 1.5px dashed var(--accent);
    \\    outline-offset: 2px; opacity: 0.75; }
    \\  @keyframes c-flow-pulse { 50% { box-shadow: inset 0 0 0 1.5px var(--accent), 0 0 0 3px var(--accent-bg); } }
    \\  @media (prefers-reduced-motion: reduce) { .c-flow .t[data-open] .c-champ { animation: none; } }
    \\  @container (max-width: 600px) {
    \\    .c-flow { gap: 6px; }
    \\    .c-flow .grp { gap: 2px; }
    \\    .c-flow .lab { display: none; }
    \\  }
    \\}
    \\
;

const demo = champ.demo;

const sample_champs = [20]?champ.Champ{
    demo("Yasuo", "Yasuo"),     demo("Vex", "Vex"),            demo("Zed", "Zed"),
    demo("Aurora", "Aurora"),   demo("Ahri", "Ahri"),          null,
    demo("Kalista", "Kalista"), demo("Vi", "Vi"),              demo("Neeko", "Neeko"),
    demo("Renata", "Renata"),   demo("JarvanIV", "Jarvan IV"), demo("Caitlyn", "Caitlyn"),
    demo("Rumble", "Rumble"),   demo("Sylas", "Sylas"),        demo("Taliyah", "Taliyah"),
    demo("Azir", "Azir"),       demo("Anivia", "Anivia"),      demo("Viktor", "Viktor"),
    demo("KSante", "K'Sante"),  demo("Jayce", "Jayce"),
};

fn sample(h: *H, open: bool, preview: ?champ.Champ) []const Turn {
    const ts = h.mem.alloc(Turn, 20) catch {
        h.oom = true;
        return &.{};
    };
    for (ts, sample_champs, order, 0..) |*t, c, s, i| t.* = .{
        .champ = if (open and i == 19) null else c,
        .side = s,
        .open = open and i == 19,
        .preview = if (i == 19) preview else null,
    };
    return ts;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("last pick open", view(h, sample(h, true, null)));
    g.addFill("an answer chosen", view(h, sample(h, true, demo("Ambessa", "Ambessa"))));
    g.addFill("whole draft", view(h, sample(h, false, null)));
}

test "four phases, picks numbered 1-10, the open turn shows its preview" {
    const std = @import("std");
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const html = @import("html.zig");
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var out: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, view(&h, sample(&h, true, null)), &out.writer);
    var s = out.written();
    try std.testing.expectEqual(4, std.mem.count(u8, s, "class=\"ph\""));
    try std.testing.expectEqual(10, std.mem.count(u8, s, "data-ban"));
    try std.testing.expectEqual(10, std.mem.count(u8, s, "class=\"n\""));
    try std.testing.expect(std.mem.find(u8, s, ">10</span>") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-open"));
    try std.testing.expect(std.mem.find(u8, s, "data-preview") == null);
    try std.testing.expect(std.mem.find(u8, s, "Jayce") == null);
    out = .init(a);
    try html.write(&t, view(&h, sample(&h, true, demo("Ambessa", "Ambessa"))), &out.writer);
    s = out.written();
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-preview"));
    try std.testing.expect(std.mem.find(u8, s, "Ambessa") != null);
    out = .init(a);
    try html.write(&t, view(&h, sample(&h, false, null)[0..7]), &out.writer);
    try std.testing.expectEqual(1, std.mem.count(u8, out.written(), "class=\"n\""));
}
