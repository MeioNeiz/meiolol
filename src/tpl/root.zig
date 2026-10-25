//! HTML templates with named holes, parsed at compile time and escaped by where each hole
//! sits, so a mistake in escaping is a compile error rather than an injection.
//!
//!     const tpl = @import("tpl");
//!
//!     fn link(w: *std.Io.Writer, name: []const u8, page: []const u8, games: u32) !void {
//!         try tpl.render(w,
//!             \\<a href="{page}" title="{name}">{name}</a> <span>{games} games</span>
//!         , .{ .page = page, .name = name, .games = games });
//!     }
//!
//! `link(w, "Nunu & Willump", "javascript:alert(1)", 3)` writes
//! `<a href="about:invalid#tpl" title="Nunu &amp; Willump">Nunu &amp; Willump</a>
//! <span>3 games</span>`.
//!
//! What it guarantees
//!
//! - Every hole has a field in the args and every field a hole: a typo is a compile error.
//! - The template text is read as HTML at compile time. Each hole's context comes from its
//!   position, its value's type decides how it is written, and a pairing that can't be
//!   made safe is a compile error naming the hole.
//! - `render` and `t` templates balance their tags; `renderPart` is for layout pieces
//!   that open in one call and close in another.
//! - No allocator and no I/O beyond the `std.Io.Writer` it is given: it runs in wasm with
//!   a fixed-buffer writer.
//!
//! What it trusts: the template text itself (it is source code), `trusted` HTML, the markup
//! a component writes, and what a `format` type writes into an on* or style attribute.
//! A URL hole's scheme is checked, nothing else: `href="{x}"` may still point to another
//! site. A `render` or `format` value in a URL hole is buffered for the check, up to 2 KB.
//!
//! Holes
//!
//! - `{name}`, or `{name:options}` with std.fmt options for a number: `{gold:.1}`,
//!   `{secs:0>2}`. A name is a letter or `_`, then letters, digits and `_`; the options
//!   hold no space, newline, `{`, `;` or `,`.
//! - Any other brace is text, so most inline JS and CSS needs no escaping: `{ a: 1 }`,
//!   `p{ color: red }` and `try{f()}` are text. But `{a:1}` and `p{color:red}` are holes
//!   with options: write `{{` for a `{`.
//! - Inside `<!-- -->` nothing is a hole: comments are written as they are. A hole can't
//!   be a tag's name or sit in `<!...>`: write `&lt;{n}` for a less-than sign before one.
//! - A field may fill several holes.
//!
//! Values, by type
//!
//! - strings (`[]const u8`, `*const [n]u8`), numbers (the only values that take the
//!   hole's options) and enums (the tag name, or `format` if the enum has one)
//! - optionals: null writes nothing; `void` writes nothing
//! - components: anything with `pub fn render(self, w: *std.Io.Writer) !void`, written
//!   as is in text; `t`, `call` and `each` make them from templates and functions
//! - anything with `pub fn format(self, w: *std.Io.Writer) !void`, escaped as it streams
//! - slices and arrays of the above, one after another
//! - `trusted` HTML, `json` for scripts, `attr` and `flag` for holes inside a tag
//!
//! Contexts
//!
//! - text: escaped (`& < > " '`); components write their own markup
//! - quoted attribute value: escaped, components and `format` values included as they
//!   stream; `trusted`, `t`, `call` and `each` are compile errors (their markup would be
//!   escaped, their own holes twice)
//! - URL attribute (href, src, action, formaction, poster, cite, data, xlink:href) until
//!   its text fixes the scheme with a `:`, `/`, `?` or `#` before the hole: the value,
//!   with the attribute's text around the hole, must be relative or http, https or
//!   mailto, else it is written as `about:invalid#tpl`. A second hole before the scheme
//!   is fixed is a compile error. After that it is a plain attribute value
//! - on*, style and srcdoc attribute values are script, CSS and HTML once the browser
//!   decodes entities: a string is a compile error; numbers, enums and `format` values
//!   only
//! - inside a tag, outside quotes: only `attr`, `flag` or `trusted` (an unquoted string
//!   could add attributes)
//! - `<script>` and `<style>`: numbers, `json` or `trusted`, as HTML escaping is wrong
//!   there; data for JS goes in `<script type="application/json">{data}</script>`
//!
//! Tag and attribute names match in any case, as in HTML.
//!
//! Components
//!
//!     fn row(w: *std.Io.Writer, name: []const u8, games: u32) !void {
//!         try tpl.render(w, "<li>{name} <b>{games}</b></li>", .{ .name = name, .games = games });
//!     }
//!     try tpl.render(w, "<ul>{first}{rest}</ul>{note}", .{
//!         .first = tpl.call(row, .{ "Ahri", 2 }),
//!         .rest = tpl.each(champs, {}, rowOf), // rowOf(ctx, w, item), ctx `{}` here
//!         .note = tpl.when(champs.len == 0, tpl.t("<p>{none}</p>", .{ .none = "none yet" })),
//!     });

