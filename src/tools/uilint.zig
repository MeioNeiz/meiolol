//! uilint (src/site/ui/uilint.zig): the UI guards against uilint-debt.txt, and the
//! components register. Unlike the other tools here it imports ui: the guards read each
//! component's CSS and gallery at comptime.
//!
//! usage: uilint [--write [--grow]]
//! --write rewrites docs/plan/ui/components.md and lowers the debt file's counts to
//! today's; --grow also raises and adds lines (needs Jacob's ok)
const std = @import("std");
const Io = std.Io;
const ui = @import("ui");
const lint = ui.uilint;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(a);
    var write = false;
    var grow = false;
    for (argv[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--write")) {
            write = true;
        } else if (std.mem.eql(u8, arg, "--grow")) {
            grow = true;
        } else {
            std.debug.print("usage: uilint [--write [--grow]]\n", .{});
            std.process.exit(2);
        }
    }
    const old_text = Io.Dir.cwd().readFileAlloc(io, lint.debt_path, a, .limited(1 << 20)) catch "";
    const debt = try lint.parse(a, old_text);
    const have = try lint.counts(a, ui.all ++ ui.pages);
    const reg = try lint.registerText(a, ui.all, ui.pages, ui.components);

    var out: Io.Writer.Allocating = .init(a);
    var ok = try lint.compare(have, debt, &out.writer);
    const old_reg = Io.Dir.cwd().readFileAlloc(io, lint.register_path, a, .limited(4 << 20)) catch "";
    if (!std.mem.eql(u8, old_reg, reg)) {
        try out.writer.writeAll(lint.register_path ++ " is stale\n");
        ok = false;
    }
    if (write) {
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = lint.register_path, .data = reg });
        const new_text = try lint.debtText(a, have, debt, grow);
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = lint.debt_path, .data = new_text });
        out.clearRetainingCapacity();
        ok = try lint.compare(have, try lint.parse(a, new_text), &out.writer);
    }
    std.debug.print("{s}", .{out.written()});
    if (!ok) std.process.exit(1);
}
