//! The UI's component system (docs/plan/ui/stack.md): components build a typed node tree
//! with `H`; html.zig writes it on the server, ui.wasm patches the DOM from it, check.zig
//! lints it in plain tests. Std, tpl and core (std only), so the same files build for
//! the backend and for wasm32.
const std = @import("std");

pub const tree = @import("tree.zig");
pub const html = @import("html.zig");
pub const fmt = @import("fmt.zig");
pub const phrase = @import("phrase.zig");
pub const check = @import("check.zig");
pub const url = @import("url.zig");
pub const urls = @import("urls.zig");
pub const data = @import("data.zig");
pub const tokens = @import("tokens.zig");
pub const css = @import("css.zig");
pub const diff = @import("diff.zig");
pub const island = @import("island.zig");
pub const tiers = @import("tiers.zig");
pub const FakeDom = @import("fakedom.zig").Fake;
pub const gallery = @import("gallery.zig");

pub const button = @import("button.zig");
pub const chip = @import("chip.zig");
pub const badge = @import("badge.zig");
pub const segmented = @import("segmented.zig");
pub const tabs = @import("tabs.zig");
pub const card = @import("card.zig");
pub const select = @import("select.zig");
pub const toggletip = @import("toggletip.zig");
pub const stat = @import("stat.zig");
pub const delta = @import("delta.zig");
pub const bar = @import("bar.zig");
pub const kda = @import("kda.zig");
pub const strip = @import("strip.zig");
pub const split = @import("split.zig");
pub const role = @import("role.zig");
pub const champ = @import("champ.zig");
pub const rolepicker = @import("rolepicker.zig");
pub const filterbar = @import("filterbar.zig");
pub const champsearch = @import("champsearch.zig");
pub const champhead = @import("champhead.zig");
pub const matchbrief = @import("matchbrief.zig");
pub const matchstrip = @import("matchstrip.zig");
pub const champlist = @import("champlist.zig");
pub const draftboard = @import("draftboard.zig");
pub const champselect = @import("champselect.zig");
pub const teamrows = @import("teamrows.zig");
pub const compview = @import("compview.zig");
pub const loadscreen = @import("loadscreen.zig");
pub const gamescreen = @import("gamescreen.zig");
pub const postgame = @import("postgame.zig");
pub const signin = @import("signin.zig");
pub const toshell = @import("toshell.zig");
pub const practice = @import("practice.zig");
pub const app = @import("app.zig");
pub const site = @import("site.zig");
pub const table = @import("table.zig");
pub const chart = @import("chart.zig");
pub const dotplot = @import("dotplot.zig");
pub const trend = @import("trend.zig");
pub const timechart = @import("timechart.zig");
pub const histogram = @import("histogram.zig");
pub const lane = @import("lane.zig");
pub const timeline = @import("timeline.zig");
pub const gamedata = @import("gamedata.zig");
pub const testerdata = @import("testerdata.zig");
pub const testerpage = @import("testerpage.zig");
pub const testercand = @import("testercand.zig");
pub const modelbadge = @import("modelbadge.zig");
pub const homepage = @import("homepage.zig");
pub const yourpage = @import("yourpage.zig");
pub const yourviews = @import("yourviews.zig");
pub const yourtime = @import("yourtime.zig");
pub const gametrend = @import("gametrend.zig");
pub const recordtile = @import("recordtile.zig");
pub const highlights = @import("highlights.zig");
pub const yourlookup = @import("yourlookup.zig");
pub const yourfriends = @import("yourfriends.zig");
pub const forget = @import("forget.zig");
pub const account = @import("account.zig");
pub const scopechip = @import("scopechip.zig");
pub const today = @import("today.zig");
pub const idlookup = @import("idlookup.zig");
pub const sitesearch = @import("sitesearch.zig");
pub const learndata = @import("learndata.zig");
pub const dailydata = @import("dailydata.zig");
pub const pooldata = @import("pooldata.zig");
pub const admindata = @import("admindata.zig");
pub const modelsdata = @import("modelsdata.zig");
pub const accountsdata = @import("accountsdata.zig");
pub const adminpage = @import("adminpage.zig");
pub const admincharts = @import("admincharts.zig");
pub const admintraffic = @import("admintraffic.zig");
pub const admindeploys = @import("admindeploys.zig");
pub const adminops = @import("adminops.zig");
pub const adminmodels = @import("adminmodels.zig");
pub const notesdata = @import("notesdata.zig");
pub const notes = @import("notes.zig");
pub const noteslist = @import("noteslist.zig");
pub const alertband = @import("alertband.zig");
pub const actionbutton = @import("actionbutton.zig");
pub const logview = @import("logview.zig");
pub const steptimeline = @import("steptimeline.zig");
pub const prose = @import("prose.zig");
pub const textpage = @import("textpage.zig");
pub const aucchart = @import("aucchart.zig");
pub const learnpage = @import("learnpage.zig");
pub const dailypage = @import("dailypage.zig");
pub const dailydays = @import("dailydays.zig");
pub const dailyseat = @import("dailyseat.zig");
pub const champrolepicker = @import("champrolepicker.zig");
pub const poolslots = @import("poolslots.zig");
pub const heatgrid = @import("heatgrid.zig");
pub const poolpage = @import("poolpage.zig");
pub const poolgrid = @import("poolgrid.zig");
pub const puzzle = @import("puzzle.zig");
pub const guess = @import("guess.zig");
pub const choice = @import("choice.zig");
pub const rankstrip = @import("rankstrip.zig");
pub const draftflow = @import("draftflow.zig");
pub const reasons = @import("reasons.zig");
pub const candlist = @import("candlist.zig");
pub const yourlist = @import("yourlist.zig");
pub const gamepage = @import("gamepage.zig");
pub const gamehead = @import("gamehead.zig");
pub const gamerow = @import("gamerow.zig");
pub const dayhead = @import("dayhead.zig");
pub const resultstrip = @import("resultstrip.zig");
pub const playerbar = @import("playerbar.zig");
pub const profilesum = @import("profilesum.zig");
pub const inspector = @import("inspector.zig");
pub const scoreboard = @import("scoreboard.zig");
pub const laneduel = @import("laneduel.zig");
pub const itemrow = @import("itemrow.zig");
pub const gamestrip = @import("gamestrip.zig");
pub const minimap = @import("minimap.zig");
pub const objicon = @import("objicon.zig");
pub const versus = @import("versus.zig");
pub const spark = @import("spark.zig");
pub const art = @import("art.zig");
pub const skillgrid = @import("skillgrid.zig");
pub const itempath = @import("itempath.zig");
pub const runetree = @import("runetree.zig");
pub const buildpanel = @import("buildpanel.zig");
pub const champpage = @import("champpage.zig");
pub const champrank = @import("champrank.zig");
pub const matchpage = @import("matchpage.zig");
pub const finder = @import("finder.zig");
pub const matchgrid = @import("matchgrid.zig");
pub const violin = @import("violin.zig");
pub const changeline = @import("changeline.zig");
pub const patchhead = @import("patchhead.zig");
pub const patchpage = @import("patchpage.zig");

