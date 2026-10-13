//! HTML templates with named holes, checked at compile time.
//!
//!     try tpl.render(w, "<a href=\"{href}\">{name}</a>", .{ .href = url, .name = champ.name });
//!
//! - A hole is `{name}` or `{name:options}` (std.fmt options for a number: `{gold:.1}`, `{secs:0>2}`).
//!   Any other brace is plain text, so inline JS needs no escaping; `{{` writes `{`.
//! - Every hole needs a field and every field a hole: a typo is a compile error.
//! - Values by type: strings, numbers, enums (tag name), optionals (null writes
//!   nothing), anything with `render(self, w)` (components, `t`, `call`, `each`), slices
//!   of those, and anything with `format`. `trusted` marks HTML written as is.
//! - Escaping comes from where the hole sits, known at compile time (maud's
//!   attribute break-outs come from escaping by type alone):
//!   - text: escaped; components write their own markup
//!   - quoted attribute value: everything escaped, components and `format` included,
//!     as they stream. `trusted`, `t`, `call` and `each` are compile errors: their
//!     markup would be escaped, their own holes twice
//!   - URL attribute (href, src, action...) until its text fixes the scheme (a `:`,
//!     `/`, `?` or `#` before the hole): strings, components and `format` are
//!     scheme-checked (javascript: and the like become about:invalid); a second hole
//!     before the scheme is fixed is a compile error. `attr("href", ...)` the same
//!   - on* and style values: script after entity decoding, so a string is a compile
//!     error; numbers, enums and our own `format` types only
//!   - inside a tag, outside quotes: only `attr`, `flag` or `trusted` (an unquoted
//!     string could add attributes)
//!   - <script>, <style>: numbers, `json` or `trusted` (HTML escaping is wrong there);
//!     data for JS goes in `<script type="application/json">{data}</script>`
//! - `render` and `t` templates must balance their tags; `renderPart` is for layout
//!   pieces that open in one call and close in another.
//!
//! No allocator or I/O: the same components run in wasm with a fixed-buffer Writer.

const std = @import("std");
const Writer = std.Io.Writer;

pub fn render(w: *Writer, comptime src: []const u8, args: anytype) !void {
    return renderSegs(w, comptime parse(src, true), src, args);
}

/// As `render`, but tags may stay open or close ones opened elsewhere (page layout)
pub fn renderPart(w: *Writer, comptime src: []const u8, args: anytype) !void {
    return renderSegs(w, comptime parse(src, false), src, args);
}

/// A template as a value, to pass into another template's hole
pub fn t(comptime src: []const u8, args: anytype) Template(src, @TypeOf(args)) {
    return .{ .args = args };
}

pub fn Template(comptime src: []const u8, comptime Args: type) type {
    return struct {
        args: Args,

        pub const is_template = true;

        pub fn render(self: @This(), w: *Writer) !void {
            return renderSegs(w, comptime parse(src, true), src, self.args);
        }
    };
}

/// HTML written as is
pub const Raw = struct {
    html: []const u8,

    pub fn render(self: Raw, w: *Writer) Writer.Error!void {
        return w.writeAll(self.html);
    }
};

/// HTML written as is: only for markup we wrote, never for data (long name on purpose)
pub fn trusted(html: []const u8) Raw {
    return .{ .html = html };
}

/// `v` as JSON for a <script> hole, `<` `>` `&` as \u escapes so it can't end the script
pub fn json(v: anytype) Json(@TypeOf(v)) {
    return .{ .value = v };
}

pub fn Json(comptime T: type) type {
    return struct {
        value: T,

        pub const is_json = true;

        pub fn render(self: @This(), w: *Writer) Writer.Error!void {
            var buf: [64]u8 = undefined;
            var e: Escaping = .init(w, &buf, .script);
            std.json.Stringify.value(self.value, .{}, &e.writer) catch return error.WriteFailed;
            return e.writer.flush();
        }
    };
}

/// ` name="value"`, value escaped as in a quoted hole of that attribute; for a hole
/// inside a tag
pub fn attr(comptime name: []const u8, value: anytype) Attr(name, @TypeOf(value)) {
    return .{ .value = value };
}

