---
title: 'Bazel docs: Hermeticity'
url: https://bazel.build/basics/hermeticity
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole page)
relevance: medium
grade: A/fair
description: What a hermetic build is (isolation from the host, source identity), why it enables caching and parallel builds, and the usual leaks (absolute paths, host binaries, timestamps, writing to the source tree)
---
# Bazel docs: Hermeticity

Why: what property must a build have before its outputs can be shared between trees or
hosts?

## Assessment

- Evidence: A. Official Bazel docs; the concept underpins Google-scale caching.
- Reasoning: fair. Lists benefits and common leaks, with checks to find them; short.
- Interests: Bazel project docs, partly a migration pitch.
- Weigh: the list of leaks is a checklist for whether `zig build` steps can be shared.

## Findings

- [devflow/cache] Hermetic: same source and configuration give the same output, isolated
  from the host. Overview ^f1
  > When given the same input source code and product configuration, a hermetic build system always returns the same output by isolating the build from changes to the host system.
- [devflow/cache] Two parts: isolation (tools treated as source, pinned) and source
  identity (inputs identified by hash). Overview ^f2
  > **Isolation**: Hermetic build systems treat tools as source code.
  > **Source identity**: Hermetic build systems try to ensure the sameness of inputs.
- [devflow/cache] Hermeticity is what makes caching and parallel execution possible:
  outputs are reused until inputs change. Benefits ^f3
  > **Speed**: The output of an action can be cached, and the action need not be run again unless inputs change.
- [devflow/cache] Common leaks: non-deterministic outputs (build IDs, timestamps), host
  binaries and absolute paths that differ across hosts, and writing to the source tree.
  Identifying non-hermeticity ^f4
  > System binaries that differ across hosts (such as `/usr/bin` binaries, absolute paths, system C++ compilers for native C++ rules autoconfiguration)
  > Writing to the source tree during the build. This prevents the same source tree from being used for another target.
- [devflow/cache] The first check is a null build: a second run with no changes should
  rebuild nothing; hashing outputs from two runs or two systems finds non-reproducible
  steps. Troubleshooting ^f5
  > If you run `make` and get a successful build, running the build again should not rebuild any targets.
- [devflow/cache] Mixing remote and local execution needs a fully hermetic build. Note ^f6
  > Make your build fully hermetic when mixing remote and local execution, using Bazel’s “dynamic strategy” functionality.

## Read

- Whole page.

## Not read

- Linked BazelCon talks on remote execution and caching (Uber, TwoSigma, IBM).
