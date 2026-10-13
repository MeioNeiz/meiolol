---
status: answered
priority: now
area: stats
tags: [method, stats]
description: How do you distil GPU-trained models into small CPU models that stay explainable?
---
# How do you distil GPU-trained models into small CPU models that stay explainable?

Feeds: Jacob (2026-10-13): train heavy on the gpu-box, ship CPU-only models that pick
out information. meiolol-08's distillation step: additive CPU student fitted to GPU
teachers' soft predictions; teachers are 0a's net ensemble, win-comp, experience terms.
Builds on [[nn-draft-models]] (distillation gains are ensemble gains).

## Answer

Distillation suits us unusually well, on one condition. Fitting a student to a teacher's
probabilities instead of 0/1 labels lowers the student's variance, and the gain grows the
noisier the labels: a near-coin-flip win label is the favourable extreme (C1). Rare cells
gain most: soft targets on 3% of the data nearly matched the full-data model (C1). The
condition: the teacher must beat a well-shrunk additive model fitted to labels, on held-out
log loss; where the teacher is no better, the student gains nothing or gets worse (C5).
Choose the teacher by calibration (held-out log loss), not accuracy (C2).

Recipe (C8). Teacher targets out-of-fold: each seed net labels only games it did not train
on (C3). Student loss: squared error on the mean of the seed nets' logits; with two
classes temperature adds nothing (C4). Student form: champion-role main terms first, then
ally and enemy role-pair terms fitted on the residual with heavier shrinkage (GA2M order),
so the displayed main effects stay stable and pairs hold only what mains cannot (C7).
Optional synthetic drafts (a real draft with one slot swapped to another champion seen in
that role), labelled by the teacher, to cover rare pairs; they help only when close to
real data, and the classic method failed on high-arity categorical inputs, ours (C6).
What is kept: in binary tabular tasks soft labels on real rows kept about two thirds of
the teacher's gain over a label-trained student, with near-data synthetic rows about
88% (C6); additive students matched their teachers on 2 of 3 sets and fell well short
where the teacher used interactions (C9). Report fidelity (student vs teacher logits) and
held-out accuracy separately: they differ (C10). Validation: fit the same additive model
to labels and to teacher logits and compare term by term (distill-and-compare, C11).
GBDT students keep the most (96.5% of teacher AUC) but are not readable; use one only as
a ceiling on achievable fidelity (C12). Soft decision trees: skip (C10).

## Claims

