//! `meiolol-lab compare A B`: the paired comparison of two prediction files, B minus A in
//! log loss per game (negative: B better), 95% interval over games (games independent, so
//! clustered by game). A and B are `PATH[:COLUMN]`: netcheck/playernet preds.tsv (one row
//! per game: match_id, y, fold or block, model columns of blue's chance) or exp
//! dev.tsv-shaped files (match_id slot outcome y pred: per game, blue's chance is the
//! mean over its win rows, a red row's pred flipped). Refuses comparisons that mean
//! nothing: different labels, different games (unless --intersect), different builds or
//! snapshots per lab-run's run meta (unless --allow-build, --allow-snap). --emit appends
//! the result as a docs/nn-results row. Log loss clamps p to [1e-6, 1 - 1e-6] (gains')

const std = @import("std");
const nn = @import("nn");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const usage =
    \\  compare A B [--intersect] [--allow-build] [--allow-snap] [--by-block]
    \\          [--emit FILE --model NAME --vs NAME [--block NAME] [--source S]
    \\           [--note TEXT] [--fit-games N]]
    \\                                  B - A log loss per game (negative: B better), 95%
    \\                                  paired; A, B: PATH[:COLUMN] (preds.tsv or
    \\                                  dev.tsv-shaped); refuses different labels, games,
    \\                                  builds, snapshots; --emit appends a
    \\                                  docs/nn-results row (lab/compare.zig)
    \\
;

const emit_header = "model\tvs\tblock\tdiff\tci\tseeds\tseed_lo\tseed_hi\tgames" ++
    "\tfit_games\tsource\tnote";

const Spec = struct { path: []const u8, col: ?[]const u8 };

const Args = struct {
    a: Spec,
    b: Spec,
    intersect: bool = false,
    allow_build: bool = false,
    allow_snap: bool = false,
    by_block: bool = false,
    emit: ?[]const u8 = null,
    model: ?[]const u8 = null,
    vs: ?[]const u8 = null,
    block: ?[]const u8 = null,
    source: ?[]const u8 = null,
    note: ?[]const u8 = null,
    fit_games: ?[]const u8 = null,
};

/// `p` is blue's win chance; a dev.tsv-shaped file sums it over `n` rows until loaded
const Game = struct { y: f64, p: f64, seeds: []f64 = &.{}, n: u32 = 1, slots: u16 = 0 };

/// Keyed by "block\tmatch_id", in file order
const Games = std.StringArrayHashMapUnmanaged(Game);

const Side = struct {
    spec: Spec,
    col: []const u8,
    seed_names: []const []const u8 = &.{},
    games: Games = .empty,
    meta: ?Meta = null,
};

const Meta = struct {
    run: []const u8,
    src: ?[]const u8 = null,
    harness: ?[]const u8 = null,
    /// The snap lines' hashes, comma-joined
    snap: ?[]const u8 = null,
};

const Refusal = error{ Refused, OutOfMemory };

const Ctx = struct {
    arena: Allocator,
    io: Io,
    dir: Io.Dir,
    why: []const u8 = "",

    fn refuse(c: *Ctx, comptime fmt: []const u8, args: anytype) Refusal {
        c.why = try std.fmt.allocPrint(c.arena, fmt, args);
        return error.Refused;
    }
};

pub fn main(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8) !u8 {
    _ = gpa;
    const args = parseArgs(argv) catch {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    };
    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    var c: Ctx = .{ .arena = arena, .io = io, .dir = Io.Dir.cwd() };
    run(&c, args, w) catch |err| switch (err) {
        error.Refused => {
            try w.flush();
            std.debug.print("compare: refused: {s}\n", .{c.why});
            return 2;
        },
        else => return err,
    };
    try w.flush();
    return 0;
}

fn parseSpec(s: []const u8) Spec {
    const whole: Spec = .{ .path = s, .col = null };
    const i = std.mem.lastIndexOfScalar(u8, s, ':') orelse return whole;
    const col = s[i + 1 ..];
    if (col.len == 0 or std.mem.indexOfScalar(u8, col, '/') != null) return whole;
    return .{ .path = s[0..i], .col = col };
}

