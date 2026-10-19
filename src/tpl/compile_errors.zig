//! Templates that must not compile, each with the end of the error it must give. A Zig
//! test can't catch a compile error, so the build compiles each case on its own (the
//! `case` option names its function in `bad`) and expects its message: build.zig's
//! tplErrorChecks, `zig build tpl-errors`.

const std = @import("std");

pub const Case = struct { name: []const u8, expect: []const u8 };

/// Read by the build script, which can't compile the functions below (they import tpl;
/// Zig resolves imports lazily, so it never tries)
pub const cases = [_]Case{
    .{ .name = "hole_without_field", .expect = "hole {x} has no field in the args" },
    .{ .name = "field_without_hole", .expect = "field .x has no {x} hole" },
    .{ .name = "never_closed", .expect = "<div> is never closed (renderPart for layout pieces)" },
    .{ .name = "wrong_close", .expect = "</p> closes <div>" },
    .{ .name = "closes_nothing", .expect = "</div> closes nothing" },
    .{ .name = "void_end_tag", .expect = "</br>: void elements have no end tag" },
    .{ .name = "self_closing_div", .expect = "<div/> is not void and doesn't close in HTML" },
    .{ .name = "attribute_twice", .expect = "attribute href twice" },
    .{ .name = "attribute_twice_any_case", .expect = "attribute HREF twice" },
    .{ .name = "ends_inside_tag", .expect = "ends inside a tag, attribute, comment or script" },
    .{ .name = "tag_name_hole", .expect = tag_name_hole },
    .{ .name = "end_tag_name_hole", .expect = tag_name_hole },
    .{ .name = "less_than_hole", .expect = tag_name_hole },
    .{ .name = "doctype_hole", .expect = "a hole in <!...> isn't filled" },
    .{ .name = "string_in_tag", .expect = "hole inside a tag must be quoted, or be tpl.attr, tpl.flag or tpl.trusted" },
    .{ .name = "trusted_in_attribute", .expect = "hole {x}: " ++ trusted_in_attribute },
    .{ .name = "template_in_attribute", .expect = "in an attribute writes markup, which would be escaped (its own holes twice); pass text or a `format` value" },
    .{ .name = "string_in_on", .expect = "hole {x}: " ++ string_in_code },
    .{ .name = "string_in_style_attribute", .expect = "hole {x}: " ++ string_in_code },
    .{ .name = "string_in_attr_onclick", .expect = "tpl.attr(\"onclick\"): " ++ string_in_code },
    .{ .name = "string_in_srcdoc", .expect = "hole {x}: " ++ string_in_code },
    .{ .name = "string_in_script", .expect = "hole in <script> or <style> needs JS or CSS escaping; pass tpl.json or tpl.trusted" },
    .{ .name = "string_in_style", .expect = "hole in <script> or <style> needs JS or CSS escaping; pass tpl.json or tpl.trusted" },
    .{ .name = "string_in_upper_case_script", .expect = "hole in <script> or <style> needs JS or CSS escaping; pass tpl.json or tpl.trusted" },
    .{ .name = "url_scheme_from_two_holes", .expect = "a URL's scheme can't come from two holes" },
    .{ .name = "url_takes_no_bool", .expect = "hole {x}: a URL attribute takes a string, number, enum or a `render` or `format` value (scheme-checked), not bool" },
    .{ .name = "escaped_twice", .expect = "hole {x}: esc() value would be escaped twice; pass the string" },
    .{ .name = "options_on_a_string", .expect = "{x:.2}: options are for numbers, not *const [3:0]u8" },
    .{ .name = "options_on_optional_strings", .expect = "{x:.2}: options are for numbers, not ?[]const []const u8" },
    .{ .name = "byte_array", .expect = "hole {x}: a [3]u8 by value would write its bytes as numbers; pass a slice or pointer (&array)" },
    .{ .name = "cant_write_bool", .expect = "hole {x}: can't write a bool" },
};

const tag_name_hole = "a tag's name can't come from a hole (`&lt;` for a less-than sign)";
const trusted_in_attribute = "tpl.trusted HTML inside an attribute value would be escaped; pass the text";
const string_in_code = "a string in an on*, style or srcdoc attribute is script, CSS or HTML once entities are decoded; pass a number or a `format` value";

const tpl = @import("tpl");
const case = @import("options").case;
const Writer = std.Io.Writer;

test {
    var buf: [256]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try @field(bad, case)(&w);
}