/// Components whose CSS ships (css.join): add one when a page first uses it
pub const components = .{ button, chip, badge, segmented, card, toggletip, strip, role, champ, rolepicker, champsearch, champhead, matchbrief, matchstrip, champlist, table, chart, dotplot, trend, histogram, art, skillgrid, itempath, runetree, buildpanel, tabs, site, sitesearch, filterbar, champpage, kda, timeline, versus, objicon, minimap, gamestrip, inspector, gamehead, gamerow, spark, stat, scoreboard, laneduel, itemrow, gamepage, lane, matchpage, matchgrid, champrolepicker, finder, delta, bar, violin, tiers, guess, puzzle, choice, reasons, candlist, learnpage, split, draftboard, draftflow, dailypage, dailyseat, dailydays, changeline, patchhead, patchpage, poolslots, heatgrid, poolpage, poolgrid, dayhead, resultstrip, playerbar, profilesum, recordtile, highlights, gametrend, yourpage, yourviews, yourtime, yourlookup, yourfriends, forget, idlookup, today, homepage, prose, textpage, aucchart, account, scopechip };

/// Every component, in the gallery's order
pub const all = .{ button, chip, scopechip, badge, segmented, tabs, card, select, toggletip, stat, delta, bar, kda, strip, split, alertband, actionbutton, logview, steptimeline, prose, textpage, modelbadge, role, champ, site, sitesearch, rolepicker, filterbar, champsearch, champhead, matchbrief, matchstrip, champlist, draftboard, champselect, teamrows, compview, loadscreen, gamescreen, postgame, signin, practice, app, table, chart, dotplot, trend, timechart, histogram, aucchart, lane, timeline, spark, art, skillgrid, itempath, runetree, buildpanel, versus, objicon, minimap, gamestrip, inspector, gamehead, gamerow, scoreboard, laneduel, itemrow, gamepage, guess, puzzle, choice, rankstrip, draftflow, reasons, candlist, champrolepicker, poolslots, heatgrid, matchgrid, finder, violin, learnpage, dailypage, dailyseat, dailydays, changeline, patchhead, patchpage, poolpage, poolgrid, dayhead, resultstrip, playerbar, profilesum, recordtile, highlights, gametrend, yourpage, yourviews, yourtime, yourlookup, yourfriends, forget, idlookup, today, homepage, account, testerpage, testercand, notes, noteslist, adminpage, admincharts, admintraffic, adminops, adminmodels };

