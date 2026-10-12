---
title: 'dota2-predictor (andreiapostoae): README, preprocessing/dataset.py'
url: https://github.com/andreiapostoae/dota2-predictor
kind: project
commit: 173c230196cd67b71573b71382beec2c42d87955
for: [draft-predictor-methods]
looked: 2026-10-12
depth: code (README.md, preprocessing/dataset.py)
relevance: medium
grade: C/fair
description: Hobby Dota 2 draft-only predictor and last-pick suggester (2017, 371 stars, MIT, behind dotadamus.com); LR on one-hot picks plus pair win-rate features, per-MMR-bracket models
---
# dota2-predictor (andreiapostoae): README, preprocessing/dataset.py

Why: a public, practitioner draft-only predictor for ranked Dota 2 with numbers by MMR
and a learning-curve plateau, i.e. the closest Dota analogue to what we build.

## Assessment

- Evidence: C. One author, 371 stars, 83 forks, last push Dec 2022; served a public
  site. Numbers from one README run, no intervals.
- Reasoning: fair. Honest FAQ (NNs no better than LR, 60% is the best found).
- Interests: none (non-commercial).
- Weigh: the ROC AUC of about 0.63-0.65 for ranked All Pick is a realistic ranked
  draft-only figure; the default pipeline may leak via whole-dataset pair win rates.

## Findings

- [data] Data: ranked and normal All Pick games mined from the Steam API, with the
  average public MMR per game, filtered into MMR brackets with one model each.
  `README.md` ^f1
  > game_mode: 22 - All Pick
  > avg_mmr: average MMR of people with public MMR in the game
- [method] Features: one-hot heroes per side plus three advantage features from a
  synergy matrix (pair win rate as teammates) and a counter matrix (pair win rate as
  opponents); model is logistic regression. `README.md`, `preprocessing/dataset.py` ^f2
  > The algorithm used for training is Logistic Regression and the evaluation is done through cross validation.
  > x_matrix[i, -3:] = augment_with_advantages(synergy_matrix,
- [method] Headline: about 0.65 ROC AUC with LR or neural nets; example run at 4500+
  MMR: 112,057 train games, 8,390 test, test AUC 0.628, accuracy 59.2%. `README.md` ^f3
  > The project achieves roughly 0.65 ROC AUC score using Logistic Regression and Neural Networks.
  > INFO:training.cross_validation:Test ROC AUC: 0.628
  > INFO:training.cross_validation:Test accuracy score: 0.592
- [method] Neural networks matched LR at best, after much tuning. `README.md` FAQ ^f4
  > Even with a lot of tuning, the NNs acted at best as good as the Logistic Regression
- [method] Learning curve plateaus after about 200k games; author suggests at least
  150k. `README.md` FAQ ^f5
  > Experimentally, I'd say at least 150k. If you analyze the learning rates, you can see the plateau after 200k.
- [method] (inferred) Possible leakage: by default the synergy and counter matrices
  are loaded from `pretrained/synergies_all.csv` and `counters_all.csv` (named "all")
  for both train and test sets, so pair win rates likely include the test games'
  outcomes. `preprocessing/dataset.py` ^f6
  > synergies = np.loadtxt('pretrained/synergies_all.csv')
- [data] (claim) Pro games are a different population: pubs are MMR-balanced, pro
  data would be noise to a pub model. `README.md` FAQ ^f7
  > The pro scene is totally different than pubs because in pubs there is some MMR balance

## Read

- `README.md` (all), `preprocessing/dataset.py`

## Not read

- `training/cross_validation.py` (split details), `preprocessing/advantages.py`,
  learning-curve image (imgur)