const std = @import("std");
const Writer = std.Io.Writer;

/// Writes the template `src` with each `{hole}` filled from the field of `args` with its
/// name, escaped for where the hole sits. The template must balance its tags.
pub fn render(w: *Writer, comptime src: []const u8, args: anytype) !void {
    return renderSegs(w, comptime parse(src, true), src, args);
}

/// As `render`, but tags may stay open or close ones opened by an earlier call: for page
/// layout split across functions
pub fn renderPart(w: *Writer, comptime src: []const u8, args: anytype) !void {
    return renderSegs(w, comptime parse(src, false), src, args);
}

/// A template as a value, to fill another template's hole; rendered there, as `render`
pub fn t(comptime src: []const u8, args: anytype) Template(src, @TypeOf(args)) {
    return .{ .args = args };
}

/// The type `t` returns. Naming it lets a function return a template without rendering it.
pub fn Template(comptime src: []const u8, comptime Args: type) type {
    return struct {
        args: Args,

        /// Marks markup a quoted attribute can't take
        pub const is_template = true;

        pub fn render(self: @This(), w: *Writer) !void {
            return renderSegs(w, comptime parse(src, true), src, self.args);
        }
    };
}

/// HTML written as is: what `trusted` and `flag` return
pub const Raw = struct {
    html: []const u8,

    pub fn render(self: Raw, w: *Writer) Writer.Error!void {
        return w.writeAll(self.html);
    }
};

/// HTML written as is: only for markup the program wrote, never for data (the long name
/// is on purpose). Allowed in text, inside a tag and in `<script>`
pub fn trusted(html: []const u8) Raw {
    return .{ .html = html };
}

/// `v` as JSON (std.json) for a `<script>` hole, with `<`, `>` and `&` as \u escapes so it
/// can't end the script or open a comment there
pub fn json(v: anytype) Json(@TypeOf(v)) {
    return .{ .value = v };
}

/// The type `json` returns
pub fn Json(comptime T: type) type {
    return struct {
        value: T,

        /// Marks a value a `<script>` hole takes
        pub const is_json = true;

        pub fn render(self: @This(), w: *Writer) Writer.Error!void {
            var buf: [64]u8 = undefined;
            var e: Escaping = .init(w, &buf, .script);
            std.json.Stringify.value(self.value, .{}, &e.writer) catch return error.WriteFailed;
            return e.writer.flush();
        }
    };
}

/// ` name="value"`, for a hole inside a tag: `<a{href}>`. The value is checked and escaped
/// as in a quoted hole of that attribute (a URL's scheme, a string in on* refused)
pub fn attr(comptime name: []const u8, value: anytype) Attr(name, @TypeOf(value)) {
    return .{ .value = value };
}