pub const H = tree.H;
pub const N = tree.N;
pub const Tree = tree.Tree;
pub const Text = tree.Text;
pub const Event = tree.Event;
pub const Phrase = phrase.Phrase;
pub const plain = phrase.plain;

test {
    std.testing.refAllDecls(@This());
    _ = @import("tests.zig");
    _ = @import("island_test.zig");
    _ = @import("tiers_test.zig");
    _ = @import("patchpage_test.zig");
    _ = @import("dailypage_test.zig");
    _ = @import("poolpage_test.zig");
    _ = @import("testerpage_test.zig");
    _ = @import("testercand_test.zig");
    _ = @import("table_test.zig");
    _ = @import("champsearch_test.zig");
    _ = @import("homepage_test.zig");
    _ = @import("yourpage_test.zig");
    _ = @import("yourviews_test.zig");
}

test "every component: scoped, linted CSS; clean states; no dead class" {
    try gallery.expectSound(all);
}

test "site components: one a site component imports is one too, so its CSS ships" {
    @setEvalBranchQuota(100_000);
    // filterbar's select is its gallery's only
    const gallery_only = .{.{ "filterbar", "select" }};
    inline for (components) |C| {
        const name = comptime fileName(C);
        var parts = std.mem.splitSequence(u8, @embedFile(name ++ ".zig"), "@import(\"");
        _ = parts.next();
        next: while (parts.next()) |rest| {
            const dep = rest[0 .. std.mem.findScalar(u8, rest, '"') orelse continue];
            if (!std.mem.endsWith(u8, dep, ".zig")) continue;
            const d = dep[0 .. dep.len - ".zig".len];
            inline for (gallery_only) |g| if (std.mem.eql(u8, g[0], name) and std.mem.eql(u8, g[1], d)) continue :next;
            inline for (components) |S| if (std.mem.eql(u8, fileName(S), d)) continue :next;
            inline for (all) |A| if (std.mem.eql(u8, fileName(A), d)) {
                std.debug.print("{s} imports {s}, not in components\n", .{ name, d });
                return error.TestUnexpectedResult;
            };
        }
    }
}

fn fileName(comptime C: type) []const u8 {
    const t = @typeName(C);
    return t[(std.mem.findScalarLast(u8, t, '.') orelse return t) + 1 ..];
}
