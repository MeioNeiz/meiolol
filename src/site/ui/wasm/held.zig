//! A decoded ui.data answer and the bytes its slices point into, freed when the next
//! lands (the admin page's wasm files)
const std = @import("std");
const ui = @import("ui");

const gpa = std.heap.wasm_allocator;

pub fn Held(comptime T: type) type {
    return struct {
        mem: ?std.heap.ArenaAllocator = null,
        bytes: []u8 = &.{},
        v: T = undefined,

        /// Takes `b`; null (and `b` freed) when it doesn't decode
        pub fn set(s: *@This(), b: []u8) ?*const T {
            var next: std.heap.ArenaAllocator = .init(gpa);
            const v = ui.data.decode(next.allocator(), T, b) catch {
                next.deinit();
                gpa.free(b);
                return null;
            };
            s.drop();
            s.* = .{ .mem = next, .bytes = b, .v = v };
            return &s.v;
        }

        fn drop(s: *@This()) void {
            if (s.mem) |*m| m.deinit();
            if (s.bytes.len > 0) gpa.free(s.bytes);
            s.* = .{};
        }
    };
}
