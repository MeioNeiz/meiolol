# Overview ⚡ Zig Programming Language

<https://ziglang.org/learn/overview/>

[Download](https://ziglang.org/download/) [Learn](https://ziglang.org/learn/) [News](https://ziglang.org/news/) [Zig Software Foundation](https://ziglang.org/zsf/) [Devlog](https://ziglang.org/devlog/2026/) [Source](https://codeberg.org/ziglang/zig) [Join a Community](https://ziglang.org/community)

[← Back to **Learn**](https://ziglang.org/learn/)

# Overview

# Feature Highlights

## Small, simple language

Focus on debugging your application rather than debugging your programming language knowledge.

Zig’s entire syntax is specified with a [580-line PEG grammar file](https://ziglang.org/documentation/master/#Grammar).

There is **no hidden control flow**, no hidden memory allocations, no preprocessor, and no macros. If Zig code doesn’t look like it’s jumping away to call a function, then it isn’t. This means you can be sure that the following code calls only `foo()` and then `bar()`, and this is guaranteed without needing to know the types of anything:

```
var a = b + c.d;
foo();
bar();
```

Examples of hidden control flow:

-   D has `@property` functions, which are methods that you call with what looks like field access, so in the above example, `c.d` might call a function.
-   C++, D, and Rust have operator overloading, so the `+` operator might call a function.
-   C++, D, and Go have throw/catch exceptions, so `foo()` might throw an exception, and prevent `bar()` from being called.

Zig promotes code maintenance and readability by making all control flow managed exclusively with language keywords and function calls.

## Performance and Safety: Choose Two

Zig has four [build modes](https://ziglang.org/documentation/master/#Build-Mode), and they can all be mixed and matched all the way down to [scope granularity](https://ziglang.org/documentation/master/#setRuntimeSafety).

| Parameter | [Debug](https://ziglang.org/documentation/master/#Debug) | [ReleaseSafe](https://ziglang.org/documentation/master/#ReleaseSafe) | [ReleaseFast](https://ziglang.org/documentation/master/#ReleaseFast) | [ReleaseSmall](https://ziglang.org/documentation/master/#ReleaseSmall) |
| --- | --- | --- | --- | --- |
| Optimizations - improve speed, harm debugging, harm compile time |  | On | On | On |
| Runtime Safety Checks - harm speed, harm size, crash instead of undefined behavior | On | On |  |  |

Here is what [Integer Overflow](https://ziglang.org/documentation/master/#Integer-Overflow) looks like at compile time, regardless of the build mode:

1-integer-overflow.zig

```
test "integer overflow at compile time" {
    const x: u8 = 255;
    _ = x + 1;
}
```

Shell

$ zig test 1-integer-overflow.zig
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/1-integer-overflow.zig:3:11: error: overflow of integer type 'u8' with value '256'
    \_ = x + 1;
        ~~^~~

Here is what it looks like at runtime, in safety-checked builds:

2-integer-overflow-runtime.zig

```
test "integer overflow at runtime" {
    var x: u8 = 255;
    x += 1;
}
```

Shell

$ zig test 2-integer-overflow-runtime.zig
1/1 2-integer-overflow-runtime.test.integer overflow at runtime...thread 3050386 panic: integer overflow
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/2-integer-overflow-runtime.zig:3:7: 0x1254595 in test.integer overflow at runtime (2-integer-overflow-runtime.zig)
    x += 1;
      ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/compiler/test\_runner.zig:295:25: 0x1208421 in mainTerminal (test\_runner.zig)
        if (test\_fn.func()) |\_| {
                        ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/compiler/test\_runner.zig:74:28: 0x1207c02 in main (test\_runner.zig)
        return mainTerminal(init);
                           ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:789:88: 0x120439f in callMain (std.zig)
    if (fn\_info.param\_types\[0\].? == std.process.Init.Minimal) return wrapMain(root.main(.{
                                                                                       ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:248:5: 0x1203d81 in \_start (std.zig)
    asm volatile (switch (native\_arch) {
    ^
error: the following test command terminated with signal ABRT:
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/.zig-cache/o/dffbede827703741bf5afa85ea16b75f/test --seed=0xd0ef932

Those [stack traces work on all targets](https://ziglang.org/learn/overview/#stack-traces-on-all-targets), including [freestanding](https://andrewkelley.me/post/zig-stack-traces-kernel-panic-bare-bones-os.html).

With Zig one can rely on a safety-enabled build mode, and selectively disable safety at the performance bottlenecks. For example the previous example could be modified like this:

3-undefined-behavior.zig

```
test "actually undefined behavior" {
    @setRuntimeSafety(false);
    var x: u8 = 255;
    x += 1; // XXX undefined behavior!
}
```

Zig uses [Illegal Behavior](https://ziglang.org/documentation/master/#Illegal-Behavior) as a razor sharp tool for both bug prevention and performance enhancement.

Speaking of performance, Zig is faster than C.

-   All Zig code lives in one compilation unit, optimized together.
-   Carefully chosen illegal behavior. For example, in Zig both signed and unsigned integers have illegal behavior on overflow, contrasted to only signed integers in C. This [facilitates optimizations that are not available in C](https://godbolt.org/z/vhjv9oM1W).
-   Zig directly exposes a [SIMD vector type](https://ziglang.org/documentation/master/#Vectors), making it easy to write portable vectorized code.
-   The standard library provides essential data structures such as hash maps and array lists, whereas in C it is tempting to use linked lists for simplicity.
-   Advanced CPU features are enabled by default, unless [cross-compiling](https://ziglang.org/learn/overview/#cross-compiling-is-a-first-class-use-case).

## Zig competes with C instead of depending on it

The Zig Standard Library integrates with libc, but does not depend on it. Here’s Hello World:

4-hello.zig

```
const std = @import("std");

pub fn main() void {
    std.debug.print("Hello, world!\n", .{});
}
```

Shell

$ zig build-exe 4-hello.zig
$ ./4-hello
Hello, world!

When compiled with `-O ReleaseSmall`, debug symbols stripped, single-threaded mode, this produces a 9.8 KiB static executable for the x86\_64-linux target:

```
$ zig build-exe hello.zig -O ReleaseSmall -fstrip -fsingle-threaded
$ wc -c hello
9944 hello
$ ldd hello
  not a dynamic executable
```

A Windows build is even smaller, coming out to 4096 bytes:

```
$ zig build-exe hello.zig -O ReleaseSmall -fstrip -fsingle-threaded -target x86_64-windows
$ wc -c hello.exe
4096 hello.exe
$ file hello.exe
hello.exe: PE32+ executable (console) x86-64, for MS Windows
```

## Order independent top level declarations

Top level declarations such as global variables are order-independent and lazily analyzed. The initialization values of global variables are [evaluated at compile-time](https://ziglang.org/learn/overview/#compile-time-reflection-and-compile-time-code-execution).

5-global-variables.zig

```
var y: i32 = add(10, x);
const x: i32 = add(12, 34);

test "global variables" {
    assert(x == 46);
    assert(y == 56);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

const std = @import("std");
const assert = std.debug.assert;
```

Shell

$ zig test 5-global-variables.zig
1/1 5-global-variables.test.global variables...OK
All 1 tests passed.

## Optional type instead of null pointers

In other programming languages, null references are the source of many runtime exceptions, and even stand accused of being [the worst mistake of computer science](https://www.lucidchart.com/techblog/2015/08/31/the-worst-mistake-of-computer-science/).

Unadorned Zig pointers cannot be null:

6-null-to-ptr.zig

```
test "null @intToPtr" {
    const foo: *i32 = @ptrFromInt(0x0);
    _ = foo;
}
```

Shell

$ zig test 6-null-to-ptr.zig
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/6-null-to-ptr.zig:2:35: error: pointer type '\*i32' does not allow address zero
    const foo: \*i32 = @ptrFromInt(0x0);
                                  ^~~

However any type can be made into an [optional type](https://ziglang.org/documentation/master/#Optionals) by prefixing it with `?`:

7-optional-syntax.zig

```
const std = @import("std");
const assert = std.debug.assert;

test "null @intToPtr" {
    const ptr: ?*i32 = @ptrFromInt(0x0);
    assert(ptr == null);
}
```

Shell

$ zig test 7-optional-syntax.zig
1/1 7-optional-syntax.test.null @intToPtr...OK
All 1 tests passed.

To unwrap an optional value, one can use `orelse` to provide a default value:

8-optional-orelse.zig

```
// malloc prototype included for reference
extern fn malloc(size: size_t) ?*u8;

fn doAThing() ?*Foo {
    const ptr = malloc(1234) orelse return null;
    // ...
}
```

Another option is to use if:

9-optional-if.zig

```
fn doAThing(optional_foo: ?*Foo) void {
    // do some stuff

    if (optional_foo) |foo| {
        doSomethingWithFoo(foo);
    }

    // do some stuff
}
```

The same syntax works with [while](https://ziglang.org/documentation/master/#while):

10-optional-while.zig

```
const std = @import("std");

pub fn main() void {
    const msg = "hello this  is dog";
    var it = std.mem.tokenizeAny(u8, msg, " ");
    while (it.next()) |item| {
        std.debug.print("{s}\n", .{item});
    }
}
```

Shell

$ zig build-exe 10-optional-while.zig
$ ./10-optional-while
hello
this
is
dog

## Manual memory management

A library written in Zig is eligible to be used anywhere:

-   [Desktop applications](https://isaacfreund.com/software/river/)
-   Low-latency servers
-   [Databases](https://tigerbeetle.com/)
-   Operating System kernels
-   [Embedded devices](https://microzig.tech/)
-   Real-time software, e.g. live performances, airplanes, pacemakers
-   In web browsers or other plugins with WebAssembly
-   By other programming languages, using the C ABI

In order to accomplish this, Zig programmers must manage their own memory, and must handle memory allocation failure.

This is true of the Zig Standard Library as well. Any functions that need to allocate memory accept an allocator parameter. As a result, the Zig Standard Library can be used even for the freestanding target.

In addition to [A fresh take on error handling](https://ziglang.org/learn/overview/#a-fresh-take-on-error-handling), Zig provides [defer](https://ziglang.org/documentation/master/#defer) and [errdefer](https://ziglang.org/documentation/master/#errdefer) to make all resource management - not only memory - simple and easily verifiable.

For an example of `defer`, see [Integration with C libraries without FFI/bindings](https://ziglang.org/learn/overview/#integration-with-c-libraries-without-ffibindings). Here is an example of using `errdefer`:

11-errdefer.zig

```
const Device = struct {
    name: []u8,

    fn create(allocator: *Allocator, id: u32) !Device {
        const device = try allocator.create(Device);
        errdefer allocator.destroy(device);

        device.name = try std.fmt.allocPrint(allocator, "Device(id={d})", id);
        errdefer allocator.free(device.name);

        if (id == 0) return error.ReservedDeviceId;

        return device;
    }
};
```

## A fresh take on error handling

Errors are values, and may not be ignored:

12-errors-as-values.zig

```
const std = @import("std");

pub fn main() void {
    _ = std.fs.cwd().openFile("does_not_exist/foo.txt", .{});
}
```

Shell

$ zig build-exe 12-errors-as-values.zig
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/12-errors-as-values.zig:4:15: error: root source file struct 'fs' has no member named 'cwd'
    \_ = std.fs.cwd().openFile("does\_not\_exist/foo.txt", .{});
        \~~~~~~^~~~
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/fs.zig:1:1: note: struct declared here
//! File System.
^~~~~~~~~~~~~~~~
referenced by:
    callMain \[inlined\]: /home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:788:64
    callMainWithArgs \[inlined\]: /home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:729:20
    posixCallMainAndExit: /home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:681:38
    2 reference(s) hidden; use '-freference-trace=5' to see all references

Errors can be handled with [catch](https://ziglang.org/documentation/master/#catch):

13-errors-catch.zig

```
const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) void {
    const io = init.io;

    const file: Io.File = Io.Dir.cwd().openFile(io, "does_not_exist/foo.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {}\n", .{err});
        break :label .stderr();
    };

    var file_writer = file.writer(io, &.{});
    file_writer.interface.writeAll("all your codebase are belong to us\n") catch return;
}
```

Shell

$ zig build-exe 13-errors-catch.zig
$ ./13-errors-catch
unable to open file: error.FileNotFound
all your codebase are belong to us

The keyword [try](https://ziglang.org/documentation/master/#try) is a shortcut for `catch |err| return err`:

14-errors-try.zig

```
const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const file = try Io.Dir.cwd().openFile(io, "does_not_exist/foo.txt", .{});
    defer file.close(io);

    var file_writer = file.writer(io, &.{});
    try file_writer.interface.writeAll("all your codebase are belong to us\n");
}
```

Shell

$ zig build-exe 14-errors-try.zig
$ ./14-errors-try
error: FileNotFound
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/Io/Threaded.zig:4993:35: 0x11a0fa4 in dirOpenFilePosix (std.zig)
                        .NOENT => return error.FileNotFound,
                                  ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/Io/Dir.zig:581:5: 0x10374a0 in openFile (std.zig)
    return io.vtable.dirOpenFile(io.userdata, dir, sub\_path, options);
    ^
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/14-errors-try.zig:7:18: 0x11e87f8 in main (14-errors-try.zig)
    const file = try Io.Dir.cwd().openFile(io, "does\_not\_exist/foo.txt", .{});
                 ^

Note that is an [Error Return Trace](https://ziglang.org/documentation/master/#Error-Return-Traces), not a [stack trace](https://ziglang.org/learn/overview/#stack-traces-on-all-targets). The code did not pay the price of unwinding the stack to come up with that trace.

The [switch](https://ziglang.org/documentation/master/#switch) keyword used on an error ensures that all possible errors are handled:

15-errors-switch.zig

```
const std = @import("std");

test "switch on error" {
    _ = parseInt("hi", 10) catch |err| switch (err) {};
}

fn parseInt(buf: []const u8, radix: u8) !u64 {
    var x: u64 = 0;

    for (buf) |c| {
        const digit = try charToDigit(c);

        if (digit >= radix) {
            return error.DigitExceedsRadix;
        }

        x = try std.math.mul(u64, x, radix);
        x = try std.math.add(u64, x, digit);
    }

    return x;
}

fn charToDigit(c: u8) !u8 {
    const value = switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => return error.InvalidCharacter,
    };

    return value;
}
```

Shell

$ zig test 15-errors-switch.zig
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/15-errors-switch.zig:4:40: error: switch must handle all possibilities
    \_ = parseInt("hi", 10) catch |err| switch (err) {};
                                       ^~~~~~~~~~~~~~~
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/15-errors-switch.zig:4:40: note: unhandled error value: 'error.Overflow'
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/15-errors-switch.zig:4:40: note: unhandled error value: 'error.InvalidCharacter'
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/15-errors-switch.zig:4:40: note: unhandled error value: 'error.DigitExceedsRadix'

The keyword [unreachable](https://ziglang.org/documentation/master/#unreachable) is used to assert that no errors will occur:

16-unreachable.zig

```
const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) void {
    const io = init.io;

    const file = Io.Dir.cwd().openFile(io, "does_not_exist/foo.txt", .{}) catch unreachable;
    defer file.close(io);

    var file_writer = file.writer(io, &.{});
    file_writer.interface.writeAll("all your codebase are belong to us\n") catch unreachable;
}
```

Shell

$ zig build-exe 16-unreachable.zig
$ ./16-unreachable
thread 3049921 panic: attempt to unwrap error: FileNotFound
error return context:
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/Io/Threaded.zig:4993:35: 0x11a0fa4 in dirOpenFilePosix (std.zig)
                        .NOENT => return error.FileNotFound,
                                  ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/Io/Dir.zig:581:5: 0x10374a0 in openFile (std.zig)
    return io.vtable.dirOpenFile(io.userdata, dir, sub\_path, options);
    ^

stack trace:
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/16-unreachable.zig:7:81: 0x11f2e21 in main (16-unreachable.zig)
    const file = Io.Dir.cwd().openFile(io, "does\_not\_exist/foo.txt", .{}) catch unreachable;
                                                                                ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:827:30: 0x11e904d in callMain (std.zig)
    return wrapMain(root.main(.{
                             ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:248:5: 0x11e86e1 in \_start (std.zig)
    asm volatile (switch (native\_arch) {
    ^
(process terminated by signal)

This invokes [undefined behavior](https://ziglang.org/learn/overview/#performance-and-safety-choose-two) in the unsafe build modes, so be sure to use it only when success is guaranteed.

### Stack traces on all targets

The stack traces and [error return traces](https://ziglang.org/documentation/master/#Error-Return-Traces) shown on this page work on all Tier 1 Support and some Tier 2 Support targets. [Even freestanding](https://andrewkelley.me/post/zig-stack-traces-kernel-panic-bare-bones-os.html)!

In addition, the standard library has the ability to capture a stack trace at any point and then dump it to standard error later:

17-stack-traces.zig

```
const std = @import("std");

var address_buffer: [8]usize = undefined;

var trace1: std.debug.StackTrace = .{
    .return_addresses = address_buffer[0..4],
    .skipped = .none,
};

var trace2: std.debug.StackTrace = .{
    .return_addresses = address_buffer[4..],
    .skipped = .none,
};

pub fn main() void {
    foo();
    bar();

    std.debug.print("first one:\n", .{});
    std.debug.dumpStackTrace(&trace1);
    std.debug.print("\n\nsecond one:\n", .{});
    std.debug.dumpStackTrace(&trace2);
}

fn foo() void {
    trace1 = std.debug.captureCurrentStackTrace(.{}, address_buffer[0..4]);
}

fn bar() void {
    trace2 = std.debug.captureCurrentStackTrace(.{}, address_buffer[4..]);
}
```

Shell

$ zig build-exe 17-stack-traces.zig
$ ./17-stack-traces
first one:
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/17-stack-traces.zig:26:48: 0x11ea96f in foo (17-stack-traces.zig)
    trace1 = std.debug.captureCurrentStackTrace(.{}, address\_buffer\[0..4\]);
                                               ^
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/17-stack-traces.zig:16:8: 0x11e937c in main (17-stack-traces.zig)
    foo();
       ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:788:64: 0x11e8cab in callMain (std.zig)
    if (fn\_info.param\_types.len == 0) return wrapMain(root.main());
                                                               ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:248:5: 0x11e86e1 in \_start (std.zig)
    asm volatile (switch (native\_arch) {
    ^
(additional stack frames may have been skipped...)

second one:
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/17-stack-traces.zig:30:48: 0x11e9b4f in bar (17-stack-traces.zig)
    trace2 = std.debug.captureCurrentStackTrace(.{}, address\_buffer\[4..\]);
                                               ^
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/17-stack-traces.zig:17:8: 0x11e9381 in main (17-stack-traces.zig)
    bar();
       ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:788:64: 0x11e8cab in callMain (std.zig)
    if (fn\_info.param\_types.len == 0) return wrapMain(root.main());
                                                               ^
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/start.zig:248:5: 0x11e86e1 in \_start (std.zig)
    asm volatile (switch (native\_arch) {
    ^
(additional stack frames may have been skipped...)

The standard library’s DebugAllocator uses this technique to report leaks and double frees.

## Generic data structures and functions

Types are values that must be known at compile-time:

18-types.zig

```
const std = @import("std");
const assert = std.debug.assert;

test "types are values" {
    const T1 = u8;
    const T2 = bool;
    assert(T1 != T2);

    const x: T2 = true;
    assert(x);
}
```

Shell

$ zig test 18-types.zig
1/1 18-types.test.types are values...OK
All 1 tests passed.

A generic data structure is simply a function that returns a `type`:

19-generics.zig

```
const std = @import("std");

fn List(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,
    };
}

pub fn main() void {
    var buffer: [10]i32 = undefined;
    var list: List(i32) = .{
        .items = &buffer,
        .len = 0,
    };
    list.items[0] = 1234;
    list.len += 1;

    std.debug.print("{d}\n", .{list.items.len});
}
```

Shell

$ zig build-exe 19-generics.zig
$ ./19-generics
10

## Compile-time reflection and compile-time code execution

The [@typeInfo](https://ziglang.org/documentation/master/#typeInfo) builtin function provides reflection:

20-reflection.zig

```
const std = @import("std");

const Header = struct {
    magic: u32,
    name: []const u8,
};

pub fn main() void {
    printInfoAboutStruct(Header);
}

fn printInfoAboutStruct(comptime T: type) void {
    const info = @typeInfo(T).@"struct";
    inline for (info.field_types, info.field_names) |FieldType, field_name| {
        std.debug.print(
            "{s} has a field called {s} with type {s}\n",
            .{
                @typeName(T),
                field_name,
                @typeName(FieldType),
            },
        );
    }
}
```

Shell

$ zig build-exe 20-reflection.zig
$ ./20-reflection
20-reflection.Header has a field called magic with type u32
20-reflection.Header has a field called name with type \[\]const u8

The Zig Standard Library uses this technique to implement formatted printing. Despite being a [Small, simple language](https://ziglang.org/learn/overview/#small-simple-language), Zig’s formatted printing is implemented entirely in Zig. Meanwhile, in C, compile errors for printf are hard-coded into the compiler. Similarly, in Rust, the formatted printing macro is hard-coded into the compiler.

Zig can also evaluate functions and blocks of code at compile-time. In some contexts, such as global variable initializations, the expression is implicitly evaluated at compile-time. Otherwise, one can explicitly evaluate code at compile-time with the [comptime](https://ziglang.org/documentation/master/#comptime) keyword. This can be especially powerful when combined with assertions:

21-comptime.zig

```
const std = @import("std");
const assert = std.debug.assert;

fn fibonacci(x: u32) u32 {
    if (x <= 1) return x;
    return fibonacci(x - 1) + fibonacci(x - 2);
}

test "compile-time evaluation" {
    var array: [fibonacci(6)]i32 = undefined;

    @memset(&array, 42);

    comptime {
        assert(array.len == 12345);
    }
}
```

Shell

$ zig test 21-comptime.zig
/home/ci/deps/zig-x86\_64-linux-0.17.0/lib/std/debug.zig:442:14: error: reached unreachable code
    if (!ok) unreachable; // assertion failure
             ^~~~~~~~~~~
/home/ci/.cache/act/b3e9cea477256f08/hostexecutor/zig-code/features/21-comptime.zig:15:15: note: called at comptime here
        assert(array.len == 12345);
        ~~~~~~^~~~~~~~~~~~~~~~~~~~

## Integration with C libraries without FFI/bindings

[@cImport](https://ziglang.org/documentation/master/#cImport) directly imports types, variables, functions, and simple macros for use in Zig. It even translates inline functions from C into Zig.

Here is an example of emitting a sine wave using [libsoundio](http://libsound.io/):

22-sine-wave.zig

```
const c = @cImport(@cInclude("soundio/soundio.h"));
const std = @import("std");

fn sio_err(err: c_int) !void {
    switch (err) {
        c.SoundIoErrorNone => {},
        c.SoundIoErrorNoMem => return error.NoMem,
        c.SoundIoErrorInitAudioBackend => return error.InitAudioBackend,
        c.SoundIoErrorSystemResources => return error.SystemResources,
        c.SoundIoErrorOpeningDevice => return error.OpeningDevice,
        c.SoundIoErrorNoSuchDevice => return error.NoSuchDevice,
        c.SoundIoErrorInvalid => return error.Invalid,
        c.SoundIoErrorBackendUnavailable => return error.BackendUnavailable,
        c.SoundIoErrorStreaming => return error.Streaming,
        c.SoundIoErrorIncompatibleDevice => return error.IncompatibleDevice,
        c.SoundIoErrorNoSuchClient => return error.NoSuchClient,
        c.SoundIoErrorIncompatibleBackend => return error.IncompatibleBackend,
        c.SoundIoErrorBackendDisconnected => return error.BackendDisconnected,
        c.SoundIoErrorInterrupted => return error.Interrupted,
        c.SoundIoErrorUnderflow => return error.Underflow,
        c.SoundIoErrorEncodingString => return error.EncodingString,
        else => return error.Unknown,
    }
}

var seconds_offset: f32 = 0;

fn write_callback(
    maybe_outstream: ?[*]c.SoundIoOutStream,
    frame_count_min: c_int,
    frame_count_max: c_int,
) callconv(.C) void {
    _ = frame_count_min;
    const outstream: *c.SoundIoOutStream = &maybe_outstream.?[0];
    const layout = &outstream.layout;
    const float_sample_rate: f32 = @floatFromInt(outstream.sample_rate);
    const seconds_per_frame = 1.0 / float_sample_rate;
    var frames_left = frame_count_max;

    while (frames_left > 0) {
        var frame_count = frames_left;

        var areas: [*]c.SoundIoChannelArea = undefined;
        sio_err(c.soundio_outstream_begin_write(
            maybe_outstream,
            @ptrCast(&areas),
            &frame_count,
        )) catch |err| std.debug.panic("write failed: {s}", .{@errorName(err)});

        if (frame_count == 0) break;

        const pitch = 440.0;
        const radians_per_second = pitch * 2.0 * std.math.pi;
        var frame: c_int = 0;
        while (frame < frame_count) : (frame += 1) {
            const float_frame: f32 = @floatFromInt(frame);
            const sample = std.math.sin((seconds_offset + float_frame *
                seconds_per_frame) * radians_per_second);
            {
                var channel: usize = 0;
                while (channel < @as(usize, @intCast(layout.channel_count))) : (channel += 1) {
                    const channel_ptr = areas[channel].ptr;
                    const sample_ptr: *f32 = @ptrCast(@alignCast(&channel_ptr[@intCast(areas[channel].step * frame)]));
                    sample_ptr.* = sample;
                }
            }
        }
        const float_frame_count: f32 = @floatFromInt(frame_count);
        seconds_offset += seconds_per_frame * float_frame_count;

        sio_err(c.soundio_outstream_end_write(maybe_outstream)) catch |err| std.debug.panic("end write failed: {s}", .{@errorName(err)});

        frames_left -= frame_count;
    }
}

pub fn main() !void {
    const soundio = c.soundio_create();
    defer c.soundio_destroy(soundio);

    try sio_err(c.soundio_connect(soundio));

    c.soundio_flush_events(soundio);

    const default_output_index = c.soundio_default_output_device_index(soundio);
    if (default_output_index < 0) return error.NoOutputDeviceFound;

    const device = c.soundio_get_output_device(soundio, default_output_index) orelse return error.OutOfMemory;
    defer c.soundio_device_unref(device);

    std.debug.print("Output device: {s}\n", .{device.*.name});

    const outstream = c.soundio_outstream_create(device) orelse return error.OutOfMemory;
    defer c.soundio_outstream_destroy(outstream);

    outstream.*.format = c.SoundIoFormatFloat32NE;
    outstream.*.write_callback = write_callback;

    try sio_err(c.soundio_outstream_open(outstream));

    try sio_err(c.soundio_outstream_start(outstream));

    while (true) c.soundio_wait_events(soundio);
}
```

```
$ zig build-exe sine.zig -lsoundio -lc
$ ./sine
Output device: Built-in Audio Analog Stereo
^C
```

[This Zig code is significantly simpler than the equivalent C code](https://gist.github.com/andrewrk/d285c8f912169329e5e28c3d0a63c1d8), as well as having more safety protections, and all this is accomplished by directly importing the C header file - no API bindings.

_Zig is better at using C libraries than C is at using C libraries._

### Zig is also a C compiler

Here’s an example of Zig building some C code:

hello.c

```
#include <stdio.h>

int main(int argc, char **argv) {
    printf("Hello world\n");
    return 0;
}
```

```
$ zig build-exe hello.c -lc
$ ./hello
Hello world
```

You can use `--verbose-cc` to see what C compiler command this executed:

```
$ zig build-exe hello.c -lc --verbose-cc
zig cc -MD -MV -MF .zig-cache/tmp/42zL6fBH8fSo-hello.o.d -nostdinc -fno-spell-checking -isystem /home/andy/dev/zig/build/lib/zig/include -isystem /home/andy/dev/zig/build/lib/zig/libc/include/x86_64-linux-gnu -isystem /home/andy/dev/zig/build/lib/zig/libc/include/generic-glibc -isystem /home/andy/dev/zig/build/lib/zig/libc/include/x86_64-linux-any -isystem /home/andy/dev/zig/build/lib/zig/libc/include/any-linux-any -march=native -g -fstack-protector-strong --param ssp-buffer-size=4 -fno-omit-frame-pointer -o .zig-cache/tmp/42zL6fBH8fSo-hello.o -c hello.c -fPIC
```

Note that if you run the command again, there is no output, and it finishes instantly:

```
$ time zig build-exe hello.c -lc --verbose-cc

real	0m0.027s
user	0m0.018s
sys	0m0.009s
```

This is thanks to [Build Artifact Caching](https://ziglang.org/download/0.4.0/release-notes.html#Build-Artifact-Caching). Zig automatically parses the .d file using a robust caching system to avoid duplicating work.

Not only can Zig compile C code, but there is a very good reason to use Zig as a C compiler: [Zig ships with libc](https://ziglang.org/learn/overview/#zig-ships-with-libc).

### Export functions, variables, and types for C code to depend on

One of the primary use cases for Zig is exporting a library with the C ABI for other programming languages to call into. The `export` keyword in front of functions, variables, and types causes them to be part of the library API:

23-math-test.zig

```
export fn add(a: i32, b: i32) i32 {
    return a + b;
}
```

To make a static library:

```
$ zig build-lib mathtest.zig
```

To make a shared library:

```
$ zig build-lib mathtest.zig -dynamic
```

Here is an example with the [Zig Build System](https://ziglang.org/learn/overview/#zig-build-system):

test.c

```
#include "mathtest.h"
#include <stdio.h>

int main(int argc, char **argv) {
    int32_t result = add(42, 1337);
    printf("%d\n", result);
    return 0;
}
```

24-build.zig

```
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const lib = b.addSharedLibrary("mathtest", "mathtest.zig", b.version(1, 0, 0));

    const exe = b.addExecutable("test", null);
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c99"});
    exe.linkLibrary(lib);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    const run_cmd = exe.run();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run_cmd.step);
}
```

```
$ zig build test
1379
```

## Cross-compiling is a first-class use case

Zig builds for all supported targets independently of the host. There is no separate “cross toolchain” or anything like that. Here’s a native Hello World:

4-hello.zig

```
const std = @import("std");

pub fn main() void {
    std.debug.print("Hello, world!\n", .{});
}
```

Shell

$ zig build-exe 4-hello.zig
$ ./4-hello
Hello, world!

Now to build it for x86\_64-windows, x86\_64-macos, and aarch64-linux:

```
$ zig build-exe hello.zig -target x86_64-windows
$ file hello.exe
hello.exe: PE32+ executable (console) x86-64, for MS Windows
$ zig build-exe hello.zig -target x86_64-macos
$ file hello
hello: Mach-O 64-bit x86_64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|PIE>
$ zig build-exe hello.zig -target aarch64-linux
$ file hello
hello: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), statically linked, with debug_info, not stripped
```

This works on any Tier 3+ target, for any Tier 3+ target.

### Zig ships with libc

You can find the available libc targets with `zig targets`:

```
...
.libc = .{
  "arc-linux-gnu",
  "arm-freebsd-eabihf",
  "arm-linux-gnueabi",
  "arm-linux-gnueabihf",
  "arm-linux-musleabi",
  "arm-linux-musleabihf",
  "arm-netbsd-eabi",
  "arm-netbsd-eabihf",
  "armeb-linux-gnueabi",
  "armeb-linux-gnueabihf",
  "armeb-linux-musleabi",
  "armeb-linux-musleabihf",
  "armeb-netbsd-eabi",
  "armeb-netbsd-eabihf",
  "thumb-linux-musleabi",
  "thumb-linux-musleabihf",
  "thumb-windows-gnu",
  "thumbeb-linux-musleabi",
  "thumbeb-linux-musleabihf",
  "aarch64-freebsd-none",
  "aarch64-linux-gnu",
  "aarch64-linux-musl",
  "aarch64-maccatalyst-none",
  "aarch64-macos-none",
  "aarch64-netbsd-none",
  "aarch64-windows-gnu",
  "aarch64_be-linux-gnu",
  "aarch64_be-linux-musl",
  "aarch64_be-netbsd-none",
  "csky-linux-gnueabi",
  "csky-linux-gnueabihf",
  "hexagon-linux-musl",
  "loongarch64-linux-gnu",
  "loongarch64-linux-gnusf",
  "loongarch64-linux-musl",
  "loongarch64-linux-muslsf",
  "m68k-linux-gnu",
  "m68k-linux-musl",
  "m68k-netbsd-none",
  "mips-linux-gnueabi",
  "mips-linux-gnueabihf",
  "mips-linux-musleabi",
  "mips-linux-musleabihf",
  "mips-netbsd-eabi",
  "mips-netbsd-eabihf",
  "mipsel-linux-gnueabi",
  "mipsel-linux-gnueabihf",
  "mipsel-linux-musleabi",
  "mipsel-linux-musleabihf",
  "mipsel-netbsd-eabi",
  "mipsel-netbsd-eabihf",
  "mips64-linux-gnuabi64",
  "mips64-linux-gnuabin32",
  "mips64-linux-muslabi64",
  "mips64-linux-muslabin32",
  "mips64el-linux-gnuabi64",
  "mips64el-linux-gnuabin32",
  "mips64el-linux-muslabi64",
  "mips64el-linux-muslabin32",
  "powerpc-linux-gnueabi",
  "powerpc-linux-gnueabihf",
  "powerpc-linux-musleabi",
  "powerpc-linux-musleabihf",
  "powerpc-netbsd-eabi",
  "powerpc-netbsd-eabihf",
  "powerpc64-freebsd-none",
  "powerpc64-linux-gnu",
  "powerpc64-linux-musl",
  "powerpc64le-freebsd-none",
  "powerpc64le-linux-gnu",
  "powerpc64le-linux-musl",
  "riscv32-linux-gnu",
  "riscv32-linux-musl",
  "riscv64-freebsd-none",
  "riscv64-linux-gnu",
  "riscv64-linux-musl",
  "s390x-linux-gnu",
  "s390x-linux-musl",
  "sparc-linux-gnu",
  "sparc-netbsd-none",
  "sparc64-linux-gnu",
  "sparc64-netbsd-none",
  "wasm32-wasi-musl",
  "x86-freebsd-none",
  "x86-linux-gnu",
  "x86-linux-musl",
  "x86-netbsd-none",
  "x86-windows-gnu",
  "x86_64-freebsd-none",
  "x86_64-linux-gnu",
  "x86_64-linux-gnux32",
  "x86_64-linux-musl",
  "x86_64-linux-muslx32",
  "x86_64-maccatalyst-none",
  "x86_64-macos-none",
  "x86_64-netbsd-none",
  "x86_64-windows-gnu",
},
...
```

This means `-lc` for these targets _does not depend on any system files_!

Let’s look at that [C hello world example](https://ziglang.org/learn/overview/#zig-is-also-a-c-compiler) again:

```
$ zig build-exe hello.c -lc
$ ./hello
Hello world
$ ldd ./hello
	linux-vdso.so.1 (0x00007ffd03dc9000)
	libc.so.6 => /lib/libc.so.6 (0x00007fc4b62be000)
	libm.so.6 => /lib/libm.so.6 (0x00007fc4b5f29000)
	libpthread.so.0 => /lib/libpthread.so.0 (0x00007fc4b5d0a000)
	libdl.so.2 => /lib/libdl.so.2 (0x00007fc4b5b06000)
	librt.so.1 => /lib/librt.so.1 (0x00007fc4b58fe000)
	/lib/ld-linux-x86-64.so.2 => /lib64/ld-linux-x86-64.so.2 (0x00007fc4b6672000)
```

[glibc](https://www.gnu.org/software/libc/) does not support building statically, but [musl](https://www.musl-libc.org/) does:

```
$ zig build-exe hello.c -lc -target x86_64-linux-musl
$ ./hello
Hello world
$ ldd hello
  not a dynamic executable
```

In this example, Zig built musl libc from source and then linked against it. The build of musl libc for x86\_64-linux remains available thanks to the [caching system](https://ziglang.org/download/0.4.0/release-notes.html#Build-Artifact-Caching), so any time this libc is needed again it will be available instantly.

This means that this functionality is available on any platform. Windows and macOS users can build Zig and C code, and link against libc, for any of the targets listed above. Similarly code can be cross compiled for other architectures:

```
$ zig build-exe hello.c -lc -target aarch64-linux-gnu
$ file hello
hello: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, for GNU/Linux 2.0.0, with debug_info, not stripped
```

Zig is a better C compiler than C compilers!

This functionality is more than bundling a cross-compilation toolchain along with Zig. For example, the total size of libc headers that Zig ships is 130 MiB uncompressed. Meanwhile, the headers for musl libc + linux headers on x86\_64 alone are 8 MiB, and for glibc are 3.1 MiB (glibc is missing the linux headers), yet Zig currently ships with 97 libcs. With a naive bundling that would be 776 MiB. However, thanks to this [process\_headers tool](https://codeberg.org/ziglang/zig/src/commit/0.15.2/tools/process_headers.zig), and some [good old manual labor](https://codeberg.org/ziglang/infra/src/branch/master/libc-update), Zig binary tarballs remain roughly 50 MiB total, despite supporting libc for all these targets, as well as compiler-rt, libunwind, libcxx, and libtsan, and despite being a clang-compatible C compiler. For comparison, the Windows binary build of clang 8.0.0 itself from llvm.org is 132 MiB.

## Zig Build System and Package Manager

Zig comes with a build system, so you don’t need a separate tool to orchestrate your build process.

```
$ zig init
info: created build.zig
info: created build.zig.zon
info: created src/main.zig
info: created src/root.zig
info: see `zig build --help` for a menu of options
```

25-all-bases.zig

```
const std = @import("std");

pub fn main() !void {
    std.debug.print("All your base are belong to us.\n", .{});
}
```

26-build.zig

```
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("example", "src/main.zig");
    exe.setBuildMode(mode);

    const run_cmd = exe.run();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
```

Let’s have a look at that `--help` menu.

```
$ zig build --help
Usage: zig build [steps] [options]

Steps:
  install (default)            Copy build artifacts to prefix path
  uninstall                    Remove build artifacts from prefix path
  run                          Run the app
  test                         Run tests

Project-Specific Options:
  -Dtarget=[string]            The CPU architecture, OS, and ABI to build for
  -Dcpu=[string]               Target CPU features to add or subtract
  -Dofmt=[string]              Target object format
  -Ddynamic-linker=[string]    Path to interpreter on the target system
  -Doptimize=[enum]            Prioritize performance, safety, or binary size
                                 Supported Values:
                                   Debug
                                   ReleaseSafe
                                   ReleaseFast
                                   ReleaseSmall

System Integration Options:
  --search-prefix [path]       Add a path to look for binaries, libraries, headers
  --sysroot [path]             Set the system root directory (usually /)
  --libc [file]                Provide a file which specifies libc paths

  --system [pkgdir]            Disable package fetching; enable all integrations
  -fsys=[name]                 Enable a system integration
  -fno-sys=[name]              Disable a system integration

  Available System Integrations:                Enabled:
  (none)                                        -

General Options:
  -p, --prefix [path]          Where to install files (default: zig-out)
  --prefix-lib-dir [path]      Where to install libraries
  --prefix-exe-dir [path]      Where to install executables
  --prefix-include-dir [path]  Where to install C header files

  --release[=mode]             Request release mode, optionally specifying a
                               preferred optimization mode: fast, safe, small

  -fdarling,  -fno-darling     Integration with system-installed Darling to
                               execute macOS programs on Linux hosts
                               (default: no)
  -fqemu,     -fno-qemu        Integration with system-installed QEMU to execute
                               foreign-architecture programs on Linux hosts
                               (default: no)
  --libc-runtimes [path]       Enhances QEMU integration by providing dynamic libc
                               (e.g. glibc or musl) built for multiple foreign
                               architectures, allowing execution of non-native
                               programs that link with libc.
  -frosetta,  -fno-rosetta     Rely on Rosetta to execute x86_64 programs on
                               ARM64 macOS hosts. (default: no)
  -fwasmtime, -fno-wasmtime    Integration with system-installed wasmtime to
                               execute WASI binaries. (default: no)
  -fwine,     -fno-wine        Integration with system-installed Wine to execute
                               Windows programs on Linux hosts. (default: no)

  -h, --help                   Print this help and exit
  -l, --list-steps             Print available steps
  --verbose                    Print commands before executing them
  --color [auto|off|on]        Enable or disable colored error messages
  --error-style [style]        Control how build errors are printed
    verbose                    (Default) Report errors with full context
    minimal                    Report errors after summary, excluding context like command lines
    verbose_clear              Like 'verbose', but clear the terminal at the start of each update
    minimal_clear              Like 'minimal', but clear the terminal at the start of each update
  --multiline-errors [style]   Control how multi-line error messages are printed
    indent                     (Default) Indent non-initial lines to align with initial line
    newline                    Include a leading newline so that the error message is on its own lines
    none                       Print as usual so the first line is misaligned
  --summary [mode]             Control the printing of the build summary
    all                        Print the build summary in its entirety
    new                        Omit cached steps
    failures                   (Default if short-lived) Only print failed steps
    line                       (Default if long-lived) Only print the single-line summary
    none                       Do not print the build summary
  -j<N>                        Limit concurrent jobs (default is to use all CPU cores)
  --maxrss <bytes>             Limit memory usage (default is to use available memory)
  --skip-oom-steps             Instead of failing, skip steps that would exceed --maxrss
  --test-timeout <timeout>     Limit execution time of unit tests, terminating if exceeded.
                               The timeout must include a unit: ns, us, ms, s, m, h
  --fetch[=mode]               Fetch dependency tree (optionally choose laziness) and exit
    needed                     (Default) Lazy dependencies are fetched as needed
    all                        Lazy dependencies are always fetched
  --watch                      Continuously rebuild when source files are modified
  --debounce <ms>              Delay before rebuilding after changed file detected
  --webui[=ip]                 Enable the web interface on the given IP address
  --fuzz[=limit]               Continuously search for unit test failures with an optional
                               limit to the max number of iterations. The argument supports
                               an optional 'K', 'M', or 'G' suffix (e.g. '10K'). Implies
                               '--webui' when no limit is specified.
  --time-report                Force full rebuild and provide detailed information on
                               compilation time of Zig source code (implies '--webui')
     -fincremental             Enable incremental compilation
  -fno-incremental             Disable incremental compilation

Advanced Options:
  -freference-trace[=num]      How many lines of reference trace should be shown per compile error
  -fno-reference-trace         Disable reference trace
  -fallow-so-scripts           Allows .so files to be GNU ld scripts
  -fno-allow-so-scripts        (default) .so files must be ELF files
  --build-file [file]          Override path to build.zig
  --cache-dir [path]           Override path to local Zig cache directory
  --global-cache-dir [path]    Override path to global Zig cache directory
  --zig-lib-dir [arg]          Override path to Zig lib directory
  --build-runner [file]        Override path to build runner
  --seed [integer]             For shuffling dependency traversal order (default: random)
  --build-id[=style]           At a minor link-time expense, embeds a build ID in binaries
      fast                     8-byte non-cryptographic hash (COFF, ELF, WASM)
      sha1, tree               20-byte cryptographic hash (ELF, WASM)
      md5                      16-byte cryptographic hash (ELF)
      uuid                     16-byte random UUID (ELF, WASM)
      0x[hexstring]            Constant ID, maximum 32 bytes (ELF, WASM)
      none                     (default) No build ID
  --debug-log [scope]          Enable debugging the compiler
  --debug-pkg-config           Fail if unknown pkg-config flags encountered
  --debug-rt                   Debug compiler runtime libraries
  --verbose-link               Enable compiler debug output for linking
  --verbose-air                Enable compiler debug output for Zig AIR
  --verbose-llvm-ir[=file]     Enable compiler debug output for LLVM IR
  --verbose-llvm-bc=[file]     Enable compiler debug output for LLVM BC
  --verbose-cimport            Enable compiler debug output for C imports
  --verbose-cc                 Enable compiler debug output for C compilation
  --verbose-llvm-cpu-features  Enable compiler debug output for LLVM CPU features
```

You can see that one of the available steps is run.

```
$ zig build run
All your codebase are belong to us.
Run `zig build test` to run the tests.
```

Here are some example build scripts:

-   [Build script of OpenGL Tetris game](https://github.com/andrewrk/tetris/blob/master/build.zig)
-   [Build script of bare metal Raspberry Pi 3 arcade game](https://github.com/andrewrk/clashos/blob/master/build.zig)
-   [Build script of Zig compiler](https://codeberg.org/ziglang/zig/src/branch/master/build.zig)

## Wide range of targets supported

Zig uses a “support tier” system to communicate the level of support for different targets.

[Support Table as of Zig 0.15](https://ziglang.org/download/0.15.1/release-notes.html#Target-Support)

## Friendly toward package maintainers

Even though Zig is self-hosted, building from source only depends on system C/C++ toolchain and LLVM, using standard CMake build steps thanks to [a WebAssembly based bootstrap process](https://ziglang.org/news/goodbye-cpp/).

For those distributions that want to avoid binary blobs, there is a well-documented set of steps to [reproduce Zig without binaries](https://jakstys.lt/2024/zig-reproduced-without-binaries/).

In the future, we hope to inspire a third party to implement a Zig interpreter written in C that can reduce this to O(1) step.

The build system acknowledges system integration as an explicit intent. For example, the `--system <path>` flag disables package fetching and enables all `-fsys=[name]` options. Those “system integration options” are available in build scripts, allowing package maintainers and upstream developers to cooperate. Fewer patches for package maintainers, and upstream authors can make intentional choices in response to system integration build configuration.

Non-debug [build modes](https://ziglang.org/documentation/master/#Build-Mode) are reproducible/deterministic.

There is a [JSON version of the download page](https://ziglang.org/download/index.json).

This page is also available in the following languages:  

[English (original)](https://ziglang.org/learn/overview/) [Español](https://ziglang.org/es-AR/learn/overview/) [Русский](https://ziglang.org/ru-RU/learn/overview/) [Italiano](https://ziglang.org/it-IT/learn/overview/) [Deutsch](https://ziglang.org/de-DE/learn/overview/) [Українська](https://ziglang.org/uk-UA/learn/overview/) [日本語](https://ziglang.org/ja-JP/learn/overview/) [中文](https://ziglang.org/zh-CN/learn/overview/) [한국어](https://ziglang.org/ko-KR/learn/overview/)
