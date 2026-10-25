//! HTML backend: the tree as server bytes. Escaping is tpl's (writeEscaped); URL values
//! were checked by tpl.safeUrl when the node was built. No whitespace between tags, and
//! `<!---->` between two text nodes, so the browser parses back the same nodes in the
//! same order (hydration adopts them by pre-order position)
const std = @import("std");
const tpl = @import("tpl");
const tree = @import("tree.zig");

pub fn write(t: *const tree.Tree, n: tree.N, w: *std.Io.Writer) std.Io.Writer.Error!void {
    const x = t.node(n);
    if (x.tag == .@"#text") return tpl.writeEscaped(x.text, w);
    try w.writeByte('<');
    try w.writeAll(@tagName(x.tag));
    for (t.attrsOf(n)) |a| {
        try w.writeByte(' ');
        try w.writeAll(a.name);
        try w.writeAll("=\"");
        try tpl.writeEscaped(a.value, w);
        try w.writeByte('"');
    }
    try w.writeByte('>');
    if (x.tag.isVoid()) return;
    var prev_text = false;
    for (t.kidsOf(n)) |k| {
        const is_text = t.node(k).tag == .@"#text";
        if (is_text and prev_text) try w.writeAll("<!---->");
        prev_text = is_text;
        try write(t, k, w);
    }
    try w.writeAll("</");
    try w.writeAll(@tagName(x.tag));
    try w.writeByte('>');
}

/// The tree as a tpl component: `{island}` in a page template writes it as is
pub const Part = struct {
    t: *const tree.Tree,
    root: tree.N,

    pub fn render(p: Part, w: *std.Io.Writer) !void {
        return write(p.t, p.root, w);
    }
};
