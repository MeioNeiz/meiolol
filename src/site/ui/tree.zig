//! Typed node tree. Components build it with `H` (one arena per render); backends read
//! it: html.zig (server bytes), diff.zig (keyed DOM patching in ui.wasm), check.zig
//! (lint and queries in plain `zig build test`).
//!
//!     h.tr(.{ .key = x.id, .class = "row", .on_click = h.on(t, .{ .open = x.id }) }, .{
//!         h.td(.{ .class = "num" }, .{rank}),
//!         h.td(.{ .data_name = {} }, .{x.name}),
//!     })
//!
//! Attributes are an anonymous struct, checked at compile time: `_` in a field name is
//! `-`; `key` keys the node among its siblings; `on_<event>` takes `h.on(component,
//! msg)`; any other `on*`, `srcdoc` and a string `style` are compile errors (style takes
//! `h.vars`, numbers and scale colours only); href/src/action... are scheme-checked by
//! tpl's own check, for both backends. Values: strings, numbers, enums (tag name), void and true
//! (present), false and null (absent); `aria_*` bools write "true"/"false".
//! Children are a tuple of nodes, node slices (`List.items`), optionals, strings and
//! numbers; neighbouring strings and numbers become one text node. There is no raw
//! HTML and no <script> or <style> tag, so escaping has two contexts (text, attribute
//! value) and both are tpl.writeEscaped.
const std = @import("std");
const tpl = @import("tpl");
const figures = @import("fmt.zig");
const Allocator = std.mem.Allocator;

pub const Tag = enum(u8) {
    @"#text",
    a,
    abbr,
    b,
    button,
    caption,
    col,
    colgroup,
    details,
    dialog,
    div,
    em,
    figure,
    footer,
    form,
    h1,
    h2,
    h3,
    h4,
    header,
    i,
    img,
    input,
    label,
    li,
    nav,
    ol,
    option,
    p,
    s,
    section,
    select,
    small,
    span,
    strong,
    summary,
    table,
    tbody,
    td,
    th,
    thead,
    time,
    tr,
    ul,
    // SVG from here: created in the SVG namespace
    svg,
    circle,
    clipPath,
    defs,
    ellipse,
    g,
    line,
    linearGradient,
    mask,
    path,
    polygon,
    polyline,
    rect,
    stop,
    text,
    title,
    tspan,
    use,

    pub fn isSvg(t: Tag) bool {
        return @backingInt(t) >= @backingInt(Tag.svg);
    }

    pub fn isVoid(t: Tag) bool {
        return t == .col or t == .img or t == .input;
    }
};

pub const Ev = enum(u4) {
    click,
    input,
    change,
    keydown,
    focusin,
    focusout,
    pointerdown,
    pointermove,
    pointerup,
    pointerleave,
    pointercancel,
    toggle,
};

/// A DOM event as Zig sees it. Pointer x is relative to the handler's element, w its width
pub const Event = struct {
    kind: Ev,
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    pointer: i32 = 0,
    /// The input's value, or the key for keydown
    text: []const u8 = "",
    /// The handler's node: its DOM id (for pointer capture)
    dom: u32 = 0,
    /// Set by the handler: preventDefault
    handled: bool = false,
    /// Set by the handler: capture the pointer on the handler's element
    capture: bool = false,
    /// Set by the handler: the URL change gets a history entry (Back undoes it), not a
    /// replaced one
    push: bool = false,
    /// Set by the handler: done to the node marked `data_ref` once the DOM is patched
    after: ?After = null,
};

pub const After = struct {
    /// click: a link chosen by keyboard follows itself
    op: enum { focus, scroll, show, hide, click },
    /// The `data-ref` value of the node in the new tree
    ref: []const u8,
};

/// A message bound to a component: `h.on(self, .{ .sort = .w })`. Typed at the call,
/// stored as bytes so the tree stays one type
pub const Handler = struct {
    target: *anyopaque,
    call: *const fn (*anyopaque, *const [msg_max]u8, *Event) void,
    msg: [msg_max]u8 align(8),
    ev: Ev = .click,
};
pub const msg_max = 16;

pub const N = enum(u32) { none = std.math.maxInt(u32), _ };

pub const Attr = struct { name: []const u8, value: []const u8 };

