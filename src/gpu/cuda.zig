//! CUDA driver API, loaded from libcuda.so.1 at run time: no toolkit needed to build or
//! run (WSL ships the driver as /usr/lib/wsl/lib/libcuda.so.1)

const std = @import("std");

pub const Result = c_int;
pub const Device = c_int;
pub const Context = ?*anyopaque;
pub const Module = ?*anyopaque;
pub const Function = ?*anyopaque;
pub const DevicePtr = u64;

pub const Api = struct {
    cuInit: *const fn (c_uint) callconv(.c) Result,
    cuDeviceGet: *const fn (*Device, c_int) callconv(.c) Result,
    cuDeviceGetName: *const fn ([*]u8, c_int, Device) callconv(.c) Result,
    cuDeviceTotalMem_v2: *const fn (*usize, Device) callconv(.c) Result,
    cuDevicePrimaryCtxRetain: *const fn (*Context, Device) callconv(.c) Result,
    cuCtxSetCurrent: *const fn (Context) callconv(.c) Result,
    cuCtxSynchronize: *const fn () callconv(.c) Result,
    cuModuleLoadData: *const fn (*Module, *const anyopaque) callconv(.c) Result,
    cuModuleGetFunction: *const fn (*Function, Module, [*:0]const u8) callconv(.c) Result,
    cuMemAlloc_v2: *const fn (*DevicePtr, usize) callconv(.c) Result,
    cuMemFree_v2: *const fn (DevicePtr) callconv(.c) Result,
    cuMemcpyHtoD_v2: *const fn (DevicePtr, *const anyopaque, usize) callconv(.c) Result,
    cuMemcpyDtoH_v2: *const fn (*anyopaque, DevicePtr, usize) callconv(.c) Result,
    cuLaunchKernel: *const fn (
        Function,
        c_uint,
        c_uint,
        c_uint,
        c_uint,
        c_uint,
        c_uint,
        c_uint,
        ?*anyopaque,
        ?[*]?*anyopaque,
        ?[*]?*anyopaque,
    ) callconv(.c) Result,
    cuGetErrorName: *const fn (Result, *?[*:0]const u8) callconv(.c) Result,

    pub fn load() !Api {
        const h = std.c.dlopen("libcuda.so.1", .{ .LAZY = true }) orelse return error.NoLibcuda;
        var api: Api = undefined;
        inline for (comptime std.meta.fieldNames(Api)) |name| {
            const p = std.c.dlsym(h, name) orelse return error.MissingCudaSymbol;
            @field(api, name) = @ptrCast(@alignCast(p));
        }
        return api;
    }

    pub fn check(api: *const Api, r: Result) !void {
        if (r == 0) return;
        var name: ?[*:0]const u8 = null;
        _ = api.cuGetErrorName(r, &name);
        std.log.err("cuda: {s} ({d})", .{ if (name) |n| std.mem.span(n) else "?", r });
        return error.Cuda;
    }
};

/// One device with its primary context current and the embedded kernels loaded
pub const Gpu = struct {
    api: Api,
    device: Device,
    module: Module,

    pub fn init(ptx: [:0]const u8) !Gpu {
        const api = try Api.load();
        try api.check(api.cuInit(0));
        var device: Device = 0;
        try api.check(api.cuDeviceGet(&device, 0));
        var ctx: Context = null;
        try api.check(api.cuDevicePrimaryCtxRetain(&ctx, device));
        try api.check(api.cuCtxSetCurrent(ctx));
        var module: Module = null;
        try api.check(api.cuModuleLoadData(&module, ptx.ptr));
        return .{ .api = api, .device = device, .module = module };
    }

    pub fn name(g: *const Gpu, buf: []u8) ![]const u8 {
        try g.api.check(g.api.cuDeviceGetName(buf.ptr, @intCast(buf.len), g.device));
        return std.mem.sliceTo(buf, 0);
    }

    pub fn function(g: *const Gpu, kernel: [:0]const u8) !Function {
        var f: Function = null;
        try g.api.check(g.api.cuModuleGetFunction(&f, g.module, kernel));
        return f;
    }

    pub fn alloc(g: *const Gpu, comptime T: type, n: usize) !DevicePtr {
        var p: DevicePtr = 0;
        try g.api.check(g.api.cuMemAlloc_v2(&p, n * @sizeOf(T)));
        return p;
    }

    pub fn free(g: *const Gpu, p: DevicePtr) void {
        _ = g.api.cuMemFree_v2(p);
    }

    pub fn upload(g: *const Gpu, comptime T: type, dst: DevicePtr, src: []const T) !void {
        try g.api.check(g.api.cuMemcpyHtoD_v2(dst, src.ptr, src.len * @sizeOf(T)));
    }

    pub fn download(g: *const Gpu, comptime T: type, dst: []T, src: DevicePtr) !void {
        try g.api.check(g.api.cuMemcpyDtoH_v2(dst.ptr, src, dst.len * @sizeOf(T)));
    }

    /// 1-D launch over n threads; args are pointers to each kernel parameter
    pub fn launch(g: *const Gpu, f: Function, n: u32, args: []const ?*anyopaque) !void {
        const block: u32 = 256;
        try g.api.check(g.api.cuLaunchKernel(
            f,
            (n + block - 1) / block,
            1,
            1,
            block,
            1,
            1,
            0,
            null,
            @constCast(args.ptr),
            null,
        ));
    }

    pub fn sync(g: *const Gpu) !void {
        try g.api.check(g.api.cuCtxSynchronize());
    }
};
