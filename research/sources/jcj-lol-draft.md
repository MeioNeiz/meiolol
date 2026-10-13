---
title: 'jcj1337/lol_draft_project: draft-only LoL win models on a time split (2026)'
url: https://github.com/jcj1337/lol_draft_project
kind: project
commit: 6b6b69cdf645d24ad99f9a377f781dd9e8e46aae
for: [draft-predictor-methods, nn-draft-models]
looked: 2026-10-12
depth: code (README, docs/PROJECT_OVERVIEW.md, outputs/model_comparison results and learning curves; src/draft_models.py, src/draft_features.py, compare_models.py)
relevance: high
grade: C/strong
description: Student project comparing logistic, pairs, FM, XGBoost and transformer draft-only win models on 110k Diamond+ games, tested on the next patch with bootstrap intervals
---
# jcj1337/lol_draft_project: draft-only LoL win models on a time split (2026)

Why: honest held-out numbers for draft-only LoL win prediction, and whether richer
architectures beat a per-role champion strength model.

## Assessment

- Evidence: C. One contributor, 0 stars, created 2026-01, pushed 2026-10-09; results
  committed as CSVs with configs. Overview's style suggests LLM-assisted writing.
- Reasoning: strong. Time split, bootstrap intervals, leak check, admits limits (gaps
  section), learning curves and recency test.
- Interests: none known (student project, no product).
- Weigh: the closest public analogue to meiolol's setup and numbers; small data (110k,
  15k-game test patch) so architecture comparisons only say "no difference at this size".

## Findings

- [method] [stats] Draft-only on patch 16.6 test (15,092 games, trained on 16.1-16.5): every model lands at AUC about 0.554 and 53.5-53.8% accuracy; log loss 0.6883-0.6894 vs constant 0.6930. `docs/PROJECT_OVERVIEW.md` section 7.1 ^f1
  > **Every model finds the same small, real signal**: AUC ≈ 0.555 and ~53.5% accuracy.
- [method] Per-role champion strength logistic regression (L2, C=0.01) is not beaten by pairs, factorization machine or transformer; differences within bootstrap noise. `docs/PROJECT_OVERVIEW.md` ^f2
  > **Nothing beats the per-role tier list yet.**
- [method] XGBoost on the same one-hot inputs is significantly worse (-0.0009 log loss vs strength, CI excludes 0). `docs/PROJECT_OVERVIEW.md` ^f3
  > **XGBoost is significantly worse.** Trees are an inefficient way to represent ~800 small additive champion effects.
- [method] Transformer and FM needed a warm start from the fitted logistic regression; from scratch, mini-batch noise kept the strength part below the logistic optimum. `docs/PROJECT_OVERVIEW.md` section 6.4 ^f4
  > We found this warm start necessary: trained from scratch, mini-batch noise kept the strength part from ever reaching the logistic regression's optimum
- [method] [stats] Symmetry built in: score = side + h(blue, red) - h(red, blue), so swapping teams flips the probability; XGBoost gets both orientations as training rows instead. `docs/PROJECT_OVERVIEW.md` ^f5
  > score = side advantage + h(blue team, red team) − h(red team, blue team)
- [stats] Learning curves have not levelled off at 73k training games; improvement over constant roughly 1.3, 2.0, 2.5, 4.0 (x1000) at 9k, 18k, 37k, 73k games for strength. `docs/PROJECT_OVERVIEW.md` section 7.2 ^f6
  > **No curve has levelled off.** Each doubling of data still improves every model, even the simplest one.
- [data] [stats] Recency weighting by patch age: strong down-weighting (gamma 0.5 or less per patch) hurts, 0.7 about equals no weighting. `docs/PROJECT_OVERVIEW.md` section 7.3 ^f7
  > **Older patches remain useful.** Strong down-weighting (γ ≤ 0.5) hurts.
- [data] [stats] Leak: player season win rates fetched after the games include the predicted game; with them the first transformer reached about 63%, and a one-line higher-team-win-rate rule 62.4%. `docs/PROJECT_OVERVIEW.md` section 3 ^f8
  > The player win rates were downloaded *after* the games were played, so they already included the result of the very game being predicted.
- [data] Data: 110k ranked solo games, NA, EUW, KR, OCE, patches 16.1-16.6, Diamond+ ladder crawl; games under 15 minutes left out of exports. `docs/PROJECT_OVERVIEW.md` section 4 ^f9
  > 110,000 ranked solo/duo games from NA, EUW, KR and OCE
- [stats] Calibration fine but predictions narrow: about two thirds between 45% and 55%, 95% between 40% and 60%. `docs/PROJECT_OVERVIEW.md` ^f10
  > about two-thirds fall between 45% and 55%, and 95% between 40% and 60%.
