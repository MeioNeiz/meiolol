//! Notes on the live site (the notes island, /api/notes, src/api/notes.zig): what a note
//! holds, as ui.data binary both ways, and the bounds the API holds every field to
const std = @import("std");

pub const Scope = enum(u8) { page, everywhere };
pub const Status = enum(u8) { open, done };
pub const Theme = enum(u8) { light, dark };

/// How the noted element is found again after a rebuild: its anchor (the nearest
/// ancestor-or-self with a c-* class, else with data-island, else <body>: kind page),
/// the anchor's index among the page's matches, the child path from it, and the start of
/// the element's text, which breaks ties when data changed the page
pub const Target = struct {
    kind: Kind,
    /// The c-* class or data-island value; "" for the whole page
    name: []const u8 = "",
    nth: u16 = 0,
    /// Child steps from the anchor, "tag:i" (the i-th element child with that tag, lower
    /// case) joined by '>'; "" for the anchor itself (kind page: the whole page)
    steps: []const u8 = "",
    /// Trimmed, whitespace-collapsed text, at most max_snippet bytes
    snippet: []const u8 = "",

    pub const Kind = enum(u8) { page, component, island };

    /// The component's class, for "everywhere" and grouping; "" when none
    pub fn component(t: Target) []const u8 {
        return if (t.kind == .component) t.name else "";
    }
};

/// What the island sends to add a note
pub const New = struct {
    /// location.pathname
    path: []const u8,
    /// location.search and location.hash: the page's state (filters, tab, #id=)
    hash: []const u8 = "",
    scope: Scope = .page,
    target: Target = .{ .kind = .page },
    /// Viewport, CSS px
    vw: u16 = 0,
    vh: u16 = 0,
    theme: Theme = .light,
    text: []const u8,
};

pub const Note = struct {
    id: u32,
    /// Unix seconds
    created: i64,
    updated: i64,
    author: []const u8,
    path: []const u8,
    hash: []const u8,
    scope: Scope,
    target: Target,
    vw: u16,
    vh: u16,
    theme: Theme,
    text: []const u8,
    status: Status,
    /// e.g. the fixing commit
    reply: []const u8,
};

pub const List = struct {
    /// Newest first
    notes: []const Note,
    /// More matched than the cap returned
    more: bool = false,
};

/// PATCH: the fields given change
pub const Change = struct {
    status: ?Status = null,
    reply: ?[]const u8 = null,
};

/// The textarea's maxlength, in UTF-16 units
pub const max_chars = 2000;
/// Bytes: a UTF-16 unit is at most 3 bytes of UTF-8 (a pair, 4), so whatever maxlength
/// lets through fits
pub const max_text = 3 * max_chars;
pub const max_reply = 500;
pub const max_path = 256;
pub const max_hash = 512;
pub const max_name = 40;
pub const max_snippet = 60;
pub const max_steps = 16;
/// A tag in a step ("svg", "foreignobject"), and a child index
const max_tag = 16;
const max_index = 999;

/// The marker cookie: set at an admin's login (or the /admin/notes toggle), it has
/// nginx add the tool's tag to pages (site/notes.zig)
pub const marker = "__Host-meiolol_notes";

/// Why `n` is refused; null when every field is in bounds
pub fn check(n: New) ?[]const u8 {
    // The list links path ++ hash: "//host" or "/\\host" would be another site
    if (n.path.len == 0 or n.path.len > max_path or n.path[0] != '/' or !urlish(n.path) or
        std.mem.startsWith(u8, n.path, "//") or std.mem.findAny(u8, n.path, "?#\\") != null) return "bad path";
    if (n.hash.len > max_hash or !urlish(n.hash) or (n.hash.len > 0 and n.hash[0] != '?' and n.hash[0] != '#')) return "bad hash";
    if (checkTarget(n.target)) |why| return why;
    if (n.scope == .everywhere and n.target.kind != .component) return "everywhere needs a component";
    const text = std.mem.trim(u8, n.text, " \t\r\n");
    if (text.len == 0) return "empty text";
    if (n.text.len > max_text or !std.unicode.utf8ValidateSlice(n.text)) return "bad text";
    return null;
}

/// Why `c` is refused; null when in bounds
pub fn checkChange(c: Change) ?[]const u8 {
    if (c.status == null and c.reply == null) return "nothing to change";
    if (c.reply) |r| if (r.len > max_reply or !std.unicode.utf8ValidateSlice(r)) return "bad reply";
    return null;
}

fn checkTarget(t: Target) ?[]const u8 {
    if (t.kind == .page) {
        if (t.name.len != 0 or t.nth != 0) return "bad target";
    } else {
        if (t.name.len == 0 or t.name.len > max_name) return "bad target name";
        for (t.name) |ch| if (!std.ascii.isAlphanumeric(ch) and ch != '-' and ch != '_') return "bad target name";
        if (t.kind == .component and !std.mem.startsWith(u8, t.name, "c-")) return "bad target name";
    }
    if (!stepsOk(t.steps)) return "bad steps";
    if (t.snippet.len > max_snippet or !std.unicode.utf8ValidateSlice(t.snippet)) return "bad snippet";
    return null;
}

