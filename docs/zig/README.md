# Writing good Zig (0.17)

A practice guide built from the official docs, the 0.17 std and compiler source, and the
codebases the Zig community treats as exemplary (TigerBeetle, Ghostty, ZLS, River, Roc,
zig-clap, SuperHTML, Bun's last Zig tag) plus matklad, Mitchell Hashimoto, Loris Cro and
Karl Seguin. Every rule says why, shows real code, and names where sources disagree.

Read this index, then only the file for the task. Section numbers are global (memory.md
holds 5.1-5.15), so a reference like "memory.md 5.7" stays valid when files change.

## Files

| File | Sections | Read when |
| --- | --- | --- |
| [sources.md](sources.md) | 1 | judging a source or its Zig version |
| [principles.md](principles.md) | 2 | the core team's direction in one page |
| [style.md](style.md) | 3.1-3.7 | naming, file layout, formatting, function size, comments |
| [idioms.md](idioms.md) | 4.1-4.15 | const, expressions, for, slicing, switch, unions, casts, layouts, undefined, defaults |
| [memory.md](memory.md) | 5.1-5.15 | allocators, `init.gpa`, containers, defer/errdefer, reserve-first, arenas, ownership, limits, OOM |
| [errors.md](errors.md) | 6.1-6.9 | error sets, translating, diagnostics side channels, errdefer logging, fatal, traces |
| [safety.md](safety.md) | 7.1-7.11 | assert semantics, bugs vs errors, build modes, ReleaseSafe, assert patterns, bounded loops |
| [comptime.md](comptime.md) | 8.1-8.11 | generics, restraint, compile errors, anytype, inline else, backends, reflection |
| [api.md](api.md) | 9.1-9.10 | options structs, decl literals, init/create, buffers, push ifs up, interfaces, typed indexes, format |
| [io.md](io.md) | 10.1-10.5 | `io: Io`, Writer/Reader, flush, async/cancel/Group, cancellation, locks |
| [testing.md](testing.md) | 11.1-11.8 | test wiring, OOM and fault injection, data-driven, snapshot, fuzzing, random, hygiene |
| [perf.md](perf.md) | 12.1-12.7 | DOD numbers, SoA, indexes, hot loops, packed records, SIMD, measuring |
| [build.md](build.md) | 13.1-13.6 | build.zig shape, 0.17 configure, options, fmt, entry points, version pin, zon |
| [c-interop.md](c-interop.md) | 14 | translate-c, `[*c]` at the boundary, callbacks, headers |
| [logging.md](logging.md) | 15 | scoped logs, run-time filtering |
| [disagreements.md](disagreements.md) | 16 | where respected sources differ, and our pick |
| [stale.md](stale.md) | 17 | old idiom to 0.17 idiom, before trusting any web example |
| [checklists.md](checklists.md) | 18-19 | pitfalls table and a review checklist |
| [meiolol.md](meiolol.md) | | starting counts for applying the guide here |

## The rules in one screen

Each links to the section with the reasoning and examples.

- Names: types TitleCase, other functions camelCase, the rest snake_case; no
  Value/Data/Manager/utils; units and qualifiers last (`latency_ms_max`) (style.md 3.1-3.3)
- A file with fields is `const Name = @This();`; `Self` only inside type functions;
  receivers named after the type (style.md 3.4)
- Allocating functions take an allocator named for its lifetime; main takes
  `std.process.Init` and passes `gpa`, `arena`, `io` down (memory.md 5.1-5.2)
- Containers are unmanaged: `.empty`, allocator per call, `deinit(gpa)` ends with
  `self.* = undefined` (memory.md 5.4-5.5)
- `defer`/`errdefer` on the line after each acquisition; an errdefer's scope ends where
  ownership moves (memory.md 5.6)
- Reserve first, mutate with `*AssumeCapacity`, mark the tail `errdefer comptime
  unreachable` (memory.md 5.7)
- Arenas for one-lifetime work, `reset(.retain_capacity)` in loops; size lists before
  growing them in an arena (memory.md 5.8)
- No pointer into a container survives a mutation of it; store indexes (memory.md 5.10)
- Every read from outside has a limit (memory.md 5.13)
- Errors are codes for branching; details go in a diagnostics side channel; switch on
  errors, never `==`; no `anyerror` (errors.md 6.2-6.5)
- Bugs are asserted and crash; operating errors are handled (safety.md 7.2)
- Ship with safety on (ReleaseSafe) unless a profile says otherwise (safety.md 7.4)
- Assert arguments, invariants and results where state is subtle; split compound
  asserts; `defer assert(post)`; every `unreachable` says why (safety.md 7.5, 7.9)
- Bound every loop: `for (0..max) |_| {...} else @panic(...)` (safety.md 7.6)
- Comptime sparse; misuse is a located `@compileError`; `inline else` over `inline
  for` (comptime.md 8.2-8.5)
- `io` and `gpa` positional, behaviour in an options struct; tied defaults as decl
  literals (api.md 9.1-9.2)
- Interfaces only when reuse pays: direct call, then tagged union or comptime backend,
  then vtable (api.md 9.8)
- Typed indexes as `enum(u32) { _ }` with a `none` sentinel (api.md 9.9)
- Streams are `*std.Io.Writer`/`Reader`; flush at the end; `defer cancel` after each
  `io.async` (io.md 10.2-10.3)
- Tests beside the code on `testing.allocator`, wired from the root; exercise error
  paths; snapshot and fuzz against an oracle (testing.md 11.1-11.6)
- Shrink the struct you have most of; hot loops as free functions over slices; profile
  before complicating (perf.md 12.1-12.7)
- build.zig like the 0.17 `zig init` template; configure is pure; pin the Zig version
  (build.md 13.1-13.4)

## Evidence

research/ (josearch) holds every quoted finding: questions `zig-good-practice` and its
children `zig-style`, `zig-memory`, `zig-errors-safety`, `zig-comptime`,
`zig-api-design`, `zig-testing`, `zig-perf`, `zig-build`. `[[slug#^fN]]` in these files
points at a finding; `josearch show slug#^fN` prints it, and `research/raw/` has the
verbatim text. The readers' working notes, with more excerpts per source:
data/team/2026-10-22-zig-guide/ (gitignored).

## Editing

One topic per file; keep each under ~500 lines (memory.md is the largest). New
practice: add it to its topic file with a source citation, add a line here if it
changes the one-screen rules, and record the evidence in research/ first. Version
changes go in stale.md.
