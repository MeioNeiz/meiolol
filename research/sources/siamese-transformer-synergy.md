---
title: 'Ye et al. 2026: Learning Team Synergy from Team Composition with a Siamese Transformer'
url: https://journals.flvc.org/FLAIRS/article/download/141762/147195
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: docs (whole paper, 4 pages)
relevance: medium
grade: C/weak
description: FLAIRS-39 (2026) short paper; shared-weight transformer per team, team vectors differenced, vs MLP and a joint 10-token transformer on NBA, LoL pro (76k), LoL ranked (156k), Valorant
---
# Ye et al. 2026: Learning Team Synergy from Team Composition with a Siamese Transformer

Why: does attention over a team's roster, with a shared (Siamese) team encoder compared
by difference, beat plain nets on draft-only win prediction, and at what sizes?

## Assessment

- Evidence: C. Short conference paper, small Berry College group; Kaggle LoL data (2014
  ranked, Oracle's Elixir pro), 10-fold random CV, no linear or logistic baseline, no
  log loss, no seed spread. Code on GitHub (Heuzi/Team-Synergy-Transformer, not read).
- Reasoning: weak. Explains the Siamese inductive bias well; accuracy gaps of 1-3 points
  on LoL are within what random folds and checkpoint choice could give; the auxiliary
  branch uses post-game stats (gold earned, kills) so its 95% is leakage.
- Interests: authors' own model.
- Weigh: trust the direction (shared team encoder beats a joint encoder that mixes both
  teams' tokens); discount every LoL number; nothing here beats a ratings baseline.

## Findings

- [method] Architecture: shared embedding per character, row-wise l2 normalised, one
  transformer encoder over one team's tokens with no positional encoding, mean pool,
  sigmoid linear head to a team descriptor; the two descriptors are differenced. ^f1
  > A transformer encoder models within-team interactions through self-attention. It omits positional encoding because team composition is order-invariant.
  > The composition branch then contrasts the two teams by a coordinate-wise difference, followed by a sigmoid
- [method] Sizes: 8-dim embeddings, a single encoder layer with 2 heads and FFN 64;
  Adam lr 1e-5, BCE, early stop after 40 epochs without improvement, best validation
  checkpoint. Bigger did not help. ^f2
  > All models employ an embedding layer that maps each character to an 8-dimensional embedding vector (de = 8). All transformer-based architectures use a single TransformerEncoder layer with two attention heads and a feed-forward dimension of 64.
  > increasing model complexity did not yield additional performance gains
- [method] [data] Data: NBA 10,360 games; LoL Pro 76,318 (168 champions); LoL Amateur
  156,348 (136 champions, Kaggle ranked games from 2014); Valorant 12,473; split 10-fold
  random CV 80/10/10, not time. Table 1 and Evaluation ^f3
  > All datasets are evaluated using 10-fold cross-validation with 80%/10%/10% train/validation/test splits.
- [method] Draft-only accuracy, LoL Pro: MLP 52.0, Siamese MLP 52.5, joint transformer
  50.4, Siamese transformer 53.7. LoL Amateur: 51.0, 53.2, 50.1, 54.2. NBA: 56.1, 62.3,
  49.0, 63.3. No logistic baseline, no log loss. Table 2 (layout interleaved, no clean
  quote) ^f4
- [method] Siamese (shared team encoder) beat the non-Siamese version in both MLP and
  transformer form; the joint 10-token transformer stayed near chance. ^f5
  > In contrast, the non-Siamese transformer performs worst and remains near chance across datasets despite having comparable capacity and a similar transformer backbone.
- [method] (inferred) The head is w'sigmoid(s1 - s2) + b: swapping teams flips the
  difference, but with a free bias it is only antisymmetric if b = -sum(w)/2, so side
  symmetry is approximate, not built in. ^f6
- [method] [data] Checked, not there: no comparison with logistic regression or champion
  win rates; the "+ aux info" rows (LoL Amateur 94.9%) use in-game stats such as gold
  earned and wards bought, i.e. outcome leakage, not pre-game information. ^f7
  > The amateur dataset also includes auxiliary hero information such as role position, gold earned, and wards bought.
- [method] (inferred) At 76k-156k LoL games the Siamese transformer's lift over a
  Siamese MLP is about 1 accuracy point on random folds; with our ratings already at
  53-54% on a time split, attention alone is unlikely to add much without a ratings
  baseline underneath. ^f8

## Read

- Whole paper (abstract, data, model, methods, Table 2, discussion)

## Not read

- Code on GitHub (Heuzi/Team-Synergy-Transformer): exact training script, seeds
