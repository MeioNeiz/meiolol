//! AdminLab: the Models tab's Neural nets and Lab campaigns, an island of its own between
//! AdminModels and AdminRuns (ui-adminlab.wasm: with them ui-adminruns.wasm was 13 KB over
//! its budget). It fetches training/training.bin once it shows. All: the Neural nets and
//! Lab campaigns cards. Neural nets: docs/nn-results per question. Lab campaigns: each
//! campaign's ideas and digest (AdminRuns lists the lab's runs below)
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const prose = @import("prose.zig");
const Gallery = @import("gallery.zig").Gallery;
const md = @import("modelsdata.zig");
const ap = @import("adminpage.zig");
const am = @import("adminmodels.zig");
const ar = @import("adminruns.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Text = tree.Text;
const View = am.View;
const dec = am.dec;
const count = am.count;

pub const name = "AdminLab";
pub const scope = .{".c-adlab"};
pub const sel = "[data-island=adminlab]";

/// Today's model's edge over a coin flip, log loss per game: the scale for a net's gain
/// (win-draft on snap-20261017T1320Z's folds: ln 2 - 0.68687)
const nn_edge = 0.0063;

pub const Lab = struct {
    tab: ap.Tab = .overview,
    cat: View = .all,
    /// The wasm's
    training: ?*const md.Training = null,
    failed: bool = false,
    /// This island's code, on its root for dom.lazyLoad
    js: []const u8 = "",
    wasm: []const u8 = "",

    /// AdminModels' keys: it owns the picker, this island follows (its cards set `cat`)
    pub const Url = struct { tab: ap.Tab = .overview, cat: View = .all };

    pub const Msg = union(enum) { view: View };

    pub fn toUrl(m: *const Lab) Url {
        return .{ .tab = m.tab, .cat = m.cat };
    }

    pub fn fromUrl(m: *Lab, u: Url) void {
        m.tab = u.tab;
        m.cat = u.cat;
    }

    pub fn update(m: *Lab, msg: Msg, ev: *tree.Event) void {
        _ = ev;
        switch (msg) {
            .view => |v| m.cat = v,
        }
    }

    pub fn shows(m: *const Lab) bool {
        return m.tab == .models and (m.cat == .all or m.cat == .nn or m.cat == .lab);
    }

    pub fn view(m: *Lab, h: *H) N {
        const on = m.shows();
        // c-adruns: AdminRuns' line chart styles
        return h.div(.{ .class = "c-admodels c-adruns c-adlab", .data_island = "adminlab", .data_js = m.js, .data_wasm = m.wasm, .hidden = !on }, .{
            if (on) body(m, h) else null,
        });
    }
};

const W = struct {
    pub const failed = plain("Nets and campaigns (training/training.bin) didn't load: reload the page to try again");
    pub const nn = plain("Neural nets");
    pub const nn_lead = Phrase("Can a neural net call the winner from the draft better than today's model (champion strength in its role plus ally duos and matchups, as the site scores drafts)? Each number is the change in log loss per game against the model named, with its 95% range: below zero is better. Today's model beats a coin flip by about {e:text} a game. Dev results score older games on newer ones; a test look is the one check per model on held-back games.");
    pub const nn_none = plain("No results yet (docs/nn-results/).");
    pub const nn_learnt = plain("What we learnt");
    pub const nn_learnt_lead = plain("Final findings the results link to (docs/learned.md).");
    pub const nn_unlinked = plain("None linked yet (the learned column in docs/nn-results).");
    pub const in_full = plain("In full, with evidence");
    pub const nn_src = Phrase("docs/nn-results/{k:text}.tsv");
    pub const c_model = plain("Model");
    pub const c_vs = plain("Against");
    pub const c_block = plain("Measured on");
    pub const c_diff = plain("Δ log loss");
    pub const c_verdict = plain("Verdict");
    pub const c_seeds = plain("Seeds");
    pub const c_games = plain("Games");
    pub const c_source = plain("Source");
    pub const test_look = plain("test look");
    pub const better = plain("better");
    pub const worse = plain("worse");
    pub const nn_cap = plain("Change in log loss per game, 95% intervals. Blue: clear of zero.");
    pub const by_share = plain("Log loss by share of fit games");
    pub const by_games = plain("Log loss by fit games");
    pub const scaling_lead = plain("Log loss as the models see more games; lower is better.");
    pub const scaling_vs = plain("Against the comparison model at each size");
    pub const scaling_cap = plain("Change in log loss per game, 95% intervals. A gap that shrinks as games grow would mean more data helps the net more.");
    pub const projected = plain(" (projected)");
    pub const single = Phrase(" (single {a:text} to {b:text})");

    pub const lab = plain("Lab campaigns");
    pub const lab_lead = plain("Each campaign is an agent improving one model inside the lab's rules (docs/lab-agent.md): ideas it tried, what held up.");
    pub const no_campaigns = plain("No campaigns yet.");
    pub const campaigns = Phrase("Campaigns: {n:count}");
    pub const c_runs = Phrase("Runs: {n:count}");
    pub const ideas = Phrase(" · ideas: {n:count} (");
    pub const undecided = plain("none decided");
    pub const new_best = Phrase(" · new best on held-back games: {n:count}");
    pub const digest = plain("Digest");
    pub const reference = plain("reference");
    pub const runs_n = Phrase("Runs: {n:count}");
    pub const runs_live = Phrase("Runs: {n:count}, {k:count} running");
};

fn body(m: *Lab, h: *H) N {
    if (m.failed and m.training == null) return h.p(.{ .class = "lead", .role = "status" }, .{W.failed});
    // AdminModels says it is loading
    const t = m.training orelse return .none;
    return switch (m.cat) {
        .all => h.div(.{ .class = "cards" }, .{ nnCard(m, h, t), labCard(m, h, t) }),
        .nn => nnView(m, h, t),
        .lab => labView(m, h, t),
        else => .none,
    };
}

// ---------- All: the Neural nets and Lab campaigns cards ----------

fn catCard(m: *Lab, h: *H, v: View, kids: []const N) N {
    return card.view(h, .{}, &.{h.div(.{ .class = "cat" }, .{
        h.h3(.{}, .{h.button(.{ .type = "button", .on_click = h.on(m, .{ .view = v }) }, .{am.view_names.get(v)})}),
        kids,
    })});
}

fn nnCard(m: *Lab, h: *H, t: *const md.Training) N {
    return catCard(m, h, .nn, &.{if (t.nn.len == 0) h.p(.{ .class = "lead" }, .{W.nn_none}) else headlines(h, t, false)});
}

fn labCard(m: *Lab, h: *H, t: *const md.Training) N {
    var n: u32 = 0;
    var live: u32 = 0;
    for (t.runs) |r| if (r.lab) {
        n += 1;
        if (r.state == .running or r.state == .paused) live += 1;
    };
    return catCard(m, h, .lab, &.{
        h.p(.{ .class = "headline" }, .{W.campaigns.with(h, .{ .n = t.campaigns.len })}),
        h.p(.{ .class = "sub" }, .{if (live > 0) W.runs_live.with(h, .{ .n = n, .k = live }) else W.runs_n.with(h, .{ .n = n })}),
    });
}

// ---------- Neural nets ----------

const nn_order = [_][]const u8{ "nets", "structured", "comp", "embx", "pretrain", "stack", "context", "player", "ldai", "gains", "scaling" };

fn nnRank(k: []const u8) usize {
    return ar.indexOf(&nn_order, k) orelse nn_order.len - 1;
}

fn vsName(vs: []const u8) []const u8 {
    const names = [_][2][]const u8{ .{ "win-draft", "today's model" }, .{ "ratings", "ratings" }, .{ "win-comp", "win-comp" }, .{ "base", "champion win rates" } };
    for (names) |x| if (std.mem.eql(u8, x[0], vs)) return x[1];
    return vs;
}

fn blockName(b: []const u8) []const u8 {
    const names = [_][2][]const u8{ .{ "folds", "5 forward rounds" }, .{ "dev-val", "newest dev games" }, .{ "test", "test look" }, .{ "random", "random split" }, .{ "projection", "projection" } };
    for (names) |x| if (std.mem.eql(u8, x[0], b)) return x[1];
    return if (b.len > 0) b else "–";
}

const Verdict = struct { text: []const u8, k: badge.Kind };

/// Better, tie or worse than the row's comparison model, from the 95% interval
fn verdict(h: *H, r: md.NnRow) Verdict {
    const who = vsName(r.vs);
    const ci = r.ci orelse return .{ .text = "no interval", .k = .neutral };
    if (r.diff + ci < 0) return .{ .text = h.fmt("better than {s}", .{who}), .k = .us };
    if (r.diff - ci > 0) return .{ .text = h.fmt("worse than {s}", .{who}), .k = .them };
    return .{ .text = h.fmt("tie with {s} (not detected)", .{who}), .k = .neutral };
}

fn signed(h: *H, v: f32, comptime places: u4) []const u8 {
    return h.fmt("{s}{s}", .{ if (v < 0) "−" else "+", dec(h, @abs(v), places) });
}

fn nnDiff(h: *H, r: md.NnRow) []const u8 {
    return if (r.ci) |c| h.fmt("{s} ± {s}", .{ signed(h, r.diff, 5), dec(h, c, 5) }) else signed(h, r.diff, 5);
}

/// The row that best answers a question: a test look first, then the folds, dev-val,
/// random; among those the comparison with today's model, first in the file (never the
/// best diff: in a breakdown by subset that would pick the luckiest subset)
fn headline(f: md.NnFile) ?md.NnRow {
    const ranks = [_][]const u8{ "test", "folds", "dev-val", "random" };
    var best: ?md.NnRow = null;
    var best_rank: usize = 99;
    for (f.rows) |r| {
        if (std.mem.eql(u8, r.vs, "-")) continue;
        const b = ar.indexOf(&ranks, r.block) orelse continue;
        const rank = b * 2 + @intFromBool(!std.mem.eql(u8, r.vs, "win-draft"));
        if (rank < best_rank) {
            best = r;
            best_rank = rank;
        }
    }
    return best;
}

fn sortedFiles(h: *H, t: *const md.Training) []const md.NnFile {
    const out = h.mem.dupe(md.NnFile, t.nn) catch {
        h.oom = true;
        return t.nn;
    };
    // Insertion sort: a dozen files, and std.mem.sort's code is about 8 KB of wasm
    for (1..out.len) |i| {
        var j = i;
        while (j > 0 and nnRank(out[j].key) < nnRank(out[j - 1].key)) : (j -= 1) std.mem.swap(md.NnFile, &out[j], &out[j - 1]);
    }
    return out;
}

/// One line per question: its headline row's verdict; full: with model, block and numbers,
/// else the size against today's model's edge
fn headlines(h: *H, t: *const md.Training, full: bool) N {
    var l = h.list();
    for (sortedFiles(h, t), 0..) |f, i| {
        if (std.mem.eql(u8, f.key, "scaling")) continue;
        const r = headline(f) orelse continue;
        const v = verdict(h, r);
        const look = if (std.mem.eql(u8, r.block, "test")) badge.view(h, .few, .{W.test_look}) else N.none;
        const size: ?[]const u8 = if (std.mem.eql(u8, r.vs, "win-draft") and r.ci != null and @abs(r.diff) > r.ci.?)
            h.fmt(" (log loss {s} {s} a game, {s}% of its edge over a coin flip)", .{ dec(h, @abs(r.diff), 4), if (r.diff < 0) "lower" else "higher", dec(h, 100 * @abs(r.diff) / nn_edge, 0) })
        else
            null;
        l.add(if (full) h.li(.{ .key = i }, .{
            h.b(.{}, .{f.title}), h.fmt(" {s}: ", .{r.model}), badge.view(h, v.k, .{v.text}), h.fmt(" on {s}, {s} ", .{ blockName(r.block), nnDiff(h, r) }), look,
        }) else h.li(.{ .key = i }, .{
            h.fmt("{s} ", .{f.title}), badge.view(h, v.k, .{v.text}), if (size) |s| h.span(.{ .class = "sub" }, .{s}) else null, " ", look,
        }));
    }
    return h.ul(.{ .class = "readings" }, .{l.done()});
}

/// learned.md items a question's rows name in their learned cell, each once
fn nnLearned(h: *H, t: *const md.Training, files: []const md.NnFile) []const md.Learned {
    var seen: std.ArrayList(u16) = .empty;
    var out: std.ArrayList(md.Learned) = .empty;
    for (files) |f| for (f.rows) |r| for (r.learned) |i| {
        if (i >= t.learned.len or std.mem.findScalar(u16, seen.items, i) != null) continue;
        seen.append(h.mem, i) catch {};
        out.append(h.mem, t.learned[i]) catch {};
    };
    return out.items;
}

fn nnView(m: *Lab, h: *H, t: *const md.Training) N {
    _ = m;
    const files = sortedFiles(h, t);
    const intro = card.view(h, .{}, &.{
        card.head(h, W.nn, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.nn_lead.with(h, .{ .e = dec(h, nn_edge, 4) })}),
        if (files.len == 0) h.p(.{ .class = "lead" }, .{W.nn_none}) else headlines(h, t, true),
    });
    if (files.len == 0) return h.div(.{ .class = "tab" }, .{intro});
    const learnt = nnLearned(h, t, files);
    var secs = h.list();
    for (files, 0..) |f, i| secs.add(h.div(.{ .key = i, .class = "tab" }, .{if (std.mem.eql(u8, f.key, "scaling")) scaling(h, f) else question(h, t, f)}));
    return h.div(.{ .class = "tab" }, .{
        intro,
        card.view(h, .{}, &.{
            card.head(h, W.nn_learnt, null, &.{}),
            h.p(.{ .class = "lead" }, .{W.nn_learnt_lead}),
            if (learnt.len == 0) h.p(.{ .class = "lead" }, .{W.nn_unlinked}) else am.learnedList(h, learnt, true),
            if (learnt.len > 0) h.el(.details, .{}, .{ h.el(.summary, .{}, .{W.in_full}), am.learnedList(h, learnt, false) }) else .none,
        }),
        secs.done(),
    });
}

