//! Styles beside components: each declares `pub const css` (its rules in `@layer
//! components`, every selector under its `.c-<name>`); `head` is the layer order, tokens
//! and base, and src/site/style.zig joins it with the legacy file and the components
//! into one stylesheet, versioned by its hash. Scoping and the lint are checks, not rewriting: the
//! server, ui.wasm and tests all write the same class names
const std = @import("std");
const tokens = @import("tokens.zig");

/// Unlayered rules would beat every layer, so legacy CSS goes in its own, below the
/// components and pages that replace it
pub const layers = "@layer tokens, base, legacy, components, pages;\n";

pub const base = @embedFile("base.css");

pub const head = layers ++ tokens.css ++ base;

/// Each listed component's rules, in order. A component no page lists ships no CSS
pub fn join(comptime components: anytype) []const u8 {
    return comptime blk: {
        var s: []const u8 = "";
        for (components) |C| s = s ++ C.css;
        break :blk s;
    };
}

/// 8 hex digits of a file's FNV-1a hash, at compile time: its hashed name (site/assets.zig)
pub fn version(comptime bytes: []const u8) []const u8 {
    return comptime blk: {
        @setEvalBranchQuota(bytes.len * 4 + 1000);
        var h: u32 = 0x811c9dc5;
        for (bytes) |c| h = (h ^ c) *% 0x01000193;
        break :blk std.fmt.comptimePrint("{x:0>8}", .{h});
    };
}

/// Selectors of rules that start with none of `scopes` (`.c-table`)
pub fn unscoped(a: std.mem.Allocator, css: []const u8, scopes: []const []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it: Rules = .{ .css = css };
    while (it.next()) |r| {
        var parts: SelectorList = .{ .s = r.selector };
        while (parts.next()) |p| {
            const s = std.mem.trim(u8, p, " \n");
            if (s.len == 0 or s[0] == '@' or std.mem.eql(u8, s, "from") or std.mem.eql(u8, s, "to") or std.ascii.isDigit(s[0])) continue;
            for (scopes) |scope| {
                if (std.mem.startsWith(u8, s, scope) and (s.len == scope.len or !isNameChar(s[scope.len]))) break;
            } else try out.append(a, s);
        }
    }
    return out.items;
}

/// A selector list's selectors: commas inside :is(), :not() and :has() don't split
const SelectorList = struct {
    s: []const u8,
    i: usize = 0,

    fn next(l: *SelectorList) ?[]const u8 {
        if (l.i >= l.s.len) return null;
        const start = l.i;
        var depth: usize = 0;
        while (l.i < l.s.len) : (l.i += 1) switch (l.s[l.i]) {
            '(' => depth += 1,
            ')' => depth -|= 1,
            ',' => if (depth == 0) {
                l.i += 1;
                return l.s[start .. l.i - 1];
            },
            else => {},
        };
        return l.s[start..];
    }
};

fn isNameChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == '_';
}

/// Class names a stylesheet's selectors mention, once each
pub fn classes(a: std.mem.Allocator, css: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it: Rules = .{ .css = css };
    while (it.next()) |r| {
        const sel = r.selector;
        var i: usize = 0;
        while (i < sel.len) : (i += 1) {
            if (sel[i] != '.' or i + 1 >= sel.len or !std.ascii.isAlphabetic(sel[i + 1])) continue;
            var j = i + 1;
            while (j < sel.len and (std.ascii.isAlphanumeric(sel[j]) or sel[j] == '-' or sel[j] == '_')) j += 1;
            const name = sel[i + 1 .. j];
            for (out.items) |o| {
                if (std.mem.eql(u8, o, name)) break;
            } else try out.append(a, name);
            i = j - 1;
        }
    }
    return out.items;
}

/// A style rule: its selector and declarations, with the @media around it if any
pub const Rule = struct { selector: []const u8, body: []const u8, media: []const u8 = "" };

