---
title: Recovering Wasted Compute in Autoresearch Agents
url: https://arxiv.org/html/2608.10424
kind: paper
commit:
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (sections 1-4, 6)
relevance: high
grade: B/strong
description: Controlled study (Aug 2026, Goldblum and others) of where AIDE, ML-Master and MLEvolve waste budget on tabular tasks; a shared bug registry, tuning enforcement and Thompson-sampling backtracking, each measured over 9 tasks x 10 seeds
---
# Recovering Wasted Compute in Autoresearch Agents

Why: the most direct measurement found of which harness mechanisms stop agents
re-doing work (repeat bugs, dead branches, early stop) and what each is worth.

## Assessment

- Evidence: B. 9 tabular tasks released after the LLM's cutoff, 10 seeds each, fixed
  2-hour budget on 22 CPU cores, GPT-5-mini only, over a thousand runs; controlled
  ablations that hold other settings fixed (TS on AIDE and MLEvolve). Held-out test
  scored by MLE-bench graders.
- Reasoning: strong. Names the mechanism behind each gain (redundant bug rate, valid
  node share), reports where an intervention hurts (ML-Master tuning), counts failed
  runs rather than averaging them away.
- Interests: academic (with Capital One authors); no product.
- Weigh: trust the debug-registry result most (large, both agents); tuning gains are
  for AIDE only; one cheap model, small tabular tasks.

## Findings

- [lab] Failure modes found: the same bugs fixed over and over, tuning skipped despite
  budget left, tree search that does not explore, EDA done but not used. `Abstract` ^f1
  > (1) they waste compute resolving the same bugs over and over again; (2) they often fail to tune hyperparameters even when they have a large remaining compute budget; (3) the tree-search algorithms that power them do not explore
- [lab] Cause of repeat bugs: only the child that debugs a failed node sees the error,
  so other branches rediscover the same API or version error, often dozens of times a
  run. `§3.1` ^f2
  > The rest of the tree therefore independently rediscovers the same deprecated API call or version mismatch, often dozens of times within a single run. We call this context isolation.
- [lab] Debug consultant: each crash is compressed to error type, short signature and
  the strategy that caused it; a shared registry turns these into BANNED patterns and
  proven USE fixes, appended to every generation prompt. `§3.1` ^f3
  > Raw tracebacks are verbose and vary across iterations; a short hint is sufficient for the LLM to avoid the mistake.
  > During generation (drafting or improving), the distilled banned-pattern list is appended to the prompt, preventing the agent from repeating known-failing API calls.
- [lab] Deterministic rule: a timeout or empty log ends the branch rather than being
  retried as noise. `§3.1` ^f4
  > execution timeouts and empty logs are treated as terminal dead ends that strictly halt the branch, rather than stochastic noise worth retrying.
- [lab] Effect of the shared bug registry: AIDE golds 22 to 38 and valid runs 73/90 to
  90/90; ML-Master golds 18 to 29; median steps to a first valid submission 6 to 0.
  Table 1. `§4.2` ^f5
  > For AIDE, the debug consultant nearly doubles the gold-medal count, from 22 to 38, and eliminates all 17 of the baseline’s failed runs, raising the valid-submission rate from 81% to 100%
  > the median number of steps to a first valid submission drops from 6 to 0
- [lab] Mechanism: redundant bug encounters fell from 46% to 7.8%, error-free nodes rose
  from 54.7% to 79.0%; more valid nodes, better held-out score (r = +0.22, 163 seeds).
  `§4.2` ^f6
  > In AIDE’s search journals, redundant bug encounters fall from 46% to 7.8%, and the fraction of nodes that execute without error rises from 54.7% to 79.0%.
- [lab] Agents under-tune: a prompt directive (baseline first, cheap trials to find the
  hyperparameters that matter, then tune around the best once gains stall) improved
  AIDE on 7 of 9 tasks. `§3.2`, `§4.3` ^f7
  > instructing it to establish a validated baseline, run cheap trials to identify the most impactful hyperparameters, then tune those around the best configuration once gains stall.
  > improving graded scores on 7 of 9 competitions with individual effects as large as +0.388 on S5E8
- [lab] Budget-dependent reward: an LLM grades tuning effort 0-3 per node; weak tuning is
  penalised throughout, strong tuning rewarded only late, so the search explores early
  and tunes late. `§3.2` ^f8
  > weak tuning (scores of 0 or 1) is penalized throughout, but strong tuning (2 or 3) is rewarded only in later stages of the search, so the agent explores broadly early and tunes intensively late.
- [lab] Interventions interact: the same tuning push hurt ML-Master, whose memory logged
  a crash as buggy without the reason, so it kept retrying the broken approach. `§4.3` ^f9
  > ML-Master’s memory then records the crash as buggy without propagating why, resulting in the agent continually retrying variants of the same broken approach.
- [lab] Backtracking: when the same error repeats down a path, return to where it first
  appeared and pick a sibling by Thompson sampling (Beta per node). With drafts held
  equal, null runs fell from 33 to 15 of 90 on AIDE; on MLEvolve TS won 5 of 9, most
  differences within SEM. `§3.3`, `§4.4` ^f10
  > Holding all other settings identical, AIDE+TS reduces null runs from 33 to 15 of 90 relative to AIDE+more drafts (a 54.5% reduction)
- [lab] More initial drafts (5 to 20) helped AIDE by itself, before TS. `§4.4` ^f11
  > AIDE with 20 initial drafts already improves over the plain setting.
- [lab] Agents ignore analysis: injected, deliberately wrong EDA was acknowledged in 21%
  of AIDE runs and changed feature selection in 5%; scores did not move. `§4.5` ^f12
  > in AIDE, the agent acknowledged the malicious EDA in only 21% of cases and let it affect feature selection in just 5%.
- [lab] Separate global facts (installed versions, valid APIs, how long a fold takes)
  from branch-local ones; re-deriving global facts per branch is the waste. `§6` ^f13
  > Global facts are invariant across the tree, and re-deriving them per branch or node is redundant.
- [lab] LLMs write nearly the same program repeatedly, so a wide tree is wide only on
  paper; selection fixes reduce variance more than they raise peaks. `§6` ^f14
  > When an agent produces dozens of near-identical programs, the tree is wide only on paper.
- [lab] Averaging over successful runs hides runs that produce nothing; count them. `§6` ^f15
  > the common practice of averaging over successful runs hides these failures so the waste goes uncounted.
- [lab] (inferred) For Claude lab sessions: a shared, append-only "known constraints"
  file (banned calls, proven fixes, how long each ladder rung takes) injected at session
  start is the cheapest measured win here; it matters most when several sessions or
  branches hit the same Zig/CUDA errors. ^f16

## Read

- Sections 1-4 and 6 whole.

## Not read

- Appendices A-C (per-seed tables, prompts, HPO asymmetry analysis, EDA injection).
