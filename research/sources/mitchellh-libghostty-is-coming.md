---
title: Libghostty Is Coming (Mitchell Hashimoto)
url: https://mitchellh.com/writing/libghostty-is-coming
kind: article
for: [zig-api-design, zig-build]
looked: 2026-10-22
depth: docs (full)
relevance: medium
grade: B/fair
description: Sept 2025 roadmap: libghostty-vt extracted from Ghostty's core as a zero-dependency (no libc) Zig module first, clean-slate C API next, versioned separately, a family of small libs
---
# Libghostty Is Coming (Mitchell Hashimoto)

Why: how does a Zig app carve a reusable library out of its core?

## Assessment

- Evidence: B. Roadmap post, but the result exists at our commit (`src/lib_vt.zig`,
  `src/terminal/c/`, `-Demit-lib-vt`, see [[ghostty-repo#^f55]], [[ghostty-repo#^f91]]).
- Reasoning: fair. Says why (ad-hoc emulators everywhere) and the plan; little on how.
- Interests: promoting libghostty adoption.
- Weigh: architectural intent only; the repo shows the realisation.

## Findings

- [zig/api] [zig/build] libghostty-vt is the terminal core as a zero-dependency library, not even libc. ^f1
  > a zero-dependency library that provides an API for parsing terminal sequences and maintaining terminal state, extracted directly from Ghostty's real-world proven core. It doesn't even require libc!
- [zig/api] The Zig module shipped first; the C API is a separate design job on the same core. ^f2
  > All of the work required is defining the C API, since the core logic is of course all there and has been used by Ghostty for years.
- [zig/api] The older internal C header is called a mess made for one consumer; the public API starts clean. ^f3
  > It isn't a _good_ C API. It is internal-only and exists to satisfy the needs of the macOS application.
- [zig/api] Library and app are versioned separately (build.zig has its own lib_version). ^f4
  > I plan to version `libghostty` separately from Ghostty the application.
- [zig/build] Further pieces will be a family of small libs to keep dependencies and code size down. ^f5
  > These will be structured as a family of libraries to minimize dependency requirements, code size, and overall maintenance complexity.
- [zig/api] API design is driven by feedback from real consumers, Ghostty being one. ^f6
  > the best way to design an API is with feedback from real consumers.
- [zig/test] The core is called fuzzed and Valgrind-tested. ^f7
  > a robust fuzzed and Valgrind-tested codebase

## Read

- Full post

## Not read

- PR 8840 (Zig module export) and its example program