pub fn Attr(comptime name: []const u8, comptime T: type) type {
    return struct {
        value: T,

        pub const is_attr = true;

        pub fn render(self: @This(), w: *Writer) !void {
            const ctx: Context = comptime if (isCodeAttr(name)) .code else if (isUrlAttr(name)) .url else .attr;
            try w.writeAll(" " ++ name ++ "=\"");
            try writeValue(w, self.value, "", ctx, .{ "", "" });
            try w.writeByte('"');
        }
    };
}

/// ` name` when `on`, for boolean attributes and classes: `<li{thin}>`
pub fn flag(on: bool, comptime html: []const u8) ?Raw {
    return if (on) trusted(" " ++ html) else null;
}

/// `value` when `on`, else nothing
pub fn when(on: bool, v: anytype) ?@TypeOf(v) {
    return if (on) v else null;
}

/// A component call as a value: `func(w, args...)` when rendered
pub fn call(comptime func: anytype, args: anytype) Call(func, @TypeOf(args)) {
    return .{ .args = args };
}

pub fn Call(comptime func: anytype, comptime Args: type) type {
    return struct {
        args: Args,

        pub const is_template = true;

        pub fn render(self: @This(), w: *Writer) @typeInfo(@TypeOf(func)).@"fn".return_type.? {
            return @call(.auto, func, .{w} ++ self.args);
        }
    };
}

/// `func(ctx, w, item)` for each item
pub fn each(items: anytype, ctx: anytype, comptime func: anytype) Each(@TypeOf(items), @TypeOf(ctx), func) {
    return .{ .items = items, .ctx = ctx };
}

pub fn Each(comptime Items: type, comptime Ctx: type, comptime func: anytype) type {
    return struct {
        items: Items,
        ctx: Ctx,

        pub const is_template = true;

        pub fn render(self: @This(), w: *Writer) @typeInfo(@TypeOf(func)).@"fn".return_type.? {
            for (self.items) |item| try func(self.ctx, w, item);
        }
    };
}

pub fn esc(s: []const u8) std.fmt.Alt([]const u8, writeEscaped) {
    return .{ .data = s };
}

pub fn writeEscaped(s: []const u8, w: *Writer) Writer.Error!void {
    var start: usize = 0;
    for (s, 0..) |ch, i| {
        const entity: []const u8 = switch (ch) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&#39;",
            else => continue,
        };
        try w.writeAll(s[start..i]);
        try w.writeAll(entity);
        start = i + 1;
    }
    try w.writeAll(s[start..]);
}

// --- parsing --------------------------------------------------------------------------

/// Where a hole sits; code: an on* or style attribute value
const Context = enum { text, attr, url, code, tag, script };

const Seg = union(enum) {
    lit: []const u8,
    hole: struct {
        name: []const u8,
        spec: []const u8,
        ctx: Context,
        /// url: the value's text before and after the hole, for the scheme check
        around: [2][]const u8 = .{ "", "" },
    },
};

const void_tags = [_][]const u8{
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr",
};

fn isVoid(name: []const u8) bool {
    for (void_tags) |v| if (std.mem.eql(u8, v, name)) return true;
    return false;
}

