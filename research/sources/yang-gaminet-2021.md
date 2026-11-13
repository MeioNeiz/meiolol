---
title: 'Yang, Zhang, Sudjianto 2021: GAMI-Net, an explainable neural network based on generalized additive models with structured interactions'
url: https://arxiv.org/pdf/2003.07132.pdf
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (abstract, 1, 2.1-2.3, 2.5-2.6, results text of 3)
relevance: medium
grade: B/fair
description: Neural GA2M (HKU, Wells Fargo model risk; arXiv v2 June 2021) with three built-in constraints: sparsity by pruning, weak heredity on pairs, and a marginal clarity penalty that keeps pairs orthogonal to their mains during training instead of purifying afterwards; accuracy on par with EBM on small sets
---
# Yang, Zhang, Sudjianto 2021: GAMI-Net

Why: what a GA2M gains from heredity, sparsity and an orthogonality penalty inside the
fit, as an alternative to post-hoc purification ([[lengerich-2020-purification]]), and
how it treats categoricals.

## Assessment

- Evidence: B. arXiv v2 (June 2021) from HKU and a bank's model-risk group, public code
  (ZebinYang/gaminet: 69 stars, 29 forks, GPL-3.0, last release v0.6.0 2022-12, last
  push 2024-03). Experiments are small: synthetic n up to 10,000, real sets from 500 to
  45,211 rows.
- Reasoning: fair. Each constraint is motivated and ablated (with and without heredity,
  a range of penalty strengths); admits it is hard to say whether it or EBM predicts
  better. EBM run at defaults with 20 interactions.
- Interests: authors' method against EBM.
- Weigh: take the three constraints as design ideas; the accuracy comparison is on
  small continuous-heavy sets and says nothing about 170-level nominal pairs or
  near-chance outcomes.

## Findings

- [method/interpret] Weak heredity: a pair may enter only if at least one of its parent
  main effects was kept. Section 1, 2.2 ^f1
  > a pairwise interaction can only be included in the final
  > model if at least one of its parent main effects is important.
- [method/interpret] Why weak heredity: smaller search space, a more readable structure,
  and empirical support from factorial experiments. Section 2.2 ^f2
  > the search space (of pairwise interactions) can be reduced and hence it brings computational
- [method/interpret] Sparsity: effects are ranked by the sample variance of their
  contribution, added one by one, and cut where validation loss is within a tolerance
  (1%) of its minimum; the same for mains and pairs. Section 2.2, 2.3, 2.5 ^f3
  > The importance of a main effect or pairwise interaction can be quantified by the variation
  > main effects will be added one-by-one in the descending order of their contributions (5). The list
- [method/interpret] Marginal clarity: besides zero means, each pair should be nearly
  orthogonal to its parent mains under the data distribution (weighted functional
  ANOVA); the sum of main x pair products over samples is penalised in the loss with
  strength lambda. Section 2.2, 2.3 ^f4
  > can be easily absorbed by their child interactions and vice versa. There could be multiple
  > The second term is the marginal clarity regularization,
- [method/interpret] The authors contrast it with purification: that one is post hoc and
  for piecewise-constant functions only. Section 2.2 ^f5
  > Note that a similar interaction purifying method is proposed in [2], which is based
  > on post-hoc processing and only suitable for piecewise constant functions.
- [method/interpret] Three training stages: mains trained and pruned; top-K pairs chosen
  by the FAST ranking on the residuals among heredity-allowed candidates, trained with
  mains frozen, pruned; then everything fine-tuned jointly under the penalty. Section
  2.3 ^f6
  > In GAMI-Net, we employ the interaction ranking algorithm proposed in [19], subject
  > stage, the main effect subnetworks are fixed. Each estimated pairwise interaction is centered
- [method/interpret] Joint fine-tuning is there because pairs fitted on frozen mains
  limit accuracy and pruning biases what is left. Section 2.3 ^f7
  > 2) The pairwise interactions estimated separately are conditional on the pre-trained main
- [method/interpret] Categoricals are one-hot encoded; a categorical main effect reduces
  to one bias node per level. Section 2.1 ^f8
  > can be simplified to many bias nodes, where each node captures the intercept effect of a
- [method/interpret] Checked, not there: how a pair subnetwork (two input nodes) takes a
  categorical with many levels, any shrinkage of rare levels, or any test with
  high-cardinality or categorical x categorical pairs. Defaults: at most K = 20 pairs,
  subnetworks of 5 ReLU layers of 40 nodes. Section 2.5 ^f9
  > tions is set to K = 20. For simplicity, each subnetwork is configured to have 5 ReLU hidden
- [method/interpret] [stats] Ablations: a larger lambda lowered the clarity loss and
  overfitting; on Bank Marketing accuracy held until lambda 0.1, and the fit with and
  without heredity came out the same. Section 3.2, 3.3 ^f10
  > get decreased while the predictive performance does not change too much until λ = 10−1 .
  > without the heredity constraint provide the same results, which indicates that the model
- [method/interpret] Results in one line: on par with EBM across the real sets (500 to
  20,640 rows in the benchmark table), neither reliably ahead. Section 3.5 ^f11
  > EBM and other benchmark models. In practice, it is hard to say which one will perform
- [method/interpret] (claim) The authors say EBM, lacking the clarity constraint, lets a
  main and its child pairs absorb each other, and that its pair count must be fixed in
  advance. Section 2.6 ^f12
  > its corresponding child pairwise interactions may be mutually absorbed, which leads to non-
- [method/interpret] (inferred) For us the three constraints map to things we have or
  can do without a net: heredity is moot (every seat has a main effect; all 45 seat
  pairs are candidates, and at cell level both champions always have mains); sparsity
  is our shrinkage of pair cells; marginal clarity is the in-fit version of purifying
  pair cells against champion mains under the seat-weighted data, which we can apply
  exactly after the fit since our terms are tables ([[lengerich-2020-purification#^f5]]).
  GAMI-Net itself adds nothing at champion-identity level: one-hot mains are a logistic
  model, and its pair subnetworks are not specified for 170-level nominals (^f9). ^f13

## Read

- Abstract, 1, 2.1 (architecture, categoricals), 2.2 (constraints), 2.3 (training),
  2.5 (hyperparameters), 2.6 (comparison with EBM), result paragraphs of 3.2-3.5.

## Not read

- 2.4 (interpretation plots), tables and figures (extraction), synthetic study details,
  the gaminet package code (how it actually feeds a categorical into a pair net).
