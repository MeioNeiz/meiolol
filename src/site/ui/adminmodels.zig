//! AdminModels: the admin page's Models tab, an island of its own below AdminOps
//! (ui-adminmodels.wasm, which fetches models.bin and training/training.bin once the tab
//! shows; ui.modelsdata). Views: All, a card per learned.md category; Win, the daily eval
//! read into sentences, run by run, each model against the shipped one and the report;
//! Early, the team effects per outcome; the other categories, learned.md and run
//! findings; Draft, a link to the tester
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const card = @import("card.zig");
const segmented = @import("segmented.zig");
const delta = @import("delta.zig");
const prose = @import("prose.zig");
const timechart = @import("timechart.zig");
const Gallery = @import("gallery.zig").Gallery;
const md = @import("modelsdata.zig");
const ad = @import("admindata.zig");
const ap = @import("adminpage.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Text = tree.Text;

pub const name = "AdminModels";
pub const scope = .{".c-admodels"};
pub const sel = "[data-island=adminmodels]";

pub const View = enum { all, win, draft, early, items, objectives, playstyle, player, data };
const views = [_]View{ .all, .win, .draft, .early, .items, .objectives, .playstyle, .player, .data };
const cats = [_]md.Cat{ .win, .early, .items, .objectives, .playstyle, .player, .data };

const view_names: std.EnumArray(View, Text) = .init(.{
    .all = plain("All"),
    .win = plain("Win (draft)"),
    .draft = plain("Draft tester"),
    .early = plain("Early game"),
    .items = plain("Items"),
    .objectives = plain("Objectives"),
    .playstyle = plain("Playstyle"),
    .player = plain("Player"),
    .data = plain("Data quality"),
});

fn catOf(v: View) ?md.Cat {
    return switch (v) {
        .all, .draft => null,
        inline else => |t| @field(md.Cat, @tagName(t)),
    };
}

fn viewOf(c: md.Cat) View {
    return switch (c) {
        inline else => |t| @field(View, @tagName(t)),
    };
}

/// The tester's page (admin.js PRIVATE until T6)
const tester_href = "/private";

/// meiolol-lab's targets; short: the outcome pick's label
const Outcome = struct { key: []const u8, label: []const u8, short: []const u8, cat: md.Cat };
const outcomes = [_]Outcome{
    .{ .key = "win", .label = "Win", .short = "Win", .cat = .win },
    .{ .key = "gold14", .label = "Gold at 14 min", .short = "Gold", .cat = .early },
    .{ .key = "lanediff14", .label = "Lane gold lead at 14 min", .short = "Lane lead", .cat = .early },
    .{ .key = "cs10", .label = "CS at 10 min", .short = "CS", .cat = .early },
    .{ .key = "deaths15", .label = "Deaths before 15 min", .short = "Deaths", .cat = .early },
    .{ .key = "first_item", .label = "First finished item", .short = "First item", .cat = .early },
};

fn outcomeOf(key: []const u8) ?Outcome {
    for (outcomes) |o| if (std.mem.eql(u8, o.key, key)) return o;
    return null;
}

fn outcomeLabel(key: []const u8) []const u8 {
    return if (outcomeOf(key)) |o| o.label else key;
}

/// Log loss of a coin flip, and of published draft-only models (docs/model.md "Method":
/// ~55-57% right)
const ll_coin = 0.6931;
const ll_published = 0.687;

pub const Models = struct {
    tab: ap.Tab = .overview,
    cat: View = .all,
    /// Early: an index into the team effects' outcomes; null for lane gold, else the first
    outcome: ?u8 = null,
    /// The wasm's
    models: ?*const md.Models = null,
    training: ?*const md.Training = null,
    models_failed: bool = false,
    training_failed: bool = false,
    /// Win: run by run, top-10% picks
    times: [2]timechart.Time = @splat(.{ .label = .{ .s = "" }, .start = 0, .series = &.{} }),
    /// This island's code, on its root for dom.lazyLoad
    js: []const u8 = "",
    wasm: []const u8 = "",

    /// Its own: url.zig leaves the keys it doesn't name (the other islands' range)
    pub const Url = struct { tab: ap.Tab = .overview, cat: View = .all };

    pub const Msg = union(enum) { view: View, outcome: u8 };

    pub fn toUrl(m: *const Models) Url {
        return .{ .tab = m.tab, .cat = m.cat };
    }

    pub fn fromUrl(m: *Models, u: Url) void {
        m.tab = u.tab;
        m.cat = u.cat;
    }

    pub fn update(m: *Models, msg: Msg, ev: *tree.Event) void {
        _ = ev;
        switch (msg) {
            .view => |v| m.cat = v,
            .outcome => |i| m.outcome = i,
        }
    }

    pub fn shows(m: *const Models) bool {
        return m.tab == .models;
    }

    pub fn view(m: *Models, h: *H) N {
        const on = m.shows();
        return h.div(.{ .class = "c-admodels", .data_island = "adminmodels", .data_js = m.js, .data_wasm = m.wasm, .hidden = !on }, .{
            if (on) body(m, h) else null,
        });
    }
};

const W = struct {
    pub const views = plain("Model categories");
    pub const loading = ap.W.loading;
    pub const models_failed = plain("The eval digest (models.bin) didn't load: Refresh to try again");
    pub const training_failed = plain("The lab view (training/training.bin) didn't load: the Mac uploads it with deploy/lab-push.sh, on the home network only");

    pub const learnt = plain("What we learnt");
    pub const all_lead = plain("The newest findings per category (docs/learned.md); open a category for its evidence, best model and runs.");
    pub const cat_lead = plain("Final findings (docs/learned.md), newest first.");
    pub const win_learnt = plain("Final findings for predicting the winner (docs/learned.md), newest first.");
    pub const early_learnt = plain("Final findings on the first 15 minutes: gold, CS, deaths, first item (docs/learned.md).");
    pub const nothing = plain("Nothing final yet.");
    pub const older = Phrase("Older findings ({n:count}) and recent runs");
    pub const runs = Phrase("Runs: {n:count}");
    pub const runs_live = Phrase("Runs: {n:count}, {k:count} running");
    pub const findings = Phrase(" · {n:count} findings");
    pub const head_win = Phrase("Shipped model right {acc:text} of the time (coin flip 50%).");
    pub const head_exp = Phrase(" Experiment {label:text}: {acc:text}.");
    pub const head_early = Phrase("The draft explains {v:text}% of lane gold leads at 14 min beyond champion averages.");

    pub const shipped = plain("Shipped model against the baseline");
    pub const eval_lead = Phrase("Daily eval (docs/model.md), newest {d:text}: models built from older games, scored on the newest games they never saw.");
    pub const no_report = plain("No eval report yet.");
    pub const more = plain("More readings");
    pub const run_by_run = plain("Run by run: each model against champion win rates");
    pub const run_cap = plain("Below zero beats champion win rates. Shrunk priors: empirical Bayes, a rare pair's effect pulled towards zero by how few games it has. Each run holds out a different, growing set of games, so raw scores across runs don't compare; differences on the same games do.");
    pub const base_line = plain("champion win rates");
    pub const s_current = plain("site's model");
    pub const s_eb = plain("shrunk priors");
    pub const s_joint = plain("joint ratings");
    pub const s_tuned = plain("tuned + weights");
    pub const picks = plain("Win rate of the site model's top-10% picks");
    pub const s_picks = plain("top-10% picks");
    pub const fifty = plain("50%");
    pub const each_model = plain("Each model against the one the site uses");
    pub const each_cap = Phrase("Log loss per game against the shipped model on the same {n:count} games, with 95% intervals. Blue: better beyond noise.");
    pub const better = plain("better");
    pub const worse = plain("worse");
    pub const curve = plain("Does more data help? Same test games, more training games");
    pub const curve_cap = plain("Log loss, lower is better. Each row doubles the training games; the test games stay the same, so this is the honest accuracy-by-data curve.");
    pub const c_games = plain("Training games");
    pub const report = plain("Full eval report (for model work)");
    pub const every = Phrase("Every eval run ({n:count})");
    pub const c_date = plain("Date");
    pub const c_games_all = plain("Games");
    pub const c_test = plain("Held out");
    pub const c_base = plain("Win rates");
    pub const c_site = plain("Site model");
    pub const c_eb = plain("Shrunk");

    pub const best = plain("Best model against the baseline");
    pub const early_lead = plain("How much of each early-game number the draft explains beyond champion averages.");
    pub const outcome = plain("Outcome");
    pub const no_team = plain("No team effects table in docs/model.md yet.");
    pub const team_total = Phrase("Who is in the game explains {v:text} of the differences in {o:text} beyond each champion's average. The rest is the game itself: players, decisions, luck.");
    pub const team_top = Phrase("The biggest single part: {s:text} ({v:text}%).");
    pub const team_none = Phrase("Adds nothing measurable: {s:text}.");
    pub const team_title = Phrase("What each part of the draft adds to {o:text}");
    pub const team_cap = Phrase("% of the variation in {o:text} explained, each part on top of the ones above it, 95% intervals (docs/model.md, \"{t:text}\"). Blue: clear of zero.");
    pub const explains_more = plain("explains more");
    pub const lab_best = plain("Best lab model so far, per outcome");
    pub const lab_cap = plain("Error removed against champion averages on the lab's practice games (not the final test), 95% intervals.");
    pub const less_error = plain("less error");

    pub const from_runs = plain("From recent runs");
    pub const effect_cap = plain("95% intervals. Blue: clear of zero.");
    pub const effect_cut = Phrase("95% intervals; the top and bottom 10 of {n:count}. Blue: clear of zero.");

    pub const draft_lead = plain("The Draft tester has its own page: build a draft and see what each model suggests for the next pick.");
    pub const open_tester = plain("Open the Draft tester");
};

fn body(m: *Models, h: *H) N {
    var picks: [views.len]segmented.Item = undefined;
    for (&picks, views) |*p, v| p.* = .{ .label = view_names.get(v), .on = h.on(m, .{ .view = v }), .selected = v == m.cat };
    return h.div(.{ .class = "tab" }, .{
        segmented.view(h, .{ .label = W.views }, &picks),
        status(m, h),
        switch (m.cat) {
            .all => allView(m, h),
            .win => winView(m, h),
            .draft => card.view(h, .{}, &.{
                card.head(h, view_names.get(.draft), null, &.{}),
                h.p(.{ .class = "lead" }, .{W.draft_lead}),
                h.a(.{ .href = tester_href }, .{W.open_tester}),
            }),
            .early => earlyView(m, h),
            else => |v| catView(m, h, catOf(v).?),
        },
    });
}

/// A line for each source the view needs that is loading or failed
fn status(m: *const Models, h: *H) []const N {
    if (m.cat == .draft) return &.{};
    const want_models = m.cat == .all or m.cat == .win;
    var l = h.list();
    if (want_models and m.models_failed) l.add(h.p(.{ .class = "lead", .role = "status" }, .{W.models_failed}));
    if (m.training_failed) l.add(h.p(.{ .class = "lead", .role = "status" }, .{W.training_failed}));
    const waiting = (want_models and m.models == null and !m.models_failed) or (m.training == null and !m.training_failed);
    if (waiting) l.add(h.p(.{ .class = "lead", .role = "status" }, .{W.loading}));
    return l.done();
}

fn learnedIn(h: *H, t: ?*const md.Training, c: md.Cat) []const md.Learned {
    const all = if (t) |x| x.learned else return &.{};
    var out: std.ArrayList(md.Learned) = .empty;
    for (all) |l| if (l.cat == c) out.append(h.mem, l) catch {
        h.oom = true;
    };
    return out.items;
}

/// Learned items as a list, each whole or its first sentence
fn learnedList(h: *H, items: []const md.Learned, short: bool) N {
    if (items.len == 0) return h.p(.{ .class = "lead" }, .{W.nothing});
    const out = h.mem.alloc(prose.Item, items.len) catch {
        h.oom = true;
        return .none;
    };
    for (out, items) |*o, l| o.* = .{ .line = if (short) l.short else l.line };
    const blocks = h.mem.dupe(prose.Block, &.{.{ .list = out }}) catch {
        h.oom = true;
        return .none;
    };
    return prose.view(h, .{ .blocks = blocks }, .{ .id_prefix = "lm-" });
}

fn readings(h: *H, lines: []const Text) N {
    var l = h.list();
    for (lines) |t| l.add(h.li(.{}, .{t}));
    return h.ul(.{ .class = "readings" }, .{l.done()});
}

// ---------- All ----------

fn allView(m: *Models, h: *H) N {
    var cards = h.list();
    for (cats) |c| cards.add(catCard(m, h, c));
    return h.div(.{ .class = "tab" }, .{
        card.sechead(h, W.learnt, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.all_lead}),
        h.div(.{ .class = "cards" }, .{cards.done()}),
    });
}

