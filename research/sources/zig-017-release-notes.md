---
title: Zig 0.17.0 release notes
url: https://ziglang.org/download/0.17.0/release-notes.html
kind: docs
commit:
for: [zig-017-migration]
looked: 2026-10-11
depth: docs (language changes, standard library, build system, package management, regressions, roadmap)
relevance: high
grade: A/strong
description: Official release notes for Zig 0.17.0 (2026-10-01): breaking language, std and build system changes with upgrade guides
---
# Zig 0.17.0 release notes

Why: which 0.17 changes hit meiolol (std.Io, build.zig, http client, sqlite C build,
wasm, Windows), and what the upgrade guides say to do.

## Assessment

- Evidence: A. The canonical reference from the Zig team, with upgrade diffs per change.
- Reasoning: strong. Explains motives and trade-offs (passthru args, maker process).
- Interests: none beyond promoting the release.
- Weigh: lists what changed, not what is still deprecated-but-working; our trial port
  ([[zig-017-trial-port]]) shows which changes actually break this repo.

## Findings

- [toolchain] @cImport is removed; TranslateC build step deprecated in favour of the external
  translate-c package. ^f1
  > @cImport was deprecated in Zig 0.16.0 and is now removed. Furthermore, in this release `std.Build.Step.TranslateC` is deprecated in favor of an explicit package dependency on official ZSF translate-c package
- [toolchain] Array multiplication `a ** b` is removed in favour of @splat. ^f2
  > Array multiplication syntax (`a ** b`) has been removed in favor of `@splat`.
- [toolchain] Struct and union type info is now struct-of-arrays (field_names, field_types). ^f3
  > When doing type reflection, structs and unions return their information in struct-of-arrays style
- [toolchain] bit_set and ascii renames: initEmpty/initFull become empty/full; indexOfIgnoreCase
  becomes findIgnoreCase. ^f4
  > Removed `std.bit_set.Integer.initEmpty` in favor of `std.bit_set.Integer.empty`.
  > Removed `std.ascii.indexOfIgnoreCase` in favor of `std.ascii.findIgnoreCase`.
- [toolchain] Run step: `b.args` is gone; use addPassthruArgs. ^f5
  > In the Run step, passthru args are all together now, not observable in configure phase whether run args are provided.
- [toolchain] build.zig now runs in a separate configurer process from the maker. ^f6
  > `zig build` now runs projects' `build.zig` code in a separate executable than the one that performs
- [toolchain] Deprecated, still working in 0.17: std.builtin (to std.lang), fmt.allocPrint (to
  Allocator.print), ArrayList getLast. ^f7
  > Deprecated `std.builtin` in favor of `std.lang`.
  > `getLastOrNull` has been deprecated and renamed to `last`
- [toolchain] Footgun: containsAtLeastScalar swapped parameter order and may still compile. ^f8
  > now be incorrect since the `element` and `minimum` parameters have swapped places
- [toolchain] Uri.getHost moved to HostName.fromUri, with a different error set. ^f9
  > `Uri.getHost` has been moved to `HostName.fromUri` (without a graceful deprecation
- [toolchain] Windows resource compilation (addWin32ResourceFile) moves to an external package
  in the next release (0.18). ^f10
  > will be moved out of the compiler and into an
- [toolchain] Checked, not there: no breaking change listed for std.Io networking or the http
  client API; the only Io addition noted is Semaphore.waitTimeout, not socket timeouts. ^f11
  > Added `std.Io.Semaphore.waitTimeout`
- [toolchain] Known regressions include response files for Run steps after the maker split. ^f12
  > breaks response file use cases for `std.Build.Step.Run`
- [toolchain] 0.18 will move to LLVM 23 and re-enable loop vectorisation. ^f13
  > Zig 0.18.0 will upgrade to LLVM 23, so will allow us to re-enable this optimization pass.

## Read

- Language Changes, Standard Library, Build System, Package Management, Bug Fixes,
  Toolchain (LLVM, resinator), Roadmap: fully

## Not read

- Target support tables, linker internals, fuzzer, zig objdump: not relevant to meiolol
