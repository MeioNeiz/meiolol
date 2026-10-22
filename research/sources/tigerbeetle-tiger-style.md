---
title: TigerBeetle TIGER_STYLE.md (TigerStyle coding style guide)
url: https://raw.githubusercontent.com/tigerbeetle/tigerbeetle/main/docs/TIGER_STYLE.md
kind: docs
commit: 0450c32b2c3c3ab6114f3402cc601341cc8192aa
for: [zig-good-practice, zig-style, zig-errors-safety, zig-memory, zig-api-design, zig-perf, zig-testing]
looked: 2026-10-22
depth: docs (TIGER_STYLE.md word for word, internals/docs.md)
relevance: high
grade: A/strong
description: TigerBeetle's style guide: safety, performance, developer experience in that order; assertions, limits, static allocation, naming, 70-line functions, 100 columns
---
# TigerBeetle TIGER_STYLE.md (TigerStyle coding style guide)

Why: the most cited Zig style guide outside the official docs; what it says, why, and
which parts fit a crawler, stats pipeline, site generator and desktop app (meiolol).

## Assessment

- Evidence: A. TigerBeetle repo since April 2020, 17.2k stars, 923 forks, 127 named
  contributors (143 with anonymous), Apache-2.0, release 0.17.9 (July 2026), pushed
  2026-10-16. The guide is followed in a ~159k-line Zig codebase (247 .zig files) and
  enforced in part by a tidy test ([[tigerbeetle-tidy]]); widely copied by other Zig
  projects. Commit 0450c32 (2026-10-14), Zig 0.16.0 at that commit.
- Reasoning: strong. Almost every rule gives its why (physical screen size, fuzzing
  leverage, NASA Power of Ten, an OSDI paper on error handling); admits the style is
  "evolving".
- Interests: TigerBeetle is a company; the guide doubles as engineering-brand
  marketing (quotes, "biodigital jazz"). Rules are tuned for a distributed financial
  database with deterministic simulation testing.
- Weigh: trust the assertion, naming, error-handling, options-struct and control-flow
  rules as general. Static allocation, no recursion, `u32` over `usize` and "zero
  dependencies" come from database and safety-critical constraints; the guide itself
  states them as absolute rules, not as domain-specific. The code does not meet every
  number (see [[tigerbeetle-code]]: 2 asserts per function is met in VSR/LSM, not in
  stdx/io; ~10% of functions exceed 70 lines).

## Findings

- [zig/safety] Design goals are ranked: safety, then performance, then developer
  experience; style exists to serve them, readability is only table stakes. ^f1
  > Our design goals are safety, performance, and developer experience. In that order.
  > readability is table stakes, a means to an end rather than an end in itself.
- [zig/style] Zero technical debt policy: showstoppers found in design are fixed
  before shipping, because code is cheapest to change while hot. ^f2
  > TigerBeetle has a “zero technical debt” policy. We do it right the first time.
  > code, like steel, is less expensive to change while it's hot