fn catCard(m: *Models, h: *H, c: md.Cat) N {
    const items = learnedIn(h, m.training, c);
    var n_runs: u32 = 0;
    var live: u32 = 0;
    if (m.training) |t| for (t.runs) |r| if (r.cat == c) {
        n_runs += 1;
        if (r.state == .running or r.state == .paused) live += 1;
    };
    const runs = if (live > 0) W.runs_live.with(h, .{ .n = n_runs, .k = live }) else W.runs.with(h, .{ .n = n_runs });
    const v = viewOf(c);
    return card.view(h, .{}, &.{
        h.div(.{ .class = "cat" }, .{
            h.h3(.{}, .{h.button(.{ .type = "button", .on_click = h.on(m, .{ .view = v }) }, .{view_names.get(v)})}),
            headline(m, h, c),
            learnedList(h, items[0..@min(items.len, 2)], true),
            h.p(.{ .class = "sub" }, .{ runs, if (items.len > 2) W.findings.with(h, .{ .n = items.len }) else null }),
        }),
    });
}

fn headline(m: *const Models, h: *H, c: md.Cat) N {
    switch (c) {
        .win => {
            const w = (m.models orelse return .none).win orelse return .none;
            const s = w.models[w.shipped orelse return .none];
            const exp: ?Text = if (w.experiment) |i| W.head_exp.with(h, .{ .label = w.models[i].label, .acc = pct(h, w.models[i].acc).s }) else null;
            return h.p(.{ .class = "headline" }, .{ W.head_win.with(h, .{ .acc = pct(h, s.acc).s }), exp });
        },
        .early => {
            const te = (m.training orelse return .none).team orelse return .none;
            const o = outcomeIndex(te, "lanediff14") orelse return .none;
            const v = te.total[o] orelse return .none;
            return h.p(.{ .class = "headline" }, .{W.head_early.with(h, .{ .v = dec(h, v.mean, 1) })});
        },
        else => return .none,
    }
}

// ---------- Win ----------

