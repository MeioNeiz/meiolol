//! meiolol-lab: modelling experiments on the gpu-box (x86_64 Linux, glibc, CUDA through
//! libcuda). `zig build lab` builds it; docs/model.md has the results

const std = @import("std");
const cuda = @import("gpu/cuda.zig");

const ptx: [:0]const u8 = @embedFile("kernels.ptx") ++ "";

const usage =
    \\meiolol-lab COMMAND
    \\  gpu-smoke   add two vectors on the GPU and check against the CPU
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    if (argv.len < 2) {
        std.debug.print("{s}", .{usage});
        return 2;
    }
    if (std.mem.eql(u8, argv[1], "gpu-smoke")) {
        try gpuSmoke(init.gpa);
        return 0;
    }
    std.debug.print("unknown command {s}\n{s}", .{ argv[1], usage });
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
