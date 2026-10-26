//! DraftBoard: a draft as lane rows, our seat on the left, theirs mirrored on the right,
//! the role between; both teams' bans under. A seat: portrait, name, a line for its
//! state (hovering, picking) and an optional short fact coloured by its lean; an ally
//! still to pick can carry ideas for the role. The desktop's champ select first, then
//! the draft tester and Daily Draft (draft-tester.md). Champions and roles only: no
//! player names or ranks (product rules)
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const badge = @import("badge.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "DraftBoard";
pub const scope = .{".c-draft"};

pub const State = enum { empty, intent, hover, locked };

pub const Lean = enum { none, good, bad };

pub const Seat = struct {
    champ: ?champ.Champ = null,
    state: State = .empty,
    you: bool = false,
    /// Their turn to pick is now
    picking: bool = false,
    /// The row's role is the recommender's guess (enemy positions are hidden in ranked)
    guessed: bool = false,
    /// A few words ("strong in top now", "51.2% in top"); "" for none
    fact: []const u8 = "",
    lean: Lean = .none,
    /// An ally still to pick: options for the role
    ideas: []const champ.Champ = &.{},
    /// Practice's click on the seat and on each idea (ui/practice.zig Act); "" for none
    act: []const u8 = "",
    idea_acts: []const []const u8 = &.{},
};

pub const Lane = struct {
    role: role.Role,
    us: Seat = .{},
    them: Seat = .{},
};

pub const Board = struct {
    /// Role order, five in a normal draft
    lanes: []const Lane,
    bans_us: []const champ.Champ = &.{},
    bans_them: []const champ.Champ = &.{},
};

const Side = enum { us, them };

pub fn view(h: *H, b: Board) N {
    var rows = h.list();
    for (b.lanes) |l| rows.add(h.div(.{ .key = @as(u32, @backingInt(l.role)), .class = "lane" }, .{
        seat(h, l.us, .us),
        h.span(.{ .class = "mid" }, .{
            role.view(h, l.role, .{ .s = .s }),
            if (l.them.guessed and l.them.champ != null) h.span(.{ .class = "q", .role = "img", .aria_label = words.guessed }, .{"?"}) else null,
        }),
        seat(h, l.them, .them),
    }));
    return h.div(.{ .class = "c-draft" }, .{
        h.div(.{ .class = "heads" }, .{
            h.span(.{ .data_side = Side.us }, .{words.us}),
            h.span(.{ .data_side = Side.them }, .{words.them}),
        }),
        h.div(.{ .class = "lanes" }, .{rows.done()}),
        bans(h, b),
    });
}

fn seat(h: *H, s: Seat, side: Side) N {
    const line: ?N = if (s.picking)
        badge.view(h, .turn, .{words.picking})
    else switch (s.state) {
        .intent => h.span(.{ .class = "line" }, .{words.intent}),
        .hover => h.span(.{ .class = "line" }, .{words.hover}),
        .empty, .locked => null,
    };
    var ideas = h.list();
    for (s.ideas, 0..) |c, i| ideas.add(h.span(.{
        .key = i,
        .data_act = if (i < s.idea_acts.len) s.idea_acts[i] else null,
    }, .{champ.view(h, c, .{ .px = .@"20" })}));
    return h.div(.{
        .class = "seat",
        .data_side = side,
        .data_turn = s.picking,
        .data_you = s.you,
        .data_act = if (s.act.len > 0) s.act else null,
    }, .{
        champ.view(h, s.champ, .{
            .px = .@"40",
            .state = if (s.champ != null and s.state != .locked) .thin else .normal,
            .side = if (s.champ == null or s.state != .locked or s.you) null else switch (side) {
                .us => .us,
                .them => .them,
            },
            .you = s.you,
            .named = false,
            .label = words.empty,
        }),
        h.span(.{ .class = "who" }, .{
            if (s.champ) |c| h.b(.{}, .{c.name}) else null,
            line,
            if (s.fact.len > 0) h.span(.{ .class = "fact", .data_lean = if (s.lean == .none) null else s.lean }, .{s.fact}) else null,
            if (s.ideas.len > 0) h.span(.{ .class = "ideas" }, .{ h.span(.{ .class = "line" }, .{words.ideas}), ideas.done() }) else null,
        }),
    });
}

fn bans(h: *H, b: Board) ?N {
    if (b.bans_us.len + b.bans_them.len == 0) return null;
    var us = h.list();
    for (b.bans_us, 0..) |c, i| us.add(h.span(.{ .key = i }, .{champ.view(h, c, .{ .px = .@"20", .state = .banned })}));
    var them = h.list();
    for (b.bans_them, 0..) |c, i| them.add(h.span(.{ .key = i }, .{champ.view(h, c, .{ .px = .@"20", .state = .banned })}));
    return h.div(.{ .class = "bans" }, .{
        h.span(.{ .data_side = Side.us }, .{us.done()}),
        h.span(.{ .class = "line" }, .{words.bans}),
        h.span(.{ .data_side = Side.them }, .{them.done()}),
    });
}

const words = struct {
    const us = plain("Your team");
    const them = plain("Enemy team");
    const picking = plain("Picking");
    const intent = plain("wants it");
    const hover = plain("hovering");
    const ideas = plain("ideas");
    const bans = plain("Bans");
    const empty = plain("Empty seat");
    const guessed = plain("Role guessed");
};

pub const css =
    \\@layer components {
    \\  .c-draft { container-type: inline-size; display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0;
    \\    max-width: 640px; }
    \\  .c-draft .heads, .c-draft .bans { display: grid; grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
    \\    align-items: center; gap: var(--sp-2); padding: 0 var(--sp-2); }
    \\  .c-draft .heads { grid-template-columns: 1fr 1fr; font-size: var(--fs-xs); font-weight: var(--w-m); }
    \\  .c-draft [data-side="us"] { color: var(--us); }
    \\  .c-draft [data-side="them"] { color: var(--them); text-align: right; }
    \\  .c-draft .lanes { display: flex; flex-direction: column; gap: 2px; }
    \\  .c-draft .lane { display: grid; grid-template-columns: minmax(0, 1fr) 24px minmax(0, 1fr); align-items: center;
    \\    gap: var(--sp-2); padding: 6px var(--sp-2); border-radius: var(--r-s); background: var(--panel-2); }
    \\  .c-draft .mid { display: flex; flex-direction: column; align-items: center; color: var(--muted); }
    \\  .c-draft .q { font-size: var(--fs-xs); color: var(--faint); line-height: 1; }
    \\  .c-draft .seat { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; color: var(--text);
    \\    border-radius: var(--r-s); }
    \\  .c-draft .seat[data-side="them"] { flex-direction: row-reverse; }
    \\  .c-draft .seat[data-turn] { box-shadow: 0 0 0 1px var(--turn-line); background: var(--wash);
    \\    padding: 3px; margin: -3px; }
    \\  .c-draft .who { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
    \\  .c-draft .seat[data-side="them"] .who { align-items: flex-end; text-align: right; }
    \\  .c-draft .who > b { font-weight: var(--w-m); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-draft .line { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-draft .fact { font-size: var(--fs-xs); color: var(--t2); max-width: 100%; overflow: hidden;
    \\    text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-draft .fact[data-lean="good"] { color: var(--hi2); }
    \\  .c-draft .fact[data-lean="bad"] { color: var(--lo2); }
    \\  .c-draft .ideas { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
    \\  .c-draft .bans > span { display: flex; gap: 4px; flex-wrap: wrap; }
    \\  .c-draft .bans > [data-side="them"] { justify-content: flex-end; }
    \\  @container (max-width: 360px) {
    \\    .c-draft .seat > .c-champ { --sz: var(--icon-m); }
    \\    .c-draft .lane { gap: var(--sp-1); padding: 4px; }
    \\  }
    \\}
    \\
;

const demo = champ.demo;

/// Mid draft: allies locked, hovering and picking, two enemies shown with guessed roles
pub const sample: Board = .{
    .lanes = &.{
        .{
            .role = .top,
            .us = .{ .champ = demo("Garen", "Garen"), .state = .locked, .fact = "strong in top now", .lean = .good },
            .them = .{ .champ = demo("Darius", "Darius"), .state = .locked, .guessed = true },
        },
        .{
            .role = .jungle,
            .us = .{ .champ = demo("LeeSin", "Lee Sin"), .state = .hover, .picking = true },
            .them = .{},
        },
        .{
            .role = .mid,
            .us = .{ .champ = demo("Ahri", "Ahri"), .state = .hover, .you = true },
            .them = .{ .champ = demo("Syndra", "Syndra"), .state = .locked, .guessed = true, .fact = "weak in mid now", .lean = .bad },
        },
        .{
            .role = .bot,
            .us = .{ .ideas = &.{ demo("Jinx", "Jinx"), demo("Caitlyn", "Caitlyn"), demo("Ezreal", "Ezreal") } },
        },
        .{
            .role = .support,
            .us = .{ .champ = demo("Lulu", "Lulu"), .state = .intent },
        },
    },
    .bans_us = &.{ demo("Yasuo", "Yasuo"), demo("Zed", "Zed") },
    .bans_them = &.{ demo("Vex", "Vex"), demo("Aurora", "Aurora"), demo("Smolder", "Smolder") },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("mid draft", view(h, sample));
    g.addFill("planning, nothing shown", view(h, .{ .lanes = &.{
        .{ .role = .top },
        .{ .role = .jungle },
        .{ .role = .mid, .us = .{ .you = true } },
        .{ .role = .bot },
        .{ .role = .support },
    } }));
}
