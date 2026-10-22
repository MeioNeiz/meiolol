---
status: answered
parent: zig-good-practice
priority: soon
area: code
tags: [zig/build]
description: How should a Zig project structure build.zig, modules, packages, C interop and cross-compilation?
---
# How should a Zig project structure build.zig, modules, packages, C interop and cross-compilation?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo

## Answer

Shape build.zig like the 0.17 `zig init` template: standard target and optimize options
wired into every root module, `b.createModule` for internal modules and `b.addModule` only
to expose one, one `addTest` plus `addRunArtifact` per module under one `test` step (C1,
C2, C3). In 0.17 the configure phase is cached in a separate process: no side effects,
no run args (`addPassthruArgs`), declared inputs (C4). Generated files come from in-tree
host tools as LazyPaths; committing them is a separate step (C5). Enforce formatting with
addFmt check steps; keep a no-install `check` step for fast diagnostics (C6, C7). Pin the
Zig version at comptime; one `ci` step; few entry points with filters (C8, C9). Large
builds split into a package with one Config struct (C10). zon: hash is truth, lazy deps,
git-ignore zig-pkg (C11). C headers through the translate-c package (C12). Dev loop
`-fincremental --watch` (C13).

## Claims

- C1: The 0.17 init template is the core team's commented reference for build.zig. for: [[zig-repo-docs#^f1]], [[zig-repo-docs#^f2]], [[zig-repo-docs#^f10]]
- C2: addModule exposes a module to dependants; createModule is for internal ones. for: [[zig-talk-build-system-intro#^f6]], [[zig-talk-build-system-intro#^f7]], [[zig-repo-docs#^f6]]
- C3: Standard target and optimize options are wired into every root module; never hardcode a release mode. for: [[zig-learn-build-system#^f7]], [[zig-learn-build-system#^f8]], [[zig-repo-docs#^f7]]
- C4: In 0.17 configure is cached and pure: no side effects, no run args, declared inputs. for: [[zig-devlog-2026#^f1]], [[zig-devlog-2026#^f3]], [[zig-017-release-notes#^f33]], [[zig-017-release-notes#^f5]]
- C5: Generated files come from in-tree host tools as LazyPaths; never mutate sources in the normal build. for: [[zig-learn-build-system#^f17]], [[zig-learn-build-system#^f20]], [[zls-repo#^f4]]
- C6: Formatting is enforced through addFmt steps in the test graph. for: [[zig-repo-docs#^f26]]
- C7: A no-install check step gives fast semantic diagnostics. for: [[kristoff-zls-experience#^f2]], [[zls-repo#^f6]]
- C8: Pin the Zig version with a comptime check. for: [[tigerbeetle-code#^f1]], [[ghostty-repo#^f85]]
- C9: One ci step and a small fixed set of entry points with filters. for: [[tigerbeetle-code#^f7]], [[matklad-o1-build-file#^f2]], [[matklad-o1-build-file#^f3]]
- C10: Large builds split into a package with one Config struct rehydrated at comptime. for: [[ghostty-repo#^f82]], [[ghostty-repo#^f83]]
- C11: build.zig.zon: hash is truth, minimal paths, git-ignore zig-pkg; optional deps lazy. for: [[zig-repo-docs#^f20]], [[zig-repo-docs#^f22]], [[zig-devlog-2026#^f6]], [[zig-017-release-notes#^f35]], [[ghostty-repo#^f87]]
- C12: C headers go through the translate-c package; @cImport is removed. for: [[zig-017-release-notes#^f1]], [[river-repo#^f18]]
- C13: The team's dev loop is `zig build -fincremental --watch` on a native test step. for: [[zig-016-release-notes#^f38]], [[zig-devlog-2026#^f17]], [[zig-repo-docs#^f24]]
- C14: Build config reaches code via b.addOptions as comptime values. for: [[zig-learn-build-system#^f9]], [[zig-repo-docs#^f25]]
- C15: Default to ReleaseSafe as the preferred release mode in apps that ship. for: [[tigerbeetle-code#^f4]] against: [[zig-learn-build-system#^f8]]

## Disagreements

- Preferred release mode: the learn guide says none is preferable; TigerBeetle sets
  ReleaseSafe as preferred. For an app we ship, safe.
- `.imports` field vs `addImport`: no rule (Loris Cro).
- `-Dno-bin` with incremental: useful on 0.14/0.15, little benefit on 0.16 ELF; on
  macOS Mach-O it may still be the fast loop.

## Open

- Does incremental work on aarch64 macOS in 0.17 (the release notes say x86_64 Linux)?
