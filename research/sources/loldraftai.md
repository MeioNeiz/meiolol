---
title: LoLDraftAI public monorepo archive (May 2025 state)
url: https://github.com/Looyyd/loldraftai-monorepo-public
kind: project
commit: 10e7e2f86a0a0d0efb71ea3e3b128a96cd89d105
for: [riot-production-key, draft-predictor-methods]
looked: 2026-10-11
depth: code (README, data-collection rate limiter, desktop footer, blog posts, apps/machine-learning model, data prep, training)
relevance: high
grade: C/fair
description: Public archive of LoLDraftAI: deep learning draft win predictor trained on Riot API ranked matches, with desktop app
---
# LoLDraftAI public monorepo archive (May 2025 state)

Why: the nearest precedent to meiolol's design (ML model trained on Riot ranked match data, desktop champ select app); how does it collect data and present itself to Riot?

## Assessment

- Evidence: C. Single contributor, 8 stars, archive created 2025-08, code state May 2025 (later development private). The live product is still running (see [[loldraftai-site]]).
- Reasoning: fair. README and blog are candid about metrics and a data bug.
- Interests: commercial product's own repo.
- Weigh: shows exactly the meiolol pattern in production; nothing in the repo says whether or how Riot approved it, so the production key is inferred from rate limits only.
- Weigh (method): its 55-56% is a random file-level split on recent patches, after dropping AFK and stomp games via 15-minute stats, with the checkpoint chosen on that same split; a time-split number on unfiltered games would be lower. Code is real and readable (PyTorch, W&B), single author.

## Findings

- [tools] [method] Hosts a deep learning model predicting match outcome from draft only; desktop app downloadable. `README.md` ^f1
  > hosts a deep learning model that predicts and analyzes League of Legends matches from draft only.
- [data] Collects summoners and matches from the Riot API into Postgres, exported to parquet for training. `README.md` ^f2
  > A Postgresql database(Standard_B4ms (4 vCores)) for storing the league api data(Summoners and Matches).
- [data] [policy] Match collector is rate limited at 100 requests per 10 seconds, above development key limits. `apps/data-collection/src/scripts/processMatches.ts` ^f3
  > reservoir: 100,
  > reservoirRefreshInterval: 10 * 1000,
- [policy] (inferred) 100 requests per 10 s far exceeds a development key's 100 per 2 minutes, so the collector almost certainly runs on a production (or at least personal-with-raised-limits) key. Not confirmed anywhere in the repo. ^f4
- [policy] Desktop app and site carry Riot's "isn't endorsed" boilerplate. `apps/desktop/src/components/Layout.tsx` ^f5
  > LoLDraftAI isn't endorsed by Riot Games and doesn't reflect the
- [method] Reported draft-only model accuracy 56.1% (solo queue), 56.8% (pro). `README.md` ^f6
  > Accuracy: 56.1%
- [data] A region-default bug duplicated EUW matches across regions, inflating claimed accuracy until fixed (to 55%). `correction-reddit-post/page.tsx` ^f7
  > This new model has an accuracy of 55%.
- [policy] Checked, not there: no mention of Riot approval, production key, RSO, Vanguard or removed features in README or grep of md/ts/tsx/py. ^f8

- [method] Model: learned embeddings for each of the 10 champions (126 dims), a patch (64), a champion x patch pair (2 dims), elo and queue (32 each), concatenated in fixed role order and fed to an MLP. `apps/machine-learning/utils/match_prediction/model.py` ^f9
  > mlp_input_dim += config.champion_embed_dim * 10  # 10 champions
- [method] Champion x patch embedding kept tiny because larger overfits. `config.py` ^f10
  > 2  # Needs to be small to avoid overfit, was 4 before and that's fine.
- [method] Default MLP: 11 layers 1024 down to 64, dropout 0.5, AdamW weight decay 0.05, one-cycle LR 8e-4, 50 epochs, batch 20480 on GPU. `config.py`, `utils/match_prediction/__init__.py` ^f11
  > self.dropout = 0.5
  > self.weight_decay = 0.05
- [method] (inferred) The "residual" add only fires when consecutive layer widths match, so in practice only between the equal-width 512 and 256 layers. `model.py` ^f12
  > if x.shape == residual.shape:  # Only add residual if shapes match
