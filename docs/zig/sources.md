# 1. Sources and how much to trust them

Evidence grade: A proven (canonical, years of use), B credible first-hand, C works for
its author. Zig changes every minor release, so the version each source targets matters
as much as its grade.

| Source | What | Zig | Grade |
| --- | --- | --- | --- |
| Language reference 0.17.0 | the spec, its Style Guide, Memory and Illegal Behavior chapters; examples run in CI | 0.17 | A |
| Release notes 0.11 to 0.17 | each breaking change with the team's reasoning | each | A |
| ziglang.org learn, devlog, `zig init` template | build system guide, design posts, the commented reference build.zig | 0.14-0.17 | A |
| Andrew Kelley talks | Practical DOD (2021), Don't Forget To Flush (2025), New Async I/O (2025) | various | A |
| std and compiler source @ 0.17.0 | ArrayList, hash maps, Allocator, Io, json, testing, Ast, Zir, InternPool | 0.17 | A |
| TigerBeetle | distributed database; TIGER_STYLE.md, tidy lint, simulation testing | 0.16 | A |
| Ghostty | terminal emulator, 365k lines, 422 contributors | 0.17 | A |
| ZLS | the language server | 0.17 | A |
| River | Wayland compositor by Isaac Freund (core team) | 0.16 | A |
| Roc compiler | 1.1M lines, written design rules and custom lints (agent-heavy) | 0.17 | B |
| zig-clap, SuperHTML | comptime CLI parser; Loris Cro's HTML tooling | 0.17-dev | A/B |
| Bun (last Zig tag) | huge, forked Zig, now rewritten in Rust: a cautionary case | fork | A |
| matklad (Alex Kladov) | 50 posts: errors, reserve-first, comptime, testing | 0.12-0.17 | B |
| Mitchell Hashimoto | Ghostty author: comptime, tripwire, SIMD, leak post-mortem | 0.11-0.17 | B |
| Loris Cro, Karl Seguin, Ryan Liptak, ziggit | asserts, Io, Learning Zig, OOM testing, threads | 0.13-0.16 | A-C |

Cautions:

- Official pages carry stale code: learn/build-system and learn/overview still show
  managed `ArrayList.init`, `@cImport` and `std.fs.cwd()`, and their own CI output shows
  them failing on 0.17 [[zig-learn-build-system#^f15]], [[zig-learn-overview#^f14]].
  Trust the langref and the std source over the learn pages.
- Most blog code predates 0.15 (Writergate) or 0.16 (std.Io). Section 17 lists what
  changed.
- TigerBeetle states database-specific rules as universal (static allocation, no
  recursion) [[tigerbeetle-tiger-style#^f49]]. Take the reasoning, check the domain.
