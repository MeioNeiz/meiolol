//! The Learn page (docs/plan/ui/learn.md): one puzzle a screen. ChapterStrip on top
//! (title, the chapter's question, n/N, stars), the PuzzleCard, and beside it (under it
//! on a phone) ChapterPath: this chapter's puzzles, the tips earned, every chapter with
//! its progress. A chapter's end lists its takeaways with their stars. One island
//! (ui-learn.wasm); progress in localStorage through the page's code (`progress`)
const std = @import("std");
const tree = @import("tree.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const button = @import("button.zig");
const toggletip = @import("toggletip.zig");
const guess = @import("guess.zig");
const puzzle = @import("puzzle.zig");
const ld = @import("learndata.zig");
const champ = @import("champ.zig");
const choice = @import("choice.zig");
const role = @import("role.zig");
const phrase = @import("phrase.zig");
const url = @import("url.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "LearnPage";
pub const scope = .{".c-learn"};
pub const sel = "[data-island=learn]";

const W = struct {
    pub const title = plain("Learn");
    pub const chapter = Phrase("Chapter {n:int}");
    pub const of = Phrase("{a:int} / {b:int}");
    pub const done = Phrase("Chapter {n:int} done");
    pub const lock = plain("Lock in");
    pub const next = plain("Next");
    pub const next_chapter = plain("Next chapter");
    pub const again = plain("Again");
    pub const tips = plain("Your tips");
    pub const chapters = plain("Chapters");
    pub const games = Phrase("{n:count} games");
};

pub const Page = struct {
    d: *const ld.Data,
    a: std.mem.Allocator,
    c: u8,
    p: u8 = 0,
    /// On a chapter's end screen
    end: bool = false,
    g: guess.Guess = .{ .lo = 0, .hi = 100 },
    pick: ?u8 = null,
    revealed: bool = false,
    progress: ld.Progress = .{},
    /// Set when progress changed: the page's code saves it
    dirty: bool = false,
    /// The server's render: Data as ui.data, base64, for the island
    bin: []const u8 = "",

    /// The puzzle's id: a link to one puzzle
    pub const Url = struct { p: url.Str(48) = .{} };

    pub const Msg = union(enum) {
        guess,
        lock,
        next,
        again,
        choose: u8,
        go: [2]u8,
        key,
    };

    pub fn init(a: std.mem.Allocator, d: *const ld.Data) Page {
        var p: Page = .{ .d = d, .a = a, .c = @min(d.start, @as(u8, @intCast(d.chapters.len - 1))) };
        p.reset();
        return p;
    }

    fn cur(p: *const Page) *const ld.Puzzle {
        return &p.d.chapters[p.c].puzzles[p.p];
    }

    fn reset(p: *Page) void {
        p.revealed = false;
        p.pick = null;
        p.end = false;
        switch (p.cur().answer) {
            .guess => |x| p.g = .{ .lo = x.lo, .hi = x.hi, .step = x.step, .unit = x.unit, .from = if (p.cur().setup == .rates) 50 else null },
            .pick => {},
        }
    }

    fn lockable(p: *const Page) bool {
        if (p.revealed or p.end) return false;
        return switch (p.cur().answer) {
            .guess => p.g.value != null,
            .pick => p.pick != null,
        };
    }

    fn reveal(p: *Page) void {
        p.revealed = true;
        const z = p.cur();
        const n: u2 = switch (z.answer) {
            .guess => |x| blk: {
                p.g.real = x.real;
                break :blk p.g.stars(x.tol);
            },
            .pick => |x| if (p.pick == x.right) 3 else 0,
        };
        p.progress.set(p.a, z.id, n) catch {};
        p.dirty = true;
    }

    pub fn update(p: *Page, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .guess => return if (p.g.event(ev) == .commit) p.reveal(),
            .lock => return if (p.lockable()) p.reveal(),
            .choose => |i| return if (!p.revealed) {
                p.pick = i;
            },
            .next => p.advance(),
            .again => {
                p.p = 0;
                p.reset();
            },
            .go => |x| {
                p.c = x[0];
                p.p = x[1];
                p.reset();
                ev.push = true;
            },
            .key => {
                const z = p.cur();
                if (std.mem.eql(u8, ev.text, "Enter")) {
                    if (p.revealed) {
                        p.advance();
                    } else if (z.answer == .pick and p.lockable()) {
                        return p.reveal();
                    } else return;
                    ev.handled = true;
                } else if (!p.end and !p.revealed and z.answer == .pick and ev.text.len == 1 and ev.text[0] >= '1' and ev.text[0] - '1' < z.answer.pick.choices.len) {
                    p.pick = ev.text[0] - '1';
                    ev.handled = true;
                    return;
                } else return;
            },
        }
        // On a phone the answer sits below the stage: the next puzzle starts at its top
        ev.after = .{ .op = .scroll, .ref = "main" };
    }

    fn advance(p: *Page) void {
        const ch = p.d.chapters[p.c];
        if (p.end) {
            p.c = @intCast((p.c + 1) % p.d.chapters.len);
            p.p = 0;
            p.reset();
        } else if (p.p + 1 < ch.puzzles.len) {
            p.p += 1;
            p.reset();
        } else p.end = true;
    }

    pub fn toUrl(p: *const Page) Url {
        var u: Url = .{};
        u.p.set(p.cur().id);
        return u;
    }

    pub fn fromUrl(p: *Page, u: Url) void {
        for (p.d.chapters, 0..) |ch, ci| for (ch.puzzles, 0..) |z, zi| if (std.mem.eql(u8, z.id, u.p.slice())) {
            p.c = @intCast(ci);
            p.p = @intCast(zi);
            p.reset();
            return;
        };
    }

    pub fn view(p: *Page, h: *H) N {
        return h.div(.{ .class = "c-learn", .data_island = "learn", .data_bin = if (p.bin.len > 0) p.bin else null, .on_keydown = h.on(p, .key) }, .{
            p.strip(h),
            h.div(.{ .class = "grid" }, .{
                h.div(.{ .class = "main", .data_ref = "main" }, .{if (p.end) p.endCard(h) else p.puzzleCard(h)}),
                p.path(h),
            }),
        });
    }

    fn strip(p: *const Page, h: *H) N {
        const ch = p.d.chapters[p.c];
        var total: u32 = 0;
        for (p.progress.stars.items) |n| total += n;
        return h.div(.{ .class = "strip" }, .{
            h.el(.h1, .{}, .{W.title}),
            badge.view(h, .neutral, .{W.chapter.with(h, .{ .n = p.c })}),
            h.span(.{ .class = "ct" }, .{ch.title}),
            h.span(.{ .class = "meta" }, .{
                W.of.with(h, .{ .a = p.p + 1, .b = ch.puzzles.len }),
                h.span(.{ .class = "tot" }, .{ "★ ", total }),
            }),
        });
    }

    fn puzzleCard(p: *Page, h: *H) N {
        const z = p.cur();
        // The reveal's rows replace any setup: the whole picture once answered
        const stage: N = if (p.revealed and z.reveal.len > 0) p.ratesStage(h, z) else switch (z.setup) {
            .rates => p.ratesStage(h, z),
            .duel => |d| p.duelStage(h, d),
            .tiles => |t| p.tilesStage(h, t),
            .chips => |c| p.chipsStage(h, c),
        };
        const tt = toggletip.view(h, "lp-src", .{W.games.with(h, .{ .n = z.games })}, W.games.with(h, .{ .n = z.games }), .{ .s = z.from });
        return puzzle.view(h, .{
            .stage = stage,
            .q = question(h, z),
            .ctx = if (!p.revealed and z.ctx.len > 0) h.span(.{}, .{z.ctx}) else null,
            .answer = switch (z.answer) {
                .pick => |x| p.choices(h, x),
                .guess => if (z.setup == .rates) null else guess.view(h, &p.g, .{ .on = h.on(p, .guess) }),
            },
            .off = if (p.revealed and z.answer == .guess) guess.offText(h, &p.g) else null,
            .stars = if (p.revealed) p.progress.get(z.id) else null,
            .why = if (p.revealed) .{ .s = z.why } else null,
            .take = if (p.revealed) .{ .s = z.tip } else null,
            .games = h.span(.{}, .{&tt}),
            .action = if (p.revealed)
                button.view(h, .{ .v = .primary, .on = h.on(p, .next) }, .{W.next})
            else
                button.view(h, .{ .v = .primary, .disabled = !p.lockable(), .on = h.on(p, .lock) }, .{W.lock}),
        });
    }

    /// The question, its term (if any) a Toggletip with the term's note
    fn question(h: *H, z: *const ld.Puzzle) N {
        const t = z.term orelse return h.span(.{}, .{z.q});
        const i = std.mem.find(u8, z.q, t.word) orelse return h.span(.{}, .{z.q});
        const tt = toggletip.view(h, "lp-term", .{t.word}, .{ .s = t.word }, .{ .s = t.note });
        return h.span(.{}, .{ z.q[0..i], &tt, z.q[i + t.word.len ..] });
    }

    fn ratesStage(p: *Page, h: *H, z: *const ld.Puzzle) N {
        const ask: ?usize = if (z.setup == .rates and !p.revealed) z.setup.rates.ask else null;
        const src = if (p.revealed and z.reveal.len > 0) z.reveal else z.setup.rates.rows;
        const real: ?f32 = if (z.answer == .guess) z.answer.guess.real else null;
        // A pick's scale is its rows' alone (p.g is the last guess's)
        var lo: f32 = if (z.answer == .guess) p.g.lo else 100;
        var hi: f32 = if (z.answer == .guess) p.g.hi else 0;
        const rows = h.mem.alloc(puzzle.Row, src.len) catch {
            h.oom = true;
            return .none;
        };
        for (src, 0..) |x, i| {
            const hit = p.revealed and real != null and @abs(x.v - real.?) < 0.05;
            rows[i] = .{
                .label = .{ .s = x.label },
                .sub = if (x.sub.len > 0) tree.Text{ .s = x.sub } else null,
                .v = if (ask == i) null else x.v,
                .games = x.games,
                .hit = hit,
                .you = if (hit) p.g.value else null,
            };
            lo = @min(lo, @floor(x.v / 10) * 10);
            hi = @max(hi, @ceil(x.v / 10) * 10);
        }
        return puzzle.rates(h, .{
            .lo = lo,
            .hi = hi,
            .rows = rows,
            .ticks = ticks(h, lo, hi),
            .ask = if (ask != null) &p.g else null,
            .on = h.on(p, .guess),
        });
    }

    fn ticks(h: *H, lo: f32, hi: f32) []const f32 {
        const step: f32 = if (hi - lo > 30) 10 else 5;
        var l: std.ArrayList(f32) = .empty;
        var v = @ceil(lo / step) * step;
        while (v <= hi) : (v += step) l.append(h.mem, v) catch {
            h.oom = true;
            break;
        };
        return l.items;
    }

    fn iconSrc(p: *const Page, h: *H, c: ld.Champ) []const u8 {
        return h.fmt("https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ p.d.ddragon, c.key });
    }

    fn icon(p: *const Page, h: *H, c: ld.Champ, px: champ.Px) N {
        return champ.view(h, .{ .name = c.name, .src = p.iconSrc(h, c) }, .{ .px = px });
    }

    fn duelStage(p: *const Page, h: *H, d: ld.Duel) N {
        var l = h.list();
        for (d.vs, 0..) |f, i| l.add(h.span(.{ .key = i }, .{ p.icon(h, f.champ, .@"32"), h.b(.{}, .{f.text}) }));
        return h.div(.{ .class = "duel" }, .{
            h.div(.{ .class = "who" }, .{
                p.icon(h, d.who, .@"48"),
                h.span(.{}, .{ h.span(.{ .class = "nm" }, .{d.who.name}), role.view(h, d.role, .{}) }),
            }),
            h.span(.{ .class = "vs" }, .{d.label}),
            h.div(.{ .class = "vs3" }, .{l.done()}),
        });
    }

    fn tilesStage(p: *const Page, h: *H, ts: []const ld.Tile) N {
        var l = h.list();
        for (ts, 0..) |t, i| {
            var ics = h.list();
            for (t.champs, 0..) |c, j| {
                if (j > 0 and t.sep.len > 0) ics.add(h.span(.{ .key = 2 * j - 1, .class = "sep" }, .{t.sep}));
                ics.add(h.span(.{ .key = 2 * j, .class = "ic" }, .{ p.icon(h, c, .@"32"), h.span(.{ .class = "nm" }, .{c.name}) }));
            }
            l.add(h.div(.{ .key = i, .class = "tile" }, .{
                if (t.title.len > 0) h.div(.{ .class = "h" }, .{ if (t.role) |r| role.view(h, r, .{}) else null, t.title }) else null,
                h.div(.{ .class = "ics" }, .{ics.done()}),
            }));
        }
        return h.div(.{ .class = "tiles" }, .{l.done()});
    }

    fn chipsStage(p: *const Page, h: *H, c: ld.Chips) N {
        var l = h.list();
        for (c.champs) |x| l.add(p.icon(h, x, .@"40"));
        for (c.chips) |t| l.add(badge.view(h, .accent, .{t}));
        return h.div(.{ .class = "chips" }, .{l.done()});
    }

    fn choices(p: *Page, h: *H, x: ld.Pick) N {
        const cs = h.mem.alloc(choice.Choice, x.choices.len) catch {
            h.oom = true;
            return .none;
        };
        for (x.choices, cs, 0..) |c, *o, i| {
            const chosen = p.pick != null and p.pick.? == i;
            o.* = .{
                .champ = if (c.champ) |y| .{ .name = y.name, .src = p.iconSrc(h, y) } else null,
                .label = .{ .s = c.text },
                .chosen = chosen,
                .mark = if (!p.revealed) .none else if (i == x.right) .right else if (chosen) .wrong else .none,
                .sub = if (c.shown.len > 0) .{ .s = c.shown } else null,
                .on = h.on(p, .{ .choose = @as(u8, @intCast(i)) }),
            };
        }
        return choice.view(h, .{ .done = p.revealed, .label = .{ .s = p.cur().q } }, cs);
    }

    fn endCard(p: *Page, h: *H) N {
        const ch = p.d.chapters[p.c];
        const s = p.progress.chapter(ch);
        var l = h.list();
        for (ch.puzzles, 0..) |z, i| l.add(h.el(.li, .{ .key = i }, .{
            h.span(.{ .class = "t" }, .{z.tip}),
            puzzle.stars(h, p.progress.get(z.id) orelse 0, false),
        }));
        const full: u32 = 3 * @as(u32, @intCast(ch.puzzles.len));
        return card.view(h, .{}, &.{h.div(.{ .class = "end" }, .{
            h.div(.{ .class = "done-h" }, .{
                h.span(.{ .class = "k" }, .{W.done.with(h, .{ .n = p.c })}),
                h.h2(.{}, .{ch.title}),
                puzzle.stars(h, @intCast(@min(3, (3 * @as(u32, s.stars) + full / 2) / @max(full, 1))), true),
            }),
            h.el(.ul, .{ .class = "tk" }, .{l.done()}),
            h.div(.{ .class = "foot" }, .{
                button.view(h, .{ .v = .quiet, .on = h.on(p, .again) }, .{W.again}),
                button.view(h, .{ .v = .primary, .on = h.on(p, .next) }, .{W.next_chapter}),
            }),
        })});
    }

    fn path(p: *Page, h: *H) N {
        var tips = h.list();
        var chs = h.list();
        for (p.d.chapters, 0..) |ch, ci| {
            const s = p.progress.chapter(ch);
            chs.add(h.a(.{
                .key = ci,
                .href = h.fmt("#p={s}", .{ch.puzzles[0].id}),
                .class = "ch",
                .aria_current = if (ci == p.c) "step" else null,
                .on_click = h.on(p, .{ .go = .{ @as(u8, @intCast(ci)), 0 } }),
            }, .{
                h.span(.{ .class = "n" }, .{ci}),
                h.span(.{ .class = "t" }, .{ch.title}),
                h.span(.{ .class = "p" }, .{W.of.with(h, .{ .a = s.done, .b = ch.puzzles.len })}),
            }));
            for (ch.puzzles) |z| if (p.progress.get(z.id) != null) tips.add(puzzle.take(h, .{ .s = z.tip }));
        }
        return card.view(h, .{ .label = W.chapters }, &.{h.div(.{ .class = "path" }, .{
            if (tips.done().len > 0) h.div(.{ .class = "tips" }, .{ h.span(.{ .class = "lab" }, .{W.tips}), tips.done() }) else null,
            h.div(.{ .class = "chs" }, .{ h.span(.{ .class = "lab" }, .{W.chapters}), chs.done() }),
        })});
    }
};

pub const css =
    \\@layer components {
    \\  .c-learn { display: grid; gap: var(--sp-3); container: learn / inline-size; }
    \\  .c-learn > .strip { display: flex; align-items: center; gap: var(--sp-3); min-width: 0; }
    \\  .c-learn > .strip h1 { margin: 0; font-size: var(--fs-l); }
    \\  .c-learn > .strip .ct { color: var(--t2); font-size: var(--fs-s); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; }
    \\  .c-learn > .strip .meta { display: flex; gap: var(--sp-3); margin-left: auto; font-size: var(--fs-s); color: var(--muted);
    \\    font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-learn > .grid { display: grid; grid-template-columns: minmax(0, 1fr) 340px; gap: var(--sp-3); align-items: start; }
    \\  .c-learn .main { min-width: 0; }
    \\  .c-learn .path { display: grid; gap: var(--sp-3); }
    \\  .c-learn .duel { display: flex; align-items: center; gap: var(--sp-4) var(--sp-5); flex-wrap: wrap; }
    \\  .c-learn .who { display: flex; align-items: center; gap: var(--sp-3); }
    \\  .c-learn .who .nm { display: block; font-size: var(--fs-xl); font-weight: var(--w-b); }
    \\  .c-learn .vs { color: var(--faint); font-size: var(--fs-s); text-transform: uppercase; letter-spacing: 0.06em; }
    \\  .c-learn .vs3 { display: flex; gap: var(--sp-4); }
    \\  .c-learn .vs3 > span { display: grid; justify-items: center; gap: 2px; }
    \\  .c-learn .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: var(--sp-2); }
    \\  .c-learn .tile { display: grid; justify-items: center; gap: var(--sp-2); padding: var(--sp-3) var(--sp-2);
    \\    border-radius: var(--r-m); background: var(--bg); border: 1px solid var(--line); }
    \\  .c-learn .tile .h { display: flex; align-items: center; gap: 6px; font-size: var(--fs-s); font-weight: var(--w-m); }
    \\  .c-learn .tile .ics, .c-learn .chips { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\  .c-learn .tile .ics { flex-wrap: nowrap; align-items: flex-start; justify-content: center; gap: var(--sp-1); }
    \\  .c-learn .tile .ic { max-width: 64px; display: grid; justify-items: center; gap: 2px;
    \\    font-size: var(--fs-xs); line-height: 1.2; color: var(--t2); text-align: center; }
    \\  .c-learn > .grid > .main { scroll-margin-top: calc(var(--header) + var(--sp-3)); }
    \\  .c-learn .tile .sep { padding-top: 8px; font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-learn .lab { font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--faint); text-transform: uppercase; letter-spacing: 0.06em; }
    \\  .c-learn .tips, .c-learn .chs { display: grid; gap: var(--sp-2); }
    \\  .c-learn .ch { all: unset; display: grid; grid-template-columns: 22px minmax(0, 1fr) auto; gap: var(--sp-2); align-items: center;
    \\    min-height: 36px; padding: 0 var(--sp-2); border-radius: var(--r-ctl); color: var(--t2); font-size: var(--fs-s); cursor: pointer; }
    \\  .c-learn .ch[aria-current] { color: var(--text); font-weight: var(--w-m); background: var(--panel-2); }
    \\  .c-learn .ch .t { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-learn .ch .n, .c-learn .ch .p { font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; }
    \\  .c-learn .end { display: grid; gap: var(--sp-4); }
    \\  .c-learn .done-h { display: grid; justify-items: center; gap: var(--sp-2); text-align: center; }
    \\  .c-learn .done-h .k { font-size: var(--fs-xs); font-weight: var(--w-b); letter-spacing: 0.06em; text-transform: uppercase; color: var(--accent); }
    \\  .c-learn .done-h h2 { margin: 0; font-size: var(--fs-xl); }
    \\  .c-learn .tk { margin: 0; padding: 0; display: grid; gap: var(--sp-2); }
    \\  .c-learn .tk li { list-style: none; display: flex; justify-content: space-between; gap: var(--sp-3); padding: var(--sp-2) var(--sp-3);
    \\    border-radius: var(--r-m); background: var(--panel-2); }
    \\  .c-learn .end .foot { display: flex; justify-content: space-between; }
    \\  @container learn (max-width: 1000px) { .c-learn > .grid { grid-template-columns: minmax(0, 1fr); } }
    \\  @container learn (max-width: 760px) { .c-learn > .strip .ct { display: none; } }
    \\}
    \\
;

pub fn gallery(g: *@import("gallery.zig").Gallery) void {
    const h = g.h;
    if (shown(h.mem, &ld.demo, 1, 0, null)) |p| g.addFill("first visit: chapter 1, the mastery guess", p.view(h));
    if (shown(h.mem, &ld.demo, 1, 0, 55)) |p| g.addFill("mastery guess locked in: every band, 3.3 off", p.view(h));
    if (shown(h.mem, &ld.demo, 1, 1, null)) |p| g.addFill("counter duel", p.view(h));
    if (shown(h.mem, &ld.demo, 1, 1, 0)) |p| g.addFill("counter, a wrong pick revealed: each into Yone and against everyone", p.view(h));
    if (shown(h.mem, &ld.demo, 0, 0, null)) |p| g.addFill("chapter 0: role tiles", p.view(h));
    if (shown(h.mem, &counter_demo, 0, 0, null)) |p| g.addFill("chapter 0: counter tiles, one phrase each", p.view(h));
    if (shown(h.mem, &chips_demo, 0, 0, null)) |p| g.addFill("chips setup with a slider", p.view(h));
    if (shown(h.mem, &chips_demo, 0, 0, 60)) |p| g.addFill("chips setup revealed: the bands", p.view(h));
    if (shown(h.mem, &ld.demo, 1, 1, 1)) |p| {
        p.progress.set(h.mem, "know", 2) catch {
            h.oom = true;
        };
        p.end = true;
        g.addFill("chapter end", p.view(h));
    }
}

/// A page on chapter `c` puzzle `z`, answered with `answer` (a guess, or a pick's index)
fn shown(a: std.mem.Allocator, d: *const ld.Data, c: u8, z: u8, answer: ?f32) ?*Page {
    const p = a.create(Page) catch return null;
    p.* = .init(a, d);
    p.c = c;
    p.p = z;
    p.reset();
    if (answer) |x| {
        switch (p.cur().answer) {
            .guess => p.g.value = x,
            .pick => p.pick = @intFromFloat(x),
        }
        p.reveal();
    }
    return p;
}

const chips_demo: ld.Data = .{ .ddragon = "16.21.1", .start = 0, .chapters = &.{.{ .title = "Does a lead in lane win?", .puzzles = &.{.{
    .id = "fed",
    .q = "How often does your team win?",
    .ctx = "You: 1,000+ gold up at 14. The other four: behind",
    .setup = .{ .chips = .{ .champs = &.{}, .chips = &.{ "You +1,000 at 14", "Other four behind" } } },
    .answer = .{ .guess = .{ .lo = 20, .hi = 80, .real = 47.3, .tol = 2 } },
    .reveal = &.{
        .{ .label = "Other four", .sub = "3k+ behind", .v = 27.6, .games = 16_328 },
        .{ .label = "1.5-3k behind", .v = 46.6, .games = 18_349 },
        .{ .label = "1.5k+ ahead", .v = 89.1, .games = 56_450 },
    },
    .why = "A fed laner wins 68.6% overall, but that rides on the other four.",
    .tip = "Ahead in lane? Take your lead to where your team is losing.",
    .games = 59_796,
    .from = "Ranked solo, Platinum IV and up",
}} }} };

const testing = std.testing;

test "first visit on chapter 1; guess, lock in, pick by key and click, chapter end, next chapter" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var p: Page = .init(arena.allocator(), &ld.demo);
    try testing.expectEqual(@as(u8, 1), p.c);
    try testing.expectEqualStrings("know", p.cur().id);
    var ev: tree.Event = .{ .kind = .click };
    p.update(.lock, &ev);
    try testing.expect(!p.revealed);
    ev = .{ .kind = .pointerdown, .x = 75, .w = 100 };
    p.update(.guess, &ev);
    try testing.expectEqual(@as(?f32, 55), p.g.value);
    ev = .{ .kind = .keydown, .text = "Enter" };
    p.update(.guess, &ev);
    try testing.expect(p.revealed);
    try testing.expectEqual(@as(?u2, 1), p.progress.get("know"));
    try testing.expect(p.dirty);
    p.update(.next, &ev);
    try testing.expectEqualStrings("counter-top", p.cur().id);
    ev = .{ .kind = .keydown, .text = "1" };
    p.update(.key, &ev);
    p.update(.{ .choose = 1 }, &ev);
    try testing.expect(!p.revealed);
    ev = .{ .kind = .keydown, .text = "Enter" };
    p.update(.key, &ev);
    try testing.expect(p.revealed);
    try testing.expectEqual(@as(?u2, 3), p.progress.get("counter-top"));
    p.update(.next, &ev);
    try testing.expect(p.end);
    p.update(.next, &ev);
    try testing.expectEqual(@as(u8, 0), p.c);
    try testing.expect(!p.end);
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    _ = p.view(&h);
    try testing.expect(!h.oom);
}

test "a puzzle's link opens it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var p: Page = .init(arena.allocator(), &ld.demo);
    p.fromUrl(url.read(Page.Url, "#p=counter-top"));
    try testing.expectEqualStrings("counter-top", p.cur().id);
    try testing.expectEqualStrings("counter-top", p.toUrl().p.slice());
}

test "the island opens the linked puzzle" {
    const island = @import("island.zig");
    const Fake = @import("fakedom.zig").Fake;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var fake: Fake = .{ .a = a };
    try fake.fragment.appendSlice(a, "#p=counter-top");
    var rt: island.Runtime(Fake) = .init(a, &fake);
    var server: Page = .init(a, &ld.demo);
    var state: Page = .init(a, &ld.demo);
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    t.root = server.view(&h);
    fake.server = &t;
    _ = try rt.add(Page, &state, &server, sel);
    try testing.expectEqualStrings("counter-top", state.cur().id);
}

const counter_demo: ld.Data = .{ .ddragon = "16.21.1", .start = 0, .chapters = &.{.{ .title = "The basics", .puzzles = &.{.{
    .id = "basic-counter-mordekaiser-illaoi",
    .q = "Who wins this lane more often?",
    .ctx = "Illaoi against Mordekaiser, top lane",
    .setup = .{ .tiles = &.{
        .{ .title = "Top", .role = .top, .champs = &.{ ld.ch("Malphite", "Malphite"), ld.ch("Vayne", "Vayne") }, .sep = "into" },
        .{ .title = "Mid", .role = .mid, .champs = &.{ ld.ch("Yasuo", "Yasuo"), ld.ch("Akshan", "Akshan") }, .sep = "into" },
    } },
    .answer = .{ .pick = .{ .right = 1, .choices = &.{
        .{ .text = "Illaoi", .shown = "won 42%", .games = 1_965 },
        .{ .text = "Mordekaiser", .shown = "won 58%", .games = 1_965 },
    } } },
    .why = "Mordekaiser wins 58% of these games: a counter to Illaoi.",
    .tip = "A few matchups are lopsided: know the ones that beat your champion.",
    .games = 1_965,
    .from = "Ranked games, every region, all ranks, last 30 days; top lane games only",
}} }} };
