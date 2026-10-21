---
title: Chelba and Acero 2004: Adaptation of Maximum Entropy Capitalizer
url: https://aclanthology.org/W04-3237.pdf
kind: paper
commit: 
for: [patch-transfer]
looked: 2026-10-21
depth: docs (whole paper)
relevance: high
grade: B/fair
description: EMNLP 2004: MAP adaptation of a logistic (maxent) model by a Gaussian prior centred on the background model's weights; little in-domain data helps a lot
---
# Chelba and Acero 2004: Adaptation of Maximum Entropy Capitalizer

Why: the PRIOR method, i.e. fine-tuning a logistic model toward last patch's weights.

## Assessment

- Evidence: B. EMNLP paper, one task (capitalisation), two test sets; widely used as the PRIOR baseline since (Daumé 2007).
- Reasoning: fair. Method derived; one hyperparameter swept on dev.
- Interests: none known.
- Weigh: the gain is for a task with plenty of signal per example; ours is a coin with a 2-3 pp edge, so the useful prior variance will be tiny.

## Findings

- [method/dynamics] MAP adaptation: the Gaussian prior on the weights is centred on the background model's weights rather than 0. Section 4 ^f1
  > The effect of the prior is to keep the model parameters λi close to the background ones.
- [method/dynamics] [stats] One tied prior variance, picked by line search on in-domain dev data; small variance means no adaptation, large means fitting the small in-domain set. Sections 3, 5 ^f2
  > values of σ2 result in no adaptation at all, whereas
- [method/dynamics] A very small in-domain set (25-70k words) cut error by about 20-25% relative over the background model alone. Abstract ^f3
  > adaptation technique using a very small amount of matched BN data — 25-70kwds — is about 20-25% relative.
- [method/dynamics] The gain came from re-weighting the background features, not from new in-domain ones. Section 6 ^f4
  > A surprising result is that the adaptation performance gain is not due to adding more, domain-specific features but rather making better use of the background features for modeling the in-domain data.
- [method/dynamics] (inferred) For us: warm start from last patch's ratings with L2 toward them (not toward 0), the strength picked on newest-patch dev games; unchanged champions should barely move, so a per-champion variance (bigger for patched champions) is the natural extension. ^f5

## Read

- Whole paper, results tables.

## Not read

- Appendix A derivation.
