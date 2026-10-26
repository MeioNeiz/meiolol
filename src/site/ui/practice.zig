//! Practice (private edition): a champ select set up by hand in the app (role, pick
//! place, stage, screen, a random draft) and a champion picker for any seat or ban. Its
//! own island and file (ui-practice.wasm), loaded only while practice is on: the shell
//! renders it above the app's page and keeps its Data at practice.bin. The poller
//! builds what the app's page shows from the setup (src/practice.zig).
//!
//! The board is ui-app.wasm's: while practice shows, the shell writes an Act on each
//! seat, lane option, ally idea and ban option as data-act, and ui-practice.wasm takes
//! the clicks. A seat opens the picker, a lane option hovers it as my pick (a second
//! click locks it), an idea fills its ally's seat, a ban option is my ban
const std = @import("std");
const tree = @import("tree.zig");
const button = @import("button.zig");
const chip = @import("chip.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const segmented = @import("segmented.zig");
const url = @import("url.zig");
const toshell = @import("toshell.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;
const Target = toshell.Target;

pub const name = "Practice";
pub const scope = .{".c-practice"};
pub const sel = "[data-island=practice]";

pub const Screen = enum { select, loading, game, post };
pub const Stage = enum { planning, bans, picks, finalising };
pub const Lead = enum { behind, even, ahead };

/// The bar's minutes; Set.minute is an index into them
pub const minutes = [_]u8{ 5, 10, 15, 20, 25, 30, 35 };

pub const Data = struct {
    /// The shell's count of changes, as app.Data's
    seq: u32,
    /// False while the client's own champ select or game shows: practice waits
    shown: bool = true,
    screen: Screen = .select,
    stage: Stage = .picks,
    role: role.Role = .mid,
    /// My place in my team's pick order, 0 first
    pick: u8 = 2,
    minute: u8 = 15,
    lead: Lead = .even,
    win: bool = true,
    my_bans: [5]?champ.Champ = @splat(null),
    their_bans: [5]?champ.Champ = @splat(null),
    /// Every champion for the picker, most played first
    champs: []const Pick = &.{},
    /// Indexes into champs by games in each role (Role.all's order): an ally's seat
    by_role: [5][]const u16 = @splat(&.{}),
};

pub const Pick = struct { id: u32, champ: champ.Champ };

/// A click on the app's board, written by the shell as data-act ("seat enemy 2",
/// "take 266", "ban 266", "fill 3 266")
pub const Act = union(enum) {
    /// The picker for this seat
    seat: Target,
    take: u32,
    ban: u32,
    /// An ally's idea into their seat: role index, champion
    fill: struct { u8, u32 },

    pub fn format(a: Act, w: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (a) {
            .seat => |t| switch (t) {
                inline else => |i, tag| try w.print("seat {t} {d}", .{ tag, i }),
            },
            .take => |c| try w.print("take {d}", .{c}),
            .ban => |c| try w.print("ban {d}", .{c}),
            .fill => |f| try w.print("fill {d} {d}", .{ f[0], f[1] }),
        }
    }

    pub fn parse(s: []const u8) ?Act {
        var it = std.mem.tokenizeScalar(u8, s, ' ');
        const verb = it.next() orelse return null;
        const a = it.next() orelse return null;
        const b = it.next();
        if (std.mem.eql(u8, verb, "seat")) {
            const tag = std.meta.stringToEnum(std.meta.Tag(Target), a) orelse return null;
            const i = place(b orelse return null) orelse return null;
            return .{ .seat = switch (tag) {
                inline else => |t| @unionInit(Target, @tagName(t), i),
            } };
        }
        if (std.mem.eql(u8, verb, "fill")) return .{ .fill = .{ place(a) orelse return null, id(b orelse return null) orelse return null } };
        const c = id(a) orelse return null;
        if (std.mem.eql(u8, verb, "take")) return .{ .take = c };
        if (std.mem.eql(u8, verb, "ban")) return .{ .ban = c };
        return null;
    }

    fn place(s: []const u8) ?u8 {
        const i = std.fmt.parseInt(u8, s, 10) catch return null;
        return if (i < 5) i else null;
    }

    fn id(s: []const u8) ?u32 {
        return std.fmt.parseInt(u32, s, 10) catch null;
    }
};

pub const Practice = struct {
    data: Data,
    /// The seat or ban the picker is open for
    target: ?Target = null,
    query: url.Str(32) = .{},
    lock_in: bool = true,

    pub const Msg = union(enum) { set: toshell.Set, random, clear, open: Target, close, query, key, lock, empty, choose: u32 };

    pub fn update(p: *Practice, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .set => |s| toshell.practice(.set, s),
            .random => toshell.practice(.random, {}),
            .clear => toshell.practice(.clear, {}),
            .open => |t| {
                p.open(t);
                ev.after = .{ .op = .focus, .ref = "search" };
            },
            .close => p.target = null,
            .query => p.query.set(ev.text),
            .key => if (std.mem.eql(u8, ev.text, "Enter")) {
                var buf: [1]u16 = undefined;
                const found = p.matches(&buf);
                if (found.len > 0) p.place(p.data.champs[found[0]].id);
            } else if (std.mem.eql(u8, ev.text, "Escape")) {
                p.target = null;
            },
            .lock => p.lock_in = !p.lock_in,
            .empty => p.place(0),
            .choose => |c| p.place(c),
        }
    }

    pub fn open(p: *Practice, t: Target) void {
        p.target = t;
        p.query.len = 0;
    }

    /// A click on the board: the picker opens here, the rest goes to the shell
    pub fn act(p: *Practice, a: Act) void {
        if (!p.data.shown) return;
        switch (a) {
            .seat => |t| p.open(t),
            .take => |c| toshell.practice(.take, c),
            .ban => |c| toshell.practice(.ban, c),
            .fill => |f| toshell.practice(.place, .{ .at = .{ .ally = f[0] }, .champion = f[1], .locked = true }),
        }
    }

    fn place(p: *Practice, c: u32) void {
        const t = p.target orelse return;
        toshell.practice(.place, .{ .at = t, .champion = c, .locked = c != 0 and (t != .ally or p.lock_in) });
        p.target = null;
    }

    /// Champions whose name holds the query (any case), as indexes into champs: by
    /// games in the seat's role for an ally, overall otherwise. Up to out.len
    fn matches(p: *const Practice, out: []u16) []u16 {
        const d = &p.data;
        const order: ?[]const u16 = if (p.target) |t| switch (t) {
            .ally => |r| if (d.by_role[r].len > 0) d.by_role[r] else null,
            else => null,
        } else null;
        const total = if (order) |o| o.len else d.champs.len;
        var n: usize = 0;
        for (0..total) |k| {
            if (n == out.len) break;
            const i: u16 = if (order) |o| o[k] else @intCast(k);
            if (i >= d.champs.len) continue;
            if (std.ascii.findIgnoreCase(d.champs[i].champ.name, p.query.slice()) == null) continue;
            out[n] = i;
            n += 1;
        }
        return out[0..n];
    }

    pub fn view(p: *Practice, h: *H) N {
        const d = p.data;
        const attrs = .{ .class = "c-practice", .data_island = "practice", .data_seq = d.seq };
        if (!d.shown) return h.div(attrs, .{h.p(.{ .class = "hint" }, .{W.waits})});
        return h.div(attrs, .{
            h.div(.{ .class = "row" }, .{
                p.choice(h, .screen, W.screen, &W.screens, @backingInt(d.screen)),
                if (d.screen == .select) p.choice(h, .stage, W.stage, &W.stages, @backingInt(d.stage)) else null,
                p.choice(h, .role, W.role_label, &W.roles, @backingInt(d.role)),
                p.choice(h, .pick, W.pick, &W.places, d.pick),
                button.view(h, .{ .s = .s, .on = h.on(p, .random) }, .{W.random}),
                button.view(h, .{ .s = .s, .on = h.on(p, .clear) }, .{W.clear}),
            }),
            switch (d.screen) {
                .select => h.div(.{ .class = "row" }, .{
                    h.span(.{ .class = "bans" }, .{ h.span(.{ .class = "k" }, .{W.bans}), p.bans(h, true), p.bans(h, false) }),
                    h.p(.{ .class = "hint" }, .{W.how}),
                }),
                .loading => null,
                .game, .post => h.div(.{ .class = "row" }, .{
                    p.choice(h, .minute, W.minute, &W.minute_names, std.mem.indexOfScalar(u8, &minutes, d.minute) orelse 2),
                    p.choice(h, .lead, W.team, &W.leads, @backingInt(d.lead)),
                    if (d.screen == .post) p.choice(h, .win, W.result, &W.results, @intFromBool(!d.win)) else null,
                }),
            },
            if (p.target) |t| p.picker(h, t) else null,
        });
    }

    /// "Label [a][b][c]"; a click sets the field to the choice's index
    fn choice(p: *Practice, h: *H, comptime field: std.meta.Tag(toshell.Set), label: tree.Text, names: []const tree.Text, current: usize) N {
        const items = h.mem.alloc(segmented.Item, names.len) catch {
            h.oom = true;
            return .none;
        };
        for (items, names, 0..) |*it, n, i| {
            const s: toshell.Set = if (field == .win) .{ .win = i == 0 } else @unionInit(toshell.Set, @tagName(field), @intCast(i));
            it.* = .{ .label = n, .selected = i == current, .on = if (i == current) null else h.on(p, .{ .set = s }) };
        }
        return h.span(.{ .class = "choice" }, .{
            h.span(.{ .class = "k" }, .{label}),
            segmented.view(h, .{ .s = .s, .label = label }, items),
        });
    }

    /// One team's five bans, each opening the picker
    fn bans(p: *Practice, h: *H, mine: bool) N {
        const list = if (mine) p.data.my_bans else p.data.their_bans;
        var l = h.list();
        for (list, 0..) |c, i| {
            const t: Target = if (mine) .{ .my_ban = @intCast(i) } else .{ .their_ban = @intCast(i) };
            l.add(h.button(.{
                .key = i,
                .type = "button",
                .aria_label = if (c) |x| tree.Text{ .s = x.name } else W.empty_ban,
                .on_click = h.on(p, .{ .open = t }),
            }, .{champ.view(h, c, .{ .px = .@"24", .state = if (c != null) .banned else .normal, .side = if (mine) .us else .them, .named = false })}));
        }
        return h.span(.{ .data_side = if (mine) "us" else "them" }, .{l.done()});
    }

    fn picker(p: *Practice, h: *H, t: Target) N {
        const found = h.mem.alloc(u16, p.data.champs.len) catch {
            h.oom = true;
            return .none;
        };
        var l = h.list();
        for (p.matches(found)) |i| {
            const c = p.data.champs[i];
            l.add(h.button(.{ .key = c.id, .type = "button", .class = "pick", .on_click = h.on(p, .{ .choose = c.id }) }, .{
                champ.view(h, c.champ, .{ .px = .@"40", .named = false }),
                h.span(.{}, .{c.champ.name}),
            }));
        }
        return h.div(.{ .class = "picker", .role = "dialog", .aria_modal = true, .aria_label = W.pick_one }, .{
            h.div(.{ .class = "box" }, .{
                h.div(.{ .class = "head" }, .{
                    switch (t) {
                        .ally => |r| h.el(.h2, .{}, .{ W.your_team, role.Role.label(@fromBackingInt(@intCast(r))) }),
                        .enemy => |i| h.el(.h2, .{}, .{ W.enemy_seat, @as(u32, i) + 1 }),
                        .my_ban => h.el(.h2, .{}, .{W.my_ban}),
                        .their_ban => h.el(.h2, .{}, .{W.their_ban}),
                    },
                    button.view(h, .{ .v = .icon, .s = .s, .label = W.close, .on = h.on(p, .close) }, .{"×"}),
                }),
                h.div(.{ .class = "row" }, .{
                    h.input(.{
                        .value = p.query.slice(),
                        .placeholder = W.search,
                        .aria_label = W.search,
                        .data_ref = "search",
                        .on_input = h.on(p, .query),
                        .on_keydown = h.on(p, .key),
                    }),
                    if (t == .ally) chip.view(h, .{ .pressed = p.lock_in, .on = h.on(p, .lock) }, .{W.lock_in}) else null,
                    button.view(h, .{ .s = .s, .on = h.on(p, .empty) }, .{W.empty}),
                }),
                h.div(.{ .class = "grid" }, .{l.done()}),
            }),
        });
    }
};

const W = struct {
    const waits = plain("Practice waits while the client is in champ select or a game.");
    const how = plain("Click a seat or ban to fill it; a lane option hovers it as your pick, a second click locks it.");
    const screen = plain("Screen");
    const screens = [_]tree.Text{ plain("Champ select"), plain("Loading"), plain("In game"), plain("Post game") };
    const stage = plain("Stage");
    const stages = [_]tree.Text{ plain("Planning"), plain("Bans"), plain("Picks"), plain("Finalising") };
    const role_label = plain("Role");
    const roles = [_]tree.Text{ plain("Top"), plain("Jungle"), plain("Mid"), plain("Bot"), plain("Support") };
    const pick = plain("Pick");
    const places = [_]tree.Text{ plain("1"), plain("2"), plain("3"), plain("4"), plain("5") };
    const minute = plain("Minute");
    const minute_names = [_]tree.Text{ plain("5"), plain("10"), plain("15"), plain("20"), plain("25"), plain("30"), plain("35") };
    const team = plain("Your team");
    const leads = [_]tree.Text{ plain("Behind"), plain("Even"), plain("Ahead") };
    const result = plain("Result");
    const results = [_]tree.Text{ plain("Win"), plain("Loss") };
    const random = plain("Random draft");
    const clear = plain("Clear");
    const bans = plain("Bans");
    const empty_ban = plain("Empty ban");
    const pick_one = plain("Pick a champion");
    const your_team = plain("Your team: ");
    const enemy_seat = plain("Enemy seat ");
    const my_ban = plain("Your team's ban");
    const their_ban = plain("Enemy team's ban");
    const close = plain("Close");
    const search = plain("Search champions");
    const lock_in = plain("Lock in");
    const empty = plain("Empty");
};

pub const css =
    \\@layer components {
    \\  .c-practice { position: sticky; top: 0; z-index: 3; display: flex; flex-direction: column; gap: var(--sp-2);
    \\    padding: var(--sp-2) var(--sp-4); background: var(--panel-2); border-bottom: 1px solid var(--line); }
    \\  .c-practice .row { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2) var(--sp-4); }
    \\  .c-practice .choice, .c-practice .bans, .c-practice .bans > span { display: inline-flex; align-items: center; gap: var(--sp-1); }
    \\  .c-practice .bans { gap: var(--sp-3); }
    \\  .c-practice .k { font-size: var(--fs-s); color: var(--muted); }
    \\  .c-practice .bans button { all: unset; display: inline-flex; cursor: pointer; border-radius: var(--r-s); }
    \\  .c-practice .bans button:focus-visible { outline: 2px solid var(--focus); }
    \\  .c-practice .hint { margin: 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-practice .picker { position: fixed; inset: 0; z-index: 10; display: flex; align-items: center;
    \\    justify-content: center; background: color-mix(in srgb, var(--bg) 70%, transparent); }
    \\  .c-practice .box { display: flex; flex-direction: column; gap: var(--sp-2); width: min(560px, 100% - 32px);
    \\    height: min(520px, 100% - 32px); padding: var(--sp-3); background: var(--panel); border: 1px solid var(--line);
    \\    border-radius: var(--r-m); box-shadow: var(--shadow-pop); }
    \\  .c-practice .head { display: flex; align-items: center; justify-content: space-between; }
    \\  .c-practice h2 { margin: 0; font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-practice input { flex: 1; min-width: 0; }
    \\  .c-practice .grid { flex: 1; overflow-y: auto; display: grid; grid-template-columns: repeat(auto-fill, minmax(76px, 1fr));
    \\    align-content: start; gap: 4px; }
    \\  .c-practice .pick { all: unset; display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 4px;
    \\    border-radius: var(--r-s); font-size: var(--fs-xs); text-align: center; cursor: pointer; }
    \\  .c-practice .pick:hover { background: var(--ctl-bg-2); }
    \\  .c-practice .pick:focus-visible { outline: 2px solid var(--focus); }
    \\}
    \\
;

const sample_champs = [_]Pick{
    .{ .id = 103, .champ = .{ .name = "Ahri", .src = "" } },
    .{ .id = 266, .champ = .{ .name = "Aatrox", .src = "" } },
    .{ .id = 7, .champ = .{ .name = "LeBlanc", .src = "" } },
    .{ .id = 64, .champ = .{ .name = "Lee Sin", .src = "" } },
};

pub const sample: Data = .{
    .seq = 1,
    .my_bans = .{ .{ .name = "Yasuo", .src = "" }, null, null, null, null },
    .their_bans = .{ .{ .name = "Zed", .src = "" }, .{ .name = "Yone", .src = "" }, null, null, null },
    .champs = &sample_champs,
    .by_role = .{ &.{ 1, 0 }, &.{3}, &.{ 0, 2 }, &.{}, &.{} },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, Data, ?Target }{
        .{ "champ select", sample, null },
        .{ "in game", .{ .seq = 2, .screen = .game, .minute = 20, .lead = .ahead }, null },
        .{ "waiting for the client", .{ .seq = 3, .shown = false }, null },
        .{ "picker for mid", sample, .{ .ally = 2 } },
    };
    for (states) |s| {
        const p = h.mem.create(Practice) catch return;
        p.* = .{ .data = s[1], .target = s[2] };
        g.addFill(s[0], p.view(h));
    }
}

const testing = std.testing;

test "acts as the shell writes them and back" {
    const all = [_]Act{ .{ .seat = .{ .enemy = 2 } }, .{ .seat = .{ .ally = 4 } }, .{ .take = 266 }, .{ .ban = 7 }, .{ .fill = .{ 3, 103 } } };
    for (all) |a| {
        var b: [32]u8 = undefined;
        const s = try std.fmt.bufPrint(&b, "{f}", .{a});
        try testing.expectEqualDeep(a, Act.parse(s).?);
    }
    var buf: [32]u8 = undefined;
    try testing.expectEqualStrings("seat enemy 2", try std.fmt.bufPrint(&buf, "{f}", .{all[0]}));
    for ([_][]const u8{ "", "seat", "seat enemy 5", "seat bench 1", "take x", "fill 9 1", "jump 3" }) |bad|
        try testing.expect(Act.parse(bad) == null);
}

var sent: std.ArrayList(u8) = .empty;

fn record(s: []const u8) void {
    sent.appendSlice(testing.allocator, s) catch unreachable;
    sent.append(testing.allocator, '\n') catch unreachable;
}

test "picker: an ally's list by role games, filtered, Enter places the first locked" {
    const old = toshell.out;
    defer toshell.out = old;
    toshell.out = record;
    defer sent.deinit(testing.allocator);
    sent.clearRetainingCapacity();

    var p: Practice = .{ .data = sample };
    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .open = .{ .ally = 2 } }, &ev);
    var buf: [8]u16 = undefined;
    try testing.expectEqualSlices(u16, &.{ 0, 2 }, p.matches(&buf));
    ev.text = "le";
    p.update(.query, &ev);
    try testing.expectEqualSlices(u16, &.{2}, p.matches(&buf));
    ev.text = "Enter";
    p.update(.key, &ev);
    try testing.expect(p.target == null);

    // Enemies: every champion in the file's order; Empty clears, never locked
    p.act(.{ .seat = .{ .enemy = 0 } });
    try testing.expectEqualSlices(u16, &.{ 0, 1, 2, 3 }, p.matches(&buf));
    p.update(.empty, &ev);
    // Lock in off: an ally's pick is a hover
    p.update(.lock, &ev);
    p.act(.{ .seat = .{ .ally = 0 } });
    p.update(.{ .choose = 266 }, &ev);
    p.act(.{ .fill = .{ 1, 64 } });
    p.act(.{ .take = 103 });
    try testing.expectEqualStrings(
        \\{"practice":{"place":{"at":{"ally":2},"champion":7,"locked":true}}}
        \\{"practice":{"place":{"at":{"enemy":0},"champion":0,"locked":false}}}
        \\{"practice":{"place":{"at":{"ally":0},"champion":266,"locked":false}}}
        \\{"practice":{"place":{"at":{"ally":1},"champion":64,"locked":true}}}
        \\{"practice":{"take":103}}
        \\
    , sent.items);

    // Waiting for the client: board clicks do nothing
    p.data.shown = false;
    p.act(.{ .seat = .{ .enemy = 1 } });
    try testing.expect(p.target == null);
}
