//! The shell's OS-free parts, tested on any host (win.zig and mac.zig only build)
test {
    _ = @import("channel.zig");
    _ = @import("files.zig");
    _ = @import("place.zig");
    _ = @import("demo.zig");
    _ = @import("client.zig");
}
