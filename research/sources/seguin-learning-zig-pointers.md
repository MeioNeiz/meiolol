---
title: Learning Zig - Pointers (Karl Seguin)
url: https://www.openmymind.net/learning_zig/pointers/
kind: book
commit:
for: [zig-memory, zig-api-design, zig-perf]
looked: 2026-10-22
depth: skimmed
relevance: low
grade: B/fair
description: Chapter on value vs pointer parameters, const parameters, struct layout and shallow copies
---
# Learning Zig - Pointers (Karl Seguin)

Why: what newcomers are told about parameter passing and layout.

## Assessment

- Evidence: B. Widely read intro; revised for 0.16.
- Reasoning: fair.
- Interests: none known.
- Weigh: his "Zig can pass parameters however it wants" describes parameter reference
  optimisation, which has known aliasing hazards (see ^f4); don't rely on it either way.

## Findings

- [zig/style] A `var` that is never mutated is a compile error; it must be `const`. ^f1
  > That was a unkind trick; the code won't compile: _local variable is never mutated_.
- [zig/perf] Plain struct layout is unspecified; `packed` or `extern` give guarantees. ^f2
  > By default, Zig doesn't make guarantees about the memory layout of structures.
- [zig/api] Parameters are constants; take `*T` to mutate the caller's value. Method calls take the address automatically. ^f3
  > Zig knows that the method expects a pointer and passes the value correctly (by reference).
- [zig/api] He says the compiler may pass a by-value parameter by reference when it can't be mutated. ^f4
  > Zig can pass parameters however it wants, so long as it can guarantee that the intent of the code is preserved.
- [zig/memory] Copies are shallow: a copied struct's slice still points at the same bytes. ^f5
  > The answer is that only a shallow copy of the value is made.

## Read

- Skimmed the chapter prose.
