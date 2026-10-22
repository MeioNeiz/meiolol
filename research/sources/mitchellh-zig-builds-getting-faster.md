---
title: Zig Builds Are Getting Faster (Mitchell Hashimoto)
url: https://mitchellh.com/writing/zig-builds-getting-faster
kind: article
for: [zig-build]
looked: 2026-10-22
depth: docs (full)
relevance: medium
grade: B/fair
description: Oct 2025 measurements of Ghostty build times, Zig 0.14 vs 0.15.1: build script 7.2s to 1.7s, full 41s to 32s, lib-vt incremental 2.9s to 0.98s on the self-hosted backend
---
# Zig Builds Are Getting Faster (Mitchell Hashimoto)

Why: what do Zig versions and backend choice do to real build times, and what keeps a build
script cheap?

## Assessment

- Evidence: B. One machine, single runs reported without spread, but a real large project.
- Reasoning: fair. Says what each number measures and what still uses LLVM.
- Interests: an enthusiastic Zig backer (donor); numbers are plausible and modest.
- Weigh: snapshot of 0.15.1; 0.16/0.17 moved further. Useful for the shape: build.zig compile
  cost, LLVM vs self-hosted.

## Findings

- [zig/build] [toolchain] Compiling Ghostty's build.zig itself fell from 7.2s (0.14) to 1.7s (0.15), measured by `zig build --help`. ^f1
  > Zig 0.14: 7sec 167ms
  > Zig 0.15: 1sec 702ms
- [zig/build] A well-written build script rebuilds itself rarely; its cost is paid by every fresh source build. ^f2
  > A well-written build script should only rebuild itself rarely.
- [zig/build] [toolchain] Full uncached build 41s to 32s, still mostly LLVM because the self-hosted x86_64 backend couldn't build all of Ghostty yet. ^f3
  > Ghostty still can't fully build and link using the self-hosted x86\_64 backend, since the backend still has bugs.
- [zig/build] [toolchain] A one-line change rebuilt libghostty-vt in 0.98s on the self-hosted backend, against 2.9s before. ^f4
  > Zig 0.15: 975ms
- [zig/build] (inferred) Keeping a library-sized module that builds on the self-hosted backend gives a sub-second edit loop; he cites staying in flow. ^f5
  > now its so fast I can stay in flow in my terminal.
- [zig/build] [toolchain] Incremental compilation wasn't functional in 0.15.1; rebuilds still recompile the module. ^f6
  > Incremental compilation in Zig isn't functional yet, so this still recompiles a considerable amount of code.

## Read

- Full post

## Not read

- Linked Zig release notes (covered by other notes)
