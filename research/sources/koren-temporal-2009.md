---
title: 'Koren 2009: Collaborative Filtering with Temporal Dynamics'
url: https://faculty.cc.gatech.edu/~zha/CSE8801/CF/kdd-fp074-koren.pdf
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 3 concept drift approaches, 4.1-4.2 time-changing baselines)
relevance: high
grade: A/strong
description: KDD 2009 best paper (Yahoo, Netflix Prize winner): time windows and exponential decay lost signal; time-binned item biases b_i + b_i,Bin(t) on top of stationary terms worked
---
# Koren 2009: Collaborative Filtering with Temporal Dynamics

Why: patch drift in champion strength looks like Netflix's time-changing item
biases; what worked there for using old data without being misled by it.

## Assessment

- Evidence: A. KDD 2009 best research paper; part of the Netflix Prize winning
  solution; 100M ratings.
- Reasoning: strong. Reports the negative result for decay weighting, explains why,
  and builds the alternative with ablations by RMSE.
- Interests: author's own approach.
- Weigh: trust the negative decay result for sparse per-entity data and the binned
  bias form; ratings are not win/loss, so tune the bin and shrinkage ourselves.

## Findings

- [method] [stats] Many delicate shifts happen at once, each with few instances; time
  windows and instance decay lose too much signal by discarding data. Abstract ^f1
  > Classical time-window or instancedecay approaches cannot work, as they lose too much signal when discarding data instances.
- [method] [stats] Measured: across exponential decay rates on two model families,
  quality improved as decay was moderated, best with no decay at all. Section 3 ^f2
  > The consistent finding was that prediction quality improves as we moderate that time decay, reaching best quality when there is no decay at all.
- [method] [stats] Why: old data still carries persistent and cross-entity patterns,
  so down-weighting it loses signal with the noise when data per entity is scarce.
  Section 3 ^f3
  > Thus, just underweighting past actions loses too much signal along with the lost noise, which is detrimental given the scarcity of data per user.
- [method] What worked: split each item's bias into a stationary part plus a
  per-time-bin offset (30 bins of ~10 weeks), all L2-regularised; bin size balances
  resolution against data per bin, and many sizes gave similar accuracy. Section 4.1 ^f4
  > The decision of how to split the timeline into bins should balance the desire to achieve finer resolution (hence, smaller bins) with the need to have enough ratings per bin (hence, larger bins).
  > For the movie rating data, there is a wide variety of bin sizes that yield about the same accuracy.
- [method] Time-binned item effects gave a small gain (RMSE 0.9799 to 0.9771); user
  drift mattered more. Section 4.2 ^f5
  > while temporal movie effects reside in the data (lowering RMSE from 0.9799 to 0.9771), the drift in user biases is much more influential.
- [method] (inferred) Direct analogue for us: champion rating = stationary term +
  per-patch offset (bin = patch, a known change point) with its own, stronger L2, all
  games kept at full weight. Champions untouched by a patch keep near-zero offsets. ^f6

## Read

- Abstract, 1, 3 (tracking drift), 4.1-4.2 (time-changing baseline predictors)

## Not read

- 5 temporal factor model (SVD++ with time), 6 neighbourhood model
