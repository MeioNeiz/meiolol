//! A dvui backend that draws into memory: no OS window, no GPU. `zig build
//! desktop-shot` renders the window's states to PNG with it, so the UI can be looked
//! at and checked on any machine. dvui draws everything as textured triangles with
//! premultiplied alpha and does its own edge feathering, so a plain rasteriser with
//! "over" blending gives the same picture as dx11, give or take font hinting.

const std = @import("std");
const dvui = @import("dvui");

allocator: std.mem.Allocator,
arena: std.mem.Allocator = undefined,
size: dvui.Size.Natural,
size_pixels: dvui.Size.Physical,
scale: f32,
/// The window, premultiplied RGBA
screen: Image,
/// Where drawing goes: the screen or a texture target
target: Image,
time: i128 = 0,

pub const kind: dvui.enums.Backend = .custom;

const Raster = @This();
pub const Context = *Raster;

const Image = struct {
    pixels: []u8,
    width: u32,
    height: u32,
};

pub const InitOptions = struct {
    allocator: std.mem.Allocator,
    /// Logical size; pixels are this times `scale` (1.5 for Windows' 150%)
    size: dvui.Size.Natural,
    scale: f32 = 1,
};

pub fn init(opts: InitOptions) !Raster {
    const w: u32 = @round(opts.size.w * opts.scale);
    const h: u32 = @round(opts.size.h * opts.scale);
    const screen: Image = .{ .pixels = try opts.allocator.alloc(u8, w * h * 4), .width = w, .height = h };
    @memset(screen.pixels, 0);
    return .{
        .allocator = opts.allocator,
        .size = opts.size,
        .size_pixels = .{ .w = @floatFromInt(w), .h = @floatFromInt(h) },
        .scale = opts.scale,
        .screen = screen,
        .target = screen,
    };
}

pub fn deinit(self: *Raster) void {
    self.allocator.free(self.screen.pixels);
    self.* = undefined;
}

/// The last frame as PNG
pub fn writePng(self: *Raster, w: *std.Io.Writer) !void {
    try dvui.PNGEncoder.writeWithResolution(w, self.screen.pixels, self.screen.width, self.screen.height, 0);
}

pub fn backend(self: *Raster) dvui.Backend {
    return dvui.Backend.init(self);
}

pub fn nanoTime(self: *Raster) i128 {
    defer self.time += 16 * std.time.ns_per_ms;
    return self.time;
}

pub fn sleep(_: *Raster, _: u64) void {}

pub fn begin(self: *Raster, arena: std.mem.Allocator) !void {
    self.arena = arena;
    @memset(self.screen.pixels, 0);
}

pub fn end(_: *Raster) !void {}

pub fn pixelSize(self: *Raster) dvui.Size.Physical {
    return self.size_pixels;
}

pub fn windowSize(self: *Raster) dvui.Size.Natural {
    return self.size;
}

pub fn contentScale(self: *Raster) f32 {
    return self.scale;
}

const Vec = @Vector(4, f32);

