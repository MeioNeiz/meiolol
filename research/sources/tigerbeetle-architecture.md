---
title: TigerBeetle ARCHITECTURE.md and internals docs (HACKING, VOPR, testing)
url: https://raw.githubusercontent.com/tigerbeetle/tigerbeetle/main/docs/ARCHITECTURE.md
kind: docs
commit: 0450c32b2c3c3ab6114f3402cc601341cc8192aa
for: [zig-memory, zig-testing, zig-errors-safety, zig-perf, zig-good-practice]
looked: 2026-10-22
depth: docs (ARCHITECTURE.md design decisions; internals HACKING, vopr, testing, README)
relevance: high
grade: A/strong
description: TigerBeetle's own account of why static allocation, single thread, determinism, simulation testing, no dependencies and Zig; plus how to build, test and fuzz
---
# TigerBeetle ARCHITECTURE.md and internals docs (HACKING, VOPR, testing)

Why: TIGER_STYLE.md states rules; ARCHITECTURE.md says what problem they solve, which
is where the domain limits of Tiger Style show.

## Assessment

- Evidence: A. Same project as [[tigerbeetle-tiger-style]] (since 2020, 17.2k stars,
  127 contributors, production financial database, Jepsen-tested 0.16.11). The docs
  describe the code as shipped at 0450c32 (Zig 0.16.0).
- Reasoning: strong. Each decision has a positive and negative reason; it says where
  terms are used idiosyncratically ("static allocation") and compares Zig with Rust.
- Interests: vendor docs, partly persuasive.
- Weigh: the design reasons are tied to an OLTP database (contention, durability,
  byte-identical replicas). Treat static allocation and single threading as answers to
  that workload, not as general Zig practice.

## Findings

- [zig/memory] "Static allocation" means: at startup compute the worst-case count of
  every object type from CLI arguments, allocate exactly that, then never allocate
  again; not `.bss` statics and not an arena that can still run out. ^f1
  > When TigerBeetle starts, for every "object type" in the system it computes the worst-case upper bound for the number of objects needed, based on CLI arguments.
  > This is also different from arena allocation.
- [zig/memory] Static allocation is a forcing function for limits; limits give
  backpressure for free and bound concurrency, since each "future" is a struct field
  owned by a component. Speed and low latency variance are a consequence, not the main
  reason. ^f2
  > **static allocation is a forcing function to ensure that everything has a limit**
  > TigerBeetle _can't_ heap allocate structures at runtime.
  > it is not the main reason for choosing static allocation.
- [zig/perf] Single threaded by design: the workload is contended (hot accounts), so
  parallel transactions don't help; one core reaches 1M TPS with efficient use, and
  testing gets simpler. ^f3
  > TigerBeetle is single-threaded.
  > keeping the system single threaded greatly simplifies the programming model and makes testing much more efficient.
- [zig/build] No dependencies beyond Linux (io_uring), the Zig compiler and parts of
  std; usefulness of dependencies falls with project lifetime; Zig's std APIs suit
  static allocation. ^f4
  > The usefulness of dependencies is generally inversely-proportional to the lifetime of the project.
  > It is a pleasant intentional coincidence that Zig's standard library APIs are compatible with static allocation.
- [zig/memory] [zig/api] Why Zig: no GC needed; Rust's temporal and thread safety
  matter less under static allocation and one thread; idiomatic Zig containers take
  the allocator per method, not in the constructor, which fits static allocation. ^f5
  > Rust has better temporal and thread safety but static allocation and single-threaded execution reduce the relative importance of these benefits.
  > Idiomatic Zig collections don't have an allocator as a parameter of the constructor. Instead they explicitly pass an allocator to the methods that require allocation.
- [zig/comptime] Zig is "a DSL for machine code": comptime lets you express directly
  what the machine should do, at the cost of no declaration-site interfaces. ^f6
  > Zig is a DSL for machine code.
  > This comes at the cost of missing declaration-site interfaces but it's less important in a zero-dependency context.
