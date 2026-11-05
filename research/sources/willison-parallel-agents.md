---
title: Embracing the parallel coding agent lifestyle (Simon Willison, 2025)
url: https://simonwillison.net/2025/Oct/5/parallel-coding-agents/
kind: article
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Practitioner's first-hand account of running several Claude Code and Codex agents at once; review is the bottleneck
---
# Embracing the parallel coding agent lifestyle (Simon Willison, 2025)

Why: what limits the number of parallel coding agents for one developer, and how do
practitioners isolate them?

## Assessment

- Evidence: B. First-hand report by a well-known practitioner (Datasette, long-running
  blog); weeks of use, no measurements
- Reasoning: fair. Names the bottleneck (review) and sorts tasks by how much review they
  need; no counts or timings
- Interests: sponsored blog (sponsor banner), no stake in a parallel-agent product
- Weigh: trust the "review is the limit" and task-sorting points; no numbers to reuse

## Findings

- [devflow/agents] The natural bottleneck on parallel agents is the human reviewing
  their output, not the agents. ^f1
  > AI-generated code needs to be reviewed, which means the natural bottleneck on all of this is how fast I can review the results.
- [devflow/agents] He lands one significant change at a time; the extra agents get work
  that adds little cognitive overhead. ^f2
  > I can only focus on reviewing and landing one significant change at a time, but I’m finding an increasing number of tasks that can still be fired off in parallel without adding too much cognitive overhead to my primary work.
- [devflow/agents] Parallel work that pays: research and proofs of concept (no code kept),
  explaining existing code, and low-stakes maintenance such as fixing deprecation
  warnings. ^f3
  > Research tasks answer questions or provide recommendations without making modifications to a project that you plan to keep.
  > Is your test suite spitting out a warning that something you are using is deprecated? Chuck that at a bot
- [devflow/agents] Work from your own detailed specification is much cheaper to review
  than code arriving unasked. ^f4
  > Code that started from your own specification is a lot less effort to review.
- [devflow/agents] Isolation: separate terminals in different directories; for two agents
  on one repo a fresh checkout (often in /tmp) rather than git worktrees; riskier tasks
  go to cloud agents. ^f5
  > I haven’t adopted git worktrees yet: if I want to run two agents in isolation against the same repo I do a fresh checkout, often into `/tmp`.
- [devflow/agents] Checked, not there: no count of agents run at once, no build or CI
  contention, no throughput numbers. ^f6

## Read

- whole post: closely

## Not read

- Jesse Vincent's and Peter Steinberger's workflow posts linked at the end
