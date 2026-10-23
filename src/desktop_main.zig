//! `meiolol-desktop`: the lane card in a window (dvui, Direct3D 11). The data and the
//! client poller live in desktop/poller.zig; this is the Windows window around them.

const std = @import("std");
const dvui = @import("dvui");
const ui = @import("desktop/ui.zig");
const poller = @import("desktop/poller.zig");
const setup = @import("desktop/setup.zig");
const build_options = @import("build_options");

pub const dvui_app: dvui.App = .{
    .config = .{ .options = .{
        .size = ui.size,
        .min_size = ui.min_size,
        .title = ui.title,
        .window_init_options = .{ .theme = ui.theme },
    } },
    .initFn = start,
    .deinitFn = stop,
    .frameFn = frame,
};
pub const panic = dvui.App.panic;
// The poller retries every second; Debug builds would print a stack trace for each
// error.Unexpected from the network layer
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn, .unexpected_error_tracing = false };

const backend = dvui.backend;
const win32 = backend.win32;

/// For the poller to wake the UI thread: the backend's refresh() does nothing
var hwnd: win32.HWND = undefined;

/// dvui's Direct3D 11 App main draws every vsync and never sleeps (10% of a core and 6%
/// of the GPU with nothing changing, gpu-box 2026-10-14). Same setup, but between frames
/// it waits for a message or dvui's next deadline
pub fn main(init: std.process.Init) !void {
    dvui.App.main_init = init;
    // Logs reach the console when started from one
    dvui.Backend.Common.windowsAttachConsole() catch {};
    if (setup.atStart(init, build_options.desktop_version) == .exit) return;
    const class = setup.window_class;
    const icon = win32.LoadIconW(win32.GetModuleHandleW(null), @ptrFromInt(1)); // meiolol.rc
    backend.RegisterClass(class, .{ .icon = icon }) catch win32.panicWin32("RegisterClass", win32.GetLastError());
    const opts = dvui_app.config.get();
    dvui.io = init.io;

    var state: backend.WindowState = undefined;
    const b = try backend.initWindow(&state, .{
        .registered_class = class,
        .dvui_gpa = init.gpa,
        .dvui_window_init_options = opts.window_init_options,
        .allocator = init.gpa,
        .size = opts.size,
        .min_size = opts.min_size,
        .max_size = opts.max_size,
        .vsync = opts.vsync,
        .title = opts.title,
        .icon = opts.icon,
    });
    defer b.deinit();
    hwnd = backend.hwndFromContext(b);
    const win = b.getWindow();
    var open = true;
    win.open_flag = &open;

    try win.begin(win.frame_time_ns);
    try start(win);
    _ = try win.end(.{});
    defer stop(win);

    var woken = false;
    while (open) {
        if (backend.serviceMessageQueue() == .quit) break;
        try win.begin(win.beginWait(woken));
        const res = try frame();
        const end_micros = try win.end(.{});
        if (res != .ok) break;
        woken = waitMessage(win.waitTime(end_micros));
    }
}

/// Sleeps until a message arrives or `micros` pass (maxInt: no deadline). True if woken
fn waitMessage(micros: u32) bool {
    if (micros == 0) return false;
    const ms = if (micros == std.math.maxInt(u32)) win32.INFINITE else micros / 1000 + 1;
    const wait_timeout = 0x102;
    return win32.MsgWaitForMultipleObjectsEx(0, null, ms, win32.QS_ALLINPUT, win32.MWMO_INPUTAVAILABLE) != wait_timeout;
}
fn start(_: *dvui.Window) !void {
    const init = dvui.App.main_init orelse return error.NoProcessInit;
    const edition: ui.Edition = if (build_options.public) .public else .private;
    try poller.start(init, null, wakeUi, build_options.desktop_version, edition);
}

fn wakeUi() void {
    _ = win32.PostMessageW(hwnd, win32.WM_NULL, 0, 0);
}

fn stop(_: *dvui.Window) void {
    poller.stop();
}

fn frame() !dvui.App.Result {
    poller.frame();
    return .ok;
}