fn isNameStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn isName(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn fail(comptime src: []const u8, comptime at: usize, comptime msg: []const u8) noreturn {
    const from = if (at > 30) at - 30 else 0;
    const to = @min(src.len, at + 30);
    @compileError("template: " ++ msg ++ ", at: \"" ++ src[from..to] ++ "\"");
}

fn parse(comptime src: []const u8, comptime balanced: bool) []const Seg {
    @setEvalBranchQuota(20_000 + 100 * src.len);
    comptime {
        var segs: []const Seg = &.{};
        // Literal text is src[lit_start..i]: slices, not copies
        var lit_start: usize = 0;
        var stack: []const []const u8 = &.{};
        const State = enum { text, tag, dq, sq, comment, script };
        var state: State = .text;
        var tag_name: []const u8 = "";
        var tag_start: usize = 0;
        var attr_name: []const u8 = "";
        var value_start: usize = 0;
        var script_end: []const u8 = "";
        var i: usize = 0;
        while (i < src.len) {
            const c = src[i];
            if (c == '{' and state != .comment) {
                if (i + 1 < src.len and src[i + 1] == '{') {
                    segs = withLit(segs, src[lit_start .. i + 1]);
                    i += 2;
                    lit_start = i;
                    continue;
                }
                if (hole(src, i)) |h| {
                    segs = withLit(segs, src[lit_start..i]);
                    const ctx: Context = switch (state) {
                        .text, .comment => .text,
                        .tag => .tag,
                        .dq, .sq => if (isCodeAttr(attr_name)) .code else if (isUrlAttr(attr_name)) .url else .attr,
                        .script => .script,
                    };
                    const around = if (ctx == .url) urlAround(src, value_start, i, h.end) else null;
                    segs = segs ++ [_]Seg{.{ .hole = .{
                        .name = h.name,
                        .spec = h.spec,
                        .ctx = if (ctx == .url and around == null) .attr else ctx,
                        .around = around orelse .{ "", "" },
                    } }};
                    i = h.end;
                    lit_start = i;
                    continue;
                }
            }
            if (state == .script and std.mem.startsWith(u8, src[i..], script_end)) {
                state = .text; // the end tag itself is read as text
                continue;
            }
            i += 1;
            switch (state) {
                .text => if (c == '<' and i < src.len) {
                    if (std.mem.startsWith(u8, src[i..], "!--")) {
                        state = .comment;
                    } else if (src[i] == '!') {
                        // doctype: no holes or nesting worth tracking
                        const end = std.mem.indexOfScalarPos(u8, src, i, '>') orelse fail(src, i, "unclosed <!");
                        i = end + 1;
                    } else if (src[i] == '/') {
                        const end = std.mem.indexOfScalarPos(u8, src, i, '>') orelse fail(src, i, "unclosed end tag");
                        const name = std.mem.trim(u8, src[i + 1 .. end], " \n");
                        if (isVoid(name)) fail(src, i, "</" ++ name ++ ">: void elements have no end tag");
                        if (balanced) {
                            if (stack.len == 0) fail(src, i, "</" ++ name ++ "> closes nothing");
                            const open = stack[stack.len - 1];
                            if (!std.mem.eql(u8, open, name)) fail(src, i, "</" ++ name ++ "> closes <" ++ open ++ ">");
                            stack = stack[0 .. stack.len - 1];
                        } else if (stack.len > 0 and std.mem.eql(u8, stack[stack.len - 1], name)) {
                            stack = stack[0 .. stack.len - 1];
                        }
                        i = end + 1;
                    } else if (std.ascii.isAlphabetic(src[i])) {
                        var end = i;
                        while (end < src.len and (std.ascii.isAlphanumeric(src[end]) or src[end] == '-')) end += 1;
                        tag_name = src[i..end];
                        tag_start = end;
                        i = end;
                        state = .tag;
                    }
                },
                .tag => switch (c) {
                    '"', '\'' => {
                        state = if (c == '"') .dq else .sq;
                        attr_name = lastAttrName(src[0 .. i - 1]);
                        value_start = i;
                    },
                    '>' => {
                        state = .text;
                        checkAttrs(src, tag_start, i - 1);
                        const self_closing = src[i - 2] == '/';
                        // Self-closing is SVG's; in HTML `<div/>` opens a div
                        if (self_closing and !isVoid(tag_name) and !inSvg(stack, tag_name)) {
                            fail(src, i, "<" ++ tag_name ++ "/> is not void and doesn't close in HTML");
                        }
                        if (!self_closing and !isVoid(tag_name)) {
                            stack = stack ++ [_][]const u8{tag_name};
                            if (std.mem.eql(u8, tag_name, "script") or std.mem.eql(u8, tag_name, "style")) {
                                state = .script;
                                script_end = "</" ++ tag_name;
                            }
                        }
                    },
                    else => {},
                },
                .dq => if (c == '"') {
                    state = .tag;
                },
                .sq => if (c == '\'') {
                    state = .tag;
                },
                .comment => if (std.mem.endsWith(u8, src[0..i], "-->")) {
                    state = .text;
                },
                .script => {},
            }
        }
        if (state != .text) fail(src, src.len, "ends inside a tag, attribute, comment or script");
        if (balanced and stack.len > 0) fail(src, src.len, "<" ++ stack[stack.len - 1] ++ "> is never closed (renderPart for layout pieces)");
        segs = withLit(segs, src[lit_start..]);
        const out = segs[0..segs.len].*;
        return &out;
    }
}

fn withLit(comptime segs: []const Seg, comptime lit: []const u8) []const Seg {
    return if (lit.len == 0) segs else segs ++ [_]Seg{.{ .lit = lit }};
}

/// A URL attribute's text around a hole that the scheme check must see: none when the
/// text before it fixes the scheme (a `:`, `/`, `?` or `#`), else that text and what
/// follows the hole up to a delimiter (`{x}:y` makes a scheme too). Holes aren't text,
/// so two before the scheme is fixed can't be checked
fn urlAround(comptime src: []const u8, comptime start: usize, comptime at: usize, comptime end: usize) ?[2][]const u8 {
    var j = start;
    var after_hole = false;
    while (j < at) {
        if (std.mem.indexOfScalar(u8, ":/?#", src[j]) != null) return null;
        if (src[j] == '{') if (hole(src, j)) |h| {
            after_hole = true;
            j = h.end;
            continue;
        };
        j += 1;
    }
    if (after_hole) fail(src, at, "a URL's scheme can't come from two holes");
    var k = end;
    while (k < src.len and std.mem.indexOfScalar(u8, "\"'{", src[k]) == null) : (k += 1) {
        if (std.mem.indexOfScalar(u8, ":/?#", src[k]) != null) {
            k += 1;
            break;
        }
    }
    return .{ src[start..at], src[end..k] };
}

/// on* and style values are script and CSS once entities are decoded
fn isCodeAttr(comptime name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, "style") or (name.len > 2 and std.ascii.startsWithIgnoreCase(name, "on"));
}