fn parseArgs(argv: []const []const u8) !Args {
    var specs: [2]Spec = undefined;
    var n_specs: usize = 0;
    var args: Args = .{ .a = undefined, .b = undefined };
    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (!std.mem.startsWith(u8, a, "--")) {
            if (n_specs == 2) return error.Usage;
            specs[n_specs] = parseSpec(a);
            n_specs += 1;
            continue;
        }
        const flags = [_]struct { []const u8, *bool }{
            .{ "--intersect", &args.intersect },
            .{ "--allow-build", &args.allow_build },
            .{ "--allow-snap", &args.allow_snap },
            .{ "--by-block", &args.by_block },
        };
        const flag = for (flags) |f| {
            if (std.mem.eql(u8, a, f[0])) break f[1];
        } else null;
        if (flag) |f| {
            f.* = true;
            continue;
        }
        const opts = [_]struct { []const u8, *?[]const u8 }{
            .{ "--emit", &args.emit },
            .{ "--model", &args.model },
            .{ "--vs", &args.vs },
            .{ "--block", &args.block },
            .{ "--source", &args.source },
            .{ "--note", &args.note },
            .{ "--fit-games", &args.fit_games },
        };
        const opt = for (opts) |o| {
            if (std.mem.eql(u8, a, o[0])) break o[1];
        } else return error.Usage;
        i += 1;
        if (i == argv.len) return error.Usage;
        opt.* = argv[i];
    }
    if (n_specs != 2) return error.Usage;
    if (args.emit != null and (args.model == null or args.vs == null)) return error.Usage;
    args.a = specs[0];
    args.b = specs[1];
    return args;
}

const max_cols = 64;

fn splitLine(line: []const u8, cols: *[max_cols][]const u8) usize {
    var it = std.mem.splitScalar(u8, line, '\t');
    var n: usize = 0;
    while (it.next()) |x| : (n += 1) if (n < max_cols) {
        cols[n] = x;
    };
    return n;
}

fn find(names: []const []const u8, name: []const u8) ?usize {
    for (names, 0..) |x, i| if (std.mem.eql(u8, x, name)) return i;
    return null;
}

fn isSeed(name: []const u8) bool {
    if (!std.mem.startsWith(u8, name, "seed") or name.len == 4) return false;
    for (name[4..]) |ch| if (!std.ascii.isDigit(ch)) return false;
    return true;
}

