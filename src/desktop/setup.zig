//! The Windows side of the per-user install (install.zig): on start, an exe from the
//! download (update.key beside it) installs itself and starts the installed copy; the
//! installed one keeps its Start menu shortcut, which Windows search indexes, and its
//! Apps list entry current. Settings' Uninstall runs `meiolol-desktop.exe --uninstall`
//! (`--quiet` skips its question). The installed app runs once: starting it again shows
//! the open window, and installing a new download closes it first. `--portable` skips all
//! of it.

const std = @import("std");
const Io = std.Io;
const win32 = @import("dvui").backend.win32;
const install = @import("install.zig");
const update = @import("update.zig");

const uninstall_key = win32.L("Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\meiolol");
const shortcut_name = "meiolol.lnk";
/// The window class (desktop_main.zig): FindWindowW finds the open copy by it
pub const window_class = win32.L("meiolol");
const instance_mutex = win32.L("Local\\meiolol-desktop");

pub const Next = enum { run, exit };

pub fn atStart(init: std.process.Init, version: u64) Next {
    const arena = init.arena.allocator();
    const io = init.io;
    const argv = init.minimal.args.toSlice(arena) catch return .run;
    if (hasArg(argv, "--portable")) return .run;
    if (hasArg(argv, "--uninstall")) {
        uninstall(arena, io, hasArg(argv, "--quiet")) catch |err| fail("Couldn't remove meiolol: {t}", .{err});
        return .exit;
    }
    const exe_path = std.process.executablePathAlloc(io, arena) catch return .run;
    const exe_dir = std.fs.path.dirname(exe_path) orelse return .run;
    const target = installDir(arena) catch return .run;
    if (install.samePath(exe_dir, target)) {
        // Held until exit; the second copy finds it taken
        _ = win32.CreateMutexW(null, win32.FALSE, instance_mutex);
        if (win32.GetLastError() == .ERROR_ALREADY_EXISTS) {
            showOpen();
            return .exit;
        }
        register(arena, target, version) catch |err| std.log.warn("install entry: {t}", .{err});
        return .run;
    }
    var from = Io.Dir.cwd().openDir(io, exe_dir, .{ .iterate = true }) catch return .run;
    defer from.close(io);
    if (from.access(io, update.key_file, .{})) |_| {} else |_| return .run;

    installFrom(arena, io, from, std.fs.path.basename(exe_path), target, version) catch |err| {
        fail("Couldn't install meiolol into {s}: {t}. Running it from here instead.", .{ target, err });
        return .run;
    };
    return .exit;
}

fn hasArg(argv: []const [:0]const u8, name: []const u8) bool {
    for (argv[1..]) |a| if (std.mem.eql(u8, a, name)) return true;
    return false;
}

fn installFrom(arena: std.mem.Allocator, io: Io, from: Io.Dir, exe: []const u8, target: []const u8, version: u64) !void {
    closeOpen();
    var to = try Io.Dir.cwd().createDirPathOpen(io, target, .{});
    defer to.close(io);
    try install.copyInto(arena, io, from, exe, to);
    try register(arena, target, version);
    const installed = try std.fs.path.join(arena, &.{ target, update.exe_name });
    try start(arena, installed, target, .{});
}

fn showOpen() void {
    const hwnd = win32.FindWindowW(window_class, null) orelse return;
    if (win32.IsIconic(hwnd) != 0) _ = win32.ShowWindow(hwnd, win32.SW_RESTORE);
    _ = win32.SetForegroundWindow(hwnd);
}

/// Asks the open copy to close, as its close button does, and waits for it to exit (it
/// could be the installed exe, held open until then)
fn closeOpen() void {
    const hwnd = win32.FindWindowW(window_class, null) orelse return;
    var pid: u32 = 0;
    _ = win32.GetWindowThreadProcessId(hwnd, &pid);
    const process = win32.OpenProcess(win32.PROCESS_SYNCHRONIZE, win32.FALSE, pid);
    defer if (process) |p| {
        _ = win32.CloseHandle(p);
    };
    _ = win32.PostMessageW(hwnd, win32.WM_CLOSE, 0, 0);
    if (process) |p| _ = win32.WaitForSingleObject(p, 10_000);
}

/// %LOCALAPPDATA%\Programs\meiolol
fn installDir(arena: std.mem.Allocator) ![]const u8 {
    return std.fs.path.join(arena, &.{ try knownFolder(arena, &win32.FOLDERID_UserProgramFiles), install.dir_name });
}

fn knownFolder(arena: std.mem.Allocator, id: *const win32.Guid) ![]const u8 {
    var path: ?win32.PWSTR = null;
    const create = @backingInt(win32.KF_FLAG_CREATE);
    if (win32.SHGetKnownFolderPath(id, @bitCast(create), null, &path) < 0) return error.NoKnownFolder;
    defer win32.CoTaskMemFree(path);
    return std.unicode.wtf16LeToWtf8Alloc(arena, std.mem.span(path.?));
}

