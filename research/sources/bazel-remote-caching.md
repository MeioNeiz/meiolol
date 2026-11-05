---
title: 'Bazel docs: Remote Caching'
url: https://bazel.build/remote/caching
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole page)
relevance: high
grade: A/fair
description: How Bazel's remote and disk caches work: action cache keyed by an action's declared inputs, command and env, plus a content-addressed store; any HTTP PUT/GET server works; known ways hits are lost or wrongly shared
---
# Bazel docs: Remote Caching

Why: what makes a shared build cache hit across machines and checkouts, and what breaks
it?

## Assessment

- Evidence: A. Official docs of the build system Google's own (Blaze) descends from;
  remote caching in Bazel since 0.10 (2018), bazel-remote in production at several
  companies since 2018.
- Reasoning: fair. Explains the model and lists known issues honestly; no numbers on hit
  rates or speed-ups.
- Interests: Bazel project docs.
- Weigh: the model (key = hash of declared inputs, command, env) is the reference design
  to compare Zig's cache against.

## Findings

- [devflow/cache] A build is split into actions with declared inputs, outputs, command
  line and environment; the remote cache stores those actions' outputs. Overview ^f1
  > Each action has inputs, output names, a command line, and environment variables. Required inputs and expected outputs are declared explicitly for each action.
- [devflow/cache] Two stores: an action cache (action hash to result metadata) and a
  content-addressable store of output files. Overview ^f2
  > The action cache, which is a map of action hashes to action result metadata.
  > A content-addressable store (CAS) of output files.
- [devflow/cache] Reuse across machines is safe only if the build is reproducible. Intro ^f3
  > If your build is reproducible, the outputs from one machine can be safely reused on another machine, which can make builds significantly faster.
- [devflow/cache] Lookup order: local outputs first, then the remote cache; misses run
  locally and their outputs are uploaded. How a build uses remote caching ^f4
  > Bazel checks your local machine for existing build outputs and reuses any that it finds.
  > New build outputs are uploaded to the remote cache.
- [devflow/cache] The backend can be any HTTP/1.1 server with PUT and GET (nginx WebDAV,
  bazel-remote, S3, GCS); data is opaque bytes under /ac/ and /cas/. Backend, HTTP protocol ^f5
  > A HTTP/1.1 server can treat Bazel’s data as opaque bytes and so many existing servers can be used as a remote caching backend.
- [devflow/cache] Write access is worth restricting, for example only CI writes and
  developers read. Read from and write to the remote cache ^f6
  > You may want only your CI system to be able to write to the remote cache.
- [devflow/cache] A disk cache directory serves the same role for several checkouts or
  branches on one machine. Disk cache ^f7
  > This is useful for sharing build artifacts when switching branches and/or working on multiple workspaces of the same project, such as multiple checkouts.
- [devflow/cache] Editing an input during a build can upload a wrong result to the cache
  (guard flag `--experimental_guard_against_concurrent_changes`). Known issues ^f8
  > When an input file is modified during a build, Bazel might upload invalid results to the remote cache.
- [devflow/cache] Hits are lost when environment differs (different `$PATH`), and wrongly
  shared when an action uses an untracked tool outside the workspace (a system compiler).
  Known issues ^f9
  > For example, environments with different `$PATH` variables won’t share cache hits.
  > Then, two users with different compilers installed will wrongly share cache hits because the outputs are different but they have the same action hash.
- [devflow/cache] Poisoned cache: no way to tell which outputs belong to which build, so
  the fix is delete all or delete old. Delete content ^f10
  > When deleting outputs, either delete the entire cache, or delete old outputs.
- [devflow/cache] (inferred) Many agents editing one checkout while builds run is exactly
  the ^f8 hazard: a step that reads a file mid-edit can record a result against content
  it did not build. ^f11

## Read

- Whole page.

## Not read

- Linked debugging pages (cache-local, cache-remote) and the FOSDEM 2018 talk.
