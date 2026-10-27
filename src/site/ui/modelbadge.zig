//! ModelBadge: which model a number comes from. Its name says what the model is; accent
//! Badges say where it is used (Daily, App), a plain one where and when it was made (Box
//! 24 Oct, Lab 18 Oct). As a menu option it adds one facts line (games, patches, held-out
//! accuracy). Draft tester's model Select first; Daily's "the model's pick" note and the
//! app's About next (draft-tester.md)
const tree = @import("tree.zig");
const badge = @import("badge.zig");
const select = @import("select.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "ModelBadge";
pub const scope = .{".c-model"};

pub const Model = struct {
    name: tree.Text,
    /// A Select button's label (two words at most): "Live model"
    short: tree.Text,
    used_in: []const tree.Text = &.{},
    /// "Box 24 Oct"
    from: tree.Text,
    /// Shown as an option's second line
    facts: ?tree.Text = null,
};

pub fn view(h: *H, m: Model) N {
    return h.span(.{ .class = "c-model" }, .{tags(h, m)});
}

/// A menu option: the badge over its facts line
pub fn option(h: *H, m: Model) N {
    return h.span(.{ .class = "c-model", .data_v = "opt" }, .{
        h.span(.{ .class = "tags" }, .{tags(h, m)}),
        if (m.facts) |f| h.span(.{ .class = "sub" }, .{f}) else null,
    });
}

fn tags(h: *H, m: Model) []const N {
    var l = h.list();
    l.add(h.b(.{}, .{m.name}));
    for (m.used_in) |u| l.add(badge.view(h, .accent, .{u}));
    l.add(badge.view(h, .neutral, .{m.from}));
    return l.done();
}

pub const css =
    \\@layer components {
    \\  .c-model { display: inline-flex; align-items: center; gap: var(--sp-1); flex-wrap: wrap; min-width: 0; }
    \\  .c-model b { font-weight: var(--w-m); margin-right: 2px; }
    \\  .c-model[data-v="opt"] { flex-direction: column; align-items: flex-start; gap: 2px; }
    \\  .c-model > .tags { display: inline-flex; align-items: center; gap: var(--sp-1); flex-wrap: wrap; }
    \\  .c-model > .sub { font-size: var(--fs-xs); color: var(--muted); font-weight: var(--w-r); }
    \\}
    \\
;

const live: Model = .{
    .name = plain("Live draft model"),
    .short = plain("Live model"),
    .used_in = &.{ plain("Daily"), plain("App") },
    .from = plain("Box 24 Oct"),
    .facts = plain("Ratings + pairs · 1.7M games · 16.19–16.21 · 55.4% on 173k held out"),
};
const comp: Model = .{
    .name = plain("Comp model"),
    .short = plain("Comp model"),
    .from = plain("Lab 18 Oct"),
    .facts = plain("Additive v2 · 649k games · 16.19–16.20 · 55.3% on 86k held out"),
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("used and from", view(h, live));
    g.add("lab only", view(h, comp));
    const o: select.Opts = .{ .id = g.id("model") };
    // The button keeps a short label; the badges show in its menu
    g.add("as a Select", select.button(h, o, live.short));
    g.add("its menu", select.menu(h, o, &.{
        .{ .label = live.name, .node = option(h, live), .selected = true },
        .{ .label = comp.name, .node = option(h, comp) },
    }, true));
}