/// The Start menu shortcut and the Apps list entry, both per user
fn register(arena: std.mem.Allocator, dir: []const u8, version: u64) !void {
    const exe = try std.fs.path.join(arena, &.{ dir, update.exe_name });
    const programs = try knownFolder(arena, &win32.FOLDERID_Programs);
    try shortcut(arena, try std.fs.path.join(arena, &.{ programs, shortcut_name }), exe, dir);

    var key: ?win32.HKEY = null;
    try check(win32.RegCreateKeyExW(win32.HKEY_CURRENT_USER, uninstall_key, 0, null, .{}, win32.KEY_SET_VALUE, null, &key, null));
    defer _ = win32.RegCloseKey(key);
    var buf: [16]u8 = undefined;
    const strings = [_][2][]const u8{
        .{ "DisplayName", "meiolol" },
        .{ "DisplayVersion", install.displayVersion(&buf, version) },
        .{ "Publisher", "meio.lol" },
        .{ "URLInfoAbout", "https://meio.lol" },
        .{ "DisplayIcon", exe },
        .{ "InstallLocation", dir },
        .{ "UninstallString", try arena.print("\"{s}\" --uninstall", .{exe}) },
    };
    for (strings) |s| {
        const value = try wide(arena, s[1]);
        const bytes: u32 = @intCast((value.len + 1) * 2);
        try check(win32.RegSetValueExW(key, try wide(arena, s[0]), 0, win32.REG_SZ, @ptrCast(value.ptr), bytes));
    }
    for ([_][:0]const u16{ win32.L("NoModify"), win32.L("NoRepair") }) |name| {
        const one: u32 = 1;
        try check(win32.RegSetValueExW(key, name, 0, win32.REG_DWORD, @ptrCast(&one), 4));
    }
}

fn shortcut(arena: std.mem.Allocator, lnk: []const u8, exe: []const u8, dir: []const u8) !void {
    if (win32.CoInitializeEx(null, win32.COINIT_APARTMENTTHREADED) < 0) return error.ComInit;
    defer win32.CoUninitialize();
    var link: *win32.IShellLinkW = undefined;
    try hr(win32.CoCreateInstance(win32.CLSID_ShellLink, null, win32.CLSCTX_INPROC_SERVER, win32.IID_IShellLinkW, @ptrCast(&link)));
    defer _ = link.IUnknown.Release();
    try hr(link.SetPath(try wide(arena, exe)));
    try hr(link.SetWorkingDirectory(try wide(arena, dir)));
    try hr(link.SetDescription(win32.L("Champ select picks from meio.lol")));
    try hr(link.SetIconLocation(try wide(arena, exe), 0));
    var file: *win32.IPersistFile = undefined;
    try hr(link.IUnknown.QueryInterface(win32.IID_IPersistFile, @ptrCast(&file)));
    defer _ = file.IUnknown.Release();
    try hr(file.Save(try wide(arena, lnk), win32.TRUE));
}

fn uninstall(arena: std.mem.Allocator, io: Io, quiet: bool) !void {
    const title = win32.L("Remove meiolol");
    const ask = win32.L("Remove meiolol and its downloaded statistics from this PC?");
    const style: win32.MESSAGEBOX_STYLE = .{ .YESNO = 1, .ICONQUESTION = 1 };
    if (!quiet and win32.MessageBoxW(null, ask, title, style) != win32.IDYES) return;
    closeOpen();

    const programs = try knownFolder(arena, &win32.FOLDERID_Programs);
    Io.Dir.cwd().deleteFile(io, try std.fs.path.join(arena, &.{ programs, shortcut_name })) catch {};
    switch (win32.RegDeleteTreeW(win32.HKEY_CURRENT_USER, uninstall_key)) {
        .NO_ERROR, .ERROR_FILE_NOT_FOUND => {},
        else => |e| return check(e),
    }
    // This exe runs from the folder and Windows won't delete a running exe: cmd retries
    // for up to 30 s while it exits
    const dir = try installDir(arena);
    const cmd = try arena.print("cmd.exe /d /c for /l %i in (1,1,30) do (rmdir /s /q \"{0s}\" 2>nul & " ++
        "if not exist \"{0s}\" exit /b & ping -n 2 127.0.0.1 >nul)", .{dir});
    try start(arena, null, std.fs.path.dirname(dir) orelse dir, .{ .cmd = cmd });
}

const StartOptions = struct { cmd: ?[]const u8 = null };

/// A detached process: `exe`, or `options.cmd` as a hidden command line
fn start(arena: std.mem.Allocator, exe: ?[]const u8, cwd: []const u8, options: StartOptions) !void {
    var si: win32.STARTUPINFOW = std.mem.zeroes(win32.STARTUPINFOW);
    si.cb = @sizeOf(win32.STARTUPINFOW);
    var pi: win32.PROCESS_INFORMATION = undefined;
    const line = try wide(arena, options.cmd orelse try arena.print("\"{s}\"", .{exe.?}));
    const flags: win32.PROCESS_CREATION_FLAGS = if (options.cmd != null) win32.CREATE_NO_WINDOW else .{};
    if (win32.CreateProcessW(null, line, null, null, win32.FALSE, flags, null, try wide(arena, cwd), &si, &pi) == 0)
        return error.StartFailed;
    _ = win32.CloseHandle(pi.hProcess);
    _ = win32.CloseHandle(pi.hThread);
}

fn fail(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    var wbuf: [1024]u16 = undefined;
    const text = std.mem.print(&buf, fmt, args) catch fmt;
    const n = std.unicode.wtf8ToWtf16Le(wbuf[0 .. wbuf.len - 1], text) catch 0;
    wbuf[n] = 0;
    _ = win32.MessageBoxW(null, wbuf[0..n :0], win32.L("meiolol"), win32.MB_ICONERROR);
}

fn wide(arena: std.mem.Allocator, s: []const u8) ![:0]u16 {
    return std.unicode.wtf8ToWtf16LeAllocZ(arena, s);
}

fn hr(result: win32.HRESULT) !void {
    if (result < 0) return error.ComFailed;
}

fn check(err: win32.WIN32_ERROR) !void {
    if (err != .NO_ERROR) return error.RegistryFailed;
}
