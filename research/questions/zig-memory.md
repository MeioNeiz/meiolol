---
status: answered
parent: zig-good-practice
priority: soon
area: code
tags: [zig/memory]
description: How should Zig code allocate, own and free memory: allocator choice, arenas, defer and errdefer, static allocation, containers?
---
# How should Zig code allocate, own and free memory: allocator choice, arenas, defer and errdefer, static allocation, containers?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo

## Answer

Every function that allocates takes an `Allocator`; only `main` or the lifetime owner
chooses one (C1). In 0.17 `main(init: std.process.Init)` hands over `init.gpa`
(SafeAllocator with leak report in safe builds, a fast allocator otherwise), a
process-lifetime `init.arena` and `init.io` (C2). Name allocators by lifetime: `gpa`,
`arena`, `scratch` (C3). Containers are unmanaged: `.empty`, allocator per call,
`deinit(gpa)` that poisons with `self.* = undefined` (C4, C5). Reserve capacity first,
then mutate with `*AssumeCapacity` in a tail marked `errdefer comptime unreachable`
(C6). `errdefer` goes right after each acquisition and its scope ends when ownership
moves (C7, C8). Arenas suit one-lifetime work (request, parse, batch, config); reset
with `retain_capacity` in loops; their `free` is a no-op and growing lists in them
wastes memory (C9, C10). Results owning many allocations carry their own arena or offer
a Leaky variant (C11). Pointers into growing or mutated containers are invalid; keep them
short, use indexes, or `lockPointers` (C12). Bound everything read from outside (C13).
TigerBeetle's static allocation is real but database-specific; take the forcing
function (named maxima, allocate in an init phase) rather than the rule (C14). OOM
policy is contested: std propagates, matklad would abort in apps (C15).

## Claims

- C1: Allocating functions take an Allocator; libraries never choose one. for: [[zig-langref-017-b#^f73]], [[zig-langref-017-b#^f74]], [[seguin-learning-zig-heap-memory#^f9]], [[zls-repo#^f11]] against: [[river-repo#^f7]], [[bun-repo#^f7]]
- C2: In 0.17 main takes std.process.Init with gpa (SafeAllocator in safe builds), arena and io. for: [[zig-std-allocators#^f22]], [[zig-std-allocators#^f23]], [[zig-016-release-notes#^f19]], [[zig-017-release-notes#^f25]]
- C3: Allocator parameters are named for their lifetime (gpa, arena, scratch). for: [[matklad-comptime-orm#^f2]], [[matklad-aphorisms#^f4]], [[tigerbeetle-tiger-style#^f29]]
- C4: Containers are unmanaged with `.empty` and the allocator per call. for: [[zig-std-containers#^f1]], [[zig-std-containers#^f3]], [[zig-014-release-notes#^f6]], [[zig-015-release-notes#^f22]], [[ziggit-arraylist-unmanaged-015#^f1]]
- C5: deinit takes a pointer and ends with `self.* = undefined`. for: [[zig-std-containers#^f4]], [[zls-repo#^f14]], [[ghostty-repo#^f10]]
- C6: Reserve capacity first, then mutate infallibly, marking the tail with `errdefer comptime unreachable`. for: [[matklad-reserve-first#^f4]], [[matklad-reserve-first#^f5]], [[zig-std-containers#^f6]], [[zig-std-containers#^f25]], [[ghostty-repo#^f30]]
- C7: errdefer goes on the line after each acquisition. for: [[zig-langref-017-b#^f7]], [[seguin-learning-zig-heap-memory#^f3]], [[zls-repo#^f13]], [[ghostty-repo#^f29]]
- C8: An errdefer must end its scope where ownership transfers, or it double frees. for: [[ziggit-errdefer-double-free#^f1]], [[ziggit-errdefer-double-free#^f2]], [[tigerbeetle-code#^f13]]
- C9: Arenas fit one-lifetime units of work and are reset with retain_capacity in loops. for: [[zig-std-allocators#^f13]], [[seguin-leveraging-allocators#^f2]], [[ghostty-repo#^f11]], [[zls-repo#^f17]]
- C10: Arena free is a no-op unless last; growing an ArrayList inside an arena wastes old buffers. for: [[seguin-arena-free-nested#^f1]], [[seguin-arena-arraylist#^f2]], [[seguin-arena-arraylist#^f4]]
- C11: Results owning many allocations carry their own arena or offer a Leaky variant. for: [[zig-std-json-fmt-args#^f3]], [[zig-std-json-fmt-args#^f4]], [[zig-clap-repo#^f12]]
- C12: Pointers into containers die on growth or removal; ArrayList gained lockPointers to assert it. for: [[seguin-learning-zig-coding-in-zig#^f1]], [[ziggit-invalidate-pointers#^f1]], [[zig-devlog-2026#^f13]], [[zig-017-release-notes#^f26]]
- C13: Reads of untrusted input always carry a limit. for: [[zig-std-io#^f23]], [[zig-std-json-fmt-args#^f9]], [[liptak-fuzz-allocators#^f1]]
- C14: Full static allocation needs bounded inputs and is justified by TigerBeetle's domain. for: [[tigerbeetle-architecture#^f1]], [[tigerbeetle-blog-no-dynamic-memory#^f5]], [[matklad-static-alloc-compilers#^f7]], [[matklad-static-alloc-compilers#^f8]]
- C15: Applications may reasonably abort on OOM; libraries propagate it. for: [[matklad-reserve-first#^f9]], [[zig-std-json-fmt-args#^f20]] against: [[zig-langref-017-b#^f16]]
- C16: Never infer ownership from a derived property; store it explicitly with no default. for: [[mitchellh-ghostty-memory-leak-fix#^f4]], [[ghostty-repo#^f18]]
- C17: Copying a stateful struct (an arena) by value then using the original loses allocations. for: [[seguin-assigning-arenas#^f2]], [[seguin-assigning-arenas#^f7]]
- C18: Hash map keys are owned by the map's owner, duped only on insert, freed before deinit. for: [[seguin-learning-zig-coding-in-zig#^f4]], [[seguin-getorput-string-keys#^f4]], [[seguin-getorput-string-keys#^f5]]

## Disagreements

- Allocator passing vs one global: ZLS, zig-clap, SuperHTML pass it; River and Bun use a
  global over libc. Passing keeps testing.allocator leak checks; prefer passing.
- OOM: std and the langref treat OOM as recoverable (A); matklad would abort in apps (B).
  For an app, either is defensible; reserve-first protects invariants regardless.
- Release allocator: Ghostty uses libc malloc in release, std and ziggit point to
  smp_allocator; `init.gpa` makes the choice for you.

## Open

- Measured cost of SafeAllocator vs smp_allocator on a crawler-shaped workload
- Whether `lockPointers` is in 0.17.0 for ArrayList (release notes say so; check source)