const bad = struct {
    fn hole_without_field(w: *Writer) !void {
        try tpl.render(w, "<p>{x}</p>", .{});
    }
    fn field_without_hole(w: *Writer) !void {
        try tpl.render(w, "<p></p>", .{ .x = 1 });
    }
    fn never_closed(w: *Writer) !void {
        try tpl.render(w, "<div>", .{});
    }
    fn wrong_close(w: *Writer) !void {
        try tpl.render(w, "<div></p>", .{});
    }
    fn closes_nothing(w: *Writer) !void {
        try tpl.render(w, "</div>", .{});
    }
    fn void_end_tag(w: *Writer) !void {
        try tpl.render(w, "<br></br>", .{});
    }
    fn self_closing_div(w: *Writer) !void {
        try tpl.render(w, "<div/>", .{});
    }
    fn attribute_twice(w: *Writer) !void {
        try tpl.render(w, "<a href=\"x\" href=\"y\"></a>", .{});
    }
    fn ends_inside_tag(w: *Writer) !void {
        try tpl.render(w, "<a href=\"x", .{});
    }
    fn attribute_twice_any_case(w: *Writer) !void {
        try tpl.render(w, "<a href=\"x\" HREF=\"y\"></a>", .{});
    }
    fn tag_name_hole(w: *Writer) !void {
        try tpl.renderPart(w, "<{x}>", .{ .x = "script" });
    }
    fn end_tag_name_hole(w: *Writer) !void {
        try tpl.renderPart(w, "</{x}>", .{ .x = "script" });
    }
    fn less_than_hole(w: *Writer) !void {
        try tpl.render(w, "<p><{n} games</p>", .{ .n = 5 });
    }
    fn doctype_hole(w: *Writer) !void {
        try tpl.renderPart(w, "<!doctype {x}>", .{ .x = "html" });
    }
    fn string_in_tag(w: *Writer) !void {
        try tpl.render(w, "<a {x}></a>", .{ .x = "href=x" });
    }
    fn trusted_in_attribute(w: *Writer) !void {
        try tpl.render(w, "<p title=\"{x}\"></p>", .{ .x = tpl.trusted("<b>") });
    }
    fn template_in_attribute(w: *Writer) !void {
        try tpl.render(w, "<p title=\"{x}\"></p>", .{ .x = tpl.t("<b>{y}</b>", .{ .y = 1 }) });
    }
    fn string_in_on(w: *Writer) !void {
        try tpl.render(w, "<p onclick=\"go({x})\"></p>", .{ .x = "1" });
    }
    fn string_in_style_attribute(w: *Writer) !void {
        try tpl.render(w, "<p style=\"color:{x}\"></p>", .{ .x = "red" });
    }
    fn string_in_attr_onclick(w: *Writer) !void {
        try tpl.render(w, "<p{x}></p>", .{ .x = tpl.attr("onclick", "go()") });
    }
    fn string_in_srcdoc(w: *Writer) !void {
        try tpl.render(w, "<iframe srcdoc=\"{x}\"></iframe>", .{ .x = "<script>alert(1)</script>" });
    }
    fn string_in_upper_case_script(w: *Writer) !void {
        try tpl.render(w, "<SCRIPT>go({x})</SCRIPT>", .{ .x = "1" });
    }
    fn string_in_script(w: *Writer) !void {
        try tpl.render(w, "<script>go({x})</script>", .{ .x = "1" });
    }
    fn string_in_style(w: *Writer) !void {
        try tpl.render(w, "<style>p{color:{x}}</style>", .{ .x = "red" });
    }
    fn url_scheme_from_two_holes(w: *Writer) !void {
        try tpl.render(w, "<a href=\"{a}{b}\"></a>", .{ .a = "java", .b = "script:x" });
    }
    fn url_takes_no_bool(w: *Writer) !void {
        try tpl.render(w, "<a href=\"{x}\"></a>", .{ .x = true });
    }
    fn escaped_twice(w: *Writer) !void {
        try tpl.render(w, "<p>{x}</p>", .{ .x = tpl.esc("a&b") });
    }
    fn options_on_a_string(w: *Writer) !void {
        try tpl.render(w, "<p>{x:.2}</p>", .{ .x = "abc" });
    }
    fn options_on_optional_strings(w: *Writer) !void {
        try tpl.render(w, "<p>{x:.2}</p>", .{ .x = @as(?[]const []const u8, null) });
    }
    fn byte_array(w: *Writer) !void {
        try tpl.render(w, "<p>{x}</p>", .{ .x = [3]u8{ 'a', 'b', 'c' } });
    }
    fn cant_write_bool(w: *Writer) !void {
        try tpl.render(w, "<p>{x}</p>", .{ .x = true });
    }
};
