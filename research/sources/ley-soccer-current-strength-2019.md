---
title: 'Ley, Van de Wiele, Van Eetvelde 2019: Ranking soccer teams on basis of their current strength, a comparison of maximum likelihood approaches'
url: https://arxiv.org/pdf/1705.09575v2
kind: paper
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: docs (sections 1-2, 4.1, 5.1; Tables 1-2)
relevance: high
grade: B/strong
description: Statistical Modelling 2019 (Ghent, DeepMind); ten strength models fitted by time-weighted likelihood with a half-period decay, half period tuned per model on forward predictions of 3,230 EPL and 3,868 European national team matches; win-only Bradley-Terry wants the longest memory
---
# Ley, Van de Wiele, Van Eetvelde 2019: Ranking soccer teams on basis of their current strength, a comparison of maximum likelihood approaches

Why: how strong should time decay be, measured on forward predictions, and does the best
decay depend on how much information each game carries?

## Assessment

- Evidence: B. Peer-reviewed (Statistical Modelling), basis of later World Cup
  forecasts; 17 EPL seasons, 16 years of national team games; grid search of the half
  period with forward rolling predictions.
- Reasoning: strong. Same weighting for every model, a no-skill baseline (Majority), and
  two scores.
- Interests: none known.
- Weigh: the half periods are football's; the transferable result is the ordering (less
  information per game, longer memory) and that grid-edge optima mean "no decay" was
  not tested.

## Findings

- [method/dynamics] Time decay as weighted likelihood: weight = (1/2)^(days ago / half
  period), so a game one half period old counts half. Section 2.1 ^f1
  > a match played Half period days ago only contributes half as much as a match played today
- [method] [stats] Protocol: within each EPL season, predict every second-half round
  from the games before it, refitting after each round; half period tried from 20 to
  600 days in steps of 20 (national teams 100 to 1500). Sections 4.1, 5.1 ^f2
  > In all our models, the Half Period is varied between 20 and 600 days in steps of 20.
- [method/dynamics] [stats] Win-only Bradley-Terry picks the longest memory on the grid
  (EPL 540-600 days, the grid's top; national teams 1400-1500, also the top), while
  goal-based Poisson models, with more information per game, pick 180-300 days. Table 1,
  Table 2 ^f3
  > It is also noteworthy that the best two models have among the lowest Half Periods.
- [method/dynamics] (inferred) The less a single outcome tells you, the longer the
  memory a forecast wants: a binary result needs many old games to pin a strength down,
  and decaying them costs more variance than the drift it removes. Our draft outcome is
  far noisier than a football result, which fits our null for half-lives of 3-7 days
  (docs/model.md hl3, hl7) and jcj's "gamma 0.5 per patch hurts". ^f4
- [method] [stats] Parsimony wins: one strength per team beats two or three; Bradley-
  Terry with separate home and away strengths is worse than the no-skill Majority
  method on log loss (1.0845 vs 1.0387). Table 1 ^f5
  > Finally we remark that the BT model with home and away parameters does worse than the Majority method according to the log loss criterion.
- [method/dynamics] Checked, not there: no "no decay" (infinite half period) arm for
  the models that hit the grid edge, no state-space comparison, no known change points
  (transfers are handled by fitting each season separately). ^f6

## Read

- Abstract, sections 1-2, 4.1 (Table 1), 5.1 (Table 2).

## Not read

- Bookmaker comparison, EURO 2016 simulation, rankings.