/// `raw` (an element's text) as a snippet in `out`: whitespace runs as one space, none
/// at either end, cut on a whole character at out.len
pub fn snippet(out: []u8, raw: []const u8) []const u8 {
    var n: usize = 0;
    var space = false;
    for (raw) |ch| {
        if (std.ascii.isWhitespace(ch)) {
            space = n > 0;
            continue;
        }
        if (n + @intFromBool(space) >= out.len) break;
        if (space) {
            out[n] = ' ';
            n += 1;
            space = false;
        }
        out[n] = ch;
        n += 1;
    }
    // A character cut short goes whole
    var lead = n;
    while (lead > 0 and out[lead - 1] & 0xC0 == 0x80) lead -= 1;
    if (lead > 0) {
        const len = std.unicode.utf8ByteSequenceLength(out[lead - 1]) catch 1;
        if (lead - 1 + len > n) n = lead - 1;
    }
    while (n > 0 and out[n - 1] == ' ') n -= 1;
    return out[0..n];
}

/// `s` cut to at most `max` bytes on a whole character
pub fn cut(s: []const u8, max: usize) []const u8 {
    if (s.len <= max) return s;
    var n = max;
    // Back over the cut character's continuation bytes, then its lead
    while (n > 0 and s[n] & 0xC0 == 0x80) n -= 1;
    return s[0..n];
}

test cut {
    try std.testing.expectEqualStrings("abc", cut("abc", 5));
    try std.testing.expectEqualStrings("ab", cut("abé", 3));
    try std.testing.expectEqualStrings("abé", cut("abéx", 4));
    try std.testing.expectEqualStrings("", cut("€", 2));
}

test snippet {
    var buf: [max_snippet]u8 = undefined;
    try std.testing.expectEqualStrings("Ahri 52.3%", snippet(&buf, "  Ahri\n\t 52.3%  "));
    var small: [6]u8 = undefined;
    try std.testing.expectEqualStrings("abcd", snippet(&small, "abcd é"));
    try std.testing.expectEqualStrings("abc é", snippet(&small, "abc é"));
    try std.testing.expectEqualStrings("ab €", snippet(&small, "ab €x"));
    try std.testing.expectEqualStrings("", snippet(&small, " \n "));
}

/// Printable ASCII without spaces: what location gives, percent-encoded
fn urlish(s: []const u8) bool {
    for (s) |ch| if (ch <= ' ' or ch > '~') return false;
    return true;
}

fn stepsOk(steps: []const u8) bool {
    if (steps.len == 0) return true;
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, steps, '>');
    while (it.next()) |step| {
        n += 1;
        if (n > max_steps) return false;
        const colon = std.mem.findScalar(u8, step, ':') orelse return false;
        const tag = step[0..colon];
        if (tag.len == 0 or tag.len > max_tag or !std.ascii.isLower(tag[0])) return false;
        for (tag) |ch| if (!std.ascii.isLower(ch) and !std.ascii.isDigit(ch) and ch != '-') return false;
        const i = std.fmt.parseInt(u16, step[colon + 1 ..], 10) catch return false;
        if (i > max_index or step.len - colon - 1 > 3) return false;
    }
    return true;
}

const ok: New = .{ .path = "/champion/ahri", .hash = "?role=mid#id=3", .text = "Too wide" };

test check {
    try std.testing.expectEqual(null, check(ok));
    var n = ok;
    n.target = .{ .kind = .component, .name = "c-tierrow", .nth = 2, .steps = "div:0>span:1", .snippet = "Ahri 52.3%" };
    n.scope = .everywhere;
    try std.testing.expectEqual(null, check(n));
    n.target = .{ .kind = .island, .name = "top", .steps = "svg:0>g:12" };
    n.scope = .page;
    try std.testing.expectEqual(null, check(n));
    n.target = .{ .kind = .page, .steps = "main:0>table:1", .snippet = "Old table" };
    try std.testing.expectEqual(null, check(n));
}

test "check: refuses fields out of bounds" {
    const long: [max_text + 1]u8 = @splat('a');
    const long_snippet: [max_snippet + 1]u8 = @splat('a');
    const long_reply: [max_reply + 1]u8 = @splat('a');
    const many_steps = comptime blk: {
        var s: []const u8 = "a:0";
        for (0..max_steps) |_| s = s ++ ">a:0";
        break :blk s;
    };
    const bad = [_]New{
        .{ .path = "", .text = "x" },
        .{ .path = "champion", .text = "x" },
        .{ .path = "/a?b", .text = "x" },
        .{ .path = "/a b", .text = "x" },
        .{ .path = "//evil.example/x", .text = "x" },
        .{ .path = "/\\evil.example/x", .text = "x" },
        .{ .path = "/a", .hash = "#\x00", .text = "x" },
        .{ .path = "/a", .hash = "/x", .text = "x" },
        .{ .path = "/a", .text = " \n" },
        .{ .path = "/a", .text = &long },
        .{ .path = "/a", .text = "\xff" },
        .{ .path = "/a", .scope = .everywhere, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .page, .name = "c-x" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .component, .name = "tierrow" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "a\"b" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "a", .steps = "div" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "a", .steps = "div:1000" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "a", .steps = "div:0001" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "a", .steps = "Div:0" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "a", .steps = "div:0>" }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "a", .steps = many_steps }, .text = "x" },
        .{ .path = "/a", .target = .{ .kind = .island, .name = "a", .snippet = &long_snippet }, .text = "x" },
    };
    for (bad) |n| try std.testing.expect(check(n) != null);
    try std.testing.expect(checkChange(.{}) != null);
    try std.testing.expect(checkChange(.{ .reply = &long_reply }) != null);
    try std.testing.expectEqual(null, checkChange(.{ .status = .done, .reply = "fixed in 1a2b3c4d" }));
}
