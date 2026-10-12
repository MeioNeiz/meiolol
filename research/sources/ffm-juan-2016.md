---
title: 'Juan et al. 2016: Field-aware Factorization Machines for CTR Prediction'
url: https://www.csie.ntu.edu.tw/~cjlin/papers/ffm.pdf
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, sections 1-2, 4.2-4.6, 5)
relevance: high
grade: A/strong
description: RecSys 2016 paper (Criteo, NTU, LIBFFM authors) on field-aware FMs, which won the Criteo and Avazu CTR competitions; compares LM, Poly2, FM, FFM on logloss and time
---
# Juan et al. 2016: Field-aware Factorization Machines

Why: whether field-aware FMs (one latent vector per champion per opposing field, e.g.
ally vs enemy slot) beat plain FMs and logistic models on sparse categorical data.

## Assessment

- Evidence: A. Won two Kaggle CTR competitions (Criteo 45.8M rows, Avazu); Chih-Jen
  Lin (LIBLINEAR, LIBSVM); LIBFFM widely used.
- Reasoning: strong. Same SG implementation for all models, grid-searched parameters,
  reports time, negative results (phishing, adult, numerical data) and early-stopping
  difficulties.
- Interests: authors' own method and package.
- Weigh: trust the guideline on when FFM helps; gains are on huge CTR sets, so the
  size at which they appear for us is open.

## Findings

- [method] FMs beat Poly2 (free pair weights) on sparse data because each feature's
  vector is learned from all its other pairs, so rare or unseen pairs still get
  sensible predictions. Section 2 ^f1
  > For FMs, because the prediction of (ESPN, Adidas) is determined by wESPN · wAdidas , and because wESPN and wAdidas are also learned from other pairs
- [method] Accuracy vs speed trade-off: FFM best logloss, LM fastest but worst, FM a
  good balance; on Criteo (45.8M rows) private logloss LM 0.462, Poly2 and FM about
  0.449, FFM 0.446 (Table 3, no verbatim quote). Section 4.5 ^f2
  > Clearly, FFMs outperform other models in terms of logloss, but it also requires longer training time than LMs and FMs.
  > FM is a good balance between logloss and speed.
- [method] When FFM helps: most features categorical and the one-hot set highly sparse;
  not when data is dense or interactions don't matter (adult: all models matched the
  linear one). Section 4.6 ^f3
  > FFMs should be effective for data sets that contain categorical features and are transformed to binary features.
  > for adult, it seems feature conjunction is not useful because all models perform similarly to the linear model.
- [method] FFMs overfit easily and logloss is sensitive to the number of epochs; they
  use validation early stopping, which worked better than other tricks they tried.
  Section 4.3 ^f4
  > A difficulty in applying early stopping is that the logloss is sensitive to the number of epochs.
  > However, results are not as successful as that by early stopping of using a validation set.
- [method] Model size is O(n f k), n features times f fields times k; latent sizes
  used were small (k = 4 for FFM vs 40-100 for FM in Table 3). Section 3.3 ^f5
  > Recall that the model size of FFMs is O(nf k).
- [method] (inferred) A draft has natural fields (ally role slots, enemy role slots);
  FFM would let a champion's synergy vector differ from its counter vector. With 170
  champions, 10 fields and k = 4, that is ~7k parameters, cheap at 10^5 games. ^f6

## Read

- Abstract, 1, 2 (Poly2, FM), 3.3 fields, 4.2-4.3 early stopping, 4.5-4.6, guideline

## Not read

- 3.1-3.2 optimisation and parallelism, 4.4 parallel speedup details
