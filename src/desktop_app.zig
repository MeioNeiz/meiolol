//! The app's own Zig for the webview shell (src/shell): the League client poller and what
//! it publishes, with no toolkit. A module rooted here, as the poller imports from src/
pub const poller = @import("desktop/poller.zig");
pub const state = @import("desktop/state.zig");
pub const board = @import("board.zig");
pub const lanecard = @import("lanecard.zig");
pub const loading = @import("loading.zig");
pub const ingame = @import("ingame.zig");
pub const postgame = @import("postgame.zig");
pub const practice = @import("practice.zig");
pub const lcu = @import("lcu/root.zig");
pub const core = @import("core");
pub const Icons = @import("desktop/icons.zig").Icons;

test {
    _ = state;
}
