//! Design tokens, the one source: tokens.css is written from here (`css`), into the
//! bundle by src/site/style.zig. Transcribed from the gallery's mocks/tokens.css by
//! data/team/2026-10-25-ui-build/tools/tokens2zig.py; edit here once the visual pass ends
const std = @import("std");

pub const Token = struct { name: []const u8, value: []const u8 };
pub const Override = struct { media: []const u8, tokens: []const Token };

pub const root = [_]Token{
    // Surfaces, darkest to lightest. One card surface (--panel); --panel-2 for hover and
    // raised rows, --panel-3 for selected/pressed
    .{ .name = "bg", .value = "#08090a" },
    .{ .name = "panel", .value = "#111214" },
    .{ .name = "panel-2", .value = "#17181b" },
    .{ .name = "panel-3", .value = "#1e1f23" },
    .{ .name = "line", .value = "rgb(255 255 255 / 0.075)" },
    .{ .name = "line-2", .value = "rgb(255 255 255 / 0.13)" },
    // Ink
    .{ .name = "text", .value = "#f1f2f4" },
    .{ .name = "t2", .value = "#b4b7bd" },
    .{ .name = "muted", .value = "#8e939c" },
    // 4.6:1 on --panel: game counts and units must stay readable
    .{ .name = "faint", .value = "#7a7f88" },
    // Brand/selection only, never data
    .{ .name = "accent", .value = "#a99dff" },
    .{ .name = "brand", .value = "#8b7cf6" },
    // The logo's dot
    .{ .name = "brand-dot", .value = "#f5c451" },
    .{ .name = "accent-bg", .value = "rgb(139 124 246 / 0.16)" },
    .{ .name = "focus", .value = "rgb(139 124 246 / 0.6)" },
    // Diverging scale: above usual blue, below orange, grey middle; step 4 rare. Text on
    // dark, all >= 5.3:1. Always with a second cue (sign, bar, bold)
    .{ .name = "lo4", .value = "#fb2b9a" },
    .{ .name = "lo3", .value = "#fe6652" },
    .{ .name = "lo2", .value = "#f79c40" },
    .{ .name = "lo1", .value = "#caac83" },
    .{ .name = "s0", .value = "#a1a5ab" },
    .{ .name = "hi1", .value = "#89afd6" },
    .{ .name = "hi2", .value = "#59aaf8" },
    .{ .name = "hi3", .value = "#25d1ff" },
    .{ .name = "hi4", .value = "#0bfaf4" },
    // Cell fills for heat cells (number in --text on top)
    .{ .name = "f-lo3", .value = "#ae4200" },
    .{ .name = "f-lo2", .value = "#7d3400" },
    .{ .name = "f-lo1", .value = "#512a0f" },
    .{ .name = "f-0", .value = "#202225" },
    .{ .name = "f-hi1", .value = "#153758" },
    .{ .name = "f-hi2", .value = "#104e89" },
    .{ .name = "f-hi3", .value = "#1a68bf" },
    .{ .name = "good", .value = "var(--hi2)" },
    .{ .name = "bad", .value = "var(--lo2)" },
    // Magnitude without good/bad (pick, ban, games, gold lean): neutral ink bar
    .{ .name = "bar-lo", .value = "#5d6169" },
    .{ .name = "bar-hi", .value = "#b4b7bd" },
    .{ .name = "bar-track", .value = "rgb(255 255 255 / 0.06)" },
    // Two sides of a comparison (your team/enemy, you/opponent, champion A/B). Always
    // with a label or position; never colour a --them number with the scale
    .{ .name = "us", .value = "#5aaeff" },
    .{ .name = "them", .value = "#f0596b" },
    .{ .name = "us-hot", .value = "#3de0ff" },
    .{ .name = "them-hot", .value = "#ff3b8d" },
    .{ .name = "us-bg", .value = "rgb(90 174 255 / 0.12)" },
    .{ .name = "them-bg", .value = "rgb(240 89 107 / 0.12)" },
    // Game moment kinds (classes, not magnitudes)
    .{ .name = "turn", .value = "#f5c451" },
    .{ .name = "turn-line", .value = "rgb(245 196 81 / 0.35)" },
    .{ .name = "gain", .value = "#3ccf91" },
    .{ .name = "drop", .value = "#f59a4a" },
    .{ .name = "cost", .value = "#f0596b" },
    .{ .name = "death", .value = "#8a8f98" },
    .{ .name = "obj", .value = "#6aa1ff" },
    // Charts
    .{ .name = "axis", .value = "rgb(255 255 255 / 0.16)" },
    .{ .name = "grid", .value = "rgb(255 255 255 / 0.05)" },
    .{ .name = "range-bg", .value = "rgb(169 157 255 / 0.12)" },
    // Type: 5 sizes, nothing else. xs labels/axes/captions, s secondary, m body and
    // tables, l section titles and tile values, xl page title and hero figure
    .{ .name = "font", .value = "Inter, system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif" },
    .{ .name = "fs-xs", .value = "11px" },
    .{ .name = "fs-s", .value = "12px" },
    .{ .name = "fs-m", .value = "13px" },
    .{ .name = "fs-l", .value = "16px" },
    .{ .name = "fs-xl", .value = "22px" },
    .{ .name = "lh", .value = "1.45" },
    .{ .name = "lh-tight", .value = "1.2" },
    .{ .name = "w-r", .value = "400" },
    .{ .name = "w-m", .value = "550" },
    .{ .name = "w-b", .value = "650" },
    // Spacing
    .{ .name = "sp-0", .value = "2px" },
    .{ .name = "sp-1", .value = "4px" },
    .{ .name = "sp-2", .value = "8px" },
    .{ .name = "sp-3", .value = "12px" },
    .{ .name = "sp-4", .value = "16px" },
    .{ .name = "sp-5", .value = "24px" },
    .{ .name = "sp-6", .value = "32px" },
    // Radii: s badges and cells, ctl controls, m cards, l popovers/dialogs
    .{ .name = "r-s", .value = "4px" },
    .{ .name = "r-ctl", .value = "6px" },
    .{ .name = "r-m", .value = "8px" },
    .{ .name = "r-l", .value = "12px" },
    .{ .name = "r-pill", .value = "999px" },
    // Controls: visible heights. --ctl buttons, segmented, selects, inputs; --ctl-s
    // compact (in rows, chips); --ctl-l tabs and role picker. --hit: minimum tap area
    // (phone 44); a smaller visible control grows its hit area to it
    .{ .name = "ctl", .value = "36px" },
    .{ .name = "ctl-s", .value = "28px" },
    .{ .name = "ctl-l", .value = "44px" },
    .{ .name = "hit", .value = "32px" },
    // Control surfaces: filled, a step above the card; selected is a solid tinted fill,
    // not an outline, so it reads at a glance and stays inside its group
    .{ .name = "ctl-bg", .value = "#1c1d21" },
    .{ .name = "ctl-bg-2", .value = "#26272c" },
    .{ .name = "ctl-line", .value = "rgb(255 255 255 / 0.1)" },
    .{ .name = "sel-bg", .value = "#3b3762" },
    .{ .name = "sel-ink", .value = "#ffffff" },
    .{ .name = "sel-line", .value = "rgb(169 157 255 / 0.45)" },
    // Ink on the brand fill (primary button); a faint wash for flat labels (Badge,
    // reason chip) and its hover step
    .{ .name = "on-brand", .value = "#ffffff" },
    .{ .name = "wash", .value = "rgb(255 255 255 / 0.05)" },
    .{ .name = "wash-2", .value = "rgb(255 255 255 / 0.1)" },
    // Tabs: the selected tab's bar on the panel edge
    .{ .name = "tab-bar", .value = "2px" },
    // Table header band
    .{ .name = "th-bg", .value = "#16171a" },
    // Rows and icons
    .{ .name = "row", .value = "30px" },
    .{ .name = "row-s", .value = "26px" },
    .{ .name = "icon-s", .value = "20px" },
    .{ .name = "icon", .value = "24px" },
    .{ .name = "icon-m", .value = "32px" },
    .{ .name = "icon-l", .value = "48px" },
    // Layout
    .{ .name = "wrap", .value = "1560px" },
    .{ .name = "gutter", .value = "24px" },
    .{ .name = "header", .value = "48px" },
    .{ .name = "gap", .value = "var(--sp-2)" },
    .{ .name = "card-py", .value = "10px" },
    .{ .name = "card-px", .value = "12px" },
    .{ .name = "card-pad", .value = "var(--card-py) var(--card-px)" },
    // Elevation, motion, stacking
    .{ .name = "shadow-pop", .value = "0 12px 32px rgb(0 0 0 / 0.5)" },
    // A chosen segment lifted off its well; the primary button's top light
    .{ .name = "shadow-ctl", .value = "0 1px 2px rgb(0 0 0 / 0.5)" },
    .{ .name = "shadow-btn", .value = "inset 0 1px 0 rgb(255 255 255 / 0.18), 0 1px 2px rgb(0 0 0 / 0.4)" },
    .{ .name = "dur", .value = "120ms" },
    .{ .name = "ease", .value = "cubic-bezier(0.2, 0, 0, 1)" },
    .{ .name = "z-sticky", .value = "10" },
    .{ .name = "z-header", .value = "20" },
    .{ .name = "z-pop", .value = "30" },
};

