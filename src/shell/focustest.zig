//! `--focus-test 1|2`: what scripted runs skip, unattended (deploy/shell.sh focus on the
//! gpu-box). It takes focus, so shell.sh runs it only while no game is running.
//! Run 1: minimised, restored, then the taskbar (another process) put in front and the
//! window restored again (win.zig logs the memory target; a scripted start isn't in front),
//! moved to `moved`, closed (window.txt). Run 2 opens where run 1 left it, minimises
//! itself; shell.sh then starts a third copy, which must exit and bring this window back.
//! The verdicts are read from shell.log by shell.sh

const std = @import("std");
const win = @import("win.zig");
const c = win.c;
const place = @import("place.zig");

/// Physical pixels: a place that is neither the default centre nor the screen's edge
pub const moved: place.Rect = .{ .x = 140, .y = 90, .w = 960, .h = 640 };

var run: u8 = 0;
var painted_at: ?f64 = null;
var step: u8 = 0;
var foreground: ?bool = null;

pub fn start(n: u8) void {
    run = n;
}

pub fn painted(t: f64) void {
    if (painted_at == null) painted_at = t;
}

/// Once a second
pub fn tick() void {
    const t0 = painted_at orelse return;
    const s = (win.nowMs() - t0) / 1000;
    const fg = c.GetForegroundWindow() == win.hwnd;
    if (foreground == null or foreground.? != fg) {
        foreground = fg;
        win.log("focus test: foreground {s}", .{if (fg) "yes" else "no"});
    }
    const steps: []const Step = if (run == 1) &run1 else &run2;
    if (step < steps.len and s >= steps[step].at) {
        win.log("focus test: {s}", .{steps[step].name});
        steps[step].do();
        step += 1;
    }
}

const Step = struct { at: f64, name: []const u8, do: *const fn () void };

const run1 = [_]Step{
    .{ .at = 2, .name = "minimise", .do = minimise },
    .{ .at = 9, .name = "restore", .do = restore },
    .{ .at = 16, .name = "taskbar in front", .do = other },
    .{ .at = 23, .name = "restore", .do = restore },
    .{ .at = 26, .name = "move", .do = move },
    .{ .at = 28, .name = "close", .do = close },
};

const run2 = [_]Step{
    .{ .at = 2, .name = "minimise (shell.sh starts a second copy)", .do = minimise },
    .{ .at = 20, .name = "close", .do = close },
};

fn minimise() void {
    _ = c.ShowWindow(win.hwnd, c.SW_MINIMIZE);
}

fn restore() void {
    _ = c.ShowWindow(win.hwnd, c.SW_RESTORE);
    _ = c.SetForegroundWindow(win.hwnd);
}

fn other() void {
    if (c.FindWindowW(win.W("Shell_TrayWnd"), null)) |tray| _ = c.SetForegroundWindow(tray);
}

fn move() void {
    _ = c.SetWindowPos(win.hwnd, null, moved.x, moved.y, moved.w, moved.h, c.SWP_NOZORDER);
}

fn close() void {
    _ = c.PostMessageW(win.hwnd, c.WM_CLOSE, 0, 0);
}
