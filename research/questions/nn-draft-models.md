---
status: answered
priority: now
area: stats
tags: [method, stats]
description: What neural draft models work at 100k-1M games, with what architecture, size, regularisation, training tricks and pretraining, and how much did they beat a logistic baseline on a time split?
---
# What neural draft models work at 100k-1M games, with what architecture, size, regularisation, training tricks and pretraining, and how much did they beat a logistic baseline on a time split?

Feeds: neural net programme (coordinator meiolol-2c; modellers meiolol-f1, meiolol-0d
[b5e038]): starting configs and pitfalls for draftnet, residual-on-ratings, profile and
set/attention nets; docs/model.md "Neural draft models". Builds on
[[draft-predictor-methods]] (C2, C4, C10, C15) and [[comp-attribute-features]]. Ours:
~230k games, ratings ~53-54% on a time split, dev noise ~+-0.0005 log loss.

## Answer

No source shows a neural draft model beating logistic regression beyond noise on a
time split at 100k-300k games (C1). jcj's warm-started interaction transformer tied
LR on the next patch at 110k games; DraftRec's draft-only nets were within 0.2-1.1
points of LR at 280k on a time split, and LR won on Dota. Gains of 0.01-0.05 AUC appear
only on random splits at 0.6M-30M games (C2), and LoLDraftAI's 55-56% has no LR
baseline, a random split and test-set checkpointing (C3). A net trained from scratch
does not even reach the LR optimum: jcj needed a warm start from the fitted LR (C4).
Small capacity wins at this size (C5). The best-measured analogue of "residual on a
GLM" (CANN) gains about 0.0016 nats over the GLM at similar size (C7).

Recipe for ~230k games (C11): a residual on the ratings offset with the net's output
started at zero (CANN, C6), small (2-3 layers of 128-256, champion embeddings 8-16),
dropout 0.1-0.2, AdamW at lr 1e-3 (MLP) or 1e-4 (attention), weight decay 1e-4 to
3e-4 with embeddings regularised explicitly, batch 512, constant lr, clip 1.0,
early stopping on validation log loss checked more than once per epoch (best epoch can
be 2), 3-5 seeds or TabM-mini heads averaged in probability (C8, C9). Structured nets:
a shared per-team encoder compared by difference beat a joint 10-token encoder and an
MLP by about 1 point on random folds at 156k LoL games (C10); in CS:GO a plain MLP beat
DeepSets beat Set Transformer (C10). Pretrained embeddings: one measured gain, on
probably overlapping data; nothing for win prediction (C12). Auxiliary targets and
class priors help only with less data, per LoLDraftAI, unablated at our size (C13).
Distillation gains are ensemble gains (C9). Never select on accuracy or use label
smoothing (C14). Search curve saturated (last searches found almost nothing new).

## Claims