- C1: Soft targets lower student variance most when labels are noisy and data per cell is thin. for: [[menon-statistical-distil-2021#^f1]], [[menon-statistical-distil-2021#^f2]], [[menon-statistical-distil-2021#^f4]], [[hinton-distilling-2015#^f8]], [[tan-distill-compare-2018#^f4]]
- C2: A teacher's calibration matters more than its accuracy; teacher variance across training samples hurts. for: [[menon-statistical-distil-2021#^f5]], [[menon-statistical-distil-2021#^f6]], [[menon-statistical-distil-2021#^f7]]
- C3: Teacher targets must be out-of-fold; re-labelling its own training rows costs accuracy. for: [[ba-caruana-deep-2014#^f5]], [[pocket-tfm-gbdt-2026#^f2]], [[pocket-tfm-gbdt-2026#^f3]]
- C4: Regressing the student's logits on the (ensemble-averaged) teacher logits by squared error beat KL and probability losses; temperature KL tends to it at high T. for: [[ba-caruana-deep-2014#^f1]], [[ba-caruana-deep-2014#^f2]], [[ba-caruana-deep-2014#^f4]], [[hinton-distilling-2015#^f4]] against: [[fakoor-augdistil-2020#^f1]]
- C5: Distillation gives nothing, or harms, when the teacher is no better than the best label-trained model. for: [[fakoor-augdistil-2020#^f4]], [[pocket-tfm-gbdt-2026#^f5]]
- C6: Teacher-labelled extra inputs add accuracy only if close to the real distribution; binary tasks: labels 82.85, soft labels on real rows 83.89, plus near synthetic rows 84.21, teacher 84.40; MUNGE failed on high-arity nominal inputs. for: [[fakoor-augdistil-2020#^f3]], [[fakoor-augdistil-2020#^f7]], [[bucila-compression-2006#^f2]], [[bucila-compression-2006#^f4]], [[bucila-compression-2006#^f5]], [[bucila-compression-2006#^f6]]
- C7: Fit main effects first and pairs on the residual; detecting real pairs needs far more samples than candidate pairs, and weak pairs look like chance. for: [[lou-ga2m-2013#^f3]], [[lou-ga2m-2013#^f4]], [[lou-ga2m-2013#^f5]], [[lou-ga2m-2013#^f6]]
- C8 (inferred): Our recipe: out-of-fold mean seed logits, squared-error fit, mains then shrunk pairs, synthetic one-slot swaps tested against none, kept only if the teacher beats the shrunk label-fit model. from: C1, C3, C4, C5, C6, C7
- C9: Distilled additive students matched their teachers where interactions were weak (Pneumonia, FICO) and lost 3 AUC points where not (Magic); pair terms help on some data and hurt on others. for: [[tan-global-additive-2018#^f3]], [[tan-global-additive-2018#^f4]], [[tan-global-additive-2018#^f5]], [[tan-global-additive-2018#^f7]]
- C10: Students often disagree with their teachers even when accuracy matches; fidelity and generalisation are separate measurements; restricted students (soft trees) kept a fifth to a half of the gap. for: [[stanton-kd-work-2021#^f1]], [[stanton-kd-work-2021#^f2]], [[stanton-kd-work-2021#^f3]], [[frosst-soft-tree-2017#^f1]], [[frosst-soft-tree-2017#^f3]]
- C11: Distill-and-compare: fit a transparent model to the teacher's calibrated logits and another to outcomes, then compare shape functions per feature; an additive model with pairs was about as faithful as a random forest. for: [[tan-distill-compare-2018#^f1]], [[tan-distill-compare-2018#^f2]], [[tan-distill-compare-2018#^f3]], [[tan-distill-compare-2018#^f5]]
- C12: A GBDT student kept 96.5% of teacher AUC at millisecond CPU latency; tree students gain less from distillation than neural ones. for: [[pocket-tfm-gbdt-2026#^f1]], [[fakoor-augdistil-2020#^f5]]
- C13: A NAM is an additive model trainable on GPU whose per-feature nets act as lookup tables; it was within noise of EBM (MIMIC-II AUC 0.830 vs 0.835). for: [[agarwal-nam-2021#^f1]], [[agarwal-nam-2021#^f2]], [[agarwal-nam-2021#^f3]], [[agarwal-nam-2021#^f4]]

## Disagreements

- Loss: logit L2 (Ba and Caruana, A; Hinton's high-T limit) vs Brier on probabilities
  (Fakoor, B). Near p=0.5 the two nearly coincide (our case), so it hardly matters; our
  own fit with both on the folds settles it.
- Synthetic inputs: large gains in Bucila (A) and Fakoor (B) vs failure on high-arity
  nominal data (Bucila ^f5) and little gain for limited students (Distill-and-Compare
  ^f6). Test one-slot swaps against real games only.

## Open

- No source distils into an additive model on a noisy binary game outcome; the share of
  the teacher an additive draft student keeps is ours to measure (fidelity and log loss).
- Whether our GPU teachers beat the shrunk additive label fit at all (C5): today no net
  beats ratings or win-comp (docs/learned.md), so distillation may have nothing to pass on
  until one does; the player-history teacher is the likelier source.
- Leads: Lengerich 2020 functional ANOVA purification (keeps main effects out of pair
  terms); Sun, Schulte 2020 hockey model distilled into linear model trees; Beyer 2021
  patient and consistent teachers.
