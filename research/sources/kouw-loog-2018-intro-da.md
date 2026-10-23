---
title: An introduction to domain adaptation and transfer learning (Kouw and Loog, 2018)
url: https://arxiv.org/pdf/1812.11806v2
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: docs (sections 4, 5.1, 6.1, 6.4, 7)
relevance: high
grade: B/strong
description: TU Delft tutorial survey of domain adaptation (arXiv 2018, 42 pages): prior, covariate and concept shift, importance weighting and its weight-variance and divergence limits, open problems
---
# An introduction to domain adaptation and transfer learning (Kouw and Loog, 2018)

Why: a careful statement of where importance weighting stops working, in particular
when p(y|x) changes (our patch case), and what it says about mixed shifts.

## Assessment

- Evidence: B. Tutorial survey by domain adaptation researchers (Loog a long-standing
  name in the field); arXiv, widely cited; no new experiments.
- Reasoning: strong. Derives each case from the risk, states assumptions and when
  they fail, lists open questions plainly.
- Interests: none known.
- Weigh: trust the definitions and limits; the "some robustness to violation" remark
  is a claim without numbers.

## Findings

- [method/dynamics] Three simple shifts by which factor changes: prior shift (p(y)),
  covariate shift (p(x), same posterior), concept shift (same p(x), posterior changes).
  Section 4 ^f1
  > the posteriors change, then it is a case of ”concept shift”
- [method/dynamics] Under concept shift the weight would be pT(y|x)/pS(y|x), which no
  unlabelled data can estimate: adaptation needs target labels. Section 4.3 ^f2
  > But adaptation in this setting is still impossible without labeled target data.
- [method/dynamics] For drift over time, the extra structure is order and small steps:
  with feedback each step, the drift can be modelled and the next shift predicted.
  Section 4.3 ^f3
  > the shifts are ordered and are relatively small between neighboring time steps
- [method] Importance weighting's error bound grows with the Rényi divergence between
  domains, which diverges when the domains are too far apart; more divergence needs
  more samples. Section 5.1 ^f4
  > will diverge to infinity when the domains are too far apart
- [method] Weight variance is the practical failure: one sample takes most of the
  weight and the classifier ignores the rest. Section 5.1 ^f5
  > Large weight variance means that it is highly probable that one sample will receive a very large weight, while the rest will receive nearly-zero weights.
- [method/dynamics] The covariate shift assumption needs equal posteriors over the whole
  feature space, much stronger than equal decision boundaries, so it is often assumed
  where it does not hold. Section 6.1 ^f6
  > Equal class-posterior distributions is a much more difficult condition to satisfy than equal decision boundaries.
- [method/dynamics] (claim) Some experiments suggest weighting is robust to mild
  violations; no numbers given. Section 6.1 ^f7
  > some experiments have indicated that there is some robustness to a violation of the covariate shift assumption
- [method/dynamics] When both p(x) and p(y|x) change, the two cannot be told apart
  without some target labels. Section 7 ^f8
  > if there are both changes in the data distributions and changes in the class-posterior distributions, then these cannot be identified without some target labels
- [method/dynamics] Open question they name: does the equal-posterior assumption hold
  on only part of the feature space? That is the patch case: unchanged champions keep
  their posterior, patched ones do not. Section 7 ^f9
  > Does the assumption of equal class-posterior distributions hold for only a part of feature space?
- [method/dynamics] Sequential adaptation through intermediate domains (a chain of
  importance-weighting steps, like a particle filter) is proposed but unstudied: do
  errors accumulate? Section 6.4 ^f10
  > will adaptation errors accumulate?

## Read

- Section 4 (shift types), 5.1 (importance weighting), 6.1, 6.4, 7.

## Not read

- Sections 2-3 (risk minimisation basics), 5.2-5.6 (subspace mappings, invariant
  spaces, feature augmentation, minimax, robust): other readers cover representation
  methods.