const url_attrs = [_][]const u8{ "href", "src", "action", "formaction", "poster", "cite", "data", "xlink:href" };

fn isUrlAttr(name: []const u8) bool {
    for (url_attrs) |u| if (std.mem.eql(u8, u, name)) return true;
    return false;
}

/// The attribute name before `="` at the end of `before`
fn lastAttrName(comptime before: []const u8) []const u8 {
    var end = before.len;
    while (end > 0 and (before[end - 1] == '=' or before[end - 1] == ' ')) end -= 1;
    var start = end;
    while (start > 0 and (std.ascii.isAlphanumeric(before[start - 1]) or before[start - 1] == '-' or before[start - 1] == ':' or before[start - 1] == '_')) start -= 1;
    return before[start..end];
}

/// SVG elements that self-close; listed so an SVG fragment needs no <svg> around it
const svg_shapes = [_][]const u8{
    "circle", "ellipse", "line", "path", "polygon", "polyline", "rect", "stop", "use",
};

fn inSvg(comptime stack: []const []const u8, comptime name: []const u8) bool {
    if (std.mem.eql(u8, name, "svg")) return true;
    for (svg_shapes) |shape| if (std.mem.eql(u8, shape, name)) return true;
    for (stack) |open| if (std.mem.eql(u8, open, "svg")) return true;
    return false;
}

