//! Each page's CSS inline: the head (tokens, base, the font) and the components its HTML and
//! its islands' wasm name, by a scan for their scope classes (only code that can run is in
//! a wasm). Public and private pages alike. Measured against the one linked sheet: first page ~0.7 s sooner on Slow 4G,
//! each later page ~60 ms slower (research/questions/css-per-page.md)
const std = @import("std");
const ui = @import("ui");
const style = @import("style.zig");
const root = @import("root.zig");
const csp = @import("csp.zig");
const assets = @import("assets.zig");

/// The private pages' (admin, notes list, Draft tester), after the public ones: the
/// cascade they had as a second sheet
const private = .{ ui.alertband, ui.actionbutton, ui.adminpage, ui.timechart, ui.admincharts, ui.admintraffic, ui.steptimeline, ui.logview, ui.adminops, ui.adminmodels, ui.adminlab, ui.adminruns, ui.select, ui.modelbadge, ui.rankstrip, ui.testerpage, ui.testercand, ui.notes, ui.noteslist };
const all = ui.components ++ private;

const n = all.len;
pub const Set = std.bit_set.Array(u64, n);

const by_scope = blk: {
    var kvs: []const struct { []const u8, u16 } = &.{};
    for (all, 0..) |C, i| {
        for (C.scope) |s| kvs = kvs ++ .{.{ s[1..], @as(u16, i) }};
    }
    break :blk std.StaticStringMap(u16).initComptime(kvs);
};

fn isName(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == '_';
}

/// Adds the components whose scope class `bytes` names (`c-card`, whole words only)
pub fn scan(set: *Set, bytes: []const u8) void {
    var i: usize = 0;
    while (std.mem.findPos(u8, bytes, i, "c-")) |at| {
        var e = at + 2;
        while (e < bytes.len and isName(bytes[e])) e += 1;
        i = e;
        if (at > 0 and isName(bytes[at - 1])) continue;
        if (by_scope.get(bytes[at..e])) |k| set.set(k);
    }
}

/// By file name: islands load from / or the private page's folder
fn wasmData(files: []const assets.Hashed, path: []const u8) ?[]const u8 {
    const name = path[if (std.mem.findScalarLast(u8, path, '/')) |i| i + 1 else 0..];
    for (files) |h| if (std.mem.eql(u8, h.path, name)) return h.data;
    return null;
}

/// Adds the components of every island `page` names in a data-wasm, loaded at once or
/// on first use; their files among `files`
fn scanIslands(set: *Set, page: []const u8, files: []const assets.Hashed) void {
    var i: usize = 0;
    const key = "data-wasm=\"";
    while (std.mem.findPos(u8, page, i, key)) |at| {
        const start = at + key.len;
        const end = std.mem.findScalarPos(u8, page, start, '"') orelse break;
        i = end;
        if (wasmData(files, page[start..end])) |wasm| scan(set, wasm);
    }
}

/// The head (tokens, base, the font) and each component, minified apart: the public ones
/// the same bytes as the minified bundle. At first use, not comptime: minifying there costs a
/// minute of every backend compile
const Pieces = struct {
    head: []const u8,
    components: [n][]const u8,
};

var pieces: Pieces = undefined;
var state: std.atomic.Value(u8) = .init(0); // 0 none, 1 building, 2 ready

fn minified(a: std.mem.Allocator, readable: []const u8) ![]const u8 {
    return style.minify(try a.alloc(u8, readable.len), readable);
}

fn build() !Pieces {
    // Process lifetime: never freed
    const a = std.heap.page_allocator;
    // Root-relative: the CSS is inlined into pages at any depth
    const head = ui.css.head ++ ui.css.font_face[0] ++ "/" ++ style.font.path ++ ui.css.font_face[1];
    var p: Pieces = .{ .head = try minified(a, head), .components = undefined };
    inline for (all, &p.components) |C, *c| c.* = try minified(a, C.css);
    return p;
}

fn get() !*const Pieces {
    while (true) {
        switch (state.load(.acquire)) {
            2 => return &pieces,
            0 => if (state.cmpxchgStrong(0, 1, .acquire, .monotonic) == null) {
                pieces = build() catch |e| {
                    state.store(0, .release);
                    return e;
                };
                state.store(2, .release);
                return &pieces;
            },
            else => std.atomic.spinLoopHint(),
        }
    }
}

/// The head, then `set`'s components in order: the one sheet's cascade
pub fn css(a: std.mem.Allocator, set: Set) ![]const u8 {
    const p = try get();
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(a, p.head);
    for (p.components, 0..) |c, i| if (set.isSet(i)) try out.appendSlice(a, c);
    return out.items;
}

const link = "<link rel=\"stylesheet\" href=\"/" ++ style.file.path ++ "\">";

/// `page` with its link to the one sheet replaced by the CSS it uses, its hash in the
/// page's CSP; anything else as is
pub fn deliver(a: std.mem.Allocator, page: []const u8) ![]const u8 {
    return deliverWith(a, page, &root.hashed_assets);
}

/// As deliver, for a private page whose islands' files are `files`
pub fn deliverWith(a: std.mem.Allocator, page: []const u8, files: []const assets.Hashed) ![]const u8 {
    if (!std.mem.startsWith(u8, page, "<!doctype html>")) return page;
    const at = std.mem.find(u8, page, link) orelse return page;
    var set: Set = .empty;
    scan(&set, page);
    scanIslands(&set, page, files);
    const text = try css(a, set);
    return csp.withStyle(a, try std.mem.concat(a, u8, &.{ page[0..at], "<style>", text, "</style>", page[at + link.len ..] }), text);
}

fn index(comptime scope: []const u8) usize {
    return by_scope.get(scope).?;
}

test "scan: whole scope classes only" {
    var set: Set = .empty;
    scan(&set, "<div class=\"c-card x\"><span class=\"abc-chip c-nothing\">");
    try std.testing.expect(set.isSet(index("c-card")));
    try std.testing.expect(!set.isSet(index("c-chip")));
    try std.testing.expectEqual(1, set.count());
}

test "deliver: the link becomes the page's CSS, islands' included" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var island: Set = .empty;
    scan(&island, wasmData(&root.hashed_assets, assets.sitesearch_wasm.path).?);
    try std.testing.expect(island.count() > 0);
    const page = try std.mem.concat(a, u8, &.{
        "<!doctype html><head>",     link,        "</head><div class=\"c-card\"></div><div data-js=\"x\" data-wasm=\"/",
        assets.sitesearch_wasm.path, "\"></div>",
    });
    const out = try deliver(a, page);
    try std.testing.expect(std.mem.find(u8, out, link) == null);
    var want: Set = island;
    want.set(index("c-card"));
    const start = std.mem.find(u8, out, "<style>").? + "<style>".len;
    try std.testing.expectEqualStrings(try css(a, want), out[start..std.mem.find(u8, out, "</style>").?]);
    try std.testing.expectEqual("<!doctype html><head>".len + "<style>".len, start);
    try std.testing.expectEqualStrings("{}", try deliver(a, "{}"));
}

test "css: every public component is the one sheet" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var public: Set = .empty;
    public.setRangeValue(.{ .start = 0, .end = ui.components.len }, true);
    try std.testing.expectEqualStrings(style.bundle, try css(a, public));
}
