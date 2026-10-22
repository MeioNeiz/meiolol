//! The site in memory for rendering on request (Loaded), and the views file
//! (data/views.bin) it writes and reads

const std = @import("std");
const store = @import("store");
const html = @import("html.zig");
const daily = @import("../daily.zig");
const learn = @import("../learn.zig");
const pool = @import("../pool.zig");
const learning = @import("../learning.zig");
const spread = @import("../spread.zig");
const filters = @import("filters.zig");
const evalchart = @import("evalchart.zig");
const flat = @import("flat.zig");
const patchday = @import("../patchday.zig");

const Writer = std.Io.Writer;

const log = std.log.scoped(.site);

const root = @import("root.zig");
const Options = root.Options;
const Champ = root.Champ;
const Site = root.Site;
const File = root.File;
const asset = root.asset;
const renderPage = root.renderPage;
const renderShared = root.renderShared;
const Extras = @import("extras.zig").Extras;
const loadParts = @import("load.zig").loadParts;
const unload = @import("load.zig").unload;

/// The whole site in memory for rendering on request (`meiolol serve --render`, `meiolol
/// dev`): each view loads on its first request and stays
pub const Loaded = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    db: store.Db,
    opts: Options,
    arena_state: std.heap.ArenaAllocator,
    extras: Extras,
    sites: [html.View.count]?*Site = @splat(null),
    mutex: std.Io.Mutex = .init,
    /// False: requests never load a view; one not loaded yet is error.Loading (`meiolol
    /// render` loads them with loadView while it serves)
    lazy: bool = true,
    /// Parts of an earlier views file the loads take (reuseViews)
    old: ?*const Parts = null,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, db: store.Db, opts: Options) !*Loaded {
        const l = try gpa.create(Loaded);
        l.* = .{ .gpa = gpa, .io = io, .db = db, .opts = opts, .arena_state = .init(gpa), .extras = .{} };
        // It serves what the static build leaves out, so needs every view's data
        l.opts.static = .all;
        l.extras = .load(l.arena_state.allocator(), io, opts);
        return l;
    }

    pub fn deinit(l: *Loaded) void {
        for (l.sites) |s| if (s) |loaded| unload(loaded);
        l.extras.deinit(l.gpa, l.arena_state.allocator(), l.io);
        l.arena_state.deinit();
        l.gpa.destroy(l);
    }

    pub fn site(l: *Loaded, v: html.View) !*const Site {
        try l.mutex.lock(l.io);
        defer l.mutex.unlock(l.io);
        if (l.sites[v.index()]) |s| return s;
        if (!l.lazy) return error.Loading;
        const s = try loadParts(l.gpa, l.io, l.db, l.opts, v, &l.extras, l.old);
        l.sites[v.index()] = s;
        return s;
    }

    /// Loads `v` without holding the lock, so requests for loaded views go on meanwhile.
    /// Only one caller at a time: the database connection isn't shared
    pub fn loadView(l: *Loaded, v: html.View) !void {
        {
            try l.mutex.lock(l.io);
            defer l.mutex.unlock(l.io);
            if (l.sites[v.index()] != null) return;
        }
        const s = try loadParts(l.gpa, l.io, l.db, l.opts, v, &l.extras, l.old);
        l.mutex.lockUncancelable(l.io);
        defer l.mutex.unlock(l.io);
        l.sites[v.index()] = s;
    }

    /// The page or file at `path` from the site root, in `arena`; null when there is none
    pub fn get(l: *Loaded, arena: std.mem.Allocator, path: []const u8) !?[]const u8 {
        const view, const rest = for ([_]html.View{ html.View.all[3], html.View.all[2], html.View.all[1] }) |v| {
            if (std.mem.startsWith(u8, path, v.dir())) break .{ v, path[v.dir().len..] };
        } else .{ html.View.all[0], path };
        if (l.opts.euw_only and view.region != .euw) return null;
        if (try asset(arena, l.io, l.opts, rest)) |data| return data;
        var s = (try l.site(view)).*;
        s.arena = arena;
        var aw: Writer.Allocating = .init(arena);
        if (try renderPage(&s, &aw.writer, rest)) return aw.written();
        for (s.files) |f| if (std.mem.eql(u8, f.path, rest)) return f.data;
        if (view.index() != 0) return null;
        var shared = (try l.site(html.View.shared)).*;
        shared.arena = arena;
        if (try renderShared(&shared, &aw.writer, rest)) return aw.written();
        for (shared.shared_files) |f| if (std.mem.eql(u8, f.path, rest)) return f.data;
        return null;
    }

    /// The u64 after the magic: a file with another came from a binary whose types or
    /// part sources differ (partKeys); this one renders from it only when they match
    pub fn viewsFormat() u64 {
        var h: std.hash.Wyhash = .init(0);
        h.update(views_magic);
        for (partKeys()) |k| h.update(std.mem.asBytes(&k));
        return h.final();
    }

    /// Every loaded view and the options to `path`, for readViews: `meiolol site
    /// --views` does the database work once, and `meiolol render` reads the result
    /// in seconds (docs/hosting.md "Rendering on request"). Part by part, each with its
    /// key, so a later write can keep the ones still current (reuseViews)
    pub fn writeViews(l: *Loaded, path: []const u8) !void {
        const io = l.io;
        var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
        defer file.deinit(io);
        var buf: [64 * 1024]u8 = undefined;
        var fw = file.file.writer(io, &buf);
        const w = &fw.interface;
        try w.writeAll(views_magic);
        try w.writeInt(u64, viewsFormat(), .little);
        const keys = partKeys();
        var aw: Writer.Allocating = .init(l.gpa);
        defer aw.deinit();
        try writePart(w, &aw, keys, .opts, html.View.all[0], l.opts);
        for (l.sites, html.View.all) |slot, v| {
            const s = slot orelse continue;
            try writePart(w, &aw, keys, .base, v, BasePart{
                .patches = s.opts.patches,
                .champs = s.champs,
                .games = s.games,
                .patch = s.patch,
                .when = s.when,
                .patch_mix = s.patch_mix,
                .ddragon_version = s.ddragon_version,
                .since_ms = s.since_ms,
                .model = s.model,
            });
            const champs_key = champsKey(s.champs);
            if (v.index() == 0) try writePart(w, &aw, keys, .filter, v, FilterPart{ .champs_key = champs_key, .filter = s.filter });
            try writePart(w, &aw, keys, .people, v, PeoplePart{
                .champs_key = champs_key,
                .pool = s.pool,
                .learning = s.learning,
                .spread = s.spread,
                .by_view = s.by_view,
            });
            if (s.patchday) |pd| try writePart(w, &aw, keys, .prev, v, patchday.Wins{
                .prev_patch = pd.prev_patch,
                .cur_patch = pd.cur_patch,
                .prev_games = pd.prev_games,
                .cur_games = pd.cur_games,
                .champions = pd.champions,
            });
            if (std.meta.eql(v, html.View.shared)) try writePart(w, &aw, keys, .daily, v, DailyPart{
                .champs_key = champs_key,
                .files = s.daily_files,
                .learn = s.learn,
                .eval = s.eval,
            });
        }
        try w.flush();
        try file.replace(io);
    }

    fn writePart(w: *Writer, aw: *Writer.Allocating, keys: [part_count]u64, part: Part, v: html.View, value: anytype) !void {
        aw.clearRetainingCapacity();
        try flat.write(&aw.writer, value);
        try w.writeByte(@backingInt(part));
        try w.writeByte(@intCast(v.index()));
        try w.writeInt(u64, keys[@backingInt(part)], .little);
        try w.writeInt(u64, aw.written().len, .little);
        try w.writeAll(aw.written());
    }

    /// The views and options writeViews wrote, every one loaded (lazy off); options'
    /// strings in `arena`, which must outlive it. error.ViewsMismatch when a binary
    /// with other part keys wrote it
    pub fn readViews(gpa: std.mem.Allocator, io: std.Io, db: store.Db, path: []const u8, arena: std.mem.Allocator) !*Loaded {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
        defer gpa.free(bytes);
        const parts: Parts = try .parse(bytes, true);
        const opts = (try parts.get(Options, .opts, html.View.all[0], arena)) orelse return error.ViewsMismatch;
        const l = try Loaded.init(gpa, io, db, opts);
        errdefer l.deinit();
        l.lazy = false;
        for (&l.sites, html.View.all) |*slot, v| {
            if (parts.spans[@backingInt(Part.base)][v.index()] == null) continue;
            slot.* = try loadParts(gpa, io, db, l.opts, v, &l.extras, &parts);
        }
        return l;
    }

    /// Loads take what they can from the views file at `path` (Parts) instead of the
    /// database: `meiolol site --views --reuse` after a deploy, which loads only the
    /// parts the deploy changed. Kept until deinit; none when there is no file or it
    /// has another layout
    pub fn reuseViews(l: *Loaded, path: []const u8) !void {
        const a = l.arena_state.allocator();
        const bytes = std.Io.Dir.cwd().readFileAlloc(l.io, path, a, .unlimited) catch |err| switch (err) {
            error.FileNotFound => return,
            else => |e| return e,
        };
        const parts = try a.create(Parts);
        parts.* = Parts.parse(bytes, false) catch |err| switch (err) {
            error.ViewsMismatch => {
                log.info("views file {s}: another layout, nothing kept", .{path});
                return;
            },
            else => |e| return e,
        };
        l.old = parts;
    }
};