- [zig/test] Determinism is the meta principle above static allocation: same input,
  same logical result by the same physical path; any randomised test failure
  reproduces from its seed. ^f7
  > A meta principle above "static allocation" is determinism.
  > Any test failure can be reliably reproduced by sharing a seed that led to the failure.
- [zig/test] Simulation testing is the most important technique: the whole cluster on
  one thread with storage faults and fast time; unlike TLA+ it tests the
  implementation. ^f8
  > The most important technique deployed is simulation testing
  > unlike formal proofs and model checking, the simulation testing exercises a specific implementation.
- [zig/perf] [zig/safety] Control plane vs data plane: keep control `if`s out of data
  `for`s; the cheap control plane can afford O(N) assertions for O(1) work. ^f9
  > Keeping control plane `if`s outside of data plane `for`s keeps the inner loop free of branching.
  > the overhead of control plane is small so it can use very aggressive assertions (up to spending O(N) time to verify O(1) operation).
- [zig/perf] The `commit` function is synchronous and does no IO; all IO happens in a
  separate prefetch phase that can run in parallel. ^f10
  > Crucially, the `commit` function itself doesn't do any reading from storage.
  > All IO happens in the separate prefetch phase.
- [zig/memory] [zig/api] Async IO without heap-allocated contexts: each component owns
  fixed arrays of operation structs, linked by `IO` into an intrusive list; total
  concurrency is the sum of per-component limits. ^f11
  > In TigerBeetle, each component stores its own resumption contexts.
  > The limit is implicit, it is the sum of per-component explicit limits.
- [zig/safety] Assertions stay on in production: better to stop than run in an
  incorrect state; thousands of assertions plus simulator checkers. `docs/internals/vopr.md` ^f12
  > TigerBeetle is somewhat unique in that it keeps these assertions on, even in production.
  > it is far better to stop operating than to continue operating in an incorrect state.
- [zig/test] VOPR stubs every non-deterministic part (clock, network, disk), injects
  faults from a seed, and replays any failure from seed plus commit; one VOPR minute
  equals days of real testing. `docs/internals/vopr.md` ^f13
  > In the simulator, all non-deterministic parts of the system are stubbed out. This includes the clock, network, and disk operations.
  > When a simulation causes any type of failure, the seed and Git commit hash can be used to replay back the exact simulation and bug.
- [zig/build] Dev loop: pinned Zig downloaded into the repo (`./zig/download.ps1`,
  then `./zig/zig build`); `zig build test -- <filter>`; `zig build fuzz -- smoke`;
  `zig build check` to compile without emitting a binary; `zig build ci` mirrors CI.
  `docs/internals/HACKING.md` ^f14
  > ./zig/download.ps1 # Yes, .ps1 even on Linux.
  > Quickly check if the code compiles without spending time to generate the binary:
  > ./zig/zig build ci
- [zig/style] Code review: one assigned reviewer, co-responsible for the PR landing;
  an extra reviewer when a change affects version `v` and `v+1` compatibility.
  `docs/internals/HACKING.md` ^f15
  > Only a single person is assigned to any particular pull request, to avoid diffusion of responsibility and the bystander effect.
- [zig/memory] (inferred) Checked, not there: ARCHITECTURE.md never claims static
  allocation suits every program; it justifies it through database properties
  (overload, bounded concurrency, determinism, byte-identical replicas). The domain
  framing is implicit, not a stated caveat. ^f16

## Read

- `docs/ARCHITECTURE.md`: Design Decisions sections (Intentionality to io_uring,
  Message Passing).
- `docs/internals/HACKING.md`, `vopr.md`, `testing.md`, `README.md`: all.

## Not read

- `docs/ARCHITECTURE.md` LSM, Grid, Time, Direct IO, Flexible Quorums, Protocol
  Aware Recovery, Hash-Chaining: database internals, not Zig practice.
- `docs/internals/vsr.md`, `lsm.md`, `sync.md`, `upgrades.md`, `releases.md`.