/// The type `attr` returns
pub fn Attr(comptime name: []const u8, comptime T: type) type {
    return struct {
        value: T,

        /// Marks a value a hole inside a tag takes
        pub const is_attr = true;

        const ctx = attrContext(name);

        pub fn render(self: @This(), w: *Writer) !void {
            comptime check(T, "tpl.attr(\"" ++ name ++ "\")", ctx);
            try w.writeAll(" " ++ name ++ "=\"");
            try writeValue(w, self.value, "", ctx, .{ "", "" });
            try w.writeByte('"');
        }
    };
}

/// ` html` when `on`, else nothing: boolean attributes and fixed classes inside a tag,
/// `<li{thin}>` with `.thin = tpl.flag(thin, "class=\"thin\"")`
pub fn flag(on: bool, comptime html: []const u8) ?Raw {
    return if (on) trusted(" " ++ html) else null;
}

/// `v` when `on`, else nothing
pub fn when(on: bool, v: anytype) ?@TypeOf(v) {
    return if (on) v else null;
}

/// A function call as a value: `func(w, args...)` when rendered, `w` the writer of the
/// template it fills. For components that take parameters
pub fn call(comptime func: anytype, args: anytype) Call(func, @TypeOf(args)) {
    return .{ .args = args };
}

/// The type `call` returns
pub fn Call(comptime func: anytype, comptime Args: type) type {
    return struct {
        args: Args,

        /// Marks markup a quoted attribute can't take
        pub const is_template = true;

        pub fn render(self: @This(), w: *Writer) @typeInfo(@TypeOf(func)).@"fn".return_type.? {
            return @call(.auto, func, .{w} ++ self.args);
        }
    };
}

/// `func(ctx, w, item)` for each of `items` when rendered: lists and table rows
pub fn each(items: anytype, ctx: anytype, comptime func: anytype) Each(@TypeOf(items), @TypeOf(ctx), func) {
    return .{ .items = items, .ctx = ctx };
}

/// The type `each` returns
pub fn Each(comptime Items: type, comptime Ctx: type, comptime func: anytype) type {
    return struct {
        items: Items,
        ctx: Ctx,

        /// Marks markup a quoted attribute can't take
        pub const is_template = true;

        pub fn render(self: @This(), w: *Writer) @typeInfo(@TypeOf(func)).@"fn".return_type.? {
            for (self.items) |item| try func(self.ctx, w, item);
        }
    };
}

/// `s` HTML-escaped as a std.fmt value, for writing outside a template:
/// `w.print("<td>{f}</td>", .{tpl.esc(name)})`. A template hole takes `s` itself
pub fn esc(s: []const u8) std.fmt.Alt([]const u8, writeEscaped) {
    return .{ .data = s };
}

/// Writes `s` with `& < > " '` as entities: safe in text and in quoted attribute values
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

/// Where a hole sits
const Context = enum {
    text,
    /// A quoted attribute value
    attr,
    /// A URL attribute's value until its scheme is fixed
    url,
    /// An on*, style or srcdoc attribute's value: script, CSS or HTML
    code,
    /// Inside a tag, outside quotes
    tag,
    /// In <script> or <style>
    script,
};

/// A parsed template: text written as is, and holes
const Seg = union(enum) {
    lit: []const u8,
    hole: struct {
        name: []const u8,
        spec: []const u8,
        ctx: Context,
        /// url: the value's text before and after the hole, for the scheme check
        around: [2][]const u8 = .{ "", "" },
        /// Offset in the template, for errors
        at: usize,
    },
};

const void_tags = [_][]const u8{
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr",
};

fn isVoid(name: []const u8) bool {
    for (void_tags) |v| if (std.ascii.eqlIgnoreCase(v, name)) return true;
    return false;
}

