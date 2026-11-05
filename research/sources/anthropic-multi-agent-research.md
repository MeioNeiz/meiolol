---
title: How we built our multi-agent research system (Anthropic Engineering, 2025)
url: https://www.anthropic.com/engineering/multi-agent-research-system
kind: article
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole post; numbers and coding remarks read closely)
relevance: medium
grade: B/strong
description: Anthropic's orchestrator-worker Research feature: 3-5 parallel subagents, 90% gains on breadth tasks, 15x tokens, coding less parallelisable
---
# How we built our multi-agent research system (Anthropic Engineering, 2025)

Why: what does Anthropic report about how many parallel agents pay off, and for which
kinds of work?

## Assessment

- Evidence: B. A production system with internal evals (about 20 queries to start,
  BrowseComp analysis); evals unpublished
- Reasoning: strong. Explains why multi-agent works (token spend), its costs (15x
  tokens) and where it doesn't fit (coding, shared context)
- Interests: vendor, describing its own product
- Weigh: the "coding is less parallelisable" and "sync waits on the slowest" points
  transfer; the 90% figures are for breadth-first research, not coding

## Findings

- [devflow/agents] Multi-agent (Opus 4 lead, Sonnet 4 subagents) beat single-agent Opus 4
  by 90.2% on their internal research eval, on breadth-first queries. ^f1
  > a multi-agent system with Claude Opus 4 as the lead agent and Claude Sonnet 4 subagents outperformed single-agent Claude Opus 4 by 90.2% on our internal research eval
- [devflow/agents] Token use alone explained 80% of BrowseComp performance variance;
  multi-agent works mainly by spending more tokens. ^f2
  > We found that token usage by itself explains 80% of the variance
- [devflow/agents] Cost: agents use about 4x the tokens of chat, multi-agent systems
  about 15x. ^f3
  > agents typically use about 4× more tokens than chat interactions, and multi-agent systems use about 15× more tokens than chats
- [devflow/agents] Coding has fewer truly parallel tasks than research, and agents are
  not yet good at coordinating and delegating in real time; shared context or many
  dependencies make a poor fit. ^f4
  > most coding tasks involve fewer truly parallelizable tasks than research, and LLM agents are not yet great at coordinating and delegating to other agents in real time
- [devflow/agents] Their default fan-out is 3-5 subagents in parallel, each running 3+
  tools in parallel; that cut research time by up to 90% on complex queries. ^f5
  > the lead agent spins up 3-5 subagents in parallel rather than serially; (2) the subagents use 3+ tools in parallel. These changes cut research time by up to 90% for complex queries
- [devflow/agents] Effort scales with the task: 1 agent for a fact, 2-4 subagents for
  comparisons, 10+ only for complex research; early versions spawned 50 subagents for
  simple queries. ^f6
  > Simple fact-finding requires just 1 agent with 3-10 tool calls, direct comparisons might need 2-4 subagents with 10-15 calls each, and complex research might use more than 10 subagents
  > Early agents made errors like spawning 50 subagents for simple queries
- [devflow/agents] Vague task descriptions made subagents duplicate each other's work;
  each needs an objective, output format, tools and clear boundaries. ^f7
  > Without detailed task descriptions, agents duplicate work, leave gaps, or fail to find necessary information.
- [devflow/agents] Synchronous fan-out waits for the slowest subagent, which can block
  the whole system. ^f8
  > the entire system can be blocked while waiting for a single subagent to finish searching
- [devflow/agents] (inferred) For us: a coordinator that waits on all builders before
  the next step pays the slowest builder's queue wait; shared build slots make that
  tail longer. ^f9

## Read

- whole post; evaluation and production-reliability sections skimmed
