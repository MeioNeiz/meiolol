# 6. Errors

## 6.1 Four ways to consume an error

`try` to propagate; `catch value` or a labelled block for a default; `catch unreachable`
only as an assertion you can prove; `if ... else |err| switch` or `catch |err| switch` to
branch. Ignoring one is a compile error [[zig-langref-017-b#^f3]],
[[zig-langref-017-b#^f5]].

```zig
// research/raw/zig-langref-017.md:7171
fn doAnotherThing(str: []u8) error{InvalidChar}!void {
    if (parseU64(str, 10)) |number| {
        doSomethingWithNumber(number);
    } else |err| switch (err) {
        error.Overflow => {
            // handle overflow...
        },
        else => |leftover_err| return leftover_err,
    }
}
```

Discards are separate syntax on purpose: `_ = x` for values, `catch {}` for errors, so a
function that becomes fallible can't have its error dropped silently
[[matklad-error-codes-control-flow#^f6]].

Don't `try` everything up to `main` in an app: decide what is recoverable, or the program
might as well panic [[ziggit-code-smells#^f1]].

## 6.2 Error sets: inferred inside, named at boundaries, never anyerror

Inferred sets (`!T`) make a function generic over its errors; explicit sets are needed
for function pointers, recursion and public API [[zig-langref-017-b#^f10]]. `anyerror`
hides the possible errors from docs and exhaustive switches [[zig-langref-017-b#^f2]].
The std names sets, documents each error, and composes them with `||`
[[zig-std-allocators#^f26]]:

```zig
// ziglang/zig lib/std/process.zig:60 @ 0.17.0
pub const CurrentPathError = error{
    /// Buffer is too small to contain the current path.
    NameTooLong,
    /// Not possible on Windows. Always returned on WASI.
    CurrentDirUnlinked,
    /// The current path cannot be retrieved due to a limitation of the
    /// underlying libc or syscall implementation. Retrying with a larger
    /// buffer will not succeed.
    PathExceedsLimit,
} || Io.Cancelable || Io.UnexpectedError;
```

ZLS has 185 `error{OutOfMemory}` signatures; a parser that cannot fail says so with
`error{}!T` (zig-clap) [[zls-repo#^f18]]. Never persist error integers: numbering changes
with the source [[zig-langref-017-b#^f14]].

## 6.3 Compare errors with switch, never ==

`err == error.Foo` upcasts to `anyerror`, so a renamed or misspelt error still compiles.
TigerBeetle's lint bans `== error.` and `!= error.` [[tigerbeetle-tidy#^f4]].

## 6.4 Translate at boundaries with an exhaustive switch

When an inner error can only mean one thing, map it explicitly; if the inner set grows,
the switch stops compiling. `catch unreachable` would hide that
[[zig-std-containers#^f14]]:

```zig
// ziglang/zig lib/std/mem/Allocator.zig:506 @ 0.17.0
pub fn print(a: Allocator, comptime format: []const u8, args: anytype) Error![]u8 {
    var aw = try std.Io.Writer.Allocating.initCapacity(a, format.len);
    defer aw.deinit();
    aw.writer.print(format, args) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
    };
    return aw.toOwnedSlice();
}
```

Ghostty does the same for errors that can only mean internal corruption: list every
member with no `else`, then panic [[ghostty-repo#^f31]]:

```zig
// ghostty src/terminal/PageList.zig:181 @ 08a9518
                const page_ = compressed.cloneBuf(memory) catch |err| {
                    // The encoded data was produced by our codec and remains
                    // immutable while compressed. Failure is internal
                    // corruption, matching the normal restoration boundary.
                    switch (err) {
                        error.TruncatedInput,
                        error.InvalidOffset,
                        error.OutputTooSmall,
                        error.OutputSizeMismatch,
                        => {},
                    }

                    alloc.free(memory);
                    log.err("failed to clone compressed page err={}", .{err});
                    @panic("failed to clone compressed terminal page");
                };
```

## 6.5 Errors are codes; details travel out of band

Zig errors carry no payload, by design: a handling type needs one variant per recovery
path; payloads would bloat every `E!T` return [[matklad-error-codes-control-flow#^f2]],
[[matklad-error-abi#^f1]]. Five shapes in respected code, all agreeing that the detail
goes beside the error:

1. **Opaque interface error, detail on the implementation.** Generic code over
   `*Io.Writer` sees one error; the concrete writer keeps the OS error
   [[zig-std-io#^f11]], [[zig-std-io#^f12]]:

```zig
// ziglang/zig lib/std/Io/Writer.zig:91 @ 0.17.0
pub const Error = error{
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

// ziglang/zig lib/std/Io/File/Writer.zig:123 @ 0.17.0
fn drainStreaming(w: *Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
    const io = w.io;
    const header = w.interface.buffered();
    const n = w.file.writeStreaming(io, header, data, splat) catch |err| {
        w.err = err;
        return error.WriteFailed;
    };
    w.pos += n;
    return w.interface.consume(n);
}
```

2. **Optional Diagnostics out-parameter.** std.zon, std.json, zig-clap. The caller who
   handles passes null [[zig-clap-repo#^f8]], [[ziggit-error-payload-data#^f1]]:

```zig
// zig-clap example/simple.zig:15 @ 05faf390
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, init.minimal.args, .{
        .diagnostic = &diag,
        .allocator = init.gpa,
    }) catch |err| {
        // Report useful error and exit.
        try diag.reportToFile(init.io, .stderr(), err);
        return err;
    };
    defer res.deinit();
```

3. **Diagnostics factory** (matklad, TigerBeetle tidy): a struct of `add_*` constructor
   functions; callers pass what they have, every site is greppable, tests capture output,
   and the returned error is deliberately independent of which diagnostic was added
   [[matklad-diagnostics-factory#^f1]], [[matklad-diagnostics-factory#^f4]]:

```zig
// research/raw/matklad-diagnostics-factory.md:91 (TigerBeetle tidy.zig)
fn emit(
    errors: *Errors,
    comptime fmt: []const u8,
    args: anytype,
) void {
    comptime assert(fmt[fmt.len - 1] == '\n');
    errors.count += 1;
    if (errors.captured) |*captured| {
        captured.writer(errors.gpa).print(fmt, args)
            catch @panic("OOM");
    } else {
        std.debug.print(fmt, args);
    }
}
```

4. **Reported, then a marker error.** SuperHTML writes the message and returns
   `error.Fatal`, meaning "already reported" [[superhtml-repo#^f17]].

5. **User-input errors as a list; only OOM returns.** A config with five typos reports
   five, with file and line, and still loads [[ghostty-repo#^f33]].

## 6.6 Context with errdefer log, in tool code

```zig
// research/raw/matklad-error-context.md:12
fn process_file(io: Io, path: []const u8) !void {
    errdefer log.err("path={s}", .{path});

    const fd = try Io.Dir.cwd().openFile(io, path, .{});
    defer fd.close(io);

    // ...
}
```

Plain `try`s stay, context stacks across frames. The drawback: it logs even when a caller
later handles the error, `error.Canceled` included, so not in library code
[[matklad-error-context#^f4]], [[matklad-error-context#^f5]]. TigerBeetle uses an errdefer
to log the likely cause of an init failure [[tigerbeetle-code#^f32]].

## 6.7 No `errdefer |err|` in 0.17: split the function

```zig
// research/raw/zig-017-release-notes.md:731 (upgrade diff)
 fn processOneTarget(job: Job) void {
-    errdefer |err| std.debug.panic("panic: {s}", .{@errorName(err)});
+    processOneTargetInner(job) catch |err| std.debug.panic("panic: {s}", .{@errorName(err)});
+}
+fn processOneTargetInner(job: Job) !void {
     const target = job.target;
```

[[zig-017-release-notes#^f21]]. TigerBeetle (on 0.16) still uses the capture form.

## 6.8 One place ends the chain

User-facing failures get a message and an exit code, not a stack trace: `std.process.fatal`
or a `noreturn` helper at the top [[zls-repo#^f20]], [[river-repo#^f14]]:

```zig
// river river/main.zig:225 @ 13752403
    Io.Dir.cwd().access(io, path, .{ .execute = true }) catch |err| {
        switch (err) {
            error.FileNotFound => log.debug("no init file found at path {s}", .{path}),
            error.PermissionDenied, error.AccessDenied => fatal("failed to run init executable {s}: the file is not executable", .{path}),
            else => fatal("failed to run init executable {s}: {t}", .{ path, err }),
        }
        util.gpa.free(path);
        return null;
    };
```

At C callback boundaries errors stop: River reports OOM to the Wayland client with
`postNoMemory()` [[river-repo#^f12]].

## 6.9 Error return traces

`try` everywhere stays debuggable: traces show every return point and cost almost
nothing on the success path. They are on by default only in debug builds, so a crash
report from a safe build has none unless enabled [[zig-langref-017-b#^f11]],
[[zig-langref-017-b#^f12]].
