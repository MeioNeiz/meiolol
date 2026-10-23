---
title: 'Kumar et al. 2022: Fine-Tuning can Distort Pretrained Features and Underperform Out-of-Distribution'
url: https://arxiv.org/pdf/2202.10054
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: listed (sections 1-4, 6, appendix B.3)
relevance: medium
grade: B/strong
description: Kumar, Raghunathan, Jones, Ma, Liang (Stanford, ICLR 2022 oral); full fine-tuning from a random head distorts pretrained features on directions the fine-tune data doesn't cover; LP-FT (fit the head first, then fine-tune) fixes it
---
# Kumar et al. 2022: Fine-Tuning can Distort Pretrained Features and Underperform OOD

Why: if we fine-tune a set net on a small newest-patch set, do the parts of the input
space that set doesn't cover (rare champions, rare pairs) get damaged?

## Assessment

- Evidence: B. ICLR 2022 oral, Stanford (Liang, Ma); 10 shift benchmarks, MoCo and
  CLIP backbones, 3 runs with intervals, a theorem in two-layer linear nets, and
  checks of the predicted mechanism (feature movement measured).
- Reasoning: strong. Theory predicts and tests when FT wins (close ID and OOD, weak
  features) and when it loses; says LP-FT is a principled baseline, not SOTA.
- Interests: none known.
- Weigh: their ID/OOD maps loosely onto us: the fine-tune set is newest-patch games,
  and the "OOD" part is whatever those few games don't span (champions and combos
  barely played in it), though our test is the same patch. Trust the mechanism
  (random head plus small data distorts features); sizes are vision-specific.

## Findings

- [method/dynamics] Fine-tuning beat linear probing in distribution (85.1% vs
  82.9%) but lost out of distribution on 8 of 10 shifts (59.3% vs 66.2%). Section 4.1 ^f1
  > Fine-tuning does better than linear probing on 5 out of 6 ID datasets (average accuracy of 85.1% for fine-tuning vs. 82.9% for linear probing, see Table 1).
  > linear-probing does better on 8 out of 10 OOD datasets (average accuracy of 66.2% for linear probing vs. 59.3% for fine-tuning, see Table 2)
- [method/dynamics] Mechanism: gradient updates move representations only within
  the span of the fine-tune data; directions outside it stay put, so the refit head
  no longer matches them. Section 3.2.1 ^f2
  > representations change only in the ID subspace (i.e., subspace spanned by the training data) and are unchanged in the orthogonal subspace
- [method/dynamics] The damage comes from the head starting far off (random or
  zero): coupled updates move the features a lot. A head already near right would
  not raise OOD error. Section 3.2.2 ^f3
  > If the head were somehow initialized perfectly at v? , then fine-tuning updates may not increase the OOD error. However, when the head is randomly initialized (or initialized to zero) as is standard in fine-tuning, the alignment error is high, leading to high OOD error.
- [method/dynamics] LP-FT (fit the head with the body frozen, then fine-tune all)
  was best both ID (85.7%) and OOD (68.9%), at the same compute; features moved
  10-100x less than under plain fine-tuning (30x on CIFAR-10). Sections 1, 4.2, B.3 ^f4
  > We find that LP-FT gets the best accuracy ID (average: 85.7%) and OOD (average: 68.9%).
  > LP-FT indeed changes both ID and OOD features 10 × −100× less than fine-tuning does
- [method/dynamics] Early stopping does not rescue plain fine-tuning: even early
  stopped on OOD data it stayed below linear probing (61.3% vs 67.1%). Section 4.3 ^f5
  > As expected, fine-tuning does improve a little, but linear probing (average accuracy: 67.1%) is still better than fine-tuning (average accuracy: 61.3%).
- [method/dynamics] Fine-tuning wins when the pretrained features are weak or the
  shift is small (CIFAR-10 to CIFAR-10.1, ImageNetV2). Section 1 ^f6
  > fine-tuning can do better than linear probing OOD if the pretrained features are not very high quality (MoCo-v1 instead of MoCo-v2) or the ID and OOD datasets are very close
- [method/dynamics] Training sets ran from 20K to over a million examples, so the
  effect is not just a small-data artefact. Section 4.1 ^f7
  > Our training datasets vary in size from 20K examples to over a million examples, so linear probing does not appear to perform better than fine-tuning simply because of a small training set.
- [method/dynamics] (inferred) For us: continuing a trained set net on new-patch games
  starts from a head that is already good (last patch's), which is the condition
  under which ^f3 says fine-tuning does little harm; the risk is resetting or adding
  a fresh head (a new per-patch output) and fine-tuning everything at once. If we add
  per-patch parameters, fit them first with the body frozen (LP-FT order), then
  optionally unfreeze. ^f8

## Read

- Abstract, sections 1-4 (theory in outline), 6, appendix B.3 (feature distance)

## Not read

- Proofs (appendix A), per-dataset tables, B.4 extra architectures and heuristics