- [stats] With 15k test games, log loss differences below about 0.0005 are indistinguishable from noise. `docs/PROJECT_OVERVIEW.md` section 10 ^f11
  > Differences below ~0.0005 log loss cannot be distinguished from noise
- [method] A first draft-only attempt gave probabilities clustered near 0.5, called close to random by the author. `README.md` ^f12
  > A draft-only model produced probabilities clustered near `0.5` for most games and behaved close to random.
- [method] (inferred) Its 53.5% / AUC 0.554 at 73-110k games matches meiolol's 53.3-53.5% / AUC 0.550 at 90k almost exactly, so meiolol is at the honest draft-only level for that data size. ^f13

- [method] Transformer: score = side + h(blue, red) - h(red, blue), h = per-role champion strength (embedding of size 1 per champion x role) + an interaction module; interaction is a pre-norm transformer encoder over 10 picks (champion + role + team embeddings, a CLS token), width 32, 2 layers, 4 heads, feed-forward 64, dropout 0.1, LayerNorm and a linear head initialised to zero. `src/draft_models.py` ^f14
  > def __init__(self, n_champs: int, d: int = 32, layers: int = 2, heads: int = 4, ff: int = 64, dropout: float = 0.1):
  > nn.init.zeros_(self.head[1].weight)
- [method] FM interaction: champion vector of size k (std 0.01 init) plus a role vector; synergy = per-role-pair weight times dot product over teammate pairs, matchup = per-role-pair weight times e_i K e_j over enemy pairs, K initialised to 0.1 times identity. `src/draft_models.py` ^f15
  > matchup(us, them) = sum over enemy pairs (i, j)  of b_ij * e_i^T K e_j
- [method] Warm start: before training, side and strength terms are set to a scikit-learn L2 logistic regression with the same penalty (C = 1 / (2 lam_strength)); epoch 0 (pure LR) is kept if interactions never improve validation loss. `src/draft_models.py` ^f16
  > """Set side advantage + strengths to the logistic regression with the same L2 penalty."""
  > # epoch 0 = the warm start (pure logistic regression); kept if interactions never help
- [method] Optimiser: Adam with two parameter groups, strengths at lr 1e-3 (only fine-tuned) and interactions at their own lr; L2 penalties scaled by 1/N added to each mini-batch loss, on weights and embeddings only (lam_strength 50, equal to sklearn C=0.01). No schedule, no gradient clipping. `src/draft_models.py` ^f17
  > lam_strength: float = 50.0      # times 1/N; equals sklearn C=0.01 for the strength term
- [method] Grids: FM k in {4, 8} x lam_interaction in {5, 20}, lr 1e-3, batch 1024, up to 30 epochs, patience 5; transformer width 32, lam_interaction in {1, 5, 20}, lr 1e-3, batch 512, up to 30 epochs, patience 3; early stopping on validation log loss, best epoch restored. `src/draft_models.py` ^f18
  > NetConfig(lam_interaction=c, k=32, lr_interaction=1e-3, batch_size=512, max_epochs=30, patience=3)
- [method] [stats] Selected configs: FM k=4, lam 20, best at epoch 14; transformer lam 1, best at epoch 2, i.e. the transformer barely moved from the LR warm start before validation loss turned. `outputs/model_comparison/configs.json` ^f19
  > "patience": 3, "lam_strength": 50.0, "epochs": 2
- [stats] Protocol: tune on train with validation = latest 40% (per platform, by time) of the second-latest patch, then refit on train + validation for the chosen number of epochs and score the latest patch. `src/draft_features.py`, `scripts/compare_models.py` ^f20
  > val   = the latest `val_frac_of_second_latest` of the second-latest patch, per platform
  > model.refit(trainval_df)
- [method] [stats] Test log loss (patch 16.6): LR strength 0.68851, LR with pair one-hots 0.68834, FM 0.68861, transformer 0.68847, XGBoost 0.68943; accuracy 53.5%, 53.6%, 53.8%, 53.6%, 53.6%. `outputs/model_comparison/results.csv` ^f21
  > transformer,test,0.6884658761876226
- [method] No augmentation: the nets are antisymmetric by construction, so side swap is not needed; only XGBoost trains on both orientations. Unseen champions map to id 0. `src/draft_models.py` ^f22
  > Every model is symmetric between the two teams: swapping blue and red turns P into 1 - P,

## Read

- `README.md`, `docs/PROJECT_OVERVIEW.md` in full, `outputs/model_comparison/results.csv`,
  `learning_curves.csv`
- 2026-10-13: `src/draft_models.py` in full, `src/draft_features.py` (split, features),
  `scripts/compare_models.py` (main protocol), `configs.json`

## Not read

- bootstrap CSVs, `reports/*.pdf`, `scripts/grid_search_transformer.py` (earlier
  transformer with player numeric features); no results yet on the new 250k-per-day collector data
