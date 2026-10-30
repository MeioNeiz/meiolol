//! Build tool: `compileerrors EXPECT... -- ZIG TEST ARGS...` compiles code that must not
//! compile (src/tpl/compile_errors.zig, src/site/ui/compile_errors.zig) and checks that
//! each EXPECT ends one of its errors, one error each, in any order. All cases in one
//! compile: Zig reports every failing instantiation, and caches no failed compile, so a
//! compile per case reran all 47 on every `zig build test`
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    const sep = for (args, 0..) |arg, i| (if (std.mem.eql(u8, arg, "--")) break i) else return error.Usage;
    // Longest first: an expect that ends another's would otherwise take that one's error
    const expects = try a.alloc([]const u8, sep - 1);
    for (expects, args[1..sep]) |*e, arg| e.* = arg;
    std.mem.sort([]const u8, expects, {}, struct {
        fn longer(_: void, x: []const u8, y: []const u8) bool {
            return x.len > y.len;
        }
    }.longer);
    const r = try std.process.run(a, io, .{ .argv = args[sep + 1 ..], .stderr_limit = .limited(4 << 20) });

    var errors: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, r.stderr, '\n');
    while (lines.next()) |line| {
        if (std.mem.find(u8, line, ": error: ")) |at| try errors.append(a, line[at + ": error: ".len ..]);
    }
    const used = try a.alloc(bool, errors.items.len);
    @memset(used, false);
    var missing: usize = 0;
    for (expects) |want| {
        for (errors.items, used) |got, *u| {
            if (!u.* and std.mem.endsWith(u8, got, want)) {
                u.* = true;
                break;
            }
        } else {
            std.debug.print("no error ending: {s}\n", .{want});
            missing += 1;
        }
    }
    var extra: usize = 0;
    for (errors.items, used) |got, u| if (!u) {
        std.debug.print("unexpected error: {s}\n", .{got});
        extra += 1;
    };
    if (r.term.success()) std.debug.print("compiled, expected {d} errors\n", .{expects.len});
    if (missing + extra == 0 and !r.term.success()) return;
    std.debug.print("\n{s}", .{r.stderr});
    std.process.exit(1);
}
