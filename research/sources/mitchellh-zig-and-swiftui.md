---
title: Integrating Zig and SwiftUI (Mitchell Hashimoto)
url: https://mitchellh.com/writing/zig-and-swiftui
kind: article
for: [zig-build, zig-api-design]
looked: 2026-10-22
depth: docs (full)
relevance: medium
grade: B/fair
description: May 2023 post: Zig core as a static lib with a hand-written C header, libtool-merged deps, lipo universal binary, xcframework, consumed by SwiftUI; Zig 0.11 build API
---
# Integrating Zig and SwiftUI (Mitchell Hashimoto)

Why: how does a Zig core expose a C ABI for a native GUI, and how does build.zig drive the
platform tools?

## Assessment

- Evidence: B. Ghostty's own setup, used a year at the time, through a macOS major update.
- Reasoning: fair. Explains each step and why ObjC was rejected; little on costs beyond
  complexity.
- Interests: none.
- Weigh: build code is Zig 0.11 (`addStaticLibrary`, `.root_source_file = .{ .path = ...}`),
  stale; the current shape is the `src/build/` package with LibtoolStep, LipoStep,
  XCFrameworkStep in [[ghostty-repo#^f82]]. Relevant to meiolol only if we ship a lib.

## Findings

- [zig/api] Split: cross-platform logic in Zig as a C-ABI static library, GUI per platform; ~90% of code shared with Linux. ^f1
  > Compile your cross-platform logic into a static library that exposes the C ABI as the primary interface
- [zig/api] `export fn` gives the C calling convention; only the signature is limited to C types (no comptime params, error sets, odd int widths), the body can use everything. ^f2
  > This restriction _only applies to the signature_. You can use all of those features inside the function body.
- [zig/api] The C header is written by hand; the consumer (Swift) learns the API only from it. ^f3
  > Note, you actually _must_ write a header file, because this is how Swift is going to know what the API is for your library.
- [zig/build] Static libraries don't carry their C dependencies, so a custom LibtoolStep merges them into one archive. ^f4
  > Static libraries do not also embed their static dependencies.
- [zig/build] Platform tools (libtool, lipo, xcframework) are wrapped as custom build steps in build.zig. ^f5
  > The `LipoStep` is a custom step I wrote to call `lipo`
- [zig/build] He picked old, stable system tools because they are unlikely to be brittle. ^f6
  > All of the steps are tried and true -- usually decades-old -- operations and tools for working with system libraries.
- [toolchain] Written against the 0.11 nightly; he expected the code to go stale. ^f7
  > I am using the 0.11 nightly build for all the examples in this post.

## Read

- Full post

## Not read

- The gists with LibtoolStep, LipoStep, XCFrameworkStep source (current versions are in the repo)
