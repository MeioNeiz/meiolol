---
title: Instance Weighting for Domain Adaptation in NLP (Jiang and Zhai, ACL 2007)
url: https://aclanthology.org/P07-1034.pdf
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: docs (whole paper, 8 pages)
relevance: high
grade: A/fair
description: ACL 2007 paper splitting domain shift into labelling (p(y|x)) and instance (p(x)) adaptation, with one weighted objective that prunes misleading source instances, up-weights labelled target ones and adds self-labelled target ones
---
# Instance Weighting for Domain Adaptation in NLP (Jiang and Zhai, ACL 2007)

Why: which old-patch games to trust when the new patch changed p(win | draft) for some
champions: the canonical instance-weighting paper that separates that case from p(x)
shift.

## Assessment

- Evidence: A. ACL 2007, widely cited as the standard instance-weighting reference;
  three tasks (POS, NE typing, spam), logistic regression, accuracy only, no
  significance tests or repeats.
- Reasoning: fair. Clear decomposition and honest about the one failure (weblog), but
  the weight heuristics (top-k pruning, factor a) are hand-set, and the density-ratio
  weight beta was never tried.
- Interests: none known; their own framework against plain baselines.
- Weigh: trust the decomposition and the ordering "up-weight target > prune source";
  the sizes are NLP accuracies, not log loss on near-coin-flip labels.

## Findings

- [method/dynamics] Shift splits into two needs with different fixes: labelling
  adaptation (p(y|x) differs) and instance adaptation (p(x) differs, p(y|x) about the
  same). Section 1, 2.1 ^f1
  > there are two distinct needs for adaptation, corresponding to the different distributions of instances and the different classification functions in the source and the target domains
- [method/dynamics] Fixes for a changed p(y|x): change the representation, a prior on
  the parameters, or pruning the instances whose p(y|x) changed; all need target labels
  or prior knowledge of where it changed. Section 2.2 ^f2
  > If we know the instances x for which pt (y|x) is different from ps (y|x), we can actively remove these instances from the training data
  > we need either some prior knowledge about the target domain, or some labeled target domain instances
- [method/dynamics] The density-ratio weight pt(x)/ps(x) only addresses instance
  adaptation, and they never estimated it: beta was fixed at 1 because density
  estimation in high dimensions is hard. Section 3.2 ^f3
  > We have not explored this direction, and in our experiments, we set β to 1 for all source instances.
- [method/dynamics] Pruning heuristic: fit a model on the few labelled target
  instances, classify the source instances with it, and drop the top k it gets wrong
  by confidence (alpha 0), keep the rest at alpha 1. Section 3.1 ^f4
  > (ranked by their prediction confidence) are discarded
- [method/dynamics] Pruning mostly helped (POS 0.8630 to 0.8720, spam u00 0.6306 to
  0.8106 when all misclassified were dropped) but hurt on weblog NE (0.7045 to 0.6600),
  which they put down to the labelled target sample being biased. Section 4.2, Table 1 ^f5
  > In the case of weblog NE type classification, however, removing the source instances hurt the performance.
  > the set of labeled target instances we use is a biased sample from the target domain
- [method/dynamics] Adding the labelled target instances with weight a times a source
  instance (a 2 to 20) beat equal weighting in almost all cases (POS 0.9349 equal, 0.9443
  at a = 20). Section 4.3, Table 2 ^f6
  > in almost all cases, weighting the target instances more than the source instances performed better than weighting them equally
- [method/dynamics] Pruning on top of target up-weighting was worse than up-weighting
  alone in most cases (weblog 0.7840 to 0.6670): the emphasis shifts onto a small,
  biased target sample. Section 4.3 ^f7
  > when combined, the performance in most cases is not as good as when no source instances are removed
- [method/dynamics] Their overall result: using more target information matters much
  more than removing misleading source instances. Section 6 ^f8
  > incorporating and exploiting more information from the target domain is much more useful than excluding misleading training examples from the source domain
- [method] Checked, not there: no time-ordered shift, no log loss or calibration, no
  rule for choosing k or a beyond trying values on the test domain. ^f9
- [method/dynamics] (inferred) For us, a draft model gets ~45% of games wrong even when
  correct, so per-game "misclassified by the new-patch model" is mostly noise; pruning
  only makes sense per cell (old-patch games of a champion whose new-patch rate
  disagrees with its old one). And a patch's first days are a biased target sample
  (early hours, players trying the buffed champion), the weblog failure mode. ^f10

## Read

- Whole paper (sections 1-6, tables 1-3).

## Not read

- Cited Daumé and Marcu 2006 mixture model: covered by daume-2007-easy-da's lineage.
