---
title: 'Perlich, Provost, Simonoff 2003: Tree Induction vs. Logistic Regression, A Learning-Curve Analysis'
url: https://www.jmlr.org/papers/volume4/perlich03a/perlich03a.pdf
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 4.2 crossing curves, 5.1-5.2, 6 discussion)
relevance: high
grade: A/strong
description: JMLR 2003 (NYU Stern) learning curves of logistic regression vs trees on 36 binary datasets up to 2M rows: curves cross; logistic wins when signal is weakly separable (max AUC <= 0.8)
---
# Perlich, Provost, Simonoff 2003: Tree Induction vs. Logistic Regression

Why: our task has very low separability (AUC 0.55); whether trees or logistic
regression win there, and whether that changes with data size.

## Assessment

- Evidence: A. JMLR 2003, much cited; 36 binary datasets from 1k to 2M rows, full
  learning curves with error bars, accuracy and AUC.
- Reasoning: strong. Explains the crossing with linearity and noise, flags its
  exceptions and why they may not be exceptions.
- Interests: none known.
- Weigh: single trees (C4.5), not boosted ensembles; the separability criterion is the
  transferable part.

## Findings

- [method] [stats] Learning curves cross: logistic regression wins on small training
  sets, trees on large ones, often within the same domain, so model comparisons must
  look at the curve, not one size. Abstract ^f1
  > logistic regression is better for smaller training sets and tree induction for larger data sets. Importantly, this often holds for training sets drawn from the same domain (that is, the learning curves cross)
- [method] [stats] Which wins at scale is predicted by signal separability: trees for
  well-separable data, logistic regression where classes separate poorly. Section 1 ^f2
  > Tree induction is preferable for larger training-set sizes for which the classes can be separated well. Logistic regression is preferable for smaller training-set sizes and where the classes cannot be separated well
- [method] [stats] Low separability (max AUC <= 0.8): when distinguishable, logistic
  regression won 8-1-1 on AUC; several sets were indistinguishable within error bars.
  Section 5.2 ^f3
  > When the methods are distinguishable logistic regression is clearly the more effective method, in terms of both accuracy and AUR. Ten data sets fall into this category. Logistic regression’s win-tie-loss record here is 8-1-1 for AUR
  > For these data sets it is difficult to draw any conclusions, in terms of either accuracy or AUR, since the curves tend to be within each other’s error bars.
- [method] Why: a near-linear concept with noise favours logistic regression early;
  trees need more data to reach the needed complexity. Section 4.2 ^f4
  > If there are fewer non-linearities and there is little noise, then logistic regression will do better early on (relative to the number of parameters, of course); tree induction will need more data to reach the necessary complexity.
- [method] (inferred) At max AUC around 0.55 our data is far into the low-separability
  regime; expect a regularised logistic model (plus factorised pair terms) to stay
  competitive with tree ensembles well past 10^6 games, and compare families by
  learning curves, not a single split. ^f5

## Read

- Abstract, 1, 4.2, 5.1-5.2, 6

## Not read

- 2-3 methods and pruning/probability estimation variants, per-dataset curves
