---
title: Conditionally Disabling Code with Comptime in Zig (Mitchell Hashimoto)
url: https://mitchellh.com/writing/zig-comptime-conditional-disable
kind: article
for: [zig-comptime]
looked: 2026-10-22
depth: docs (full)
relevance: high
grade: B/strong
description: Sept 2024 post: comptime if for platform, debug and build-config code; the gotcha that comptime doesn't cross function boundaries; mixed comptime and runtime conditions
---
# Conditionally Disabling Code with Comptime in Zig (Mitchell Hashimoto)

Why: how and when to compile code out with comptime?

## Assessment

- Evidence: B. Author of [[ghostty-repo]] (A), two years into Ghostty; Zig 0.13 docs linked.
- Reasoning: strong. Compares with C preprocessor and Go build tags, shows the gotcha and the
  fix, and the CI practice that covers it.
- Interests: none.
- Weigh: semantics unchanged through 0.17 as far as we know; verify the `inline fn` trick on
  our compiler if we rely on it.

## Findings

- [zig/comptime] Reasons to disable code: platform-specific code, debug-only code, build-configured features; omitting also shrinks the binary and removes runtime branches. ^f1
  > omitting the code at compile time also has the benefit of making your binary smaller and avoiding runtime conditionals which may have a performance cost.
- [zig/comptime] A plain `if` on comptime-known values (builtin) skips analysis of the dead branch; the `comptime` keyword is redundant there but makes intent explicit. ^f2
  > Zig will automatically evaluate the condition at compile time if all available information is known at compile time.
  > I included it to make the example more explicit.
- [zig/comptime] A comptime operand first in an `and` chain gates the runtime conditions and the block, so they may name types that only exist in some builds. ^f3
  > Importantly, this means I can use the `adwaita` library in the runtime conditions as well as the code block and I won't get compiler errors
- [zig/comptime] Check twice when needed: a build-time version check and a runtime check of the dynamically linked library. ^f4
  > The first one is a build-time check that we have libadwaita available and that the version is at least 1.4.0.
- [zig/comptime] Gotcha: comptime doesn't cross a function call; `if (hasFeature())` compiles both branches unless the call is `comptime`. ^f5
  > comptime doesn't cross function boundaries unless the `comptime` keyword is used.
- [zig/comptime] If the helper mixes comptime and runtime checks, make it `inline fn`. ^f6
  > Unfortunately, this won't work if `hasFeature` mixes comptime and non-comptime conditions. In that case, you'll need to inline the function:
- [zig/test] [zig/build] He builds both sides of every comptime switch in CI because the failure mode is silent. ^f7
  > Whenever I have comptime checks like this I always add both branches to CI to ensure that my program can build in both environments.
- [zig/comptime] Comptime is his favourite Zig feature after two years of Ghostty, though he first thought it a gimmick. ^f8
  > comptime is used _all over_ and is by far my favorite feature about Zig.

## Read

- Full post

## Not read

- The rest of the "Zig comptime usecases" series (only the tagged-union post found besides this)
