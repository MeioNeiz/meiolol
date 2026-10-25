//! The sign-in form (device.zig does the request): the whole body on a first start with no
//! data yet, else one line under the content that opens it. Both editions.

const std = @import("std");
const dvui = @import("dvui");
const w = @import("widgets.zig");

pub const State = @import("state.zig").SignIn;

pub const Hook = struct {
    state: *const State,
    /// From the UI thread, holding the poller's mutex; copies what it keeps
    submit: *const fn (username: []const u8, password: []const u8) void,
};

var username_buf: [64]u8 = @splat(0);
var password_buf: [256]u8 = @splat(0);
/// The line under the content was clicked open
var open = false;

/// The form, when `full` or opened from the line
pub fn view(hook: Hook, full: bool) void {
    const s = hook.state;
    if (!s.needed) return;
    if (!full and !open) {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .padding = .{ .x = 16, .y = 6, .w = 16, .h = 6 } });
        defer row.deinit();
        dvui.labelNoFmt(@src(), if (s.message.len > 0) s.message else "Sign in to keep the statistics and the app current.", .{}, .{
            .gravity_y = 0.5,
            .font = w.small(),
            .color_text = .{ .color = w.text().opacity(0.7) },
        });
        if (dvui.button(@src(), "Sign in", .{}, .{ .gravity_y = 0.5, .margin = .{ .x = 10 } })) open = true;
        return;
    }
    var body = dvui.box(@src(), .{ .dir = .vertical }, .{ .padding = .all(16), .max_size_content = .width(360) });
    defer body.deinit();
    w.heading(@src(), "Sign in to meio.lol", null);
    w.para(@src(), "With the account you were invited to. The app keeps a sign-in of its own, which you can remove on your account page at meio.lol.", .{}, .{ .muted = true, .small = true });

    var enter = false;
    {
        var te = dvui.textEntry(@src(), .{ .text = .{ .buffer = &username_buf }, .placeholder = "Username or email" }, .{ .expand = .horizontal, .margin = .{ .y = 8 } });
        if (dvui.firstFrame(te.data().id)) dvui.focusWidget(te.data().id, null, null);
        enter = te.enter_pressed;
        te.deinit();
    }
    {
        var te = dvui.textEntry(@src(), .{ .text = .{ .buffer = &password_buf }, .placeholder = "Password", .password_char = "•" }, .{ .expand = .horizontal, .margin = .{ .y = 4 } });
        enter = enter or te.enter_pressed;
        te.deinit();
    }
    const username = std.mem.trim(u8, std.mem.sliceTo(&username_buf, 0), " ");
    const password = std.mem.sliceTo(&password_buf, 0);
    const ready = !s.busy and username.len > 0 and password.len > 0;
    const clicked = dvui.button(@src(), if (s.busy) "Signing in…" else "Sign in", .{}, .{ .style = if (ready) .highlight else .control, .margin = .{ .y = 8 } });
    if (ready and (clicked or enter)) {
        hook.submit(username, password);
        @memset(&password_buf, 0);
    }
    if (s.message.len > 0 and !s.busy) w.para(@src(), "{s}", .{s.message}, .{ .color = w.palette.caution });
}