fn winView(m: *Models, h: *H) N {
    const mo = m.models orelse return learntWin(m, h);
    const ev = mo.eval;
    const lead: Text = if (ev.len > 0) W.eval_lead.with(h, .{ .d = ap.day(h, @as(i64, ev[ev.len - 1].date) * 86400).s }) else W.no_report;
    const w = mo.win orelse return h.div(.{ .class = "tab" }, .{
        card.view(h, .{}, &.{ card.head(h, W.shipped, null, &.{}), h.p(.{ .class = "lead" }, .{lead}), h.p(.{ .class = "lead" }, .{W.no_report}) }),
        learntWin(m, h),
    });
    const lines = winReadings(h, mo, w);
    var charts = h.list();
    if (runByRun(h, ev)) |o| charts.add(chart(m, h, 0, o));
    if (picksChart(h, ev)) |o| charts.add(chart(m, h, 1, o));
    var rows: std.ArrayList(FRow) = .empty;
    for (w.models, 0..) |x, i| if (x.d) |d| if (!is(w.current, i)) rows.append(h.mem, .{ .label = x.label, .v = d.mean, .ci = d.ci }) catch {
        h.oom = true;
    };
    if (rows.items.len > 0) charts.add(forest(h, W.each_model, W.each_cap.with(h, .{ .n = w.games }), rows.items, .{ .num = .ll, .left = W.better, .right = W.worse }));
    if (w.curve) |c| charts.add(curveTable(h, c));
    return h.div(.{ .class = "tab" }, .{
        card.view(h, .{}, &.{
            card.head(h, W.shipped, null, &.{}),
            h.p(.{ .class = "lead" }, .{lead}),
            readings(h, lines[0..@min(lines.len, 1)]),
        }),
        h.div(.{ .class = "charts" }, .{charts.done()}),
        if (lines.len > 1) card.view(h, .{}, &.{ card.head(h, W.more, null, &.{}), readings(h, lines[1..]) }) else null,
        h.el(.details, .{ .class = "c-card" }, .{
            h.el(.summary, .{}, .{W.report}),
            prose.view(h, mo.report, .{ .id_prefix = "ev-", .top = 3 }),
        }),
        evalTable(h, ev),
        learntWin(m, h),
    });
}

/// The eval report's numbers in plain sentences. One rule for every headline: the shipped
/// model; the best experiment that beats it stays beside it, labelled, so it can be tested
fn winReadings(h: *H, mo: *const md.Models, w: md.Win) []const Text {
    var out: std.ArrayList(Text) = .empty;
    const add = struct {
        fn f(hh: *H, o: *std.ArrayList(Text), t: Text) void {
            o.append(hh.mem, t) catch {
                hh.oom = true;
            };
        }
    }.f;
    if (w.shipped) |si| {
        const s = w.models[si];
        const share = @max(0, (ll_coin - s.ll) / (ll_coin - ll_published));
        var t = h.fmt("From the draft alone the shipped model calls the winner of {s} new games right {s} of the time (a coin flip: 50%). Published draft models trained on millions of games reach about 55 to 57%; by log loss we are {d:.0}% of the way there.", .{ count(h, w.games), pct(h, s.acc).s, 100 * share });
        if (w.experiment) |ei| {
            const e = w.models[ei];
            const against = if (e.d) |d| h.fmt(" (log loss {s} against the shipped model)", .{pm(h, d, .ll)}) else "";
            t = h.fmt("{s} Best experiment, not shipped: {s}, {s}{s}.", .{ t, e.label, pct(h, e.acc).s, against });
        }
        add(h, &out, .{ .s = t });
    }
    if (w.base != null and w.current != null) if (w.models[w.base.?].d) |b| {
        add(h, &out, .{ .s = if (@abs(b.mean) <= b.ci)
            h.fmt("The model the site and app use is no better than each champion's own win rate (difference {s}, inside noise): its matchup and duo terms add nothing measurable yet.", .{pm(h, b, .ll)})
        else if (b.mean < 0)
            h.fmt("Champion win rates alone beat the model the site uses ({s}): its pair terms add noise.", .{pm(h, b, .ll)})
        else
            h.fmt("The model the site uses beats champion win rates alone ({s}).", .{pm(h, .{ .mean = -b.mean, .ci = b.ci }, .ll)}) });
    };
    var winners: std.ArrayList(u8) = .empty;
    for (w.models, 0..) |x, i| {
        const d = x.d orelse continue;
        if (d.mean + d.ci >= 0 or is(w.base, i) or std.mem.find(u8, x.label, "coin") != null or std.mem.find(u8, x.label, "blue side") != null) continue;
        if (winners.items.len > 0) winners.appendSlice(h.mem, ", ") catch {};
        winners.print(h.mem, "{s} ({s})", .{ x.label, pm(h, d, .ll) }) catch {};
    }
    if (winners.items.len > 0) {
        var why: []const u8 = "";
        if (w.lane_weight) |x| if (x > 1.3) {
            why = h.fmt(" The tuning weighs lane matchups {d:.1} times the default: lane matchups carry signal the shipped model shrinks away.", .{x});
        };
        if (w.duo_weight) |x| if (x < 0.85) {
            why = h.fmt("{s} Duo terms are shrunk to {d:.2}: mostly noise.", .{ why, x });
        };
        add(h, &out, .{ .s = h.fmt("Beats the shipped model beyond noise: {s}. The eval runs several times a day, so check it holds run after run (Run by run chart).{s}", .{ winners.items, why }) });
    }
    if (w.picks) |p| {
        const n: f32 = @floatFromInt(@max(p.n, 1));
        const z = (p.p - 0.5) / @sqrt(0.25 / n);
        add(h, &out, .{ .s = if (z >= 3)
            h.fmt("Picks the shipped model ranks in its top 10% for their slot won {s} of {s} games: a small but real edge of {d:.1} points (about {d:.0} standard errors; fewer in truth, as picks in one team share a result).", .{ pct(h, p.p).s, count(h, p.n), (p.p - 0.5) * 100, z })
        else
            h.fmt("Picks the shipped model ranks in its top 10% won {s} of {s} games: not yet distinguishable from 50%.", .{ pct(h, p.p).s, count(h, p.n) }) });
    }
    if (w.deciles.len > 0) {
        var miss: f32 = 0;
        for (w.deciles) |c| miss = @max(miss, @abs(c.predicted - c.won));
        const se = 100 * @sqrt(0.25 / @as(f32, @floatFromInt(@max(w.deciles[0].games, 1))));
        add(h, &out, .{ .s = h.fmt("Its percentages can be read at face value: predictions run from {d:.1}% to {d:.1}% and each tenth of games landed within {d:.1} points of its prediction (noise alone is about ±{d:.1}).", .{ w.deciles[0].predicted, w.deciles[w.deciles.len - 1].predicted, miss, 2 * se }) });
    }
    if (w.curve) |c| if (c.per_doubling) |pd| if (pd > 0 and c.games.len > 0) {
        const need = (c.last - ll_published) / pd;
        const n: f64 = @floatFromInt(c.games[c.games.len - 1]);
        const target = n * std.math.pow(f64, 2, need);
        const days = if (mo.matches_per_day) |r| if (r > 0) h.fmt(" (~{s} days of crawling at today's rate, while patches change every two weeks)", .{count(h, @as(u64, @intFromFloat(@min((target - n) / r, 1e12))))}) else "" else "";
        add(h, &out, .{ .s = h.fmt("More games help slowly: each doubling of games improves champion win rates by {d:.4} log loss. At that pace reaching published accuracy takes about {d:.0} more doublings, ~{s} games{s}. Gains have to come from better inputs too, not volume alone.", .{ pd, need, count(h, @as(u64, @intFromFloat(@min(target, 1e15)))), days }) });
    };
    if (w.experience) |x| if (@abs(x.d.mean) <= x.d.ci) {
        var all_up = x.bins.len > 0;
        for (x.bins) |b| all_up = all_up and b > 0;
        add(h, &out, .{ .s = h.fmt("Knowing how many games the player has on the champion doesn't improve the prediction yet ({s}).{s}", .{ pm(h, x.d, .ll), if (all_up) " Every experience band shows a positive effect against unknown players, which fits selection (crawled players come from the current ladder, where winners sit) better than skill." else "" }) });
    };
    if (w.gold) |g| add(h, &out, .{ .s = h.fmt("Adding typical lane gold at 14 min (from timelines) to the draft: accuracy {s} vs {s}, log loss {d:.4} vs {d:.4}.", .{ pct(h, g[0].acc).s, pct(h, g[1].acc).s, g[0].ll, g[1].ll }) });
    return out.items;
}