- C1: On time splits at 110-280k LoL games, draft-only nets tie LR or beat it by 0.2-1.1 accuracy points; on Dota LR was best. for: [[jcj-lol-draft#^f21]], [[jcj-lol-draft#^f2]], [[draftrec-2022#^f4]], [[draftrec-2022#^f5]], [[siska-moba-draft-2021#^f5]]
- C2: Net and pairwise-embedding gains of 0.01-0.05 AUC over LR come from random splits at 0.6M-30M games. for: [[neuralac-2021#^f4]], [[chen-avatar-embedding-2018#^f4]], [[juewu-draft-2020#^f4]] against: [[draftrec-2022#^f4]]
- C3: LoLDraftAI's net (126-dim champion embeddings, 11-layer MLP, dropout 0.5, AdamW 0.05 on MLP weights only, one-cycle lr 8e-4, batch 20480, aux heads) is tuned for tens of millions of games, with a random split and the test set choosing the epoch. for: [[loldraftai#^f9]], [[loldraftai#^f11]], [[loldraftai#^f13]], [[loldraftai#^f21]], [[loldraftai#^f23]], [[loldraftai#^f30]]
- C4: Draft nets trained from scratch stay below the LR optimum; warm-started from LR, a transformer peaked at epoch 2. for: [[jcj-lol-draft#^f4]], [[jcj-lol-draft#^f16]], [[jcj-lol-draft#^f19]]
- C5: More capacity does not help at 1e4-1e5 games: small embeddings, no hidden layer chosen, small nets best near 1e5 rows. for: [[loldraftai#^f10]], [[neuralac-2021#^f9]], [[siska-moba-draft-2021#^f5]], [[actuarial-scaling-2026#^f2]], [[siamese-transformer-synergy#^f2]]
- C6: A CANN boosts a GLM: GLM loss, start at the GLM with the net's output at zero, keep only if out-of-sample loss drops; trainable output weights beat fixed. for: [[cann-editorial-2019#^f2]], [[cann-editorial-2019#^f3]], [[cann-editorial-2019#^f5]], [[insurance-nn-benchmark-2023#^f2]], [[insurance-nn-benchmark-2023#^f3]]
- C7: At ~1e5 rows the best net beat the GLM by about 0.0016 nats. for: [[actuarial-scaling-2026#^f3]]
- C8: Tabular net defaults: MLP 3x256, dropout 0.1-0.15, AdamW lr 1e-3 to 2e-3, wd 3e-4, batch 256-512, patience 16-40 on validation loss; FT-Transformer 3 layers, d 192, 8 heads, attention dropout 0.2, FFN 0.1, lr 1e-4, wd 1e-5 not on embeddings or LayerNorm. for: [[realmlp-2024#^f2]], [[realmlp-2024#^f3]], [[tabm-repo#^f1]], [[tabm-repo#^f2]], [[grinsztajn-tabular-2022#^f9]], [[tabm-2024#^f8]], [[ft-transformer-2021#^f8]], [[ft-transformer-2021#^f11]]
- C9: Ensembles are the reliable gain: 5 seeds or TabM heads (train on the mean of head losses, average probabilities); single nets vary a lot and distilled students are unstable. for: [[deep-ensembles-2017#^f1]], [[tabm-2024#^f2]], [[tabm-repo#^f3]], [[ft-transformer-2021#^f9]], [[practical-kd-2023#^f2]], [[practical-kd-2023#^f4]], [[insurance-nn-benchmark-2023#^f5]]
- C10: A shared per-team encoder compared by difference beat a plain MLP and a joint 10-token transformer by about 1 point (random CV, 76-156k LoL games, no LR baseline); in CS:GO a plain MLP beat DeepSets beat Set Transformer. for: [[siamese-transformer-synergy#^f3]], [[siamese-transformer-synergy#^f4]], [[siamese-transformer-synergy#^f5]], [[esta-csgo-2022#^f4]], [[esta-csgo-2022#^f5]]
- C11 (inferred): Start with a small residual-on-ratings net, a shared per-team encoder for structure, early stopping on log loss within the first epochs, and 3-5 member ensembles; expect at most ~0.001-0.002 log loss. from: C1, C4, C5, C6, C7, C8, C9, C10
- C12: Masked pretraining cut a football net's MSE 11-13% versus scratch, on data that probably overlapped the evaluation; no pretrained-vs-scratch embedding result exists for win prediction. for: [[risingballer-2024#^f4]], [[risingballer-2024#^f5]], [[nba2vec-2023#^f4]]
- C13: Auxiliary targets (game length, gold at 15, duration) and class-based init helped LoLDraftAI only with less data. for: [[loldraftai#^f13]], [[loldraftai#^f14]]
- C14: Label smoothing hurts log loss and AUC; select checkpoints on cross-entropy. for: [[realmlp-2024#^f6]]

## Disagreements

- Net lift: random-split gains (C2: NeuralAC B, Chen B, JueWu B) vs time-split ties
  (C1: jcj C, DraftRec B). Split and size differ together; our forward folds at
  ~230k settle it for us.
- Set vs MLP: Siamese transformer beat MLP (C, LoL, random CV) while ESTA's MLP beat
  set models (B, CS:GO, tiny data). Different inputs (ids vs aggregated features).

## Open

- Modeller: exact configs (dims, depth, dropout, weight decay, lr, schedule, epochs,
  early stopping) of nets that worked on draft or similar tabular data at 1e5-1e6 rows.
- Critic: which "net beats LR" results survive a time split; which used test-set
  checkpointing or random splits?
- Data-efficiency: residual on a GLM offset (CANN), warm starts, pretrained or
  profile-based embeddings, auxiliary targets, distillation: measured gains at small data?
- Structure: DeepSets / attention over a team, antisymmetric team-vs-team: lift?
- Variance: seed spread of small-data nets, ensemble size that pays.
- Leads: CANN-ranked missing interactions (arXiv 2209.08030), LocalGLMnet
  (2107.11059), LinNet lineup embeddings, Dota CBOW pick embeddings, Kim/Jang/Suh
  group-comparison net; auxiliary-target ablations in MOBAs (none found in 2 searches).
