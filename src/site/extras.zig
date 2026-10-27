//! What every view shares, loaded once: curves, builds and lean files, and the pool
//! and learning tallies

const std = @import("std");
const store = @import("store");
const core = @import("core");
const html = @import("html.zig");
const pool = @import("../pool.zig");
const learning = @import("../learning.zig");
const builds = @import("../builds.zig");
const stats = @import("../stats.zig");
const lean = @import("../lean.zig");
const partials = @import("../partials.zig");
const patchnotes = @import("../patchnotes.zig");

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
    builds_rank: [html.View.count][builds.rank_tiers.len]?builds.File = @splat(@splat(null)),
    lean: ?lean.File = null,
    /// Pool and learning tallies, on the first view's load: one pass over the database
    /// serves every view with the same champions. A view with others adds its own:
    /// views loading at once may still hold the first
    people: std.ArrayList(*People) = .empty,
    /// `site --views`: the views partials' directory (data/partials), whose games the
    /// loads read instead of the database's tables; null: the database
    partials_dir: ?[]const u8 = null,
    /// Opened (and brought up to date) on the first load that reads games
    games: ?*partials.Store = null,
    /// load's, for what is loaded on first use
    arena: ?std.mem.Allocator = null,
    /// notesFor's, by "<prev> <cur>": null where they failed
    notes: std.StringHashMapUnmanaged(?*const patchnotes.Notes) = .empty,
    /// For views loading at once (Options.view_loads): one each for partialsFor, tallies
    /// and notesFor, so a view reading the open partials never waits on a minute of tallies
    games_mutex: std.Io.Mutex = .init,
    people_mutex: std.Io.Mutex = .init,
    notes_mutex: std.Io.Mutex = .init,
    /// Views loading at once: the first to fail sets it, and the others stop at their
    /// next step (going)
    stopped: std.atomic.Value(bool) = .init(false),
    /// Views loading at once: each phase's CPU time is its thread's, not the process's
    at_once: bool = false,

    pub fn load(arena: std.mem.Allocator, io: std.Io, opts: Options) Extras {
        var e: Extras = .{ .arena = arena };
        for (opts.curves, &e.curves) |path, *c| {
            if (path) |p| c.* = loadCurves(arena, io, p);
        }
        for (opts.curves_prev, &e.curves_prev) |path, *c| {
            if (path) |p| c.* = loadCurves(arena, io, p);
        }
        for (opts.builds, &e.builds) |path, *b| {
            if (path) |p| b.* = loadParsed(builds.File, arena, io, p, "builds", .limited(1 << 30));
        }
        for (opts.builds_prev, &e.builds_prev) |path, *b| {
            if (path) |p| b.* = loadParsed(builds.File, arena, io, p, "builds", .limited(1 << 30));
        }
        for (opts.builds_rank, &e.builds_rank) |paths, *bs| for (paths, bs) |path, *b| {
            if (path) |p| b.* = loadParsed(builds.File, arena, io, p, "builds", .limited(1 << 30));
        };
        if (opts.lean) |p| e.lean = loadParsed(lean.File, arena, io, p, "lean file", .limited(1 << 24));
        return e;
    }

    /// `arena` is load's
    pub fn deinit(e: *Extras, gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io) void {
        for (&e.curves) |*c| if (c.*) |*x| x.unmap(arena, io);
        for (&e.curves_prev) |*c| if (c.*) |*x| x.unmap(arena, io);
        for (e.people.items) |p| {
            p.deinit(gpa);
            gpa.destroy(p);
        }
        e.people.deinit(gpa);
        if (e.games) |g| g.deinit();
    }

    /// Riot's changes from `prev` to `cur` (Options.ddragon_dir), loaded on the pair's
    /// first call; null without the directory or when they fail: the patch page goes
    /// without
    pub fn notesFor(e: *Extras, gpa: std.mem.Allocator, io: std.Io, dir: ?[]const u8, prev: []const u8, cur: []const u8) !?*const patchnotes.Notes {
        const d = dir orelse return null;
        const arena = e.arena orelse return null;
        try e.notes_mutex.lock(io);
        defer e.notes_mutex.unlock(io);
        var buf: [64]u8 = undefined;
        const key = std.fmt.bufPrint(&buf, "{s} {s}", .{ prev, cur }) catch return null;
        if (e.notes.get(key)) |n| return n;
        const n: ?*const patchnotes.Notes = if (patchnotes.load(gpa, arena, io, d, prev, cur)) |loaded| blk: {
            const p = try arena.create(patchnotes.Notes);
            p.* = loaded;
            break :blk p;
        } else |err| switch (err) {
            error.OutOfMemory => return err,
            else => blk: {
                log.warn("patch notes {s} to {s}: {t}", .{ prev, cur, err });
                break :blk null;
            },
        };
        try e.notes.put(arena, try arena.dupe(u8, key), n);
        return n;
    }

    /// The partials, opened on the first call; null without partials_dir or when they
    /// fail. Readers get them only once opened
    pub fn partialsFor(e: *Extras, gpa: std.mem.Allocator, io: std.Io, db: store.Db, phases: *Phases) !?*partials.Store {
        try e.games_mutex.lock(io);
        defer e.games_mutex.unlock(io);
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

    /// The tallies for st's champions, made on the first call with them: they read st
    /// only for its ids, so whichever view comes first makes the same
    pub fn tallies(e: *Extras, gpa: std.mem.Allocator, io: std.Io, db: store.Db, st: *const Stats, opts: Options) !*const People {
        try e.people_mutex.lock(io);
        defer e.people_mutex.unlock(io);
        for (e.people.items) |p| if (std.mem.eql(u32, p.ids, st.ids)) return p;
        // Waited on another view's that failed
        try e.going();
        const sets: []const []const []const u8 = if (opts.euw_only)
            &.{opts.platforms}
        else
            &.{ opts.platforms, opts.all_platforms };
        var spreads: [html.View.count]stats.Slice = undefined;
        for (html.View.all, &spreads) |v, *s| s.* = viewSlice(opts, v.region, v.period);
        var learnings: [2]stats.Slice = undefined;
        for ([_]html.Period{ .days30, .patch }, &learnings) |period, *s| s.* = viewSlice(opts, .all, period);
        try e.people.ensureUnusedCapacity(gpa, 1);
        const p = try gpa.create(People);
        errdefer gpa.destroy(p);
        const ids = try gpa.dupe(u32, st.ids);
        errdefer gpa.free(ids);
        // Learning after pool: it reads the bins pool's mastery pass finds
        var pools = try pool.tally(gpa, db, st, sets, &spreads, e.games);
        errdefer pools.deinit(gpa);
        const learnt = try learning.tallyWith(gpa, db, st, &learnings, e.games);
        p.* = .{ .ids = ids, .pool = pools, .learning = learnt };
        e.people.appendAssumeCapacity(p);
        if (e.games) |g| log.info("partials: {d} mastery rows, {d} read", .{ g.counts.mastery, g.counts.mastery_read });
        return p;
    }

    /// error.Stopped once another view loading at once has failed
    pub fn going(e: *const Extras) !void {
        if (e.stopped.load(.monotonic)) return error.Stopped;
    }
};

