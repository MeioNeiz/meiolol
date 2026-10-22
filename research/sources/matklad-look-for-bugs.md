---
title: Look Out For Bugs (matklad, 2025-09-04)
url: https://matklad.github.io/2025/09/04/look-for-bugs.html
kind: article
commit: 
for: [zig-testing, zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Find bugs by slow code reading: follow control flow, stare at state; Zig smell is an allocator and a try in the same scope; avoid self, use proper names
---
# Look Out For Bugs (matklad, 2025-09-04)

Why: review habits for Zig code. Version neutral.

## Assessment

- Evidence: B. First-hand: bugs found in IntelliJ ImmutableText and TigerBeetle (PR 3194)
  by reading.
- Reasoning: fair. Practical tips, little on limits.
- Interests: none.
- Weigh: review practice, complements tests.

## Findings

- [zig/test] Bugs can be found by just reading code; careful slow reading builds the
  mental model. ^f1
  > You can find bugs by just reading code.
- [zig/test] Read along control flow from main ("goto definition"), and stare at the
  state: find all places key fields are created and modified. ^f2
  > Identify the key data structures and fields, and search for all places where they are created and modified.
- [zig/style] Name things consistently (`connection` everywhere) and avoid `self`, so a
  text search for `connection.peer` finds every use. ^f3
  > If your language allows it, avoid `self`, use proper names.
- [zig/memory] [zig/errors] Zig smell: an allocator and a `try` in the same scope need
  care (see reserve first). ^f4
  > In Zig, if there’s an allocator and a `try` in the same scope, you need to be very careful.
- [zig/style] A tricky isolated function is probably fine; a tricky interaction between
  functions is a smell. ^f5
  > If there’s a tricky _interaction_ between functions, it is a smell, and some bugs are lurking there.
- [zig/test] Review the whole subsystem, not just the diff; use git blame and `git log -S`
  for the historical why. ^f6
  > If you are reviewing a PR, don’t review _just_ the diff, review the entire subsystem.

## Read

- Whole post.

## Not read

- teamten.com "Don't Write Bugs" (linked): other author.
