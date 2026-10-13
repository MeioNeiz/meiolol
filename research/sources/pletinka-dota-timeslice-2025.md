---
title: 'Pletinka 2025: Time-slice win probability prediction in Dota 2 (UCU bachelor thesis)'
url: https://er.ucu.edu.ua/bitstreams/6ab1188c-9298-4ca2-850b-8b75c1aa7d75/download
kind: paper
commit: 
for: [live-win-probability]
looked: 2026-10-13
depth: docs (sections 3-6)
relevance: low
grade: D/weak
description: Ukrainian Catholic University 2025 bachelor thesis; Transformer encoder pretrained on next-slice prediction over 30-second Dota 2 pro snapshots, frozen, then an MLP head for win probability; temperature chosen by eye
---
# Pletinka 2025: Time-slice win probability prediction in Dota 2 (UCU bachelor thesis)

Why: the one transformer-over-frames win probability model found (self-supervised
pretraining on next-frame prediction), to see if it shows sequence models winning.

## Assessment

- Evidence: D. Bachelor thesis; 11k pro games of one patch; no baseline (no GBDT or
  per-frame model), no per-minute accuracy, no log loss or ECE.
- Reasoning: weak. The outcome head is trained and scored on each game's last window,
  where the winner is nearly decided; temperature picked so curves looked right.
- Interests: none.
- Weigh: shows the shape of a pretrain-then-head design and its pitfalls; no evidence
  that it beats a frame model.

## Findings

- [data] Data: 12,000 pro games of patch 7.37 from OpenDota; games under 20 or over 60
  minutes dropped, 11,267 parsed replays at 30-second resolution. Sections 3.1, 3.5 ^f1
  > The collected dataset contains 12000 pro league matches played on the 7.37 version of the game.
  > leaving 11267 parsed replays prepared for model training.
- [method] Design: Transformer over a 20-slice (10-minute) window, pretrained to
  predict the next slice (MSE), then frozen; an MLP head maps the embeddings to win
  probability. Section 4.1 ^f2
  > Pretraining: The Transformer is trained on the next token prediction task using unlabeled sequences of size c.
  > Fine-tuning: The MLP is trained on labeled match outcomes, given the last window of size c of the match
- [method] The head is trained on each game's last window; the reported 99% accuracy
  is on those end-of-game windows, so it says nothing about mid-game. Section 5.1.2 ^f3
  > For the outcome prediction given the last 20 slices of the game, the trained model achieves 99% accuracy on both training and validation sets
- [stats] Outputs were overconfident; temperature was set by a manual grid over T in
  2-4 to make curves look intuitive (T = 2.5), not by validation log loss. Section 5.2 ^f4
  > a manual grid search was performed over T ∈ [2, 4] with a step of 0.5 to select the value that produced probability curves that best matched intuitive expectations.
- [method] No prediction before minute 10 (window must fill); the author proposes a
  draft-based starter model until then. Section 6.2 ^f5
  > Introducing a simple startup predictor that would generate probabilities based on heroes’ draft and landing statistics
- [method] (inferred) Training a win head on end-of-game states only teaches it the
  easy cases; the head must see frames from every minute, weighted so each game counts
  once, and be scored per minute. ^f6

## Read

- Sections 3 (data), 4.1 (pipeline), 5 (training, calibration), 6 (conclusions)

## Not read

- Section 4.2 transformer details, case studies in 5.3
