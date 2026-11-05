---
title: 'Zig issue 13050: cache hits with differently named zig lib directories (GitHub)'
url: https://github.com/ziglang/zig/issues/13050
kind: thread
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole thread, via gh)
relevance: medium
grade: B/strong
description: 2022 thread (Bazel's zig-cc maintainer and Andrew Kelley): absolute and per-directory paths in Zig's cache manifests stopped hits across sandboxes and machines; led to prefix-relative manifest paths
---
# Zig issue 13050: cache hits with differently named zig lib directories (GitHub)

Why: is Zig's cache path dependent, by design or by accident, and did that change?

## Assessment

- Evidence: B. Zig's lead and the maintainer of bazel-zig-cc, reproduced on both sides;
  2022 (Zig 0.10), closed Nov 2022. Old, but explains the design now in Cache.zig.
- Reasoning: strong. States the intended design for local and global caches and the
  trade-offs (symlinks, realpath).
- Interests: none beyond getting Zig to work under Bazel.
- Weigh: history; the current behaviour is in [[zig-017-build-cache]].

## Findings

- [zig/build] [devflow/cache] The problem: building from different directories rebuilt
  libc shims per directory, tens of GB of libc++ under Bazel's per-action sandboxes. Body ^f1
  > When using a relative zig lib directory (`ZIG_LIB_DIR=lib`) and when building from different directories, libc shims get rebuilt *for every working directory*.
  > In our case, it causes tens of gigabytes of `libc++.a` in zig cache directory, besides the CPU usage to generate those.
- [zig/build] [devflow/cache] Intended design: global cache manifests hold absolute paths;
  local cache manifests relative to the project root, so a moved project keeps its cache.
  andrewrk 2022-10-05 ^f2
  > Meanwhile, manifest files in the local cache would ideally contain only paths relative to the local project root, so that the project directory could be moved to a new location and the cache would continue functioning seamlessly.
- [zig/build] [devflow/cache] Different absolute paths stop sharing between machines or
  users (a different home directory is enough). motiejus 2022-10-05 ^f3
  > As a result, two machines/people with a different sandbox path (e.g. `/home/motiejus` and `/home/john` is enough to make a difference a difference) cannot share the compiled artifacts.
- [zig/build] [devflow/cache] Symlinks are not resolved: two paths to one directory count
  as different. andrewrk 2022-10-05 ^f4
  > However, the system will still consider two paths to be different even if they are symlinks resolving to the same directory
- [zig/build] [devflow/cache] Resolution agreed: drop the lib dir path from the hash (file
  contents are enough) and store lib dir files relative to a special prefix. andrewrk
  2022-11-14 ^f5
  > Not adding the zig lib directory path into cache hash. It's enough to consider the file contents of every file.
  > In cache manifest files, have a special way to encode a "zig lib directory" prefix.

## Read

- Whole thread (body and 12 comments).

## Not read

- The follow-up PRs (#13071, #13051 and the prefix change) themselves; the result is read
  in 0.17 source instead.
