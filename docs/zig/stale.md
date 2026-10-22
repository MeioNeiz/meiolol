# 17. Stale advice: old idiom to 0.17 idiom

Most Zig on the web predates at least one of these. Merged from the release notes
0.11-0.17 and the readers' checks against the 0.17 std.

| Old | 0.17 | Since |
| --- | --- | --- |
| `@intCast(u8, x)` (type argument) | `@intCast(x)` with a result type, `@as(T, @intCast(x))` if none | 0.11 |
| `for (a) \|x, i\|` | `for (a, 0..) \|x, i\|`, `for (a, b) \|x, *y\|` | 0.11 |
| `addTest` runs tests | `b.addRunArtifact(test_exe)` | 0.11 |
| `var` for never-mutated locals | `const` (compile error) | 0.12 |
| `@fieldParentPtr(Parent, "f", p)` | `const p: *Parent = @alignCast(@fieldParentPtr("f", ptr))` | 0.12 |
| `std.os.*` | `std.posix` (0.12), then `std.Io` or `std.posix.system` (0.16) | 0.12, 0.16 |
| `pub const std_options = struct {...}` | `pub const std_options: std.Options = .{...}` | 0.12 |
| `.{ .path = "src/main.zig" }` | `b.path("src/main.zig")` | 0.12 |
| `std.ComptimeStringMap` | `std.StaticStringMap(T).initComptime(kvs)` | 0.13 |
| `zig-cache/` | `.zig-cache/` | 0.13 |
| containers initialised `= .{}` | `= .empty` | 0.14 |
| `GeneralPurposeAllocator(.{}){}` | `DebugAllocator` (0.14), `init.gpa` (0.16), `SafeAllocator` (0.17) | 0.14-0.17 |
| `@setCold(true)` | `@branchHint(.cold)` as the first statement | 0.14 |
| `@typeInfo(T).Struct` | `.@"struct"`, then 0.17 struct-of-arrays `field_names` | 0.14, 0.17 |
| `std.meta.FieldType` | `@FieldType` | 0.14 |
| `std.mem.page_size` | `std.heap.pageSize()` | 0.14 |
| `addStaticLibrary`, `addSharedLibrary` | `addLibrary(.{ .linkage = ... })` | 0.14 |
| `addExecutable(.{ .root_source_file })` | `.root_module = b.createModule(...)` | 0.14, removed 0.15 |
| `popOrNull`, `mem.split`, `std.rand`, `TailQueue` | `pop`, `splitScalar`, `std.Random`, `DoublyLinkedList` | 0.14 |
| `std.ArrayList(T).init(gpa)`, `list.deinit()` | `.empty`, `list.append(gpa, x)`, `list.deinit(gpa)` | 0.15 |
| `usingnamespace` | plain declarations, `{}` sentinels, zero-bit field + `@fieldParentPtr` mixins | 0.15 |
| `async`/`await`/`suspend` | `io.async`, `Future.await(io)` / `cancel(io)` | 0.15, 0.16 |
| `writer: anytype`, `GenericWriter`, `AnyWriter`, `bufferedWriter` | `*std.Io.Writer` over a caller buffer, then `flush()` | 0.15 |
| `std.io.getStdOut().writer()` | `Io.File.Writer.init(.stdout(), io, &buf)`, `&w.interface` | 0.15, 0.16 |
| `format(self, comptime fmt, options, writer)`, `{}` | `format(self, w: *std.Io.Writer) std.Io.Writer.Error!void`, `{f}` | 0.15 |
| `fmtSliceHexLower`, `fmtIntSizeDec`, `@tagName` in `{s}` | `{x}`, `{B}`, `{t}` | 0.15 |
| `std.BoundedArray(T, n)` | caller slice, or `ArrayList.initBuffer(&buf)` + `appendBounded` | 0.15 |
| `LinearFifo`, `RingBuffer` | `std.Io.Reader` / `Writer` | 0.15 |
| `fixedBufferStream(data).reader()` | `std.Io.Reader.fixed(data)` | 0.16 |
| `std.Thread.Pool` + `WaitGroup` | `std.Io.Group`, `io.async` | 0.16 |
| `std.Thread.Mutex`, `Condition`, `ResetEvent` | `std.Io.Mutex`, `Io.Condition`, `Io.Event` | 0.16 |
| `std.os.environ`, `argsAlloc` | `init.environ_map`, `init.minimal.args` | 0.16 |
| `std.crypto.random`, `std.time.Timer` | `io.random` / `randomSecure`, `std.Io.Timestamp` | 0.16 |
| `std.fs.cwd()`, `std.fs.File`, `file.close()` | `std.Io.Dir.cwd()`, `std.Io.File`, `file.close(io)` | 0.16 |
| `ThreadSafeAllocator` | lock-free allocators (ArenaAllocator is thread-safe) | 0.16 |
| `@Type(.{ .int = ... })`, `std.meta.Int` | `@Int(.unsigned, n)`, `@Struct`, `@Enum`, `@Union`, `@Tuple` | 0.16 |
| `@intFromFloat(x)` | `@trunc(x)` (or `@round`, `@floor`) into an int result type | 0.16 |
| `std.mem.indexOf*` | `std.mem.find*` (deprecated aliases still compile) | 0.16 |
| `AutoArrayHashMapUnmanaged` | `std.array_hash_map.Auto` | 0.16 |
| fuzz `fn(ctx, input: []const u8)` | `fn(ctx, smith: *std.testing.Smith)` | 0.16 |
| `@cImport` | translate-c package from build.zig | removed 0.17 |
| `[1]u8{0} ** n` | `@splat(0)` with an array result type | removed 0.17 |
| `@intFromEnum`, `@enumFromInt` | `@backingInt`, `@fromBackingInt` (zig fmt rewrites) | 0.17 |
| `std.builtin`, `OptimizeMode.ReleaseFast` | `std.lang`, `Optimize.fast` | 0.17 |
| `builtin.mode`, `builtin.os`, `.cpu` | `builtin.optimize`, `builtin.target.os`, `.target.cpu` | 0.17 |
| `std.fmt.allocPrint(a, ...)`, `bufPrint` | `a.print(...)`, `std.mem.print` | 0.17 |
| `Allocator.dupeZ`, `fmt.bufPrintZ` | `dupeSentinel(.., 0)`, `mem.printSentinel(.., 0)` | 0.17 |
| `errdefer \|err\| ...` | split the function, `inner() catch \|err\| ...` | 0.17 |
| `void{}` | `{}` | 0.17 |
| `std.meta.fieldNames`, `inline for (info.fields)` | `@typeInfo(T).@"struct".field_names` / `field_types` | 0.17 |
| `std.math.divCeil(a, b) catch unreachable` | `@divCeil(a, b)` | 0.17 |
| `bit_set.IntegerBitSet.initEmpty()` | `bit_set.Integer.empty` | 0.17 |
| `list.getLast()` | `list.last().?` | 0.17 |
| `std.heap.stackFallback(n, gpa)` | `BufferFirstAllocator.init(buf, gpa)` | 0.17 |
| `if (b.args) \|a\| run.addArgs(a)` | `run.addPassthruArgs()` | 0.17 |
| `@bitCast` to type-pun an extern struct | `@ptrCast` or an extern union | 0.17 |
| `@hasDecl` feature detection | `{}` sentinel; `@hasDecl` sees only pub decls | 0.15, 0.17 |
| `std.zon.parse.fromSlice(T, gpa, src, &diag, .{})` | `fromSlice(T, .{ .gpa, .arena, .source, .diagnostics })` | 0.17 |
| `-Dno-bin` for incremental on ELF | plain `-fincremental --watch` | 0.16 |
| `callconv(.C)` | `callconv(.c)` | 0.14 |