const views_magic = "MEIOVIE2";
/// A views file's parts. Each has its own key (partKeys), so a write after a deploy
/// keeps those whose types and sources the deploy left alone and loads only the rest
const Part = enum(u8) { opts, base, filter, people, daily, prev };
const part_count = @typeInfo(Part).@"enum".field_names.len;

/// A view's stats and champions; the parts after it are made from these. The rest of
/// its Site is rebuilt from them (stats from model, the champion index), comes from the
/// extras (curves, builds and lean files, read again by the loading binary) or from the
/// binary and options (addFiles)
pub const BasePart = struct {
    patches: []const []const u8,
    champs: []Champ,
    games: u32,
    patch: []const u8,
    when: []const u8,
    patch_mix: []const u8,
    ddragon_version: []const u8,
    since_ms: i64,
    model: []const u8,
};

/// The parts after the base hold the champsKey of the champions they were made with,
/// and are kept only with the same: a new champion moves every index
pub const FilterPart = struct { champs_key: u64, filter: filters.Made };

pub const PeoplePart = struct {
    champs_key: u64,
    pool: pool.Pool,
    learning: learning.Learning,
    spread: spread.Spread,
    by_view: []const root.ByView,
};

/// The shared view's
pub const DailyPart = struct {
    champs_key: u64,
    files: []const File,
    learn: ?learn.Facts,
    eval: []const evalchart.Point,
};