/// Triangles in physical pixels, sampled at pixel centres; top-left fill rule so
/// shared edges are not blended twice
pub fn drawClippedTriangles(
    self: *Raster,
    texture: ?dvui.Texture,
    vtx: []const dvui.Vertex,
    idx: []const dvui.Vertex.Index,
    clipr: ?dvui.Rect.Physical,
) !void {
    const t = self.target;
    var x_lo: f32 = 0;
    var y_lo: f32 = 0;
    var x_hi: f32 = @floatFromInt(t.width);
    var y_hi: f32 = @floatFromInt(t.height);
    if (clipr) |c| {
        x_lo = @max(x_lo, c.x);
        y_lo = @max(y_lo, c.y);
        x_hi = @min(x_hi, c.x + c.w);
        y_hi = @min(y_hi, c.y + c.h);
    }
    var i: usize = 0;
    while (i + 2 < idx.len) : (i += 3) {
        var a = vtx[idx[i]];
        var b = vtx[idx[i + 1]];
        const c = vtx[idx[i + 2]];
        var area = edge(a.pos, b.pos, c.pos);
        if (area == 0) continue;
        if (area < 0) {
            std.mem.swap(dvui.Vertex, &a, &b);
            area = -area;
        }
        const x0: i32 = @floor(@max(x_lo, @min(a.pos.x, b.pos.x, c.pos.x)));
        const y0: i32 = @floor(@max(y_lo, @min(a.pos.y, b.pos.y, c.pos.y)));
        const x1: i32 = @ceil(@min(x_hi, @max(a.pos.x, b.pos.x, c.pos.x)));
        const y1: i32 = @ceil(@min(y_hi, @max(a.pos.y, b.pos.y, c.pos.y)));
        const ca = color(a.col);
        const cb = color(b.col);
        const cc = color(c.col);
        var y = y0;
        while (y < y1) : (y += 1) {
            var x = x0;
            while (x < x1) : (x += 1) {
                const p: dvui.Point.Physical = .{ .x = @as(f32, @floatFromInt(x)) + 0.5, .y = @as(f32, @floatFromInt(y)) + 0.5 };
                const wa = edge(b.pos, c.pos, p);
                const wb = edge(c.pos, a.pos, p);
                const wc = edge(a.pos, b.pos, p);
                if (!inside(wa, b.pos, c.pos) or !inside(wb, c.pos, a.pos) or !inside(wc, a.pos, b.pos)) continue;
                const la = wa / area;
                const lb = wb / area;
                const lc = wc / area;
                var src = ca * @as(Vec, @splat(la)) + cb * @as(Vec, @splat(lb)) + cc * @as(Vec, @splat(lc));
                if (texture) |tex| {
                    const u = a.uv[0] * la + b.uv[0] * lb + c.uv[0] * lc;
                    const v = a.uv[1] * la + b.uv[1] * lb + c.uv[1] * lc;
                    src *= sample(tex, u, v);
                }
                const at = (@as(usize, @intCast(y)) * t.width + @as(usize, @intCast(x))) * 4;
                const dst = t.pixels[at..][0..4];
                const d: Vec = .{ @floatFromInt(dst[0]), @floatFromInt(dst[1]), @floatFromInt(dst[2]), @floatFromInt(dst[3]) };
                const out = src * @as(Vec, @splat(255)) + d * @as(Vec, @splat(1 - src[3]));
                const px: [4]f32 = out;
                for (dst, px) |*o, f| o.* = @round(std.math.clamp(f, 0, 255));
            }
        }
    }
}

/// Twice the signed area of (a, b, p): positive when p is left of a -> b in screen
/// coordinates (y down)
fn edge(a: dvui.Point.Physical, b: dvui.Point.Physical, p: dvui.Point.Physical) f32 {
    return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
}

fn inside(w: f32, a: dvui.Point.Physical, b: dvui.Point.Physical) bool {
    if (w > 0) return true;
    if (w < 0) return false;
    const top = a.y == b.y and b.x < a.x;
    const left = b.y < a.y;
    return top or left;
}

fn color(c: dvui.Color.PMA) Vec {
    const v: Vec = .{ @floatFromInt(c.r), @floatFromInt(c.g), @floatFromInt(c.b), @floatFromInt(c.a) };
    return v / @as(Vec, @splat(255));
}

fn texel(tex: dvui.Texture, x: i64, y: i64) Vec {
    const w: i64 = tex.width;
    const h: i64 = tex.height;
    const cx: usize = @intCast(std.math.clamp(x, 0, w - 1));
    const cy: usize = @intCast(std.math.clamp(y, 0, h - 1));
    const px: [*]const u8 = @ptrCast(tex.ptr);
    const at = (cy * tex.width + cx) * 4;
    return color(.{ .r = px[at], .g = px[at + 1], .b = px[at + 2], .a = px[at + 3] });
}

