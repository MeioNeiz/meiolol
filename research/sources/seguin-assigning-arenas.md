---
title: Be Careful When Assigning ArenaAllocators (Karl Seguin, 2024)
url: https://www.openmymind.net/Be-Careful-When-Assigning-ArenaAllocators/
kind: article
commit:
for: [zig-memory]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/fair
description: A real pg.zig bug: copying an ArenaAllocator by value into a struct before allocating from the local copy
---
# Be Careful When Assigning ArenaAllocators (Karl Seguin, 2024)

Why: value-copy pitfalls with stateful structs.

## Assessment

- Evidence: B. Bug reported and fixed in his pg.zig (a real library); Jun 2024, Zig 0.13
  (uses `GeneralPurposeAllocator`). The copy semantics are unchanged in 0.17; the 0.17
  arena still has `State` and `promote`.
- Reasoning: strong. Shows wrong fix (pointer to stack), right fix and its leak.
- Interests: none known.
- Weigh: trust; general lesson: never copy a struct whose state you then mutate through
  the original.

## Findings

- [zig/memory] Assignments, including returns, are copies; returning an array is fine, returning a slice of a local array dangles. ^f1
  > In Zig, assignments, including return values, are always copies.
- [zig/memory] Bug: `.arena = arena` copies the arena, then `arena.allocator().dupe` mutates the local copy; deinit on the stored copy frees nothing, so it leaks (or crashes). ^f2
  > When we assign the `arena` variable to our `arena` field, via `.arena = arena`, we're making a copy of our `ArenaAllocator`.
  > In short, we're duping from one arena and freeing from another.
- [zig/memory] Taking `&arena` instead dangles: the local dies on return. ^f3
  > But we've introduced a dangling pointer since the address that we're copying lives on the stack which will become invalid when we return.
- [zig/memory] Robust fix: put the arena on the heap with `create`, `errdefer destroy`, and destroy it in `deinit` after `arena.deinit()`. ^f4
  > const arena = try allocator.create(ArenaAllocator);
  > errdefer allocator.destroy(arena);
- [zig/memory] To save a field, store `ArenaAllocator.State` and `promote(allocator)` it in deinit. ^f5
  > The main takeway is that we can "promote" our `ArenaAllocator.State` back into an `ArenaAllocator` by providing the same `allocator` passed to `init`.
- [zig/memory] Reordering fields so the copy happens after allocating works but is fragile. ^f6
  > But this would only work for simple cases as it doesn't seem like a particularly robust solution. It's very easy to mess up.
- [zig/memory] The bug in pg.zig showed as a bus error after reallocations across copies. ^f7
  > The result was a bus error - something you don't see often.

## Read

- Whole post.
