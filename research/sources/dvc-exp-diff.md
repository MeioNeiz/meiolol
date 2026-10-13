---
title: 'DVC docs: dvc exp diff'
url: https://dvc.org/doc/command-reference/exp/diff
kind: docs
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (whole page)
relevance: medium
grade: A/fair
description: DVC's run diff command; compares params and metrics of two experiments (or one against the workspace), listing only what changed with old, new and change columns
---
# DVC docs: dvc exp diff

Why: what a run diff command shows, as a model for comparing two lab runs.

## Assessment

- Evidence: A. treeverse/dvc, since 2017, ~15.9k stars, active.
- Reasoning: fair. Reference docs.
- Interests: vendor docs, open source.
- Weigh: trust as a design.

## Findings

- [lab] With no arguments, compares all params and metrics in the workspace against
  the last commit, listing only those that changed (all with --all). ^f1
  > Only params/metrics that changed are listed, by default (show everything with `--all`).
- [lab] Takes two experiment names or hashes; one argument compares it to the
  workspace. ^f2
  > `a_rev` and `b_rev` are optional experiments to compare. They accept experiment names or hashes
- [lab] Output is one row per metric or param: path, name, value in A, value in B,
  change; JSON or Markdown on request. ^f3
  > Path         Metric  gluey-leak  ochre-dook   Change
  > `--json` - prints the command's output in easily parsable JSON format, instead of a human-readable table.
- [lab] Checked, not there: the change column is a raw difference with no noise
  estimate, interval or significance. ^f4
- [lab] (inferred) For meiolol: `lab diff <run-a> <run-b>` should print changed args,
  changed provenance (HEAD, binary hash, data snapshot) and the paired metric
  difference with its interval from stored per-game predictions, not two unpaired
  numbers. ^f5

## Read

- Whole page.

## Not read

- Comparing Experiments user guide page.