/// No attribute twice in one tag; `attrs` is the tag after its name, up to `>`. Holes
/// outside quotes (tpl.attr, tpl.flag) aren't seen, so can still repeat one
fn checkAttrs(comptime src: []const u8, comptime start: usize, comptime end: usize) void {
    const attrs = src[start..end];
    var names: []const []const u8 = &.{};
    var i: usize = 0;
    while (i < attrs.len) {
        const c = attrs[i];
        if (c == '"' or c == '\'') {
            i = std.mem.indexOfScalarPos(u8, attrs, i + 1, c).? + 1;
        } else if (c == '{') {
            i = (std.mem.indexOfScalarPos(u8, attrs, i, '}') orelse attrs.len - 1) + 1;
        } else if (std.ascii.isAlphabetic(c)) {
            var j = i;
            while (j < attrs.len and (std.ascii.isAlphanumeric(attrs[j]) or attrs[j] == '-' or attrs[j] == ':' or attrs[j] == '_')) j += 1;
            const name = attrs[i..j];
            for (names) |n| if (std.mem.eql(u8, n, name)) fail(src, start + i, "attribute " ++ name ++ " twice");
            names = names ++ [_][]const u8{name};
            // An unquoted value (`type=search`) is no attribute name
            while (j < attrs.len and std.ascii.isWhitespace(attrs[j])) j += 1;
            if (j < attrs.len and attrs[j] == '=') {
                j += 1;
                while (j < attrs.len and std.ascii.isWhitespace(attrs[j])) j += 1;
                if (j < attrs.len and attrs[j] != '"' and attrs[j] != '\'') {
                    while (j < attrs.len and !std.ascii.isWhitespace(attrs[j])) j += 1;
                }
            }
            i = j;
        } else i += 1;
    }
}

const Hole = struct { name: []const u8, spec: []const u8, end: usize };

/// `{name}` or `{name:spec}` at src[i], else null (a plain brace)
fn hole(comptime src: []const u8, comptime i: usize) ?Hole {
    var j = i + 1;
    if (j >= src.len or !isNameStart(src[j])) return null;
    while (j < src.len and isName(src[j])) j += 1;
    const name = src[i + 1 .. j];
    if (j < src.len and src[j] == '}') return .{ .name = name, .spec = "", .end = j + 1 };
    if (j >= src.len or src[j] != ':') return null;
    const close = std.mem.indexOfScalarPos(u8, src, j, '}') orelse return null;
    const spec = src[j + 1 .. close];
    for (spec) |ch| if (ch == '{' or ch == ' ' or ch == '\n' or ch == ';' or ch == ',') return null;
    return .{ .name = name, .spec = spec, .end = close + 1 };
}

// --- rendering ------------------------------------------------------------------------

fn renderSegs(w: *Writer, comptime segs: []const Seg, comptime src: []const u8, args: anytype) !void {
    const Args = @TypeOf(args);
    comptime {
        for (std.meta.fieldNames(Args)) |field| {
            var used = false;
            for (segs) |s| if (s == .hole and std.mem.eql(u8, s.hole.name, field)) {
                used = true;
            };
            if (!used) @compileError("template: field ." ++ field ++ " has no {" ++ field ++ "} hole in \"" ++ src ++ "\"");
        }
    }
    inline for (segs) |s| switch (s) {
        .lit => |l| try w.writeAll(l),
        .hole => |h| {
            if (!@hasField(Args, h.name)) @compileError("template: hole {" ++ h.name ++ "} has no field in the args (" ++ @typeName(Args) ++ ")");
            try writeValue(w, @field(args, h.name), h.spec, h.ctx, h.around);
        },
    };
}

fn writeValue(w: *Writer, v: anytype, comptime spec: []const u8, comptime ctx: Context, comptime around: [2][]const u8) !void {
    const T = @TypeOf(v);
    comptime check(T, ctx);
    switch (@typeInfo(T)) {
        .int, .comptime_int, .float, .comptime_float => return w.print("{d" ++ (if (spec.len > 0) ":" ++ spec else "") ++ "}", .{v}),
        .@"enum" => if (!@hasDecl(T, "render")) return writeText(w, @tagName(v), ctx, around),
        .optional => return if (v) |inner| writeValue(w, inner, spec, ctx, around),
        .void => return,
        else => {},
    }
    if (comptime isString(T)) return writeText(w, v, ctx, around);
    if (comptime hasDecl(T, "render") or hasDecl(T, "format")) {
        if (T == std.fmt.Alt([]const u8, writeEscaped)) @compileError("template: esc() value would be escaped twice; pass the string");
        if (ctx == .url) {
            // Whole, for the scheme check: URLs are short
            var buf: [2048]u8 = undefined;
            var url: Writer = .fixed(&buf);
            if (comptime hasDecl(T, "render")) try v.render(&url) else try url.print("{f}", .{v});
            return writeText(w, url.buffered(), ctx, around);
        }
        // Escaped as it streams: in an attribute a component's markup is just text
        const escape = comptime !hasDecl(T, "render") or ctx == .attr or ctx == .code;
        if (!escape) return v.render(w);
        var buf: [64]u8 = undefined;
        var e: Escaping = .init(w, &buf, .html);
        if (comptime hasDecl(T, "render")) {
            try v.render(&e.writer);
        } else {
            e.writer.print("{f}", .{v}) catch return error.WriteFailed;
        }
        return e.writer.flush();
    }
    switch (@typeInfo(T)) {
        .pointer => |p| if (p.size == .slice) {
            for (v) |item| try writeValue(w, item, spec, ctx, around);
            return;
        } else if (p.size == .one and @typeInfo(p.child) == .array) {
            for (v) |item| try writeValue(w, item, spec, ctx, around);
            return;
        },
        .array => {
            for (v) |item| try writeValue(w, item, spec, ctx, around);
            return;
        },
        else => {},
    }
    @compileError("template: can't write a " ++ @typeName(T));
}

