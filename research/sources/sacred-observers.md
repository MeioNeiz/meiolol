---
title: 'Sacred docs: Observing an Experiment (run record, file layout, events)'
url: https://sacred.readthedocs.io/en/stable/observers.html
kind: docs
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (intro, Mongo entry, file storage layout, events, custom info)
relevance: high
grade: A/fair
description: Sacred (IDSIA, since 2014) docs for what a run record holds: status, times, config with seed, git commit and dirty flag, host, dependencies, source md5s, input file hashes, captured output, artifacts
---
# Sacred docs: Observing an Experiment (run record, file layout, events)

Why: what a mature tracker records per run, to compare with meiolol's run dir
(meta, src.diff, log, runs.tsv row).

## Assessment

- Evidence: A. IDSIA/sacred, created March 2014, ~4.4k stars, release 0.8.7 (Nov
  2024), still pushed in 2025; long used in academic ML (Sacred/Omniboard).
- Reasoning: fair. Docs describe what is stored and when, little on why.
- Interests: none (open-source research tool).
- Weigh: trust as a reference schema for a run record.

## Findings

- [lab] Goal of a run record: enough to analyse results and reproduce them; observers
  see the run while it is still running. ^f1
  > When you run an experiment you want to keep track of enough information, such that you can analyse the results, and reproduce them if needed.
- [lab] Every run gets a status (e.g. COMPLETED), start, heartbeat and stop times, a
  result, the full config including the seed, captured stdout, artifacts. Database
  Entry ^f2
  > "status" : "COMPLETED",
  > "seed" : 909032414,
- [lab] Provenance: package dependencies with versions, source files with md5, git
  url, commit and a dirty flag, host (OS, CPU, hostname, Python). Database Entry ^f3
  > "dependencies" : \["numpy==1.9.1", "sacred==0.7.0"\],
  > As you can see a lot of relevant information is being stored, among it the used configuration, automatically detected package dependencies and information about the host.
- [lab] The file observer writes one directory per run: config.json, cout.txt,
  info.json, run.json, plus a deduplicated _sources dir of source snapshots named by
  md5. File Storage Observer ^f4
  > The FileStorageObserver creates a separate sub-directory for each run and stores several files in there
  > The FileStorageObserver also stores a snapshot of the source-code in a separate `my_runs/_sources` directory
- [lab] Input files opened through the run are logged with their MD5, so the data a
  run read is pinned. Resources ^f5
  > In any case the filename along with its MD5 hash is logged.
- [lab] A run ends as completed (with result), interrupted, or failed (with
  stacktrace); queued runs are recorded too; a heartbeat every 10 s shows it is alive
  and updates output and partial results. Events ^f6
  > once it stops one of the three `completed_event`, `interrupted_event`, or `failed_event` is fired. If the run is only being queued, then instead of all the above only a single `queued_event` is fired.
  > Sacred fires a `failed_event` with the fail time and the corresponding stacktrace.
  > The heartbeat event is also a way of monitoring if an experiment is still running.
- [lab] Small per-run values (loss per epoch, parameter count) go in an info dict;
  big outputs like a trained model go in as artifacts. Saving Custom Information ^f7
  > The `info` dictionary is meant to store small amounts of information about the experiment, like training loss for each epoch or the total number of parameters.
  > This mechanism is meant to store big custom chunks of data like a trained model.
- [lab] Checked, not there: no run comparison or diff command and no dedup of
  identical configs in these docs; comparison is left to dashboards (Omniboard,
  Sacredboard) or queries on the store. ^f8
- [lab] (inferred) For meiolol: our run dir already covers commit, dirty count, host,
  args, log; missing versus Sacred are an explicit status for every run (queued,
  running, failed with error tail, interrupted), a heartbeat, input data hashes
  (snapshot id or md5 of the game files) and the config as a structured, hashable
  object rather than an args string. ^f9

## Read

- Intro, Mongo database entry, file storage layout, events, custom info, resources,
  artifacts.

## Not read

- Other observers (TinyDB, SQL schema, S3, Slack), template rendering.
