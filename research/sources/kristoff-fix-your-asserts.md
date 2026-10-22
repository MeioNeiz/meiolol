---
title: You Must Fix Your Asserts (Loris Cro, 2026)
url: https://kristoff.it/blog/fix-your-asserts/
kind: article
commit:
for: [zig-errors-safety, zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: A/strong
description: Zig core team member on how std.debug.assert works across build modes, side effects in asserts, debug-only expensive checks, and why disabling asserts in prod is wrong
---
# You Must Fix Your Asserts (Loris Cro, 2026)

Why: assertion policy and build modes, from the Zig team.

## Assessment

- Evidence: A. Loris Cro is VP of Community at the Zig Software Foundation; May 2026,
  links Zig 0.16 docs. Mechanics (assert = `if (!ok) unreachable`, build-mode
  semantics) are the language's own.
- Reasoning: strong. Separates three uses of asserts, argues costs, gives the
  counter-case (log instead of crash) in an edit.
- Interests: defends Zig's ReleaseFast against Rust-rewrite critics (Bun).
- Weigh: trust mechanics fully; the "never disable" stance is argued opinion, shared by
  TigerBeetle (which he cites).

## Findings

- [zig/safety] Prefer the type system over an assert when it can express the constraint (e.g. `*T` vs `?*T`). ^f1
  > If your type system can be used to enforce one of these constraints, then you will probably want to use the facilities in your language rather than asserts.
- [zig/safety] Asserts state pre- and postconditions and invariants, and with fuzzing catch more than unit tests. ^f2
  > **An assert is worth a thousand unit tests** (and orders of magnitude more than that if you fuzz)
- [zig/safety] `std.debug.assert` is `if (!ok) unreachable`; `unreachable` also works as an expression in impossible switch arms. ^f3
  > pub fn assert(ok: bool) void {
  > Another neat property of `unreachable` is that it can be used as a statement, but it is also valid anywhere an expression (of any type) is expected.
- [zig/safety] A tripped assert panics in Debug and ReleaseSafe; in ReleaseFast and ReleaseSmall it is unchecked illegal behaviour that the optimiser exploits. ^f4
  > Checked modes (Debug, ReleaseSafe, `@setRuntimeSafety(true)`) guarantee a crash of your program by panicking, while unchecked modes (ReleaseFast, ReleaseSmall, `@setRuntimeSafety(false)`) incur “unchecked illegal behavior”.
- [zig/build] Build mode can differ per dependency, and per block with `@setRuntimeSafety`. ^f5
  > every dependency can be built in a different mode and you can even use [`@setRuntimeSafety`](https://ziglang.org/documentation/0.16.0/#setRuntimeSafety) for block-level granularity within a single function.
- [zig/perf] In unchecked modes the optimiser propagates `unreachable` facts, sometimes non-locally. ^f6
  > optimizing compilers have the ability to propagate `unreachable` information, resulting in non-local optimizations that you might not be able to easily anticipate as a programmer.
- [zig/safety] `assert` is a function, not a macro: its argument is always evaluated, so side effects in it are fine. ^f7
  > assert(my_map.remove("expected-to-exist"));
- [zig/perf] Expensive assert computations are not elided in release; guard them with a comptime `if (builtin.mode == .Debug)`. ^f8
  > if you have an assert that relies on performing complex computations, then those won’t necessarily be elided when building in unchecked modes, in which case you need to take care to guard the code with a comptime `if`:
- [zig/safety] Disabling asserts in production is in his view irredeemably bad: wrong asserts stay hidden and later code builds on them. ^f9
  > **I believe it to be an irredeemably bad practice**.
  > **because otherwise you will keep writing more code that mistakenly relies on those wrong assertions**
- [zig/safety] Valid choices: keep asserts on (ReleaseSafe) when misbehaviour is costly, or use ReleaseFast when speed matters more; even then, build critical C deps fast. ^f10
  > When the time comes, I’ll publish ReleaseSafe builds, but even then I will still build some critical dependencies in ReleaseFast
- [zig/safety] A variant he accepts: an assert that logs instead of crashing, where crashing is worse and a human reads the logs. ^f11
  > Another variant of the second case is to have the assert print a log line instead of crashing the program
- [zig/safety] Language-level safety checks (overflow, bounds, division by zero) can't be disabled by the user's assert choices. ^f12
  > Zig as a language will always implicitly add a lot of asserts to your code that you can’t disable

## Read

- Whole post including the 2026-06-01 edit.
