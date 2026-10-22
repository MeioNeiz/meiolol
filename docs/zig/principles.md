# 2. What the core team means by good Zig

The langref opens by defining robust, optimal, reusable and maintainable; maintainable
means "precisely communicating intent to the compiler and other programmers"
[[zig-langref-017-a#^f1]], and robust includes handling out-of-memory
[[zig-langref-017-a#^f2]]. "Why Zig" adds: no hidden control flow, no hidden allocation,
a small language [[zig-learn-why#^f1]], [[zig-learn-why#^f2]].

Every release since 0.11 has pushed the std the same way [[zig-good-practice]] C1:

- concrete over generic: `*std.Io.Writer` instead of `writer: anytype`
  [[zig-015-release-notes#^f12]]
- explicit over hidden: no `usingnamespace` [[zig-015-release-notes#^f1]], no global
  environment [[zig-016-release-notes#^f20]], no allocator stored in containers
  [[zig-015-release-notes#^f22]]
- resources created once in `main` and passed down: `std.process.Init` hands over gpa,
  arena, io and environment [[zig-016-release-notes#^f19]]
- caller-provided buffers rather than guessed capacities (BoundedArray removed)
  [[zig-015-release-notes#^f24]]

What the respected projects add on top is small: assertions everywhere state is subtle,
tests that exercise error paths, a few mechanical lints, and restraint with comptime.
