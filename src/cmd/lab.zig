//! `meiolol lab-place`, `lab-sweep`: deploy/lab-run.sh's and lab-sweep.sh's decisions
//! (src/labtools). They take no --data and touch no data directory

const std = @import("std");
const labtools = @import("../labtools/root.zig");
const Cmd = @import("../main.zig").Cmd;

pub const usage_lab_place = labtools.place.usage;
pub const usage_lab_sweep = labtools.sweep.usage;

pub fn cmdLabPlace(c: *Cmd) !u8 {
    var s: Stdio = undefined;
    s.init(c.init.io);
    // Perl's truth, as lab-place.pl read it: LAB_AUTO_MAC=1 lets auto use the Mac again
    const auto_mac = labtools.perl.truthy(c.init.environ_map.get("LAB_AUTO_MAC") orelse "");
    const code = try labtools.place.main(c.arena, c.args, &s.in.interface, auto_mac, &s.out.interface, &s.err.interface);
    try s.flush();
    return code;
}

pub fn cmdLabSweep(c: *Cmd) !u8 {
    var s: Stdio = undefined;
    s.init(c.init.io);
    const code = try labtools.sweep.main(c.arena, c.init.io, c.args, &s.in.interface, &s.out.interface, &s.err.interface);
    try s.flush();
    return code;
}

const Stdio = struct {
    in_buf: [64 * 1024]u8,
    out_buf: [64 * 1024]u8,
    err_buf: [4096]u8,
    in: std.Io.File.Reader,
    out: std.Io.File.Writer,
    err: std.Io.File.Writer,

    fn init(s: *Stdio, io: std.Io) void {
        s.in = std.Io.File.stdin().reader(io, &s.in_buf);
        s.out = std.Io.File.stdout().writer(io, &s.out_buf);
        s.err = std.Io.File.stderr().writer(io, &s.err_buf);
    }

    fn flush(s: *Stdio) !void {
        try s.out.interface.flush();
        try s.err.interface.flush();
    }
};
