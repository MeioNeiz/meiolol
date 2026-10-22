---
title: Static Allocation For Compilers (matklad, 2025-12-23)
url: https://matklad.github.io/2025/12/23/static-allocation-compilers.html
kind: article
commit: 
for: [zig-memory]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: What TigerBeetle's "static allocation" means (all at startup, sized by CLI args), why it composes, and an idea for O(1)-memory compiler processing
---
# Static Allocation For Compilers (matklad, 2025-12-23)

Why: when no-allocation-after-startup is possible outside a database. Language neutral,
no Zig version dependence.

## Assessment

- Evidence: B. First-hand from TigerBeetle for the database part; the compiler part is
  speculative and he says so.
- Reasoning: strong. Explains the precondition (finite inputs and outputs), the
  overload answer (drop messages) and contrasts arenas.
- Interests: works at TigerBeetle.
- Weigh: trust the description of TigerBeetle; treat the compiler idea as an untested
  idea ("Is there any practical benefits here? I don't know!").

## Findings

- [zig/memory] TigerBeetle's static allocation means no allocation after startup, sized by
  runtime command line arguments, with no deallocation; not `static` arrays. ^f1
  > However, all allocation happens at startup, and there’s no deallocation.
- [zig/memory] It depends on the problem's physics: finite messages (1MiB) in and out
  mean processing needs no extra memory. ^f2
  > if your input is finite, and your output is finite, it’s actually quite hard to need to allocate extra memory!
- [zig/memory] (claim) In practice it is compositional, not constant vigilance; routing.zig
  is cited as an isolated non-allocating subsystem. ^f3
  > In practice, I learned that it is surprisingly compositional.
- [zig/memory] Overload: unbounded concurrent messages are handled by dropping a message
  when resources are not available. ^f4
  > a safe move is to drop a message on the floor if the required processing resources are not available.
- [zig/memory] (claim) Not allocating is simpler than allocating, if achievable. ^f5
  > Counter-intuitively, not allocating is simpler than allocating, provided that you can pull it off!
- [zig/memory] Contrast with a fixed arena: arena size is fixed but you can OOM; static
  allocation can't OOM but its size is known only after startup. ^f6
  > With arenas, the size is fixed explicitly, but you can OOM. With static allocation it is the opposite
- [zig/memory] Disk is not statically allocated in TigerBeetle: it can fail with ENOSPACE
  and has a dynamic block allocator. ^f7
  > TigerBeetle doesn’t do “static allocation” on disk, it can fail with `ENOSPACE` at runtime
- [zig/memory] [zig/perf] Idea: an output arena for O(N) finished results plus O(1)
  processing of bounded chunks (e.g. a 4 MiB file limit, runtime-overridable), with
  indexes for output data. ^f8
  > Compiling then essentially becomes a “stream processing” problem, where both inputs and outputs are arbitrary large, but the filter program itself must execute in O(1) memory.

## Read

- Whole post.

## Not read

- TigerBeetle ARCHITECTURE.md and routing.zig: reader "tigerbeetle".
