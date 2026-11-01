//! Testers' applications for the desktop app (the form ui.apply on /download, the
//! admin's Applications tab, src/api/applications.zig): what an application holds, as
//! ui.data binary both ways, and the bounds the form and the API both check
const std = @import("std");

pub const Role = enum(u8) { none, top, jungle, mid, bot, support };
pub const Rank = enum(u8) { none, iron, bronze, silver, gold, platinum, emerald, diamond, master, grandmaster, challenger };
/// approved: Jacob hands out a private login himself; nothing is sent from here
pub const Status = enum(u8) { open, approved, declined };

/// What the form sends to POST /api/apply
pub const New = struct {
    /// Name#TAG as typed
    riot_id: []const u8,
    /// An email address or a Discord username
    contact: []const u8,
    role: Role = .none,
    rank: Rank = .none,
    /// One line
    why: []const u8,
};

pub const Application = struct {
    id: u32,
    /// Unix seconds; `decided` 0 while open
    created: i64,
    decided: i64,
    riot_id: []const u8,
    contact: []const u8,
    role: Role,
    rank: Rank,
    why: []const u8,
    status: Status,
};

/// GET /api/applications.bin: newest first
pub const List = struct { applications: []const Application, more: bool };

/// POST /api/applications.bin?id=N&set=S
pub const Set = enum { open, approved, declined, delete };

/// Bytes: Riot IDs are at most 16 + 1 + 5 characters, emails 254; `why` is the form's
/// maxlength in UTF-16 units, each at most 3 bytes of UTF-8 (a 4-byte one takes two)
pub const max_riot_id = 64;
pub const max_contact = 254;
pub const max_why_chars = 200;
pub const max_why = 3 * max_why_chars;

/// Why `n` is refused; null when it can be stored
pub fn check(n: New) ?[]const u8 {
    if (!riotId(n.riot_id)) return "Riot ID: Name#TAG, as the League client shows it.";
    if (contactKind(n.contact) == null) return "Contact: an email address or a Discord username.";
    const why = std.mem.trim(u8, n.why, " \t");
    if (why.len == 0) return "Why: one line, please.";
    if (n.why.len > max_why or !std.unicode.utf8ValidateSlice(n.why) or std.mem.findAny(u8, n.why, "\r\n") != null) return "Why: one line, up to 200 characters.";
    return null;
}

/// Name#TAG: name 1-32 bytes, tag 1-8, one '#', no '/', '?' or '\\' (as api.cache.riotIdKey)
pub fn riotId(s: []const u8) bool {
    if (s.len > max_riot_id or !std.unicode.utf8ValidateSlice(s)) return false;
    const at = std.mem.findScalar(u8, s, '#') orelse return false;
    const name = std.mem.trim(u8, s[0..at], " ");
    const tag = std.mem.trim(u8, s[at + 1 ..], " ");
    if (name.len == 0 or name.len > 32 or tag.len == 0 or tag.len > 8) return false;
    return std.mem.findAny(u8, s, "/?\\\r\n") == null and std.mem.findScalar(u8, s[at + 1 ..], '#') == null and
        std.mem.findScalar(u8, tag, ' ') == null;
}

pub const Contact = enum { email, discord };

/// An email (one '@', a dot in the domain) or a Discord username (2-32 of a-z, 0-9, '_',
/// '.', an '@' before it allowed); null for neither
pub fn contactKind(s: []const u8) ?Contact {
    if (s.len == 0 or s.len > max_contact) return null;
    for (s) |c| if (c <= ' ' or c == 0x7f) return null;
    if (std.mem.findScalar(u8, s, '@')) |at| if (at > 0) {
        const domain = s[at + 1 ..];
        const dot = std.mem.findScalarLast(u8, domain, '.') orelse return null;
        if (std.mem.findScalar(u8, domain, '@') != null or dot == 0 or dot + 1 == domain.len) return null;
        return .email;
    };
    const name = if (s[0] == '@') s[1..] else s;
    if (name.len < 2 or name.len > 32) return null;
    for (name) |c| if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '.') return null;
    return .discord;
}

const testing = std.testing;

test check {
    const ok: New = .{ .riot_id = "Meio Neiz#EUW", .contact = "a@b.co", .why = "I main mid" };
    try testing.expectEqual(null, check(ok));
    var n = ok;
    n.why = "  ";
    try testing.expect(check(n) != null);
    n.why = "two\nlines";
    try testing.expect(check(n) != null);
    n = ok;
    n.riot_id = "nohash";
    try testing.expect(check(n) != null);
    n = ok;
    n.contact = "not an email";
    try testing.expect(check(n) != null);
}

test riotId {
    try testing.expect(riotId("Faker#KR1"));
    try testing.expect(riotId("Hide on bush#KR1"));
    try testing.expect(!riotId("#KR1"));
    try testing.expect(!riotId("A#"));
    try testing.expect(!riotId("A#1#2"));
    try testing.expect(!riotId("A/B#EUW"));
    try testing.expect(!riotId("A#toolongtag"));
}

test contactKind {
    try testing.expectEqual(.email, contactKind("jo@example.com").?);
    try testing.expectEqual(.discord, contactKind("meio_neiz").?);
    try testing.expectEqual(.discord, contactKind("@meio.neiz").?);
    try testing.expectEqual(null, contactKind("jo@example"));
    try testing.expectEqual(null, contactKind("jo@example."));
    try testing.expectEqual(null, contactKind("a b@c.d"));
    try testing.expectEqual(null, contactKind("x"));
    try testing.expectEqual(null, contactKind(""));
}
