//! meiolol-lab: modelling experiments. `zig build lab` builds it for this machine
//! (zig-out/bin) and the gpu-box (zig-out/gpu-box: x86_64 Linux, CUDA through libcuda);
//! docs/model.md has the results

const std = @import("std");
const cuda = @import("gpu/cuda.zig");
const anonymise = @import("lab/anonymise.zig");
const archive = @import("lab/archive.zig");
const mastery_pre = @import("lab/mastery_pre.zig");
const seatstats = @import("lab/seatstats.zig");
const compstats = @import("lab/compstats.zig");
const nnexport = @import("lab/nnexport.zig");
const protocol = @import("lab/protocol.zig");
const rows = @import("lab/rows.zig");
const pack = @import("lab/pack.zig");
const enemy = @import("lab/enemy.zig");
const pairs = @import("lab/pairs.zig");
const bench = @import("lab/bench.zig");
const draftnet = @import("lab/draftnet.zig");
const exp = @import("lab/exp.zig");
const draft = @import("lab/draft.zig");
const lane = @import("lab/lane.zig");
const harness = @import("lab/harness.zig");
const embfiles = @import("lab/embfiles.zig");
const fields = @import("lab/fields.zig");
const style = @import("lab/style.zig");
const compcheck = @import("lab/compcheck.zig");
const champcomp = @import("lab/champcomp.zig");
const champgroups = @import("lab/champgroups.zig");
const events = @import("lab/events.zig");
const randsplit = @import("lab/randsplit.zig");
const winnet = @import("lab/winnet.zig");
const effects = @import("lab/effects.zig");
const eventvalue = @import("lab/eventvalue.zig");
const stateexport = @import("lab/stateexport.zig");
const pretrain = @import("lab/pretrain.zig");
const playernet = @import("lab/playernet.zig");
const stack = @import("lab/stack.zig");
const curve = @import("lab/curve.zig");
const synth = @import("lab/synth.zig");
const health = @import("lab/health.zig");
const compare = @import("lab/compare.zig");
const looks = @import("lab/looks.zig");

const ptx: [:0]const u8 = @embedFile("kernels.ptx") ++ "";