pub const Node = struct {
    tag: Tag,
    /// Bit per Ev with a handler
    events: u16 = 0,
    n_attrs: u16 = 0,
    key: u32 = 0,
    parent: u32 = 0,
    /// DOM id, set by hydration or the diff
    dom: u32 = 0,
    attrs: u32 = 0,
    kids: u32 = 0,
    n_kids: u32 = 0,
    handlers: u32 = 0,
    text: []const u8 = "",
};

pub const Tree = struct {
    nodes: std.ArrayList(Node) = .empty,
    kids: std.ArrayList(N) = .empty,
    attrs: std.ArrayList(Attr) = .empty,
    handlers: std.ArrayList(Handler) = .empty,
    root: N = .none,
    /// Bit per Ev any node handles: what the island listens for
    events: u16 = 0,

    pub fn node(t: *const Tree, n: N) *Node {
        return &t.nodes.items[@backingInt(n)];
    }

    pub fn kidsOf(t: *const Tree, n: N) []const N {
        const x = t.node(n);
        return t.kids.items[x.kids..][0..x.n_kids];
    }

    pub fn attrsOf(t: *const Tree, n: N) []const Attr {
        const x = t.node(n);
        return t.attrs.items[x.attrs..][0..x.n_attrs];
    }

    pub fn attr(t: *const Tree, n: N, name: []const u8) ?[]const u8 {
        for (t.attrsOf(n)) |a| if (std.mem.eql(u8, a.name, name)) return a.value;
        return null;
    }

    pub fn handler(t: *const Tree, n: N, ev: Ev) ?*Handler {
        const x = t.node(n);
        const bit = @as(u16, 1) << @backingInt(ev);
        if (x.events & bit == 0) return null;
        const before: u16 = x.events & (bit - 1);
        return &t.handlers.items[x.handlers + @popCount(before)];
    }

    /// Text of the subtree as the reader sees it run together
    pub fn textOf(t: *const Tree, n: N, w: *std.Io.Writer) !void {
        const x = t.node(n);
        if (x.tag == .@"#text") return w.writeAll(x.text);
        for (t.kidsOf(n)) |k| try t.textOf(k, w);
    }

    /// First node in pre-order whose attribute `name` is `value` (null: present)
    pub fn find(t: *const Tree, from: N, name: []const u8, value: ?[]const u8) ?N {
        if (t.attr(from, name)) |v| if (value == null or std.mem.eql(u8, v, value.?)) return from;
        for (t.kidsOf(from)) |k| if (t.find(k, name, value)) |f| return f;
        return null;
    }

    pub fn count(t: *const Tree, from: N, name: []const u8) usize {
        var c: usize = @intFromBool(t.attr(from, name) != null);
        for (t.kidsOf(from)) |k| c += t.count(k, name);
        return c;
    }
};

/// `h.vars(.{ .x = 31.5 })`: ` --x:31.5` for a style attribute. Numbers and scale colours
/// (fmt.WrColour) only, so a style value never carries data as CSS text
pub const Vars = struct { css: []const u8 };

/// `h.cls(.{ .thin = g < 1000, .off = s < 10 })` plus a fixed base: "row thin"
pub const Class = struct { s: []const u8 };

/// A growing list of sibling nodes, for loops
pub const List = struct {
    h: *H,
    items: std.ArrayList(N) = .empty,

    pub fn add(l: *List, n: N) void {
        if (n == .none) return;
        l.items.append(l.h.mem, n) catch {
            l.h.oom = true;
        };
    }

    pub fn done(l: *const List) []const N {
        return l.items.items;
    }
};