fn question(h: *H, t: *const md.Training, f: md.NnFile) N {
    var rows = h.list();
    var forest: std.ArrayList(am.FRow) = .empty;
    for (f.rows, 0..) |r, i| {
        const v = verdict(h, r);
        const test_ = std.mem.eql(u8, r.block, "test");
        rows.add(h.tr(.{ .key = i }, .{
            h.th(.{}, .{ r.model, if (r.note.len > 0) h.span(.{ .class = "sub" }, .{h.fmt(" {s}", .{r.note})}) else null }),
            h.td(.{}, .{vsName(r.vs)}),
            h.td(.{}, .{if (test_) badge.view(h, .few, .{W.test_look}) else h.span(.{}, .{blockName(r.block)})}),
            h.td(.{ .class = "num nw" }, .{nnDiff(h, r)}),
            h.td(.{}, .{badge.view(h, v.k, .{v.text})}),
            h.td(.{ .class = "num" }, .{if (r.seeds) |s| h.fmt("{s}{s}", .{ count(h, s), if (r.seed_lo != null and r.seed_hi != null) W.single.with(h, .{ .a = signed(h, r.seed_lo.?, 5), .b = signed(h, r.seed_hi.?, 5) }).s else "" }) else "–"}),
            h.td(.{ .class = "num" }, .{if (r.games) |g| count(h, g) else "–"}),
            h.td(.{ .class = "src" }, .{if (r.source.len > 0) r.source else "–"}),
        }));
        if (!std.mem.eql(u8, r.vs, "-") and !std.mem.eql(u8, r.block, "projection")) forest.append(h.mem, .{
            .label = h.fmt("{s} vs {s}, {s}", .{ r.model, vsName(r.vs), r.block }),
            .v = r.diff,
            .ci = r.ci orelse 0,
        }) catch {};
    }
    const learnt = nnLearned(h, t, &.{f});
    return h.div(.{ .class = "tab" }, .{
        card.view(h, .{}, &.{
            card.head(h, .{ .s = f.title }, null, &.{}),
            h.p(.{ .class = "lead" }, .{W.nn_src.with(h, .{ .k = f.key })}),
            h.div(.{ .class = "tw" }, .{h.table(.{}, .{
                h.thead(.{}, .{h.tr(.{}, .{
                    h.th(.{}, .{W.c_model}),
                    h.th(.{}, .{W.c_vs}),
                    h.th(.{}, .{W.c_block}),
                    h.th(.{ .class = "num", .data_answer = true }, .{W.c_diff}),
                    h.th(.{}, .{W.c_verdict}),
                    h.th(.{ .class = "num" }, .{W.c_seeds}),
                    h.th(.{ .class = "num" }, .{W.c_games}),
                    h.th(.{}, .{W.c_source}),
                })}),
                h.tbody(.{}, .{rows.done()}),
            })}),
            if (learnt.len > 0) am.learnedList(h, learnt, true) else .none,
        }),
        if (forest.items.len > 0) am.forest(h, .{ .s = f.title }, W.nn_cap, forest.items, .{ .num = .ll5, .left = W.better, .right = W.worse }) else null,
    });
}