const usage =
    \\meiolol-lab [--emb DIR] [--control shuffle] COMMAND
    \\  --emb DIR                       pretrain's embeddings for a needs_embeddings
    \\                                  candidate, in any command that fits one
    \\                                  (lab/embfiles.zig)
    \\  --control shuffle               every candidate fit on its training games'
    \\                                  outcomes permuted between games (scoring keeps
    \\                                  the real ones): a gain must vanish
    \\  gpu-smoke                       add two vectors on the GPU, check against the CPU
    \\  anonymise SRC DST [SALT_FILE]   copy snapshot SRC to DST with PUUIDs and match ids
    \\                                  hashed (salt: 32 bytes, default
    \\                                  ~/.config/meiolol/snap-salt; docs/data-safety.md)
    \\  archive EXPORT ARCHIVE [SALT_FILE] [FORGOTTEN]  pseudonymise one raw export from
    \\                                  the box into ARCHIVE (lab/archive.zig; zstd on PATH)
    \\  archive-forget ARCHIVE FORGOTTEN [SALT_FILE]  drop archived documents naming a
    \\                                  forgotten PUUID (plain, one per line)
    \\  archive-age ARCHIVE [DAYS]      blank hashed PUUIDs in days older than DAYS (730)
    \\  mastery-pre SNAP ARCHIVE        each ranked participant's latest archived mastery
    \\                                  fetch before game start: SNAP/mastery_pre.tsv
    \\                                  (lab/mastery_pre.zig; zstd on PATH)
    \\  seat-stats SNAP [DDRAGON [ARCHIVE]]  each ranked seat's end-of-game damage dealt
    \\                                  and taken, CC, healing from raw.db then the raw
    \\                                  archive, resists and range from
    \\                                  DDRAGON/<patch>/{champion,item}.json:
    \\                                  SNAP/seat_stats.tsv (lab/seatstats.zig); rows load it
    \\  comp-stats SNAP DDRAGON [ARCHIVE]  more per seat (vision, objectives, waveclear,
    \\                                  fights, roams, item flags) and team objectives, same
    \\                                  sources: SNAP/comp_stats.tsv, comp_teams.tsv
    \\                                  (lab/compstats.zig)
    \\  nn-export SNAP                  every game as tensors for the draft nets: SNAP/nn/
    \\                                  (lab/nnexport.zig: champions, splits, folds, aux
    \\                                  targets, fit-only norms)
    \\  split SNAP_DIR                  the shared held-out split (eval's, one time cut):
    \\                                  prints it, writes SNAP_DIR/split.tsv
    \\  rows SNAP_DIR                   load the model rows, print outcome counts and means
    \\  pack SNAP_DIR                   write the model rows as column files in SNAP_DIR/pack,
    \\                                  which every command then loads instead of SQLite
    \\  pairs BASE REF [PREDS...]       paired MSE gains of prediction TSVs on shared rows,
    \\                                  % of BASE's MSE, intervals vs REF clustered by game
    \\  bench SNAP [OPT VALUE]...       fm fits timed on one core, all cores and the GPU
    \\                                  (lab/bench.zig): --devices cpu1,cpu,gpu --kinds
    \\                                  additive,lane,pairwise --dims 8,32,128 --scales
    \\                                  1,4,16 --epochs 10 --sweep 0 (fits per sweep)
    \\                                  --profile 1 (GPU: fm_grad, fm_adam shares)
    \\  draftbench SNAP [OPT VALUE]...  the deep draft model (lab/draftnet.zig) timed the
    \\                                  same way: --devices cpu1,cpu,gpu --scales
    \\                                  1,4,16,64 --epochs 2 --sweep 0 --limit 0
    \\
++ exp.usage ++ draft.usage ++ lane.usage ++ fields.usage ++ style.usage ++ compcheck.usage ++ champcomp.usage ++ champgroups.usage ++ events.usage ++ randsplit.usage ++ stack.usage ++ curve.usage ++ winnet.usage ++ pretrain.usage ++ playernet.usage ++ synth.usage ++ health.usage ++ effects.usage ++ eventvalue.usage ++ stateexport.usage ++ compare.usage ++ looks.usage;

pub fn main(init: std.process.Init) !u8 {
    flushDenormals();
    const arena = init.arena.allocator();
    var argv = try init.minimal.args.toSlice(arena);
    const emb_dir: embfiles.Dir = .{ .io = init.io, .path = if (argv.len >= 3 and std.mem.eql(u8, argv[1], "--emb")) argv[2] else "" };
    const emb_source = emb_dir.source();
    if (emb_dir.path.len > 0) {
        harness.embeddings = &emb_source;
        argv = try std.mem.concat(arena, [:0]const u8, &.{ argv[0..1], argv[3..] });
    }
    if (argv.len >= 3 and std.mem.eql(u8, argv[1], "--control")) {
        harness.control = std.meta.stringToEnum(harness.Control, argv[2]) orelse {
            std.debug.print("--control: shuffle (permute: netcheck --net set's own --control)\n", .{});
            return 2;
        };
        argv = try std.mem.concat(arena, [:0]const u8, &.{ argv[0..1], argv[3..] });
    }
    if (argv.len < 2) {
        std.debug.print("{s}", .{usage});
        return 2;
    }
    const cmd = argv[1];
    if (std.mem.eql(u8, cmd, "gpu-smoke")) {
        try gpuSmoke(init.gpa);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "anonymise") and argv.len >= 4) {
        const salt = try readSalt(init, arena, if (argv.len >= 5) argv[4] else null) orelse return 1;
        try anonymise.run(init.gpa, init.io, argv[2], argv[3], salt);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "archive") and argv.len >= 4) {
        const salt = try readSalt(init, arena, if (argv.len >= 5) argv[4] else null) orelse return 1;
        const n = try archive.run(init.gpa, init.io, argv[2], argv[3], salt, if (argv.len >= 6) argv[5] else null);
        std.log.info("archived {s}: {d} summaries, {d} timelines, {d} mastery, {d} forgotten, {d} unreadable left out", .{
            argv[2], n.summaries, n.timelines, n.mastery, n.forgotten, n.unreadable,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "archive-forget") and argv.len >= 4) {
        const salt = try readSalt(init, arena, if (argv.len >= 5) argv[4] else null) orelse return 1;
        const text = try std.Io.Dir.cwd().readFileAlloc(init.io, argv[3], arena, .limited(1 << 30));
        var list: std.ArrayList([]const u8) = .empty;
        var lines = std.mem.tokenizeAny(u8, text, " \t\r\n");
        while (lines.next()) |p| try list.append(arena, p);
        const n = try archive.forget(init.gpa, init.io, argv[2], salt, list.items);
        std.log.info("archive: {d} lines dropped for {d} forgotten players", .{ n, list.items.len });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "archive-age") and argv.len >= 3) {
        const max_days = if (argv.len >= 4) try std.fmt.parseInt(u32, argv[3], 10) else 730;
        const today = @divFloor(std.Io.Clock.real.now(init.io).toSeconds(), std.time.s_per_day);
        const n = try archive.age(init.gpa, init.io, argv[2], today, max_days);
        std.log.info("archive: {d} days aged past {d} days", .{ n, max_days });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "mastery-pre") and argv.len >= 4) {
        const n = try mastery_pre.run(init.gpa, init.io, argv[2], argv[3]);
        std.log.info("mastery-pre: {d} rows, {d} with a pre-game fetch, median gap {d:.1} h " ++
            "({d} archive files read, {d} begun after the last game skipped)", .{
            n.rows, n.pre_game, n.median_gap_h, n.files_read, n.files_skipped,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "comp-stats") and (argv.len == 4 or argv.len == 5)) {
        const n = try compstats.run(init.gpa, init.io, argv[2], argv[3], if (argv.len == 5) argv[4] else null);
        std.log.info("comp-stats: {d} seats ({d} with item flags), {d} teams from {d} of {d} games' " ++
            "summaries ({d} from the archive); {d} unreadable, {d} seats with another champion left out", .{
            n.seats, n.with_items, n.teams, n.docs, n.games, n.from_archive, n.bad_docs, n.mismatch,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "seat-stats") and argv.len >= 3) {
        const n = try seatstats.run(
            init.gpa,
            init.io,
            argv[2],
            if (argv.len >= 4) argv[3] else null,
            if (argv.len >= 5) argv[4] else null,
        );
        std.log.info("seat-stats: {d} lines ({d} with Data Dragon values) from {d} of {d} games' " ++
            "summaries ({d} from the archive); {d} unreadable, {d} seats with another champion left out", .{
            n.lines, n.with_static, n.docs, n.games, n.from_archive, n.bad_docs, n.mismatch,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "events") and argv.len >= 3) {
        const n = try events.run(init.gpa, init.io, argv[2]);
        std.log.info("events: {d} lines from {d} timelines of {d} games ({d} with a summary); " ++
            "{d} epic monsters with an unknown steal", .{ n.lines, n.timelines, n.games, n.summaries, n.steal_unknown });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "nn-export") and argv.len >= 3) {
        var data = try loadData(init, argv[2]);
        defer data.deinit();
        const c = try harness.cuts(init.gpa, &data);
        var e = try nnexport.build(init.gpa, &data, c);
        defer e.deinit();
        try nnexport.write(init.gpa, init.io, argv[2], &e);
        std.log.info("nn-export: {d} games, {d} champions, {d} patches, k {d} -> {s}/{s}", .{
            e.len(), e.champions.len, e.patches.len, nnexport.k, argv[2], nnexport.dir_name,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "split") and argv.len >= 3) {
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try protocol.writeSplit(init.gpa, init.io, argv[2], &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    if (std.mem.eql(u8, cmd, "bench") and argv.len >= 3) {
        var opts: bench.Options = .{};
        var i: usize = 3;
        while (i + 1 < argv.len) : (i += 2) {
            const v = argv[i + 1];
            if (std.mem.eql(u8, argv[i], "--devices")) {
                opts.devices = try parseList(bench.Device, arena, v);
            } else if (std.mem.eql(u8, argv[i], "--kinds")) {
                opts.kinds = try parseList(@import("lab/fm.zig").Kind, arena, v);
            } else if (std.mem.eql(u8, argv[i], "--dims")) {
                opts.dims = try parseList(u32, arena, v);
            } else if (std.mem.eql(u8, argv[i], "--scales")) {
                opts.scales = try parseList(u32, arena, v);
            } else if (std.mem.eql(u8, argv[i], "--epochs")) {
                opts.epochs = try std.fmt.parseInt(u32, v, 10);
            } else if (std.mem.eql(u8, argv[i], "--sweep")) {
                opts.sweep = try std.fmt.parseInt(u32, v, 10);
            } else if (std.mem.eql(u8, argv[i], "--profile")) {
                opts.profile = !std.mem.eql(u8, v, "0");
            } else {
                std.debug.print("bench: unknown option {s}\n{s}", .{ argv[i], usage });
                return 2;
            }
        }
        var gpu: ?cuda.Gpu = null;
        if (std.mem.findScalar(bench.Device, opts.devices, .gpu) != null) {
            gpu = try cuda.Gpu.init(ptx);
            var buf: [128]u8 = @splat(0);
            std.log.info("device: {s}", .{try gpu.?.name(&buf)});
        }
        var data = try loadData(init, argv[2]);
        defer data.deinit();
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try bench.run(init.gpa, init.io, &data, opts, if (gpu) |*g| g else null, &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    if (std.mem.eql(u8, cmd, "draftbench") and argv.len >= 3) {
        var opts: draftnet.Options = .{};
        var i: usize = 3;
        while (i + 1 < argv.len) : (i += 2) {
            const v = argv[i + 1];
            if (std.mem.eql(u8, argv[i], "--devices")) {
                opts.devices = try parseList(draftnet.Device, arena, v);
            } else if (std.mem.eql(u8, argv[i], "--scales")) {
                opts.scales = try parseList(u32, arena, v);
            } else if (std.mem.eql(u8, argv[i], "--epochs")) {
                opts.epochs = try std.fmt.parseInt(u32, v, 10);
            } else if (std.mem.eql(u8, argv[i], "--sweep")) {
                opts.sweep = try std.fmt.parseInt(u32, v, 10);
            } else if (std.mem.eql(u8, argv[i], "--limit")) {
                opts.limit = try std.fmt.parseInt(u32, v, 10);
            } else {
                std.debug.print("draftbench: unknown option {s}\n{s}", .{ argv[i], usage });
                return 2;
            }
        }
        var gpu: ?cuda.Gpu = null;
        if (std.mem.findScalar(draftnet.Device, opts.devices, .gpu) != null) gpu = try cuda.Gpu.init(ptx);
        var data = try loadData(init, argv[2]);
        defer data.deinit();
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try draftnet.run(init.gpa, init.io, &data, opts, if (gpu) |*g| g else null, &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    if (std.mem.eql(u8, cmd, "pairs") and argv.len >= 4) {
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try pairs.run(init.gpa, init.io, argv[2..], &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    if (std.mem.eql(u8, cmd, "draft")) {
        return draft.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "fields")) {
        return fields.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "style")) {
        return style.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "stack")) {
        return stack.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "looks")) {
        return looks.main(init.gpa, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "compare")) {
        return compare.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "health")) {
        return health.main(init.gpa, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "plant-score")) {
        return synth.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "curve")) {
        return curve.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "ldai-filter")) {
        return randsplit.main(init.gpa, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "champcomp")) {
        return champcomp.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "champgroups")) {
        return champgroups.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "compcheck")) {
        return compcheck.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "netcheck")) {
        return winnet.main(init.gpa, arena, init.io, argv[2..], ptx);
    }
    if (std.mem.eql(u8, cmd, "eventvalue")) {
        return eventvalue.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "state-export")) {
        return stateexport.main(init.gpa, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "effects")) {
        return effects.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "playernet")) {
        return playernet.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "pretrain")) {
        return pretrain.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "lane")) {
        return lane.main(init.gpa, arena, init.io, argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "exp")) {
        return exp.main(init.gpa, arena, init.io, init.environ_map.get("HOME"), argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "pack") and argv.len >= 3) {
        var legendaries = try rows.loadLegendaries(init.gpa, init.io, argv[2]);
        defer legendaries.deinit(init.gpa);
        const n = try pack.write(init.gpa, init.io, argv[2], &legendaries);
        std.log.info("packed {d} games, {d} rows into {s}/{s} ({d:.1} MB)", .{
            n.games, n.rows, argv[2], pack.dir_name, @as(f64, @floatFromInt(n.bytes)) / 1e6,
        });
        return 0;
    }
    if (std.mem.eql(u8, cmd, "rows") and argv.len >= 3) {
        var data = try loadData(init, argv[2]);
        defer data.deinit();
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try rows.summary(&data, &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    std.debug.print("unknown command {s}\n{s}", .{ cmd, usage });
    return 2;
}

fn gpuSmoke(gpa: std.mem.Allocator) !void {
    const gpu = try cuda.Gpu.init(ptx);
    var buf: [128]u8 = @splat(0);
    std.debug.print("device: {s}\n", .{try gpu.name(&buf)});
    const vadd = try gpu.function("vadd");

    const n: u32 = 1 << 24;
    const a = try gpa.alloc(f32, n);
    defer gpa.free(a);
    const b = try gpa.alloc(f32, n);
    defer gpa.free(b);
    const c = try gpa.alloc(f32, n);
    defer gpa.free(c);
    for (a, b, 0..) |*x, *y, i| {
        x.* = @floatFromInt(i);
        y.* = 0.5;
    }
    var da = try gpu.alloc(f32, n);
    defer gpu.free(da);
    var db = try gpu.alloc(f32, n);
    defer gpu.free(db);
    var dc = try gpu.alloc(f32, n);
    defer gpu.free(dc);
    try gpu.upload(f32, da, a);
    try gpu.upload(f32, db, b);
    var nn = n;
    try gpu.launch(vadd, n, &.{ @ptrCast(&da), @ptrCast(&db), @ptrCast(&dc), @ptrCast(&nn) });
    try gpu.sync();
    try gpu.download(f32, c, dc);
    var bad: usize = 0;
    for (a, b, c) |x, y, z| bad += @intFromBool(z != x + y);
    std.debug.print("vadd n={d}: {d} mismatches\n", .{ n, bad });
    if (bad != 0) return error.Mismatch;
}

test {
    _ = @import("lab/snapcache.zig");
    _ = stack;
    _ = anonymise;
    _ = curve;
    _ = synth;
    _ = health;
    _ = compare;
    _ = looks;
    _ = archive;
    _ = mastery_pre;
    _ = seatstats;
    _ = compstats;
    _ = @import("lab/summaries.zig");
    _ = nnexport;
    _ = protocol;
    _ = rows;
    _ = pack;
    _ = enemy;
    _ = pairs;
    _ = bench;
    _ = draftnet;
    _ = harness;
    _ = exp;
    _ = draft;
    _ = lane;
    _ = fields;
    _ = style;
    _ = compcheck;
    _ = @import("lab/comps.zig");
    _ = champcomp;
    _ = champgroups;
    _ = events;
    _ = randsplit;
    _ = winnet;
    _ = pretrain;
    _ = playernet;
    _ = effects;
    _ = eventvalue;
    _ = stateexport;
}

/// x86 SSE runs ~100x slower on denormal floats, which Adam's decaying moments of rarely
/// seen parameters spend thousands of steps in: fm fits on the gpu-box ran 3-4x slower at
/// 16x rows (docs/compute.md "GPU vs CPU"). Flush them to zero (FTZ, DAZ); fits matched
/// to the last digit. Threads started afterwards inherit it
fn flushDenormals() void {
    if (@import("builtin").target.cpu.arch != .x86_64) return;
    var csr: u32 = 0;
    asm volatile ("stmxcsr (%[p])"
        :
        : [p] "r" (&csr),
        : .{ .memory = true });
    csr |= (1 << 15) | (1 << 6);
    asm volatile ("ldmxcsr (%[p])"
        :
        : [p] "r" (&csr),
        : .{ .memory = true });
}

/// Comma-separated enum tags or integers
fn parseList(comptime T: type, arena: std.mem.Allocator, text: []const u8) ![]const T {
    var out: std.ArrayList(T) = .empty;
    var it = std.mem.tokenizeScalar(u8, text, ',');
    while (it.next()) |s| try out.append(arena, switch (@typeInfo(T)) {
        .@"enum" => std.meta.stringToEnum(T, s) orelse return error.Usage,
        else => try std.fmt.parseInt(T, s, 10),
    });
    return out.items;
}

fn loadData(init: std.process.Init, snap: []const u8) !rows.Data {
    var legendaries = try rows.loadLegendaries(init.gpa, init.io, snap);
    defer legendaries.deinit(init.gpa);
    return rows.load(init.gpa, snap, &legendaries);
}

/// The snapshot salt: SALT_FILE or ~/.config/meiolol/snap-salt (docs/data-safety.md);
/// null after logging when it is not 32 bytes
fn readSalt(init: std.process.Init, arena: std.mem.Allocator, path: ?[]const u8) !?*const anonymise.Salt {
    const salt_path = path orelse try std.fs.path.join(arena, &.{
        init.environ_map.get("HOME") orelse return error.NoHome, ".config/meiolol/snap-salt",
    });
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, salt_path, arena, .limited(64));
    if (bytes.len != 32) {
        std.log.err("{s}: want 32 bytes, found {d}", .{ salt_path, bytes.len });
        return null;
    }
    return bytes[0..32];
}