fn isNameStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn isName(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn isAttrName(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == ':' or c == '_';
}

/// A compile error naming the template text around `at`, message last (the build's
/// compile-error check matches the end of the line)
fn fail(comptime src: []const u8, comptime at: usize, comptime msg: []const u8) noreturn {
    const from = at -| 30;
    const to = @min(src.len, at + 30);
    var near = src[from..to].*;
    for (&near) |*ch| if (ch.* == '\n') {
        ch.* = ' ';
    };
    const dots = [2][]const u8{ if (from > 0) "..." else "", if (to < src.len) "..." else "" };
    @compileError("template \"" ++ dots[0] ++ &near ++ dots[1] ++ "\": " ++ msg);
}

/// The template as text and holes, each hole with its context. A small HTML tokenizer
/// (text, tag, quoted value, comment, script or style body) that tracks open elements;
/// `balanced` makes every element close, in order, within this template
fn parse(comptime src: []const u8, comptime balanced: bool) []const Seg {
    @setEvalBranchQuota(20_000 + 100 * src.len);
    comptime {
        var segs: []const Seg = &.{};
        // Literal text is src[lit_start..i]: slices, not copies
        var lit_start: usize = 0;
        // Open elements, innermost last
        var stack: []const []const u8 = &.{};
        const State = enum { text, tag, dq, sq, comment, script };
        var state: State = .text;
        var tag_name: []const u8 = "";
        // Where the tag's attributes start, after its name
        var attrs_start: usize = 0;
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
                if (lexHole(src, i)) |h| {
                    // `<{x}>` could open a <script> the parser never saw
                    if (state == .text and i > 0 and src[i - 1] == '<') fail(src, i, tag_name_hole);
                    segs = withLit(segs, src[lit_start..i]);
                    const ctx: Context = switch (state) {
                        .text => .text,
                        .tag => .tag,
                        .dq, .sq => attrContext(attr_name),
                        .script => .script,
                        .comment => unreachable,
                    };
                    const around = if (ctx == .url) urlAround(src, value_start, i, h.end) else null;
                    segs = segs ++ [_]Seg{.{ .hole = .{
                        .name = h.name,
                        .spec = h.spec,
                        .ctx = if (ctx == .url and around == null) .attr else ctx,
                        .around = around orelse .{ "", "" },
                        .at = i,
                    } }};
                    i = h.end;
                    lit_start = i;
                    continue;
                }
            }
            if (state == .script and std.ascii.startsWithIgnoreCase(src[i..], script_end)) {
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
                        const end = std.mem.findScalarPos(u8, src, i, '>') orelse fail(src, i, "unclosed <!");
                        if (findHole(src, i, end)) |at| fail(src, at, "a hole in <!...> isn't filled");
                        i = end + 1;
                    } else if (src[i] == '/') {
                        const end = std.mem.findScalarPos(u8, src, i, '>') orelse fail(src, i, "unclosed end tag");
                        if (findHole(src, i, end)) |at| fail(src, at, tag_name_hole);
                        stack = closeTag(src, i, std.mem.trim(u8, src[i + 1 .. end], " \n"), stack, balanced);
                        i = end + 1;
                    } else if (std.ascii.isAlphabetic(src[i])) {
                        var end = i;
                        while (end < src.len and (std.ascii.isAlphanumeric(src[end]) or src[end] == '-')) end += 1;
                        tag_name = src[i..end];
                        attrs_start = end;
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
                        checkAttrs(src, attrs_start, i - 1);
                        const self_closing = src[i - 2] == '/';
                        // Self-closing is SVG's; in HTML `<div/>` opens a div
                        if (self_closing and !isVoid(tag_name) and !inSvg(stack, tag_name)) {
                            fail(src, i, "<" ++ tag_name ++ "/> is not void and doesn't close in HTML");
                        }
                        if (!self_closing and !isVoid(tag_name)) {
                            stack = stack ++ [_][]const u8{tag_name};
                            if (std.ascii.eqlIgnoreCase(tag_name, "script") or std.ascii.eqlIgnoreCase(tag_name, "style")) {
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
                // `<!-->` and `<!--->` close too, as in HTML
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

/// The open elements after `</name>` at src[at]. Unbalanced (renderPart), an end tag may
/// close an element opened by an earlier call
fn closeTag(comptime src: []const u8, comptime at: usize, comptime name: []const u8, comptime stack: []const []const u8, comptime balanced: bool) []const []const u8 {
    if (isVoid(name)) fail(src, at, "</" ++ name ++ ">: void elements have no end tag");
    const open = if (stack.len > 0) stack[stack.len - 1] else {
        if (balanced) fail(src, at, "</" ++ name ++ "> closes nothing");
        return stack;
    };
    if (std.ascii.eqlIgnoreCase(open, name)) return stack[0 .. stack.len - 1];
    if (balanced) fail(src, at, "</" ++ name ++ "> closes <" ++ open ++ ">");
    return stack;
}

const tag_name_hole = "a tag's name can't come from a hole (`&lt;` for a less-than sign)";

/// The first hole in src[start..end], for text the parser skips
fn findHole(comptime src: []const u8, comptime start: usize, comptime end: usize) ?usize {
    for (start..end) |j| if (src[j] == '{' and lexHole(src, j) != null) return j;
    return null;
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
        if (std.mem.findScalar(u8, ":/?#", src[j]) != null) return null;
        if (src[j] == '{') if (lexHole(src, j)) |h| {
            after_hole = true;
            j = h.end;
            continue;
        };
        j += 1;
    }
    if (after_hole) fail(src, at, "a URL's scheme can't come from two holes");
    var k = end;
    while (k < src.len and std.mem.findScalar(u8, "\"'{", src[k]) == null) : (k += 1) {
        if (std.mem.findScalar(u8, ":/?#", src[k]) != null) {
            k += 1;
            break;
        }
    }
    return .{ src[start..at], src[end..k] };
}

fn attrContext(comptime name: []const u8) Context {
    return if (isCodeAttr(name)) .code else if (isUrlAttr(name)) .url else .attr;
}

/// on*, style and srcdoc values are script, CSS and HTML once entities are decoded
pub fn isCodeAttr(comptime name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, "style") or std.ascii.eqlIgnoreCase(name, "srcdoc") or
        (name.len > 2 and std.ascii.startsWithIgnoreCase(name, "on"));
}

/// Attributes whose value a browser loads or navigates to: a javascript: URL there runs
const url_attrs = [_][]const u8{ "href", "src", "action", "formaction", "poster", "cite", "data", "xlink:href" };

pub fn isUrlAttr(name: []const u8) bool {
    for (url_attrs) |u| if (std.ascii.eqlIgnoreCase(u, name)) return true;
    return false;
}

/// The attribute name before `="` at the end of `before`, spaces around `=` allowed
fn lastAttrName(comptime before: []const u8) []const u8 {
    var end = before.len;
    while (end > 0 and (before[end - 1] == '=' or std.ascii.isWhitespace(before[end - 1]))) end -= 1;
    var start = end;
    while (start > 0 and isAttrName(before[start - 1])) start -= 1;
    return before[start..end];
}

/// SVG elements that self-close; listed so an SVG fragment needs no <svg> around it
const svg_shapes = [_][]const u8{
    "circle", "ellipse", "line", "path", "polygon", "polyline", "rect", "stop", "use",
};

fn inSvg(comptime stack: []const []const u8, comptime name: []const u8) bool {
    if (std.ascii.eqlIgnoreCase(name, "svg")) return true;
    for (svg_shapes) |shape| if (std.ascii.eqlIgnoreCase(shape, name)) return true;
    for (stack) |open| if (std.ascii.eqlIgnoreCase(open, "svg")) return true;
    return false;
}

/// No attribute twice in one tag; src[start..end] is the tag after its name, up to `>`.
/// Holes outside quotes (tpl.attr, tpl.flag) aren't seen, so can still repeat one
fn checkAttrs(comptime src: []const u8, comptime start: usize, comptime end: usize) void {
    const attrs = src[start..end];
    var names: []const []const u8 = &.{};
    var i: usize = 0;
    while (i < attrs.len) {
        const c = attrs[i];
        if (c == '"' or c == '\'') {
            i = std.mem.findScalarPos(u8, attrs, i + 1, c).? + 1;
        } else if (c == '{') {
            i = (std.mem.findScalarPos(u8, attrs, i, '}') orelse attrs.len - 1) + 1;
        } else if (std.ascii.isAlphabetic(c)) {
            var j = i;
            while (j < attrs.len and isAttrName(attrs[j])) j += 1;
            const name = attrs[i..j];
            for (names) |n| if (std.ascii.eqlIgnoreCase(n, name)) fail(src, start + i, "attribute " ++ name ++ " twice");
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

const Lexed = struct { name: []const u8, spec: []const u8, end: usize };

/// `{name}` or `{name:spec}` at src[i], else null (a plain brace)
fn lexHole(comptime src: []const u8, comptime i: usize) ?Lexed {
    var j = i + 1;
    if (j >= src.len or !isNameStart(src[j])) return null;
    while (j < src.len and isName(src[j])) j += 1;
    const name = src[i + 1 .. j];
    if (j < src.len and src[j] == '}') return .{ .name = name, .spec = "", .end = j + 1 };
    if (j >= src.len or src[j] != ':') return null;
    const close = std.mem.findScalarPos(u8, src, j, '}') orelse return null;
    const spec = src[j + 1 .. close];
    for (spec) |ch| if (ch == '{' or ch == ' ' or ch == '\n' or ch == ';' or ch == ',') return null;
    return .{ .name = name, .spec = spec, .end = close + 1 };
}

// --- checking -------------------------------------------------------------------------

fn holeError(comptime where: []const u8, comptime msg: []const u8) noreturn {
    @compileError("template " ++ where ++ ": " ++ msg);
}

/// What a hole may hold where it sits; `where` names it in errors. writeValue relies on
/// it: what passes here, writeValue can write safely
fn check(comptime T: type, comptime where: []const u8, comptime ctx: Context) void {
    switch (@typeInfo(T)) {
        .optional => |o| return check(o.child, where, ctx),
        .void => return,
        else => {},
    }
    const name = @typeName(T);
    if (T == std.fmt.Alt([]const u8, writeEscaped)) holeError(where, "esc() value would be escaped twice; pass the string");
    if (@typeInfo(T) == .array and @typeInfo(T).array.child == u8) {
        holeError(where, "a " ++ name ++ " by value would write its bytes as numbers; pass a slice or pointer (&array)");
    }
    const value = isNumber(T) or isString(T) or @typeInfo(T) == .@"enum" or hasDecl(T, "render") or hasDecl(T, "format");
    switch (ctx) {
        .text => {},
        .attr, .url, .code => {
            if (T == Raw) holeError(where, "tpl.trusted HTML inside an attribute value would be escaped; pass the text");
            if (hasDecl(T, "is_template")) {
                holeError(where, "a " ++ name ++ " in an attribute writes markup, which would be escaped (its own holes twice); pass text or a `format` value");
            }
            if (ctx == .url and !value) {
                holeError(where, "a URL attribute takes a string, number, enum or a `render` or `format` value (scheme-checked), not " ++ name);
            }
            if (ctx == .code and isString(T)) {
                holeError(where, "a string in an on*, style or srcdoc attribute is script, CSS or HTML once entities are decoded; pass a number or a `format` value");
            }
        },
        .tag => if (T != Raw and !hasDecl(T, "is_attr")) {
            holeError(where, "a " ++ name ++ " hole inside a tag must be quoted, or be tpl.attr, tpl.flag or tpl.trusted");
        },
        .script => if (!isNumber(T) and T != Raw and !hasDecl(T, "is_json")) {
            holeError(where, "a " ++ name ++ " hole in <script> or <style> needs JS or CSS escaping; pass tpl.json or tpl.trusted");
        },
    }
    if (value) return;
    if (Item(T)) |I| return check(I, where, ctx);
    holeError(where, "can't write a " ++ name);
}

/// T without optionals, slices and arrays around it: what the hole's options format
fn Base(comptime T: type) type {
    if (@typeInfo(T) == .optional) return Base(@typeInfo(T).optional.child);
    if (isString(T)) return T;
    return if (Item(T)) |I| Base(I) else T;
}

/// The element type of a slice or array (or a pointer to one), else null
fn Item(comptime T: type) ?type {
    return switch (@typeInfo(T)) {
        .pointer => |p| switch (p.size) {
            .slice => p.child,
            .one => switch (@typeInfo(p.child)) {
                .array => |a| a.child,
                else => null,
            },
            else => null,
        },
        .array => |a| a.child,
        else => null,
    };
}

fn isNumber(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .comptime_int, .float, .comptime_float => true,
        else => false,
    };
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

// --- rendering ------------------------------------------------------------------------

fn renderSegs(w: *Writer, comptime segs: []const Seg, comptime src: []const u8, args: anytype) !void {
    const Args = @TypeOf(args);
    comptime {
        for (@typeInfo(Args).@"struct".field_names) |field| {
            for (segs) |s| {
                if (s == .hole and std.mem.eql(u8, s.hole.name, field)) break;
            } else fail(src, 0, "field ." ++ field ++ " has no {" ++ field ++ "} hole");
        }
        for (segs) |s| if (s == .hole) {
            if (!@hasField(Args, s.hole.name)) fail(src, s.hole.at, "hole {" ++ s.hole.name ++ "} has no field in the args");
            const T = @FieldType(Args, s.hole.name);
            check(T, "hole {" ++ s.hole.name ++ "}", s.hole.ctx);
            if (s.hole.spec.len > 0 and !isNumber(Base(T))) {
                fail(src, s.hole.at, "{" ++ s.hole.name ++ ":" ++ s.hole.spec ++ "}: options are for numbers, not " ++ @typeName(T));
            }
        };
    }
    inline for (segs) |s| switch (s) {
        .lit => |l| try w.writeAll(l),
        .hole => |h| try writeValue(w, @field(args, h.name), h.spec, h.ctx, h.around),
    };
}

/// `v` as `check` let it through for `ctx`
fn writeValue(w: *Writer, v: anytype, comptime spec: []const u8, comptime ctx: Context, comptime around: [2][]const u8) !void {
    const T = @TypeOf(v);
    switch (@typeInfo(T)) {
        .int, .comptime_int, .float, .comptime_float => return w.print("{d" ++ (if (spec.len > 0) ":" ++ spec else "") ++ "}", .{v}),
        .@"enum" => if (!@hasDecl(T, "render") and !@hasDecl(T, "format")) return writeText(w, @tagName(v), ctx, around),
        .optional => return if (v) |inner| writeValue(w, inner, spec, ctx, around),
        .void => return,
        else => {},
    }
    if (comptime isString(T)) return writeText(w, v, ctx, around);
    if (comptime hasDecl(T, "render") or hasDecl(T, "format")) {
        if (ctx == .url) {
            // Whole, for the scheme check: URLs are short (a longer one fails, WriteFailed)
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
    for (v) |item| try writeValue(w, item, spec, ctx, around);
}

fn writeText(w: *Writer, s: []const u8, comptime ctx: Context, comptime around: [2][]const u8) !void {
    if (ctx == .url and !safeUrl(around[0], s, around[1])) return w.writeAll("about:invalid#tpl");
    return writeEscaped(s, w);
}

/// Relative, or http, https or mailto: what a page links to. Anything else with a
/// scheme (javascript:, data:, or one hidden by whitespace) is refused. The URL is
/// `before ++ s ++ after`
pub fn safeUrl(comptime before: []const u8, s: []const u8, comptime after: []const u8) bool {
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

test {
    _ = @import("tests.zig");
}
