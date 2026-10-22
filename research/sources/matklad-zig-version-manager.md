---
title: The Worst Zig Version Manager (matklad, 2023-06-02)
url: https://matklad.github.io/2023/06/02/the-worst-zig-version-manager.html
kind: article
commit: 
for: [zig-build]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: Vendor a polyglot sh/PowerShell getzig script that downloads a pinned Zig into ./zig, as TigerBeetle does, instead of PATH or version managers
---
# The Worst Zig Version Manager (matklad, 2023-06-02)

Why: toolchain pinning. Zig 0.10.1 example; idea current.

## Assessment

- Evidence: B. TigerBeetle practice (install_zig.sh), PoC script he says ChatGPT mostly
  wrote.
- Reasoning: fair.
- Interests: none.
- Weigh: meiolol already pins Zig in build.zig; the ./zig-in-repo approach is an
  alternative, and he asks for upstream hashed manifests.

## Findings

- [toolchain] [zig/build] TigerBeetle puts the right Zig version in `./zig` at the repo
  root and runs `./zig/zig build test`, not zig from PATH. ^f1
  > We don’t use `zig` from `PATH`. Instead, we just put the correct version of Zig into `./zig` folder in the root of the repository
- [toolchain] Desiderata: version and hash in a `zig-version.txt`, integrity verified
  after download. ^f2
  > After downloading the file, its integrity should be verified.

## Read

- Whole post.
