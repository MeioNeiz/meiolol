---
title: Don't Build Multi-Agents (Walden Yan, Cognition, 2025)
url: https://cognition.ai/blog/dont-build-multi-agents
kind: article
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole post)
relevance: medium
grade: B/strong
description: The critic: parallel subagents that don't share full context make conflicting implicit decisions; prefer one linear agent
---
# Don't Build Multi-Agents (Walden Yan, Cognition, 2025)

Why: the case against splitting work across parallel agents; where does coordination
cost come from?

## Assessment

- Evidence: B. Builders of Devin (a production coding agent) reporting their design
  principles; argued from examples, no measurements. Dated June 2025; redirects to
  cognition.com
- Reasoning: strong. Explains the failure mechanism, gives alternatives (single agent,
  history compression) and admits limits (context windows)
- Interests: vendor of a single-agent product (Devin), selling it at the end
- Weigh: the mechanism (implicit decisions conflict) applies to parallel sessions on
  one repo; the blanket "don't" is about agents splitting one task, not independent
  tasks

## Findings

- [devflow/agents] Splitting one task across parallel subagents is fragile: each
  misreads or reinterprets its part and the combiner inherits the mismatch. ^f1
  > This is a tempting architecture, especially if you work in a domain of tasks with several parallel components to it. However, it is very fragile.
- [devflow/agents] Two principles: share full context (whole agent traces), and actions
  carry implicit decisions, so parallel agents that can't see each other conflict. ^f2
  > Share context, and share full agent traces, not just individual messages
  > Actions carry implicit decisions, and conflicting decisions carry bad results
- [devflow/agents] Recommended default: one single-threaded linear agent; for very long
  tasks, a model that compresses history. ^f3
  > The simplest way to follow the principles is to just use a single-threaded linear agent
- [devflow/agents] Agents can't yet resolve conflicts by talking them out the way two
  engineers settle a merge conflict; multi-agent collaboration in 2025 is fragile. ^f4
  > If Engineer A’s code causes a merge conflict with Engineer B, the correct protocol is to talk out the differences and reach a consensus.
  > it is evident that in 2025, running multiple agents in collaboration only results in fragile systems.
- [devflow/agents] (inferred) For us: the conflict cost grows with how much parallel
  sessions' work overlaps; independent tasks with their own files escape most of it,
  shared files (tokens, root modules) don't. ^f5
- [devflow/agents] Checked, not there: no numbers on how many agents, no build or CI
  contention. ^f6

## Read

- whole post: closely
