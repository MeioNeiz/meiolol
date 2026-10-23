---
title: 'Lee et al. 2022: Surgical Fine-Tuning Improves Adaptation to Distribution Shifts'
url: https://arxiv.org/pdf/2210.11466
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: listed (sections 1-4, 6; not appendix proofs)
relevance: high
grade: B/strong
description: Lee, Chen, Tajwar, Kumar, Yao, Liang, Finn (Stanford, ICLR 2023); fine-tuning one block of a pretrained net on a small target set beats full fine-tuning, and the best block is where the shift lives
---
# Lee et al. 2022: Surgical Fine-Tuning Improves Adaptation to Distribution Shifts

Why: when a patch moves a handful of champions, which part of a set net should be
refit on little newest-patch data?

## Assessment

- Evidence: B. ICLR 2023, Stanford group (Finn, Liang, Kumar); 7 real shifts plus 2
  WILDS, 3 seeds, a synthetic test where the shifted block is known, and a two-layer
  theorem. Image models (ResNet, CLIP ViT), not tabular or embeddings of entities.
- Reasoning: strong. Says why (causal-module intuition, theorem), states the limit
  (freezing pays only with little target data), and admits Auto-RGN trails the best
  hand-picked block.
- Interests: none known; Kumar co-authors LP-FT ([[kumar-lpft-2022]]), same school of
  thought (preserve pretrained features).
- Weigh: trust the direction (tune where the shift is; full fine-tuning on a small
  target set overfits and forgets); sizes are from vision and won't transfer.

## Findings

- [method/dynamics] Fine-tuning one block and freezing the rest matched or beat full
  fine-tuning on every shift tested. Abstract, Figure 2 ^f1
  > selectively fine-tuning a subset of layers (which we term surgical fine-tuning) matches or outperforms commonly used fine-tuning approaches
- [method/dynamics] Which block is best depends on where the shift is: first block for
  input-level shifts, middle for feature-level, last layer for output-level (label or
  spurious correlation). Figure 1 ^f2
  > Fine-tuning the first block works best for input-level shifts such as CIFAR-C (image corruption), later blocks work best for feature-level shifts such as Entity-30 (shift in entity subgroup), and tuning the last layer works best for output-level shifts
- [method/dynamics] Mechanism: with few new directions in the input, tuning only the
  first layer learns them from few examples while keeping the source knowledge; full
  fine-tuning moves the head too and forgets. Section 1 ^f3
  > If the target distribution contains only a few new “directions” (inputs outside the span of the source distribution), we show that tuning only the first layer can learn these new directions with very few target examples, while preserving all the information learned from the source distribution.
- [method/dynamics] The benefit of freezing is a small-target-data effect; with
  plentiful target data tune more. On CIFAR-C the Block 1 vs All gap shrinks as the
  target set grows. Section 2 ^f4
  > We note that the efficacy of parameter freezing is a consequence of having limited target data, and choosing a bigger S will be beneficial in settings where target data is plentiful.
  > the gap between Block 1 and All decreases as the number of training points increases
- [method/dynamics] Synthetic test: noise added to one known block; tuning only that
  block beat tuning any other block or all of them (first-block noise: 92.5% tuning
  block 1 vs 87.8% tuning all). Figure 5 ^f5
  > only tuning the subset of parameters that is responsible for the shift performs better than tuning any other subset of parameters and even outperforms tuning all layers
- [method/dynamics] On a CLIP ViT, tuning only the embedding layer was best on
  Camelyon17 (95.6 vs 92.3 all), later blocks on FMoW. Table 1 ^f6
  > tuning the earliest embedding layer works best for Camelyon17 and tuning later attention blocks works best for FMoW
- [method/dynamics] Auto-RGN: per-tensor learning rate scaled by gradient norm over
  parameter norm, normalised to [0, 1] each epoch; one run, no extra hyperparameters;
  it gives the shifted block the highest weights and beats full fine-tuning, but
  trails choosing the block by cross-validation. Sections 4.1-4.3 ^f7
  > At each epoch, we normalize the per-tensor RGN values to lie between 0 and 1 and then multiply the base learning rate to obtain a per-tensor learning rate.
  > Auto-RGN is able to ascertain which parameters may be responsible for the shift and weight the learning of those parameters to be higher than the others
  > is the most competitive method that requires only 1 fine-tuning run although it does not quite match the performance of Cross-Val
- [method/dynamics] Gradual unfreezing did not consistently beat full fine-tuning;
  an L1 penalty toward the pretrained weights was only slightly better than full.
  Section 4.2 ^f8
  > While Gradual Unfreeze fails to consistently outperform full fine-tuning
  > L1 Regularize performs slightly better than fine-tuning all
- [method/dynamics] Checked, not there: the target fine-tune uses target data only;
  no replay of source data and no comparison with retraining on pooled source plus
  target. Evaluation is target-only, early-stopped on held-out target data. Section 2 ^f9
  > In all experiments, we perform early stopping on held-out target data according to the fine-tuning loss.
- [method/dynamics] (inferred) For us: a patch that buffs or nerfs a few champions is
  an input-level shift in a few rows of the champion and champion-role embedding
  tables, a few new directions in the sense of ^f3. The surgical choice is to tune only
  those rows (or the whole embedding tables, plus the ratings offset) on newest-patch
  games, with the DeepSets body and head frozen; Auto-RGN over embedding rows is a
  one-run way to find which champions moved. ^f10

## Read

- Sections 1-4 and 6 (discussion); Tables 1, 4, 5; Figures 1-5

## Not read

- Appendix proofs (A.2), per-dataset details and AdamW results (Table 8)