/// Absolute log loss by fit games (a line per model, projections apart) and each model's
/// difference at each size
fn scaling(h: *H, f: md.NnFile) N {
    var charts = h.list();
    for ([_]bool{ true, false }) |share| {
        var xs: std.ArrayList(f32) = .empty;
        var names: std.ArrayList([]const u8) = .empty;
        for (f.rows) |r| {
            if (!std.mem.eql(u8, r.vs, "-")) continue;
            const x = fitGames(r.fit_games, share) orelse continue;
            if (std.mem.findScalar(f32, xs.items, x) == null) xs.append(h.mem, x) catch {};
            const n = lineName(h, r);
            if (ar.indexOf(names.items, n) == null) names.append(h.mem, n) catch {};
        }
        if (xs.items.len == 0) continue;
        for (1..xs.items.len) |i| {
            var j = i;
            while (j > 0 and xs.items[j] < xs.items[j - 1]) : (j -= 1) std.mem.swap(f32, &xs.items[j], &xs.items[j - 1]);
        }
        var lines: std.ArrayList(ar.Line) = .empty;
        for (names.items, 0..) |n, k| {
            const ys = h.mem.alloc(f32, xs.items.len) catch return ar.oom(h);
            @memset(ys, std.math.nan(f32));
            for (f.rows) |r| {
                if (!std.mem.eql(u8, r.vs, "-") or !std.mem.eql(u8, lineName(h, r), n)) continue;
                const x = fitGames(r.fit_games, share) orelse continue;
                ys[std.mem.findScalar(f32, xs.items, x).?] = r.diff;
            }
            lines.append(h.mem, .{ .name = n, .ys = ys, .s = @intCast(k % 6) }) catch {};
        }
        charts.add(ar.lineChart(h, if (share) W.by_share else W.by_games, xs.items, lines.items, .{ .share = share }));
    }
    var rel: std.ArrayList(am.FRow) = .empty;
    for (f.rows) |r| if (!std.mem.eql(u8, r.vs, "-")) rel.append(h.mem, .{
        .label = h.fmt("{s} vs {s}, {s}", .{ r.model, vsName(r.vs), if (r.fit_games.len > 0) r.fit_games else "?" }),
        .v = r.diff,
        .ci = r.ci orelse 0,
    }) catch {};
    if (rel.items.len > 0) charts.add(am.forest(h, W.scaling_vs, W.scaling_cap, rel.items, .{ .num = .ll5, .left = W.better, .right = W.worse }));
    return card.view(h, .{}, &.{
        card.head(h, .{ .s = f.title }, null, &.{}),
        h.p(.{ .class = "lead" }, .{ W.nn_src.with(h, .{ .k = f.key }), ". ", W.scaling_lead }),
        h.div(.{ .class = "charts" }, .{charts.done()}),
    });
}