fn writeText(w: *Writer, s: []const u8, comptime ctx: Context, comptime around: [2][]const u8) !void {
    if (ctx == .url and !safeUrl(around[0], s, around[1])) return w.writeAll("about:invalid#tpl");
    return writeEscaped(s, w);
}

fn isString(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |p| switch (p.size) {
            .slice => p.child == u8,
            .one => switch (@typeInfo(p.child)) {
                .array => |a| a.child == u8,
                else => false,
            },
            else => false,
        },
        else => false,
    };
}

fn hasDecl(comptime T: type, comptime name: []const u8) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => @hasDecl(T, name),
        .pointer => |p| p.size == .one and hasDecl(p.child, name),
        else => false,
    };
}

/// What a hole may hold where it sits
fn check(comptime T: type, comptime ctx: Context) void {
    if (@typeInfo(T) == .optional) return check(@typeInfo(T).optional.child, ctx);
    if (T == void) return;
    const number = switch (@typeInfo(T)) {
        .int, .comptime_int, .float, .comptime_float => true,
        else => false,
    };
    const name = @typeName(T);
    switch (ctx) {
        .text => {},
        .attr, .url, .code => {
            if (T == Raw) @compileError("template: tpl.trusted HTML inside an attribute value would be escaped; pass the text");
            if (hasDecl(T, "is_template")) {
                @compileError("template: a " ++ name ++ " in an attribute writes markup, which would be escaped (its own holes twice); pass text or a `format` value");
            }
            const value = number or isString(T) or @typeInfo(T) == .@"enum" or hasDecl(T, "render") or hasDecl(T, "format");
            if (ctx == .url and !value) {
                @compileError("template: a URL attribute takes a string, number, enum or a `render` or `format` value (scheme-checked), not " ++ name);
            }
            if (ctx == .code and isString(T)) {
                @compileError("template: a string in an on* or style attribute is script or CSS once entities are decoded; pass a number or a `format` value");
            }
        },
        .tag => if (T != Raw and !hasDecl(T, "is_attr")) {
            @compileError("template: a " ++ name ++ " hole inside a tag must be quoted, or be tpl.attr, tpl.flag or tpl.trusted");
        },
        .script => if (!number and T != Raw and !hasDecl(T, "is_json")) {
            @compileError("template: a " ++ name ++ " hole in <script> or <style> needs JS or CSS escaping; pass tpl.json or tpl.trusted");
        },
    }
}

/// Relative, or http, https or mailto: what a page links to. Anything else with a
/// scheme (javascript:, data:, or one hidden by whitespace) is refused. The URL is
/// `before ++ s ++ after`
fn safeUrl(comptime before: []const u8, s: []const u8, comptime after: []const u8) bool {
    var scheme: [8]u8 = undefined;
    var n: usize = 0;
    for ([_][]const u8{ before, s, after }) |part| for (part) |ch| switch (ch) {
        ':' => {
            if (n > scheme.len) return false;
            for ([_][]const u8{ "http", "https", "mailto" }) |ok| {
                if (std.ascii.eqlIgnoreCase(scheme[0..n], ok)) return true;
            }
            return false;
        },
        '/', '?', '#' => return true,
        else => {
            if (n < scheme.len) scheme[n] = ch;
            n += 1;
        },
    };
    return true;
}

