//! The Learn page: short lessons for new players with examples picked from this
//! patch's games, a three-question check each, and practice drafts (static/learn.js
//! fills those from learn/practice.json). Plain words first, numbers behind them; jargon
//! carries a glossary tip. Progress stays in the browser.
//!
//! Examples show raw win rates with n, not the draft model's points: at a few thousand
//! games the model's pair terms are still noise.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const matchup = @import("matchup.zig");
const learn = @import("../learn.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const Counts = core.statsfile.Counts;
const score = core.score;
const curvesfile = core.curvesfile;
const Site = root.Site;
const Champ = root.Champ;

/// Pairs (matchups, duos) with fewer games are not used as examples
const min_pair_games = 20;
/// Game length examples need this many games in both the short and the long bucket
const min_length_games = 40;
/// Pseudo-games pulling a length bucket's win rate toward the champion's own
const length_prior = 30;
/// A champion counts as a role's own above this share of its games
const role_share = 0.85;
/// Below this many games on the patch the lessons say the examples are early
const early_games = 50_000;
const mastery_source = "https://old.reddit.com/r/leagueoflegends/comments/130ucfb/" ++
    "champion_mastery_a_statistical_analysis_of_1m/";

const Term = struct { []const u8, []const u8 };

/// Shown on hover or focus wherever the word appears; learn.js gets the same list
pub const glossary = [_]Term{
    .{ "lane", "One of three paths to the enemy base: top, middle (mid) and bottom (bot). " ++
        "Jungle is the area between them." },
    .{ "cs", "Creep score: minions and jungle monsters killed. Each one gives gold, so CS " ++
        "is most of a laner's income." },
    .{ "xp", "Experience. It levels your champion up; level 6 unlocks the ultimate ability." },
    .{ "gold", "Earned from CS, kills and objectives, and spent on items. More gold means " ++
        "stronger items." },
    .{ "spike", "A moment a champion gets much stronger, often at level 6 or on finishing " ++
        "an item." },
    .{ "scaling", "How much stronger a champion gets as the game goes on. Champions that " ++
        "scale well are strongest late." },
    .{ "counter", "A champion that tends to do well against another one, usually in the " ++
        "same lane." },
    .{ "points", "Percentage points of win chance: +2 points turns a 50% chance into 52%." },
    .{ "patch", "Riot's balance update, about every two weeks. The numbers here come from " ++
        "the current one." },
    .{ "magic", "Damage from abilities of mages and some others. Reduced by magic resist." },
    .{ "physical", "Damage from basic attacks and most fighters and marksmen. Reduced by " ++
        "armour." },
    .{ "armour", "A stat that reduces physical damage. Items with armour cost gold that is " ++
        "then not spent on damage." },
    .{ "mastery", "Riot's count of how much you have played a champion." },
    .{ "duo", "Two champions on the same team, for example bot and support, who play near " ++
        "each other." },
};

fn tip(comptime key: []const u8) []const u8 {
    inline for (glossary) |t| {
        if (comptime std.mem.eql(u8, t[0], key)) return t[1];
    }
    @compileError("no glossary entry " ++ key);
}

const term_html = "<dfn class=\"term\" tabindex=\"0\" data-tip=\"{tip}\">{text}</dfn>";
const Dfn = tpl.Template(term_html, struct { tip: []const u8, text: []const u8 });

/// `text` with a tip for glossary entry `key`, for a template hole
fn term(comptime key: []const u8, text: []const u8) Dfn {
    return .{ .args = .{ .tip = tip(key), .text = text } };
}

const Choice = struct { t: []const u8, id: ?u32 = null };
const Question = struct { q: []const u8, choices: []const Choice, answer: usize, why: []const u8 };

const Ctx = struct {
    site: *const Site,
    facts: *const learn.Facts,
    a: std.mem.Allocator,

    fn print(ctx: Ctx, comptime fmt: []const u8, args: anytype) ![]const u8 {
        return ctx.a.print(fmt, args);
    }

    fn choice(ch: Champ) Choice {
        return .{ .t = ch.name, .id = ch.id };
    }
};

fn rate(n: Counts) f64 {
    if (n.games == 0) return 0;
    return @as(f64, @floatFromInt(n.wins)) / @as(f64, @floatFromInt(n.games));
}

fn champ(w: *Writer, ctx: Ctx, ch: Champ) !void {
    try ctx.site.champLink(w, ch, "");
}

fn pctOf(n: Counts) u32 {
    return @intFromFloat(@round(100 * rate(n)));
}

pub fn write(site: *const Site, w: *Writer, facts: *const learn.Facts) !void {
    const a = site.arena;
    const p = site.sharedPage(
        "Learn to draft | meiolol",
        "Short lessons for new League of Legends players, with examples from real ranked " ++
            "games, and practice drafts with every option explained.",
        .learn,
    );
    try html.head(w, p);
    try w.writeAll(
        \\<h1>Learn to draft</h1>
        \\<p class="lead">Five short lessons, then practice on real ranked drafts. One step at
        \\a time.</p>
        \\<div class="learn-tabs" role="tablist" hidden><button type="button" role="tab"
        \\data-view="lessons">Lessons <span id="t-lessons"></span></button><button type="button"
        \\role="tab" data-view="practice">Practice <span id="t-practice"></span></button></div>
        \\<section id="lessons" data-view="lessons">
        \\<h2 class="nojs">Lessons</h2>
        \\<ol id="lesson-dots" class="dots" hidden></ol>
        \\
    );
    if (site.games < early_games) try tpl.render(w,
        \\<p class="note">Early data: {games} games on patch {patch} so far, so some examples
        \\are chance.</p>
        \\
    , .{ .games = site.games, .patch = site.patch });
    try w.writeAll("<div class=\"lessons\">\n");
    const ctx: Ctx = .{ .site = site, .facts = facts, .a = a };
    const Lesson = struct {
        key: []const u8,
        title: []const u8,
        sub: []const u8,
        body: *const fn (Ctx, *Writer) anyerror![]const Question,
    };
    const lessons = [_]Lesson{
        .{ .key = "roles", .title = "Roles", .sub = "Five jobs on every team", .body = roles },
        .{
            .key = "counters",
            .title = "Counters",
            .sub = "And your own champion",
            .body = counters,
        },
        .{ .key = "timing", .title = "Early and late", .sub = "Who is strong when", .body = timing },
        .{ .key = "damage", .title = "Mixing damage", .sub = "Magic and physical", .body = damage },
        .{ .key = "synergy", .title = "Synergy", .sub = "Champions that work together", .body = synergy },
    };
    var checks: std.json.ArrayHashMap([]const Question) = .{};
    for (lessons, 1..) |l, i| {
        try tpl.renderPart(w,
            \\<article class="card lesson" id="lesson-{key}" data-lesson="{key}">
            \\<h2 class="lesson-head"><span class="lesson-n">{n}</span><span>{title}
            \\<span class="muted">{sub}</span></span></h2>
            \\<div class="lesson-body">
            \\
        , .{ .key = l.key, .n = i, .title = l.title, .sub = l.sub });
        const qs = try l.body(ctx, w);
        try tpl.renderPart(w,
            \\</div>
            \\<div class="check" data-lesson="{key}"></div>
            \\<div class="lesson-nav"></div>
            \\</article>
            \\
        , .{ .key = l.key });
        try checks.map.put(a, l.key, qs);
    }
    try w.writeAll("</div>\n</section>\n");
    try practiceSection(w);
    var terms: std.json.ArrayHashMap([]const u8) = .{};
    for (glossary) |t| try terms.map.put(a, t[0], t[1]);
    try tpl.render(w,
        \\<script type="application/json" id="checks">{checks}</script>
        \\<script type="application/json" id="glossary">{terms}</script>
        \\<script src="reasons.js" defer></script>
        \\<script src="learn.js" defer></script>
        \\
    , .{ .checks = tpl.json(checks), .terms = tpl.json(terms) });
    try html.foot(w, p);
}

fn practiceSection(w: *Writer) !void {
    try w.writeAll(
        \\<section id="practice" data-view="practice">
        \\<h2 class="nojs">Practice drafts</h2>
        \\<p class="muted">A real ranked game with your slot open. Pick one of four, then see
        \\what each brings. Several can fit.</p>
        \\<div id="p-levels" class="levels" role="group" aria-label="Level"></div>
        \\<div id="p-bar" class="stepbar" aria-hidden="true"></div>
        \\<details class="p-settings"><summary>Role and your champions</summary>
        \\<div class="practice-setup">
        \\<div class="setup-row"><span class="setup-label" id="p-roles-label">Your role</span>
        \\<div id="p-roles" class="seg" role="group" aria-labelledby="p-roles-label"></div></div>
        \\<div class="setup-row"><label class="setup-label" for="p-pool-input">Champions you play</label>
        \\<div class="own-pool"><input id="p-pool-input" list="p-champions"
        \\placeholder="Add a champion" autocomplete="off"><datalist id="p-champions"></datalist>
        \\<span id="p-pool" class="chips"></span></div></div>
        \\<p class="muted small">Optional: yours then turn up among the options when they fit.</p>
        \\</div></details>
        \\<p id="p-status" class="note">Loading…</p>
        \\<div id="drill" hidden>
        \\<p id="p-about" class="muted small"></p>
        \\<div class="board">
        \\<div class="card side-0"><h3 id="p-side-0"></h3><ol id="p-team-0" class="team"></ol>
        \\<p class="bans" id="p-bans-0"></p></div>
        \\<div class="card side-1"><h3 id="p-side-1"></h3><ol id="p-team-1" class="team"></ol>
        \\<p class="bans" id="p-bans-1"></p></div>
        \\</div>
        \\<section class="card question">
        \\<h2 id="p-question" tabindex="-1"></h2>
        \\<div id="p-hints" class="hints"></div>
        \\<div id="p-options" class="choices"></div>
        \\</section>
        \\<section id="p-reveal" hidden>
        \\<h2 id="p-reveal-title" tabindex="-1"></h2>
        \\<ul id="p-notes" class="card notes"></ul>
        \\<p id="p-real" class="muted small"></p>
        \\<p id="p-done" class="note level-done" hidden></p>
        \\<p><button type="button" id="p-next" class="primary">Next draft</button></p>
        \\<p class="muted small">From this patch's ranked games: how drafts like this tend to
        \\go, not what anyone should pick.</p>
        \\</section>
        \\</div>
        \\</section>
        \\
    );
}

fn champLinks(w: *Writer, ctx: Ctx, list: []const Champ) !void {
    try w.writeAll("<span class=\"champ-row\">");
    for (list) |ch| try champ(w, ctx, ch);
    try w.writeAll("</span>");
}

fn mainRole(st: *const core.Stats, c: usize) struct { Role, f64 } {
    var best: Role = .top;
    var total: u64 = 0;
    for (Role.all) |r| {
        const g = st.champRole(r, c).games;
        total += g;
        if (g > st.champRole(best, c).games) best = r;
    }
    if (total == 0) return .{ best, 0 };
    const games: f64 = @floatFromInt(st.champRole(best, c).games);
    return .{ best, games / @as(f64, @floatFromInt(total)) };
}

const role_jobs = [_][]const u8{
    "alone in the top lane, often a tough fighter.",
    "roams between the lanes and helps where it can.",
    "the middle lane, close to both others. Often a mage or assassin.",
    "the bot lane's damage, usually a marksman who is strong late.",
    "shares bot lane: protects, places vision, starts fights.",
};

/// The `n` champions with most games in `r`, most first
fn mostPlayed(ctx: Ctx, r: Role, comptime n: usize) ![]Champ {
    const st = &ctx.site.stats;
    var top: [n]?Champ = @splat(null);
    for (ctx.site.champs) |ch| {
        const g = st.champRole(r, ch.c).games;
        if (g == 0) continue;
        for (&top, 0..) |*slot, i| {
            if (slot.* == null or g > st.champRole(r, slot.*.?.c).games) {
                var j: usize = n - 1;
                while (j > i) : (j -= 1) top[j] = top[j - 1];
                slot.* = ch;
                break;
            }
        }
    }
    var list: std.ArrayList(Champ) = .empty;
    for (top) |t| if (t) |ch| try list.append(ctx.a, ch);
    return list.items;
}

fn roles(ctx: Ctx, w: *Writer) ![]const Question {
    const site = ctx.site;
    const st = &site.stats;
    try tpl.renderPart(w,
        \\<p>Five players, one per role, each with a place on the map. You face the enemy in your
        \\{lane}.</p>
        \\<ul class="roles">
        \\
    , .{ .lane = term("lane", "lane") });
    for (Role.all, role_jobs) |r, job| {
        try tpl.render(w,
            \\<li><b>{role}</b>: {job} {champs}</li>
            \\
        , .{
            .role = root.roleName(r),
            .job = job,
            .champs = tpl.call(champLinks, .{ ctx, try mostPlayed(ctx, r, 3) }),
        });
    }
    try w.writeAll("</ul>\n");

    var qs: std.ArrayList(Question) = .empty;
    const asked = [_]Role{ .jungle, .utility, .top };
    for (asked) |want| {
        var best: ?Champ = null;
        var best_share: f64 = 0;
        for (site.champs) |ch| {
            const r, const share = mainRole(st, ch.c);
            if (r != want or share < role_share) continue;
            if (best != null and st.champRole(r, ch.c).games <= st.champRole(r, best.?.c).games) continue;
            best = ch;
            best_share = share;
        }
        const ch = best orelse continue;
        var choices: std.ArrayList(Choice) = .empty;
        for (Role.all) |r| try choices.append(ctx.a, .{ .t = root.roleName(r) });
        try qs.append(ctx.a, .{
            .q = try ctx.print("Which role is {s} played in most?", .{ch.name}),
            .choices = choices.items,
            .answer = @backingInt(want),
            .why = try ctx.print("{s}: {d:.0}% of {s}'s games this patch.", .{
                root.roleName(want), 100 * best_share, ch.name,
            }),
        });
    }
    return qs.items;
}

const Pair = struct { x: Champ, y: Champ, r: Role, yr: Role, pp: f64, n: Counts };

/// Lane matchups with enough games, the clearest first, each from the side that does
/// better. Ranked by the model's smoothed edge, which keeps thin pairs from the top.
fn lanePairs(ctx: Ctx) ![]Pair {
    const site = ctx.site;
    const st = &site.stats;
    var list: std.ArrayList(Pair) = .empty;
    for (Role.all) |r| {
        for (site.champs, 0..) |x, i| {
            for (site.champs[i + 1 ..]) |y| {
                const n = st.enemy(r, r, x.c, y.c);
                if (n.games < min_pair_games) continue;
                const pp = score.matchupPp(st, site.score_opts, r, x.c, r, y.c);
                const flipped: Counts = .{ .games = n.games, .wins = n.games - n.wins };
                try list.append(ctx.a, if (pp >= 0)
                    .{ .x = x, .y = y, .r = r, .yr = r, .pp = pp, .n = n }
                else
                    .{ .x = y, .y = x, .r = r, .yr = r, .pp = -pp, .n = flipped });
            }
        }
    }
    std.mem.sort(Pair, list.items, {}, byPp);
    return list.items;
}

fn byPp(_: void, p: Pair, q: Pair) bool {
    return p.pp > q.pp;
}

fn counters(ctx: Ctx, w: *Writer) ![]const Question {
    const st = &ctx.site.stats;
    const pairs = try lanePairs(ctx);
    try tpl.render(w,
        \\<p>A {counter} tends to beat another champion, usually in the same lane.</p>
        \\
    , .{ .counter = term("counter", "counter") });
    if (pairs.len > 0) {
        const p = pairs[0];
        try tpl.render(w,
            \\<p class="example">{x} won {pct}% of {games} games against {y} in {lane} lane this
            \\patch (usually {x_pct}% and {y_pct}%).</p>
            \\
        , .{
            .x = tpl.call(champ, .{ ctx, p.x }),
            .pct = pctOf(p.n),
            .games = p.n.games,
            .y = tpl.call(champ, .{ ctx, p.y }),
            .lane = root.roleName(p.r),
            .x_pct = pctOf(st.champRole(p.r, p.x.c)),
            .y_pct = pctOf(st.champRole(p.r, p.y.c)),
        });
    }
    try tpl.render(w,
        \\<p><b>Your own champion matters more.</b> New to a champion (under 10,000 {mastery}
        \\points), players win about 44%; once they know it, 51.5%. Most counters move it 2 to 4
        \\{points}. <a href="{source}" rel="noopener">Source</a> (1M+ ranked games).</p>
        \\
    , .{ .mastery = term("mastery", "mastery"), .points = term("points", "points"), .source = mastery_source });

    var qs: std.ArrayList(Question) = .empty;
    if (pairs.len >= 3) {
        for (pairs[1..3], 0..) |p, i| {
            // Alternate which side is listed first so the answer is not always the first
            const two = [2]Choice{ Ctx.choice(p.x), Ctx.choice(p.y) };
            const choices = if (i == 0) two else .{ two[1], two[0] };
            try qs.append(ctx.a, .{
                .q = try ctx.print("{s} lane: which tends to do better, {s} or {s}?", .{
                    root.roleName(p.r), choices[0].t, choices[1].t,
                }),
                .choices = try ctx.a.dupe(Choice, &choices),
                .answer = i,
                .why = try ctx.print("{s} won {d}% of {d} games against {s} this patch.", .{
                    p.x.name, pctOf(p.n), p.n.games, p.y.name,
                }),
            });
        }
    }
    try qs.insert(ctx.a, @min(qs.items.len, 1), .{
        .q = "You have played one champion for 100 games. The enemy laner is a champion " ++
            "it is a little weak against. At most ranks, what tends to matter more?",
        .choices = try ctx.a.dupe(Choice, &.{
            .{ .t = "Playing the champion you know" },
            .{ .t = "Switching to a counter you have never played" },
        }),
        .answer = 0,
        .why = "Players new to a champion win about 44% against 51.5% once they know it: " ++
            "a bigger gap than most counters.",
    });
    return qs.items;
}

const Timing = struct {
    ch: Champ,
    r: Role,
    n: [learn.lengths]Counts,
    /// Long minus short win rate, each smoothed toward the champion's own
    diff: f64,
};

/// Champions in their main role with enough short and long games, the most
/// late-leaning first
fn timings(ctx: Ctx) ![]Timing {
    const st = &ctx.site.stats;
    const last = learn.lengths - 1;
    var list: std.ArrayList(Timing) = .empty;
    for (ctx.site.champs) |ch| {
        const r, _ = mainRole(st, ch.c);
        const n = ctx.facts.champs[ch.c].length[@backingInt(r)];
        if (n[0].games < min_length_games or n[last].games < min_length_games) continue;
        var all: Counts = .{ .games = 0, .wins = 0 };
        for (n) |b| {
            all.games += b.games;
            all.wins += b.wins;
        }
        const smooth = struct {
            fn f(b: Counts, base: f64) f64 {
                return (@as(f64, @floatFromInt(b.wins)) + length_prior * base) /
                    (@as(f64, @floatFromInt(b.games)) + length_prior);
            }
        }.f;
        try list.append(ctx.a, .{
            .ch = ch,
            .r = r,
            .n = n,
            .diff = smooth(n[last], rate(all)) - smooth(n[0], rate(all)),
        });
    }
    std.mem.sort(Timing, list.items, {}, struct {
        fn f(_: void, p: Timing, q: Timing) bool {
            return p.diff > q.diff;
        }
    }.f);
    return list.items;
}

fn lengthLabel(b: usize) []const u8 {
    return switch (b) {
        0 => "Under 25 min",
        1 => "25 to 32 min",
        else => "32 min or more",
    };
}

fn lengthBars(w: *Writer, ctx: Ctx, t: Timing) !void {
    try tpl.renderPart(w, "<div class=\"lenbars\"><div class=\"lenbars-head\">{champ} <span class=\"muted\">{role}</span></div>\n", .{
        .champ = tpl.call(champ, .{ ctx, t.ch }),
        .role = root.roleName(t.r),
    });
    for (t.n, 0..) |n, b| {
        const p = pctOf(n);
        // Bars start at 30% so differences around 50% are visible
        const width = (std.math.clamp(p, 30, 70) - 30) * 100 / 40;
        try tpl.render(w,
            \\<div class="lenbar"><span>{label}</span><span class="bar"><i style="width:{width}%"{up}></i>
            \\</span><span class="num">{p}% of {games}</span></div>
            \\
        , .{
            .label = lengthLabel(b),
            .width = width,
            .up = tpl.flag(p >= 50, "class=\"up\""),
            .p = p,
            .games = n.games,
        });
    }
    try w.writeAll("</div>\n");
}

fn timing(ctx: Ctx, w: *Writer) ![]const Question {
    const list = try timings(ctx);
    try tpl.render(w,
        \\<p>Some champions {spike} early; others {scale} and are strongest late.</p>
        \\
    , .{ .spike = term("spike", "spike"), .scale = term("scaling", "scale") });
    if (list.len >= 2) {
        const late = list[0];
        const early = list[list.len - 1];
        try tpl.render(w,
            \\<p>Win rate by game length this patch:</p>
            \\<div class="grid">
            \\{late_bars}{early_bars}</div>
            \\
        , .{
            .late_bars = tpl.call(lengthBars, .{ ctx, late }),
            .early_bars = tpl.call(lengthBars, .{ ctx, early }),
        });
    }
    if (ctx.site.curves) |*c| try laneExample(ctx, w, c);

    var qs: std.ArrayList(Question) = .empty;
    if (list.len >= 6) {
        const Ask = struct { late: Timing, early: Timing, long: bool };
        const asks = [_]Ask{
            .{ .late = list[1], .early = list[list.len - 2], .long = true },
            .{ .late = list[2], .early = list[list.len - 3], .long = false },
        };
        for (asks, 0..) |q, i| {
            // The second question lists the early champion first
            const first, const second = if (i == 0) .{ q.late, q.early } else .{ q.early, q.late };
            const winner = if (q.long) q.late else q.early;
            const b: usize = if (q.long) learn.lengths - 1 else 0;
            try qs.append(ctx.a, .{
                .q = if (q.long)
                    "Which wins more of its long games (32 minutes or more)?"
                else
                    "Which wins more of its short games (under 25 minutes)?",
                .choices = try ctx.a.dupe(Choice, &.{ Ctx.choice(first.ch), Ctx.choice(second.ch) }),
                .answer = if (winner.ch.id == first.ch.id) 0 else 1,
                .why = try ctx.print("{s} {d}% of {d} games, {s} {d}% of {d}.", .{
                    first.ch.name,  pctOf(first.n[b]),  first.n[b].games,
                    second.ch.name, pctOf(second.n[b]), second.n[b].games,
                }),
            });
        }
    }
    try qs.append(ctx.a, .{
        .q = "A champion that \"scales well\" is…",
        .choices = try ctx.a.dupe(Choice, &.{
            .{ .t = "Strongest late in the game" },
            .{ .t = "Strongest in the first few minutes" },
            .{ .t = "Good against one particular champion" },
        }),
        .answer = 0,
        .why = "Scaling means growing stronger with levels and items, so the champion is at " ++
            "its best late.",
    });
    return qs.items;
}

/// The lane with the biggest typical gold lead at lane_minute, from enough games
fn laneExample(ctx: Ctx, w: *Writer, c: *const curvesfile.Curves) !void {
    const Best = struct { x: Champ, y: Champ, r: Role, gold: i16, v: curvesfile.View };
    var best: ?Best = null;
    for (c.curves) |cv| {
        const h = cv.header;
        if (h.bracket != @backingInt(curvesfile.Bracket.all) or h.a == h.b) continue;
        if (h.games < matchup.thin_games) continue;
        const x = matchup.champ(ctx.site, h.a) orelse continue;
        const y = matchup.champ(ctx.site, h.b) orelse continue;
        const r: Role = @fromBackingInt(@intCast(h.role));
        const v = c.get(r, .all, x.id, y.id).?;
        const m = v.minute(curvesfile.lane_minute - 1);
        if (m.n < h.games / 2) continue;
        if (best != null and @abs(m.gold.p50) <= @abs(best.?.gold)) continue;
        best = .{ .x = x, .y = y, .r = r, .gold = m.gold.p50, .v = v };
    }
    const b = best orelse return;
    const ahead, const behind = if (b.gold >= 0) .{ b.x, b.y } else .{ b.y, b.x };
    const x_wins: Counts = .{ .games = b.v.games(), .wins = b.v.wins() };
    const ahead_win = if (b.gold >= 0) rate(x_wins) else 1 - rate(x_wins);
    try tpl.render(w,
        \\<p class="example">{lane} lane: {ahead} is typically {lead} {gold} ahead of {behind} at
        \\{minute} minutes and wins {win:.0}% of {games} games. <a href="{href}">The lane</a></p>
        \\
    , .{
        .ahead = tpl.call(champ, .{ ctx, ahead }),
        .lead = @abs(b.gold),
        .gold = term("gold", "gold"),
        .behind = tpl.call(champ, .{ ctx, behind }),
        .minute = curvesfile.lane_minute,
        .lane = root.roleName(b.r),
        .win = 100 * ahead_win,
        .games = b.v.games(),
        .href = try matchup.path(ctx.a, b.r, ahead, behind),
    });
}

fn mixName(b: usize) []const u8 {
    return switch (b) {
        0 => "Mostly physical (under 30% magic)",
        1 => "Mixed",
        else => "Mostly magic (70% or more)",
    };
}

fn magicPct(ctx: Ctx, ch: Champ) u32 {
    return @intFromFloat(@round(100 * ctx.facts.champs[ch.c].magic.?));
}

/// Champions mainly played in `r` whose magic share is within [lo, hi], most played
/// first, leaving out `skip`
fn byDamage(ctx: Ctx, r: Role, lo: f64, hi: f64, skip: []const Champ) ![]Champ {
    const st = &ctx.site.stats;
    var list: std.ArrayList(Champ) = .empty;
    outer: for (ctx.site.champs) |ch| {
        const m = ctx.facts.champs[ch.c].magic orelse continue;
        if (m < lo or m > hi) continue;
        const main, _ = mainRole(st, ch.c);
        if (main != r) continue;
        for (skip) |s| if (s.id == ch.id) continue :outer;
        try list.append(ctx.a, ch);
    }
    std.mem.sort(Champ, list.items, r, struct {
        fn f(role: Role, p: Champ, q: Champ) bool {
            _ = role;
            return p.games > q.games;
        }
    }.f);
    return list.items;
}

fn damage(ctx: Ctx, w: *Writer) ![]const Question {
    try tpl.render(w,
        \\<p>{physical} is blocked by {armour}, {magic} by magic resist. A team with one kind is
        \\easy to defend against.</p>
        \\
    , .{
        .physical = term("physical", "Physical damage"),
        .armour = term("armour", "armour"),
        .magic = term("magic", "magic damage"),
    });
    var total: u32 = 0;
    for (ctx.facts.mix) |m| total += m.games;
    if (total > 0) {
        try w.writeAll(
            \\<div class="table-scroll"><table class="mix"><thead><tr><th>Team damage</th>
            \\<th class="num">Win rate</th><th class="num">Teams</th></tr></thead><tbody>
            \\
        );
        for (ctx.facts.mix, 0..) |m, b| {
            try tpl.render(w,
                \\<tr{thin}><td>{name}</td><td class="num">{p}%</td><td class="num">{games}</td></tr>
                \\
            , .{
                .thin = tpl.flag(m.games < 200, "class=\"thin\""),
                .name = mixName(b),
                .p = pctOf(m),
                .games = m.games,
            });
        }
        try w.writeAll(
            \\</tbody></table></div>
            \\<p class="muted small">Teams this patch by their champions' usual magic share; under
            \\200 teams greyed out.</p>
            \\
        );
    }

    // Mid laners for the options, and one physical teammate per other role
    const mid_magic = try byDamage(ctx, .middle, 0.85, 1, &.{});
    const mid_physical = try byDamage(ctx, .middle, 0, 0.15, &.{});
    var team: std.ArrayList(Champ) = .empty;
    for ([_]Role{ .top, .jungle, .bottom, .utility }) |r| {
        const list = try byDamage(ctx, r, 0, 0.3, &.{});
        if (list.len > 0) try team.append(ctx.a, list[0]);
    }
    if (mid_magic.len > 0 and mid_physical.len > 0) {
        try tpl.render(w, "<p>Magic mids: {magic}<br>Physical mids: {physical}</p>\n", .{
            .magic = tpl.call(champLinks, .{ ctx, mid_magic[0..@min(mid_magic.len, 4)] }),
            .physical = tpl.call(champLinks, .{ ctx, mid_physical[0..@min(mid_physical.len, 4)] }),
        });
    }

    var qs: std.ArrayList(Question) = .empty;
    if (mid_magic.len < 3 or mid_physical.len < 3) return qs.items;
    const m = mid_magic;
    const p = mid_physical;
    try qs.append(ctx.a, .{
        .q = "Which of these deals mostly magic damage?",
        .choices = try ctx.a.dupe(Choice, &.{ Ctx.choice(p[0]), Ctx.choice(m[1]), Ctx.choice(p[1]) }),
        .answer = 1,
        .why = try ctx.print("{d}% of {s}'s damage to champions is magic.", .{
            magicPct(ctx, m[1]), m[1].name,
        }),
    });
    try qs.append(ctx.a, .{
        .q = "Which of these deals mostly physical damage?",
        .choices = try ctx.a.dupe(Choice, &.{ Ctx.choice(p[2]), Ctx.choice(m[2]), Ctx.choice(m[0]) }),
        .answer = 0,
        .why = try ctx.print("Only {d}% of {s}'s damage to champions is magic.", .{
            magicPct(ctx, p[2]), p[2].name,
        }),
    });
    if (team.items.len == 4) {
        const t = team.items;
        try qs.append(ctx.a, .{
            .q = try ctx.print(
                "Your teammates are {s}, {s}, {s} and {s}: all mostly physical. You are mid. " ++
                    "Which pick adds magic damage?",
                .{ t[0].name, t[1].name, t[2].name, t[3].name },
            ),
            .choices = try ctx.a.dupe(Choice, &.{ Ctx.choice(p[0]), Ctx.choice(p[1]), Ctx.choice(m[0]) }),
            .answer = 2,
            .why = try ctx.print(
                "{s} deals {d}% magic damage, so the enemy cannot answer your whole team " ++
                    "with armour.",
                .{ m[0].name, magicPct(ctx, m[0]) },
            ),
        });
    }
    return qs.items;
}

/// Ally pairs with enough games, the clearest first (by the model's smoothed edge)
fn duoPairs(ctx: Ctx) ![]Pair {
    const site = ctx.site;
    const st = &site.stats;
    var list: std.ArrayList(Pair) = .empty;
    for (Role.all, 0..) |r, ri| {
        for (Role.all[ri + 1 ..]) |yr| {
            for (site.champs) |x| {
                if (st.champRole(r, x.c).games < min_pair_games) continue;
                for (site.champs) |y| {
                    if (x.c == y.c) continue;
                    const n = st.ally(r, yr, x.c, y.c);
                    if (n.games < min_pair_games) continue;
                    const pp = score.duoPp(st, site.score_opts, r, x.c, yr, y.c);
                    try list.append(ctx.a, .{ .x = x, .y = y, .r = r, .yr = yr, .pp = pp, .n = n });
                }
            }
        }
    }
    std.mem.sort(Pair, list.items, {}, byPp);
    return list.items;
}

fn duoName(ctx: Ctx, p: Pair) ![]const u8 {
    return ctx.print("{s} ({s}) with {s} ({s})", .{
        p.x.name, root.roleName(p.r), p.y.name, root.roleName(p.yr),
    });
}

fn synergy(ctx: Ctx, w: *Writer) ![]const Question {
    const duos = try duoPairs(ctx);
    try tpl.render(w,
        \\<p>Some champions win more together, most of all neighbours: a bot and support {duo},
        \\or jungle and a lane.</p>
        \\
    , .{ .duo = term("duo", "duo") });
    if (duos.len >= 3) {
        try w.writeAll(
            \\<p>Pairs that win most together this patch:</p>
            \\<ul class="duos">
            \\
        );
        for (duos[0..3]) |p| {
            try tpl.render(w,
                \\<li>{x}<span class="muted">{x_role}</span> + {y}<span class="muted">{y_role}</span>
                \\<span class="num">won {p}% of {games} games together</span></li>
                \\
            , .{
                .x = tpl.call(champ, .{ ctx, p.x }),
                .x_role = root.roleName(p.r),
                .y = tpl.call(champ, .{ ctx, p.y }),
                .y_role = root.roleName(p.yr),
                .p = pctOf(p.n),
                .games = p.n.games,
            });
        }
        try w.writeAll("</ul>\n");
    }

    var qs: std.ArrayList(Question) = .empty;
    // Each of the three pairs shown against two of the three weakest
    if (duos.len < 6) return qs.items;
    const weak = duos[duos.len - 3 ..];
    for (0..3) |i| {
        const good = duos[i];
        var choices: [3]Choice = .{
            .{ .t = try duoName(ctx, weak[i]) },
            .{ .t = try duoName(ctx, weak[(i + 1) % 3]) },
            .{ .t = try duoName(ctx, good) },
        };
        // Rotated left by i so the answer moves around: it ends up at 2 - i
        std.mem.rotate(Choice, &choices, i);
        try qs.append(ctx.a, .{
            .q = "Which pair tends to win more together?",
            .choices = try ctx.a.dupe(Choice, &choices),
            .answer = 2 - i,
            .why = try ctx.print("{s}: won {d}% of {d} games together this patch.", .{
                try duoName(ctx, good), pctOf(good.n), good.n.games,
            }),
        });
    }
    return qs.items;
}
