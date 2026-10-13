---
title: 'DVC docs: internal files (run cache)'
url: https://doc.dvc.org/user-guide/project-structure/internal-files
kind: docs
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (run cache section)
relevance: medium
grade: A/fair
description: DVC's internal files page; the run cache keys each stage run by a hash of exact dependency contents, parameter values and command, so an identical run is restored instead of re-executed
---
# DVC docs: internal files (run cache)

Why: how a mature tool deduplicates identical runs.

## Assessment

- Evidence: A. treeverse/dvc, since 2017, ~15.9k stars; run cache on by default.
- Reasoning: fair; states its determinism assumption.
- Interests: vendor docs, open source.
- Weigh: trust the mechanism; our runs are seeded but GPU runs may not be bitwise
  deterministic, so a cache hit is "already measured", not "identical output".

## Findings

- [lab] exp run and repro log every stage run and reuse it by default. Run cache ^f1
  > [`dvc exp run`](https://doc.dvc.org/command-reference/exp/run) and [`dvc repro`](https://doc.dvc.org/command-reference/repro) by default populate and reutilize a log of stages that have been run in the project.
- [lab] A run's identity is the exact dependency contents or parameter values plus the
  literal command, hashed into a path in the run cache. Run cache ^f2
  > Runs are identified as combinations of exact dependency contents (or parameter values), and the literal command(s) to execute. These combinations are represented by special hashes
- [lab] The cache assumes deterministic commands. Run cache ^f3
  > The run cache assumes that stage commands are deterministic
- [lab] (inferred) For meiolol: a run key = hash(binary hash, data snapshot id, sorted
  args, seed) stored in runs.tsv would let lab-run refuse or short-circuit an exact
  repeat ("same as run X, dev gain Y") instead of spending GPU time. ^f4

## Read

- Run cache section; skimmed the rest.

## Not read

- dvc.lock format details.