/// Plain properties on :root beside the tokens
pub const root_props = [_]Token{
    .{ .name = "color-scheme", .value = "dark" },
};

pub const overrides = [_]Override{
    .{ .media = "(pointer: coarse)", .tokens = &.{
        .{ .name = "ctl", .value = "40px" },
        .{ .name = "ctl-s", .value = "32px" },
        .{ .name = "ctl-l", .value = "44px" },
        .{ .name = "hit", .value = "44px" },
        .{ .name = "row", .value = "36px" },
    } },
    .{ .media = "(max-width: 480px)", .tokens = &.{
        .{ .name = "gutter", .value = "16px" },
        .{ .name = "card-py", .value = "8px" },
        .{ .name = "card-px", .value = "10px" },
    } },
};

/// The tokens layer as CSS
pub const css: []const u8 = blk: {
    @setEvalBranchQuota(100_000);
    var s: []const u8 = "@layer tokens {\n:root {";
    for (root_props) |p| s = s ++ " " ++ p.name ++ ": " ++ p.value ++ ";";
    for (root) |t| s = s ++ " --" ++ t.name ++ ": " ++ t.value ++ ";";
    s = s ++ " }\n";
    for (overrides) |o| {
        s = s ++ "@media " ++ o.media ++ " { :root {";
        for (o.tokens) |t| s = s ++ " --" ++ t.name ++ ": " ++ t.value ++ ";";
        s = s ++ " } }\n";
    }
    break :blk s ++ "}\n";
};

/// A token's value at compile time: a compile error names a token that doesn't exist
pub fn get(comptime name: []const u8) []const u8 {
    inline for (root) |t| if (comptime std.mem.eql(u8, t.name, name)) return t.value;
    @compileError("no token --" ++ name);
}

pub fn has(name: []const u8) bool {
    for (root) |t| if (std.mem.eql(u8, t.name, name)) return true;
    return false;
}

test "every override names a token" {
    for (overrides) |o| for (o.tokens) |t| try std.testing.expect(has(t.name));
    try std.testing.expectEqualStrings("13px", get("fs-m"));
}
