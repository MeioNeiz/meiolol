---
title: 'Wüthrich and Merz 2019: Editorial: Yes, we CANN!'
url: https://www.cambridge.org/core/services/aop-cambridge-core/content/view/66E8BEC373B5CCEF3BF3303D442D6B75/S0515036118000429a.pdf/editorial-yes-we-cann.pdf
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: listed (whole 3-page editorial)
relevance: high
grade: A/fair
description: ASTIN Bulletin 2019 editorial defining the Combined Actuarial Neural Net (CANN): a GLM as skip connection, net output layer initialised at zero, so training starts at the GLM and boosts it
---
# Wüthrich and Merz 2019: Editorial: Yes, we CANN!

Why: our plan is a net fitted as a residual on top of logistic champion ratings; this
is the canonical recipe for exactly that (GLM offset plus net correction).

## Assessment

- Evidence: A as the canonical reference (Wüthrich is a leading actuarial ML author;
  CANN is the standard term, used by later benchmarks such as
  [[insurance-nn-benchmark-2023]]). The editorial itself is a toy illustration, no
  experiments.
- Reasoning: fair. Clear recipe and when to drop it; no numbers.
- Interests: none known.
- Weigh: trust the construction and initialisation; whether it helps must be measured.

## Findings

- [method] CANN: the GLM linear predictor enters the net's output as a skip connection,
  so the net only adds structure on top of the GLM. p. 2 ^f1
  > In machine learning jargon, this is called adding a skip connection to the feed-forward neural net μNN . This skip connection exactly contains the classical actuarial regression function log (μGLM ).
- [method] Key trick: start gradient descent at the GLM MLE with the net's output
  weights and bias set to zero, so training is boosting of the GLM. p. 2 ^f2
  > We choose as initial value θ0 the MLE β MLE of (1) for β, and we set b3 = 0 and B3 = 0. This initialization is the crucial and subtle point in our concept
  > the blended model μCANN can be understood as a boosting enhancement where the gradient descent algorithm challenges μGLM for additional model structure.
- [method] Train with the GLM's own deviance loss (for us, log loss). p. 2 ^f3
  > To be consistent with the GLM approach of (1) we choose the deviance loss function as the objective function in the gradient descent algorithm.
- [method] The GLM part may stay trainable, be frozen, or be frozen with a trainable
  credibility weight α. p. 3 ^f4
  > we may either train β or declare the initial value β MLE to be an untrainable weight.
  > In this latter case α is interpreted as the credibility weight assigned to the GLM part.
- [method] Decision rule: keep the CANN only if it substantially lowers out-of-sample
  deviance, otherwise stay with the GLM. p. 3 ^f5
  > If the blended model μCANN provides a substantial improvement in the deviance loss (subject to over-fitting), then μGLM misses important model structure and the CANN approach μCANN should be used. Otherwise we should stay with the GLM.
- [method] Starting near the optimum makes training fast, so bootstrapping (many
  refits) becomes feasible; categoricals go in through embedding layers. p. 3 ^f6
  > we expect fast (near) convergence of the gradient descent algorithm because we are already starting the algorithm in a model that is close to optimal.
  > we can easily treat categorical covariates using embedding layers in neural nets.
- [method] (inferred) For us: logit = rating offset (champion ratings) + net(picks),
  net's last layer zero-initialised; early stopping then measures directly whether the
  net finds anything beyond the ratings, and an epoch-0 validation loss equals the
  logistic baseline. ^f7

## Read

- Whole editorial (3 pages)

## Not read

- Schelldorfer and Wüthrich 2019 SSRN case study (French MTPL numbers); not fetched
