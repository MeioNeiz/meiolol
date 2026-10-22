---
title: Learning Zig - Heap Memory & Allocators (Karl Seguin)
url: https://www.openmymind.net/learning_zig/heap_memory/
kind: book
commit:
for: [zig-memory, zig-api-design, zig-testing]
looked: 2026-10-22
depth: docs (whole chapter)
relevance: high
grade: B/fair
description: Chapter on alloc/free, defer/errdefer, init/deinit, leaks, testing allocator, arena, FixedBufferAllocator, buffers and writers instead of allocation
---
# Learning Zig - Heap Memory & Allocators (Karl Seguin)

Why: the community's standard explanation of allocator idioms and ownership.

## Assessment

- Evidence: B. Widely read intro by the http.zig maintainer (1621 stars, 30
  contributors); http.zig's per-request arena is the real-use example he cites. Revised
  for 0.16 (DebugAllocator, decl literals, `std.Io.Writer`).
- Reasoning: fair to strong. Gives the why for each allocator and when not to allocate.
- Interests: mentions his own http.zig library as the example.
- Weigh: idioms sound. Stale bits: every example builds a `DebugAllocator` in `main`,
  though his own later chapter uses 0.16 "juicy main" (`init.gpa`); the release pattern
  picks `c_allocator`, where 0.14+ code (and meiolol) often uses `smp_allocator`.

## Findings

- [zig/memory] `try alloc` followed by `defer free` is the common, foolproof pairing; allocating in one place and freeing elsewhere is equally common. ^f1
  > This `try alloc` + `defer free` pattern _is_ common, and for good reason: freeing close to where we allocate is relatively foolproof.
- [zig/memory] Zig's `defer` runs at the end of its enclosing block, not the function (unlike Go). ^f2
  > In Zig, the defer will be run at the end of its containing scope. In Go, defer is run at the end of the containing function.
- [zig/memory] In `init`, each allocation gets an `errdefer free` so a later failure undoes earlier allocations; he adds it even after the last fallible step so future edits stay safe. ^f3
  > In this case and only this case we need to undo the allocation of `players`.
  > This isn't strickly necessary. Nothing following the above alloc
- [zig/api] `init` allocating and `deinit` freeing is a std convention, not a language rule; `open`/`close` where they read better. ^f4
  > The names `init` and `deinit` aren't special. They're just what the Zig standard library uses and what the community has adopted.
- [zig/memory] Nothing enforces calling `deinit` exactly once. ^f5
  > we can mess it up by never calling `deinit` or calling it more than once.
- [zig/memory] Calling a function that returns allocated memory and dropping the result leaks: the caller owns it. ^f6
  > This is a memory leak. The memory created in `allocLower` is never freed.
- [zig/api] No default allocator; functions that allocate take one, by convention first. ^f7
  > Zig doesn't have a default allocator.
  > By convention, this is usually the first parameter.
- [zig/api] Two forms: an allocator per call (explicit) or stored at `init` (less explicit, practical for long-lived objects). ^f8
  > This is less explicit, since you've given the object an allocator to use, but you don't know which method calls will actually allocate. This approach is more practical for long-lived objects.
- [zig/api] Libraries should accept an `Allocator` and let the user choose. ^f9
  > If you're building a library, then it's best to accept an `std.mem.Allocator` and let users of your library decide which allocator implementation to use.
- [zig/test] `std.testing.allocator` fails a test on leaks and prints the allocation's stack trace. ^f10
  > The important thing is that if we use `std.testing.allocator` in our tests, we can catch most memory leaks.
  > Thankfully the testing allocator tells us exactly where the leaking memory was allocated.
- [zig/memory] An arena suits short-lived state such as parser scratch: one `deinit` frees all, and `free`/`destroy` are no-ops. ^f11
  > Everything will be released when we call `deinit` on the `arena`. In fact, the `free` and `destroy` of an ArenaAllocator do nothing.
- [zig/memory] The arena's limit: no individual frees, so it must be torn down before memory grows too far. ^f12
  > Since there's no way to free individual allocations, you need to be sure that the arena's `deinit` will be called within a reasonable memory growth.
- [zig/memory] Code that receives an `Allocator` must not assume its implementation (still free what it allocates); the owner of the lifetime picks the allocator, not the container. ^f13
  > if you receive an `std.mem.Allocator` you should not make any assumptions about the underlying implementation.
  > It's the code making use of `IntList` that has this knowledge.
- [zig/memory] http.zig gives each response an arena cleared when the response is sent; a request is a natural arena lifetime. ^f14
  > the HTTP server I mentioned above exposes an arena allocator on the `Response`. Once the response is sent, the arena is cleared.
- [zig/memory] FixedBufferAllocator: fast, hard-capped, frees only the last allocation (stack-like); reset and reuse is common. ^f15
  > Another drawbacks is that `free` and `destroy` will only work on the last allocated/created item (think of a stack).
  > A common pattern with FixedBufferAllocators, and to a lesser degree ArenaAllocators, is to `reset` them and reuse them.
- [zig/memory] Common app pattern: DebugAllocator in Debug builds with leak check at exit, `c_allocator` in release. ^f16
  > we use `DebugAllocator` in `Debug` builds and `std.heap.c_allocator` in `Release` builds.
- [zig/api] Prefer a caller-supplied buffer (`bufPrint`) over allocating when limits are known. ^f17
  > But there are plenty of scenarios where an application has known limits, such as a maximum name length. In those cases `bufPrint` is safer and faster.
- [zig/api] Or stream to a `*std.Io.Writer` instead of building an allocated string; writers go last in parameter lists, allocators first. ^f18
  > While allocators are often given as the first parameter of a function, writers are normally the last.
- [zig/api] Declaration literals make init readable: `.init` for DebugAllocator, `.empty` for an empty hash map. ^f19
  > var gpa: std.heap.DebugAllocator(.{}) = .init;
  > For example, an empty hash map is initialized using the `.empty` declaration literal.
- [zig/api] Options/config structs with defaults are passed as `.{}` or `.{ .port = 5882 }`. ^f20
  > No fields are set because the `DebugAllocatorConfig` struct defines defaults, which we'll be using. This is a common pattern with configuration / options.
- [toolchain] `DebugAllocator` was `GeneralPurposeAllocator`, hence `gpa` names. ^f21
  > The `DebugAllocator` used to be called `GeneralPurposeAllocator`.
- [zig/safety] From 0.16 the compiler rejects returning `&local` from a function. ^f22
  > This was replaced because, as-of Zig 0.16, the compiler catches the mistake.
- [zig/memory] To outlive the frame, return a heap pointer from `create` and fill it with `ptr.* = .{...}`. ^f23
  > But sometimes you _will_ want a function to return a pointer to something it creates. You'll do this when you want a lifetime to be free from the call stack's rigidity.
- [zig/memory] (inferred) Stale for 0.16+: building a DebugAllocator in `main` is replaced by `pub fn main(init: std.process.Init)` and `init.gpa`, which his Coding In Zig chapter already uses. ^f24

## Read

- Whole chapter.
