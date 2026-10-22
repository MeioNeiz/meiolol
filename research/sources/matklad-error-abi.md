---
title: Error ABI (matklad, 2025-11-09)
url: https://matklad.github.io/2025/11/09/error-ABI.html
kind: article
commit: 
for: [zig-errors-safety, zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: Large ADT errors pessimise the happy path ABI; register-sized error codes or unwinding avoid it
---
# Error ABI (matklad, 2025-11-09)

Why: the performance case for small error values (Zig's error codes are register-sized).
Language design post, mostly Rust examples; no Zig version dependence.

## Assessment

- Evidence: B. Expert reasoning; he admits no reproducible benchmarks for the unwinding
  claim and cites two outside sources.
- Reasoning: fair. Mechanism is clear; the optimality claim is untested.
- Interests: none.
- Weigh: the ABI argument supports keeping error payloads out of return types, which
  Zig enforces anyway; use as background.

## Findings

- [zig/perf] [zig/errors] Large error types inflate the result size and push functions
  across the call stack to return through memory; one large rare error worsens code
  everywhere. ^f1
  > Naively composing errors out of ADTs does pessimize the happy path.
  > Error virality is key here — just a single large error on however rare code path leads to worse code everywhere.
- [zig/perf] Mature Rust error libraries (failure, anyhow) hide errors behind a thin
  pointer, which needs a global allocator. ^f2
  > That is the reason why mature error handling libraries hide the error behind a thin pointer
- [zig/perf] A better ABI reserves one register for a register-sized error. ^f3
  > the ABI of `-> Result<T, E>` is exactly the same as `T`, except that a single register is reserved for `E` (this requires the errors to be register-sized)
- [zig/errors] (claim) Unwinding may be optimal; no reproducible benchmarks known. ^f4
  > The bold claim is that unwinding is the optimal thing to do! I don’t know of a good set of reproducible benchmarks
- [zig/errors] (inferred) Zig's error codes plus an out-of-band Diagnostics sink keep the
  error part of `E!T` register-sized, which is this post's argument applied. ^f5

## Read

- Whole post.

## Not read

- Joe Duffy "safe native code" error model; linked talk. Other authors.
