---
title: 'Ibrahim et al. 2024: Simple and Scalable Strategies to Continually Pre-train Large Language Models'
url: https://arxiv.org/pdf/2403.08763
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: listed (abstract, 1, 4.2, 6.1-6.4 summaries, limitations)
relevance: medium
grade: B/fair
description: Ibrahim, Thérien, Gupta et al. (Mila, Concordia, EleutherAI; TMLR 2024); continuing an LLM on new data with LR re-warm and re-decay plus a few percent replay of old data matches retraining from scratch on the union, at a fraction of the compute
---
# Ibrahim et al. 2024: Continually Pre-train LLMs (replay vs refit on the union)

Why: the direct comparison we need: continue from the old model (with or without
replay) against a fresh fit on pooled old plus new data.

## Assessment

- Evidence: B. TMLR 2024, 405M and 10B decoder transformers, 200-300B new tokens,
  a weak (English to English) and a strong (English to German) shift; later used by
  DeepSeek-V2 and Zamba continual pretraining (their section 1). Single seed per
  config (stated limitation).
- Reasoning: fair. Clear baselines (union-trained from scratch), compute-matched
  replay; scale is the opposite of ours (huge new data, LLM loss), and their goal is
  both old and new data, ours newest patch only.
- Interests: none known.
- Weigh: trust the qualitative pattern (no replay adapts best to new data but
  forgets old; small replay fixes forgetting at little cost to adaptation; the
  learning rate must be raised again to adapt at all). Their new set is large, ours
  is small, so the "continued model wins on new data" result may not carry over.

## Findings

- [method/dynamics] Learning-rate re-warming and re-decaying plus replay matched a
  full retrain from scratch on all data, by final loss and benchmark average, at
  both a weak and a strong shift, and at 10B. Abstract ^f1
  > a simple and scalable combination of learning rate (LR) re-warming, LR re-decaying, and replay of previous data is sufficient to match the performance of fully re-training from scratch on all available data
- [method/dynamics] Without replay, continued models adapted better to the new data
  than the union-trained model but forgot much of the old. Section 6.1 ^f2
  > comparing models continually pre-trained with re-warming and re-decaying to the union baseline, we note that these models adapt better (lower final validation loss) to D1 than the union baseline
  > these models experience significant forgetting on D0 , showing the need for replay to make these models competitive with the union baseline
- [method/dynamics] Continuing at the small final learning rate forgets least but
  adapts least; re-warming is needed to adapt, and a stronger shift means more of
  both forgetting and adaptation. Section 6.1 ^f3
  > re-warming and re-decaying are necessary to maximize adaptation to the new dataset when continually pre-training LLMs
  > a stronger distribution shift between D0 and D1 exacerbates forgetting and enhances adaptation
- [method/dynamics] Even 1% replay cut forgetting a lot; 1-10% replay cost little
  new-data loss; 50% replay adapted clearly worse to the new data. Stronger shift
  needed more replay (25% for German, 5% for English). Section 6.2, Figure 1 ^f4
  > even the lowest tested replay of 1% significantly reduces forgetting on Pile compared to the no-replay baselines
  > when using an extreme amount of replay (50%), we observe that the model adapts relatively significantly worse to D1
  > the stronger shift requires more replay to mitigate forgetting to the same extent
- [method/dynamics] Replay is compute-equivalent: replayed old examples take the
  place of new ones in each batch, so x% replay means x% of each batch from old
  data. Section 4.2 ^f5
  > x is the percentage of data in each training batch that comes from D0
- [method/dynamics] Their advice: try replay fractions on a short budget, since the
  differences show early, and pick by your own evaluations. Section 1 ^f6
  > We recommend experimenting with different replay fractions since relative differences between them appear very early during training.
- [method/dynamics] Limits: two model sizes, two datasets per run (not a long
  sequence of shifts), no seed variation. Limitations ^f7
  > we only studied two model sizes (405M and 10B)
- [method/dynamics] (inferred) For us: if only newest-patch loss matters, the
  no-replay continued model is the one that wins on new data in their runs, but
  only because the new set was huge; with a few thousand new-patch games, replay is
  what stops the net forgetting champion pairs and comps the new patch hasn't shown
  yet. Sweep replay share (5-50%) with the old games in each batch, against a pooled
  fresh refit, all scored on held-out newest-patch games. ^f8

## Read

- Abstract, 1 (contributions, rules of thumb), 4.2, 6.1-6.4 summaries, limitations

## Not read

- 6.3 benchmark tables, 7 infinite learning-rate schedules, appendices