/// A Writer that escapes what passes through it into `out`: HTML, or for <script>, the
/// characters that could end it as \u escapes (valid in JSON strings, the only place
/// JSON has them)
const Escaping = struct {
    out: *Writer,
    mode: enum { html, script },
    writer: Writer,

    fn init(out: *Writer, buffer: []u8, mode: @FieldType(Escaping, "mode")) Escaping {
        return .{ .out = out, .mode = mode, .writer = .{ .buffer = buffer, .vtable = &.{ .drain = drain } } };
    }

    fn put(self: *Escaping, s: []const u8) Writer.Error!void {
        if (self.mode == .html) return writeEscaped(s, self.out);
        var start: usize = 0;
        for (s, 0..) |ch, i| {
            const code: []const u8 = switch (ch) {
                '<' => "\\u003c",
                '>' => "\\u003e",
                '&' => "\\u0026",
                else => continue,
            };
            try self.out.writeAll(s[start..i]);
            try self.out.writeAll(code);
            start = i + 1;
        }
        try self.out.writeAll(s[start..]);
    }

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
        const self: *Escaping = @alignCast(@fieldParentPtr("writer", w));
        try self.put(w.buffered());
        w.end = 0;
        var n: usize = 0;
        for (data[0 .. data.len - 1]) |d| {
            try self.put(d);
            n += d.len;
        }
        const pattern = data[data.len - 1];
        for (0..splat) |_| try self.put(pattern);
        return n + pattern.len * splat;
    }
};

// --- tests ----------------------------------------------------------------------------

fn expectRender(expected: []const u8, comptime src: []const u8, args: anytype) !void {
    var buf: [512]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try render(&w, src, args);
    try std.testing.expectEqualStrings(expected, w.buffered());
}

test "holes escape by type" {
    try expectRender(
        "<a href=\"x?a=1&amp;b=2\">Nunu &amp; Willump</a> 3 1.5 euw",
        "<a href=\"{href}\">{name}</a> {n} {f:.1} {region}",
        .{ .href = "x?a=1&b=2", .name = "Nunu & Willump", .n = 3, .f = @as(f64, 1.46), .region = enum { euw }.euw },
    );
}

test "raw, optional, flag and attr" {
    const thin = true;
    try expectRender(
        "<li class=\"thin\" data-games=\"5\"><b>hi</b></li>",
        "<li{thin}{games}>{body}{none}</li>",
        .{
            .thin = flag(thin, "class=\"thin\""),
            .games = attr("data-games", 5),
            .body = trusted("<b>hi</b>"),
            .none = @as(?[]const u8, null),
        },
    );
}

test "plain braces, {{ and script holes" {
    try expectRender(
        "<script>try{f(3)}catch(e){}</script><p>{x}</p>",
        "<script>try{f({n})}catch(e){}</script><p>{{x}</p>",
        .{ .n = 3 },
    );
}

test "nested templates, calls and each" {
    const Item = struct { name: []const u8, games: u32 };
    const items = [_]Item{ .{ .name = "Ahri", .games = 2 }, .{ .name = "K'Sante", .games = 1 } };
    const row = struct {
        fn f(unit: []const u8, w: *Writer, it: Item) !void {
            try render(w, "<li>{name} {games} {unit}</li>", .{ .name = it.name, .games = it.games, .unit = unit });
        }
    }.f;
    const heading = struct {
        fn f(w: *Writer, text: []const u8, games: u32) !void {
            try render(w, "<h2>{text} <span>{games}</span></h2>", .{ .text = text, .games = games });
        }
    }.f;
    try expectRender(
        "<div><h2>Picks <span>3</span></h2><ul><li>Ahri 2 games</li><li>K&#39;Sante 1 games</li></ul><i>x</i></div>",
        "<div>{title}<ul>{rows}</ul>{note}</div>",
        .{
            .title = call(heading, .{ "Picks", @as(u32, 3) }),
            .rows = each(&items, @as([]const u8, "games"), row),
            .note = t("<i>{s}</i>", .{ .s = "x" }),
        },
    );
}

