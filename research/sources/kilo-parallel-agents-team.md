---
title: How 7 Kilo Code Engineers Run Up to 20 Parallel Agents (Kilo blog, 2026)
url: https://web.archive.org/web/20260615171307/https://blog.kilo.ai/p/how-7-kilo-code-engineers-run-up
kind: article
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole post, Wayback copy; live page is behind a cookie wall)
relevance: medium
grade: C/fair
description: Vendor blog polling 7 engineers: 2-4 foreground agents each, background fire-and-forget agents beyond that, verification the new bottleneck
---
# How 7 Kilo Code Engineers Run Up to 20 Parallel Agents (Kilo blog, 2026)

Why: how many parallel coding agents do practitioners actually run, with numbers?

## Assessment

- Evidence: C. A 30-minute discussion among 7 engineers at an agent vendor, plus
  quoted figures from Willison, Hashimoto and Osmani; self-reported counts, no
  throughput or quality measurements
- Reasoning: fair. Separates foreground (attended) from background (fire-and-forget)
  agents, which explains the inflated 20-100 claims
- Interests: vendor (Kilo Code sells agents, links its products throughout)
- Weigh: the 2-4 foreground count is consistent across several named people; treat
  "20 agents" as mostly unattended background jobs; nothing on shared build capacity

## Findings

- [devflow/agents] Most of the 7 engineers run 2-4 foreground agents (ones they watch,
  review and steer) at a time. ^f1
  > Most of our engineers have 2-4 foreground agents running at a time
- [devflow/agents] Others cited agree: Hashimoto manages at most two agents; one
  architecture engineer keeps to two or three, as quality drops without close
  attention. ^f2
  > calls) himself “the mayor” managing at most two agents at a time.
  > even with SOTA models, output quality on complex tasks drops quickly unless you stay close to the work.
- [devflow/agents] The one engineer running 20+ agents has 1-3 in the foreground; the
  rest are background agents that each ship a PR checked by tests and are judged later.
  ^f3
  > Mark usually runs 1-3 parallel agents in the foreground, while the rest are background jobs that don’t demand a lot of attention.
  > Each agent ships a pull request, which passes or fails in tests, and Mark looks at the final result later.
- [devflow/agents] Addy Osmani runs four to five background agents on low-to-medium
  complexity work. ^f4
  > runs four to five background agents handling low-to-medium complexity work
- [devflow/agents] Size a task so its output can be reviewed in one sitting; split
  tasks so each finishes before context fills (quality said to drop near 60% fill,
  a claim). ^f5
  > A good agent task should produce an output a human can review in one sitting.
- [devflow/agents] Conclusion: the bottleneck is moving from writing code to verifying
  it; the practical shape is 2-4 foreground agents, a handful in the background, and a
  strong verification loop. ^f6
  > the practical workflow is much less dramatic: 2–4 agents in the foreground, a handful in the background, and a strong verification loop on top.
- [devflow/agents] (inferred) Background agents lean hardest on automated tests ("passes
  or fails in tests"), so a team that adds background agents adds test and CI load,
  the resource we are short of. ^f7
- [devflow/agents] Checked, not there: no mention of build, test or CI contention
  between agents, or of local versus cloud test capacity. ^f8

## Read

- whole post

## Not read

- linked: Yegge's Gas Town, Ronacher's "agent psychosis", Osmani's coding agents
  manager post
