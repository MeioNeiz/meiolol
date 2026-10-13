---
title: 'Rugby-Bot (STATS LLC, 2019): multi-task learning and fine-grained features for rugby league'
url: https://arxiv.org/pdf/1910.07410
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: docs (sections 3.1-3.2)
relevance: low
grade: C/fair
description: STATS LLC (Lucey group) 2019 arXiv preprint; one wide-and-deep net with a mixture density output jointly predicting win probability, final scoreline, try and metres per tackle on 750 NRL games; no single-task ablation
---
# Rugby-Bot (STATS LLC, 2019): multi-task learning and fine-grained features for rugby league

Why: a sports model that predicts win alongside score and in-game targets from one
net; does it measure what the auxiliary targets add, and how does it weight losses?

## Assessment

- Evidence: C. Industry preprint (STATS, Lucey), production motivation; one test loss
  number, random 80/20 split of tackles, no ablations.
- Reasoning: fair. Clear argument for one joint likelihood over hand-weighted losses;
  no evidence that multi-tasking improved win probability.
- Interests: vendor's own product.
- Weigh: borrow the loss-weighting idea (joint likelihood) at most; no effect size.

## Findings

- [method] Targets predicted together: play selection, metres and try per tackle, try
  per set, win probability and final scoreline. Section 3 ^f1
  > Win Probability [yw ]: likelihood of winning the game
  > Scoreline Prediction [ys ]: predicted final score of each team
- [method] Motivation is consistency and maintenance, not accuracy: separate specialist
  models fail to share structure. Section 3 ^f2
  > Simply constructing a model “or specialist” for each task leaves much to be desired: it fails to share information and structure that is common across tasks
- [method] Loss weighting problem solved by a mixture density output: one negative log
  likelihood over the whole state vector instead of hand-set weights for regression and
  classification losses. Section 3.2.2 ^f3
  > Therefore, we have a single loss for our prediction: the negative log-likelihood that a game-state is observed given the current game-state.
  > how should 1m error in the predicted meters gained be waited against 1pt error in the final scoreline?
- [method] [data] Data: 2015-2018 NRL, over 750 games and 250,000 tackles, random 80/20
  split. Section 3.1 ^f4
  > Rugby-Bot is built on data from the 2015-2018 National Rugby League seasons which includes over 750 games and more than 250,000 distinct tackles
- [method] Checked, not there: no single-task win model to compare against, so no
  measure of whether the auxiliary heads helped win prediction. ^f5

## Read

- Abstract, 1, 3.1-3.2 (data, wide and deep, MDN)

## Not read

- Section 4 onwards (DVOA analysis, case studies)
