//! `meiolol eval`, `outcomes`, `legendaries`, `objectives`, `winchance`, `items`,
//! `playstyle`, `scaling`, `carry`: model checks and analyses on held-out games

const std = @import("std");
const stats = @import("../stats.zig");
const eval = @import("../eval.zig");
const replay = @import("../replay.zig");
const outcomes = @import("../outcomes.zig");
const objectives = @import("../objectives.zig");
const winchance = @import("../winchance.zig");
const items = @import("../items.zig");
const playstyle = @import("../playstyle.zig");
const scaling = @import("../scaling.zig");
const carry = @import("../carry.zig");
const test_looks = @import("../lab/looks.zig");
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
    while (c.next()) |_| {
        if (try g.parse(c) or try heldOut(c, &o)) continue;
        if (c.is("--folds")) {
            o.folds = try c.int(u32);
            if (o.folds < 2) return error.Usage;
        } else if (c.is("--history")) {
            history = try c.value();
        } else if (c.is("--replay")) {
            replay_only = true;
        } else return error.Usage;
    }
    if (replay_only and history != null) return error.Usage;
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
    \\              data (Data Dragon; outcomes and meiolol-lab's first_item read it)
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
    const legendaries = try outcomes.loadLegendaries(c.init.gpa, c.arena, c.init.io, path, chosen);
    std.debug.print("{s}: {d} patches\n", .{ path, legendaries.count() });
    return 0;
}

pub const usage_outcomes =
    \\  outcomes    do allies and enemies shift gold@14, lane gold, CS@10, deaths before 15
    \\              and first item beyond champion and lane? (markdown on stdout)
    \\
++ held_out_flags;

pub fn cmdOutcomes(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: outcomes.Options = .{};
    while (c.next()) |_| {
        if (!try g.parse(c) and !try heldOut(c, &o)) return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    const legendaries = try outcomes.loadLegendaries(
        c.init.gpa,
        c.arena,
        io,
        try std.fs.path.join(c.arena, &.{ c.data_dir, "legendaries.tsv" }),
        chosen,
    );
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try outcomes.run(c.init.gpa, io, db, chosen, platforms, &legendaries, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
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

pub const usage_items =
    \\  items       does the finished item change the win chance, given the state when it
    \\              was bought? (markdown on stdout; docs/model.md)
    \\
++ held_out_flags;

pub fn cmdItems(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: items.Options = .{};
    while (c.next()) |_| {
        if (!try g.parse(c) and !try heldOut(c, &o)) return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    const legendaries = try outcomes.loadLegendaries(
        c.init.gpa,
        c.arena,
        io,
        try std.fs.path.join(c.arena, &.{ c.data_dir, "legendaries.tsv" }),
        chosen,
    );
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try items.run(c.init.gpa, io, db, chosen, platforms, &legendaries, o, &stdout.interface);
    try stdout.interface.flush();
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

pub const usage_carry =
    \\  carry       which champions turn their own lead into wins, whose seat decides games,
    \\              which reward experience, which make games more decided? (markdown on
    \\              stdout; docs/model.md "Carry and impact")
    \\              --cuts A,B,C,D,E,DEV,TEST  ms: the lab's 5 fold block starts, dev
    \\                               and test cuts (default: eval.split's, as the lab's)
    \\              --patch P, --platform P, --test-share F  as scaling (default 0.15)
    \\              --test-platform P  region model only: dev-val and test on P's games;
    \\                               the global model is never scored on a region
    \\              --final          also score the test games (one look per model)
    \\              --table FILE     TSV of every champion-role's terms by minute
    \\              --type-table FILE  TSV of champion type x role x state terms by minute
    \\              --fold-table FILE  per fold and dev: leverage, scaling, skill per
    \\                               champion-role fitted before the block
    \\              --plant COV:SD[:SEED]  redraw winners with a planted champion slope on
    \\                               lane, kd, dmg or exp, sd SD win pp per unit
    \\
;

pub fn cmdCarry(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: carry.Options = .{};
    while (c.next()) |_| {
        if (try g.parse(c) or try heldOut(c, &o)) continue;
        if (c.is("--cuts")) {
            var it = std.mem.splitScalar(u8, try c.value(), ',');
            for (&o.cuts) |*x| x.* = std.fmt.parseInt(i64, it.next() orelse return error.Usage, 10) catch return error.Usage;
            if (it.next() != null) return error.Usage;
        } else if (c.is("--final")) {
            o.final = true;
        } else if (c.is("--table")) {
            o.table = try c.value();
        } else if (c.is("--fold-table")) {
            o.fold_table = try c.value();
        } else if (c.is("--type-table")) {
            o.type_table = try c.value();
        } else if (c.is("--plant")) {
            var it = std.mem.splitScalar(u8, try c.value(), ':');
            const cov = std.meta.stringToEnum(carry.Cov, it.next().?) orelse return error.Usage;
            const sd = std.fmt.parseFloat(f64, it.next() orelse return error.Usage) catch return error.Usage;
            const seed = if (it.next()) |x| std.fmt.parseInt(u64, x, 10) catch return error.Usage else 1;
            if (cov == .one) return error.Usage;
            o.plant = .{ .cov = cov, .sd = sd, .seed = seed };
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    if (o.final) _ = try test_looks.record(c.init.gpa, io, std.Io.Dir.cwd(), c.data_dir, "meiolol carry", c.args, &stdout.interface);
    var exclude = if (o.final) try test_looks.Exclude.load(c.init.gpa, io, std.Io.Dir.cwd(), c.data_dir) else null;
    defer if (exclude) |*e| e.deinit(c.init.gpa);
    if (exclude) |*e| o.exclude = &e.keys;
    try carry.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

pub const usage_scaling =
    \\  scaling     which champions win more than the gold and XP lead says, by minute
    \\              (scaling) and by the lead (converting it, coming back)? (markdown on
    \\              stdout; docs/model.md)
    \\
++ held_out_flags ++
    \\              --table FILE     TSV of every champion-role's effect and slope by minute
    \\              --state S        baseline: lead (team gold, XP; default), roles (gold
    \\                               by role: who holds it), objectives (+ objectives held)
    \\              --slope L        champion x lead term: team (default) or own (own gold
    \\                               minus the lane opponent's)
    \\
;

pub fn cmdScaling(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: scaling.Options = .{};
    while (c.next()) |_| {
        if (try g.parse(c) or try heldOut(c, &o)) continue;
        if (c.is("--table")) {
            o.table = try c.value();
        } else if (c.is("--state")) {
            o.state = std.meta.stringToEnum(scaling.State, try c.value()) orelse return error.Usage;
        } else if (c.is("--slope")) {
            o.slope = std.meta.stringToEnum(scaling.Slope, try c.value()) orelse return error.Usage;
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try scaling.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}