fn load(c: *Ctx, spec: Spec) !Side {
    const text = c.dir.readFileAlloc(c.io, spec.path, c.arena, .unlimited) catch |err|
        return c.refuse("{s}: {s}", .{ spec.path, @errorName(err) });
    var lines = std.mem.splitScalar(u8, text, '\n');
    var line_no: usize = 0;
    const header = while (lines.next()) |l| {
        line_no += 1;
        const line = std.mem.trimEnd(u8, l, "\r");
        if (line.len > 0 and line[0] != '#') break line;
    } else return c.refuse("{s}: no header line", .{spec.path});
    var head: [max_cols][]const u8 = undefined;
    const n_head = splitLine(header, &head);
    if (n_head > max_cols)
        return c.refuse("{s}: over {d} columns", .{ spec.path, max_cols });
    const names = head[0..n_head];
    const per_row = find(names, "slot") != null and find(names, "outcome") != null;
    const mi = find(names, "match_id") orelse
        return c.refuse("{s}: no match_id column", .{spec.path});
    const yi = find(names, "y") orelse return c.refuse("{s}: no y column", .{spec.path});
    const bi = find(names, "block") orelse if (per_row) null else find(names, "fold");

    var side: Side = .{ .spec = spec, .col = undefined };
    const fixed = [_][]const u8{
        "match_id", "y", "fold", "block", "platform", "slot", "outcome",
    };
    if (spec.col) |col| {
        if (find(&fixed, col) != null or find(names, col) == null)
            return c.refuse("{s}: no model column {s}", .{ spec.path, col });
        side.col = col;
    } else if (per_row) {
        side.col = "pred";
    } else {
        side.col = if (find(names, "ens") != null) "ens" else names[n_head - 1];
        if (find(&fixed, side.col) != null)
            return c.refuse("{s}: no model column", .{spec.path});
    }
    const pi = find(names, side.col) orelse
        return c.refuse("{s}: no {s} column", .{ spec.path, side.col });

    var seed_at: std.ArrayList(usize) = .empty;
    var seed_names: std.ArrayList([]const u8) = .empty;
    if (!per_row) for (names, 0..) |x, i| if (isSeed(x)) {
        try seed_at.append(c.arena, i);
        try seed_names.append(c.arena, x);
    };
    side.seed_names = seed_names.items;
    const si = if (per_row) find(names, "slot").? else 0;
    const oi = if (per_row) find(names, "outcome").? else 0;

    var cols: [max_cols][]const u8 = undefined;
    var key_buf: [512]u8 = undefined;
    while (lines.next()) |l| {
        line_no += 1;
        const line = std.mem.trimEnd(u8, l, "\r");
        if (line.len == 0 or line[0] == '#') continue;
        const n = splitLine(line, &cols);
        if (n < n_head) return c.refuse("{s}:{d}: short row", .{ spec.path, line_no });
        if (per_row and !std.mem.eql(u8, cols[oi], "win")) continue;
        const block = if (bi) |b| cols[b] else "-";
        const key = std.fmt.bufPrint(&key_buf, "{s}\t{s}", .{ block, cols[mi] }) catch
            return c.refuse("{s}:{d}: match_id too long", .{ spec.path, line_no });
        const y = std.fmt.parseFloat(f64, cols[yi]) catch
            return c.refuse("{s}:{d}: bad y", .{ spec.path, line_no });
        const p = std.fmt.parseFloat(f64, cols[pi]) catch
            return c.refuse("{s}:{d}: bad {s}", .{ spec.path, line_no, side.col });
        const e = try side.games.getOrPut(c.arena, key);
        if (!e.found_existing) e.key_ptr.* = try c.arena.dupe(u8, key);
        if (!per_row) {
            if (e.found_existing) return c.refuse("{s}: game {s} {s} repeated", .{
                spec.path, block, cols[mi],
            });
            const seeds = try c.arena.alloc(f64, seed_at.items.len);
            for (seeds, seed_at.items) |*s, at| {
                s.* = std.fmt.parseFloat(f64, cols[at]) catch
                    return c.refuse("{s}:{d}: bad {s}", .{ spec.path, line_no, names[at] });
            }
            e.value_ptr.* = .{ .y = y, .p = p, .seeds = seeds };
            continue;
        }
        const slot = std.fmt.parseInt(u4, cols[si], 10) catch
            return c.refuse("{s}:{d}: bad slot", .{ spec.path, line_no });
        if (slot > 9) return c.refuse("{s}:{d}: bad slot", .{ spec.path, line_no });
        const blue = slot < 5;
        const blue_y = if (blue) y else 1 - y;
        const blue_p = if (blue) p else 1 - p;
        const bit = @as(u16, 1) << slot;
        if (!e.found_existing) {
            e.value_ptr.* = .{ .y = blue_y, .p = blue_p, .slots = bit };
            continue;
        }
        const g = e.value_ptr;
        if (g.slots & bit != 0) return c.refuse("{s}: game {s} {s} slot {d} repeated", .{
            spec.path, block, cols[mi], slot,
        });
        if (g.y != blue_y) return c.refuse("{s}: game {s} {s}: rows disagree on y", .{
            spec.path, block, cols[mi],
        });
        g.slots |= bit;
        g.p += blue_p;
        g.n += 1;
    }
    if (per_row) for (side.games.values()) |*g| {
        g.p /= @floatFromInt(g.n);
    };
    side.meta = try findMeta(c, spec.path);
    return side;
}

/// lab-run's `meta` beside the predictions file, or up to two directories above it
/// (netcheck writes into the run dir or a subdirectory)
fn findMeta(c: *Ctx, path: []const u8) !?Meta {
    const abs = c.dir.realPathFileAlloc(c.io, path, c.arena) catch return null;
    var dir = std.fs.path.dirname(abs);
    for (0..3) |_| {
        const d = dir orelse return null;
        const mp = try std.fs.path.join(c.arena, &.{ d, "meta" });
        if (Io.Dir.cwd().readFileAlloc(c.io, mp, c.arena, .limited(1 << 20))) |text| {
            return try parseMeta(c.arena, std.fs.path.basename(d), text);
        } else |_| {}
        dir = std.fs.path.dirname(d);
    }
    return null;
}

