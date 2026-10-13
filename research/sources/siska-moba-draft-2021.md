---
title: Drafting in MOBA Games using Machine Learning (Siska, CTU bachelor thesis, 2021)
url: https://dspace.cvut.cz/bitstreams/4e75e054-a13e-49b4-a28b-28d8a819418d/download
kind: paper
commit:
for: [nn-draft-models]
looked: 2026-10-13
depth: docs (data, model, hyperparameter search, test results; Czech)
relevance: medium
grade: C/fair
description: Czech bachelor thesis; champion embedding NN for LoL draft-only win prediction on 60k high-elo games of one patch, chronological split, 864-config grid search
---
# Drafting in MOBA Games using Machine Learning (Siska, CTU bachelor thesis, 2021)

Why: one of the few LoL neural draft predictors with a chronological split and a
published hyperparameter grid; what did the search pick at small data?

## Assessment

- Evidence: C. Bachelor thesis, Kaggle data (60k games, patch 10.16, EUW, NA, KR,
  top 0.1%), one run per config, accuracy only, no LR baseline of its own.
- Reasoning: fair. Chronological split, validation set for selection, separate test;
  discusses why validation and test differ. No log loss, no intervals.
- Interests: none (student).
- Weigh: the selected configuration is the useful part: at 35k training games the grid
  chose a 2-dim champion embedding with no hidden layer, i.e. an almost linear model.

## Findings

- [data] [stats] 60k high-elo games, all on patch 10.16, sorted by time: first 35k train, next 10k validation, last 15k test. Section 4 ^f1
  > nejprve jsme data všech zápasů chronologicky seřadili. Následně jsme data rozdělili na trénovací množinu (prvních 35 tisíc zápasů), validační množinu (následujících 10 tisíc zápasů) a testovací množinu (zbývajících 15 tisíc zápasů)
- [method] Grid of 864 configs: embedding dim 1-6, tanh or sigmoid, 0-3 hidden layers of 10, 20 or 30 units, SGD or Adam, learning rate 0.1 to 1e-5; shuffling each epoch, early stopping, and learning-rate reduction when training loss plateaus. Section 5.3-5.4, Table 5.1 ^f2
  > Dále jsme implementovali early stopping, který dokáže při trénování rozeznat overfitting a zastavit tak učení včas.
  > Počet kombinací hyperparametrů je 864
- [method] Mean validation accuracy rose with embedding dim up to 4 then flattened; more hidden layers slowly lowered it; ReLU did badly; Adam far better than SGD. Section 5.4 ^f3
  > Průměrná přesnost s vyšším počtem skrytých vrstev pomalu klesá
- [method] Best champion-only model on validation (Table 7.1): embedding dim 2, sigmoid, 0 hidden layers, Adam, learning rate 1e-5, 53.94% validation; with player features (Table 7.2): dim 1, tanh, 2 hidden layers of 20, 54.49%. (Table read from the layout text; plain text splits its cells.) ^f4
  > Nejlepším optimalizátorem se u obou modelů stal Adam s learning rate 1e-5.
- [method] [stats] Test (last 15k games): champion-only 54.06%, with player features 53.45%, below its validation score; the author suspects overfitting from the extra features or drift over time. Section 7.3 ^f5
  > Nejprve na testovací množině vyhodnotíme champ_model, který dosáhl přesnosti 54,06 %
  > Tento feat_model dosáhl přesnosti 53.45 %, což je o více než jedno procento méně oproti výsledkům na validační množině.
- [method] Checked, not there: no logistic regression or other baseline trained on the same split, only the 50.43% blue-side prior. ^f6
- [method] (inferred) At 35k training games the search collapsed to a near-linear model (2-dim embedding, no hidden layer), and the richer player-feature net lost 1 point from validation to test; consistent with nets adding nothing over LR at this size. ^f7

## Read

- Abstract, sections 4 (data), 5 (models, training, hyperparameter search), 7.2-7.3
  (results); Czech, read directly

## Not read

- Section 6 (draft assistant search tree), related work survey, figures 5.1-5.2 and
  7.1-7.2 (per-hyperparameter accuracy plots)
