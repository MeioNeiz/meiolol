---
title: 'Yang et al. 2026: Advancing Model Research in AgentX, Long-Horizon Autonomy for Industrial Recommender Systems'
url: https://arxiv.org/pdf/2609.30001
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (abstract, section 1 end, 3.3, 4.5)
relevance: high
grade: B/fair
description: Kuaishou's 2026 research agent for recommender models; rule-based action-type rotation plus agent-chosen experiments, and a historical-replay benchmark comparing experiment selection policies
---
# Yang et al. 2026: Advancing Model Research in AgentX

Why: a production LLM research agent that has to pick the next experiment under a
budget, with a direct comparison of selection policies (fixed, bandit, agent-led,
greedy, random).

## Assessment

- Evidence: B. Production system at Kuaishou: 636 completed model-changing experiments,
  online A/B tests; replay benchmark of 473 experiment nodes, 72 runs, 3 repeats per
  policy per graph. Self-reported, one company, arXiv preprint (Sep 2026).
- Reasoning: fair. Honest about null results ("no consistent gain") and about replay
  being conditioned on historically chosen branches; small repeat counts.
- Interests: vendor-internal system description.
- Weigh: trust the negative finding (fancy scheduling did not help) as a caution;
  discount production AUC gains (no independent check). Effect sizes in AUC (0.001
  target) are near-noise like ours.

## Findings

- [lab] Research is organised as four actions: Reproduce, Follow-up, Composition and
  Diagnose; Diagnose gathers evidence to choose a repair. Abstract ^f1
  > We organize this continuing research around four actions: Reproduce, Follow-up, Composition, and Diagnose.
- [lab] Split of work: human-designed rules pick the action type; the agent picks and
  designs the concrete experiment, or defers if evidence does not support one.
  Section 3.3 ^f2
  > We separate task-type allocation from concrete proposal construction
  > Human-designed rules allocate a research-action type. The Research Agent uses available evidence to construct and refine a concrete investigation or defer.
- [lab] Headline: when agents already analyse and select concrete candidates, more
  complex scheduling gave no consistent efficiency gain; fixed rotation plus agent
  selection remains a good baseline. Section 1 ^f3
  > Initial results suggest that, when agents already analyze candidate materials and prior experimental results to select concrete investigations, more complex adaptive or agent-based allocation does not consistently improve research efficiency.
- [lab] Policies compared: fixed routing, Thompson-sampling bandit routing, joint agent
  choice, uniform random, parent-result greedy; budget 20 selections. Section 4.5 ^f4
  > Bandit routing uses Thompson Sampling with a Beta(1, 1) prior, rewarding a strict new highest valid AUC among revealed results
  > Each replay run allows at most 20 experiment selections, with checkpoints at 5, 10, and 20.
- [lab] No policy led across environments; in one graph uniform random beat fixed,
  greedy and joint on mean best AUC. Section 4.5 ^f5
  > Final AUC rankings varied across replay environments, and no allocation policy consistently led across them (Table 10).
  > In Scenario A, Uniform Random’s mean exceeds Fixed, Greedy, and Joint.
- [lab] Agent selection cost ~430 minutes and 97.5M tokens for 36 runs; random and
  greedy needed no LLM calls and were competitive. Section 4.5 ^f6
  > Uniform Random and parent-result Greedy required no language-model calls. Their competitive results provide low-cost references for replay.
- [lab] An experiment's value includes the later experiments it unlocks (e.g.
  compositions), not just its own score. Section 4.5 ^f7
  > This contrast motivates evaluating an experiment not only by its recorded result, but also by the subsequent research opportunities it makes available.
- [lab] Diagnose runs were left out of the bandit comparison because their value of
  information does not show in immediate AUC. Section 4.5 ^f8
  > Diagnose is excluded because the value of information for a later repair is not captured by immediate AUC.
- [lab] Stalls: at 110 of 120 checkpoints a better result was still reachable within
  budget; a flat curve can mean a missed opportunity, not exhaustion. Section 4.5 ^f9
  > A flat search curve can therefore reflect either an unused opportunity or the limit of the recorded pool.
- [lab] Giving the selector compressed summaries of past experiments on top of raw
  code and scores did not consistently help. Section 4.5 ^f10
  > Across both batches, summaries do not consistently improve best AUC or reach the same result sooner.
- [lab] Checked, not there: no explicit numeric value or cost estimate per candidate in
  the selection policies read; cost is counted only as one selection each. ^f11
  > Each selection counts once against the experiment budget
- [lab] (inferred) For meiolol: don't build an elaborate scheduler; a fixed rotation of
  action types (diagnose, follow-up, new idea, combine) with the LLM choosing within
  each, plus a random/greedy baseline to check the LLM earns its tokens. ^f12

## Read

- Abstract, section 1 summary, 3.3, 4.5 (routing comparison, stalls, decision cost,
  summaries)

## Not read

- Sections 2, 3.1-3.2 (investigation loop, research state), 4.1-4.4 production
  results, case studies, appendices
