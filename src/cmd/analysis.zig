//! `meiolol eval`, `legendaries`, `objectives`, `winchance`, `playstyle`: model checks
//! and analyses on held-out games

const std = @import("std");
const stats = @import("../stats.zig");
const eval = @import("../eval.zig");
const draftfile = @import("../draftfile.zig");
const ddragon = @import("../ddragon.zig");
const replay = @import("../replay.zig");
const objectives = @import("../objectives.zig");
const winchance = @import("../winchance.zig");
const playstyle = @import("../playstyle.zig");
const Date = @import("../date.zig").Date;
const main = @import("../main.zig");
const Cmd = main.Cmd;
const Games = main.Games;

/// The held-out analyses' flags, in each one's usage
const held_out_flags =
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats (train uses every one given)
    \\              --test-platform P  region model only: test on P's games from the cut;
    \\                               the global model is never scored on a region
    \\              --test-share F   newest share of played games, every platform, held
    \\                               out (default 0.15: the protocol's cut over every
    \\                               platform's and patch's games, whatever is scanned)
    \\              --preds DIR      one TSV of test predictions per model
    \\
;

/// --test-share and --test-platform, and --preds where `o` (an analysis' *Options) has
/// preds_dir; false for any other flag
fn heldOut(c: *Cmd, o: anytype) !bool {
    if (c.is("--test-share")) {
        o.test_share = try c.float();
        if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
    } else if (c.is("--test-platform")) {
        o.test_platform = try c.value();
    } else if (@hasField(@TypeOf(o.*), "preds_dir") and c.is("--preds")) {
        o.preds_dir = try c.value();
    } else return false;
    return true;
}

pub const usage_eval =
    \\  eval        how well the draft model predicts held-out newer games (markdown
    \\              report on stdout; docs/model.md)
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats
    \\              --test-share F   newest share of played games held out, one time cut
    \\                               over every platform (default 0.15)
    \\              --folds K        folds for tuning inside train (default 5)
    \\              --test-platform P  region model only (the global model is never scored
    \\                               on a region): test on P's games from the cut;
    \\                               compares training on P
    \\                               alone with every --platform pooled
    \\              --history FILE   append one TSV line (date, sizes, log loss and AUC
    \\                               per model) for the accuracy-vs-data curve
    \\              --dev            score the protocol's dev-val window, fitting below
    \\                               the dev cut (no test game scored)
    \\              --setnet FILE    a lab set net seed (setnet-s<seed>.json, netcheck
    \\                               --export 1; repeat for more seeds) as a correction
    \\                               on the current model, one more row; it must have
    \\                               seen no game of the scored window
    \\              --replay         only the pool and expertise replay, on a snapshot
    \\                               with mastery_pre.tsv and mastery_pre_pool.tsv
    \\                               (meiolol-lab mastery-pre); fits lanecard.Expertise
    \\
;