/// Bump when a change outside the parts' sources (partKeys) changes what a part holds:
/// loadParts and its helpers (load.zig, extras.zig, champs.zig), core, store
const data_version: u64 = 1;

/// Each part's key: its type's shape and the source of the code that makes it, so a
/// deploy that changes either loads it again
fn partKeys() [part_count]u64 {
    return .{
        partKey(Options, &.{}),
        partKey(BasePart, &.{ @embedFile("../stats.zig"), @embedFile("../partials.zig") }),
        partKey(FilterPart, &.{ @embedFile("filters.zig"), @embedFile("../partials.zig") }),
        partKey(PeoplePart, &.{ @embedFile("../pool.zig"), @embedFile("../learning.zig"), @embedFile("../spread.zig"), @embedFile("../partials.zig") }),
        partKey(DailyPart, &.{ @embedFile("../daily.zig"), @embedFile("../learn.zig"), @embedFile("evalchart.zig"), @embedFile("../partials.zig") }),
        partKey(patchday.Wins, &.{ @embedFile("../patchday.zig"), @embedFile("../stats.zig"), @embedFile("../partials.zig") }),
    };
}

fn partKey(comptime T: type, sources: []const []const u8) u64 {
    const shape = flat.fingerprint(T);
    var h: std.hash.Wyhash = .init(data_version);
    h.update(std.mem.asBytes(&shape));
    for (sources) |s| h.update(s);
    return h.final();
}

pub fn champsKey(champs: []const Champ) u64 {
    var h: std.hash.Wyhash = .init(0);
    for (champs) |ch| h.update(std.mem.asBytes(&ch.id));
    return h.final();
}

/// A views file's parts this binary can read: those with its key (partKeys)
pub const Parts = struct {
    bytes: []const u8,
    /// By Part and html.View.index
    spans: [part_count][html.View.count]?[]const u8 = @splat(@splat(null)),
    /// The whole file must be this binary's, every part there: `meiolol render`, which
    /// never loads from the database beside the web loop
    strict: bool,

    /// error.ViewsMismatch for another layout, or with `strict` another binary's file
    fn parse(bytes: []const u8, strict: bool) !Parts {
        var r: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, r.takeArray(views_magic.len) catch return error.ViewsMismatch, views_magic)) return error.ViewsMismatch;
        if (try r.takeInt(u64, .little) != Loaded.viewsFormat() and strict) return error.ViewsMismatch;
        const keys = partKeys();
        var p: Parts = .{ .bytes = bytes, .strict = strict };
        while (r.bufferedLen() > 0) {
            const tag = try r.takeByte();
            const view = try r.takeByte();
            const key = try r.takeInt(u64, .little);
            const len = std.math.cast(usize, try r.takeInt(u64, .little)) orelse return error.Corrupt;
            const data = r.take(len) catch return error.Corrupt;
            if (view >= html.View.count) return error.Corrupt;
            // A part an older binary had: not this one's
            const part = std.enums.fromInt(Part, tag) orelse continue;
            if (key == keys[@backingInt(part)]) p.spans[@backingInt(part)][view] = data;
        }
        return p;
    }

    /// The part when there with this binary's key, in `arena`
    fn get(p: *const Parts, comptime T: type, part: Part, v: html.View, arena: std.mem.Allocator) !?T {
        const data = p.spans[@backingInt(part)][v.index()] orelse return null;
        var r: std.Io.Reader = .fixed(data);
        const value = try flat.read(T, &r, arena);
        if (r.bufferedLen() != 0) return error.Corrupt;
        return value;
    }

    /// get, from `old` when there is one
    pub fn of(old: ?*const Parts, comptime T: type, part: Part, v: html.View, arena: std.mem.Allocator) !?T {
        return if (old) |o| o.get(T, part, v, arena) else null;
    }

    /// A part made after the base, kept only with the same champions; strict: one
    /// that isn't is ViewsMismatch
    pub fn ofFor(old: ?*const Parts, comptime T: type, part: Part, v: html.View, arena: std.mem.Allocator, champs_key: u64) !?T {
        const o = old orelse return null;
        if (try o.get(T, part, v, arena)) |value| {
            if (value.champs_key == champs_key) return value;
        }
        if (o.strict) return error.ViewsMismatch;
        return null;
    }
};
