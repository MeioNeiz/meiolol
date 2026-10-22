---
title: "Andrew Kelley: A Practical Guide to Applying Data-Oriented Design (Handmade Seattle 2021)"
url: https://www.youtube.com/watch?v=IroPQ150F6c
kind: talk
commit:
for: [zig-perf, zig-api-design, zig-memory]
looked: 2026-10-22
depth: docs (whole transcript, top comments)
relevance: high
grade: A/strong
description: Kelley's DOD talk: shrink the struct you have most of; indexes for pointers, out-of-band bools, SoA (MultiArrayList), sparse data in hashmaps, encodings over polymorphism; Zig compiler numbers (tokens 64 to 5 bytes, AST 120 to 15.6, ZIR 54 to 20.3, -22% and -39% wall time)
---
# Andrew Kelley: A Practical Guide to Applying Data-Oriented Design

Why: the core team's DOD reasoning with numbers; the source behind std.MultiArrayList and
the compiler's data layout.

## Assessment

- Evidence: A. The language creator reporting measured results on the Zig compiler; the
  techniques shipped (MultiArrayList, Ast, Zir encodings are in std and the compiler).
  Handmade Seattle 2021 (reupload, 412k views). Auto captions: numbers checked for
  internal consistency (24 to 12 bytes, 160 KB to 91 KB, 64 to 5).
- Reasoning: strong. Explains the memory hierarchy, each technique with before/after
  sizes, warns about type safety, admits the numbers cover one pipeline stage.
- Interests: promoting Zig and the self-hosted compiler.
- Weigh: the 2021 numbers predate 0.10; the techniques hold. Commenters point out costs
  the talk skips: hash lookups are slower than direct access, split arrays cost an extra
  access when you need the whole record, and code is harder to read. His remark that Zig
  lacks distinct integer types is outdated: non-exhaustive enums now fill that role
  ([[zig-devlog-2024#^f1]]).

## Findings

- [zig/perf] The CPU is fast and main memory slow; math beats a memory load, so
  memoising cheap computations can make code slower. @6:11 ^f1
  > math is faster than reading from memory so you can draw a pretty interesting conclusion from this which is like should you memoize results of doing math maybe not
- [zig/perf] The practical method: find the struct you have the most of in memory and
  make it smaller. @9:08 ^f2
  > think about a struct that you have the most of in memory and think about how you can make it smaller that's the whole trick
- [zig/perf] Field order changes padding: u32,u64,u32 is 24 bytes, u32,u32,u64 is 16;
  one added bool pushes it back to 24. @11:14 ^f3
  > so just by moving these two fields around right we put the two ins in a row now what are we looking at what's the alignment same same alignment and the size yeah we went back down to 16
- [zig/perf] [zig/memory] Use u32 indexes into arrays instead of pointers: halves the
  field on 64-bit and drops alignment from 8 to 4. @13:48 ^f4
  > use indexes instead of pointers that's a trick you can use to have a smaller uh memory footprint
- [zig/api] [zig/safety] Warning: bare integer indexes lose the type safety pointers
  had; use distinct types where the language allows. @15:18 ^f5
  > but I have a warning which is watch out for type safety because in the pointer example you're going to get compile errors if you use the wrong type of stuff
- [zig/perf] Store booleans out of band: two arrays (alive, dead) instead of a flag
  field; 24 to 12 bytes per monster with indexes, and the loop skips the branch and load.
  @16:49 ^f6
  > store booleans out of band that's that's the answer to the the question the part that I did not understand when I first watched Mike D's talk
- [zig/perf] Eliminate padding with struct-of-arrays (MultiArrayList, "a five character
  fix, same API"): 10,000 monsters 160 KB to 91 KB. @20:26 ^f7
  > if your programming language lets you use a multi-array list for example that's a five character fix same same API
  > now we went from 160 kiloby for 10,000 monsters to 91 kiloby
- [zig/perf] Store sparse data in hashmaps keyed by index: with 90% of monsters holding
  nothing, 366 KB to 198 KB. @21:56 ^f8
  > I did the math with 10,000 monsters we went from 366 to 198 kilobytes
- [zig/perf] Encodings instead of polymorphism: a tag that folds flags and variants
  (bee colour, clothed or not) plus common data and an `extra` index into side arrays;
  32 to 17 bytes per monster. @26:24 ^f9
  > so we went down from 32 to 17 almost broke that in half Again by switching to
- [zig/perf] Choose encodings from the observed distribution of your data. @29:24 ^f10
  > choosing codings according to your actual distributions
- [zig/perf] Zig tokens went from 64 bytes to 5: compute line and column lazily, u32
  offsets (4 GB source limit), no end position, no parsed literals. @34:23 ^f11
  > we went down from 64 bytes per token to five it's just it's just where is it in the file and what is it
- [zig/perf] AST nodes 120 bytes to 15.6 average with SoA and multiple encodings per node
  kind; with tokens, parsing got 22% faster in wall time. @36:33 ^f12
  > so this went from 120 bytes to 15.6 average
  > if you do 22% faster wall clock time something that I'm quite happy with
- [zig/perf] ZIR instructions 54 to 20.3 bytes average (u32 source locations, encodings,
  references that encode simple values like true/false); 39% less wall time. @40:53 ^f13
  > so we go from 54 on average to 20.3 again on average
  > it gave me a 39% reduction of wall clock time
- [zig/perf] Flat arrays (tag, data, extra, string table) make serialising trivial: one
  writev/readv syscall to save or load the cache. @43:50 ^f14
  > you actually just give arrays to the OS and it just does the whole thing at once like it's one CIS call to save these to the cash
- [zig/perf] Summary list: indexes instead of pointers (watch type safety), out-of-band
  bools, SoA, sparse hashmaps, encodings instead of polymorphism. @45:20 ^f15
  > indexes instead of pointers watchever type safety store bullion out of band eliminate padding with structive arrays store sparse data in hashmaps use encodings instead of uh polymorphism
- [zig/perf] (claim) Commenter critique: hash access is much slower than pointer access,
  so out-of-band data in hashmaps trades footprint for lookup cost. ^f16
  > When storing out-of-band data in a hashtable, keep in mind that hash access is WAY slower than pointer access.

## Read

- Whole transcript; top 20 comments.

## Not read

- Slides and his gist of size scripts; "Handles are the better pointers" (floooh).
