---
title: Static Allocation, Constant Work (matklad, 2026-09-02)
url: https://matklad.github.io/2026/09/02/static-allocation-constant-work.html
kind: article
commit: 
for: [zig-memory, zig-perf, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Object pools vs use-after-free, startup-sized allocation with rejection on overload, and a fixed population of objects with a neutral reserved value processed by full loops
---
# Static Allocation, Constant Work (matklad, 2026-09-02)

Why: bounding memory and work. Zig 0.17 era (links TigerBeetle 0.17.9; `@memset(orders,
.reserved)` decl literal).

## Assessment

- Evidence: B. TigerStyle rules and TigerBeetle practice, first-hand.
- Reasoning: strong. Gives the failure mode it prevents (OOM killer, gray failure),
  the alternatives (bit set pool, free list) and ends "a trick ... not a universal
  solution".
- Interests: works at TigerBeetle.
- Weigh: a strong fit for fixed-capacity services; for batch jobs with unknown input size
  the limits don't map directly.

## Findings

- [zig/memory] [zig/safety] With a typed pool of T, a logical use-after-free aliases memory
  but causes no type confusion, unless the object stores an inline enum. ^f1
  > Logical use-after-free is still possible, but its physical effect is now different — we still get aliasing of memory, but there’s no type confusion.
- [zig/memory] Hardening idea (from Fil-C): a typed allocation function (comptime T) can
  use type-segregated pools internally. ^f2
  > you can write an allocator that uses type-segregated pools internally.
- [zig/memory] TigerStyle rule: no dynamic memory allocation after initialization; size
  from CLI (`--orders-max`), allocate in main with `gpa.alloc(Order,
  cli_args.orders_max)`, reject surplus requests. ^f3
  > No dynamic memory allocation after initialization
  > If, at runtime, more than `orders_max` requests come in, the surplus requests are rejected.
- [zig/memory] Why: systems at capacity without strict limits fail catastrophically (OOM
  killer); a static system may fail to start but handles overload gracefully. ^f4
  > Systems operating at capacity _without_ strict limits fail catastrophically.
  > The system might fail to start if you don’t have enough memory, but, if it did start, you can rest assured that it would handle overload gracefully
- [zig/memory] Pool shapes: slice plus `DynamicBitSet` of free slots, or a slice of
  `union { order: Order, next_free: ?u32 }` with `first_free`. ^f5
  > free: DynamicBitSet,
- [zig/memory] [zig/api] Constant work: always a fixed number of objects, with a neutral
  `pub const reserved: Order` value; init is `@memset(orders, .reserved)`. ^f6
  > Your initialization then becomes `@memset(orders, .reserved)`.
- [zig/safety] Objects circulate rather than being created and destroyed; write transition
  functions per pair of states and assert the expected state at every point. ^f7
  > You explicitly write state transition functions for each _pair_ of states, and that makes it easier to exhaustively enumerate all the cases.
- [zig/perf] Iterate the full set doing no-ops for reserved: if max load isn't fast enough
  that is a bug; gray failure is another way to break at the limit. ^f8
  > _If_ the maximum amount of orders is active, does the system have acceptable performance? If not, that is a bug!
- [zig/perf] A plain `for (orders)` is easier to vectorize and prefetch than an
  indirection through `orders_active` indexes. ^f9
  > is much easier for a compiler to vectorize, and for a CPU Cache to prefetch, than this:
- [zig/perf] Constant work keeps P100 latency flat regardless of load. ^f10
  > P100 latency stays flat regardless of the load.
- [zig/safety] In the small: instead of a search loop with early `break`, run the loop to
  completion and assert the match is unique (TigerBeetle grid.zig @0.17.9). ^f11
  > we sometimes let the loop to run its full natural course, additionally asserting that theres a _unique_ matching item
- [zig/memory] He has never used generational indexes. ^f12
  > Generational indexes are a popular remedy, but I have never used them

## Read

- Whole post.

## Not read

- TigerBeetle grid.zig:715-725 and TIGER_STYLE.md: reader "tigerbeetle".
