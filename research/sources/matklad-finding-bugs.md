---
title: Finding Bugs (matklad, 2026-09-19)
url: https://matklad.github.io/2026/09/19/finding-bugs.html
kind: article
commit: 
for: [zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: Case study of a small fuzzer (Rust) finding two regex crate bugs: oracle comparison, small tricky inputs, swarm distributions, reused memory
---
# Finding Bugs (matklad, 2026-09-19)

Why: generative testing technique, language neutral (examples in Rust); he applies the
same at TigerBeetle in Zig.

## Assessment

- Evidence: B. Found the known bug plus another in regex-automata 0.4.15; code public
  (matklad/regex-fuzz). He calls his own argument "very weak" since he knew the target.
- Reasoning: strong. Explicit about what the case shows and doesn't.
- Interests: argues for generative testing over unit tests (a lobste.rs debate).
- Weigh: the techniques are the point; port to Zig directly.

## Findings

- [zig/test] When a bug dodged the fuzzers, treat it as a fuzzer bug first: change the
  fuzzer to find it and related bugs, only then fix and add a unit test. ^f1
  > whenever you have a pest that dodged your fuzzers, your first order of business is to treat this event as a bug in the _fuzzer_
- [zig/test] Most important technique for algorithms: compare with an oracle (e.g. an
  O(N^2) version against the O(N log N) one). ^f2
  > by far the most important technique for testing algorithms is to compare with the known right answer, with an oracle.
- [zig/test] Design reliable systems to have an oracle: TigerBeetle exposed internal
  timestamps for Jepsen and is co-designed with its simulator VOPR. ^f3
  > if you are designing a reliable system, it’s part of your job to ensure it has an oracle!
- [zig/test] Even a plain PRNG is brutally effective if used well. ^f4
  > the insight is that even a humble PRNG is brutally effective, if you put it to good use.
- [zig/test] Generate small, tricky inputs, not huge ones; strings from a random subset
  of a fixed alphabet (sorted unique chars of the unit tests), random length. ^f5
  > Bugs _usually_ involve small, but tricky examples, weaponizing interactions between a few features.
- [zig/test] [zig/memory] Keep iterations fast by reusing memory across iterations,
  "static allocation in the small". ^f6
  > I make sure to re-use the memory across iterations
- [zig/test] Swarm testing: make the distribution itself random (feature weights 0-100,
  some features off per run). ^f7
  > an easy way to spice things up is to make the distribution _itself_ random.
- [zig/test] Recursive generators thread a size budget, split between children. ^f8
  > To control regex length, a `size` parameter is also threaded, and “branching” recursive invocations divide the `size` between the children
- [zig/test] Takeaway: co-designing the system and its test harness is leverage. ^f9
  > Black box testing is cool, but co-designing system and its testing harness is a point of leverage (build an oracle!).

## Read

- Whole post.

## Not read

- lobste.rs thread (linked): debate context, low value.
