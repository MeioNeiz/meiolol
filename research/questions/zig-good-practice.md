---
status: answered
priority: soon
area: code
tags: [zig]
description: What makes Zig code good, according to the official docs, the std library and well-respected Zig projects?
---
# What makes Zig code good, according to the official docs, the std library and well-respected Zig projects?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo. Children: zig-style, zig-memory, zig-errors-safety, zig-comptime, zig-api-design, zig-testing, zig-perf, zig-build

## Answer

Good Zig in 0.17, per the core team and the respected projects read (TigerBeetle,
Ghostty, ZLS, River, Roc, zig-clap, SuperHTML, the std and compiler), is explicit and
concrete: allocators and `io` passed in, unmanaged containers, concrete `*Io.Writer`
over anytype, no hidden globals (C1). It treats the official Style Guide and zig fmt as
the base and adds few rules, enforced mechanically where it matters (C2). It separates
bugs (asserts, kept on in shipped builds) from operating errors (codes plus diagnostics
out of band) (C3), and tests error paths, fuzzes and snapshots rather than piling up unit
tests (C4). Comptime stays sparse (C5); data is laid out for the machine where volume
matters (C6). Much widely repeated advice is stale, because the std changes every release
(C7). The guide is docs/zig/ (index README.md); children hold the per-topic claims.

## Claims

- C1: The core team's direction since 0.11 is concrete over generic and explicit over hidden. for: [[zig-015-release-notes#^f12]], [[zig-015-release-notes#^f1]], [[zig-016-release-notes#^f20]], [[zig-015-release-notes#^f22]], [[zig-learn-why#^f1]]
- C2: Mature projects add few rules over the Style Guide and zig fmt, enforcing what matters with lints. from: [[zig-style]]
- C3: Bugs are asserted and crash; operating errors are handled codes with details out of band. from: [[zig-errors-safety]]
- C4: Respected projects test error paths, fuzz and snapshot. from: [[zig-testing]]
- C5: Comptime is kept sparse in applications. from: [[zig-comptime]]
- C6: Data-oriented layout pays where data volume is large. from: [[zig-perf]]
- C7: The std is still a testbed and changes every release; advice older than 0.15 on I/O, containers, formatting and build is likely stale. for: [[zig-011-release-notes#^f24]], [[zig-017-release-notes#^f40]]
- C8: Bun's move to Rust is attributed by its author to Zig's lack of safety at scale and by Zig's author to Bun's practices. for: [[bun-in-rust#^f7]], [[ak-bun-rust-rewrite#^f2]], [[ak-bun-rust-rewrite#^f4]]

## Disagreements

See the children; the main ones: OOM abort vs propagate (zig-memory), shipping fast vs
safe (zig-errors-safety), snake_case vs camelCase functions (zig-style), anytype
(zig-comptime), built-in fuzzer vs own programs (zig-testing).

## Open


- Core team: what the langref, style guide and std source treat as idiomatic in 0.17
- Maintainers of mature projects (TigerBeetle, Ghostty, ZLS, River, Roc, Bun): which
  practices recur across them, and where they differ
- Newcomer: the common mistakes (dangling stack pointers, invalidated ArrayList pointers,
  leaks on error paths) and the idiom that prevents each
- Critic: where respected advice disagrees (static allocation, anytype, comptime depth)
- Performance person: data layout, allocation in hot paths, SIMD, build modes
- Version drift: which widely repeated advice is stale for 0.17
