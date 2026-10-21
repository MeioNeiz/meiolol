//! What every view shares, loaded once: curves, builds and lean files, and the pool
//! and learning tallies

const std = @import("std");
const store = @import("store");
const core = @import("core");
const html = @import("html.zig");
const pool = @import("../pool.zig");
const learning = @import("../learning.zig");
const builds = @import("../builds.zig");
const lean = @import("../lean.zig");
const partials = @import("../partials.zig");

const Stats = core.Stats;

const log = std.log.scoped(.site);

const root = @import("root.zig");
const Options = root.Options;
const Phases = @import("load.zig").Phases;

/// Every view's curves and builds files, loaded once for all of them
pub const Extras = struct {
    curves: [html.View.count]?core.curvesfile.Curves = @splat(null),
    curves_prev: [html.View.count]?core.curvesfile.Curves = @splat(null),
    builds: [html.View.count]?builds.File = @splat(null),
    builds_prev: [html.View.count]?builds.File = @splat(null),
    lean: ?lean.File = null,
    /// Pool and learning tallies by html.Region, on the first view's load: all patches,
    /// so both periods share them, and one pass over the database serves every view
    people: ?People = null,
    /// `site --views`: the views partials' directory (data/partials), whose games the
    /// loads read instead of the database's tables; null: the database
    partials_dir: ?[]const u8 = null,
    /// Opened (and brought up to date) on the first load that reads games
    games: ?*partials.Store = null,

    pub fn load(arena: std.mem.Allocator, io: std.Io, opts: Options) Extras {
        var e: Extras = .{};
        for (opts.curves, &e.curves) |path, *c| {
            if (path) |p| c.* = loadCurves(arena, io, p);
        }
        for (opts.curves_prev, &e.curves_prev) |path, *c| {
            if (path) |p| c.* = loadCurves(arena, io, p);
        }
        for (opts.builds, &e.builds) |path, *b| {
            if (path) |p| b.* = loadBuilds(arena, io, p);
        }
        for (opts.builds_prev, &e.builds_prev) |path, *b| {
            if (path) |p| b.* = loadBuilds(arena, io, p);
        }
        if (opts.lean) |p| e.lean = loadLean(arena, io, p);
        return e;
    }

    /// `arena` is load's
    pub fn deinit(e: *Extras, gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io) void {
        for (&e.curves) |*c| if (c.*) |*x| x.unmap(arena, io);
        for (&e.curves_prev) |*c| if (c.*) |*x| x.unmap(arena, io);
        if (e.people) |*p| p.deinit(gpa);
        if (e.games) |g| g.deinit();
    }

    /// The partials, opened on the first call; null without partials_dir or when they
    /// fail. On the loading thread, before any reader of them starts
    pub fn partialsFor(e: *Extras, gpa: std.mem.Allocator, io: std.Io, db: store.Db, phases: *Phases) !?*partials.Store {
        const dir = e.partials_dir orelse return null;
        if (e.games) |g| return g;
        // A write from the tables beats none: each file is replaced whole and the state
        // last, so what a failed refresh left is read again next time
        // Box, 18 Oct: whole-table scans 331-685 s whatever the count, lookups under
        // 2.7 ms a match; 6-8 h between full writes (~7k matches an hour) passed the
        // default 50k. Here, not in partials.zig, whose source change starts them again
        const g = partials.Store.open(gpa, io, db, dir, .{
            .now_ms = std.Io.Clock.real.now(io).toMilliseconds(),
            .bulk_after = 150_000,
        }) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                log.warn("partials at {s}: {t}; reading the database", .{ dir, err });
                e.partials_dir = null;
                return null;
            },
        };
        e.games = g;
        const n = g.counts;
        log.info("partials: {d} games, {d} matches read{s}, {d} gone, {d} day files written", .{
            n.games, n.read, if (n.bulk) " (whole tables)" else "", n.dropped, n.days_written,
        });
        phases.mark("partials");
        return g;
    }

    pub fn tallies(e: *Extras, gpa: std.mem.Allocator, db: store.Db, st: *const Stats, opts: Options) !*const People {
        if (e.people) |*p| {
            if (std.mem.eql(u32, p.ids, st.ids)) return p;
            // A champion added since (a new release): tally again
            p.deinit(gpa);
            e.people = null;
        }
        const sets: []const []const []const u8 = if (opts.euw_only)
            &.{opts.platforms}
        else
            &.{ opts.platforms, opts.all_platforms };
        const ids = try gpa.dupe(u32, st.ids);
        errdefer gpa.free(ids);
        // Learning after pool: it reads the bins pool's mastery pass finds
        var pools = try pool.tallyWith(gpa, db, st, sets, e.games);
        errdefer pools.deinit(gpa);
        const learnt = try learning.tallyWith(gpa, db, st, sets, e.games);
        e.people = .{ .ids = ids, .pool = pools, .learning = learnt };
        if (e.games) |g| log.info("partials: {d} mastery rows, {d} read", .{ g.counts.mastery, g.counts.mastery_read });
        return &e.people.?;
    }
};

pub const People = struct {
    /// Stats champion ids, which the tallies index by
    ids: []u32,
    pool: pool.Tallies,
    learning: []learning.Tally,

    fn deinit(p: *People, gpa: std.mem.Allocator) void {
        gpa.free(p.ids);
        p.pool.deinit(gpa);
        learning.freeTallies(gpa, p.learning);
    }
};

/// Optional, as curves: a bad or missing file leaves out build pages
fn loadBuilds(arena: std.mem.Allocator, io: std.Io, path: []const u8) ?builds.File {
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30)) catch |err| {
        switch (err) {
            error.FileNotFound => log.info("no builds at {s}", .{path}),
            else => log.warn("builds at {s}: {t}", .{ path, err }),
        }
        return null;
    };
    return builds.File.parse(arena, bytes) catch |err| {
        log.warn("builds at {s}: {t}", .{ path, err });
        return null;
    };
}

/// Optional, as builds: a bad or missing file leaves out the champion pages' line
fn loadLean(arena: std.mem.Allocator, io: std.Io, path: []const u8) ?lean.File {
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 24)) catch |err| {
        switch (err) {
            error.FileNotFound => log.info("no lean file at {s}", .{path}),
            else => log.warn("lean file at {s}: {t}", .{ path, err }),
        }
        return null;
    };
    return lean.File.parse(arena, bytes) catch |err| {
        log.warn("lean file at {s}: {t}", .{ path, err });
        return null;
    };
}

/// Optional extras: a bad or old file leaves out matchup pages, not the site
/// The views' curves file with the most games: the steadiest fit for the method page
pub fn biggestCurves(all: *const [html.View.count]?core.curvesfile.Curves) ?*const core.curvesfile.Curves {
    var best: ?*const core.curvesfile.Curves = null;
    for (all) |*c| if (c.*) |*x| {
        if (best == null or x.games > best.?.games) best = x;
    };
    return best;
}

/// Mapped, not read: a file is ~70-230 MB, a renderer keeps up to eight for its life, and
/// mapped pages are shared with the other renderer and the page cache (Extras.deinit
/// unmaps them)
fn loadCurves(arena: std.mem.Allocator, io: std.Io, path: []const u8) ?core.curvesfile.Curves {
    return core.curvesfile.Curves.map(arena, io, std.Io.Dir.cwd(), path) catch |err| {
        switch (err) {
            error.FileNotFound => log.info("no lane curves at {s}", .{path}),
            else => log.warn("lane curves at {s}: {t}", .{ path, err }),
        }
        return null;
    };
}
