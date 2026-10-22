---
title: Improving Fuzz Testing with Zig Allocators (Ryan Liptak, 2021)
url: https://www.ryanliptak.com/blog/improving-fuzz-testing-with-zig-allocators/
kind: article
commit:
for: [zig-testing, zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: Custom wrapping allocators for fuzzing: fail on suspiciously large allocations, and FailingAllocator with an input-derived failure index
---
# Improving Fuzz Testing with Zig Allocators (Ryan Liptak, 2021)

Why: allocator wrappers as test instruments, relevant to parsing untrusted Riot data.

## Assessment

- Evidence: B. std contributor, applied to his audiometa parser with AFL++; Oct 2021,
  updated May 2022 (Zig 0.9). Zig 0.14+ has built-in fuzzing (`zig build --fuzz`), so
  the AFL setup is dated; the allocator ideas are not.
- Reasoning: strong; measured inputs/sec before and after.
- Interests: none.
- Weigh: trust the techniques.

## Findings

- [zig/perf] Slow fuzz inputs came from trusting length fields in the input and allocating huge buffers. ^f1
  > My library would, in certain cases, take these headers at their word and try to allocate the given length, even if that length was not really feasible, e.g. if the length was larger than the size of the entire input data.
- [zig/test] A wrapping allocator that fails on allocations larger than a multiple of the input size turned those into crashes the fuzzer reports. ^f2
  > In order to be certain that all bugs of this nature are ironed out, I thought it'd make sense to induce a crash if a suspiciously large allocation were ever attempted.
- [zig/perf] After the fixes the fuzzer ran consistently above 6000 inputs/sec with no timeouts. ^f3
  > Afterwards, the fuzzer was able to run consistently above 6000 inputs/sec on my machine, without hitting any timeouts at all.
- [zig/test] Fuzz OOM paths by hashing the input into a reproducible FailingAllocator index. ^f4
  > Hash the input data into an integer and use that as the initial FailingAllocator 'allocation index'

## Read

- Whole post.
