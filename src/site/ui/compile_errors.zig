//! Components that must not compile, each with the end of the error it must give: the
//! attribute guards that keep escaping to two contexts, and the phrase and codec checks.
//! Built one case at a time by build.zig's errorChecks (`zig build ui-errors`), as
//! src/tpl/compile_errors.zig.

const std = @import("std");

pub const Case = struct { name: []const u8, expect: []const u8 };

pub const cases = [_]Case{
    .{ .name = "onclick_attribute", .expect = ".onclick: events go in .on_<event> = h.on(component, msg)" },
    .{ .name = "on_string", .expect = ".on_click takes h.on(component, msg)" },
    .{ .name = "no_such_event", .expect = "no event hover" },
    .{ .name = "srcdoc", .expect = "srcdoc is HTML: not in the tree" },
    .{ .name = "style_string", .expect = "style takes h.vars(.{ ... }), numbers only" },
    .{ .name = "style_runtime_string", .expect = "style takes h.vars(.{ ... }), numbers only" },
    .{ .name = "vars_string", .expect = "h.vars .x: numbers and scale colours (fmt.WrColour, Step, Fill) only" },
    .{ .name = "camel_attribute", .expect = "attribute .dataName: lower case, digits and _ only" },
    .{ .name = "kids_not_tuple", .expect = "children go in a tuple: .{ ... }" },
    .{ .name = "msg_too_big", .expect = "Msg is over 16 bytes: pass an index, not the value" },
    .{ .name = "phrase_missing_value", .expect = "phrase \"{n:count} games\": no value for {n}" },
    .{ .name = "phrase_extra_value", .expect = "phrase \"{n:count} games\" has no hole {m}" },
    .{ .name = "phrase_wrong_kind", .expect = "phrase {n:count} can't take []const u8" },
    .{ .name = "phrase_no_kind", .expect = "{n} needs a kind: {name:count}" },
    .{ .name = "url_float", .expect = "url: can't write f32" },
    .{ .name = "data_pointer", .expect = "data: slices only, not *const u8" },
};

const ui = @import("ui");
const case = @import("options").case;

test {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: ui.Tree = .{};
    var h: ui.H = .init(arena.allocator(), &t);
    @field(bad, case)(&h);
}

var runtime_text: []const u8 = "x";

const Big = struct {
    pub const Msg = union(enum) { name: [20]u8 };
    pub fn update(_: *Big, _: Msg, _: *ui.Event) void {}
};

const bad = struct {
    fn onclick_attribute(h: *ui.H) void {
        _ = h.div(.{ .onclick = "x" }, .{});
    }
    fn on_string(h: *ui.H) void {
        _ = h.div(.{ .on_click = "x" }, .{});
    }
    fn no_such_event(h: *ui.H) void {
        _ = h.div(.{ .on_hover = "x" }, .{});
    }
    fn srcdoc(h: *ui.H) void {
        _ = h.div(.{ .srcdoc = "x" }, .{});
    }
    fn style_string(h: *ui.H) void {
        _ = h.div(.{ .style = "color:red" }, .{});
    }
    fn style_runtime_string(h: *ui.H) void {
        _ = h.div(.{ .style = runtime_text }, .{});
    }
    fn vars_string(h: *ui.H) void {
        _ = h.div(.{ .style = h.vars(.{ .x = "red" }) }, .{});
    }
    fn camel_attribute(h: *ui.H) void {
        _ = h.div(.{ .dataName = "x" }, .{});
    }
    fn kids_not_tuple(h: *ui.H) void {
        _ = h.div(.{}, .{ .a = 1 });
    }
    fn msg_too_big(h: *ui.H) void {
        var big: Big = .{};
        _ = h.div(.{ .on_click = h.on(&big, .{ .name = @splat(0) }) }, .{});
    }
    fn phrase_missing_value(h: *ui.H) void {
        _ = ui.Phrase("{n:count} games").with(h, .{});
    }
    fn phrase_extra_value(h: *ui.H) void {
        _ = ui.Phrase("{n:count} games").with(h, .{ .n = 1, .m = 2 });
    }
    fn phrase_wrong_kind(h: *ui.H) void {
        _ = ui.Phrase("{n:count}").with(h, .{ .n = runtime_text });
    }
    fn phrase_no_kind(h: *ui.H) void {
        _ = ui.Phrase("{n} games").with(h, .{ .n = 1 });
    }
    fn url_float(_: *ui.H) void {
        var buf: [8]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        ui.url.write(struct { x: f32 = 0 }, .{ .x = 1 }, &w) catch {};
    }
    fn data_pointer(h: *ui.H) void {
        var out: std.ArrayList(u8) = .empty;
        const x: u8 = 1;
        ui.data.encode(h.mem, *const u8, &x, &out) catch {};
    }
};
