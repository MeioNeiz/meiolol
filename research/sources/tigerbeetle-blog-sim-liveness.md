---
title: Simulation Testing For Liveness (TigerBeetle blog, matklad, 2023)
url: https://tigerbeetle.com/blog/2023-07-06-simulation-testing-for-liveness
kind: article
commit:
for: [zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: VOPR split into safety mode (uniform random faults) and liveness mode (heal a core, make other faults permanent), with a resonance bug it found
---
# Simulation Testing For Liveness (TigerBeetle blog, matklad, 2023)

Why: how TigerBeetle's simulator checks progress, not only correctness.

## Assessment

- Evidence: B. Real bugs found (issue 913, PR 934).
- Reasoning: fair.
- Interests: none.
- Weigh: distributed-systems specific; the transferable idea is that random faults
  that always heal hide stuck states.

## Findings

- [zig/test] Uniform random fault injection checks safety but hides liveness bugs,
  because every fault eventually heals. ^f1
  > this partition would not have been permanent—at some point it would heal and the vicious view change cycle would be broken (and undetected).
- [zig/test] Liveness mode: heal a quorum core, make all other faults permanent, then
  require the core to finish all work within a timeout. ^f2
  > for all failures involving non-core replicas, making those failures permanent.
- [zig/test] It found a round-robin repair schedule that resonated with which replica
  held which entry, livelocking repair. ^f3
  > The most fun was a [resonance bug between our repair algorithm]

## Read

- Whole post.
