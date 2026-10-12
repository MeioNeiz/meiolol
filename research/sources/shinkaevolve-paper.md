---
title: ShinkaEvolve paper abstract (arXiv 2509.19349)
url: https://arxiv.org/abs/2509.19349
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: skimmed (abstract only)
relevance: medium
grade: C/fair
origin: shinkaevolve
description: Abstract of the ShinkaEvolve paper (Sakana AI, Sept 2025); claims sample efficiency from parent sampling, novelty rejection and bandit model choice
---
# ShinkaEvolve paper abstract (arXiv 2509.19349)

Why: the sample-efficiency claim behind ShinkaEvolve's design, relevant to our budget of
a few hundred runs.

## Assessment

- Evidence: C. Abstract only; claims, not checked against the paper's ablations.
- Reasoning: fair (abstract level).
- Interests: authors' own framework.
- Weigh: read the ablations before relying on "150 samples"; the task (circle packing)
  has an exact, noiseless score.

## Findings

- [lab] (claim) Names three ideas for sample efficiency: parent sampling balancing
  exploration and exploitation, code novelty rejection sampling, bandit choice of LLM.
  `abstract` ^f1
  > introducing three key innovations: a parent sampling technique balancing exploration and exploitation, code novelty rejection-sampling for efficient search space exploration, and a bandit-based LLM ensemble selection strategy.
- [lab] (claim) Frames prior code evolution as needing thousands of samples, and reports
  a state-of-the-art circle packing in 150. `abstract` ^f2
  > they are sample inefficient, requiring thousands of samples to identify effective solutions
  > ShinkaEvolve discovers a new state-of-the-art circle packing solution using only 150 samples

## Read

- Abstract page.

## Not read

- Paper body: ablations per component, cost per run, MoE load-balancing loss task (the
  closest to ML modelling).
