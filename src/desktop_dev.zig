//! `meiolol-desktop-dev`: the desktop window on macOS or Linux through dvui's SDL3
//! backend, for trying it against the mock client (deploy/mock-cs.sh). Not shipped: the
//! player's window is desktop_main.zig. Reads MEIOLOL_LOCKFILE as `meiolol-app` does.

const std = @import("std");
const dvui = @import("dvui");
const ui = @import("desktop/ui.zig");
const poller = @import("desktop/poller.zig");

pub const dvui_app: dvui.App = .{
    .config = .{ .options = .{
        .size = ui.size,
        .min_size = .{ .w = 360, .h = 400 },
        .title = ui.title ++ " (dev)",
        .window_init_options = .{ .theme = ui.theme },
    } },
    .initFn = start,
    .deinitFn = stop,
    .frameFn = frame,
};
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn, .unexpected_error_tracing = false };

var window: *dvui.Window = undefined;

fn start(win: *dvui.Window) !void {
    window = win;
    const init = dvui.App.main_init orelse return error.NoProcessInit;
    try poller.start(init, init.environ_map.get("MEIOLOL_LOCKFILE"), wakeUi);
}

/// From the poller thread: SDL_PushEvent is thread safe
fn wakeUi() void {
    dvui.refresh(window, @src(), null);
}

fn stop(_: *dvui.Window) void {
    poller.stop();
}

fn frame() !dvui.App.Result {
    poller.frame();
    return .ok;
}
