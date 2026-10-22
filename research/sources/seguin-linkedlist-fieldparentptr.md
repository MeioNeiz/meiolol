---
title: Zig's new LinkedList API, it's time to learn @fieldParentPtr (Karl Seguin, 2025)
url: https://www.openmymind.net/Zigs-New-LinkedList-API/
kind: article
commit:
for: [zig-api-design, zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: 0.15 std linked lists became intrusive and non-generic; recover the container with @fieldParentPtr, use @offsetOf not hand offsets
---
# Zig's new LinkedList API, it's time to learn @fieldParentPtr (Karl Seguin, 2025)

Why: intrusive containers and `@fieldParentPtr`, which also underpins `std.Io.Writer`.

## Assessment

- Evidence: B. Practitioner, Apr 2025, on the post-0.14 commit that shipped in 0.15.
- Reasoning: fair; shows the unsafe manual version first, then the builtin.
- Interests: none.
- Weigh: trust.

## Findings

- [zig/perf] std `SinglyLinkedList`/`DoublyLinkedList` became intrusive: embed a `Node` in your struct; no separate node allocation. ^f1
  > This is known as an intrusive linked list and tends to perform better and require fewer allocations.
- [zig/api] Recover the containing struct from the node with `@fieldParentPtr("node", n)`. ^f2
  > const user: *User = @fieldParentPtr("node", n);
- [zig/safety] Never hard-code field offsets: plain struct layout is not guaranteed; use `@offsetOf` (or `@fieldParentPtr`). ^f3
  > unless we're using a packed or extern struct, Zig makes no guarantees about the layout of a structure.
- [zig/api] He finds exposing `@fieldParentPtr` for a list heavy, but says developers should know it. ^f4
  > it's quite useful and developers should be familiar with it because it can help solve problems which are otherwise problematic.

## Read

- Whole post.
