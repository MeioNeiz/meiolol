---
title: 'Kim, Lee, Chung 2020: A confidence-calibrated MOBA game winner predictor (LoL)'
url: https://arxiv.org/pdf/2006.15521
kind: paper
commit: 
for: [live-win-probability]
looked: 2026-10-13
depth: docs (whole paper)
relevance: medium
grade: C/fair
description: Hanyang University IEEE CoG 2020 short paper; MLP on LoL per-minute state plus champions (top 0.01% players, 94k matches), compares temperature, vector, matrix scaling and a data-uncertainty loss on ECE, MCE, NLL
---
# Kim, Lee, Chung 2020: A confidence-calibrated MOBA game winner predictor (LoL)

Why: the one LoL in-game paper that measures calibration (ECE, reliability diagram),
with a draft (champion composition) input.

## Assessment

- Evidence: C. Four-page conference short paper; one dataset (top 0.01% players),
  one MLP, one run, no intervals; calibration pooled over all minutes.
- Reasoning: fair. Clear metric definitions; method gain over temperature scaling is
  small in NLL (0.515 vs 0.505, worse) and only ECE favours it.
- Interests: proposing their own loss.
- Weigh: useful for the baseline numbers (an MLP on state plus champions is
  miscalibrated out of the box, temperature scaling fixes most of it); the proposed
  loss is not shown to matter where it counts (NLL).

## Findings

- [data] Data: 83,875 train and 10,000 test matches of top 0.01% players, per-minute
  in-game data; split by match. Section IV ^f1
  > we collected information on 83875 matches as the train data and that on 10000 matches as the test data.
  > All matches were played between the top 0.01% players.
- [method] Input: 295 features of game time, champion composition, gold and XP
  difference and kills so far, into a 295-256-256-2 MLP. Section IV ^f2
  > it consists of in-game time, champion composition, gold and experience difference and numbers of kills so far.
- [method] Argues accuracy is the wrong target for a winner predictor; the output must
  be a calibrated probability. Section I ^f3
  > we claim that focusing on achieving accuracy may not be adequate for the eSports winner prediction; instead, the predictor should be able to calculate the actual winning probability.
- [method] [stats] Unlike images, LoL confidences spread evenly over the range, so under-
  as well as over-confidence matters. Section I ^f4
  > Owing to this characteristic, not only overconfidence but also underconfidence should become a concern.
- [stats] Uncalibrated MLP: 72.95% accuracy, ECE 4.47%, NLL 0.515; temperature scaling
  ECE 1.11%, NLL 0.505 (best NLL); their data-uncertainty loss ECE 0.57%, NLL 0.515,
  accuracy 73.81%. Table I ^f5
  > Temperature scaling scores 1.11% ECE that is the best score among Platt scaling methods. Furthermore, Temperature scaling achieves the best NLL value with 0.505.
  > The proposed method achieves 0.57% ECE and 1.26% MCE values, both of them are the best among all compared methods.
- [stats] ECE with 10 equal-width confidence bins; reliability diagram pooled over all
  minutes. Section IV ^f6
  > The size of all M bins is set to uniformly 10.
- [stats] Checked, not there: no accuracy or calibration by minute, no non-neural
  baseline, no comparison with the same features without champions. ^f7
- [method] (inferred) A pooled ECE near 1% can hide large errors in the early-minute
  band, where most rows sit near 50%; we should report ECE and log loss per minute band,
  and fit a temperature (or isotonic) on a held-out game set, per band if needed. ^f8

## Read

- Whole paper (4 pages)
