---
title: meiolol trial port to Zig 0.17.0 (our build, 2026-10-11)
url: local:scratchpad-zig017
kind: dataset
commit: 1149c0b
for: [zig-017-migration]
looked: 2026-10-11
depth: ran (scratch copy of commit 1149c0b, built and tested with official 0.17.0 on macOS arm64)
relevance: high
grade: B/strong
description: Our own port of meiolol to Zig 0.17.0: every compile error in order, the fixes, test and cross-compile results, release sizes vs 0.16
---
# meiolol trial port to Zig 0.17.0 (our build, 2026-10-11)

Why: release notes list everything that changed; only a build shows what breaks this
repo and how much work it is.

## Assessment

- Evidence: B. First-hand, exact errors, diff and build summaries saved; one machine.
- Reasoning: strong for "compiles and tests pass"; nothing was executed on the box or
  on Windows.
- Interests: none.
- Weigh: the port used the deprecated b.addTranslateC for SQLite, not the external
  translate-c package the notes recommend ([[zig-017-release-notes#^f1]]). Covers the
  tree at 1149c0b; later code may add more uses.

## Findings

- [toolchain] Round 1: build.zig fails on `b.args`. ^f1
  > build.zig:81:15: error: no field named 'args' in struct 'Build'
- [toolchain] Round 2: bit_set initEmpty and ascii.indexOfIgnoreCase removed. ^f2
  > src/core/score.zig:91:30: error: struct 'bit_set.Integer(5)' has no member named 'initEmpty'
  > src/lcu/https.zig:168:32: error: root source file struct 'ascii' has no member named 'indexOfIgnoreCase'
- [toolchain] Round 3: `**` in a test and @cImport for SQLite. ^f3
  > src/store/raw.zig:43:60: error: binary operator '*' has whitespace on one side, but not the other
  > src/store/sqlite.zig:4:15: error: invalid builtin function: '@cImport'
- [toolchain] Round 4: type info field list in the timeline codec. ^f4
  > src/riot/timeline.zig:37:48: error: no field named 'fields' in struct 'lang.Type.Enum'
- [toolchain] After 6 files changed, native build, all tests, Windows and Linux builds pass. ^f5
  > Build Summary: 11/11 steps succeeded
  > Build Summary: 7/7 steps succeeded
- [toolchain] Release sizes barely move: app 917 KB to 903 KB (Windows ReleaseSmall), box
  binary 19.6 MB to 20.6 MB (musl ReleaseSafe). ^f6
  > meiolol-app.exe: 916992 bytes on 0.16.0, 902656 bytes on 0.17.0.
  > meiolol: 19558256 bytes on 0.16.0, 20578512 bytes on 0.17.0.
- [toolchain] Checked, not there: no error in std.Io, the Riot http client, LCU https, the
  wasm module or the site generator. ^f7
- [toolchain] Not run: no 0.17 binary was executed. ^f8
  > Not run: no binary from 0.17 was executed on the box or on Windows.

## Read

- `raw/zig-017-trial-port.md`: all (errors, diff, summaries)

## Not read

- Runtime behaviour on the box (crawler, sqlite) and Windows (LCU): needs a run
