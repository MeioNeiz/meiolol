---
title: "Claude Code docs: Run agents in parallel"
url: https://code.claude.com/docs/en/agents.md
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole page)
relevance: low
grade: B/fair
description: Official overview of Claude Code's five ways to run work in parallel and when to isolate with worktrees
---
# Claude Code docs: Run agents in parallel

Why: overview of Anthropic's parallel options, linked from the worktrees page.

## Assessment

- Evidence: B. Vendor docs, overview only
- Reasoning: fair. Decision criteria (who coordinates, do workers talk, same files?)
- Interests: vendor
- Weigh: a map, few facts; the sizing numbers are on the agent teams page

## Findings

- [devflow/agents] Choice turns on three questions: who coordinates, do workers need to
  talk, and do they touch the same files (if so, worktrees or file partitioning). ^f1
  > The right approach depends on who coordinates the work, whether the workers need to communicate, and whether they edit the same files
- [devflow/agents] `/batch` splits one large change into 5 to 30 worktree-isolated
  subagents. ^f2
  > has Claude split one large change into 5 to 30 worktree-isolated subagents
- [devflow/agents] Running several sessions or subagents multiplies token use. ^f3
  > Running several sessions or subagents at once multiplies token usage.

## Read

- whole page
