# Samples ⚡ Zig Programming Language

<https://ziglang.org/learn/samples/>

[Download](https://ziglang.org/download/) [Learn](https://ziglang.org/learn/) [News](https://ziglang.org/news/) [Zig Software Foundation](https://ziglang.org/zsf/) [Devlog](https://ziglang.org/devlog/2026/) [Source](https://codeberg.org/ziglang/zig) [Join a Community](https://ziglang.org/community)

[← Back to **Learn**](https://ziglang.org/learn/)

# Samples

-   [Hello world](https://ziglang.org/learn/samples/#hello)
-   [Calling external library functions](https://ziglang.org/learn/samples/#ext)
-   [Memory leak detection](https://ziglang.org/learn/samples/#leak)
-   [C interoperability](https://ziglang.org/learn/samples/#c-interop)
-   [Zigg Zagg](https://ziglang.org/learn/samples/#zigg-zagg)
-   [Generic Types](https://ziglang.org/learn/samples/#generic)
-   [Using cURL from Zig](https://ziglang.org/learn/samples/#curl)

# Hello world

A minimal example printing hello world.

hello-world.zig

```
const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    try Io.File.stdout().writeStreamingAll(init.io, "hello world!\n");
}
```

Shell

$ zig build-exe hello-world.zig
$ ./hello-world
hello world!

# Calling external library functions

All system API functions can be invoked this way, you do not need library bindings to interface them.

windows-msgbox.zig

```
const win = @import("std").os.windows;

extern "user32" fn MessageBoxA(?win.HWND, [*:0]const u8, [*:0]const u8, u32) callconv(.winapi) i32;

pub fn main() !void {
    _ = MessageBoxA(null, "world!", "Hello", 0);
}
```

Shell

$ zig test windows-msgbox.zig
All 0 tests passed.

# Memory leak detection

Using `std.heap.DebugAllocator` you can track double frees and memory leaks.

memory-leak.zig

```
const std = @import("std");

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer std.debug.assert(debug_allocator.deinit() == .ok);

    const gpa = debug_allocator.allocator();

    const u32_ptr = try gpa.create(u32);
    _ = u32_ptr; // silences unused variable error

    // oops I forgot to free!
}
```

Shell

$ zig build-exe memory-leak.zig
$ ./memory-leak
error(DebugAllocator): memory address 0x7ff572c80000 leaked:
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/samples/memory-leak.zig:9:35: 0x11e87b4 in main (memory-leak.zig)
    const u32\_ptr = try gpa.create(u32);
                                  ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:788:64: 0x11e8eb6 in callMain (std.zig)
    if (fn\_info.param\_types.len == 0) return wrapMain(root.main());
                                                               ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:248:5: 0x11e86e1 in \_start (std.zig)
    asm volatile (switch (native\_arch) {
    ^

thread 3050149 panic: reached unreachable code
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/debug.zig:442:14: 0x1029e99 in assert (std.zig)
    if (!ok) unreachable; // assertion failure
             ^
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/samples/memory-leak.zig:5:27: 0x11e8866 in main (memory-leak.zig)
    defer std.debug.assert(debug\_allocator.deinit() == .ok);
                          ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:788:64: 0x11e8eb6 in callMain (std.zig)
    if (fn\_info.param\_types.len == 0) return wrapMain(root.main());
                                                               ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:248:5: 0x11e86e1 in \_start (std.zig)
    asm volatile (switch (native\_arch) {
    ^
(process terminated by signal)

# C interoperability

Example of importing a C header file and linking to both libc and raylib.

c-interop.zig

```
// build with `zig build-exe c-interop.zig -lc -lraylib`
const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn main() void {
    const screenWidth = 800;
    const screenHeight = 450;

    ray.InitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Hello, World!", 190, 200, 20, ray.LIGHTGRAY);
    }
}
```

# Zigg Zagg

Zig is _optimized_ for coding interviews (not really).

ziggzagg.zig

```
const std = @import("std");

pub fn main() !void {
    var i: usize = 1;
    while (i <= 16) : (i += 1) {
        if (i % 15 == 0) {
            std.log.info("ZiggZagg", .{});
        } else if (i % 3 == 0) {
            std.log.info("Zigg", .{});
        } else if (i % 5 == 0) {
            std.log.info("Zagg", .{});
        } else {
            std.log.info("{d}", .{i});
        }
    }
}
```

Shell

$ zig build-exe ziggzagg.zig
$ ./ziggzagg
info: 1
info: 2
info: Zigg
info: 4
info: Zagg
info: Zigg
info: 7
info: 8
info: Zigg
info: Zagg
info: 11
info: Zigg
info: 13
info: 14
info: ZiggZagg
info: 16

# Generic Types

In Zig types are comptime values and we use functions that return a type to implement generic algorithms and data structures. In this example we implement a simple generic queue and test its behaviour.

generic-type.zig

```
const std = @import("std");

pub fn Queue(comptime Child: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            data: Child,
            next: ?*Node,
        };
        gpa: std.mem.Allocator,
        start: ?*Node,
        end: ?*Node,

        pub fn init(gpa: std.mem.Allocator) Self {
            return Self{
                .gpa = gpa,
                .start = null,
                .end = null,
            };
        }
        pub fn enqueue(self: *Self, value: Child) !void {
            const node = try self.gpa.create(Node);
            node.* = .{ .data = value, .next = null };
            if (self.end) |end| end.next = node //
            else self.start = node;
            self.end = node;
        }
        pub fn dequeue(self: *Self) ?Child {
            const start = self.start orelse return null;
            defer self.gpa.destroy(start);
            if (start.next) |next|
                self.start = next
            else {
                self.start = null;
                self.end = null;
            }
            return start.data;
        }
    };
}

test "queue" {
    var int_queue = Queue(i32).init(std.testing.allocator);

    try int_queue.enqueue(25);
    try int_queue.enqueue(50);
    try int_queue.enqueue(75);
    try int_queue.enqueue(100);

    try std.testing.expectEqual(int_queue.dequeue(), 25);
    try std.testing.expectEqual(int_queue.dequeue(), 50);
    try std.testing.expectEqual(int_queue.dequeue(), 75);
    try std.testing.expectEqual(int_queue.dequeue(), 100);
    try std.testing.expectEqual(int_queue.dequeue(), null);

    try int_queue.enqueue(5);
    try std.testing.expectEqual(int_queue.dequeue(), 5);
    try std.testing.expectEqual(int_queue.dequeue(), null);
}
```

Shell

$ zig test generic-type.zig
1/1 generic-type.test.queue...OK
All 1 tests passed.

# Using cURL from Zig

curl.zig

```
// compile with `zig build-exe zig-curl-test.zig --library curl --library c $(pkg-config --cflags libcurl)`
const std = @import("std");
const cURL = @cImport({
    @cInclude("curl/curl.h");
});

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    // global curl init, or fail
    if (cURL.curl_global_init(cURL.CURL_GLOBAL_ALL) != cURL.CURLE_OK)
        return error.CURLGlobalInitFailed;
    defer cURL.curl_global_cleanup();

    // curl easy handle init, or fail
    const handle = cURL.curl_easy_init() orelse return error.CURLHandleInitFailed;
    defer cURL.curl_easy_cleanup(handle);

    var response_buffer = std.ArrayList(u8).init(arena);

    // superfluous when using an arena allocator, but
    // important if the allocator implementation changes
    defer response_buffer.deinit();

    // setup curl options
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_URL, "https://ziglang.org") != cURL.CURLE_OK)
        return error.CouldNotSetURL;

    // set write function callbacks
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEFUNCTION, writeToArrayListCallback) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEDATA, &response_buffer) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;

    // perform
    if (cURL.curl_easy_perform(handle) != cURL.CURLE_OK)
        return error.FailedToPerformRequest;

    std.log.info("Got response of {d} bytes", .{response_buffer.items.len});
    std.debug.print("{s}\n", .{response_buffer.items});
}

fn writeToArrayListCallback(data: *anyopaque, size: c_uint, nmemb: c_uint, user_data: *anyopaque) callconv(.C) c_uint {
    var buffer: *std.ArrayList(u8) = @ptrCast(@alignCast(user_data));
    var typed_data: [*]u8 = @ptrCast(data);
    buffer.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
    return nmemb * size;
}
```

This page is also available in the following languages:  

[English (original)](https://ziglang.org/learn/samples/) [Español](https://ziglang.org/es-AR/learn/samples/) [Русский](https://ziglang.org/ru-RU/learn/samples/) [Italiano](https://ziglang.org/it-IT/learn/samples/) [Deutsch](https://ziglang.org/de-DE/learn/samples/) [Українська](https://ziglang.org/uk-UA/learn/samples/) [日本語](https://ziglang.org/ja-JP/learn/samples/) [中文](https://ziglang.org/zh-CN/learn/samples/) [한국어](https://ziglang.org/ko-KR/learn/samples/)
