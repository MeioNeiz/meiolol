---
title: 'Bazel docs: Adapting Bazel Rules for Remote Execution'
url: https://bazel.build/remote/rules
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole page)
relevance: medium
grade: A/fair
description: What a build must give up to run its actions on other machines: isolated, stateless actions, tools via toolchains not PATH, no host-probing configure steps, host-built binaries don't run remotely
---
# Bazel docs: Adapting Bazel Rules for Remote Execution

Why: what does offloading build actions to another host require of the build?

## Assessment

- Evidence: A. Official Bazel docs for remote execution (gRPC Remote Execution API,
  Buildfarm, Buildbarn, commercial services).
- Reasoning: fair. Concrete failure modes, each with the fix.
- Interests: Bazel project docs.
- Weigh: shows remote execution is per action and needs a build system that can ship one
  action's inputs; `zig build` has no such protocol, so for us offloading means whole
  builds on another host.

## Findings

- [devflow/cache] Remote execution runs individual actions on another platform over a
  gRPC protocol; host, execution and target platforms are distinct. Intro ^f1
  > Remote execution allows Bazel to execute actions on a separate platform, such as a datacenter.
- [devflow/cache] It requires isolated actions and copes with environments that differ
  from the local one. Overview ^f2
  > **Isolated build actions.** Build tools do not retain state and dependencies cannot leak between them.
  > **Diverse execution environments.** Local build configuration is not always suitable for remote execution environments.
- [devflow/cache] Tools must come from toolchain rules, not PATH or JAVA_HOME, which may
  differ remotely. Toolchain rules ^f3
  > use a toolchain rule instead of invoking build tools via the `PATH`, `JAVA_HOME`, or other local variables that may not be set to equivalent values (or at all) in the remote execution environment.
- [devflow/cache] Configure steps that probe the host fail remotely when the remote
  platform differs. Configure-style rules ^f4
  > If the build explicitly depends on local build tools and artifacts, it will fail during remote execution if the remote execution platform is not identical to the host platform.
- [devflow/cache] (inferred) Zig's analogue: a pinned compiler (tools as source) and
  cross-compilation help, but build.zig steps that find host programs (findProgram, see
  [[zig-017-release-notes#^f33]]) are the same host-probing hazard. ^f5

## Read

- Whole page.

## Not read

- Remote execution CI configuration and Docker sandbox troubleshooting pages.
