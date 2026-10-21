---
title: 'FIFA World Cup 2026 as a Contamination-Free Benchmark for LLM Forecasting Agents: Four Models, a Bookmaker, and 104 Matches'
url: https://arxiv.org/pdf/2607.17765
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: docs (abstract, 1, 4.1, 5, 6.1-6.2)
relevance: medium
grade: C/fair
description: Ding, Guo, Xu (Memphis, 2026); four frontier LLM agents with web search forecast all 104 World Cup 2026 matches after their training cutoffs, scored on Brier and log loss against the betting market
---
# FIFA World Cup 2026 as a Contamination-Free Benchmark for LLM Forecasting Agents

Why: a clean test of LLMs as direct outcome predictors (no contamination, a strong
baseline), the "LLM as predictor" end of our question.

## Assessment

- Evidence: C. 104 matches, so differences of a few thousandths in Brier are noise;
  frontier models of mid 2026; data and code public.
- Reasoning: fair. Says plainly that agents re-express the market price.
- Interests: one author from a forecasting company (QuantaInsight).
- Weigh: trust the qualitative result (LLMs track the available price and don't beat
  it); the numbers can't rank models.

## Findings

- [method/pretrain] Setting: Claude Opus 4.8, GPT-5.5, Gemini 3.1 Pro and Grok ran a
  web search loop and gave 1X2 probabilities for every match, all after their training
  cutoffs; the betting market is the baseline. Abstract ^f1
  > Because every match kicked off after the models’ training cutoffs, the benchmark is contaminationfree by construction.
- [method/pretrain] None beat the market's Brier score (market 0.469, best agent 0.471);
  log loss 0.803-0.820 for agents vs 0.807 for the market. 6.2, Table 2 ^f2
  > Scored as a forecaster, the market attains the best Brier score of all five competitors (0.469 vs. 0.471 for the best agent)
- [method/pretrain] The agents mostly restate the market: each agent's probability
  correlates 0.97-0.99 with the market's, and their top picks agree in 92% of matches. 6.1 ^f3
  > each agent’s team-A probability tracks the market’s almost perfectly (𝑟 = 0.97–0.99), so the agents are, to first order, reading and lightly re-expressing the same price.
- [method/pretrain] Where agents disagreed, it was on near coin flips, not where one
  had found private information. 6.1 ^f4
  > Disagreement thus appears exactly where the signal is weakest, not where an agent has found private information.
- [method/pretrain] (inferred) For us: an LLM asked about a League draft would mostly
  restate public win-rate sites (the same counts we have, with less data and no
  time split), so an LLM as a direct predictor is a test of its sources, not a new
  signal; any use should be a frozen feature fitted on our games. ^f5

## Read

- Abstract, 1, 4.1, Table 2, 6.1-6.2

## Not read

- Betting (T2) and reflection sections; dataset construction
