# Using a custom test runner in Zig

<https://www.openmymind.net/Using-A-Custom-Test-Runner-In-Zig/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Using-A-Custom-Test-Runner-In-Zig/#)

# Using a custom test runner in Zig

Jul 15, 2024

**Latest Version (0.16.0):** I keep a [gist](https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b) up to date. This also includes links to gist for previous versions.

Depending on what you're used to, Zig's built-in test runner might seem a little bare. For example, you might prefer a more verbose output, maybe showing your slowest tests. You might need control over the output in order to integrate it into a larger build process or want to have global setup and teardown functions. Maybe you [just want to be able to write to stdout](https://github.com/ziglang/zig/issues/18111). Whatever your needs, Zig makes it easy to write a custom test runner.

In Zig, a test runner is entry point for `zig test` or any test step added via `zig build`. In other words, it's code that contains a `pub main() !void` entrypoint. Here's a simple version:

```zig
const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    const out = std.io.getStdOut().writer();

    for (builtin.test_functions) |t| {
        t.func() catch |err| {
            try std.fmt.format(out, "{s} fail: {}\n", .{t.name, err});
            continue;
        };
        try std.fmt.format(out, "{s} passed\n", .{t.name});
    }
}
```

### Usage

How do you use it? First, save the above as `test_runner.zig`. If you're using `zig test`, use the `--test runner` flag, e.g. `--test-runner test_runner.zig`. If you're using `zig build` specify a `test_runner` configuration when calling `addTest`:

```zig
const tests = b.addTest(.{
    .root_source_file = b.path("src/main.zig"),

    // Add this line to your build.zig:
    .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },

    // In previous version of Zig, you'd use:
    // .test_runner = b.path("test_runner.zig"),

    // ... you might have other fields
});
```

### Basics

We can see from our simple test runner that we iterate through `builtin.test_functions`, which is a slice of `std.builtin.TestFn`. This struct has two fields, a name and the test function:

```zig
pub const TestFn = struct {
    name: []const u8,
    func: *const fn () anyerror!void,
};
```

While we don't have much to go by, we can extract a fair bit from the `name`. For example, given a file "server/handshake.zig" with a `test "Handshake: parse"`, our `t.name` would be `server.handshake.test.Handshake: parse`. While it isn't foolproof, in most cases, we can extract the path to the file containing the test, and the test name.

For example, if we just wanted to display the test name and how long each test took, we could use:

```zig
const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    const out = std.io.getStdOut().writer();

    for (builtin.test_functions) |t| {
        const start = std.time.milliTimestamp();
        const result = t.func();
        const elapsed = std.time.milliTimestamp() - start;

        const name = extractName(t);
        if (result) |_| {
            try std.fmt.format(out, "{s} passed - ({d}ms)\n", .{name, elapsed});
        } else |err| {
            try std.fmt.format(out, "{s} failed - {}\n", .{t.name, err});
        }
    }
}

fn extractName(t: std.builtin.TestFn) []const u8 {
    const marker = std.mem.lastIndexOf(u8, t.name, ".test.") orelse return t.name;
    return t.name[marker+6..];
}
```

One thing to be mindful of is that Zig supports nameless tests. They look like:

```zig
test {
  // ....
}
```

Since they have no name, Zig will name them `test_#`, starting at 0. So in our fictional "server/handshake.zig" file, the first nameless test would have the name `server.handshake.test_0` and the second one would be named `server.handshake.test_1` (although it's pretty unusual to have 2 nameless tests in the same project, let alone the same file).

### Memory Leak Detection

To preserve the builtin test runner's memory leak detection when using `std.testing.allocator`, we need want to set `std.testing.allocator_instance` before each test, and check for leaks after each test:

```zig
std.testing.allocator_instance = .{};
const result = t.func();
if (std.testing.allocator_instance.deinit() == .leak) {
  try std.fmt.format(out, "{s} leaked memory\n", .{name});
}
// ... check result for errors
```

The call to `deinit()` will output details about the leak to stderr.

### Features

Any additional feature has to use the limited information we have access to.

Some like their tests to stop on the first failures. We can achieve this by returning after the first error:

```zig
...
else |err| {
  try std.fmt.format(out, "{s} failed - {}\n", .{t.name, err});
  std.process.exit(1);
}
```

If you want to be able to filter which tests are run (something the default test runner can also do), you could use an environment variable and match the test name using:

```zig
var mem: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&mem);
const test_filter = std.process.getEnvVarOwned(fba.allocator(), "TEST_FILTER") catch |err| blk: {
    if (err == error.EnvironmentVariableNotFound) break :blk  "";
    return err;
};

for (builtin.test_functions) |t| {
    if (std.mem.indexOf(u8, t.name, test_filter) == null) {
        continue;
    }
    // run the test, same as before
}
```

A common request I've seen is having a global setup/teardown. While I know some think this is a smell and should be avoided, I've personally found it useful to have in a few cases. This is something we add (admittedly a bit of hack) by using a naming convention. Here's an abbreviated version:

```zig
pub fn main() !void {
  ...

  // first run the setups
  for (builtin.test_functions) |t| {
      if (isSetup(t)) {
          try t.func();
      }
  }

  // next run normal tests
  for (builtin.test_functions) |t| {
      if (isSetup(t) or isTeardown(t)) {
        continue
      }
      try t.func()
  }

  // finally run teardowns
  for (builtin.test_functions) |t| {
      if (isTeardown(t)) {
          try t.func();
      }
  }
}

fn isSetup(t: std.builtin.TestFn) bool {
    return std.mem.endsWith(u8, t.name, "tests:beforeAll");
}

fn isTeardown(t: std.builtin.TestFn) bool {
    return std.mem.endsWith(u8, t.name, "tests:afterAll");
}
```

Now any tests named `tests:beforeAll` will be run first while any tests named `tests:afterAll` will be run last. It isn't the most efficient, but it's simple to follow and modify for your specific needs

### Conclusion

In the end, it comes down to taking the first example - which iterates through `builtin.test_functions` to call each `func` - and modifying it to meet your needs. If you're looking for something a bit more feature-rich, consider using [this test runner](https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b) as your template.
