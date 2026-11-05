---
title: meiolol build and push logs, 5 Nov 2026
url: file://data/deploys.tsv
kind: dataset
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: ran (deploys.tsv ci pairs 17 Oct to 5 Nov, push log, slot and load samples)
relevance: high
grade: B/fair
description: Our own pre-push ci durations and failures per day, push log, slot queue, Mac load and memory, box headroom, measured 5 Nov
---
# meiolol build and push logs, 5 Nov 2026

Why: measure the build queue before recommending changes to it.

## Assessment

- Evidence: B. First-hand logs: 838 ci starts in deploys.tsv, push log, live samples.
- Reasoning: fair. Durations are wall time under contention; slots keep no history, so
  queue waits are two samples, not a distribution.
- Interests: none.
- Weigh: ci durations and failure counts are solid; per-commit build demand is estimated.

## Findings

- [devflow] Pre-push ci median was 28-33 s on 17-21 Oct and 192-232 s on 4-5 Nov
  (p90 429-515 s, max 1412 s today); every run on the Mac. ^f1
  > 10-17 43 0 30 55 87 21
  > 11-05 20 6 232 515 1412 103
- [devflow] Warm ci on a quiet Mac still runs in 72-90 s: ^f2
  > 09:18 72 ok a6762737 zig build ci on the Mac
  > 00:43 90 ok 2c73a2c0 zig build ci on the Mac
- [devflow/queue] 5 Nov: 20 ci runs, 6 failed (30%); 3 of the failures were the same commit
  retried (island .wasm FileNotFound, a shared .zig-cache race per common.md). ^f3
  > 09:13 145 failed a6762737 zig build ci on the Mac
  > 09:16 91 failed a6762737 zig build ci on the Mac
- [devflow/queue] 4 Nov: 58 ci runs taking 250 min of wall time, each holding all 3 slots. ^f4
  > 11-04 58 7 192 429 1066 250
- [devflow] One ci held 3 of 3 slots for 7 min with 7 runs queued behind it, test-ui among
  them. ^f5
  > 3 of 3 held by one pre-push ci (7 min in), 7 runs waiting
- [devflow] The Mac was swapping hard: 16.5 of 17.4 GB swap used, load 13-15 on 10 cores. ^f6
  > used 16515.56M of 17408.00M
  > load averages 13.36 15.20 14.81
- [devflow] Chrome, not zig, was the top CPU user in the sample (98% plus three processes
  at 20-25%; two zig at 76% and 63%). ^f7
  > top CPU: Chrome 98% plus three more Chrome processes 20-25% each
- [devflow/cache] The box had headroom: 16 vCPU at load ~4, 51 GB available, but only 9.5 GB
  free on its root disk; the gpu-box has been off since 3 Nov. ^f8
  > 16 vCPU, load average 3.91 4.12 4.33, 51 GB memory available
- [devflow/agents] Commits on main: 89 on 4 Nov, 52 on 5 Nov by 14:16, peaking at 14 in the
  12h hour. ^f9
  > 12h 14, 13h 9, 14h 3
- [devflow/cache] Repo .zig-cache 30 GB plus ~40 GB of fixed build trees on the Mac. ^f10
  > Repo .zig-cache 30G

## Read

- data/deploys.tsv (box), ~/.cache/meiolol-push/log, slots status, compute.sh, git log.

## Not read

- Slot waits over time: slots.sh keeps no history.
