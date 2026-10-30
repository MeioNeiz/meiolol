//! Every page's URL (docs/plan/urls.md): root-relative, lowercase, no .html, no trailing
//! slash; which data (region, period) as a query, in-page state in the fragment. Page is
//! both what `{f}` spells and what `parse` reads back, so the generator, the server and
//! the wasm agree. Old URLs get no redirects (Jacob, 29 Oct)

const std = @import("std");
const Writer = std.Io.Writer;
const Role = @import("role.zig").Role;

pub const Champ = struct { slug: []const u8, role: ?Role = null };
pub const Matchup = struct { role: Role, a: []const u8, b: []const u8 };

pub const Page = union(enum) {
    home,
    /// All, or one role's list
    champions: ?Role,
    /// No role: its main role's page
    champion: Champ,
    matchups,
    matchup: Matchup,
    daily: ?u32,
    /// The current diff, or an older one by its patch with hyphens ("26-21")
    patch: ?[]const u8,
    pickup: ?Role,
    learn,
    pool,
    your,
    game,
    method,
    download,
    privacy,
    terms,
    login,
    signup,
    join,
    account,

    pub fn format(p: Page, w: *Writer) Writer.Error!void {
        switch (p) {
            .home => try w.writeByte('/'),
            .champions => |r| try opt(w, "/champions", r),
            .champion => |c| {
                try w.print("/champions/{s}", .{c.slug});
                if (c.role) |r| try w.print("/{t}", .{r});
            },
            .matchups => try w.writeAll("/matchups"),
            .matchup => |m| try w.print("/matchups/{t}/{s}-vs-{s}", .{ m.role, m.a, m.b }),
            .daily => |n| {
                try w.writeAll("/daily");
                if (n) |x| try w.print("/{d}", .{x});
            },
            .patch => |s| {
                try w.writeAll("/patch");
                if (s) |x| try w.print("/{s}", .{x});
            },
            .pickup => |r| try opt(w, "/pickup", r),
            else => try w.print("/{t}", .{p}),
        }
    }

    fn opt(w: *Writer, base: []const u8, r: ?Role) Writer.Error!void {
        try w.writeAll(base);
        if (r) |x| try w.print("/{t}", .{x});
    }
};

/// Which data a page shows: "?region=all&period=patch", "" for the default
pub const Data = struct {
    all: bool = false,
    patch: bool = false,

    pub fn format(d: Data, w: *Writer) Writer.Error!void {
        if (d.all) try w.writeAll("?region=all");
        if (d.patch) try w.writeAll(if (d.all) "&period=patch" else "?period=patch");
    }
};

/// Data spelt for each html.View, by its index (View.query reads it here); for wasm,
/// which spells by concat
pub const view_queries = [_][]const u8{ "", "?period=patch", "?region=all", "?region=all&period=patch" };

/// Each view's tree of pages and data under the site root, by View index (View.dir), never
/// in a page's URL: nginx maps the query to it
pub const view_dirs = [_][]const u8{ "", "_v/patch/", "_v/all/", "_v/all-patch/" };

/// A data file's URL with its page's stamp, ?v= (or &v=): the file keeps its path from one
/// site round to the next and browsers keep a copy 4 h (Cloudflare's browser cache TTL),
/// so a newer page would get an older file. The server ignores the query. Null when `buf`
/// is too short
pub fn stamped(buf: []u8, path: []const u8, stamp: []const u8) ?[]const u8 {
    const sep = if (std.mem.findScalar(u8, path, '?') == null) "?v=" else "&v=";
    const n = path.len + sep.len + stamp.len;
    if (n > buf.len) return null;
    @memcpy(buf[0..path.len], path);
    @memcpy(buf[path.len..][0..sep.len], sep);
    @memcpy(buf[path.len + sep.len ..][0..stamp.len], stamp);
    return buf[0..n];
}

/// `path`'s page (no query or fragment); null: not a page
pub fn parse(path: []const u8) ?Page {
    if (std.mem.eql(u8, path, "/")) return .home;
    if (path.len < 2 or path[0] != '/' or path[path.len - 1] == '/') return null;
    var it = std.mem.splitScalar(u8, path[1..], '/');
    const head = it.first();
    const a = it.next();
    const b = it.next();
    if (it.next() != null) return null;
    if (std.mem.eql(u8, head, "champions")) {
        const x = a orelse return if (b == null) .{ .champions = null } else null;
        if (std.meta.stringToEnum(Role, x)) |r| return if (b == null) .{ .champions = r } else null;
        if (!isSlug(x)) return null;
        const r = if (b) |y| std.meta.stringToEnum(Role, y) orelse return null else null;
        return .{ .champion = .{ .slug = x, .role = r } };
    }
    if (std.mem.eql(u8, head, "matchups")) {
        const x = a orelse return .matchups;
        return .{ .matchup = matchupOf(x, b orelse return null) orelse return null };
    }
    if (std.mem.eql(u8, head, "daily")) {
        if (b != null) return null;
        return .{ .daily = if (a) |x| dayOf(x) orelse return null else null };
    }
    if (std.mem.eql(u8, head, "patch")) {
        if (b != null) return null;
        const x = a orelse return .{ .patch = null };
        return if (isPatch(x)) .{ .patch = x } else null;
    }
    if (std.mem.eql(u8, head, "pickup")) {
        if (b != null) return null;
        return .{ .pickup = if (a) |x| std.meta.stringToEnum(Role, x) orelse return null else null };
    }
    if (a != null) return null;
    const p = std.meta.stringToEnum(std.meta.Tag(Page), head) orelse return null;
    return switch (p) {
        inline .learn, .pool, .your, .game, .method, .download, .privacy, .terms, .login, .signup, .join, .account => |t| t,
        else => null,
    };
}

