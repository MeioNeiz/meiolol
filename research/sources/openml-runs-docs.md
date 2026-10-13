---
title: 'OpenML docs: Runs'
url: https://docs.openml.org/concepts/runs/
kind: docs
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (whole page)
relevance: medium
grade: A/fair
origin: openml-paper
description: OpenML's current concept page for runs; every prediction for every split and instance is uploaded, so new metrics can be computed for all past runs
---
# OpenML docs: Runs

Why: confirm the current (2024) run model, especially re-scoring old runs with new
metrics.

## Assessment

- Evidence: A. Official docs of a platform in use since 2013; page dated May 2024.
- Reasoning: fair. Short; states design, admits reproducibility limits.
- Interests: platform docs.
- Weigh: agrees with [[openml-paper]]; adds the retroactive metric point explicitly.

## Findings

- [lab] Runs carry all predictions for all splits and instances, including class
  confidences, so anyone can evaluate them independently. ^f1
  > For most tasks, this includes all predictions, for all train-test splits, for all instances in the dataset, including all class confidences.
- [lab] Uploaded runs are scored by the server on many metrics, making them directly
  comparable; local metrics and runtimes are also stored. ^f2
  > When a run is uploaded, OpenML automatically evaluates every run using a wide array of evaluation metrics. This makes them directly comparable with all other runs shared on OpenML.
- [lab] New metrics can be added later and computed for all past runs. ^f3
  > New metrics can also be added to OpenML's evaluation engine, and computed for all runs afterwards.
- [lab] Exact reproduction is not guaranteed across numeric libraries, OS and
  hardware, which is why stored predictions matter. ^f4
  > exactly reproducing all results may not always be possible because of changes in numeric libraries, operating systems, and hardware

## Read

- Whole page.

## Not read

- API reference for the run upload format (predictions ARFF columns).
