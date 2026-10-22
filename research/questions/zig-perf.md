---
status: answered
parent: zig-good-practice
priority: soon
area: code
tags: [zig/perf]
description: How do respected Zig projects write fast code: data-oriented design, memory layout, SoA, SIMD, avoiding allocation in hot paths?
---
# How do respected Zig projects write fast code: data-oriented design, memory layout, SoA, SIMD, avoiding allocation in hot paths?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo

## Answer

Memory is the bottleneck, so shrink the struct you have most of: u32 indexes instead of
pointers, out-of-band bools, SoA via MultiArrayList, sparse fields in maps, encodings
instead of polymorphism; the compiler measured 22-39% wall-time gains (C1, C2). Typed
indexes, a separate API type (Key) from storage (Item), and extra arrays keep data dense
and serialisable (C3). Hot loops are free functions over slices with control flow outside
(push ifs up, fors down), batched (C4). Labelled switch for dispatch loops (C5). Everyday
SIMD: splat, vector loop, reduce, bit mask, scalar tail (C6). Packed integer records make
multi-field checks one compare (C7). Profile first and benchmark against a baseline;
`inline`, branch hints and safety opt-outs only with a measurement (C8, C9). Reserve
capacity outside loops; reuse arenas (C10). The optimiser can't see through vtables, so
hot paths stay above them (C11).

## Claims

- C1: Shrinking the most numerous struct (indexes, out-of-band bools, SoA, encodings) gave the compiler 22-39% wall-time gains. for: [[zig-talk-kelley-dod#^f2]], [[zig-talk-kelley-dod#^f7]], [[zig-talk-kelley-dod#^f12]], [[zig-talk-kelley-dod#^f13]] against: [[zig-talk-kelley-dod#^f16]]
- C2: Big homogeneous data uses MultiArrayList, u32 indexes and side extra arrays. for: [[zig-compiler-dod#^f1]], [[zig-compiler-dod#^f7]], [[zig-std-containers#^f26]], [[roc-zig-compiler#^f12]]
- C3: Separate the API type from the storage type; intern for index equality. for: [[zig-compiler-dod#^f16]], [[zig-compiler-dod#^f17]]
- C4: Hot loops are free functions over slices with branching in the caller. for: [[tigerbeetle-tiger-style#^f26]], [[tigerbeetle-code#^f18]], [[matklad-push-ifs-up#^f6]]
- C5: Labelled switch with continue suits dispatch loops (tokenizer 13% faster). for: [[zig-014-release-notes#^f1]], [[zig-014-release-notes#^f2]], [[zig-langref-017-a#^f105]]
- C6: Explicit SIMD follows splat, vector loop, reduce, mask and ctz, with a scalar tail. for: [[mitchellh-everyone-should-know-simd#^f1]], [[mitchellh-everyone-should-know-simd#^f2]], [[ghostty-repo#^f97]]
- C7: Small hot records as packed integers allow masked multi-field checks. for: [[ghostty-repo#^f73]], [[zig-langref-017-a#^f77]]
- C8: Profile first and benchmark against a do-nothing baseline; complexity needs evidence. for: [[mitchellh-ghostty-devlog-006#^f3]], [[mitchellh-ghostty-devlog-006#^f4]], [[river-repo#^f4]]
- C9: inline fn is not a hint and can hurt; @branchHint marks rare paths. for: [[zig-langref-017-a#^f122]], [[zig-langref-017-a#^f124]], [[zig-std-containers#^f15]]
- C10: Arena reset with retain_capacity removes per-iteration allocation. for: [[zig-std-allocators#^f13]], [[seguin-leveraging-allocators#^f2]]
- C11: Hot paths stay above any vtable. for: [[zig-talk-kelley-flush#^f9]], [[zig-std-io#^f9]]
- C12: Benchmarks read inputs at runtime and print a result hash. for: [[matklad-do-not-optimize-away#^f4]], [[matklad-do-not-optimize-away#^f5]]
- C13: Recompute cheap math rather than memoise. for: [[zig-talk-kelley-dod#^f1]]
- C14: Hash maps slow after many removals; array hash maps do not. for: [[zig-014-release-notes#^f24]]

## Disagreements

- Out-of-band data in hash maps: footprint win (Kelley) vs slower lookups (commenter);
  measure on the access pattern.
- Forcing inline: Ghostty measured 15-20% on 0.15.2; the langref warns it can hurt.

## Open

- Assert cost in meiolol's hot stats loops on 0.17 fast builds