fn sample(tex: dvui.Texture, u: f32, v: f32) Vec {
    const fx = u * @as(f32, @floatFromInt(tex.width)) - 0.5;
    const fy = v * @as(f32, @floatFromInt(tex.height)) - 0.5;
    if (tex.interpolation == .nearest) {
        return texel(tex, @round(fx), @round(fy));
    }
    const x0 = @floor(fx);
    const y0 = @floor(fy);
    const tx: Vec = @splat(fx - x0);
    const ty: Vec = @splat(fy - y0);
    const ix: i64 = @trunc(x0);
    const iy: i64 = @trunc(y0);
    const one: Vec = @splat(1);
    const top = texel(tex, ix, iy) * (one - tx) + texel(tex, ix + 1, iy) * tx;
    const bottom = texel(tex, ix, iy + 1) * (one - tx) + texel(tex, ix + 1, iy + 1) * tx;
    return top * (one - ty) + bottom * ty;
}

pub fn textureCreate(self: *Raster, pixels: [*]const u8, options: dvui.Texture.CreateOptions) !dvui.Texture {
    const copy = try self.allocator.dupe(u8, pixels[0 .. options.width * options.height * 4]);
    return .{
        .width = options.width,
        .height = options.height,
        .ptr = copy.ptr,
        .format = options.format,
        .interpolation = options.interpolation,
        .wrap_u = options.wrap_u,
        .wrap_v = options.wrap_v,
    };
}

pub fn textureUpdate(_: *Raster, texture: dvui.Texture, pixels: [*]const u8) !void {
    const dst: [*]u8 = @ptrCast(texture.ptr);
    const n = texture.width * texture.height * 4;
    @memcpy(dst[0..n], pixels[0..n]);
}

pub fn textureDestroy(self: *Raster, texture: dvui.Texture) void {
    const ptr: [*]u8 = @ptrCast(texture.ptr);
    self.allocator.free(ptr[0 .. texture.width * texture.height * 4]);
}

pub fn textureCreateTarget(self: *Raster, options: dvui.Texture.CreateOptions) !dvui.TextureTarget {
    const pixels = try self.allocator.alloc(u8, options.width * options.height * 4);
    @memset(pixels, 0);
    return .{
        .ptr = pixels.ptr,
        .width = options.width,
        .height = options.height,
        .format = options.format,
        .interpolation = options.interpolation,
        .wrap_u = options.wrap_u,
        .wrap_v = options.wrap_v,
    };
}

pub fn textureClearTarget(_: *Raster, target: dvui.TextureTarget) void {
    const ptr: [*]u8 = @ptrCast(target.ptr);
    @memset(ptr[0 .. target.width * target.height * 4], 0);
}

pub fn textureReadTarget(_: *Raster, target: dvui.TextureTarget, pixels: [*]u8) !void {
    const ptr: [*]const u8 = @ptrCast(target.ptr);
    const n = target.width * target.height * 4;
    @memcpy(pixels[0..n], ptr[0..n]);
}

pub fn textureDestroyTarget(self: *Raster, target: dvui.TextureTarget) void {
    self.textureDestroy(.cast(target));
}

pub fn textureFromTarget(_: *Raster, target: dvui.TextureTarget) !dvui.Texture {
    return .cast(target);
}

pub fn textureFromTargetTemp(_: *Raster, target: dvui.TextureTarget) !dvui.Texture {
    return .cast(target);
}

pub fn renderTarget(self: *Raster, target: ?dvui.TextureTarget) !void {
    self.target = if (target) |t| .{
        .pixels = @as([*]u8, @ptrCast(t.ptr))[0 .. t.width * t.height * 4],
        .width = t.width,
        .height = t.height,
    } else self.screen;
}

pub fn setCursor(_: *Raster, _: dvui.enums.Cursor) void {}
pub fn textInputRect(_: *Raster, _: ?dvui.Rect.Natural) void {}
pub fn renderPresent(_: *Raster) void {}

pub fn clipboardText(_: *Raster) std.mem.Allocator.Error![]const u8 {
    return "";
}

pub fn clipboardTextSet(_: *Raster, _: []const u8) std.mem.Allocator.Error!void {}

pub fn openURL(_: *Raster, _: []const u8, _: bool) std.mem.Allocator.Error!void {}

pub fn preferredColorScheme(_: *Raster) ?dvui.enums.ColorScheme {
    return .dark;
}

pub fn prefersReducedMotion(_: *Raster) bool {
    return true;
}

pub fn refresh(_: *Raster) void {}
