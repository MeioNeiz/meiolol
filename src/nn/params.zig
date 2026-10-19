//! Named parameters in one flat f32 buffer. Declare each parameter once (shape, init
//! rule, decay, trainable); the store gives it an offset, and the returned handle slices
//! any buffer with the same layout: the values, their gradients, a best-so-far copy.

const std = @import("std");
const optim = @import("optim.zig");

/// How a parameter's values start. Draws come from the generator in declaration order,
/// element by element, so a layout and seed always give the same values.
pub const Init = union(enum) {
    zeros,
    constant: f32,
    /// Uniform on [-bound, bound] as (u * 2 - 1) * bound, u = rnd.float(f32). Bound 0 still
    /// draws, so zeroing a layer keeps the generator's stream where it was.
    uniform: f32,
    /// Normal with this standard deviation, rnd.floatNorm(f32) * sd
    normal: f32,

    /// Kaiming (He) uniform for a ReLU layer: bound sqrt(6 / fan_in)
    pub fn kaiming(fan_in: usize) Init {
        return .{ .uniform = @sqrt(6.0 / @as(f32, @floatFromInt(fan_in))) };
    }
};

pub const Kind = enum { scalar, vector, matrix, table };

/// A parameter's place in the layout. Matrices and embedding tables are row-major: a
/// table's row i is id i's vector.
pub const Param = struct {
    offset: usize,
    rows: usize,
    cols: usize,
    kind: Kind,

    pub fn len(p: Param) usize {
        return p.rows * p.cols;
    }

    /// p's values in buf (any buffer laid out like the store)
    pub fn of(p: Param, buf: anytype) Slice(@TypeOf(buf)) {
        return buf[p.offset..][0..p.len()];
    }

    /// Row i (a table: id i's vector; a vector or scalar: row 0 is all of it)
    pub fn row(p: Param, buf: anytype, i: usize) Slice(@TypeOf(buf)) {
        std.debug.assert(i < p.rows);
        return buf[p.offset + i * p.cols ..][0..p.cols];
    }

    /// Element i of a scalar or vector, element (i / cols, i % cols) of a matrix
    pub fn at(p: Param, buf: anytype, i: usize) Elem(@TypeOf(buf)) {
        std.debug.assert(i < p.len());
        return &buf[p.offset + i];
    }

    /// Index of element i in the flat buffer
    pub fn index(p: Param, i: usize) usize {
        std.debug.assert(i < p.len());
        return p.offset + i;
    }

    fn Slice(comptime B: type) type {
        return if (@typeInfo(B).pointer.attrs.@"const") []const f32 else []f32;
    }

    fn Elem(comptime B: type) type {
        return if (@typeInfo(B).pointer.attrs.@"const") *const f32 else *f32;
    }
};

pub const Options = struct {
    init: Init = .zeros,
    /// Weight decay (or L2 penalty) coefficient, see optim.Adam.Config.decay
    decay: f32 = 0,
    frozen: bool = false,
};

pub const Spec = struct {
    name: []const u8,
    param: Param,
    init: Init,
    decay: f32,
    frozen: bool,
};

/// The layout: parameters in declaration order, laid end to end
pub const Params = struct {
    specs: std.ArrayList(Spec) = .empty,
    len: usize = 0,

    pub const empty: Params = .{};

    pub fn deinit(ps: *Params, gpa: std.mem.Allocator) void {
        ps.specs.deinit(gpa);
        ps.* = undefined;
    }

    /// Declares a parameter of rows x cols; the name is borrowed, not copied
    pub fn add(ps: *Params, gpa: std.mem.Allocator, name: []const u8, kind: Kind, rows: usize, cols: usize, opts: Options) !Param {
        std.debug.assert(ps.find(name) == null);
        switch (kind) {
            .scalar => std.debug.assert(rows == 1 and cols == 1),
            .vector => std.debug.assert(rows == 1),
            .matrix, .table => {},
        }
        const p: Param = .{ .offset = ps.len, .rows = rows, .cols = cols, .kind = kind };
        try ps.specs.append(gpa, .{ .name = name, .param = p, .init = opts.init, .decay = opts.decay, .frozen = opts.frozen });
        ps.len += p.len();
        return p;
    }

    pub fn scalar(ps: *Params, gpa: std.mem.Allocator, name: []const u8, opts: Options) !Param {
        return ps.add(gpa, name, .scalar, 1, 1, opts);
    }

    pub fn vector(ps: *Params, gpa: std.mem.Allocator, name: []const u8, n: usize, opts: Options) !Param {
        return ps.add(gpa, name, .vector, 1, n, opts);
    }

    /// rows x cols, row-major; a dense layer's weights are out x in
    pub fn matrix(ps: *Params, gpa: std.mem.Allocator, name: []const u8, rows: usize, cols: usize, opts: Options) !Param {
        return ps.add(gpa, name, .matrix, rows, cols, opts);
    }

    /// An embedding table: n ids, a dim-wide vector each
    pub fn table(ps: *Params, gpa: std.mem.Allocator, name: []const u8, n: usize, dim: usize, opts: Options) !Param {
        return ps.add(gpa, name, .table, n, dim, opts);
    }

    pub fn find(ps: *const Params, name: []const u8) ?Param {
        for (ps.specs.items) |s| if (std.mem.eql(u8, s.name, name)) return s.param;
        return null;
    }

    /// A zeroed buffer for the layout (values, gradients, ...); caller frees
    pub fn alloc(ps: *const Params, gpa: std.mem.Allocator) ![]f32 {
        const buf = try gpa.alloc(f32, ps.len);
        @memset(buf, 0);
        return buf;
    }

    /// Fills buf by each parameter's init rule, in declaration order
    pub fn initValues(ps: *const Params, buf: []f32, rnd: std.Random) void {
        std.debug.assert(buf.len == ps.len);
        for (ps.specs.items) |s| {
            const v = s.param.of(buf);
            switch (s.init) {
                .zeros => @memset(v, 0),
                .constant => |c| @memset(v, c),
                .uniform => |b| for (v) |*x| {
                    x.* = (rnd.float(f32) * 2 - 1) * b;
                },
                .normal => |sd| for (v) |*x| {
                    x.* = rnd.floatNorm(f32) * sd;
                },
            }
        }
    }

    /// The optimiser's segments, one per parameter (caller frees)
    pub fn segments(ps: *const Params, gpa: std.mem.Allocator) ![]optim.Segment {
        const out = try gpa.alloc(optim.Segment, ps.specs.items.len);
        for (out, ps.specs.items) |*o, s| o.* = .{ .len = s.param.len(), .decay = s.decay, .frozen = s.frozen };
        return out;
    }
};

