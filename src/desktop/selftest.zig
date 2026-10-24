//! `meiolol-desktop --self-test`: a start short of the window and the client. The data
//! files load and parse as the poller's would, and a lane card builds for each role.
//! Exit code 0, else 1 with the error on the console. The release's Windows smoke start
//! (deploy/desktop-smoke.sh): the exe runs on Windows at all and reads today's files

const std = @import("std");
const core = @import("core");
const lanecard = @import("../lanecard.zig");
const datafiles = @import("../datafiles.zig");

pub fn run(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const cwd = std.Io.Dir.cwd();
    const limit: std.Io.Limit = .limited(1 << 30);
    const stats_path = try datafiles.stats(arena, io) orelse return error.NoStatsFile;
    const stats: core.Stats = try .parse(arena, try cwd.readFileAlloc(io, stats_path, arena, limit));
    const curves_path = try datafiles.curves(arena, io) orelse return error.NoCurvesFile;
    const curves: core.curvesfile.Curves = try .parse(arena, try cwd.readFileAlloc(io, curves_path, arena, limit));
    var options: usize = 0;
    for (core.Role.all) |role| {
        const card = try lanecard.build(arena, .{ .stats = &stats, .curves = &curves, .role = role });
        if (card.options.len == 0) return error.NoOptions;
        options += card.options.len;
    }
    std.log.info("self-test: {s}, {s}: 5 lane cards, {d} options", .{ stats_path, curves_path, options });
}
