---
title: Reserve First (matklad, 2025-08-16)
url: https://matklad.github.io/2025/08/16/reserve-first.html
kind: article
commit: 
for: [zig-memory, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Exception safety in Zig: reserve capacity first, then mutate in an error-free path marked errdefer comptime unreachable; two real bugs (Andrew Kelley's talk, Ghostty)
---
# Reserve First (matklad, 2025-08-16)

Why: correct cleanup when allocation fails midway. Zig 0.14/0.15 era (unmanaged
containers taking `gpa`), current for 0.17.

## Assessment

- Evidence: B. Two real bugs from respected Zig code (Andrew Kelley's HYTRADBOI 2025
  talk, Ghostty @0930b2d), pattern learnt from Andrew Kelley.
- Reasoning: strong. Bug, taxonomy (strong, basic, no exception safety), fix; labels
  his takes as deliberately spicy.
- Interests: none.
- Weigh: the pattern is solid; "abort on OOM" and "remove append" are opinions he marks
  as provocations.

## Findings

- [zig/memory] [zig/errors] Bug 1 (internString in Andrew Kelley's talk): getOrPut inserts
  a key, then a later `try` fails, leaving an uninitialised table entry. ^f1
  > In the `internString` case, we insert an item into a hash table, but leave it uninitialized.
- [zig/memory] [zig/errors] Bug 2 (Ghostty Atlas.grow): the errdefer restores `data_old`
  but the `defer alloc.free(data_old)` still frees it. ^f2
  > While the data is restored to `data_old` on error, the `defer` still frees `data_old`, so we end up with uninitialized memory all the same
- [zig/errors] Both are exception safety problems: strong (state as before), basic (valid
  but different), none (invalid). ^f3
  > Both are “exception safety” problems
- [zig/memory] Pattern: first reserve enough memory without changing the structure, then
  mutate in an error-free code path. ^f4
  > First, _reserve_ enough memory for operation, without applying any changes to the data structure,
  > Then, mutate the data structure in an error-free code path.
- [zig/errors] [zig/safety] `errdefer comptime unreachable;` marks "no errors after this
  point" (end of reservation phase), checked at compile time. ^f5
  > `errdefer comptime unreachable;` is a Zig idiom for expressing “no errors after this point”.
- [zig/memory] Fixed internString: `ensureUnusedCapacityContext` and
  `ensureUnusedCapacity`, then `errdefer comptime unreachable`, then
  `getOrPutAssumeCapacityAdapted`. ^f6
  > const gop = state.string_table.getOrPutAssumeCapacityAdapted(
- [zig/memory] ensureUnusedCapacity holds all the failures but doesn't change the data
  structure; learnt from Andrew Kelley. ^f7
  > Memory reservation is a magic trick, `ensureUnusedCapacity` contains all the failures, but doesn’t change the data structure!
- [zig/memory] Spicy take: Zig should drop `append` and rename `appendAssumeCapacity` to
  `append`; reserve in bulk up front. ^f8
  > Zig should remove `append` and rename `appendAssumeCapacity` to just `append`.
- [zig/memory] [zig/errors] Applications should consider aborting on OOM; he has seen only
  one (xit) pass a 30-minute errdefer grep. Libraries: leave allocation to the caller or
  test with an allocator that really fails. ^f9
  > Zig applications should consider aborting on OOM.
  > For libraries, prefer leaving allocation to the caller, or use generative testing with an allocator that actually returns errors.
- [zig/memory] TigerBeetle reserves all resources in main and never allocates
  afterwards. ^f10
  > We take this pattern literally, reserve _all_ resources in main, and never allocate memory afterwards

## Read

- Whole post.

## Not read

- Andrew Kelley "Programming Without Pointers" HYTRADBOI 2025 talk: lead, core Zig
  data-oriented design talk.
