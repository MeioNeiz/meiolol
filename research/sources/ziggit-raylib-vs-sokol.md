---
title: 'Raylib vs Sokol vs (Ziggit help thread, May 2024)'
url: https://ziggit.dev/t/raylib-vs-sokol-vs/4454
kind: thread
commit:
for: [zig-gui-options]
looked: 2026-10-11
depth: docs (first two posts; four later posts collapsed in snapshot)
relevance: medium
grade: C/fair
description: Ziggit thread quoting Daniel Hooper's experience that raylib had rough edges and raygui is a toy, with a rebuttal
---
# Raylib vs Sokol vs (Ziggit help thread, May 2024)

Why: practitioner views on raylib/raygui versus sokol for building a real app UI.

## Assessment

- Evidence: C. One developer's first-hand report (Shape Up app, C, quoted in post 1)
  plus one rebuttal; 2024, before raylib 6.0.
- Reasoning: fair; concrete examples on both sides.
- Interests: none; the reply notes the original post is one-sided.
- Weigh: the raygui points matter for an app with float values and lists; the raylib
  API critique matters less from Zig (raylib-zig adds enums). Old: verify against
  raygui today if raylib is chosen.

## Findings

- [gui] A developer who built an app on raylib called raygui a toy: no float display, no
  event routing for overlapping elements, no rounded corners, hard to style. ^f1
  > The raygui UI library is just a toy:
  > doesn’t handle mouse event routing for overlapping or clipped elements
  > can’t be styled to look good
- [gui] Same author: raylib bug reports were mostly closed as won't fix; would use sokol
  next time. ^f2
  > almost all of them them were closed as “wont fix”
  > In the future I’ll go with [sokol](https://github.com/floooh/sokol).
- [gui] Rebuttal: the toy remark is about raygui, not raylib; the assumptions are fine for
  a game library. ^f3
  > The quote: “The raygui UI library is just a toy” is about raygui and not raylib.
  > These are acceptable assumptions for a game library.

## Read

- Posts 1 and 2

## Not read

- Posts 3-6 (collapsed); Hooper's original blog post
