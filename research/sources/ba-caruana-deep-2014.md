---
title: 'Ba, Caruana 2014: Do deep nets really need to be deep?'
url: https://arxiv.org/pdf/1312.6184
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: docs (1-2, 5-6)
relevance: high
grade: A/fair
description: NIPS 2014 paper; shallow nets trained to regress a deep net ensemble's averaged logits by L2 match deep accuracy on TIMIT and CIFAR-10, where the same shallow nets trained on labels cannot
---
# Ba, Caruana 2014: Do deep nets really need to be deep?

Why: which loss to distil with (logits by L2 vs probabilities vs KL), and why a student
trained on teacher outputs beats the same student trained on labels.

## Assessment

- Evidence: A. Canonical, widely replicated paper; two benchmarks (TIMIT 1.1M frames,
  CIFAR-10), a teacher-accuracy sweep (Figure 3). The loss comparison is a single
  sentence, no table.
- Reasoning: fair. Gives mechanisms (label noise removed, soft targets, regularisation)
  as plausible lists, not tested separately.
- Interests: none.
- Weigh: trust that logit L2 is at least as good as probability losses for a
  regression student, and the averaged-logit ensemble target. Mechanisms are
  hypotheses.

## Findings

- [method] Student regresses the teacher's logits with L2 loss rather than
  cross-entropy on its probabilities. Section 2.2 ^f1
  > are trained directly on the 183 log probability values z, also called logit, before the softmax activation.
- [method] Logit L2 beat KL divergence and L2 on probabilities. Section 2.2 ^f2
  > Logits regression outperforms all the other loss functions and is one of the key technique for obtaining the results in rest of this paper.
- [method] Why: in probability space near-0 and near-1 targets are squashed and the
  student ignores differences there; logits keep them. Section 2.2 ^f3
  > If we use these probabilities as prediction targets directly to minimize a cross entropy loss function, the student will focus on the third target and easily ignore the first and second target.
- [method] Ensemble teacher: average the members' logits and regress on the average.
  Section 3 ^f4
  > the logits (log probability of the predicted values) from each CNN in the ECNN model are averaged and the average logits are used as final regression targets to train the mimic SNNs.
- [method] Re-labelling the training set itself costs accuracy: compression works best
  with many more unlabelled inputs than training rows, away from points the teacher
  overfit. Section 3 ^f5
  > model compression works best when the unlabeled set is much larger than the train set, and when the unlabeled samples do not fall on train points where the teacher model is more likely to have overfit.
- [method] [stats] Why a student beats the same model on labels: the teacher removes
  label errors and replaces hard 0/1 with its uncertainty. Section 5 ^f6
  > if some labels have errors, the teacher model may eliminate some of these errors (i.e., censor the data), thus making learning easier for the student
- [method] Mimic training acts as regularisation for a student that overfits raw labels.
  Section 5 ^f7
  > Model compression appears to be a form of regularization that is effective at reducing this gap.
- [method] Student accuracy kept rising as teacher accuracy rose (Figure 3): a better
  teacher (an ensemble) is the main lever. Section 5.2 ^f8
  > the accuracy of both models continues to increase as teacher accuracy increases.
- [method] (inferred) For a binary win label the logit-L2 rule means: student
  log-odds = sum of champion, pair and comp terms, fitted by (weighted) least squares to
  the mean of the seed nets' logits. That is a ridge or mixed-model fit we already know
  how to shrink, closed form or a few CG steps on CPU, not a classifier fit. ^f9
- [method] (inferred) ^f5 bites us: teachers trained on all 230k games re-labelling
  those same games gives in-sample, overfit targets. Use out-of-fold teacher
  predictions (each seed net predicts only games it did not train on) or synthetic
  drafts as the student's inputs. ^f10

## Read

- Sections 1-2, 3 (TIMIT ensemble), 5-6.

## Not read

- Section 2.3 linear bottleneck layer; CIFAR-10 details; tables (extraction scrambled).