/// One value per UK day from the first eval's, the day's last run; null on days without
fn daily(h: *H, ev: []const ad.EvalRow, comptime get: fn (ad.EvalRow) ?f32) []const ?f32 {
    const first = ev[0].date;
    const n: usize = @intCast(@max(ev[ev.len - 1].date - first + 1, 1));
    const out = h.mem.alloc(?f32, n) catch {
        h.oom = true;
        return &.{};
    };
    @memset(out, null);
    for (ev) |r| {
        const i = std.math.cast(usize, r.date - first) orelse continue;
        if (i < n) if (get(r)) |v| {
            out[i] = v;
        };
    }
    return out;
}

fn runByRun(h: *H, ev: []const ad.EvalRow) ?timechart.Time {
    if (ev.len < 2) return null;
    const keys = .{
        .{ W.s_current, Rel("current").f },
        .{ W.s_eb, Rel("eb").f },
        .{ W.s_joint, Rel("joint").f },
        .{ W.s_tuned, Rel("tunedw").f },
    };
    var series: std.ArrayList(timechart.Series) = .empty;
    inline for (keys, 0..) |k, i| {
        const vs = daily(h, ev, k[1]);
        for (vs) |v| if (v != null) {
            series.append(h.mem, .{ .name = k[0], .values = vs, .colour = i }) catch {
                h.oom = true;
            };
            break;
        };
    }
    if (series.items.len == 0) return null;
    return .{ .label = W.run_by_run, .unit = .diff, .start = @as(i64, ev[0].date) * 86400, .step = 86400, .clock = .utc, .series = series.items, .refs = refs(h, 0, W.base_line), .fit = true };
}

/// A model's log loss less champion win rates'
fn Rel(comptime k: []const u8) type {
    return struct {
        fn f(r: ad.EvalRow) ?f32 {
            return (@field(r, "ll_" ++ k) orelse return null) - (r.ll_base orelse return null);
        }
    };
}

fn picksChart(h: *H, ev: []const ad.EvalRow) ?timechart.Time {
    if (ev.len < 2) return null;
    const vs = daily(h, ev, struct {
        fn f(r: ad.EvalRow) ?f32 {
            return if (r.pick_top10_win) |p| 100 * p else null;
        }
    }.f);
    for (vs) |v| if (v != null) break else return null;
    const series = h.mem.dupe(timechart.Series, &.{.{ .name = W.s_picks, .values = vs, .colour = 2 }}) catch {
        h.oom = true;
        return null;
    };
    return .{ .label = W.picks, .unit = .rate, .start = @as(i64, ev[0].date) * 86400, .step = 86400, .clock = .utc, .series = series, .refs = refs(h, 50, W.fifty), .fit = true };
}

fn refs(h: *H, v: f32, label: Text) []const timechart.Ref {
    return h.mem.dupe(timechart.Ref, &.{.{ .v = v, .label = label }}) catch {
        h.oom = true;
        return &.{};
    };
}

fn chart(m: *Models, h: *H, i: usize, o: timechart.Time) N {
    const x = &m.times[i];
    var c = o;
    c.zoom = x.zoom;
    c.tip = x.tip;
    c.drag = x.drag;
    c.press = x.press;
    x.* = c;
    return card.view(h, .{}, &.{ card.head(h, o.label, null, &.{}), x.view(h), if (i == 0) h.p(.{ .class = "cap" }, .{W.run_cap}) else .none });
}

fn curveTable(h: *H, c: md.Curve) N {
    var head = h.list();
    head.add(h.th(.{}, .{W.c_games}));
    for (c.cols, 0..) |col, i| head.add(h.th(.{ .class = "num", .data_answer = i + 1 == c.cols.len }, .{col}));
    var rows = h.list();
    for (c.games, 0..) |g, i| {
        var tds = h.list();
        tds.add(h.th(.{ .class = "num" }, .{count(h, g)}));
        for (0..c.cols.len) |k| {
            const v: ?f32 = if (i < c.ll.len and k < c.ll[i].len) c.ll[i][k] else null;
            tds.add(h.td(.{ .class = "num" }, .{if (v) |x| h.fmt("{d:.4}", .{x}) else "–"}));
        }
        rows.add(h.tr(.{}, .{tds.done()}));
    }
    return card.view(h, .{}, &.{
        card.head(h, W.curve, null, &.{}),
        h.div(.{ .class = "tw" }, .{h.table(.{}, .{ h.thead(.{}, .{h.tr(.{}, .{head.done()})}), h.tbody(.{}, .{rows.done()}) })}),
        h.p(.{ .class = "cap" }, .{W.curve_cap}),
    });
}

fn evalTable(h: *H, ev: []const ad.EvalRow) N {
    if (ev.len == 0) return .none;
    var rows = h.list();
    var i = ev.len;
    while (i > 0) {
        i -= 1;
        const r = ev[i];
        rows.add(h.tr(.{}, .{
            h.td(.{ .class = "nw" }, .{ap.day(h, @as(i64, r.date) * 86400)}),
            h.td(.{ .class = "num" }, .{count(h, r.games)}),
            h.td(.{ .class = "num" }, .{count(h, r.@"test")}),
            h.td(.{ .class = "num" }, .{ll(h, r.ll_base)}),
            h.td(.{ .class = "num" }, .{ll(h, r.ll_current)}),
            h.td(.{ .class = "num" }, .{ll(h, r.ll_eb)}),
        }));
    }
    return h.el(.details, .{ .class = "c-card" }, .{
        h.el(.summary, .{}, .{W.every.with(h, .{ .n = ev.len })}),
        h.div(.{ .class = "tw" }, .{h.table(.{}, .{
            h.thead(.{}, .{h.tr(.{}, .{
                h.th(.{}, .{W.c_date}),
                h.th(.{ .class = "num" }, .{W.c_games_all}),
                h.th(.{ .class = "num" }, .{W.c_test}),
                h.th(.{ .class = "num" }, .{W.c_base}),
                h.th(.{ .class = "num", .data_answer = true }, .{W.c_site}),
                h.th(.{ .class = "num" }, .{W.c_eb}),
            })}),
            h.tbody(.{}, .{rows.done()}),
        })}),
    });
}

/// The newest two findings in view; the rest and the run findings one click away
fn learntWin(m: *Models, h: *H) N {
    const items = learnedIn(h, m.training, .win);
    const top = items[0..@min(items.len, 2)];
    const rest = items[top.len..];
    return card.view(h, .{}, &.{
        card.head(h, W.learnt, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.win_learnt}),
        learnedList(h, top, false),
        h.el(.details, .{}, .{
            h.el(.summary, .{}, .{W.older.with(h, .{ .n = rest.len })}),
            if (rest.len > 0) learnedList(h, rest, false) else null,
            runFindings(m, h, .win),
        }),
    });
}

// ---------- Early and the other categories ----------

