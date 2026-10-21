---
title: 'Predicting Drafted Deck Strength for Magic: the Gathering'
url: https://arxiv.org/pdf/2607.04782
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: docs (whole paper, 4 pages)
relevance: high
grade: C/fair
description: Rigaux and Kashima (Kyoto, 2026, IEEE CoG short paper); win-rate prediction for MTG draft decks from card text embeddings (EmbeddingGemma) with and without per-card win-rate stats, on a time split and on an unseen expansion with and without 4 days of fine-tuning
---
# Predicting Drafted Deck Strength for Magic: the Gathering

Why: the one source found that tests text-embedded game pieces against an outcome
(win rate), not human pick agreement, including the "new pieces, few days of data"
case that matches a new champion or a patch day.

## Assessment

- Evidence: C. Short paper, 3 seeds, 120k-400k drafts, Spearman only; time split in
  the within-set test. Code public (github.com/akulen/MtGDraftEncoder), not checked.
- Reasoning: fair. States the noise ceiling (0.23) and the new-set weakness plainly;
  no log loss, no id-embedding baseline.
- Interests: none known.
- Weigh: trust the direction of Table II (text alone < empirical win-rate stats;
  a few days of outcomes close most of the gap); the sizes are noisy (± up to 0.04).

## Findings

- [method/pretrain] Cards enter as a frozen 768-dim EmbeddingGemma vector of the card's
  full oracle string, optionally concatenated with "META" per-card empirical win rates
  (Bertram et al.'s statistics). IV.A ^f1
  > we convert all the information in a card into a string (see Fig. 2) and use EmbeddingGemma [5]
  > In our results, we indicate when a model concatenates these META features to the textual features.
- [method/pretrain] Within-set, time split (2-week train, val, test chunks, ~120k
  drafts): the encoder reaches almost twice the linear baselines' rank correlation,
  near the 0.23 noise ceiling; META features help consistently. V.A, VI ^f2
  > split temporally using the last 6 weeks of data into chunks of 2 weeks assigned to training, validation, and testing chronologically
  > it quickly grows to almost twice the rank correlation of the baselines, and is close to reaching the saturation value of around 0.23
- [method/pretrain] Unseen expansion (Table II, Spearman): heuristic from empirical card
  win rates 0.139; text-only encoder 0.088 (no better than linear with META, 0.089);
  encoder with META 0.153. After fine-tuning on the set's first four days: text-only
  0.164, with META 0.181. VI, Table II ^f3
  > the model struggles to generalize to new sets, without having access to the meta features, only matching the performance of the linear model without meta features
  > Fine-tuning using the first four days of data lowers the importance of the meta features a lot
- [method/pretrain] Authors' reading: unseen cards are the main remaining problem;
  four days of data largely close the gap. VII ^f4
  > fine-tuning on as little as four days of initial data largely closes the gap to meta-augmented models
- [stats] Outcomes are censored (play to 7 wins or 3 losses); they fit a censored
  binomial likelihood and estimate a 0.23 Spearman ceiling from sampling noise. II, V.C ^f5
  > The correlation between a true win rate probability p ∼ N (0.53, 0.05) (calibrated to match the observed distribution via simulation)
- [method/pretrain] Checked, not there: no id-embedding baseline, no text-vs-features
  ablation, no log loss or calibration, no per-card cold-start breakdown. ^f6
- [method/pretrain] (inferred) For us: text embeddings of a new piece carried less
  outcome signal than a few days of its own results, and less than simple empirical
  win-rate stats. On a patch day or a champion release, a text prior is worth at most
  the first days' estimates; after that the id term wins. ^f7

## Read

- Whole paper

## Not read

- Code repository (to check the split and META leakage on the unseen set)
