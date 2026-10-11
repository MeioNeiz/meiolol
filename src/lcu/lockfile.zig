//! Finding the League Client's local API port and password.

const std = @import("std");
const builtin = @import("builtin");

pub const Credentials = struct {
    port: u16,
    password: []const u8,
    /// From the lockfile; the process list does not give it
    pid: ?u32 = null,
};

pub const default_paths: []const []const u8 = switch (builtin.os.tag) {
    .windows => &.{"C:\\Riot Games\\League of Legends\\lockfile"},
    .macos => &.{"/Applications/League of Legends.app/Contents/LoL/lockfile"},
    else => &.{},
};

/// `LeagueClient:PID:PORT:PASSWORD:https`. The password borrows from `content`.
pub fn parse(content: []const u8) !Credentials {
    var it = std.mem.splitScalar(u8, std.mem.trim(u8, content, " \t\r\n"), ':');
    _ = it.next() orelse return error.BadLockfile;
    const pid = it.next() orelse return error.BadLockfile;
    const port = it.next() orelse return error.BadLockfile;
    const password = it.next() orelse return error.BadLockfile;
    if (password.len == 0) return error.BadLockfile;
    return .{
        .port = std.fmt.parseInt(u16, port, 10) catch return error.BadLockfile,
        .password = password,
        .pid = std.fmt.parseInt(u32, pid, 10) catch null,
    };
}

/// Finds `--app-port=` and `--remoting-auth-token=` in LeagueClientUx's command line
/// (one process per line, arguments possibly quoted). Borrows from `text`.
pub fn parseCommandLine(text: []const u8) ?Credentials {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "LeagueClientUx") == null) continue;
        const port = argValue(line, "--app-port=") orelse continue;
        const token = argValue(line, "--remoting-auth-token=") orelse continue;
        if (token.len == 0) continue;
        return .{
            .port = std.fmt.parseInt(u16, port, 10) catch continue,
            .password = token,
        };
    }
    return null;
}

fn argValue(line: []const u8, key: []const u8) ?[]const u8 {
    const at = std.mem.indexOf(u8, line, key) orelse return null;
    const rest = line[at + key.len ..];
    const end = std.mem.indexOfAny(u8, rest, "\" \t\r") orelse rest.len;
    return rest[0..end];
}

pub const Source = enum { override, lockfile, process_list };

pub const Found = struct {
    credentials: Credentials,
    source: Source,
    /// The lockfile read, when there was one
    path: ?[]const u8 = null,
};

/// `override` (from --lockfile or MEIOLOL_LOCKFILE) wins; else the default install
/// path; else the running client's command line. Strings are allocated in `arena`.
pub fn discover(arena: std.mem.Allocator, io: std.Io, override: ?[]const u8) !Found {
    if (override) |path| {
        const content = readSmall(arena, io, path) catch |err| switch (err) {
            error.FileNotFound => return error.ClientNotRunning,
            else => return err,
        };
        return .{ .credentials = try parse(content), .source = .override, .path = path };
    }
    for (default_paths) |path| {
        const content = readSmall(arena, io, path) catch continue;
        const creds = parse(content) catch continue;
        return .{ .credentials = creds, .source = .lockfile, .path = path };
    }
    const listing = processList(arena, io) catch return error.ClientNotRunning;
    const creds = parseCommandLine(listing) orelse return error.ClientNotRunning;
    return .{ .credentials = creds, .source = .process_list };
}

fn readSmall(arena: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(4096));
}

/// Command lines of running processes, for parseCommandLine
pub fn processList(arena: std.mem.Allocator, io: std.Io) ![]const u8 {
    const argv: []const []const u8 = switch (builtin.os.tag) {
        // wmic is gone from current Windows; CIM gives the full command line
        .windows => &.{
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            // Single quotes only: double quotes would need escaping through CreateProcess
            "Get-CimInstance Win32_Process -Filter 'name=''LeagueClientUx.exe''' | " ++
                "Select-Object -ExpandProperty CommandLine",
        },
        else => &.{ "ps", "-A", "-o", "args" },
    };
    const result = try std.process.run(arena, io, .{
        .argv = argv,
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(64 * 1024),
    });
    return result.stdout;
}

const testing = std.testing;

test "parse lockfile" {
    const c = try parse("LeagueClient:21876:54321:AbC-dEf_123:https\n");
    try testing.expectEqual(54321, c.port);
    try testing.expectEqualStrings("AbC-dEf_123", c.password);
    try testing.expectEqual(21876, c.pid.?);
    try testing.expectError(error.BadLockfile, parse(""));
    try testing.expectError(error.BadLockfile, parse("LeagueClient:1:notaport:pw:https"));
    try testing.expectError(error.BadLockfile, parse("LeagueClient:1:123"));
}

test "parse command line" {
    const app = "/Applications/League of Legends.app/Contents/LoL/";
    const ps = "/sbin/launchd\n" ++
        app ++ "LeagueClient.app/Contents/MacOS/LeagueClient --app-port=1\n" ++
        app ++ "LeagueClient.app/Contents/Frameworks/" ++
        "LeagueClientUx.app/Contents/MacOS/LeagueClientUx " ++
        "--riotclient-auth-token=x --app-port=60123 " ++
        "--remoting-auth-token=s3cr3t-Tok --locale=en_GB\n";
    const c = parseCommandLine(ps).?;
    try testing.expectEqual(60123, c.port);
    try testing.expectEqualStrings("s3cr3t-Tok", c.password);

    const win = "\"C:/Riot Games/League of Legends/LeagueClientUx.exe\" " ++
        "\"--riotclient-auth-token=x\" \"--app-port=50999\" " ++
        "\"--remoting-auth-token=tok\" \"--app-pid=1\"";
    const w = parseCommandLine(win).?;
    try testing.expectEqual(50999, w.port);
    try testing.expectEqualStrings("tok", w.password);
    const no_token = parseCommandLine("LeagueClientUx --app-port=1");
    try testing.expectEqual(@as(?Credentials, null), no_token);
}
