---
title: 'DVC docs: dvc exp show'
url: https://dvc.org/doc/command-reference/exp/show
kind: docs
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (description, options)
relevance: medium
grade: A/fair
description: DVC's experiment table command; one row per experiment grouped by parent commit, columns for metrics, params and dependency hashes, filters for changed columns, sorting, failed and queued rows, JSON/CSV output
---
# DVC docs: dvc exp show

Why: how a mature tool shows many runs at once for comparison, and which output shape
it offers machines (an agent).

## Assessment

- Evidence: A. treeverse/dvc, since 2017, ~15.9k stars, release 3.67.1 (Mar 2026).
- Reasoning: fair. Reference docs; says what, not why.
- Interests: vendor docs (now under lakeFS), but open source.
- Weigh: trust as a design for a run table.

## Findings

- [lab] The table holds, per experiment, its parent and name or hash, then metrics,
  parameters and dependency hashes as columns. ^f1
  > Displays experiments in a detailed table which includes their parent and name (or hash), as well as colored columns for (left to right): metrics (yellow), parameters (blue) and dependencies (violet).
- [lab] Experiments are grouped by parent commit, then sorted, by default by time or
  by any one metric or param. ^f2
  > Experiments in the table are first grouped (by parent commit).
  > The `--sort-by` and `--sort-order` options can change this ordering, based on any single, visible metric or param.
- [lab] Column filters cut the table to what differs: --only-changed shows only
  metrics, params and deps that vary across experiments; --drop and --keep by regex. ^f3
  > `--only-changed` - show only metrics, parameters and dependencies with values that vary across experiments.
- [lab] Failed and queued experiments are rows in the table too (hidden only on
  request). ^f4
  > `--hide-failed` - hide failed experiments in the table.
  > `--hide-queued` - hide queued experiments in the table.
- [lab] Same data as JSON, CSV or Markdown for scripts. ^f5
  > `--json` - prints the command's output in easily parsable JSON format, instead of a human-readable table.
- [lab] Experiments get short human names (e.g. urban-sign) beside the hash. ^f6
  > a2efdc9 [urban-sign]
- [lab] (inferred) For meiolol: a `lab show` over runs.tsv with --only-changed style
  columns (args that differ), failed and queued runs as rows, and dataset/binary hash
  columns, would let the agent see what was already tried in one short table. ^f7

## Read

- Description and options.

## Not read

- Examples beyond the first table; VS Code extension.