/// The builder. Never fails mid-expression: out of memory is sticky and checked once
pub const H = struct {
    mem: Allocator,
    t: *Tree,
    oom: bool = false,
    /// Scratch for one text run
    run: std.ArrayList(u8) = .empty,

    pub fn init(mem: Allocator, t: *Tree) H {
        return .{ .mem = mem, .t = t };
    }

    pub fn fmt(h: *H, comptime f: []const u8, args: anytype) []const u8 {
        return h.mem.print(f, args) catch {
            h.oom = true;
            return "";
        };
    }

    pub fn list(h: *H) List {
        return .{ .h = h };
    }

    pub fn on(h: *H, target: anytype, msg: @TypeOf(target.*).Msg) Handler {
        _ = h;
        const T = @TypeOf(target.*);
        comptime if (@sizeOf(T.Msg) > msg_max) @compileError(@typeName(T) ++ ".Msg is over 16 bytes: pass an index, not the value");
        const thunk = struct {
            fn call(ptr: *anyopaque, m: *const [msg_max]u8, ev: *Event) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                var v: T.Msg = undefined;
                @memcpy(std.mem.asBytes(&v), m[0..@sizeOf(T.Msg)]);
                self.update(v, ev);
            }
        };
        var hd: Handler = .{ .target = target, .call = thunk.call, .msg = @splat(0) };
        @memcpy(hd.msg[0..@sizeOf(T.Msg)], std.mem.asBytes(&msg));
        return hd;
    }

    pub fn vars(h: *H, v: anytype) Vars {
        var w: std.ArrayList(u8) = .empty;
        const V = @TypeOf(v);
        inline for (@typeInfo(V).@"struct".field_names, 0..) |f, i| {
            const x = @field(v, f);
            const name = (if (i == 0) "--" else ";--") ++ f ++ ":";
            const X = @TypeOf(x);
            if (X == figures.WrColour or X == figures.Step or X == figures.Fill) {
                w.print(h.mem, name ++ "{f}", .{x}) catch {
                    h.oom = true;
                };
            } else {
                comptime if (!isNumber(@TypeOf(x))) @compileError("h.vars ." ++ f ++ ": numbers and scale colours (fmt.WrColour, Step, Fill) only");
                h.cssVar(&w, name, switch (@typeInfo(@TypeOf(x))) {
                    .int, .comptime_int => @floatFromInt(x),
                    else => @floatCast(x),
                });
            }
        }
        return .{ .css = w.items };
    }

    fn cssVar(h: *H, w: *std.ArrayList(u8), name: []const u8, x: f64) void {
        w.appendSlice(h.mem, name) catch {};
        h.number(w, x);
    }

    /// Up to two decimals, trailing zeros trimmed: no float formatter in the wasm
    fn number(h: *H, w: *std.ArrayList(u8), x: f64) void {
        var buf: [32]u8 = undefined;
        var bw: std.Io.Writer = .fixed(&buf);
        figures.fixed(&bw, x, 2, true) catch {};
        w.appendSlice(h.mem, bw.buffered()) catch {
            h.oom = true;
        };
    }

    fn numStr(h: *H, x: f64) []const u8 {
        var w: std.ArrayList(u8) = .empty;
        h.number(&w, x);
        return w.items;
    }

    pub fn cls(h: *H, comptime base: []const u8, flags: anytype) Class {
        const F = @TypeOf(flags);
        const names = @typeInfo(F).@"struct".field_names;
        var set: [names.len]bool = undefined;
        inline for (names, 0..) |f, i| set[i] = @field(flags, f);
        return h.classes(base, comptime names[0..names.len], &set);
    }

    fn classes(h: *H, base: []const u8, names: []const [:0]const u8, set: []const bool) Class {
        var w: std.ArrayList(u8) = .empty;
        w.appendSlice(h.mem, base) catch {};
        for (names, set) |f, yes| if (yes) {
            if (w.items.len > 0) w.append(h.mem, ' ') catch {};
            w.appendSlice(h.mem, f) catch {};
        };
        return .{ .s = w.items };
    }

    pub fn text(h: *H, s: []const u8) N {
        return h.push(.{ .tag = .@"#text", .text = s });
    }

    fn push(h: *H, n: Node) N {
        h.t.nodes.append(h.mem, n) catch {
            h.oom = true;
            return .none;
        };
        return @fromBackingInt(@as(u32, @intCast(h.t.nodes.items.len - 1)));
    }

    /// The typed front: checks and converts at compile time, then hands plain arrays to
    /// `make`, so each call site costs a few stores and one call (ui.wasm size)
    pub fn el(h: *H, comptime tag: Tag, attrs: anytype, kids: anytype) N {
        @setEvalBranchQuota(1_000_000);
        const A = @TypeOf(attrs);
        const fields = @typeInfo(A).@"struct".field_names;
        var as: [fields.len]Attr = undefined;
        var na: usize = 0;
        var hs: [@typeInfo(Ev).@"enum".field_names.len]Handler = undefined;
        var nh: usize = 0;
        var events: u16 = 0;
        var key: u32 = 0;
        // Handlers in Ev order, so Tree.handler finds one by popcount. A null one (a
        // component's optional `on`) is no handler
        inline for (@typeInfo(Ev).@"enum".field_names) |evn| {
            if (@hasField(A, "on_" ++ evn)) {
                const F = @FieldType(A, "on_" ++ evn);
                if (F != Handler and F != ?Handler) @compileError(".on_" ++ evn ++ " takes h.on(component, msg)");
                const hv: ?Handler = @field(attrs, "on_" ++ evn);
                if (hv) |x| {
                    hs[nh] = x;
                    hs[nh].ev = @field(Ev, evn);
                    nh += 1;
                    events |= @as(u16, 1) << @backingInt(@field(Ev, evn));
                }
            }
        }
        // Values known at compile time (literals, catalogue words) become one static
        // array in the binary; only the rest are stored at run time
        const info = @typeInfo(A).@"struct";
        const static = comptime blk: {
            var arr: []const Attr = &.{};
            for (fields, 0..) |f, i| {
                if (!info.field_attrs[i].@"comptime" or std.mem.eql(u8, f, "key") or std.mem.startsWith(u8, f, "on_")) continue;
                const name = attrName(f);
                const v = @field(attrs, f);
                if (staticValue(attrKind(name), v)) |val| arr = arr ++ [_]Attr{.{ .name = name, .value = val }};
            }
            break :blk arr;
        };
        inline for (fields, 0..) |f, fi| {
            if (comptime std.mem.startsWith(u8, f, "on_")) {
                comptime if (!@hasField(Ev, f[3..])) @compileError("no event " ++ f[3..]);
                continue;
            }
            if (comptime info.field_attrs[fi].@"comptime" and !std.mem.eql(u8, f, "key")) continue;
            const v = @field(attrs, f);
            if (comptime std.mem.eql(u8, f, "key")) {
                key = keyOf(v);
            } else {
                const name = comptime attrName(f);
                if (h.attrValue(comptime attrKind(name), v)) |val| {
                    as[na] = .{ .name = name, .value = val };
                    na += 1;
                }
            }
        }
        const K = @TypeOf(kids);
        if (K == Text) return h.make(tag, static, as[0..na], hs[0..nh], events, key, &.{.{ .text = kids.s }});
        const kf = @typeInfo(K).@"struct";
        if (!kf.is_tuple) @compileError("children go in a tuple: .{ ... }");
        var ks: [kf.field_names.len]Kid = undefined;
        inline for (0..kf.field_names.len) |i| ks[i] = toKid(kids[i]);
        return h.make(tag, static, as[0..na], hs[0..nh], events, key, &ks);
    }

    const Kid = union(enum) { none, node: N, nodes: []const N, text: []const u8, int: i64, float: f64 };

    inline fn toKid(k: anytype) Kid {
        if (@typeInfo(@TypeOf(k)) == .optional) return if (k) |v| toKidPlain(v) else .none;
        return toKidPlain(k);
    }

    inline fn toKidPlain(k: anytype) Kid {
        const K = @TypeOf(k);
        if (K == N) return .{ .node = k };
        if (K == []const N or K == []N) return .{ .nodes = k };
        if (@typeInfo(K) == .pointer and @typeInfo(K).pointer.size == .one and @typeInfo(@typeInfo(K).pointer.child) == .array and
            @typeInfo(@typeInfo(K).pointer.child).array.child == N) return .{ .nodes = k };
        if (K == Text) return .{ .text = k.s };
        if (comptime isString(K)) return .{ .text = k };
        if (K == void) return .none;
        return switch (@typeInfo(K)) {
            .int, .comptime_int => .{ .int = @intCast(k) },
            .float, .comptime_float => .{ .float = @floatCast(k) },
            else => @compileError("can't be a child: " ++ @typeName(K)),
        };
    }

    noinline fn make(h: *H, tag: Tag, static: []const Attr, as: []const Attr, hs: []const Handler, events: u16, key: u32, ks: []const Kid) N {
        var n: Node = .{ .tag = tag, .events = events, .key = key };
        h.t.events |= events;
        n.attrs = @intCast(h.t.attrs.items.len);
        n.n_attrs = @intCast(static.len + as.len);
        h.t.attrs.appendSlice(h.mem, static) catch {
            h.oom = true;
        };
        h.t.attrs.appendSlice(h.mem, as) catch {
            h.oom = true;
        };
        n.handlers = @intCast(h.t.handlers.items.len);
        h.t.handlers.appendSlice(h.mem, hs) catch {
            h.oom = true;
        };
        // Kids built first (they are arguments), so they go straight into the shared kids
        // array; neighbouring text and numbers merge into one text node
        n.kids = @intCast(h.t.kids.items.len);
        h.run.clearRetainingCapacity();
        for (ks) |k| switch (k) {
            .none => {},
            .node => |x| {
                h.flushRun();
                h.kid(x);
            },
            .nodes => |xs| {
                h.flushRun();
                for (xs) |x| h.kid(x);
            },
            .text => |s| h.run.appendSlice(h.mem, s) catch {},
            .int => |v| h.run.print(h.mem, "{d}", .{v}) catch {},
            .float => |v| h.number(&h.run, v),
        };
        h.flushRun();
        n.n_kids = @intCast(h.t.kids.items.len - n.kids);
        const me = h.push(n);
        if (me != .none) for (h.t.kids.items[n.kids..]) |k| {
            h.t.node(k).parent = @backingInt(me);
        };
        h.t.root = me;
        return me;
    }

    fn flushRun(h: *H) void {
        if (h.run.items.len == 0) return;
        const s = h.mem.dupe(u8, h.run.items) catch {
            h.oom = true;
            return;
        };
        h.run.clearRetainingCapacity();
        h.kid(h.text(s));
    }

    fn kid(h: *H, n: N) void {
        if (n == .none) return;
        h.t.kids.append(h.mem, n) catch {
            h.oom = true;
        };
    }

    const AttrKind = enum { plain, url, aria, style, class };

    fn attrKind(comptime name: []const u8) AttrKind {
        if (std.mem.eql(u8, name, "style")) return .style;
        if (std.mem.eql(u8, name, "class")) return .class;
        if (tpl.isUrlAttr(name)) return .url;
        if (std.mem.startsWith(u8, name, "aria-")) return .aria;
        return .plain;
    }

    inline fn attrValue(h: *H, comptime kind: AttrKind, v: anytype) ?[]const u8 {
        const V = @TypeOf(v);
        if (kind == .style and V != Vars and V != ?Vars) @compileError("style takes h.vars(.{ ... }), numbers only");
        if (V == Class) return if (v.s.len == 0) null else v.s;
        if (V == Vars) return v.css;
        if (V == Text) return v.s;
        if (comptime isString(V)) return if (kind == .url) checkUrl(v) else v;
        switch (@typeInfo(V)) {
            .int, .comptime_int => return h.numStr(@floatFromInt(v)),
            .float, .comptime_float => return h.numStr(@floatCast(v)),
            .bool => {
                if (kind == .aria) return if (v) "true" else "false";
                return if (v) "" else null;
            },
            .void => return "",
            .null => return null,
            .@"enum" => return @tagName(v),
            .optional => return if (v) |x| h.attrValue(kind, x) else null,
            else => @compileError("an attribute can't take " ++ @typeName(V)),
        }
    }

    /// attrValue at compile time
    fn staticValue(comptime kind: AttrKind, comptime v: anytype) ?[]const u8 {
        const V = @TypeOf(v);
        if (kind == .style and V != Vars and V != ?Vars) @compileError("style takes h.vars(.{ ... }), numbers only");
        if (V == Text) return v.s;
        if (comptime isString(V)) return if (kind == .url) checkUrl(v) else v;
        return switch (@typeInfo(V)) {
            .int, .comptime_int, .float, .comptime_float => std.fmt.comptimePrint("{d}", .{v}),
            .bool => if (kind == .aria) (if (v) "true" else "false") else if (v) "" else null,
            .void => "",
            .null => null,
            .@"enum", .enum_literal => @tagName(v),
            .optional => if (v) |x| staticValue(kind, x) else null,
            else => @compileError("an attribute can't take " ++ @typeName(V)),
        };
    }

    fn checkUrl(v: []const u8) []const u8 {
        return if (tpl.safeUrl("", v, "")) v else "about:invalid#tpl";
    }

    // A helper per common tag, so a component reads as markup; h.el(.tag, ...) for the rest
    pub inline fn a(h: *H, at: anytype, k: anytype) N {
        return h.el(.a, at, k);
    }
    pub inline fn b(h: *H, at: anytype, k: anytype) N {
        return h.el(.b, at, k);
    }
    pub inline fn button(h: *H, at: anytype, k: anytype) N {
        return h.el(.button, at, k);
    }
    pub inline fn div(h: *H, at: anytype, k: anytype) N {
        return h.el(.div, at, k);
    }
    pub inline fn h2(h: *H, at: anytype, k: anytype) N {
        return h.el(.h2, at, k);
    }
    pub inline fn h3(h: *H, at: anytype, k: anytype) N {
        return h.el(.h3, at, k);
    }
    pub inline fn label(h: *H, at: anytype, k: anytype) N {
        return h.el(.label, at, k);
    }
    pub inline fn li(h: *H, at: anytype, k: anytype) N {
        return h.el(.li, at, k);
    }
    pub inline fn p(h: *H, at: anytype, k: anytype) N {
        return h.el(.p, at, k);
    }
    pub inline fn section(h: *H, at: anytype, k: anytype) N {
        return h.el(.section, at, k);
    }
    pub inline fn small(h: *H, at: anytype, k: anytype) N {
        return h.el(.small, at, k);
    }
    pub inline fn span(h: *H, at: anytype, k: anytype) N {
        return h.el(.span, at, k);
    }
    pub inline fn strong(h: *H, at: anytype, k: anytype) N {
        return h.el(.strong, at, k);
    }
    pub inline fn table(h: *H, at: anytype, k: anytype) N {
        return h.el(.table, at, k);
    }
    pub inline fn tbody(h: *H, at: anytype, k: anytype) N {
        return h.el(.tbody, at, k);
    }
    pub inline fn td(h: *H, at: anytype, k: anytype) N {
        return h.el(.td, at, k);
    }
    pub inline fn th(h: *H, at: anytype, k: anytype) N {
        return h.el(.th, at, k);
    }
    pub inline fn thead(h: *H, at: anytype, k: anytype) N {
        return h.el(.thead, at, k);
    }
    pub inline fn tr(h: *H, at: anytype, k: anytype) N {
        return h.el(.tr, at, k);
    }
    pub inline fn ul(h: *H, at: anytype, k: anytype) N {
        return h.el(.ul, at, k);
    }
    pub inline fn svg(h: *H, at: anytype, k: anytype) N {
        return h.el(.svg, at, k);
    }
    pub inline fn g(h: *H, at: anytype, k: anytype) N {
        return h.el(.g, at, k);
    }
    pub inline fn path(h: *H, at: anytype, k: anytype) N {
        return h.el(.path, at, k);
    }
    pub inline fn line(h: *H, at: anytype, k: anytype) N {
        return h.el(.line, at, k);
    }
    pub inline fn rect(h: *H, at: anytype, k: anytype) N {
        return h.el(.rect, at, k);
    }
    pub inline fn circle(h: *H, at: anytype, k: anytype) N {
        return h.el(.circle, at, k);
    }
    pub inline fn img(h: *H, at: anytype) N {
        return h.el(.img, at, .{});
    }
    pub inline fn input(h: *H, at: anytype) N {
        return h.el(.input, at, .{});
    }
};

