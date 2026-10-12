//! meiolol-lab: modelling experiments. `zig build lab` builds it for this machine
//! (zig-out/bin) and the gpu-box (zig-out/gpu-box: x86_64 Linux, CUDA through libcuda);
//! docs/model.md has the results

const std = @import("std");
const cuda = @import("gpu/cuda.zig");
const anonymise = @import("lab/anonymise.zig");
const protocol = @import("lab/protocol.zig");
const rows = @import("lab/rows.zig");
const enemy = @import("lab/enemy.zig");
const exp = @import("lab/exp.zig");
const harness = @import("lab/harness.zig");

const ptx: [:0]const u8 = @embedFile("kernels.ptx") ++ "";

const usage =
    \\meiolol-lab COMMAND
    \\  gpu-smoke                       add two vectors on the GPU, check against the CPU
    \\  anonymise SRC DST [SALT_FILE]   copy snapshot SRC to DST with PUUIDs and match ids
    \\                                  hashed (salt: 32 bytes, default
    \\                                  ~/.config/meiolol/snap-salt; docs/data-safety.md)
    \\  split SNAP_DIR                  the shared held-out split (eval's, tested on EUW1):
    \\                                  prints it, writes SNAP_DIR/split.tsv
    \\  rows SNAP_DIR                   load the model rows, print outcome counts and means
    \\  enemy SNAP_DIR [PREDS_DIR]      base, additive and pairwise champion-role models on the
    \\                                  continuous outcomes (lab/enemy.zig); markdown table
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
    if (std.mem.eql(u8, cmd, "split") and argv.len >= 3) {
        var buf: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        try protocol.writeSplit(init.gpa, init.io, argv[2], &stdout.interface);
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
    _ = protocol;
    _ = rows;
    _ = enemy;
    _ = harness;
    _ = exp;
}