pub fn cmdEval(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: eval.Options = .{};
    var history: ?[]const u8 = null;
    var replay_only = false;
    var setnets: std.ArrayList(draftfile.SetNet) = .empty;
    while (c.next()) |_| {
        if (try g.parse(c) or try heldOut(c, &o)) continue;
        if (c.is("--folds")) {
            o.folds = try c.int(u32);
            if (o.folds < 2) return error.Usage;
        } else if (c.is("--history")) {
            history = try c.value();
        } else if (c.is("--replay")) {
            replay_only = true;
        } else if (c.is("--dev")) {
            o.dev = true;
        } else if (c.is("--setnet")) {
            const bytes = try std.Io.Dir.cwd().readFileAlloc(c.init.io, try c.value(), c.arena, .limited(64 << 20));
            try setnets.append(c.arena, try .parse(c.arena, bytes));
        } else return error.Usage;
    }
    o.setnets = setnets.items;
    // The history is the daily's test-window line of the shipped models
    if (replay_only and history != null) return error.Usage;
    if (history != null and (o.dev or o.setnets.len > 0)) return error.Usage;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    if (replay_only) {
        try replay.run(c.init.gpa, io, db, c.data_dir, chosen, platforms, o, &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    const line = try eval.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    if (history) |path| {
        const today: Date = .fromMs(std.Io.Clock.real.now(io).toMilliseconds());
        try eval.appendHistory(io, path, line, try c.arena.print("{f}", .{today}));
    }
    return 0;
}

pub const usage_legendaries =
    \\  legendaries write DATA/legendaries.tsv, the finished items of every patch in the
    \\              data (Data Dragon; meiolol-lab's first_item reads it)
    \\              --patch P, --platform P  as for stats
    \\
;

pub fn cmdLegendaries(c: *Cmd) !u8 {
    var g: Games = .{};
    while (c.next()) |_| {
        if (!try g.parse(c)) return error.Usage;
    }
    const db = try c.open();
    defer db.close();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, g.platformIds());
    const path = try std.fs.path.join(c.arena, &.{ c.data_dir, "legendaries.tsv" });
    const n = try updateLegendaries(c.init.gpa, c.arena, c.init.io, path, chosen);
    std.debug.print("{s}: {d} patches\n", .{ path, n });
    return 0;
}

/// Appends to `path` (lines "16.20<TAB>3078") the finished items of each of `patches` it
/// lacks, from Data Dragon, so later runs need no network; the patches it then holds
fn updateLegendaries(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    patches: []const []const u8,
) !usize {
    var have: std.AutoArrayHashMapUnmanaged(u32, void) = .empty;
    const cwd = std.Io.Dir.cwd();
    if (cwd.readFileAlloc(io, path, arena, .limited(16 << 20))) |text| {
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            const patch = stats.patchKey(it.next() orelse continue);
            _ = std.fmt.parseInt(u32, it.next() orelse continue, 10) catch continue;
            try have.put(arena, patch, {});
        }
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    var appended: std.ArrayList(u8) = .empty;
    for (patches) |p| {
        if ((try have.getOrPut(arena, stats.patchKey(p))).found_existing) continue;
        const items = try ddragon.legendaries(gpa, io, p);
        defer gpa.free(items);
        for (items) |item| try appended.print(arena, "{s}\t{d}\n", .{ p, item });
    }
    if (appended.items.len > 0) {
        const file = try cwd.createFile(io, path, .{ .truncate = false });
        defer file.close(io);
        var buf: [4096]u8 = undefined;
        var fw = file.writer(io, &buf);
        try fw.seekTo(try file.length(io));
        try fw.interface.writeAll(appended.items);
        try fw.interface.flush();
    }
    return have.count();
}

pub const usage_objectives =
    \\  objectives  what is an objective worth beyond its gold? win from the state at
    \\              10-30 min (markdown on stdout; docs/model.md)
    \\
++ held_out_flags;

pub fn cmdObjectives(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: objectives.Options = .{};
    while (c.next()) |_| {
        if (!try g.parse(c) and !try heldOut(c, &o)) return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try objectives.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

pub const usage_winchance =
    \\  winchance   fit win chance by minute from the game state (Your games' turning
    \\              minute and death cost): weights as Zig source, check on test games
    \\              (docs/model.md protocol) on stdout
    \\              --out FILE       default src/winchance_weights.zig
    \\              --dev            score every fifth train game instead (no weights
    \\                               unless --out)
    \\              --knots 1,5,...  the smooth fit's knot minutes
    \\
;

pub fn cmdWinchance(c: *Cmd) !u8 {
    var out: ?[]const u8 = null;
    var o: winchance.Options = .{};
    var knots: std.ArrayList(u8) = .empty;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--dev")) {
            o.dev = true;
        } else if (c.is("--knots")) {
            var it = std.mem.splitScalar(u8, try c.value(), ',');
            while (it.next()) |k| try knots.append(c.arena, std.fmt.parseInt(u8, k, 10) catch return error.Usage);
            o.knots = knots.items;
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var src: std.Io.Writer.Allocating = .init(c.arena);
    var buf: [16 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    if (out == null and !o.dev) out = "src/winchance_weights.zig";
    try winchance.fitWith(c.init.gpa, db, o, if (out != null) &src.writer else null, &stdout.interface);
    try stdout.interface.flush();
    if (out) |path| try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = src.written() });
    return 0;
}

pub const usage_playstyle =
    \\  playstyle   does early style (roaming, fights, wards) change the win chance, beyond
    \\              the champion and the state at 14:00? (markdown on stdout; docs/model.md)
    \\
++ held_out_flags;

pub fn cmdPlaystyle(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: playstyle.Options = .{};
    while (c.next()) |_| {
        if (!try g.parse(c) and !try heldOut(c, &o)) return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try playstyle.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}