/// Catalogue words (phrase.zig): a child or an attribute value
pub const Text = struct { s: []const u8 };

fn keyOf(v: anytype) u32 {
    const V = @TypeOf(v);
    if (comptime isString(V)) return @truncate(std.hash.Wyhash.hash(0, v) | 1);
    if (comptime isNumber(V)) return @as(u32, @intCast(v)) +% 1;
    @compileError("key takes a string or an integer");
}

/// SVG's mixed-case attribute names, written as is
const svg_camel = [_][]const u8{ "viewBox", "preserveAspectRatio", "gradientUnits", "textLength" };

fn attrName(comptime f: []const u8) []const u8 {
    comptime {
        if (std.mem.eql(u8, f, "srcdoc")) @compileError("srcdoc is HTML: not in the tree");
        if (std.mem.eql(u8, f, "style")) return f;
        if (tpl.isCodeAttr(f)) @compileError("." ++ f ++ ": events go in .on_<event> = h.on(component, msg)");
        var out: [f.len]u8 = undefined;
        for (f, 0..) |c, i| {
            if (!(std.ascii.isLower(c) or std.ascii.isDigit(c) or c == '_')) {
                for (svg_camel) |ok| {
                    if (std.mem.eql(u8, ok, f)) break;
                } else @compileError("attribute ." ++ f ++ ": lower case, digits and _ only");
            }
            out[i] = if (c == '_') '-' else c;
        }
        const final = out;
        return &final;
    }
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
                .array => |arr| arr.child == u8,
                else => false,
            },
            else => false,
        },
        else => false,
    };
}