fn lineName(h: *H, r: md.NnRow) []const u8 {
    return if (std.mem.eql(u8, r.block, "projection")) h.fmt("{s}{s}", .{ r.model, W.projected.s }) else r.model;
}

/// "25%" when share, "400000" else; null for the other kind or no number
fn fitGames(s: []const u8, share: bool) ?f32 {
    const t = std.mem.trim(u8, s, " ");
    const pct = std.mem.endsWith(u8, t, "%");
    if (pct != share) return null;
    const v = std.fmt.parseFloat(f32, if (pct) t[0 .. t.len - 1] else t) catch return null;
    return if (ar.finite(v)) v else null;
}

// ---------- Lab campaigns ----------

fn labView(m: *Lab, h: *H, t: *const md.Training) N {
    _ = m;
    var cards = h.list();
    for (t.campaigns, 0..) |c, i| cards.add(h.div(.{ .key = i }, .{campaign(h, c)}));
    return h.div(.{ .class = "tab" }, .{
        card.sechead(h, W.lab, null, &.{}),
        h.p(.{ .class = "lead" }, .{W.lab_lead}),
        if (t.campaigns.len == 0) h.p(.{ .class = "lead" }, .{W.no_campaigns}) else h.div(.{ .class = "charts" }, .{cards.done()}),
    });
}

