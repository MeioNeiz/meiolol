//! Finding the League Client's local API port and password.

const std = @import("std");
const builtin = @import("builtin");

pub const Credentials = struct {
    port: u16,
    password: []const u8,
    /// Plain HTTP, no certificate: only a mock client (deploy/mock-cs.sh) through an
    /// override lockfile ending `:http`. The real client always speaks HTTPS
    plain: bool = false,
};

pub const default_paths: []const []const u8 = switch (builtin.target.os.tag) {
    .windows => &.{"C:\\Riot Games\\League of Legends\\lockfile"},
    .macos => &.{"/Applications/League of Legends.app/Contents/LoL/lockfile"},
    else => &.{},
};

/// `LeagueClient:PID:PORT:PASSWORD:https`. The password borrows from `content`.
pub fn parse(content: []const u8) !Credentials {
    var it = std.mem.splitScalar(u8, std.mem.trim(u8, content, " \t\r\n"), ':');
    _ = it.next() orelse return error.BadLockfile;
    _ = it.next() orelse return error.BadLockfile;
    const port = it.next() orelse return error.BadLockfile;
    const password = it.next() orelse return error.BadLockfile;
    if (password.len == 0) return error.BadLockfile;
    const protocol = it.next() orelse "https";
    return .{
        .port = std.fmt.parseInt(u16, port, 10) catch return error.BadLockfile,
        .password = password,
        .plain = std.mem.eql(u8, protocol, "http"),
    };
}

/// Finds `--app-port=` and `--remoting-auth-token=` in LeagueClientUx's command line
/// (one process per line, arguments possibly quoted). Borrows from `text`.
pub fn parseCommandLine(text: []const u8) ?Credentials {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.find(u8, line, "LeagueClientUx") == null) continue;
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
    const at = std.mem.find(u8, line, key) orelse return null;
    const rest = line[at + key.len ..];
    const end = std.mem.findAny(u8, rest, "\" \t\r") orelse rest.len;
    return rest[0..end];
}

/// `override` (from --lockfile or MEIOLOL_LOCKFILE) wins; else the default install
/// path; else the running client's command line. Strings are allocated in `arena`.
pub fn discover(arena: std.mem.Allocator, io: std.Io, override: ?[]const u8) !Credentials {
    if (override) |path| {
        const content = readSmall(arena, io, path) catch |err| switch (err) {
            error.FileNotFound => return error.ClientNotRunning,
            else => return err,
        };
        return parse(content);
    }
    for (default_paths) |path| {
        const content = readSmall(arena, io, path) catch continue;
        const creds = parse(content) catch continue;
        if (!creds.plain) return creds;
    }
    // The process list costs ~1.5 s of CPU on Windows (PowerShell); pollers call this
    // every second while the client is closed
    if (builtin.target.os.tag == .windows and !windowsProcessRunning("LeagueClientUx.exe"))
        return error.ClientNotRunning;
    const listing = processList(arena, io) catch return error.ClientNotRunning;
    return parseCommandLine(listing) orelse error.ClientNotRunning;
}

fn readSmall(arena: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(4096));
}

const ProcessEntry = extern struct {
    size: u32 = @sizeOf(ProcessEntry),
    usage: u32 = 0,
    pid: u32 = 0,
    heap_id: usize = 0,
    module_id: u32 = 0,
    threads: u32 = 0,
    parent_pid: u32 = 0,
    priority: i32 = 0,
    flags: u32 = 0,
    exe: [260]u16 = undefined,
};
extern "kernel32" fn CreateToolhelp32Snapshot(flags: u32, pid: u32) callconv(.winapi) std.os.windows.HANDLE;
extern "kernel32" fn Process32FirstW(snap: std.os.windows.HANDLE, entry: *ProcessEntry) callconv(.winapi) c_int;
extern "kernel32" fn Process32NextW(snap: std.os.windows.HANDLE, entry: *ProcessEntry) callconv(.winapi) c_int;

/// Whether a process with this exe name runs (Toolhelp snapshot, well under a millisecond).
/// True when the snapshot fails, so the caller falls back to the full process list
fn windowsProcessRunning(comptime exe: []const u8) bool {
    const snapshot_process = 2;
    const snap = CreateToolhelp32Snapshot(snapshot_process, 0);
    if (snap == std.os.windows.INVALID_HANDLE_VALUE) return true;
    defer std.os.windows.CloseHandle(snap);
    const want = std.unicode.utf8ToUtf16LeStringLiteral(exe);
    var entry: ProcessEntry = .{};
    var ok = Process32FirstW(snap, &entry);
    while (ok != 0) : (ok = Process32NextW(snap, &entry)) {
        const name = std.mem.sliceTo(&entry.exe, 0);
        if (name.len == want.len and std.ascii.eqlIgnoreCase(
            std.mem.sliceAsBytes(name),
            std.mem.sliceAsBytes(want[0..]),
        )) return true;
    }
    return false;
}

/// Command lines of running processes, for parseCommandLine
pub fn processList(arena: std.mem.Allocator, io: std.Io) ![]const u8 {
    const argv: []const []const u8 = switch (builtin.target.os.tag) {
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
    try testing.expect(!c.plain);
    try testing.expect((try parse("LeagueClient:1:2:pw:http")).plain);
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
