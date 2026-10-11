---
title: From Outcome Prediction to Advantage Construction (SBGames 2026)
url: https://sol.sbc.org.br/index.php/sbgames/article/download/45416/45177/
kind: paper
commit:
for: [riot-api-data-depth]
looked: 2026-10-11
depth: docs (abstract, sections 1-5.1)
relevance: medium
grade: C/fair
description: UDESC paper turning match-v5 match plus timeline data into minute-level states for win probability and short-horizon event forecasts
---
# From Outcome Prediction to Advantage Construction (SBGames 2026)

Why: what a per-minute win-probability or "where did the game turn" feature can be built
from timelines, and how well it works.

## Assessment

- Evidence: C. Conference short paper, Challenger only, 450 test matches; no comparison
  with simpler baselines (authors admit this).
- Reasoning: fair. Clear causal rule (only data up to minute k), reports calibration
  and risk sets; spatial layer is exploratory.
- Interests: academic.
- Weigh: shows feasibility and rough accuracy by minute; numbers from a small Challenger
  sample, would differ for Silver to Emerald.

## Findings

- [data] [method] Match plus timeline data can be rebuilt into per-minute states using only
  information up to that minute, mixing composition, gold, xp, farm, vision, position,
  objectives, structures and items. ^f1
  > Match and timeline data are reconstructed into minute-level states using only information observable up to each minute.
  > observed-state features describe gold, experience, combat, farming, vision, position, objectives, structures, and itemization
- [method] [learning] Win probability by minute: ROC AUC 0.821 at 15 minutes, 0.872 at 20. ^f2
  > The state-estimation model reached 0.821 ROC AUC at 15 minutes and 0.872 at 20 minutes.
- [data] Dataset: Challenger ranked matches pulled from the Riot API with match details and
  timelines; evaluation on 450 test matches. ^f3
  > The dataset is built from Challenger-ranked matches through the LoL Developer’s (Riot Games) Application Programming Interface (API)
  > The state-estimation evaluation uses 450 test matches.
- [learning] [ux] Authors frame the useful output as the probability path through the game
  (when it became favourable), not a single prediction. ^f4
  > The model’s main value is not one isolated prediction, but the probability path that shows how the match moves from uncertainty toward a more stable state.
- [method] Short-horizon forecasts of next events (fights, towers, objectives) are weak:
  weighted F1 0.536 at 1 minute, 0.678 at 5 minutes. ^f5
  > Forecasting improved from 0.536 weighted F1 at a 1-minute horizon to 0.678 at 5 minutes.
- [method] Gold is predictive but treated as an outcome of farming, kills and objectives,
  not as the explanation. ^f6
  > Gold is treated as an emergent macroindicator rather than as the explanatory center.

## Read

- Abstract, introduction, related work, methodology, state-estimation results

## Not read

- Forecasting tables by event type, spatial attribution results (39 matches): exploratory