test "format values escape as they stream" {
    const V = struct {
        pub fn format(_: @This(), w: *Writer) Writer.Error!void {
            try w.writeAll("a<b");
        }
    };
    try expectRender("<p>a&lt;b</p>", "<p>{v}</p>", .{ .v = V{} });
}

test "parts may leave tags open" {
    var buf: [64]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try renderPart(&w, "<main>{x}", .{ .x = 1 });
    try renderPart(&w, "</main>", .{});
    try std.testing.expectEqualStrings("<main>1</main>", w.buffered());
}

test "void and self-closing tags, comments, doctype" {
    try expectRender(
        "<!doctype html><!-- {x} --><p><br><img src=\"a\"><svg><line x1=\"1\"/></svg></p>",
        "<!doctype html><!-- {x} --><p><br><img src=\"{src}\"><svg><line x1=\"{x}\"/></svg></p>",
        .{ .src = "a", .x = 1 },
    );
}

test "escaping follows the hole's position" {
    const Bold = struct {
        pub fn render(_: @This(), w: *Writer) Writer.Error!void {
            try w.writeAll("<b>\"x\"</b>");
        }
    };
    const Link = struct {
        pub fn render(_: @This(), w: *Writer) Writer.Error!void {
            try w.writeAll("../a.html?x=1&y=2");
        }
    };
    try expectRender(
        "<b>\"x\"</b><p title=\"&lt;b&gt;&quot;x&quot;&lt;/b&gt;\"></p>" ++
            "<a href=\"about:invalid#tpl\"></a><a href=\"https://x.io/?a=1&amp;b\"></a>" ++
            "<a href=\"../a.html?x=1&amp;y=2\"></a><a href=\"../javascript:x\"></a>",
        "{b}<p title=\"{b2}\"></p><a href=\"{bad}\"></a><a href=\"{good}\"></a>" ++
            "<a href=\"{link}\"></a><a href=\"../{rel}\"></a>",
        .{ .b = Bold{}, .b2 = Bold{}, .bad = " JavaScript:alert(1)", .good = "https://x.io/?a=1&b", .link = Link{}, .rel = "javascript:x" },
    );
}

test "json in a script can't end it" {
    try expectRender(
        "<script type=\"application/json\">{\"name\":\"\\u003c/script\\u003e\",\"n\":2}</script>",
        "<script type=\"application/json\">{data}</script>",
        .{ .data = json(.{ .name = "</script>", .n = 2 }) },
    );
}

test "URL holes: the scheme is checked with the text around the hole, components too" {
    const Js = struct {
        pub fn render(_: @This(), w: *Writer) Writer.Error!void {
            try w.writeAll("javascript:alert(1)");
        }
    };
    try expectRender(
        "<a href=\"about:invalid#tpl:x\"></a><a href=\"learn.html\"></a>" ++
            "<a href=\"https://x.io/javascript:x\"></a><img src=\"about:invalid#tpl\"><a href=\"../a/x:y\"></a>",
        "<a href=\"{bad}:x\"></a><a href=\"{page}.html\"></a>" ++
            "<a href=\"https://x.io/{fixed}\"></a><img src=\"{js}\"><a href=\"{root}a/{slug}\"></a>",
        .{ .bad = "javascript", .page = "learn", .fixed = "javascript:x", .js = Js{}, .root = "../", .slug = "x:y" },
    );
}

test "tpl.attr escapes as a quoted hole of its attribute" {
    const Colour = struct {
        pub fn format(_: @This(), w: *Writer) Writer.Error!void {
            try w.writeAll("color:oklch(0.7 0.1 50)");
        }
    };
    try expectRender(
        "<a href=\"about:invalid#tpl\" title=\"a&amp;b\"></a><i style=\"color:oklch(0.7 0.1 50)\"></i>",
        "<a{href}{title}></a><i{style}></i>",
        .{ .href = attr("href", "javascript:x"), .title = attr("title", "a&b"), .style = attr("style", Colour{}) },
    );
}

test "unquoted attribute values aren't names" {
    try expectRender("<input type=search name=search>", "<input type=search name=search>", .{});
}
