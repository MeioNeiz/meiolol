---
status: answered
parent: zig-good-practice
priority: soon
area: code
tags: [zig/api]
description: How do the Zig std and respected projects design APIs and interfaces: init and deinit, options structs, decl literals, vtables, std.Io readers and writers?
---
# How do the Zig std and respected projects design APIs and interfaces: init and deinit, options structs, decl literals, vtables, std.Io readers and writers?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo

## Answer

Dependencies with unique types (`io`, `gpa`) go positionally with canonical names;
behaviour knobs go in an options struct with documented, independent defaults (C1, C2).
Tied defaults become named declarations reached with decl literals (`.empty`, `.init`,
`.default`) (C3). Anything that blocks takes `io: Io`; no Io parameter means no I/O
(C4). Streams take `*std.Io.Writer`/`Reader`, not anytype; the buffer lives in the
interface, implementations embed it and use `@fieldParentPtr`; flush at the end; format
methods take only a writer and are called with `{f}` (C5, C6). Runtime interfaces are
`ptr` plus `*const VTable` with the hot path above the vtable, and only when reuse pays;
closed sets use tagged unions with `inline else` or comptime selection (C7, C8). Prefer
caller buffers and returned indexes to allocations and pointers (C9). `create/destroy`
for heap objects, `init/deinit` for values; short-lived objects take options in and come
out finished (C10, C11). Push ifs up and fors down: batch operations as the base case
(C12). State in instances, not globals; main passes resources down (C13).

## Claims

- C1: Dependencies (io, gpa) are positional; behaviour goes in an options struct. for: [[matklad-aphorisms#^f6]], [[tigerbeetle-tiger-style#^f34]], [[ghostty-repo#^f51]]
- C2: Options structs default and document every independent field and are passed as `.{}`. for: [[zig-std-json-fmt-args#^f1]], [[zig-std-allocators#^f18]], [[ghostty-repo#^f52]]
- C3: Tied defaults become named declarations reached with decl literals. for: [[zig-014-release-notes#^f4]], [[zig-014-release-notes#^f5]], [[zig-langref-017-a#^f75]], [[seguin-decl-literals#^f2]]
- C4: Functions that block or are nondeterministic take io: Io like an Allocator. for: [[zig-016-release-notes#^f1]], [[ak-async-io-text#^f1]], [[zig-talk-kelley-flush#^f4]], [[kristoff-zig-new-async-io#^f1]]
- C5: Streams are concrete `*Io.Writer`/`*Io.Reader` with the buffer in the interface; flush at the end. for: [[zig-015-release-notes#^f11]], [[zig-015-release-notes#^f12]], [[zig-std-io#^f8]], [[zig-talk-kelley-flush#^f10]]
- C6: Format methods take only `*Io.Writer` and are selected with `{f}`. for: [[zig-015-release-notes#^f18]], [[zig-015-release-notes#^f19]], [[zig-std-io#^f18]]
- C7: Runtime interfaces are ptr plus `*const VTable`, built by an `allocator()`/`io()` method. for: [[zig-std-allocators#^f1]], [[zig-std-allocators#^f4]], [[zls-repo#^f37]], [[tigerbeetle-code#^f29]]
- C8: Build interfaces only when reuse pays; closed sets use tagged unions or comptime selection. for: [[zig-talk-kelley-flush#^f11]], [[zig-talk-roadmap-2026#^f11]], [[seguin-interfaces#^f4]], [[ghostty-repo#^f38]], [[ghostty-repo#^f41]]
- C9: Results go into caller buffers; return indexes rather than pointers. for: [[ghostty-repo#^f20]], [[matklad-comptime-orm#^f4]], [[zig-015-release-notes#^f24]]
- C10: create/destroy for heap objects, init/deinit for values. for: [[zls-repo#^f12]], [[river-repo#^f10]]
- C11: Short-lived objects take options and come out finished, with no undefined fields. for: [[zig-013-release-notes#^f1]], [[zig-016-release-notes#^f16]]
- C12: Push ifs up and fors down; batch operations are the base case. for: [[matklad-push-ifs-up#^f1]], [[matklad-push-ifs-up#^f4]], [[tigerbeetle-architecture#^f9]]
- C13: State lives in instances; main owns process resources and passes them down. for: [[kristoff-talk-better-software#^f1]], [[zig-016-release-notes#^f20]], [[zig-016-release-notes#^f3]]
- C14: Typed indexes are `enum(u32) { _ }` with a maxInt `none` sentinel for optionals. for: [[zig-devlog-2024#^f1]], [[zig-compiler-dod#^f4]], [[zls-repo#^f27]], [[matklad-newtype-index#^f6]]
- C15: After io.async, defer a cancel that frees the result; io.concurrent only when the logic needs it. for: [[zig-016-release-notes#^f6]], [[ak-async-io-text#^f4]], [[zig-talk-async-io-zigtoberfest#^f9]], [[kristoff-asynchrony-not-concurrency#^f3]]
- C16: Simpler return types are better: void, bool, int, optional, error union. for: [[tigerbeetle-tiger-style#^f41]]

## Disagreements

- Writer buffering: Seguin preferred composition; the core team put the buffer in the
  interface. std decided.
- Field defaults vs decl literals coexist; rule of thumb: independent knobs as field
  defaults, tied values as declarations.

## Open

- Whether meiolol's Riot and LCU clients should take an injected time source (TigerBeetle
  Time vtable) for tests
