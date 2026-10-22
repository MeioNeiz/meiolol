---
title: Zig: Use The Heap to Know A Value's Address (Karl Seguin, 2024)
url: https://www.openmymind.net/Zig-Use-The-Heap-To-Know-A-Values-Address/
kind: article
commit:
for: [zig-memory, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Self-referential init: pass &pool of a stack value and return a copy breaks; take *Self or heap-allocate
---
# Zig: Use The Heap to Know A Value's Address (Karl Seguin, 2024)

Why: the init-returns-a-copy pitfall for self-referencing structs.

## Assessment

- Evidence: B. Practitioner, Mar 2024; language semantics unchanged in 0.17.
- Reasoning: fair; two options and when.
- Interests: none known.
- Weigh: trust. A third option is a stable-address `init(self: *Self)` that the std
  and many projects use; he lists it as the C-style option.

## Findings

- [zig/memory] Handing out `&local` during `init` and then returning the value by copy leaves the children pointing at the dead stack copy. ^f1
  > When we call `Call.open(&pool)`, we're passing the address of the `pool` value on the stack. When we return `pool`, we're returning a copy.
- [zig/api] Option one: the caller supplies the storage, `init(..., pool: *Pool)`, common in C and seen in Zig. ^f2
  > The first is to make this the callers problem. Our `init` would be changed to take a `*Pool`:
- [zig/memory] Option two, more common: heap-allocate with `create`, return `*Pool`, and `destroy(self)` in `deinit`. ^f3
  > Your other, probably more common, option is to put `pool` on the heap:
- [zig/memory] `alloc`/`free` are for slices, `create`/`destroy` for single items. ^f4
  > `alloc/free` is to create and free an array of items, whereas `create/destroy` is to create and free a single item.

## Read

- Whole post.
