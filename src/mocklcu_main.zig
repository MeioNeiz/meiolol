//! `meiolol-mock-lcu`: a mock League client playing a scenario (lcu/mock.zig), for
//! trying `meiolol-app watch` and the desktop window without League. deploy/mock-cs.sh
//! runs both.

const std = @import("std");
const mock = @import("lcu/mock.zig");
const Io = std.Io;

const usage =
    \\usage: meiolol-mock-lcu SCENARIO [options]
    \\  SCENARIO          testdata/lcu/scenarios/NAME.json (champions.json beside it)
    \\  --speed X         play X times faster (default 1)
    \\  --manual          Enter plays the next step, ignoring waits
    \\  --loop            start over after the last step
    \\  --lockfile PATH   where to write the lockfile (default zig-out/mock-lcu/lockfile)
    \\  --port N          LCU port (default any free one)
    \\  --live-port N     Live Client Data port (default 2999, as a real game)
    \\  --hold SECS       after the last step, serve SECS more then exit (default: until
    \\                    Ctrl+C)
    \\
;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    var scenario_path: ?[]const u8 = null;
    var speed: f64 = 1;
    var manual = false;
    var loop = false;
    var lock_path: []const u8 = "zig-out/mock-lcu/lockfile";
    var port: u16 = 0;
    var live_port: u16 = 2999;
    var hold: ?f64 = null;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "--manual")) {
            manual = true;
        } else if (std.mem.eql(u8, a, "--loop")) {
            loop = true;
        } else if (std.mem.startsWith(u8, a, "--")) {
            if (i + 1 >= argv.len) fail("{s} needs a value", .{a});
            i += 1;
            const v = argv[i];
            if (std.mem.eql(u8, a, "--speed")) {
                speed = std.fmt.parseFloat(f64, v) catch fail("--speed: not a number", .{});
                if (speed <= 0) fail("--speed must be > 0", .{});
            } else if (std.mem.eql(u8, a, "--lockfile")) {
                lock_path = v;
            } else if (std.mem.eql(u8, a, "--port")) {
                port = std.fmt.parseInt(u16, v, 10) catch fail("--port: not a port", .{});
            } else if (std.mem.eql(u8, a, "--hold")) {
                hold = std.fmt.parseFloat(f64, v) catch fail("--hold: not a number", .{});
            } else if (std.mem.eql(u8, a, "--live-port")) {
                live_port = std.fmt.parseInt(u16, v, 10) catch fail("--live-port: not a port", .{});
            } else fail("unknown option {s}", .{a});
        } else scenario_path = a;
    }
    const path = scenario_path orelse fail("", .{});
    const scenario = mock.Scenario.load(arena, io, path) catch |err| fail("{s}: {t}", .{ path, err });
    var m: mock.Mock = .{ .gpa = init.gpa, .io = io, .scenario = &scenario };

    const lcu_addr = try Io.net.IpAddress.parse("127.0.0.1", port);
    var lcu_server = lcu_addr.listen(io, .{ .reuse_address = true }) catch |err| fail("LCU port {d}: {t}", .{ port, err });
    defer lcu_server.deinit(io);
    const live_addr = try Io.net.IpAddress.parse("127.0.0.1", live_port);
    var live_server = live_addr.listen(io, .{ .reuse_address = true }) catch |err| fail("live port {d}: {t}", .{ live_port, err });
    defer live_server.deinit(io);
    var lcu_task = try io.concurrent(mock.Mock.serveLcu, .{ &m, &lcu_server });
    defer lcu_task.cancel(io);
    var live_task = try io.concurrent(mock.Mock.serveLive, .{ &m, &live_server });
    defer live_task.cancel(io);

    var buf: [128]u8 = undefined;
    const lock = try m.lockfile(&buf, lcu_server.socket.address.getPort());
    const cwd = Io.Dir.cwd();
    if (std.fs.path.dirname(lock_path)) |d| try cwd.createDirPath(io, d);
    try cwd.writeFile(io, .{ .sub_path = lock_path, .data = lock });
    defer cwd.deleteFile(io, lock_path) catch {};
    std.debug.print("mock League client: {s}, LCU on 127.0.0.1:{d}, Live Client Data on " ++
        "127.0.0.1:{d}\nlockfile {s} (MEIOLOL_LOCKFILE={s})\n", .{
        scenario.name,
        lcu_server.socket.address.getPort(),
        live_port,
        lock_path,
        lock_path,
    });

    var stdin_buf: [256]u8 = undefined;
    var stdin = Io.File.stdin().reader(io, &stdin_buf);
    while (true) {
        while (true) {
            const n = m.next;
            if (n >= scenario.steps.len) break;
            const step = scenario.steps[n].object;
            if (manual) {
                std.debug.print("Enter: step {d}/{d}", .{ n + 1, scenario.steps.len });
                _ = stdin.interface.takeDelimiter('\n') catch {};
            } else if (step.get("wait")) |w| {
                const secs: f64 = switch (w) {
                    .integer => |x| @floatFromInt(x),
                    .float => |x| x,
                    else => 0,
                };
                const ns: i96 = @trunc(secs / speed * std.time.ns_per_s);
                try io.sleep(.fromNanoseconds(ns), .awake);
            }
            _ = try m.advance();
            const st = m.state;
            const note = if (step.get("note")) |v| v.string else "";
            std.debug.print("[{d}/{d}] {s}{s}{s}{s}{s}\n", .{
                n + 1,
                scenario.steps.len,
                st.phase,
                if (std.mem.eql(u8, st.phase, "ChampSelect") and st.timer.len > 0) " " else "",
                if (std.mem.eql(u8, st.phase, "ChampSelect")) st.timer else "",
                if (note.len > 0) ": " else "",
                note,
            });
        }
        if (!loop) break;
        m.restart();
        std.debug.print("starting over\n", .{});
    }
    if (hold) |secs| {
        std.debug.print("scenario done; serving {d} s more\n", .{secs});
        try io.sleep(.fromNanoseconds(@trunc(secs * std.time.ns_per_s)), .awake);
        return;
    }
    std.debug.print("scenario done; still serving, Ctrl+C to stop\n", .{});
    while (true) try io.sleep(.fromSeconds(3600), .awake);
}

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    if (fmt.len > 0) std.debug.print("error: " ++ fmt ++ "\n", args) else std.debug.print(usage, .{});
    std.process.exit(1);
}