const testing = std.testing;

test "params: end to end in declaration order, handles slice any same-layout buffer" {
    const gpa = testing.allocator;
    var ps: Params = .empty;
    defer ps.deinit(gpa);
    const c = try ps.vector(gpa, "c", 3, .{});
    const a = try ps.scalar(gpa, "a", .{ .init = .{ .constant = 1 } });
    const e = try ps.table(gpa, "e", 4, 2, .{ .init = .{ .uniform = 0.1 }, .decay = 0.01 });
    const w = try ps.matrix(gpa, "w", 2, 8, .{ .init = .kaiming(8), .decay = 0.1, .frozen = true });
    try testing.expectEqual(@as(usize, 3 + 1 + 8 + 16), ps.len);
    try testing.expectEqual(@as(usize, 4), e.offset);
    try testing.expectEqual(@as(usize, 12), w.offset);
    try testing.expectEqual(e, ps.find("e").?);
    try testing.expectEqual(@as(?Param, null), ps.find("nope"));

    const p = try ps.alloc(gpa);
    defer gpa.free(p);
    var rng: std.Random.DefaultPrng = .init(7);
    ps.initValues(p, rng.random());
    for (c.of(p)) |x| try testing.expectEqual(@as(f32, 0), x);
    try testing.expectEqual(@as(f32, 1), a.at(p, 0).*);
    for (e.of(p)) |x| try testing.expect(@abs(x) <= 0.1 and x != 0);
    const bound = @sqrt(6.0 / 8.0);
    for (w.of(p)) |x| try testing.expect(@abs(x) <= bound);
    try testing.expectEqual(&p[4 + 2 * 3], &e.row(p, 3)[0]);
    const cp: []const f32 = p;
    try testing.expectEqual(@as(usize, 8), w.row(cp, 1).len);
    try testing.expectEqual(@as(usize, 12 + 9), w.index(9));

    const segs = try ps.segments(gpa);
    defer gpa.free(segs);
    try testing.expectEqual(@as(usize, 4), segs.len);
    try testing.expectEqual(optim.Segment{ .len = 8, .decay = 0.01 }, segs[2]);
    try testing.expect(segs[3].frozen);
}

test "params: init draws in declaration order, bound 0 still draws" {
    const gpa = testing.allocator;
    var a: Params = .empty;
    defer a.deinit(gpa);
    _ = try a.vector(gpa, "x", 5, .{ .init = .{ .uniform = 0 } });
    const ya = try a.vector(gpa, "y", 3, .{ .init = .{ .normal = 1 } });
    var b: Params = .empty;
    defer b.deinit(gpa);
    _ = try b.vector(gpa, "x", 5, .{ .init = .{ .uniform = 2 } });
    const yb = try b.vector(gpa, "y", 3, .{ .init = .{ .normal = 1 } });
    var pa: [8]f32 = undefined;
    var pb: [8]f32 = undefined;
    var ra: std.Random.DefaultPrng = .init(1);
    var rb: std.Random.DefaultPrng = .init(1);
    a.initValues(&pa, ra.random());
    b.initValues(&pb, rb.random());
    for (pa[0..5]) |x| try testing.expectEqual(@as(f32, 0), @abs(x));
    try testing.expectEqualSlices(f32, ya.of(@as([]const f32, &pa)), yb.of(@as([]const f32, &pb)));
}