fn parseMeta(arena: Allocator, run_dir: []const u8, text: []const u8) !Meta {
    var m: Meta = .{ .run = run_dir };
    var snaps: std.ArrayList(u8) = .empty;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |l| {
        const line = std.mem.trim(u8, l, " \t\r");
        const sp = std.mem.indexOfAny(u8, line, " \t") orelse continue;
        const key = line[0..sp];
        const value = std.mem.trim(u8, line[sp + 1 ..], " \t");
        if (std.mem.eql(u8, key, "src")) m.src = value;
        if (std.mem.eql(u8, key, "harness")) m.harness = value;
        if (std.mem.eql(u8, key, "snap")) {
            const at = std.mem.lastIndexOfAny(u8, value, " \t");
            const h = if (at) |i| value[i + 1 ..] else value;
            if (snaps.items.len > 0) try snaps.append(arena, ',');
            try snaps.appendSlice(arena, h);
        }
    }
    if (snaps.items.len > 0) m.snap = snaps.items;
    return m;
}

fn loss(y: f64, p: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

const Diff = struct {
    mean: f64,
    half: f64,

    fn verdict(d: Diff) enum { better, worse, tie } {
        if (d.mean + d.half < 0) return .better;
        if (d.mean - d.half > 0) return .worse;
        return .tie;
    }

    fn words(d: Diff) []const u8 {
        return switch (d.verdict()) {
            .better => "B better",
            .worse => "B worse",
            .tie => "tie (not detected)",
        };
    }
};

fn meanCi(d: []const f64) Diff {
    const n: f64 = @floatFromInt(d.len);
    if (d.len == 0) return .{ .mean = 0, .half = 0 };
    var s: f64 = 0;
    for (d) |x| s += x;
    const mean = s / n;
    if (d.len < 2) return .{ .mean = mean, .half = 0 };
    var ss: f64 = 0;
    for (d) |x| ss += (x - mean) * (x - mean);
    return .{ .mean = mean, .half = 1.96 * @sqrt(ss / (n - 1)) / @sqrt(n) };
}

fn accuracy(y: []const f64, p: []const f64) f64 {
    var right: f64 = 0;
    for (y, p) |yy, pp| {
        if ((pp >= 0.5) == (yy == 1)) right += 1;
    }
    return right / @as(f64, @floatFromInt(y.len));
}

/// Both known and unequal
fn differs(a: ?[]const u8, b: ?[]const u8) bool {
    return a != null and b != null and !std.mem.eql(u8, a.?, b.?);
}

fn blockOf(key: []const u8) []const u8 {
    return key[0..std.mem.indexOfScalar(u8, key, '\t').?];
}

fn isFold(block: []const u8) bool {
    if (std.mem.startsWith(u8, block, "fold")) return true;
    if (block.len == 0) return false;
    for (block) |ch| if (!std.ascii.isDigit(ch)) return false;
    return true;
}

fn printSide(w: *Io.Writer, label: []const u8, s: *const Side) !void {
    try w.print("{s}  {s}:{s}", .{ label, s.spec.path, s.col });
    if (s.meta) |m| {
        try w.print("  run {s}", .{m.run});
        if (m.src) |x| try w.print(" src {s}", .{x});
        if (m.harness) |x| try w.print(" harness {s}", .{x});
        if (m.snap) |x| try w.print(" snap {s}", .{x});
        try w.writeByte('\n');
    } else {
        try w.print("\n{s}: no run meta (provenance unknown)\n", .{label});
    }
}

fn run(c: *Ctx, args: Args, w: *Io.Writer) !void {
    const a = try load(c, args.a);
    const b = try load(c, args.b);
    try w.writeAll("compare: B - A, log loss per game; negative: B better\n");
    try printSide(w, "A", &a);
    try printSide(w, "B", &b);

    var differ: usize = 0;
    var first: ?[]const u8 = null;
    var both: usize = 0;
    for (a.games.keys(), a.games.values()) |k, ga| {
        const gb = b.games.get(k) orelse continue;
        both += 1;
        if (ga.y == gb.y) continue;
        differ += 1;
        if (first == null) first = k;
    }
    if (first) |k| return c.refuse("different data: {d} games' y differ (first {s})", .{
        differ, try std.mem.replaceOwned(u8, c.arena, k, "\t", " "),
    });
    const only_a = a.games.count() - both;
    const only_b = b.games.count() - both;
    if ((only_a > 0 or only_b > 0) and !args.intersect)
        return c.refuse("different games: only in A {d}, only in B {d}, both {d} " ++
            "(--intersect scores the shared ones)", .{ only_a, only_b, both });
    if (both == 0) return c.refuse("no shared games", .{});

    if (a.meta != null and b.meta != null) {
        const ma = a.meta.?;
        const mb = b.meta.?;
        if (differs(ma.harness, mb.harness) and !args.allow_build)
            return c.refuse("different builds (harness {s} vs {s}): both sides of a " ++
                "paired comparison from the same build (docs/model.md); --allow-build", .{
                ma.harness.?, mb.harness.?,
            });
        if (differs(ma.snap, mb.snap) and !args.allow_snap)
            return c.refuse("different snapshots (snap {s} vs {s}); --allow-snap", .{
                ma.snap.?, mb.snap.?,
            });
    }

    // The scored games, in A's order
    const ys = try c.arena.alloc(f64, both);
    const pa = try c.arena.alloc(f64, both);
    const pb = try c.arena.alloc(f64, both);
    const d = try c.arena.alloc(f64, both);
    const blocks = try c.arena.alloc([]const u8, both);
    const gbs = try c.arena.alloc(Game, both);
    var la: f64 = 0;
    var lb: f64 = 0;
    {
        var i: usize = 0;
        for (a.games.keys(), a.games.values()) |k, ga| {
            const gb = b.games.get(k) orelse continue;
            ys[i] = ga.y;
            pa[i] = ga.p;
            pb[i] = gb.p;
            const xa = loss(ga.y, ga.p);
            const xb = loss(ga.y, gb.p);
            la += xa;
            lb += xb;
            d[i] = xb - xa;
            blocks[i] = blockOf(k);
            gbs[i] = gb;
            i += 1;
        }
    }
    const n: f64 = @floatFromInt(both);
    la /= n;
    lb /= n;

    var counts: std.StringArrayHashMapUnmanaged(usize) = .empty;
    for (blocks) |bl| {
        const e = try counts.getOrPut(c.arena, bl);
        if (!e.found_existing) e.value_ptr.* = 0;
        e.value_ptr.* += 1;
    }
    counts.sort(struct {
        keys: []const []const u8,
        pub fn lessThan(s: @This(), i: usize, j: usize) bool {
            return std.mem.lessThan(u8, s.keys[i], s.keys[j]);
        }
    }{ .keys = counts.keys() });
    try w.print("games {d} (blocks:", .{both});
    for (counts.keys(), counts.values(), 0..) |k, v, i| {
        try w.print("{s} {s} {d}", .{ if (i == 0) "" else ",", k, v });
    }
    try w.writeByte(')');
    if (args.intersect)
        try w.print("  [intersect: dropped A-only {d}, B-only {d}]", .{ only_a, only_b });
    try w.writeByte('\n');

    try w.print("{s:<12}{s:<11}{s:<9}{s}\n", .{ "", "logloss", "auc", "acc" });
    for ([_][]const u8{ "A", "B" }, [_]f64{ la, lb }, [_][]const f64{ pa, pb }) |side, l, p| {
        const area = try nn.auc(f64, c.arena, ys, p);
        const acc = accuracy(ys, p) * 100;
        try w.print("{s:<12}{d:<11.5}{d:<9.4}{d:.1}%\n", .{ side, l, area, acc });
    }
    const diff = meanCi(d);
    try w.print("{s:<12}{d:.5} ± {d:.5} (95%, paired per game): {s}\n", .{
        "B - A", diff.mean, diff.half, diff.words(),
    });

    if (args.by_block) for (counts.keys()) |bl| {
        var db: std.ArrayList(f64) = .empty;
        for (blocks, d) |x, v| if (std.mem.eql(u8, x, bl)) try db.append(c.arena, v);
        const r = meanCi(db.items);
        try w.print("  block {s}  games {d}  B - A {d:.5} ± {d:.5}: {s}\n", .{
            bl, db.items.len, r.mean, r.half, r.words(),
        });
    };

    const b_ens = args.b.col == null or std.mem.eql(u8, args.b.col.?, "ens");
    const show_seeds = b.seed_names.len > 0 and b_ens;
    var seed_lo: f64 = std.math.inf(f64);
    var seed_hi: f64 = -std.math.inf(f64);
    if (show_seeds) {
        for (0..b.seed_names.len) |s| {
            var t: f64 = 0;
            for (gbs, ys, pa) |gb, y, p| t += loss(y, gb.seeds[s]) - loss(y, p);
            seed_lo = @min(seed_lo, t / n);
            seed_hi = @max(seed_hi, t / n);
        }
        try w.print("{s:<12}{d}: lo {d:.5} hi {d:.5}\n", .{
            "seeds (B)", b.seed_names.len, seed_lo, seed_hi,
        });
    }
    try w.print("RESULT compare games={d} a={d:.5} b={d:.5} diff={d:.5} ci={d:.5} " ++
        "verdict={t}\n", .{ both, la, lb, diff.mean, diff.half, diff.verdict() });

    const file = args.emit orelse return;
    // netcheck names its blocks dev, 1..5; the results files dev-val, folds
    const block = args.block orelse if (counts.count() == 1)
        (if (std.mem.eql(u8, counts.keys()[0], "dev")) "dev-val" else counts.keys()[0])
    else for (counts.keys()) |k| {
        if (!isFold(k))
            return c.refuse("several blocks, not all folds: name one with --block", .{});
    } else "folds";
    var row: Io.Writer.Allocating = .init(c.arena);
    const rw = &row.writer;
    try rw.print("{s}\t{s}\t{s}\t{d:.5}\t{d:.5}\t", .{
        args.model.?, args.vs.?, block, diff.mean, diff.half,
    });
    if (show_seeds)
        try rw.print("{d}\t{d:.5}\t{d:.5}\t", .{ b.seed_names.len, seed_lo, seed_hi })
    else
        try rw.writeAll("1\t\t\t");
    const source = args.source orelse if (b.meta) |m| m.run else "";
    try rw.print("{d}\t{s}\t{s}\t{s}\n", .{
        both, args.fit_games orelse "", source, args.note orelse "",
    });
    try emitRow(c, file, row.written());
    try w.print("emit {s}: {s}", .{ file, row.written() });
}

/// Appends `row` to FILE after checking its header; an older header may carry `learned`
fn emitRow(c: *Ctx, path: []const u8, row: []const u8) !void {
    if (std.mem.count(u8, row, "\t") != 11 or std.mem.count(u8, row, "\n") != 1)
        return c.refuse("emit: a tab or newline in a cell", .{});
    const text = c.dir.readFileAlloc(c.io, path, c.arena, .unlimited) catch |err|
        return c.refuse("emit {s}: {s}", .{ path, @errorName(err) });
    var lines = std.mem.splitScalar(u8, text, '\n');
    const header = while (lines.next()) |l| {
        const line = std.mem.trimEnd(u8, l, "\r");
        if (line.len == 0 or line[0] != '#') break line;
    } else "";
    const known = std.mem.eql(u8, header, emit_header) or
        std.mem.eql(u8, header, emit_header ++ "\tlearned");
    if (!known)
        return c.refuse("emit {s}: header is not docs/nn-results/README.md's", .{path});
    var f = try c.dir.openFile(c.io, path, .{ .mode = .read_write });
    defer f.close(c.io);
    var at: u64 = text.len;
    if (text.len > 0 and text[text.len - 1] != '\n') {
        try f.writePositionalAll(c.io, "\n", at);
        at += 1;
    }
    try f.writePositionalAll(c.io, row, at);
}

const testing = std.testing;

const T = struct {
    tmp: testing.TmpDir,
    arena: std.heap.ArenaAllocator,
    out: Io.Writer.Allocating = undefined,
    c: Ctx = undefined,

    fn init(t: *T) void {
        t.tmp = testing.tmpDir(.{});
        t.arena = .init(testing.allocator);
        t.out = .init(t.arena.allocator());
        t.c = .{ .arena = t.arena.allocator(), .io = testing.io, .dir = t.tmp.dir };
    }

    fn deinit(t: *T) void {
        t.arena.deinit();
        t.tmp.cleanup();
    }

    fn write(t: *T, path: []const u8, data: []const u8) !void {
        if (std.fs.path.dirname(path)) |d| try t.tmp.dir.createDirPath(testing.io, d);
        try t.tmp.dir.writeFile(testing.io, .{ .sub_path = path, .data = data });
    }

    /// Test data is written with spaces for tabs (string literals cannot hold tabs)
    fn tsv(t: *T, path: []const u8, data: []const u8) !void {
        try t.write(path, try std.mem.replaceOwned(u8, t.c.arena, data, " ", "\t"));
    }

    fn cmp(t: *T, argv: []const []const u8) !void {
        try run(&t.c, try parseArgs(argv), &t.out.writer);
    }

    fn has(t: *T, s: []const u8) bool {
        return std.mem.indexOf(u8, t.out.written(), s) != null;
    }
};

const preds_a =
    \\fold match_id platform y cand seed1 seed2 ens
    \\1 m1 EUW1 1 0.6 0.6 0.7 0.65
    \\1 m2 EUW1 0 0.4 0.3 0.5 0.35
    \\2 m3 EUW1 1 0.5 0.6 0.6 0.6
    \\2 m4 EUW1 0 0.55 0.5 0.4 0.45
    \\
;

test "per-row file: red rows flipped, blue's mean chance per game" {
    var t: T = .{ .tmp = undefined, .arena = undefined };
    t.init();
    defer t.deinit();
    // Blue lost m1: blue rows y 0, red rows y 1; blue's chance (0.4 + 0.2 + (1 - 0.7)) / 3
    try t.tsv("rows.tsv",
        \\# a comment
        \\match_id slot outcome y pred loss
        \\m1 0 win 0 0.4 9
        \\m1 3 win 0 0.2 9
        \\m1 7 win 1 0.7 9
        \\m1 0 gold14 500 300 9
        \\m2 6 win 0 0.1 9
        \\
    );
    const s = try load(&t.c, .{ .path = "rows.tsv", .col = null });
    try testing.expectEqual(2, s.games.count());
    const g1 = s.games.get("-\tm1").?;
    try testing.expectEqual(0, g1.y);
    try testing.expectApproxEqAbs(0.3, g1.p, 1e-12);
    const g2 = s.games.get("-\tm2").?;
    try testing.expectEqual(1, g2.y);
    try testing.expectApproxEqAbs(0.9, g2.p, 1e-12);
    const l = try load(&t.c, .{ .path = "rows.tsv", .col = "loss" });
    try testing.expectApproxEqAbs(1 - 9.0, l.games.get("-\tm2").?.p, 1e-12);
}

test "identical files: zero difference, a tie" {
    var t: T = .{ .tmp = undefined, .arena = undefined };
    t.init();
    defer t.deinit();
    try t.tsv("a.tsv", preds_a);
    try t.tsv("b.tsv", preds_a);
    try t.cmp(&.{ "a.tsv", "b.tsv" });
    try testing.expect(t.has("RESULT compare games=4 "));
    try testing.expect(t.has("diff=0.00000 ci=0.00000 verdict=tie"));
    try testing.expect(t.has("tie (not detected)"));
    try testing.expect(t.has("A  a.tsv:ens\nA: no run meta (provenance unknown)"));
    try testing.expect(t.has("seeds (B)   2: "));
}

test "refuses different labels and game sets; --intersect counts" {
    var t: T = .{ .tmp = undefined, .arena = undefined };
    t.init();
    defer t.deinit();
    try t.tsv("a.tsv", preds_a);
    try t.tsv("y.tsv",
        \\fold match_id y ens
        \\1 m1 0 0.6
        \\
    );
    try testing.expectError(error.Refused, t.cmp(&.{ "a.tsv", "y.tsv", "--intersect" }));
    try testing.expect(std.mem.startsWith(u8, t.c.why, "different data"));
    try t.tsv("s.tsv",
        \\fold match_id y ens
        \\1 m1 1 0.6
        \\1 m2 0 0.4
        \\2 m3 1 0.5
        \\3 m9 1 0.5
        \\
    );
    try testing.expectError(error.Refused, t.cmp(&.{ "a.tsv", "s.tsv" }));
    try testing.expectEqualStrings("different games: only in A 1, only in B 1, both 3 " ++
        "(--intersect scores the shared ones)", t.c.why);
    try t.cmp(&.{ "a.tsv", "s.tsv", "--intersect" });
    try testing.expect(t.has("games 3 (blocks: 1 2, 2 1)  [intersect: dropped A-only 1, " ++
        "B-only 1]"));
}

test "B strictly better: negative difference, B better" {
    var t: T = .{ .tmp = undefined, .arena = undefined };
    t.init();
    defer t.deinit();
    try t.tsv("a.tsv", preds_a);
    try t.cmp(&.{ "a.tsv:cand", "a.tsv:ens" });
    try testing.expect(t.has("verdict=better"));
    try testing.expect(t.has(": B better\n"));
    try testing.expect(std.mem.indexOf(u8, t.out.written(), "diff=-0.") != null);
    try testing.expect(t.has("seeds (B)   2: "));
}

test "run meta: a harness mismatch refuses, --allow-build passes" {
    var t: T = .{ .tmp = undefined, .arena = undefined };
    t.init();
    defer t.deinit();
    try t.tsv("runA/sub/preds.tsv", preds_a);
    try t.write("runA/meta", "host mac\nsrc abc123\nharness k1\nsnap /x/snaps/s1 h1\n");
    try t.tsv("runB/preds.tsv", preds_a);
    try t.write("runB/meta", "src abc123\nharness k2\nsnap /x/snaps/s1 h1\n");
    const ab = [_][]const u8{ "runA/sub/preds.tsv", "runB/preds.tsv" };
    try testing.expectError(error.Refused, t.cmp(&ab));
    try testing.expect(std.mem.startsWith(u8, t.c.why, "different builds (harness k1 vs k2)"));
    try t.cmp(&(ab ++ [_][]const u8{"--allow-build"}));
    try testing.expect(t.has("A  runA/sub/preds.tsv:ens  run runA src abc123 harness k1 " ++
        "snap h1\n"));
    try t.write("runB/meta", "harness k1\nsnap /x/snaps/s2 h2\n");
    try testing.expectError(error.Refused, t.cmp(&ab));
    try testing.expect(std.mem.startsWith(u8, t.c.why, "different snapshots"));
}

test "emit: header checked, row appended" {
    var t: T = .{ .tmp = undefined, .arena = undefined };
    t.init();
    defer t.deinit();
    try t.tsv("a.tsv", preds_a);
    try t.tsv("runB/preds.tsv", preds_a);
    try t.write("runB/meta", "harness k\n");
    try t.write("bad.tsv", "# title: x\nmodel\tvs\tdiff\n");
    const base = [_][]const u8{
        "a.tsv:cand", "runB/preds.tsv", "--model", "big net", "--vs", "ratings",
    };
    const bad = base ++ [_][]const u8{ "--emit", "bad.tsv" };
    try testing.expectError(error.Refused, t.cmp(&bad));
    try testing.expect(std.mem.indexOf(u8, t.c.why, "header") != null);
    try t.write("q.tsv", "# title: x\n" ++ emit_header ++ "\n");
    try t.cmp(&(base ++ [_][]const u8{ "--emit", "q.tsv", "--note", "a note" }));
    const text = try t.tmp.dir.readFileAlloc(testing.io, "q.tsv", t.c.arena, .unlimited);
    var lines = std.mem.splitScalar(u8, text, '\n');
    _ = lines.next();
    _ = lines.next();
    const row = lines.next().?;
    var cells: [max_cols][]const u8 = undefined;
    try testing.expectEqual(12, splitLine(row, &cells));
    try testing.expectEqualStrings("big net", cells[0]);
    try testing.expectEqualStrings("folds", cells[2]);
    try testing.expectEqualStrings("2", cells[5]);
    try testing.expect(cells[6].len > 0 and cells[7].len > 0);
    try testing.expectEqualStrings("4", cells[8]);
    try testing.expectEqualStrings("", cells[9]);
    try testing.expectEqualStrings("runB", cells[10]);
    try testing.expectEqualStrings("a note", cells[11]);
    try testing.expectEqualStrings("", lines.next().?);
}
