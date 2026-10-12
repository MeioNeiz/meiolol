//! meiolol-lab: modelling experiments. `zig build lab` builds it for this machine
//! (zig-out/bin) and the gpu-box (zig-out/gpu-box: x86_64 Linux, CUDA through libcuda);
//! docs/model.md has the results

const std = @import("std");
const cuda = @import("gpu/cuda.zig");
const anonymise = @import("lab/anonymise.zig");
const archive = @import("lab/archive.zig");
const protocol = @import("lab/protocol.zig");
const rows = @import("lab/rows.zig");
const enemy = @import("lab/enemy.zig");
const pairs = @import("lab/pairs.zig");
const lanebuckets = @import("lab/lanebuckets.zig");
const exp = @import("lab/exp.zig");
const harness = @import("lab/harness.zig");

const ptx: [:0]const u8 = @embedFile("kernels.ptx") ++ "";

const usage =
    \\meiolol-lab COMMAND
    \\  gpu-smoke                       add two vectors on the GPU, check against the CPU
    \\  anonymise SRC DST [SALT_FILE]   copy snapshot SRC to DST with PUUIDs and match ids
    \\                                  hashed (salt: 32 bytes, default
    \\                                  ~/.config/meiolol/snap-salt; docs/data-safety.md)
    \\  archive EXPORT ARCHIVE [SALT_FILE] [FORGOTTEN]  pseudonymise one raw export from
    \\                                  the box into ARCHIVE (lab/archive.zig; zstd on PATH)
    \\  archive-forget ARCHIVE FORGOTTEN [SALT_FILE]  drop archived documents naming a
    \\                                  forgotten PUUID (plain, one per line)
    \\  archive-age ARCHIVE [DAYS]      blank hashed PUUIDs in days older than DAYS (730)
    \\  split SNAP_DIR                  the shared held-out split (eval's, tested on EUW1):
    \\                                  prints it, writes SNAP_DIR/split.tsv
    \\  rows SNAP_DIR                   load the model rows, print outcome counts and means
    \\  enemy SNAP_DIR [PREDS_DIR]      base, additive and pairwise champion-role models on the
    \\                                  continuous outcomes (lab/enemy.zig); markdown table
    \\  pairs BASE REF [PREDS...]       paired MSE gains of prediction TSVs on shared rows,
    \\                                  % of BASE's MSE, intervals vs REF clustered by game
    \\  lanebuckets SNAP BASE A B       A's gain over B by lane pair train games (lab/lanebuckets.zig)
    \\
++ exp.usage;

pub fn main(init: std.process.Init) !u8 {
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
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
        const salt_path = if (argv.len >= 5) argv[4] else try std.fs.path.join(arena, &.{
            init.environ_map.get("HOME") orelse return error.NoHome, ".config/meiolol/snap-salt",
        });
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, salt_path, arena, .limited(64));
        if (bytes.len != 32) {
            std.log.err("{s}: want 32 bytes, found {d}", .{ salt_path, bytes.len });
            return 1;
        }
        try anonymise.run(init.gpa, init.io, argv[2], argv[3], bytes[0..32]);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "archive") and argv.len >= 4) {
        const salt = try readSalt(init, arena, if (argv.len >= 5) argv[4] else null) orelse return 1;
        const n = try archive.run(init.gpa, init.io, argv[2], argv[3], salt, if (argv.len >= 6) argv[5] else null);
        std.log.info("archived {s}: {d} summaries, {d} timelines, {d} mastery, {d} forgotten left out", .{
            argv[2], n.summaries, n.timelines, n.mastery, n.forgotten,
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
    if (std.mem.eql(u8, cmd, "split") and argv.len >= 3) {
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try protocol.writeSplit(init.gpa, init.io, argv[2], &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    if (std.mem.eql(u8, cmd, "lanebuckets") and argv.len >= 6) {
        var legendaries = try rows.loadLegendaries(init.gpa, init.io, argv[2]);
        defer legendaries.deinit(init.gpa);
        var data = try rows.load(init.gpa, argv[2], &legendaries);
        defer data.deinit();
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try lanebuckets.run(init.gpa, init.io, &data, argv[3], argv[4], argv[5], &stdout.interface);
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
    if (std.mem.eql(u8, cmd, "enemy") and argv.len >= 3) {
        var legendaries = try rows.loadLegendaries(init.gpa, init.io, argv[2]);
        defer legendaries.deinit(init.gpa);
        var data = try rows.load(init.gpa, argv[2], &legendaries);
        defer data.deinit();
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try rows.summary(&data, &stdout.interface);
        try enemy.run(init.gpa, init.io, &data, .{ .preds_dir = if (argv.len >= 4) argv[3] else null }, &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    if (std.mem.eql(u8, cmd, "exp")) {
        return exp.main(init.gpa, arena, init.io, init.environ_map.get("HOME"), argv[2..]);
    }
    if (std.mem.eql(u8, cmd, "rows") and argv.len >= 3) {
        var legendaries = try rows.loadLegendaries(init.gpa, init.io, argv[2]);
        defer legendaries.deinit(init.gpa);
        var data = try rows.load(init.gpa, argv[2], &legendaries);
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
    _ = anonymise;
    _ = archive;
    _ = protocol;
    _ = rows;
    _ = enemy;
    _ = pairs;
    _ = lanebuckets;
    _ = harness;
    _ = exp;
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
