//! TeamRows: a game's five lanes as mirrored rows, our player left, theirs right, the role
//! and the lane's gold gap between. A seat: portrait (greyed while dead), name, the KDA
//! and a line of figures, the respawn while dead. The app's in-game panel and post game
//! screen (src/shell/screens.zig). Champions only: no player names (product rules)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const kda = @import("kda.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "TeamRows";
pub const scope = .{".c-rows"};

pub const Lean = enum { none, good, bad };

pub const Seat = struct {
    /// Null: a champion the stats file doesn't know yet
    champ: ?champ.Champ,
    you: bool = false,
    /// Seconds to respawn while dead
    dead: ?u16 = null,
    /// Null before the game (the comp view): the line alone
    kda: ?kda.Kda = null,
    /// After the KDA ("Lv 9 · 84 cs")
    line: []const u8 = "",
};

pub const Row = struct {
    role: role.Role,
    us: ?Seat = null,
    them: ?Seat = null,
    /// Our player's gold minus theirs ("+1.2k"); "" when one is missing
    gap: []const u8 = "",
    lean: Lean = .none,
};

const Side = enum { us, them };

pub fn view(h: *H, rows: []const Row) N {
    var list = h.list();
    for (rows) |r| list.add(h.div(.{
        .key = @as(u32, @backingInt(r.role)),
        .class = "row",
        .data_you = if (r.us) |s| s.you else false,
    }, .{
        seat(h, r.us, .us),
        h.span(.{ .class = "mid" }, .{
            role.view(h, r.role, .{ .s = .s }),
            if (r.gap.len > 0) h.span(.{ .class = "gap", .data_lean = if (r.lean == .none) null else r.lean }, .{r.gap}) else null,
        }),
        seat(h, r.them, .them),
    }));
    return h.div(.{ .class = "c-rows" }, .{
        h.div(.{ .class = "heads" }, .{
            h.span(.{ .data_side = Side.us }, .{W.us}),
            h.span(.{ .data_side = Side.them }, .{W.them}),
        }),
        list.done(),
    });
}

fn seat(h: *H, s_or: ?Seat, side: Side) N {
    const s = s_or orelse return h.div(.{ .class = "seat", .data_side = side }, .{
        h.span(.{ .class = "line" }, .{W.nobody}),
    });
    return h.div(.{ .class = "seat", .data_side = side }, .{
        champ.view(h, s.champ, .{
            .px = .@"32",
            .state = if (s.dead != null) .dead else .normal,
            .you = s.you,
            .named = false,
        }),
        h.span(.{ .class = "who" }, .{
            h.b(.{}, .{if (s.champ) |c| c.name else W.unknown.s}),
            h.span(.{ .class = "line" }, .{
                if (s.kda) |k| kda.view(h, k, .{}) else null,
                if (s.line.len > 0) h.span(.{}, .{ if (s.kda != null) W.dot else null, s.line }) else null,
            }),
            if (s.dead) |t| h.span(.{ .class = "dead" }, .{W.back.with(h, .{ .t = @as(u32, t) })}) else null,
        }),
    });
}

const W = struct {
    const us = plain("Your team");
    const them = plain("Enemy team");
    const dot = plain(" · ");
    const nobody = plain("Nobody");
    const unknown = plain("New champion");
    const back = phrase.Phrase("back in {t:int}s");
};