fn is(x: ?u16, i: usize) bool {
    return if (x) |v| v == i else false;
}

fn outcomeIndex(te: md.TeamEffects, key: []const u8) ?usize {
    for (te.outcomes, 0..) |o, i| if (std.mem.eql(u8, o, key)) return i;
    return null;
}

fn earlyView(m: *Models, h: *H) N {
    return h.div(.{ .class = "tab" }, .{
        learntCard(m, h, .early, W.early_learnt),
        card.view(h, .{}, &.{
            card.head(h, W.best, null, &.{}),
            h.p(.{ .class = "lead" }, .{W.early_lead}),
            teamBlock(m, h),
        }),
    });
}

fn teamBlock(m: *Models, h: *H) N {
    const t = m.training orelse return .none;
    const best = labBest(h, t, .early);
    const te = t.team orelse return h.div(.{}, .{ h.p(.{ .class = "lead" }, .{W.no_team}), h.div(.{ .class = "charts" }, .{best}) });
    if (te.outcomes.len == 0) return .none;
    const oi: usize = if (m.outcome) |i| @min(i, te.outcomes.len - 1) else outcomeIndex(te, "lanediff14") orelse 0;
    const picks = h.mem.alloc(segmented.Item, te.outcomes.len) catch {
        h.oom = true;
        return .none;
    };
    for (picks, te.outcomes, 0..) |*p, o, i| p.* = .{ .label = .{ .s = if (outcomeOf(o)) |x| x.short else o }, .title = outcomeLabel(o), .on = h.on(m, .{ .outcome = @intCast(i) }), .selected = i == oi };
    const oname = lowerFirst(h, outcomeLabel(te.outcomes[oi]));
    var rows: std.ArrayList(FRow) = .empty;
    var top: ?FRow = null;
    var none: std.ArrayList(u8) = .empty;
    for (te.steps, te.cells) |s, cells| {
        const c = (if (oi < cells.len) cells[oi] else null) orelse continue;
        const r: FRow = .{ .label = s, .v = c.mean, .ci = c.ci };
        rows.append(h.mem, r) catch {};
        if (top == null or r.v > top.?.v) top = r;
        if (@abs(c.mean) <= c.ci) {
            if (none.items.len > 0) none.appendSlice(h.mem, "; ") catch {};
            none.appendSlice(h.mem, s) catch {};
        }
    }
    var lines: std.ArrayList(Text) = .empty;
    if (oi < te.total.len) if (te.total[oi]) |tot| lines.append(h.mem, W.team_total.with(h, .{ .v = pmPct(h, tot), .o = oname })) catch {};
    if (top) |x| lines.append(h.mem, W.team_top.with(h, .{ .s = x.label, .v = dec(h, x.v, 1) })) catch {};
    if (none.items.len > 0) lines.append(h.mem, W.team_none.with(h, .{ .s = @as([]const u8, none.items) })) catch {};
    return h.div(.{}, .{
        segmented.view(h, .{ .s = .s, .label = W.outcome }, picks),
        readings(h, lines.items),
        h.div(.{ .class = "charts" }, .{
            forest(h, W.team_title.with(h, .{ .o = oname }), W.team_cap.with(h, .{ .o = oname, .t = te.title }), rows.items, .{ .num = .pct, .better = .higher, .right = W.explains_more }),
            best,
        }),
    });
}

/// The best lab run per target of the category (practice games, `exp run`)
fn labBest(h: *H, t: *const md.Training, c: md.Cat) N {
    var rows: std.ArrayList(FRow) = .empty;
    for (outcomes) |o| {
        if (o.cat != c) continue;
        var best: ?*const md.Run = null;
        for (t.runs) |*r| {
            const res = r.res orelse continue;
            const dev = res.dev orelse continue;
            // ci 0: a reference run scoring the baseline against itself
            if (res.kind != .run or dev.ci == 0 or !std.mem.eql(u8, r.target, o.key)) continue;
            if (best == null or dev.mean < best.?.res.?.dev.?.mean) best = r;
        }
        const b = best orelse continue;
        const dev = b.res.?.dev.?;
        const own = if (b.result) |x| x.removed else null;
        rows.append(h.mem, .{
            .label = h.fmt("{s}: {s}", .{ o.label, if (b.campaign.len > 0) b.campaign else shortRun(b.run) }),
            .v = if (own) |x| x.mean else -dev.mean * 100,
            .ci = if (own) |x| x.ci else dev.ci * 100,
        }) catch {
            h.oom = true;
        };
    }
    if (rows.items.len == 0) return .none;
    return forest(h, W.lab_best, W.lab_cap, rows.items, .{ .num = .pct, .better = .higher, .right = W.less_error });
}

fn learntCard(m: *Models, h: *H, c: md.Cat, lead: Text) N {
    return card.view(h, .{}, &.{
        card.head(h, W.learnt, null, &.{}),
        h.p(.{ .class = "lead" }, .{lead}),
        learnedList(h, learnedIn(h, m.training, c), false),
        runFindings(m, h, c),
    });
}

fn catView(m: *Models, h: *H, c: md.Cat) N {
    const best = if (m.training) |t| labBest(h, t, c) else N.none;
    return h.div(.{ .class = "tab" }, .{
        learntCard(m, h, c, W.cat_lead),
        if (best != N.none) card.view(h, .{}, &.{ card.head(h, W.best, null, &.{}), h.div(.{ .class = "charts" }, .{best}) }) else null,
    });
}

/// Findings from the category's runs, newest first, each with its effect chart
fn runFindings(m: *Models, h: *H, c: md.Cat) N {
    const t = m.training orelse return .none;
    var lis = h.list();
    var charts = h.list();
    var any = false;
    for (t.runs) |r| {
        if (r.cat != c or r.findings.len == 0) continue;
        any = true;
        // Effects already charted, by index
        var shown: u64 = 0;
        for (r.findings) |f| {
            const from = if (f.campaign.len > 0) f.campaign else if (r.campaign.len > 0) r.campaign else shortRun(r.run);
            const when: []const u8 = if (r.started) |s| h.fmt(", {s}", .{ap.when(h, s).s}) else "";
            lis.add(h.li(.{}, .{ f.text, h.span(.{ .class = "sub" }, .{h.fmt(" ({s}{s})", .{ from, when })}) }));
            const e = f.effect orelse continue;
            const bit = if (e < 64) @as(u64, 1) << @intCast(e) else 0;
            if (e >= r.effects.len or shown & bit != 0) continue;
            shown |= bit;
            charts.add(effectForest(h, r.effects[e]));
        }
    }
    if (!any) return .none;
    return h.div(.{ .class = "found" }, .{
        h.h3(.{}, .{W.from_runs}),
        h.ul(.{ .class = "readings" }, .{lis.done()}),
        h.div(.{ .class = "charts" }, .{charts.done()}),
    });
}

/// An effects file as a forest, largest first; long ones as the ten largest and smallest
fn effectForest(h: *H, e: md.Effect) N {
    if (e.rows.len == 0) return .none;
    const all = h.mem.alloc(FRow, e.rows.len) catch {
        h.oom = true;
        return .none;
    };
    for (all, e.rows) |*o, r| o.* = .{ .label = r.label, .v = r.value, .ci = r.ci };
    std.mem.sort(FRow, all, {}, struct {
        fn f(_: void, a: FRow, b: FRow) bool {
            return a.v > b.v;
        }
    }.f);
    const cut = all.len > 20;
    const rows = if (!cut) all else std.mem.concat(h.mem, FRow, &.{ all[0..10], &.{.{ .label = "…", .v = 0, .ci = 0, .gap = true }}, all[all.len - 10 ..] }) catch {
        h.oom = true;
        return .none;
    };
    const unit = if (std.mem.eql(u8, e.unit, "-")) "" else e.unit;
    return forest(h, .{ .s = e.title }, if (cut) W.effect_cut.with(h, .{ .n = all.len }) else W.effect_cap, rows, .{
        .num = .sig,
        .unit = unit,
        .better = .higher,
        .right = if (e.higher.len > 0 and !std.mem.eql(u8, e.higher, "-")) Text{ .s = e.higher } else null,
    });
}

