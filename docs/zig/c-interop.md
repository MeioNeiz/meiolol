# 14. C interop

- `@cImport` is removed in 0.17: translate headers through the translate-c package from
  build.zig (`b.addTranslateC` still works but is deprecated) [[zig-017-release-notes#^f1]].
  River already does [[river-repo#^f18]]:

```zig
// river build.zig:165 @ 13752403
    const translate_c: Translator = .init(b.dependency("translate_c", .{}), .{
        .name = "c",
        .c_source_file = b.path("river/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.linkSystemLibrary("libevdev", .{});
    translate_c.linkSystemLibrary("libinput", .{});
```

- run translate-c with the real build's target and cflags [[zig-langref-017-b#^f91]]
- keep `[*c]T` inside generated bindings; convert at the boundary to `*T`, `[*]T`,
  slices or optionals [[zig-langref-017-b#^f90]]:

```zig
// research/raw/zig-langref-017.md:14125
export fn decode_base_64(
    dest_ptr: [*]u8,
    dest_len: usize,
    source_ptr: [*]const u8,
    source_len: usize,
) usize {
    const src = source_ptr[0..source_len];
    const dest = dest_ptr[0..dest_len];
```

- `opaque` types for C handles; enums crossing the ABI need an explicit tag type; C
  strings are `[*:0]const u8`; C `void` is `anyopaque` [[zig-langref-017-a#^f98]],
  [[zig-langref-017-a#^f90]]
- calling conventions are lowercase: `callconv(.c)` [[zig-langref-017-a#^f126]]
- varargs callbacks Zig can't express go through a tiny C shim calling an `export fn`
  [[river-repo#^f19]]
- a hand-written C header drifts silently: test it against the Zig enums, and add new
  tags at the end because enum order is ABI [[ghostty-repo#^f56]]
- C boundaries are where the bugs are: in Ghostty's GTK rewrite every issue but two sat
  on C API lifetimes, and Valgrind finds what Zig's allocator checks can't
  [[mitchellh-ghostty-gtk-rewrite#^f7]]
