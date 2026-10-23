//! Riot rate limits: one net.ratelimit.Limiter per routing value (Riot counts per key
//! and route), shared by everything calling that route in a process (the crawl thread
//! and proxied Your games requests), so they queue for one budget and priority callers
//! go first. App limits are the Limiter's global windows, method limits its keys'.

const std = @import("std");
const Allocator = std.mem.Allocator;
pub const Limiter = @import("net").ratelimit.Limiter;

/// The personal key's app limits, until Riot's X-App-Rate-Limit says otherwise
pub const personal_key = "20:1,100:120";

/// Regions, then platforms
pub const Limiters = struct {
    all: [regions.len + ep.platforms.len]Limiter,

    const ep = @import("endpoints.zig");
    const regions = std.enums.values(ep.Region);

    pub fn init(gpa: Allocator, io: std.Io) !Limiters {
        var l: Limiters = undefined;
        for (&l.all, 0..) |*limiter, i| {
            limiter.* = Limiter.init(gpa, io, personal_key) catch |err| {
                for (l.all[0..i]) |*done| done.deinit();
                return err;
            };
        }
        return l;
    }

    pub fn deinit(l: *Limiters) void {
        for (&l.all) |*limiter| limiter.deinit();
    }

    /// "europe", "euw1": index into `all`
    pub fn index(route: []const u8) ?usize {
        for (regions, 0..) |r, i| if (std.mem.eql(u8, @tagName(r), route)) return i;
        for (ep.platforms, 0..) |p, i| if (std.mem.eql(u8, p.host, route)) return regions.len + i;
        return null;
    }

    pub fn get(l: *Limiters, route: []const u8) ?*Limiter {
        return &l.all[index(route) orelse return null];
    }

    fn routeName(i: usize) []const u8 {
        return if (i < regions.len) @tagName(regions[i]) else ep.platforms[i - regions.len].host;
    }

    /// Each route's app windows, a line "route seconds ms ms ..." of send times in real
    /// ms, for the next process (a deploy's restart) to load
    pub fn save(l: *Limiters, w: *std.Io.Writer, real_ms: i64) !void {
        for (&l.all, 0..) |*limiter, i| try limiter.save(w, routeName(i), real_ms);
    }

    /// What save wrote, into windows of the same length; how many send times were
    /// still in their window
    pub fn load(l: *Limiters, text: []const u8, real_ms: i64) !usize {
        var loaded: usize = 0;
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| {
            const space = std.mem.findScalar(u8, line, ' ') orelse continue;
            const limiter = l.get(line[0..space]) orelse continue;
            loaded += try limiter.load(line[space + 1 ..], real_ms);
        }
        return loaded;
    }
};

const testing = std.testing;

test Limiters {
    var l = try Limiters.init(testing.allocator, testing.io);
    defer l.deinit();
    try testing.expect(l.get("europe") != l.get("euw1"));
    try testing.expect(l.get("euw1") != null and l.get("nope") == null);
}

test "saved windows load into the next process's limiters" {
    var a = try Limiters.init(testing.allocator, testing.io);
    defer a.deinit();
    const eu = a.get("europe").?;
    try eu.acquire("m", false);
    try eu.acquire("m", true);
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try a.save(&w, 1_000_000);
    try testing.expect(std.mem.startsWith(u8, w.buffered(), "europe 1 "));

    var b = try Limiters.init(testing.allocator, testing.io);
    defer b.deinit();
    try testing.expectEqual(@as(usize, 4), try b.load(w.buffered(), 1_000_000));
    try testing.expectEqual(@as(usize, 2), b.get("europe").?.global.windows.items[1].hits.len);
    try testing.expectEqual(@as(usize, 0), b.get("americas").?.global.windows.items[1].hits.len);
}
