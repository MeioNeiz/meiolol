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

/// Components whose CSS ships (css.join): add one when a page first uses it
pub const components = .{};

/// Every component, in the gallery's order
pub const all = .{ button, chip, badge, segmented, tabs, card, select, toggletip };

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
}

test "every component: scoped, linted CSS; clean states; no dead class" {
    try gallery.expectSound(all);
}