fn campaign(h: *H, c: md.Campaign) N {
    var by: std.EnumArray(md.HypStatus, u32) = .initFill(0);
    for (c.hyps) |x| by.set(x.status, by.get(x.status) + 1);
    var sub: std.ArrayList(u8) = .empty;
    sub.appendSlice(h.mem, W.c_runs.with(h, .{ .n = c.runs }).s) catch {};
    if (c.hyps.len > 0) {
        sub.appendSlice(h.mem, W.ideas.with(h, .{ .n = c.hyps.len - by.get(.reference) }).s) catch {};
        var any = false;
        for ([_]md.HypStatus{ .confirmed, .refuted, .parked, .superseded }) |s| {
            if (by.get(s) == 0) continue;
            sub.print(h.mem, "{s}{s} {t}", .{ if (any) ", " else "", count(h, by.get(s)), s }) catch {};
            any = true;
        }
        if (!any) sub.appendSlice(h.mem, W.undecided.s) catch {};
        sub.append(h.mem, ')') catch {};
    }
    if (c.new_best > 0) sub.appendSlice(h.mem, W.new_best.with(h, .{ .n = c.new_best }).s) catch {};
    var hyps = h.list();
    for (c.hyps, 0..) |x, i| {
        const k: badge.Kind = switch (x.status) {
            .confirmed => .us,
            .rejected, .parked => .few,
            else => .neutral,
        };
        hyps.add(h.li(.{ .key = i }, .{ badge.view(h, k, .{if (x.status == .reference) W.reference.s else if (x.word.len > 0) x.word else "?"}), " ", x.text }));
    }
    return card.view(h, .{}, &.{
        card.head(h, .{ .s = c.name }, null, &.{}),
        h.p(.{ .class = "sub" }, .{sub.items}),
        if (c.hyps.len > 0) h.ul(.{ .class = "hyps" }, .{hyps.done()}) else .none,
        if (c.digest) |d| h.el(.details, .{}, .{ h.el(.summary, .{}, .{W.digest}), prose.view(h, d, .{ .id_prefix = "lc-", .top = 3 }) }) else .none,
    });
}