- [method] Multi-task: win loss weight 1, four game-length-bucket win heads at 0.1, ten gold-at-15 heads sharing 0.1, game duration 0.01. `task_definitions.py` ^f13
  > gold_task_weight = 0.1 / gold_tasks_count
- [method] Richer priors and auxiliary tasks (class-based init, adjacent-patch smoothing, kills, damage) helped only with less data and were dropped at tens of millions of games. `apps/machine-learning/README.md` ^f14
  > With a lot of training data(in the tens of millions) they are not beneficial, however with less data they did bring slight improvements.
- [method] [data] Augmentation is random masking of champions to an unknown token (draft order is not in the API): 20% of chunks unmasked, 7-9 masked 15% each; one mask count per chunk, not per game. `masking_strategies.py`, `match_dataset.py` ^f15
  > self.probabilities[0] = 0.20  # No masking
  > num_to_mask = self.masking_function()
- [method] [data] Checked, not there: no blue/red side swap or role permutation augmentation anywhere in training, dataset or model code; side is implicit in slot order. ^f16
- [data] Training window: the last 52 patches, with patches under 10,000 games merged into the previous one; raw download defaults to the last 3 months. `prepare_data.py`, `download_data.py` ^f17
  > NUM_RECENT_PATCHES = 52  # Number of most recent patches to use for training
- [data] Rank is an average tier bucket of 7 values from Silver I to Master+; queues are solo (420) and Clash (700) together. `column_definitions.py` ^f18
  > possible_values_elo = [0, 1, 2, 3, 4, 5, 6]
- [data] [stats] Train and test drop games where any player has under 2400 gold, over 10 deaths, under 25 CS (non-support) or under level 4 at 15 minutes, which also removes every game ending before 15:00. `prepare_data.py` ^f19
  > MAX_DEATHS_15MIN = 10  # Maximum deaths at 15 minutes
- [stats] (inferred) Those filters use in-game information unknown in champ select and remove stomps and AFK games from the test set too, so reported accuracy is on easier, cleaner games than the tool sees live. ^f20
- [stats] Default split is a seeded random 90/10 by export file, not by time; an optional next-patch mode tests on the 2 newest patches mapped to the third newest. `prepare_data.py` ^f21
  > # 90/10 split at file level
  > - This allows testing how well the model generalizes to future patches
- [data] Checked, not there: no dedup by matchId in data prep beyond dropping rows whose matchId prefix differs from region (the fix for the duplication bug). `prepare_data.py` ^f22
  > Filter out games where matchId prefix doesn't match region
- [stats] The checkpoint kept is the epoch with best loss on the same test split that reports accuracy, so the test set doubles as validation. `train.py` ^f23
  > if val_loss < best_metric:
- [stats] Reported solo queue figures: win log loss 0.684 after the fix (constant 0.693) and calibration buckets over about 783k validation games, 50-55% predicted bucket 428,768 games at 0.525 actual. `correction-reddit-post/page.tsx` ^f24
  > The loss of the new model is of 0.684 for the win prediction task
- [stats] The duplication bug had made true accuracy 52% while claims were higher; README later states loss 0.681, accuracy 56.1% at epoch 46. `correction-reddit-post/page.tsx`, `README.md` ^f25
  > the true accuracy was 52% and the model was too confident, giving extreme predictions.
  > Validation Loss: 0.681
- [tools] [stats] The DraftGap vs LoLDraftAI accuracy comparison was withdrawn because validation data leaked into training. `draftgap-vs-loldraftai-comparison/page.tsx` ^f26
  > this blog post statistical validation part has been removed, because part of the validation data was in the training set.
- [method] Pro model: fine-tune with a new queue embedding, other embeddings frozen, mixing in solo queue data to avoid catastrophic forgetting. `apps/machine-learning/README.md` ^f27
  > The model is finetune while keeping a significant portion of data from solo queue matches, to avoid catastrophic forgetting

## Read

- `README.md`, `processMatches.ts` lines 1-70, desktop `Layout.tsx` footer, correction blog post; grep for policy terms over the repo
- 2026-10-12: `apps/machine-learning` README, model, config, masking, dataset, column and task definitions, `prepare_data.py`, `train.py` (loop, validation, checkpointing), `download_data.py`; DraftGap comparison post

## Not read

- `apps/desktop` LCU integration details; `train_pro.py`, `validation.py` (subgroup and calibration report, marked as needing update), `adapt_model.py`; W&B runs (external)
