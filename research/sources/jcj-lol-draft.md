---
title: 'jcj1337/lol_draft_project: draft-only LoL win models on a time split (2026)'
url: https://github.com/jcj1337/lol_draft_project
kind: project
commit: 6b6b69cdf645d24ad99f9a377f781dd9e8e46aae
for: [draft-predictor-methods]
looked: 2026-10-12
depth: code (README, docs/PROJECT_OVERVIEW.md, outputs/model_comparison results and learning curves)
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

## Read

- `README.md`, `docs/PROJECT_OVERVIEW.md` in full, `outputs/model_comparison/results.csv`,
  `learning_curves.csv`

## Not read

- `src/draft_models.py`, `src/draft_features.py` (code behind the overview), bootstrap CSVs,
  `reports/*.pdf`; no results yet on the new 250k-per-day collector data