- [zig/safety] Builds on NASA's Power of Ten: simple explicit control flow, no
  recursion so that bounded executions stay bounded, few abstractions because none is
  zero cost. ^f3
  > Do not use recursion to ensure that all executions that should be bounded are bounded.
  > Abstractions are [never zero cost](https://isaacfreund.com/blog/2022-05/).
- [zig/safety] Put a limit on everything: every loop and queue has a fixed upper bound,
  fail fast; a loop that must not end (event loop) asserts that. ^f4
  > all loops and all queues must have a fixed upper bound to prevent infinite loops or tail latency spikes.
  > Where a loop cannot terminate (e.g. an event loop), this must be asserted.
- [zig/style] Explicitly sized integers everywhere, avoid `usize`. ^f5
  > Use explicitly-sized types like `u32` for everything, avoid architecture-specific `usize`.
- [zig/safety] Assertions are for programmer errors, distinct from operating errors
  which must be handled; the only correct response to corrupt code is to crash. ^f6
  > Assertions detect programmer errors. Unlike operating errors, which are expected and which must be handled, assertion failures are unexpected.
  > Assertions downgrade catastrophic correctness bugs into liveness bugs.
- [zig/safety] Assert arguments, return values, pre and postconditions and invariants;
  minimum average of two assertions per function. ^f7
  > Assert all function arguments and return values, pre/postconditions and invariants.
  > The assertion density of the code must average a minimum of two assertions per function.
- [zig/safety] Pair assertions: enforce each property on two different code paths,
  e.g. before writing to disk and right after reading back. ^f8
  > For every property you want to enforce, try to find at least two different code paths where an assertion can be added.
- [zig/safety] Split compound assertions; use one-line `if` for implications. ^f9
  > Split compound assertions: prefer `assert(a); assert(b);` over `assert(a and b);`.
  > Use single-line `if` to assert an implication: `if (a) assert(b)`.
- [zig/safety] [zig/comptime] Assert relationships between compile-time constants:
  checks design integrity before the program runs. ^f10
  > Compile-time assertions are extremely powerful because they are able to check a program's design integrity _before_ the program even executes.
- [zig/safety] Golden rule: assert the positive space and the negative space; tests
  must cover invalid data and valid data turning invalid. ^f11
  > assert the _positive space_ that you do expect AND to assert the _negative space_ that you do not expect
  > **tests must test exhaustively**, not only with valid data but also with invalid data
- [zig/test] Assertions and fuzzing are not a substitute for understanding: model
  first, encode it as assertions, use the simulator (VOPR) as last line of defence. ^f12
  > a fuzzer can prove only the presence of bugs, not their absence.
  > use VOPR as the final line of defense
- [zig/memory] All memory statically allocated at startup; nothing allocated or freed
  after init. Why: predictable performance, no use-after-free, and simpler designs
  from considering all memory up front. ^f13
  > No memory may be dynamically allocated (or freed and reallocated) after initialization.
  > this also makes for more efficient, simpler designs that are more performant and easier to maintain
- [zig/style] Smallest possible scope, fewest variables in scope. ^f14
  > Declare variables at the **smallest possible scope**, and **minimize the number of variables in scope**
- [zig/style] Hard limit of 70 lines per function, for a physical reason (fits on a
  screen). ^f15
  > we enforce a **hard limit of 70 lines per function**.
- [zig/style] Splitting rules: inverse hourglass shape (few params, simple return, meaty
  body); keep control flow (`switch`/`if`) in the parent, push non-branchy work to
  helpers, keep leaf functions pure, parent owns state. Cites matklad's "push ifs up
  and fors down". ^f16
  > Good function shape is often the inverse of an hourglass: a few parameters, a simple return type, and a lot of meaty logic between the braces.
  > All control flow should be handled by _one_ function, the rest shouldn't care about control flow at all.
  > Let the parent function keep all relevant state in local variables, and use helpers to compute what needs to change, rather than applying the change directly. Keep leaf functions pure.
- [zig/build] All compiler warnings at the strictest setting from day one. ^f17
  > Appreciate, from day one, **all compiler warnings at the compiler's strictest setting**.
- [zig/api] Don't act directly on external events; run at your own pace and batch, for
  control of the control flow, performance, and bounded work per period. ^f18
  > **don't do things directly in reaction to external events**. Instead, your program should run at its own pace.
- [zig/style] Split compound conditions into nested if/else; every `if` should
  consider whether it needs an `else` to handle or assert the negative space. ^f19
  > Split complex `else if` chains into `else { if { } }` trees.
- [zig/style] State invariants positively: `if (index < count)` rather than
  `if (index >= count)`. ^f20
  > Negations are not easy! State invariants positively.
- [zig/errors] All errors must be handled; cites the OSDI'14 finding that 92% of
  catastrophic failures came from mishandled non-fatal errors. ^f21
  > All errors must be handled.
  > almost all (92%) of the catastrophic system failures are the result of incorrect handling of non-fatal errors explicitly signaled in software.
- [zig/style] Always say why: rationale raises understanding, compliance, and gives
  criteria to judge the decision. ^f22
  > **Always motivate, always say why**. Never forget to say why.
- [zig/api] Pass options explicitly at the call site rather than relying on library
  defaults, against latent bugs when defaults change. ^f23
  > **Explicitly pass options to library functions at the call site, instead of relying on the defaults**.
  > avoids latent, potentially catastrophic bugs in case the library ever changes its defaults.
- [zig/perf] Performance is won in design via back-of-the-envelope sketches over
  network, disk, memory, CPU and bandwidth, latency; optimise slowest resource first
  after weighting by frequency. ^f24
  > The best time to solve performance, to get the huge 1000x wins, is in the design phase, which is precisely when we can't measure or profile.
  > Perform back-of-the-envelope sketches with respect to the four resources (network, disk, memory, CPU) and their two main characteristics (bandwidth, latency).
- [zig/perf] Separate control plane from data plane; batching lets the control plane
  carry heavy assertions without slowing the data plane. ^f25
  > A clear delineation between control plane and data plane through the use of batching enables a high level of assertion safety without losing performance.
- [zig/perf] Extract hot loops into standalone functions with primitive arguments and
  no `self`, so the compiler need not prove fields can live in registers. ^f26
  > extract hot loops into stand-alone functions with primitive arguments without `self`
- [zig/style] Names: `snake_case` for functions, variables and files, also files
  holding a struct (departs from Zig's `CamelCase.zig`); no abbreviations; acronyms
  capitalised (`VSRState`); otherwise follow the Zig style guide. ^f27
  > We don't use Zig's `CamelCase.zig` style for "struct" files to keep the convention simple and consistent.
  > Use proper capitalization for acronyms (`VSRState`, not `VsrState`).
- [zig/style] Units and qualifiers go last, most significant word first:
  `latency_ms_max` not `max_latency_ms`, so related names group and line up. ^f28
  > For example, `latency_ms_max` rather than `max_latency_ms`.
- [zig/style] [zig/memory] Allocator names carry meaning: `gpa` and `arena` tell the
  reader whether `deinit` must be called. ^f29
  > but `gpa: Allocator` and `arena: Allocator` are excellent. They inform the reader whether `deinit` should be called explicitly.
- [zig/style] Related names of equal length (`source`/`target`, not `src`/`dest`) so
  derived names line up. ^f30
  > `source` and `target` are better than `src` and `dest`
- [zig/style] Helper and callback names carry the caller's name
  (`read_sector_callback`); callbacks go last in parameter lists. ^f31
  > `read_sector()` and `read_sector_callback()`.
  > Callbacks go last in the list of parameters.
- [zig/style] Order: important things first, `main` first; struct order is fields,
  then types, then methods. ^f32
  > The same goes for `structs`, the order is fields then types then methods:
- [zig/style] Don't overload a name with context-dependent meanings; prefer nouns
  because they work in prose and compose (`config.pipeline_max`). ^f33
  > a noun is often a better descriptor than an adjective or present participle
- [zig/api] Options struct whenever arguments can be mixed up; any function taking two
  `u64` must use one. Singletons (allocator, tracer) go positionally, general to
  specific. ^f34
  > A function taking two `u64` must use an options struct.
  > they should be threaded through constructors positionally, from the most general to the most specific.
- [zig/style] Commit messages matter more than PR descriptions, which `git blame`
  can't see. ^f35
  > a pull request description is not stored in the git repository and is invisible in `git blame`
- [zig/style] Comments are sentences (capital, full stop); explain why and, for tests,
  how (goal and method at the top). ^f36
  > Comments are sentences, with a space after the slash, with a capital letter and a full stop
  > think of writing a description at the top to explain the goal and methodology of the test
- [zig/style] Don't duplicate variables or alias them, to keep state in sync. ^f37
  > Don't duplicate variables or take aliases to them.
- [zig/api] [zig/perf] Pass arguments over 16 bytes as `*const` when a copy isn't
  meant, to catch accidental stack copies. ^f38
  > if the argument type is more than 16 bytes, then pass the argument as `*const`.
- [zig/api] [zig/memory] Construct large structs in place via an out pointer
  (`fn init(target: *T) !void`), for pointer stability and no stack copies; in-place
  init is viral up the containing struct. ^f39
  > Construct larger structs _in-place_ by passing an _out pointer_ during initialization.
  > Keep in mind that in-place initializations are viral
- [zig/style] Check variables close to their use to avoid place-of-check to
  place-of-use gaps (POCPOU). ^f40
  > **Don't introduce variables before they are needed.**
- [zig/api] [zig/errors] Simpler return types reduce branches at every call site:
  `void` > `bool` > `u64` > `?u64` > `!u64`. ^f41
  > `void` trumps `bool`, `bool` trumps `u64`, `u64` trumps `?u64`, and `?u64` trumps `!u64`.
- [zig/safety] Buffer bleeds: zero padding so stale bytes don't leak or break
  determinism. ^f42
  > Be on your guard for **[buffer bleeds](https://en.wikipedia.org/wiki/Heartbleed)**.
- [zig/memory] [zig/style] Blank lines group a resource allocation with its `defer`,
  so leaks are easier to spot. ^f43
  > Use newlines to **group resource allocation and deallocation**, i.e. before the resource allocation and after the corresponding `defer` statement
- [zig/style] Treat index, count and size as distinct types with explicit conversions
  (+1, times unit); show division intent with `@divExact`, `@divFloor`, `div_ceil`. ^f44
  > To go from an `index` to a `count` you need to add one, since indexes are _0-based_ but counts are _1-based_.
  > use `@divExact()`, `@divFloor()` or `div_ceil()` to show the reader you've thought through all the interesting scenarios where rounding may be involved.
- [zig/style] `zig fmt`, 4-space indent, hard 100-column limit (two copies side by
  side), trailing comma to let `zig fmt` wrap; braces on `if` unless one line. ^f45
  > Hard limit all line lengths, without exception, to at most 100 columns
  > add a trailing comma, close your eyes and let `zig fmt` do the rest.
- [zig/build] Zero dependencies apart from the Zig toolchain: supply chain, safety,
  performance, install time. ^f46
  > TigerBeetle has **a “zero dependencies” policy**, apart from the Zig toolchain.
- [zig/build] Scripts in Zig (`scripts/*.zig`), not shell, for portability and type
  safety across the team. ^f47
  > the next time you write a script, instead of `scripts/*.sh`, write `scripts/*.zig`.
- [zig/style] Docs style: every line of documentation is a line spent; hard wrap at
  100; American English; Oxford comma. `docs/internals/docs.md` ^f48
  > we should regard every line of documentation not as a line produced, but as a line spend.
- [zig/style] (inferred) Checked, not there: the guide never marks a rule as specific
  to databases or safety-critical code; static allocation, no recursion and `u32`
  are stated as absolutes. The domain framing is in ARCHITECTURE.md instead
  ([[tigerbeetle-architecture#^f2]]). ^f49

## Read

- `docs/TIGER_STYLE.md`: all 511 lines, word for word.
- `docs/internals/docs.md`: all.

## Not read

- Git history of TIGER_STYLE.md: when each rule was added (e.g. the in-place init and
  hot loop rules are recent).