pub const css =
    \\@layer components {
    \\  .c-adlab .hyps { margin: var(--sp-2) 0 0; padding-inline-start: var(--sp-4); display: grid; gap: var(--sp-1); font-size: var(--fs-s); }
    \\  .c-adlab td.src { font-family: var(--mono, ui-monospace, monospace); font-size: var(--fs-xs); overflow-wrap: anywhere; }
    \\}
    \\
;

pub const Demo = struct {
    fn line(comptime s: []const u8) prose.Line {
        return &[_]prose.Run{.{ .s = s }};
    }

    pub const campaigns = [_]md.Campaign{.{
        .name = "lanediff-a",
        .runs = 6,
        .new_best = 1,
        .hyps = &.{
            .{ .id = "H0", .status = .reference, .word = "reference", .text = "Baseline: champion averages." },
            .{ .id = "H1", .status = .confirmed, .word = "confirmed", .text = "The lane opponent's champion adds to lane gold." },
            .{ .id = "H2", .status = .refuted, .word = "refuted", .text = "Jungle proximity matters at 14 min." },
        },
        .digest = .{ .blocks = &.{.{ .para = line("Lane opponent terms carry the gain; the rest is noise.") }} },
    }};

    pub const nn = [_]md.NnFile{
        .{ .key = "nets", .title = "Does a net beat today's model?", .rows = &.{
            .{ .model = "set net", .vs = "win-draft", .block = "folds", .diff = -0.00041, .ci = 0.00022, .seeds = 6, .games = 1_200_000, .source = "nx-setnet", .learned = &.{0} },
            .{ .model = "set net", .vs = "win-draft", .block = "test", .diff = 0.00008, .ci = 0.0003, .games = 120_000 },
        } },
        .{ .key = "scaling", .title = "More games", .rows = &.{
            .{ .model = "set net", .vs = "-", .block = "folds", .diff = 0.6889, .fit_games = "25%" },
            .{ .model = "set net", .vs = "-", .block = "folds", .diff = 0.6878, .fit_games = "50%" },
            .{ .model = "set net", .vs = "-", .block = "folds", .diff = 0.6871, .fit_games = "100%" },
            .{ .model = "set net", .vs = "win-draft", .block = "folds", .diff = -0.0002, .ci = 0.0003, .fit_games = "100%" },
        } },
    };

    fn island(v: View) Lab {
        return .{ .tab = .models, .cat = v, .training = &ar.Demo.training };
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const states = [_][]const u8{ "all: the nets and lab cards", "neural nets", "lab campaigns", "training.bin failed", "an outcome: hidden" };
    for (states, 0..) |caption, i| {
        const m = a.create(Lab) catch return;
        m.* = switch (i) {
            0 => Demo.island(.all),
            1 => Demo.island(.nn),
            2 => Demo.island(.lab),
            3 => .{ .tab = .models, .cat = .nn, .failed = true },
            else => Demo.island(.early),
        };
        g.addFill(caption, m.view(g.h));
    }
}

const testing = std.testing;

fn render(a: std.mem.Allocator, m: *Lab) ![]const u8 {
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

test "admin lab: All's cards, the nets, the campaigns" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = Demo.island(.all);
    try expectHas(try render(a, &m), &.{ "Neural nets", "tie with today&#39;s model (not detected)", "Campaigns: 1", "Runs: 4" });
    var ev: tree.Event = .{ .kind = .click, .text = "" };
    m.update(.{ .view = .nn }, &ev);
    try testing.expectEqual(View.nn, m.toUrl().cat);
    const s = try render(a, &m);
    try expectHas(s, &.{
        "set net: ",
        "on test look, +0.00008 ± 0.00030",
        "A counter is about the two champions",
        "Log loss by share of fit games",
        "−0.00041 ± 0.00022",
        "Against the comparison model at each size",
    });
    m.cat = .lab;
    try expectHas(try render(a, &m), &.{ "Runs: 6 · ideas: 2 (1 confirmed, 1 refuted) · new best on held-back games: 1", "Jungle proximity", "Digest" });
    m.cat = .early;
    try testing.expect(!m.shows());
}