/// A view's games, for the people tallies; every region is EUW's with Options.euw_only
fn viewSlice(opts: Options, region: html.Region, period: html.Period) stats.Slice {
    return .{
        .platforms = if (region == .euw or opts.euw_only) opts.platforms else opts.all_platforms,
        .since_ms = if (period == .days30) opts.since_ms else 0,
        .patches = if (period == .patch) opts.patches else &.{},
    };
}

/// Pools by region over every patch (a pool changes more slowly than a patch; mastery is
/// lifetime), players' win rates by html.View.index, learning by html.Period (every
/// region's games, learning.zig)
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

/// Optional, as curves: a bad or missing builds file leaves out build pages, a lean file
/// the champion pages' line
fn loadParsed(comptime T: type, arena: std.mem.Allocator, io: std.Io, path: []const u8, what: []const u8, limit: std.Io.Limit) ?T {
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, arena, limit) catch |err| {
        switch (err) {
            error.FileNotFound => log.info("no {s} at {s}", .{ what, path }),
            else => log.warn("{s} at {s}: {t}", .{ what, path, err }),
        }
        return null;
    };
    return T.parse(arena, bytes) catch |err| {
        log.warn("{s} at {s}: {t}", .{ what, path, err });
        return null;
    };
}

/// The views' curves file with the most games: the steadiest fit for the method page
pub fn biggestCurves(all: *const [html.View.count]?core.curvesfile.Curves) ?*const core.curvesfile.Curves {
    var best: ?*const core.curvesfile.Curves = null;
    for (all) |*c| if (c.*) |*x| {
        if (best == null or x.games > best.?.games) best = x;
    };
    return best;
}

/// Optional extras: a bad or old file leaves out matchup pages, not the site. Mapped, not
/// read: a file is ~70-230 MB, a renderer keeps up to eight for its life, and
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