// ---------- Forest ----------

const FRow = struct { label: []const u8, v: f32, ci: f32, gap: bool = false };

const ForestOpts = struct {
    num: enum { ll, pct, sig },
    unit: []const u8 = "",
    better: enum { lower, higher } = .lower,
    /// What either end means
    left: ?Text = null,
    right: ?Text = null,
};

/// Estimates with 95% intervals, a dot and whiskers each from a line at zero; blue where
/// clear of zero on the better side, orange on the worse
fn forest(h: *H, title: Text, caption: Text, rows: []const FRow, o: ForestOpts) N {
    var span: f32 = 0;
    for (rows) |r| span = @max(span, @abs(r.v) + r.ci);
    span = if (span > 0) span * 1.1 else 1;
    var trs = h.list();
    for (rows, 0..) |r, i| {
        if (r.gap) {
            trs.add(h.tr(.{ .key = i }, .{h.td(.{ .colspan = 3 }, .{r.label})}));
            continue;
        }
        const clear = @abs(r.v) > r.ci;
        const good = (r.v < 0) == (o.better == .lower);
        trs.add(h.tr(.{ .key = i, .data_c = if (!clear) null else if (good) "good" else "bad" }, .{
            h.th(.{}, .{r.label}),
            h.td(.{ .class = "bar" }, .{delta.bar(h, .{ .d = r.v, .ci = r.ci, .span = span, .dot = true })}),
            h.td(.{ .class = "num nw" }, .{switch (o.num) {
                .ll => pm(h, .{ .mean = r.v, .ci = r.ci }, .ll),
                .pct => pmPct(h, .{ .mean = r.v, .ci = r.ci }),
                .sig => h.fmt("{s}{s}{s}", .{ sig(h, r.v, r.ci), if (o.unit.len > 0) " " else "", o.unit }),
            }}),
        }));
    }
    return card.view(h, .{}, &.{
        card.head(h, title, null, &.{}),
        if (o.left != null or o.right != null) h.div(.{ .class = "ends", .aria_hidden = true }, .{
            h.span(.{}, .{if (o.left) |l| h.fmt("← {s}", .{l.s}) else ""}),
            h.span(.{}, .{if (o.right) |r| h.fmt("{s} →", .{r.s}) else ""}),
        }) else .none,
        h.div(.{ .class = "tw" }, .{h.table(.{ .class = "forest" }, .{
            h.el(.colgroup, .{}, .{ h.el(.col, .{}, .{}), h.el(.col, .{}, .{}), h.el(.col, .{ .data_answer = true }, .{}) }),
            h.tbody(.{}, .{trs.done()}),
        })}),
        h.p(.{ .class = "cap" }, .{caption}),
    });
}

// ---------- Numbers ----------

fn count(h: *H, n: anytype) []const u8 {
    return phrase.num(h, .count, n).s;
}

/// A share as a percentage, 0.557 as 55.7%
fn pct(h: *H, share: f32) Text {
    return phrase.num(h, .rate, 100 * share);
}

fn dec(h: *H, v: f32, comptime places: u4) []const u8 {
    var out: std.Io.Writer.Allocating = .init(h.mem);
    fmt.fixed(&out.writer, v, places, false) catch {
        h.oom = true;
    };
    return out.written();
}

/// "+0.0006 ± 0.0002", the sign a true minus
fn pm(h: *H, x: md.Pm, comptime k: enum { ll }) []const u8 {
    _ = k;
    return h.fmt("{s}{s} ± {s}", .{ sign(x.mean), dec(h, @abs(x.mean), 4), dec(h, x.ci, 4) });
}

/// "1.2% ± 0.3", values already in percent
fn pmPct(h: *H, x: md.Pm) []const u8 {
    return h.fmt("{s}{s}% ± {s}", .{ if (x.mean < 0) "−" else "", dec(h, @abs(x.mean), 1), dec(h, x.ci, 1) });
}

fn sign(v: f32) []const u8 {
    return if (v < 0) "−" else if (v > 0) "+" else "";
}

/// "−2.10 ± 0.80": about three significant figures, the range to the same places
fn sig(h: *H, v: f32, ci: f32) []const u8 {
    const a = @abs(v);
    const s = if (v < 0) "−" else "";
    const c = @abs(ci);
    return if (a >= 100)
        h.fmt("{s}{s} ± {s}", .{ s, dec(h, a, 0), dec(h, c, 0) })
    else if (a >= 10)
        h.fmt("{s}{s} ± {s}", .{ s, dec(h, a, 1), dec(h, c, 1) })
    else if (a >= 1)
        h.fmt("{s}{s} ± {s}", .{ s, dec(h, a, 2), dec(h, c, 2) })
    else
        h.fmt("{s}{s} ± {s}", .{ s, dec(h, a, 3), dec(h, c, 3) });
}

fn ll(h: *H, v: ?f32) []const u8 {
    return if (v) |x| dec(h, x, 4) else "–";
}

/// "Gold at 14 min" as "gold at 14 min", "CS at 10 min" kept
fn lowerFirst(h: *H, s: []const u8) []const u8 {
    if (s.len < 2 or !std.ascii.isLower(s[1])) return s;
    const out = h.mem.dupe(u8, s) catch {
        h.oom = true;
        return s;
    };
    out[0] = std.ascii.toLower(out[0]);
    return out;
}

/// "20261024T001511Z-golden" as "golden"
pub fn shortRun(run: []const u8) []const u8 {
    const z = std.mem.find(u8, run, "Z-") orelse return run;
    if (z < 13 or z > 15 or run[8] != 'T') return run;
    for (run[0..8]) |c| if (!std.ascii.isDigit(c)) return run;
    return run[z + 2 ..];
}

