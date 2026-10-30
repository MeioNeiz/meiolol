//! The private numbers' files (ui.pv, ui-pv.wasm) under /private/ at fixed names, which
//! nginx serves to private logins only (no-cache there). shell.zig's admin_link loads them
//! on public pages for browsers that opened /admin or /private; admin.zig writes them
const ui = @import("ui");

/// After the page's inline CSS: the badge again (same rules, same layer) and the box's
pub const css = ui.css.join(.{ ui.badge, ui.pv });

pub const files = [_]struct { []const u8, []const u8 }{
    .{ "pv.css", css },
    .{ "pv.js", @embedFile("ui-pv.js") },
    .{ "pv.wasm", @embedFile("ui-pv.wasm") },
};

/// One of `files` by its name under /private/
pub fn file(name: []const u8) ?[]const u8 {
    for (files) |f| if (@import("std").mem.eql(u8, f[0], name)) return f[1];
    return null;
}