/// A page's path and its state: location.search ++ location.hash
pub const Located = struct { path: []const u8, state: []const u8 };

fn matchupOf(r: []const u8, pair: []const u8) ?Matchup {
    const role = std.meta.stringToEnum(Role, r) orelse return null;
    const i = std.mem.find(u8, pair, "-vs-") orelse return null;
    const m: Matchup = .{ .role = role, .a = pair[0..i], .b = pair[i + 4 ..] };
    return if (isSlug(m.a) and isSlug(m.b)) m else null;
}

/// Daily's n as written only: "07" and "+7" would each be a copy of a page
fn dayOf(s: []const u8) ?u32 {
    if (s.len == 0 or s.len > 9 or s[0] == '0') return null;
    for (s) |c| if (!std.ascii.isDigit(c)) return null;
    return std.fmt.parseInt(u32, s, 10) catch null;
}

/// Champion slugs (champs.zig): lowercase letters and digits, single hyphens inside
fn isSlug(s: []const u8) bool {
    if (s.len == 0 or s[0] == '-' or s[s.len - 1] == '-') return false;
    for (s, 0..) |c, i| {
        if (c == '-') {
            if (s[i - 1] == '-') return false;
        } else if (!std.ascii.isLower(c) and !std.ascii.isDigit(c)) return false;
    }
    return true;
}

/// "26-21"
fn isPatch(s: []const u8) bool {
    const i = std.mem.findScalar(u8, s, '-') orelse return false;
    if (i == 0 or i == s.len - 1) return false;
    for (s[0..i]) |c| if (!std.ascii.isDigit(c)) return false;
    for (s[i + 1 ..]) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

const testing = std.testing;

test "urls: each page spelt and parsed back" {
    const cases = [_]struct { Page, []const u8 }{
        .{ .home, "/" },
        .{ .{ .champions = null }, "/champions" },
        .{ .{ .champions = .support }, "/champions/support" },
        .{ .{ .champion = .{ .slug = "lee-sin" } }, "/champions/lee-sin" },
        .{ .{ .champion = .{ .slug = "kaisa", .role = .bot } }, "/champions/kaisa/bot" },
        .{ .matchups, "/matchups" },
        .{ .{ .matchup = .{ .role = .top, .a = "darius", .b = "garen" } }, "/matchups/top/darius-vs-garen" },
        .{ .{ .daily = null }, "/daily" },
        .{ .{ .daily = 41 }, "/daily/41" },
        .{ .{ .patch = null }, "/patch" },
        .{ .{ .patch = "26-21" }, "/patch/26-21" },
        .{ .{ .pickup = null }, "/pickup" },
        .{ .{ .pickup = .mid }, "/pickup/mid" },
        .{ .learn, "/learn" },
        .{ .pool, "/pool" },
        .{ .account, "/account" },
    };
    var buf: [64]u8 = undefined;
    var again: [64]u8 = undefined;
    for (cases) |c| {
        const s = try std.fmt.bufPrint(&buf, "{f}", .{c[0]});
        try testing.expectEqualStrings(c[1], s);
        const back = parse(s) orelse return error.NoParse;
        try testing.expectEqualStrings(c[1], try std.fmt.bufPrint(&again, "{f}", .{back}));
    }
}

test "urls: a data file stamped" {
    var buf: [32]u8 = undefined;
    try testing.expectEqualStrings("data/tiers.bin?v=123", stamped(&buf, "data/tiers.bin", "123").?);
    try testing.expectEqualStrings("practice.bin?7&v=123", stamped(&buf, "practice.bin?7", "123").?);
    try testing.expectEqual(null, stamped(buf[0..19], "data/tiers.bin", "123"));
}

test "urls: not pages" {
    const bad = [_][]const u8{
        "",
        "champions",
        "/champions/",
        "/Champions",
        "/champions.html",
        "/champions/kaisa/adc",
        "/champions/a/b/c",
        "/champions/-x",
        "/matchups/top",
        "/matchups/top/darius",
        "/matchups/adc/a-vs-b",
        "/daily/07",
        "/daily/x",
        "/patch/26.21",
        "/patch/26",
        "/pickup/adc",
        "/learn/x",
        "/admin",
        "/index",
        "/sitemap.xml",
    };
    for (bad) |s| try testing.expectEqual(null, parse(s));
}