/// Style rules in order, through @layer and @media blocks; comments skipped
pub const Rules = struct {
    css: []const u8,
    i: usize = 0,
    media: []const u8 = "",
    media_depth: usize = 0,
    depth: usize = 0,

    pub fn next(r: *Rules) ?Rule {
        while (r.i < r.css.len) {
            r.skipSpace();
            if (r.i >= r.css.len) return null;
            if (r.css[r.i] == '}') {
                if (r.depth == r.media_depth and r.depth > 0) r.media = "";
                r.depth -|= 1;
                r.i += 1;
                continue;
            }
            const open = std.mem.findScalarPos(u8, r.css, r.i, '{') orelse return null;
            const semi = std.mem.findScalarPos(u8, r.css, r.i, ';');
            // `@layer a, b;` and other statement at-rules
            if (semi != null and semi.? < open) {
                r.i = semi.? + 1;
                continue;
            }
            const prelude = std.mem.trim(u8, r.css[r.i..open], " \n\t");
            r.i = open + 1;
            if (std.mem.startsWith(u8, prelude, "@media")) {
                r.depth += 1;
                r.media = prelude;
                r.media_depth = r.depth;
                continue;
            }
            if (std.mem.startsWith(u8, prelude, "@layer") or std.mem.startsWith(u8, prelude, "@supports") or std.mem.startsWith(u8, prelude, "@container")) {
                r.depth += 1;
                continue;
            }
            const close = std.mem.findScalarPos(u8, r.css, r.i, '}') orelse r.css.len;
            const body = r.css[r.i..close];
            r.i = @min(close + 1, r.css.len);
            // @font-face, @keyframes steps: not style rules a component scopes
            if (prelude.len > 0 and prelude[0] == '@') {
                if (std.mem.startsWith(u8, prelude, "@keyframes")) r.skipBlockRest();
                continue;
            }
            return .{ .selector = prelude, .body = body, .media = r.media };
        }
        return null;
    }

    fn skipSpace(r: *Rules) void {
        while (r.i < r.css.len) {
            if (std.ascii.isWhitespace(r.css[r.i])) {
                r.i += 1;
            } else if (std.mem.startsWith(u8, r.css[r.i..], "/*")) {
                r.i = if (std.mem.find(u8, r.css[r.i + 2 ..], "*/")) |e| r.i + 2 + e + 2 else r.css.len;
            } else return;
        }
    }

    /// The rest of a @keyframes block after its first step was read
    fn skipBlockRest(r: *Rules) void {
        var d: usize = 1;
        while (r.i < r.css.len and d > 0) : (r.i += 1) switch (r.css[r.i]) {
            '{' => d += 1,
            '}' => d -= 1,
            else => {},
        };
    }
};

pub const Level = enum { off, warn, err };

/// README's CSS guardrails, run on our CSS (not legacy): warnings by default
pub const Lint = struct {
    /// Colours come from tokens: no #hex, rgb() or hsl() outside them
    colour: Level = .warn,
    /// font-size only var(--fs-*) or inherit
    font_size: Level = .warn,
    /// @media widths only at the three page breakpoints
    breakpoint: Level = .warn,
    /// No !important, except base's [hidden]
    important: Level = .warn,
    /// A display rule on [popover] keeps it open: display only under :popover-open
    popover: Level = .warn,
    /// Dashed names a rule reads (`var(--fs-q)`) that are no token
    token: Level = .warn,
};

pub const Finding = struct { level: Level, msg: []const u8 };

pub const breakpoints = [_][]const u8{ "480px", "760px", "1000px" };

