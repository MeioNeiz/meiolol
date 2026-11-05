---
title: "Claude Code docs: Orchestrate agent teams"
url: https://code.claude.com/docs/en/agent-teams.md
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (intro, team size, task size, file conflicts)
relevance: high
grade: B/fair
description: Official guidance on agent teams: start with 3-5 teammates, 5-6 tasks each, diminishing returns, own files to avoid overwrites
---
# Claude Code docs: Orchestrate agent teams

Why: Anthropic's own guidance on how many parallel Claude Code sessions to run.

## Assessment

- Evidence: B. Vendor docs for an experimental feature; guidance, no measurements
  behind the numbers
- Reasoning: fair. Lists the costs (tokens, coordination, diminishing returns); the
  3-5 figure is a starting heuristic, not derived
- Interests: vendor; says to use more agents only when the work benefits, which cuts
  against selling tokens
- Weigh: treat 3-5 as Anthropic's rule of thumb; nothing here on shared build or CI

## Findings

- [devflow/agents] Teams add coordination overhead and many more tokens; they suit
  independent work, not sequential tasks, same-file edits or many dependencies. ^f1
  > Agent teams add coordination overhead and use significantly more tokens than a single session. They work best when teammates can operate independently.
- [devflow/agents] No hard limit, but token cost scales linearly, coordination overhead
  grows and returns diminish with more teammates. ^f2
  > Diminishing returns**: beyond a certain point, additional teammates don't speed up work proportionally
  > more teammates means more communication, task coordination, and potential for conflicts
- [devflow/agents] Start with 3-5 teammates; for 15 independent tasks, 3 is a good start;
  three focused teammates often beat five scattered ones. ^f3
  > Start with 3-5 teammates for most workflows. This balances parallel work with manageable coordination. If you have 15 independent tasks, 3 teammates is a good starting point.
  > Three focused teammates often outperform five scattered ones.
- [devflow/agents] 5-6 tasks per teammate keeps everyone busy and lets the lead
  reassign work; tasks too small cost more coordination than they save. ^f4
  > Having 5-6 tasks per teammate keeps everyone productive and lets the lead reassign work if someone gets stuck.
- [devflow/agents] Two teammates editing one file overwrite each other; partition
  files per teammate (teams don't use worktrees). ^f5
  > Two teammates editing the same file leads to overwrites. Break the work so each teammate owns a different set of files.
- [devflow/agents] Start with non-coding work (review, research, debugging) to get
  parallel exploration without parallel implementation's coordination costs. ^f6
  > These tasks show the value of parallel exploration without the coordination challenges that come with parallel implementation.
- [devflow/agents] Checked, not there: nothing on shared build, test or CI capacity
  between teammates. ^f7

## Read

- intro, "Choose an appropriate team size", "Size tasks appropriately", "Avoid file
  conflicts"

## Not read

- display modes, troubleshooting, limitations
- costs page "agent team token costs"
