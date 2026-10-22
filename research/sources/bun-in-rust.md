---
title: 'Bun in Rust (Jarred Sumner, bun.sh blog, 2026): why and how Bun left Zig'
url: https://bun.sh/blog/bun-in-rust.md
kind: article
for: [zig-good-practice, zig-memory, zig-errors-safety, zig-comptime]
looked: 2026-10-22
depth: docs (whole post, Zig-relevant sections read closely)
relevance: high
grade: B/strong
description: Bun's creator explains moving 535k lines of Zig to Rust (v1.4, 2026): lifetime bugs across GC and manual memory, defer per call site, comptime bloat, ReleaseFast without bounds checks
---
# Bun in Rust (Jarred Sumner, bun.sh blog, 2026): why and how Bun left Zig

Why: the largest Zig codebase dropped Zig; what practices failed it, in its author's words?
(A project's own account; the community reader covers reactions, e.g. Andrew Kelley's reply.)

## Assessment

- Evidence: B. First-hand report by Bun's creator on a 535k-line Zig codebase, with bug
  links and measurements (leak table, binary sizes). Dated 2026-07-08.
- Reasoning: strong. Credits Zig, says other Zig users lack Bun's bugs, names the special
  cause (GC mixed with manual memory), lists what they already did.
- Interests: strong. Bun is owned by Anthropic; the author works there and used a
  pre-release Claude model for the port, so the post also showcases AI porting.
- Weigh: trust the description of their Zig pain points; the Rust gains partly come from
  fixes made during the port. The lesson for us is about lifetime discipline, not language.

## Findings

- [zig/memory] Bun's main stability problem: lifetimes of GC values mixed with manually
  managed memory, giving small leaks and some crashes; every allocation had to be reviewed. `raw/bun-in-rust.md` ^f1
  > For Bun, correctly handling the lifetimes of garbage-collected values and manually-managed values has been a major source of stability issues
- [zig/memory] Not blamed on Zig in general: other Zig users do not have these bugs, and
  mixing GC with manual memory is uncommon. ^f2
  > I don't blame Zig for that - other users of Zig don't have the bugs we had
- [zig/memory] Their Zig lifetime strategy: arenas where scope is clear (parser state, AST
  nodes), reference counting, and close attention. ^f3
  > arena lifetimes, where the scope of when it's accessible is clear
- [zig/memory] [zig/errors] defer must be written at every call site, so cleanup is easy
  to forget (leak) or run twice in rarely reached error paths (double free). ^f4
  > It's easy to end up forgetting to clean up (a memory leak), or to run cleanup code twice in rarely-reached error handling code (a double-free).
- [zig/memory] Leaks of file paths in error-handling code were among those fixed by
  automatic cleanup; a Zig attempt at full leak tracking was not merged for lack of Drop. ^f5
  > `Drop` fixed several memory leaks in Bun related to file paths in error handling code.
- [zig/safety] What they already did in Zig: a compiler patch for AddressSanitizer with the
  test suite under ASAN on every commit, ReleaseSafe builds on Windows, 24/7 fuzzing,
  end-to-end leak tests. ^f6
  > We patched the Zig compiler to add Address Sanitizer support.
  > We ship Zig safety-checked ReleaseSafe builds on Windows
- [zig/safety] Shipping ReleaseFast on macOS and Linux removed bounds checks; an
  off-by-one from the Zig code panicked in Rust, and would have in Zig under ReleaseSafe. ^f7
  > On macOS & Linux, we compiled Bun's Zig code with `ReleaseFast`, which removes bounds checks.
  > Zig would also panic in this case, if we used `ReleaseSafe` (we only did on Windows).
- [zig/safety] Zig's `assert` is a plain function, so its argument (side effects
  included) runs in every build. ^f8
  > Zig's `assert` is a function, so its argument runs in every build.
- [zig/comptime] [zig/perf] Too much comptime: the port cut the binary by 3.8 to 6.8 MB
  per platform, largely because of comptime overuse in the Zig code. ^f9
  > This is largely because we used too much `comptime` in our Zig code.
- [zig/comptime] Comptime format strings let `Output.pretty` rewrite colour markers before
  arguments are substituted, which Rust could not do. ^f10
  > In Zig, `fmt` is `comptime`, so the markers are gone before the arguments are substituted.
- [zig/perf] Large Zig functions with nested scopes used much stack (no LLVM lifetime
  markers, zig issue 23475); they split big functions as a workaround. ^f11
  > Previously, we manually worked around [an open issue](https://github.com/ziglang/zig/issues/23475) by [refactoring particularly large functions]
- [zig/style] Style guides (TigerStyle named) need enforcement; review and linters were the
  only tools. ^f12
  > The challenge with style guides is enforcement.
- [toolchain] v1.3.14 was the last Zig version of Bun; v1.4.0 the first in Rust. ^f13
  > Bun v1.3.14 was the last version of Bun written in Zig.

## Read

- whole post; sections on motivation, what we were doing, regressions, leaks, binary size, stack

## Not read

- linked PRs and issues; PORTING.md on Hacker News
