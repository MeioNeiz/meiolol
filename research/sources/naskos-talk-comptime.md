---
title: A Practical Guide to Compile Time Evaluation (Alex Naskos, Zig SHOWTIME 2020)
url: https://www.youtube.com/watch?v=iFBAUoQUJ2E
kind: talk
commit:
for: [zig-comptime]
looked: 2026-10-22
depth: docs (full transcript)
relevance: low
grade: C/fair
description: 2020 core-team talk on comptime semantics (static lifetime, concatenation, typeInfo/@Type, peer type quirk, comptime closures hack); mostly stale for 0.17
---
# A Practical Guide to Compile Time Evaluation (Alex Naskos, Zig SHOWTIME 2020)

Why: what changed in comptime idioms since 2020.

## Assessment

- Evidence: C for today's code. Alex Naskos was core team and co-wrote ZLS; Sep 2020,
  Zig 0.6/0.7; 2.5k views.
- Reasoning: fair.
- Interests: none.
- Weigh: stale: `std.meta.trait` removed (0.12), `anytype` struct fields gone, comptime
  closure tricks discouraged; 0.17 changed `@Type`/type info. Keep only the semantics
  and the build-step-vs-comptime discussion.

## Findings

- [zig/comptime] Comptime values have static lifetime: references to comptime locals never dangle. ^f1
  > in compile time every value has a static lifetime this means that it is valid forever it cannot go out of scope and be destroyed
  @0:44
- [zig/comptime] Comptime slice concatenation creates a new value each time; keep it to a minimum. ^f2
  > of course you should try to keep this at a minimum because every time you concatenate a new value is created so some more memory will be used by the compiler
  @2:16
- [zig/comptime] He shows hacks (comptime closures, relying on peer-type quirks) and says not to rely on them. ^f3
  > so yes of course you shouldn't rely on this this is totally wrong please
  @14:18
- [zig/build] Q&A: generating a Zig file in a build step is easier to inspect than comptime-generated structures (stack traces, reading the output). ^f4
  > one big upside a list of that being a possibility is that that way you can easily inspect what the result of like a let's say user space import is
  @29:55
- [toolchain] (inferred) Stale for 0.17: `std.meta.trait` and `anytype` fields shown in the talk no longer exist. ^f5

## Read

- Full transcript.