pub fn lint(a: std.mem.Allocator, css: []const u8, rules: Lint) ![]const Finding {
    var out: std.ArrayList(Finding) = .empty;
    var it: Rules = .{ .css = css };
    var seen_media: []const u8 = "";
    while (it.next()) |r| {
        const add = struct {
            fn f(al: std.mem.Allocator, o: *std.ArrayList(Finding), level: Level, comptime fm: []const u8, args: anytype) !void {
                if (level == .off) return;
                try o.append(al, .{ .level = level, .msg = try al.print(fm, args) });
            }
        }.f;
        if (r.media.len > 0 and r.media.ptr != seen_media.ptr) {
            seen_media = r.media;
            var words = std.mem.tokenizeAny(u8, r.media, " ():");
            while (words.next()) |w| if (std.mem.endsWith(u8, w, "px")) {
                for (breakpoints) |b| {
                    if (std.mem.eql(u8, b, w)) break;
                } else try add(a, &out, rules.breakpoint, "{s}: {s} is not a breakpoint (480, 760, 1000)", .{ r.media, w });
            };
        }
        var decls = std.mem.tokenizeScalar(u8, r.body, ';');
        while (decls.next()) |d| {
            const colon = std.mem.findScalar(u8, d, ':') orelse continue;
            const prop = std.mem.trim(u8, d[0..colon], " \n\t");
            const val = std.mem.trim(u8, d[colon + 1 ..], " \n\t");
            if (std.mem.startsWith(u8, prop, "--")) continue;
            if (hasColour(val)) try add(a, &out, rules.colour, "{s} {{ {s}: {s} }}: a colour outside the tokens", .{ r.selector, prop, val });
            if (std.mem.eql(u8, prop, "font-size") and !std.mem.startsWith(u8, val, "var(--fs-") and !std.mem.eql(u8, val, "inherit")) {
                try add(a, &out, rules.font_size, "{s} {{ font-size: {s} }}: not one of the five sizes", .{ r.selector, val });
            }
            if (std.mem.find(u8, val, "!important") != null and !std.mem.eql(u8, r.selector, "[hidden]")) {
                try add(a, &out, rules.important, "{s} {{ {s} }}: !important", .{ r.selector, prop });
            }
            if (std.mem.eql(u8, prop, "display") and std.mem.find(u8, r.selector, "[popover]") != null and std.mem.find(u8, r.selector, ":popover-open") == null) {
                try add(a, &out, rules.popover, "{s}: display on [popover] keeps it open; set it under :popover-open", .{r.selector});
            }
            var rest = val;
            while (std.mem.find(u8, rest, "var(--")) |at| {
                const name_start = at + "var(--".len;
                var e = name_start;
                while (e < rest.len and (std.ascii.isAlphanumeric(rest[e]) or rest[e] == '-' or rest[e] == '_')) e += 1;
                const name = rest[name_start..e];
                // Undashed names (--c, --w) are a component's own, set by h.vars
                if (std.mem.findScalar(u8, name, '-') != null and !tokens.has(name)) {
                    try add(a, &out, rules.token, "{s}: no token --{s}", .{ r.selector, name });
                }
                rest = rest[e..];
            }
        }
    }
    return out.items;
}

fn hasColour(v: []const u8) bool {
    var i: usize = 0;
    while (std.mem.findScalarPos(u8, v, i, '#')) |at| : (i = at + 1) {
        if (at + 4 <= v.len and std.ascii.isHex(v[at + 1]) and std.ascii.isHex(v[at + 2]) and std.ascii.isHex(v[at + 3])) return true;
    }
    for ([_][]const u8{ "rgb(", "rgba(", "hsl(", "hsla(" }) |f| if (std.mem.find(u8, v, f) != null) return true;
    return false;
}

const testing = std.testing;

test "our CSS passes its own lint" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const found = try lint(arena.allocator(), base, .{});
    for (found) |f| std.debug.print("base.css {s}: {s}\n", .{ @tagName(f.level), f.msg });
    try testing.expectEqual(@as(usize, 0), found.len);
}

test "the lint finds what README rules out" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const css =
        \\@layer components {
        \\/* a comment { with braces } */
        \\.c-x .a { color: #fff; font-size: 14px; margin: 0 !important; background: var(--no-such); }
        \\.c-x .b { color: var(--text); font-size: var(--fs-s); width: calc(var(--w) * 1%); }
        \\.c-x [popover] { display: grid; }
        \\.c-x [popover]:popover-open { display: grid; }
        \\@media (max-width: 700px) { .c-x .c { border: 1px solid rgb(0 0 0); } }
        \\@media (max-width: 760px) { .c-x .d { gap: 2px; } }
        \\}
    ;
    const found = try lint(arena.allocator(), css, .{});
    var msgs: std.ArrayList(u8) = .empty;
    for (found) |f| try msgs.print(arena.allocator(), "{s}\n", .{f.msg});
    try testing.expectEqualStrings(
        \\.c-x .a { color: #fff }: a colour outside the tokens
        \\.c-x .a { font-size: 14px }: not one of the five sizes
        \\.c-x .a { margin }: !important
        \\.c-x .a: no token --no-such
        \\.c-x [popover]: display on [popover] keeps it open; set it under :popover-open
        \\@media (max-width: 700px): 700px is not a breakpoint (480, 760, 1000)
        \\.c-x .c { border: 1px solid rgb(0 0 0) }: a colour outside the tokens
        \\
    , msgs.items);
    try testing.expectEqual(@as(usize, 0), (try unscoped(arena.allocator(), css, &.{".c-x"})).len);
    const cls = try classes(arena.allocator(), css);
    try testing.expectEqual(@as(usize, 5), cls.len);
    try testing.expectEqualStrings("c-x", cls[0]);
}

test "a stylesheet's version changes with its bytes" {
    try testing.expect(!std.mem.eql(u8, version("a{}"), version("b{}")));
    try testing.expectEqual(@as(usize, 8), version("a{}").len);
}
