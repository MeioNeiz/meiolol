---
title: Allocator.resize (Karl Seguin, 2025)
url: https://www.openmymind.net/Allocator-resize/
kind: article
commit:
for: [zig-memory]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: resize never moves the pointer and may fail; it doesn't update the slice length, so set buf.len yourself
---
# Allocator.resize (Karl Seguin, 2025)

Why: a pitfall with in-place resizing.

## Assessment

- Evidence: B. Practitioner, Mar 2025, Zig 0.14.
- Reasoning: fair; reproduces a segfault.
- Interests: none.
- Weigh: doesn't mention `remap` (0.14: may move) or `realloc`, which usually fit better.

## Findings

- [zig/memory] `resize` promises not to move the pointer, so it is allowed to fail and return false; when it fails nothing changed. ^f1
  > The main promise of `resize` is that it's guaranteed _not_ to move the pointer. However, to satisfy that guarantee, resize is allowed to fail, in which case nothing changes.
- [zig/memory] A successful `resize` doesn't change your slice's `len`; freeing with the old length crashed. ^f2
  > `resize` updates the underlying memory, it doesn't update the length of the slice. That's something we need to take care of.
- [zig/memory] When resize fails, fall back to alloc plus `@memcpy`. ^f3
  > we'll generally need to fallback to calling `alloc` to create our larger memory, and then, most likely, `@memcpy` to copy data from the existing (now too small) buffer to the newly created larger one.
- [zig/memory] Checked, not there: `remap` and `realloc` (which handle the move case) are not covered. ^f4

## Read

- Whole post.
