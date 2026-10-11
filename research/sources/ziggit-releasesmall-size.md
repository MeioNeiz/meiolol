---
title: 'ReleaseSmall is not small anymore? (Ziggit help thread, 2026)'
url: https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208
kind: thread
commit:
for: [zig-gui-options]
looked: 2026-10-11
depth: docs (all three loaded posts)
relevance: medium
grade: B/fair
description: Zig 0.16 Windows ReleaseSmall hello world grew from 14 KB to about 500 KB; tracked upstream
---
# ReleaseSmall is not small anymore? (Ziggit help thread, 2026)

Why: explains a floor under every candidate's Windows exe size on Zig 0.16.

## Assessment

- Evidence: B. User measurement, acknowledged by the Zig lead with an issue link.
- Reasoning: fair.
- Interests: none.
- Weigh: matches our builds (sokol clear.exe about 500 KB vs debugtext about 150 KB;
  [[zig-gui-win-builds#^f3]]); size differences under ~0.5 MB between candidates are noise.

## Findings

- [gui] On Zig 0.16 a minimal Windows ReleaseSmall exe went from 14 KB (0.15.2) to
  close to 500 KB. ^f1
  > In the version 0.15.2 the result exe file is 14Kb, in 0.16 – it is close to 500Kb.
- [gui] Andrew Kelley linked it to an upstream tracking issue. ^f2
  > tracked by [https://codeberg.org/ziglang/zig/issues/31421]
- [gui] A related thread title attributes 470+ KB to the std.Io interface. ^f3
  > Size increase by 470+ kb after adding std.Io interface.

## Read

- All loaded posts

## Not read

- Codeberg issue 31421 status (fixed in 0.17?)
