//! The UI's component system (docs/plan/ui/stack.md): components build a typed node tree
//! with `H`; html.zig writes it on the server, ui.wasm patches the DOM from it, check.zig
//! lints it in plain tests. Std and tpl only, so the same files build for the backend
//! and for wasm32.
const std = @import("std");

pub const tree = @import("tree.zig");
pub const html = @import("html.zig");
pub const fmt = @import("fmt.zig");
pub const phrase = @import("phrase.zig");
pub const check = @import("check.zig");
pub const url = @import("url.zig");
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
pub const histogram = @import("histogram.zig");
pub const lane = @import("lane.zig");
pub const timeline = @import("timeline.zig");
pub const gamedata = @import("gamedata.zig");
pub const testerdata = @import("testerdata.zig");
pub const learndata = @import("learndata.zig");
pub const pooldata = @import("pooldata.zig");
pub const admindata = @import("admindata.zig");
pub const learnpage = @import("learnpage.zig");
pub const champrolepicker = @import("champrolepicker.zig");
pub const poolslots = @import("poolslots.zig");
pub const heatgrid = @import("heatgrid.zig");
pub const puzzle = @import("puzzle.zig");
pub const guess = @import("guess.zig");
pub const choice = @import("choice.zig");
pub const rankstrip = @import("rankstrip.zig");
pub const draftflow = @import("draftflow.zig");
pub const yourlist = @import("yourlist.zig");
pub const gamepage = @import("gamepage.zig");
pub const gamehead = @import("gamehead.zig");
pub const gamerow = @import("gamerow.zig");
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
pub const components = .{ button, chip, badge, segmented, card, toggletip, strip, role, champ, rolepicker, champsearch, champhead, matchbrief, matchstrip, champlist, table, chart, dotplot, trend, histogram, art, skillgrid, itempath, runetree, buildpanel, tabs, site, filterbar, champpage, kda, timeline, versus, objicon, minimap, gamestrip, inspector, gamehead, gamerow, spark, stat, scoreboard, laneduel, itemrow, gamepage, lane, matchpage, matchgrid, finder, delta, bar, violin, tiers, guess, puzzle, choice, learnpage, changeline, patchhead, patchpage };

/// Every component, in the gallery's order
pub const all = .{ button, chip, badge, segmented, tabs, card, select, toggletip, stat, delta, bar, kda, strip, split, role, champ, site, rolepicker, filterbar, champsearch, champhead, matchbrief, matchstrip, champlist, draftboard, champselect, teamrows, loadscreen, gamescreen, postgame, signin, practice, app, table, chart, dotplot, trend, histogram, lane, timeline, spark, art, skillgrid, itempath, runetree, buildpanel, versus, objicon, minimap, gamestrip, inspector, gamehead, gamerow, scoreboard, laneduel, itemrow, gamepage, guess, puzzle, choice, rankstrip, draftflow, champrolepicker, poolslots, heatgrid, matchgrid, finder, violin, learnpage, changeline, patchhead, patchpage };

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
    _ = @import("table_test.zig");
    _ = @import("champsearch_test.zig");
}

test "every component: scoped, linted CSS; clean states; no dead class" {
    try gallery.expectSound(all);
}