pub const css =
    \\@layer components {
    \\  .c-rows { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
    \\  .c-rows .heads { display: grid; grid-template-columns: 1fr 1fr; padding: 0 var(--sp-2) 4px;
    \\    font-size: var(--fs-xs); font-weight: var(--w-m); }
    \\  .c-rows [data-side="us"] { color: var(--us); }
    \\  .c-rows .heads [data-side="them"] { color: var(--them); text-align: right; }
    \\  .c-rows .row { display: grid; grid-template-columns: minmax(0, 1fr) 48px minmax(0, 1fr); align-items: center;
    \\    gap: var(--sp-2); padding: 6px var(--sp-2); border-radius: var(--r-s); background: var(--panel-2); }
    \\  .c-rows .row[data-you] { box-shadow: inset 0 0 0 1px var(--sel-line); }
    \\  .c-rows .mid { display: flex; flex-direction: column; align-items: center; gap: 2px; color: var(--muted); }
    \\  .c-rows .gap { font-size: var(--fs-xs); font-weight: var(--w-m); font-variant-numeric: tabular-nums; color: var(--t2); }
    \\  .c-rows .gap[data-lean="good"] { color: var(--hi2); }
    \\  .c-rows .gap[data-lean="bad"] { color: var(--lo2); }
    \\  .c-rows .seat { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; color: var(--text); }
    \\  .c-rows .seat[data-side="them"] { flex-direction: row-reverse; }
    \\  .c-rows .who { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
    \\  .c-rows .seat[data-side="them"] .who { align-items: flex-end; text-align: right; }
    \\  .c-rows .who > b { font-weight: var(--w-m); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-rows .line { font-size: var(--fs-xs); color: var(--t2); overflow: hidden; text-overflow: ellipsis;
    \\    white-space: nowrap; }
    \\  .c-rows .dead { font-size: var(--fs-xs); color: var(--lo2); }
    \\  @container (max-width: 420px) {
    \\    .c-rows .row { grid-template-columns: minmax(0, 1fr) 36px minmax(0, 1fr); gap: var(--sp-1); padding: 4px; }
    \\    .c-rows .who > b { display: none; }
    \\  }
    \\}
    \\
;

const demo = champ.demo;

pub const sample = [_]Row{
    .{
        .role = .top,
        .us = .{ .champ = demo("Darius", "Darius"), .kda = .{ .k = 3, .d = 1, .a = 2 }, .line = "Lv 11 · 98 cs" },
        .them = .{ .champ = demo("Ornn", "Ornn"), .kda = .{ .k = 1, .d = 3, .a = 4 }, .line = "Lv 10 · 87 cs" },
        .gap = "+850",
        .lean = .good,
    },
    .{
        .role = .jungle,
        .us = .{ .champ = demo("Vi", "Vi"), .kda = .{ .k = 2, .d = 2, .a = 5 }, .line = "Lv 9 · 71 cs", .dead = 14 },
        .them = .{ .champ = demo("LeeSin", "Lee Sin"), .kda = .{ .k = 4, .d = 1, .a = 3 }, .line = "Lv 10 · 80 cs" },
        .gap = "−600",
        .lean = .bad,
    },
    .{
        .role = .mid,
        .us = .{ .champ = demo("Orianna", "Orianna"), .you = true, .kda = .{ .k = 2, .d = 0, .a = 6 }, .line = "Lv 11 · 121 cs" },
        .them = .{ .champ = demo("Syndra", "Syndra"), .kda = .{ .k = 1, .d = 2, .a = 1 }, .line = "Lv 10 · 112 cs" },
        .gap = "+300",
        .lean = .good,
    },
    .{
        .role = .bot,
        .us = .{ .champ = demo("Jinx", "Jinx"), .kda = .{ .k = 1, .d = 2, .a = 2 }, .line = "Lv 9 · 104 cs" },
        .them = .{ .champ = demo("Caitlyn", "Caitlyn"), .kda = .{ .k = 3, .d = 1, .a = 1 }, .line = "Lv 10 · 118 cs" },
        .gap = "−450",
        .lean = .bad,
    },
    .{
        .role = .support,
        .us = .{ .champ = demo("Thresh", "Thresh"), .kda = .{ .k = 0, .d = 2, .a = 7 }, .line = "Lv 8 · 12 cs" },
        .them = .{ .champ = demo("Leona", "Leona"), .kda = .{ .k = 0, .d = 2, .a = 6 }, .line = "Lv 8 · 9 cs" },
        .gap = "even",
    },
};

pub fn gallery(g: *Gallery) void {
    g.addFill("in game, one dead", view(g.h, &sample));
    g.addFill("a seat unknown", view(g.h, &.{ sample[0], .{ .role = .jungle, .us = sample[1].us } }));
}
