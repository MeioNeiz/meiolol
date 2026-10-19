---
status: answered
priority: soon
area: ops
tags: [toolchain]
description: What in Zig 0.17 breaks meiolol, and how much work is the move from 0.16?
---
# What in Zig 0.17 breaks meiolol, and how much work is the move from 0.16?

Feeds: docs/zig-0.17.md; docs/plan/decisions.md "Open decisions" Zig 0.17 move

## Answer

Small. A trial port of commit 1149c0b to official Zig 0.17.0 hit 6 compile errors in 4
rounds. All were fixed in 6 files (about 40 changed lines), after which the native build,
all tests, the Windows and Linux builds, and the box's musl ReleaseSafe build passed
(C1, C2). The breaks:
- build.zig `b.args` becomes addPassthruArgs
- SQLite's @cImport moves into the build (translate-c)
- bit_set initEmpty becomes .empty
- ascii.indexOfIgnoreCase becomes findIgnoreCase
- one `**` in a test
- type reflection's `.fields` becomes field_names/field_types

Nothing broke in std.Io, the http clients, the wasm module or the site (C3). Release
sizes barely change (C4). Deprecated but still working in 0.17, so cheap to clear now
before 0.18 removes them: std.builtin, fmt.allocPrint, StaticBitSet, ArrayList getLast
(C5).

Risks:
- Nothing has been run yet: crawler and SQLite on the box, LCU on Windows (C2)
- containsAtLeastScalar silently swapped its arguments (C6; not used in the tree)
- The GUI pick (dvui) is still on 0.16, with its 0.17 port open (zig-gui-options), so
  move the repo before adopting dvui, or pin dvui to its 0.17 commit when that lands

## Claims

- C1: 0.17 breaks meiolol in six places: b.args, @cImport, bit_set init, ascii rename, `**`, struct-of-arrays type info. for: [[zig-017-trial-port#^f1]], [[zig-017-trial-port#^f2]], [[zig-017-trial-port#^f3]], [[zig-017-trial-port#^f4]], [[zig-017-release-notes#^f1]], [[zig-017-release-notes#^f2]], [[zig-017-release-notes#^f3]], [[zig-017-release-notes#^f4]], [[zig-017-release-notes#^f5]]
- C2: After those fixes, build, tests, and the Windows, Linux and musl box targets all compile and pass on 0.17; nothing has been run. for: [[zig-017-trial-port#^f5]], [[zig-017-trial-port#^f8]]
- C3: std.Io, the http clients, wasm and the site needed no change. for: [[zig-017-trial-port#^f7]], [[zig-017-release-notes#^f11]]
- C4: Release binary sizes are within about 5% of 0.16. for: [[zig-017-trial-port#^f6]]
- C5: Deprecated-but-working APIs we use (std.builtin, fmt.allocPrint, getLast) will break in 0.18. for: [[zig-017-release-notes#^f7]]
- C6: containsAtLeastScalar swapped parameters and can compile wrongly. for: [[zig-017-release-notes#^f8]]
- C7: Build-graph changes: build.zig runs in a separate configurer process, Run-step response files regressed, and Windows resource files move to an external package in 0.18. for: [[zig-017-release-notes#^f6]], [[zig-017-release-notes#^f10]], [[zig-017-release-notes#^f12]]

## Disagreements

None.

## Open

- Runtime check on the box (crawl, stats, site) and on Windows (LCU watch) with 0.17
  builds
- External translate-c package vs the deprecated b.addTranslateC (both work in 0.17)
- dvui 0.17 port (issue #839, open on 2026-10-10)