pub const css =
    \\@layer components {
    \\  .c-admodels .tab { display: grid; gap: var(--sp-3); }
    \\  .c-admodels .lead { margin: 0 0 var(--sp-2); color: var(--muted); font-size: var(--fs-s); }
    \\  .c-admodels .readings { margin: 0; padding-inline-start: var(--sp-4); display: grid; gap: var(--sp-1); }
    \\  .c-admodels .charts, .c-admodels .cards { display: grid; gap: var(--sp-3);
    \\    grid-template-columns: repeat(auto-fit, minmax(min(100%, 26rem), 1fr)); }
    \\  .c-admodels .cards { grid-template-columns: repeat(auto-fit, minmax(min(100%, 20rem), 1fr)); }
    \\  .c-admodels .cards > .c-card { position: relative; }
    \\  .c-admodels .cards > .c-card:hover { border-color: var(--accent); }
    \\  .c-admodels .cat h3 { margin: 0 0 var(--sp-2); font-size: var(--fs-l); }
    \\  .c-admodels .cat h3 button { all: unset; cursor: pointer; }
    \\  .c-admodels .cat h3 button::after { content: ""; position: absolute; inset: 0; }
    \\  .c-admodels .cat h3 button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    \\  .c-admodels .headline { margin: 0 0 var(--sp-2); }
    \\  .c-admodels :is(.sub, .cap) { color: var(--muted); font-size: var(--fs-s); }
    \\  .c-admodels p:is(.sub, .cap) { margin: var(--sp-2) 0 0; }
    \\  .c-admodels .found h3 { margin: var(--sp-3) 0 var(--sp-2); font-size: var(--fs-m); }
    \\  .c-admodels .found .charts { margin-top: var(--sp-3); }
    \\  .c-admodels .tw { overflow-x: auto; }
    \\  .c-admodels table { width: 100%; border-collapse: collapse; font-size: var(--fs-s); }
    \\  .c-admodels :is(th, td) { padding: var(--sp-1) var(--sp-2); border-bottom: 1px solid var(--line);
    \\    text-align: start; vertical-align: middle; white-space: normal; }
    \\  .c-admodels thead th { color: var(--muted); font-weight: var(--w-m); }
    \\  .c-admodels tbody th { font-weight: var(--w-r); color: var(--text); }
    \\  .c-admodels :is(td, th).num { text-align: end; font-variant-numeric: tabular-nums; }
    \\  .c-admodels .nw { white-space: nowrap; }
    \\  .c-admodels table.forest th { width: 40%; overflow-wrap: anywhere; }
    \\  .c-admodels table.forest td.bar { width: 35%; }
    \\  .c-admodels table.forest td[colspan] { color: var(--muted); text-align: center; }
    \\  .c-admodels .forest tr[data-c="good"] .c-dbar > :is(i, s) { background: var(--good); }
    \\  .c-admodels .forest tr[data-c="bad"] .c-dbar > :is(i, s) { background: var(--bad); }
    \\  .c-admodels .forest tr:not([data-c]) .c-dbar > :is(i, s) { background: var(--muted); }
    \\  .c-admodels .ends { display: flex; justify-content: space-between; color: var(--muted); font-size: var(--fs-xs); }
    \\  .c-admodels details.c-card > summary, .c-admodels details > summary { cursor: pointer; font-weight: var(--w-b); }
    \\  .c-admodels details > summary + * { margin-top: var(--sp-2); }
    \\}
    \\
;

pub const Demo = struct {
    const now = ap.Demo.now;
    const today: i32 = @intCast(@divFloor(now, 86400));

    fn line(comptime s: []const u8) prose.Line {
        return &[_]prose.Run{.{ .s = s }};
    }

    const eval = [_]ad.EvalRow{
        .{ .date = today - 5, .games = 312_000, .@"test" = 31_200, .ll_base = 0.6871, .ll_current = 0.6869, .ll_eb = 0.6866, .ll_tunedw = 0.6861, .pick_top10_win = 0.528 },
        .{ .date = today - 4, .games = 321_000, .@"test" = 32_100, .ll_base = 0.6868, .ll_current = 0.6867, .ll_eb = 0.6863, .ll_tunedw = 0.6858, .pick_top10_win = 0.531 },
        .{ .date = today - 2, .games = 340_000, .@"test" = 34_000, .ll_base = 0.6866, .ll_current = 0.6866, .ll_eb = 0.6861, .ll_tunedw = 0.6857, .pick_top10_win = 0.532 },
        .{ .date = today - 1, .games = 350_000, .@"test" = 35_000, .ll_base = 0.6864, .ll_current = 0.6862, .ll_eb = 0.6859, .ll_tunedw = 0.6854, .pick_top10_win = 0.533 },
        .{ .date = today, .games = 359_420, .@"test" = 35_942, .ll_base = 0.6862, .ll_current = 0.6860, .ll_eb = 0.6858, .ll_tunedw = 0.6851, .pick_top10_win = 0.534 },
    };

    const win: md.Win = .{
        .games = 35_942,
        .models = &.{
            .{ .label = "coin flip", .ll = 0.6931, .acc = 0.5 },
            .{ .label = "champion base only", .ll = 0.6903, .acc = 0.548, .d = .{ .mean = 0.0002, .ci = 0.0004 } },
            .{ .label = "current model (additive v2)", .ll = 0.6901, .acc = 0.557 },
            .{ .label = "previous model", .ll = 0.6907, .acc = 0.551, .d = .{ .mean = 0.0006, .ci = 0.0003 } },
            .{ .label = "tuned + weights", .ll = 0.6892, .acc = 0.561, .d = .{ .mean = -0.0009, .ci = 0.0004 } },
        },
        .shipped = 2,
        .base = 1,
        .current = 2,
        .experiment = 4,
        .deciles = &.{ .{ .predicted = 41.2, .won = 40.9, .games = 3_594 }, .{ .predicted = 58.8, .won = 59.6, .games = 3_594 } },
        .picks = .{ .p = 0.534, .n = 82_404 },
        .curve = .{
            .cols = &.{ "base only", "current" },
            .games = &.{ 40_000, 80_000, 160_000, 320_000 },
            .ll = &.{ &.{ 0.6954, 0.6958 }, &.{ 0.6940, 0.6941 }, &.{ 0.6926, 0.6924 }, &.{ 0.6912, 0.6909 } },
            .per_doubling = 0.0014,
            .last = 0.6912,
        },
        .lane_weight = 1.643,
        .duo_weight = 0.797,
    };

    pub const models: md.Models = .{
        .now = now,
        .eval = &eval,
        .win = win,
        .report = .{ .blocks = &.{
            .{ .heading = .{ .level = 2, .line = line("Full draft, held-out games"), .id = "full-draft" } },
            .{ .para = line("Scored on the newest 35,942 games, trained on the 323,478 before them.") },
        } },
        .matches_per_day = 52_000,
    };

    const effect: md.Effect = .{ .name = "effects-comp.tsv", .title = "Comp terms", .unit = "% win", .higher = "more wins", .rows = &.{
        .{ .label = "engage into poke", .value = 1.4, .ci = 0.6, .n = 900 },
        .{ .label = "two tanks", .value = 0.3, .ci = 0.5, .n = 1_400 },
        .{ .label = "no magic damage", .value = -2.1, .ci = 0.8, .n = 610 },
    } };

    pub const training: md.Training = .{
        .made = now - 1_200,
        .gpu_seen = now - 600,
        .runs = &.{
            .{ .run = "20261028T120000Z-items", .state = .running, .started = now - 7_200, .args = "item-paths SNAP", .cat = .items, .last = "step 3", .findings = &.{.{ .campaign = "items-a", .text = "The first finished item explains more of gold at 14 min than the boots." }} },
            .{ .run = "20261028T001511Z-golden", .state = .finished, .started = now - 50_000, .host = .gpu_box, .cat = .win, .target = "win", .campaign = "golden", .lab = true, .res = .{ .kind = .run, .dev = .{ .mean = -0.0031, .ci = 0.0017 }, .select = .new_best }, .findings = &.{.{ .campaign = "golden", .text = "Comps matter a little: engage into poke wins more, no magic damage wins less.", .effect = 0 }}, .effects = &.{effect} },
            .{ .run = "20261027T101000Z-lanediff-a", .state = .finished, .started = now - 100_000, .cat = .early, .target = "lanediff14", .campaign = "lanediff-a", .lab = true, .res = .{ .kind = .run, .dev = .{ .mean = -0.012, .ci = 0.004 } }, .result = .{ .removed = .{ .mean = 1.2, .ci = 0.4 }, .err_base = 812, .err_cand = 806, .unit = "gold" } },
            .{ .run = "20261026T090000Z-gold14-a-ref", .state = .finished, .started = now - 190_000, .cat = .early, .target = "gold14", .campaign = "gold14-a", .lab = true, .res = .{ .kind = .run, .dev = .{ .mean = 0, .ci = 0 } } },
        },
        .learned = &.{
            .{ .cat = .win, .line = line("A counter is about the two champions, not the comps. Evidence: docs/model.md, pairs."), .short = line("A counter is about the two champions, not the comps.") },
            .{ .cat = .win, .line = line("Duos add little to the draft. Evidence: duo terms shrunk to 0.8."), .short = line("Duos add little to the draft.") },
            .{ .cat = .win, .line = line("Blue side wins 51%. Evidence: 2 million games."), .short = line("Blue side wins 51%.") },
            .{ .cat = .early, .line = line("Lane gold at 14 min is mostly the two laners' champions. Evidence: team effects."), .short = line("Lane gold at 14 min is mostly the two laners' champions.") },
            .{ .cat = .data, .line = line("Timelines go missing for about 1% of matches."), .short = line("Timelines go missing for about 1% of matches.") },
        },
        .campaigns = &.{},
        .team = .{
            .title = "Team effects on early outcomes, 2026-10-12 (3c)",
            .outcomes = &.{ "gold14", "lanediff14", "cs10" },
            .steps = &.{ "champion", "lane opponent", "both comps" },
            .cells = &.{
                &.{ .{ .mean = 6.1, .ci = 0.4 }, .{ .mean = 9.8, .ci = 0.6 }, .{ .mean = 12.0, .ci = 0.5 } },
                &.{ .{ .mean = 0.3, .ci = 0.2 }, .{ .mean = 2.4, .ci = 0.4 }, .{ .mean = 0.4, .ci = 0.2 } },
                &.{ .{ .mean = 0.1, .ci = 0.2 }, .{ .mean = 0.2, .ci = 0.3 }, null },
            },
            .total = &.{ .{ .mean = 6.5, .ci = 0.5 }, .{ .mean = 12.4, .ci = 0.8 }, .{ .mean = 12.4, .ci = 0.6 } },
        },
        .nn = &.{},
    };

    /// The headline readings only, within the gallery's word budget
    const win_short: md.Models = blk: {
        var w = win;
        w.picks = null;
        w.deciles = &.{};
        w.curve = null;
        w.lane_weight = null;
        w.duo_weight = null;
        var x = models;
        x.win = w;
        x.eval = eval[3..];
        break :blk x;
    };

    fn island(v: View) Models {
        return .{ .tab = .models, .cat = v, .models = &models, .training = &training };
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const states = [_][]const u8{ "all", "win", "early: lane gold", "items: a running run", "draft", "loading", "lab view failed", "another tab: hidden" };
    for (states, 0..) |caption, i| {
        const m = a.create(Models) catch return;
        m.* = switch (i) {
            0 => Demo.island(.all),
            1 => blk: {
                var x = Demo.island(.win);
                x.models = &Demo.win_short;
                x.training = null;
                break :blk x;
            },
            2 => Demo.island(.early),
            3 => Demo.island(.items),
            4 => .{ .tab = .models, .cat = .draft },
            5 => .{ .tab = .models },
            6 => .{ .tab = .models, .cat = .data, .training_failed = true },
            else => .{},
        };
        g.addFill(caption, m.view(g.h));
    }
}

const testing = std.testing;

fn render(a: std.mem.Allocator, m: *Models) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const root = m.view(&h);
    try testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, root, &out.writer);
    return out.written();
}

