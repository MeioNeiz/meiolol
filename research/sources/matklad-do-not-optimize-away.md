---
title: Do Not Optimize Away (matklad, 2025-12-09)
url: https://matklad.github.io/2025/12/09/do-not-optimize-away.html
kind: article
commit: 
for: [zig-perf, zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Benchmark scaffold in Zig without doNotOptimizeAway: runtime-overridable parameters from env vars and print a hash of the results
---
# Do Not Optimize Away (matklad, 2025-12-09)

Why: how to write benchmarks that measure the real thing. Zig 0.15 era
(`process.hasEnvVarConstant`, `process.parseEnvVarInt`); in 0.16+ env access moved
(environ through `std.process.Init`), so the scaffold's API calls are stale but the idea
holds.

## Assessment

- Evidence: B. Expert practice; small example.
- Reasoning: strong. Names both pitfalls (dead code elimination, constant folding) and
  why black_box is unsatisfying.
- Interests: none.
- Weigh: trust the method; check env var API names for 0.17.

## Findings

- [zig/perf] Two benchmark pitfalls: an unused result is optimised away, and compile-time
  known parameters get constant folded. ^f1
  > a reasonable compiler can notice that `computation`’s result is not used, and optimize the entire computation away.
  > compiler can constant-fold parts of it, taking advantage of the fact that values of parameters are known at compile time.
- [zig/perf] He distrusts `mem.doNotOptimizeAway` and `hint::black_box`: their meaning
  can't be explained as semantics-preserving transformation. ^f2
  > Usually languages provide some sort of an explicit “please do not optimize this away” function, like Rust’s `hint::black_box` or Zig’s `mem.doNotOptimizeAway`, but they always felt like dragon oil to me
- [zig/perf] [zig/test] Scaffold: `parameter("element_count", 1_000_000)` reads an env var
  with a default and prints it; inputs can't be folded and reruns need no recompile. ^f3
  > Because the value _can_ be specified at runtime, compiler can’t optimize assuming a particular constant.
- [zig/perf] [zig/test] Output: accumulate `hash +%= insertion_point(elements, key)` and
  print it with the timing; a wrong optimisation shows as a changed hash. ^f4
  > With the hash, if I mess my optimization work to the point of getting a wrong answer, I _immediately_ see that reflected in an unexpected value of the hash.
- [zig/perf] Rule: runtime-overridable inputs with compile-time defaults, and print the
  result or its hash. ^f5
  > Make input parameters runtime overridable (with compile time defaults),
- [zig/memory] The benchmark function takes `arena: Allocator` for its inputs. ^f6
  > fn benchmark(arena: Allocator) !void {

## Read

- Whole post.

## Not read

- godbolt link.
