//! Device code: built for nvptx64-cuda to PTX by build.zig and embedded in meiolol-lab

fn special(comptime reg: []const u8) u32 {
    return asm ("mov.u32 %[r], %" ++ reg ++ ";"
        : [r] "=r" (-> u32),
    );
}

fn globalId() u32 {
    return special("ctaid.x") * special("ntid.x") + special("tid.x");
}

export fn vadd(a: [*]const f32, b: [*]const f32, c: [*]f32, n: u32) callconv(.kernel) void {
    const i = globalId();
    if (i < n) c[i] = a[i] + b[i];
}