fn expectHas(s: []const u8, wants: []const []const u8) !void {
    for (wants) |w| if (std.mem.find(u8, s, w) == null) {
        std.debug.print("missing {s} in {s}\n", .{ w, s });
        return error.TestExpectedEqual;
    };
}

test "admin models: category cards, then a category from its card" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = Demo.island(.all);
    try expectHas(try render(a, &m), &.{
        "Shipped model right 55.7% of the time (coin flip 50%). Experiment tuned + weights: 56.1%.",
        "The draft explains 12.4% of lane gold leads at 14 min",
        "A counter is about the two champions, not the comps.",
        "Runs: 1, 1 running",
        "Runs: 1 · 3 findings",
    });
    var ev: tree.Event = .{ .kind = .click, .text = "" };
    m.update(.{ .view = .items }, &ev);
    try testing.expectEqual(View.items, m.toUrl().cat);
    try expectHas(try render(a, &m), &.{"Nothing final yet."});
    m.fromUrl(.{ .tab = .models, .cat = .data });
    try expectHas(try render(a, &m), &.{"Timelines go missing"});
    m.tab = .logs;
    try expectHas(try render(a, &m), &.{" hidden"});
}

test "admin models: the eval read into sentences, charts and tables" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = Demo.island(.win);
    const s = try render(a, &m);
    try expectHas(s, &.{
        "calls the winner of 35,942 new games right 55.7% of the time",
        "we are 49% of the way there",
        "Best experiment, not shipped: tuned + weights, 56.1% (log loss −0.0009 ± 0.0004 against the shipped model).",
        "no better than each champion&#39;s own win rate (difference +0.0002 ± 0.0004, inside noise)",
        "Beats the shipped model beyond noise: tuned + weights (−0.0009 ± 0.0004).",
        "weighs lane matchups 1.6 times",
        "Duo terms are shrunk to 0.80",
        "won 53.4% of 82,404 games: a small but real edge of 3.4 points (about 20 standard errors",
        "from 41.2% to 58.8% and each tenth of games landed within 0.8 points",
        "(~",
        "days of crawling at today&#39;s rate",
        "Run by run: each model against champion win rates",
        "data-c=\"good\"",
        "data-c=\"bad\"",
        "Every eval run (5)",
        "Full draft, held-out games",
        "Comps matter a little",
        "Comp terms",
        "more wins →",
        "−2.10 ± 0.80 % win",
    });
    // tuned + weights and engage into poke; previous model and no magic damage are worse
    try testing.expectEqual(2, std.mem.count(u8, s, "data-c=\"good\""));
    try testing.expectEqual(2, std.mem.count(u8, s, "data-c=\"bad\""));
    const empty: md.Models = .{ .now = 0, .eval = &.{}, .win = null, .report = .{ .blocks = &.{} }, .matches_per_day = null };
    m.models = &empty;
    try expectHas(try render(a, &m), &.{"No eval report yet."});
}

test "admin models: early outcomes, the best lab run, loading and failures" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = Demo.island(.early);
    try expectHas(try render(a, &m), &.{
        "Who is in the game explains 12.4% ± 0.8 of the differences in lane gold lead at 14 min",
        "The biggest single part: champion (9.8%).",
        "Adds nothing measurable: both comps.",
        "Lane gold lead at 14 min: lanediff-a",
        "1.2% ± 0.4",
    });
    var ev: tree.Event = .{ .kind = .click, .text = "" };
    m.update(.{ .outcome = 2 }, &ev);
    const s = try render(a, &m);
    try expectHas(s, &.{"differences in CS at 10 min beyond"});
    // The reference run (ci 0) is never the best
    try testing.expect(std.mem.find(u8, s, "gold14-a") == null);

    var w: Models = .{ .tab = .models, .cat = .win };
    try expectHas(try render(a, &w), &.{"Loading"});
    w.models_failed = true;
    w.training_failed = true;
    try expectHas(try render(a, &w), &.{ "models.bin) didn&#39;t load", "training/training.bin) didn&#39;t load" });
    w.cat = .draft;
    try testing.expect(std.mem.find(u8, try render(a, &w), "didn't load") == null);
}

test "admin models: short run names" {
    try testing.expectEqualStrings("golden", shortRun("20261024T001511Z-golden"));
    try testing.expectEqualStrings("gold14-a-ref", shortRun("20261012T2222Z-gold14-a-ref"));
    try testing.expectEqualStrings("plain-name", shortRun("plain-name"));
}
