---
title: 'Bilalic, Gula and Vaci 2021: Home advantage mediated (HAM) by referee bias and team performance during covid (Sci Rep)'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC8566522/
kind: paper
commit:
for: [draft-mediation]
looked: 2026-10-13
depth: docs (main text and methods; SI not read)
relevance: medium
grade: B/fair
description: Sport application of mediation; 4,356 soccer matches 2019/20 in 12 leagues, Bayesian mixed-effects path model (latent team performance and referee decisions as mediators of home venue on result), Covid empty stadia as moderator; pre-match team rating as control
---
# Bilalic, Gula and Vaci 2021: Home advantage mediated (HAM) by referee bias and team performance during covid (Sci Rep)

Why: the closest sport analogue found: a pre-game factor (home venue) whose effect on the
result is split into in-game mediators (shots, corners, cards) with pre-match team
strength as a control. Shows what sport mediation looks like in practice, and its
typical shortcuts.

## Assessment

- Evidence: B. Scientific Reports, open data source (fbref), 4,356 matches; descriptive
  numbers agree with several independent Covid home-advantage papers; follow-ups
  (handball, Euro 2020) reused the model.
- Reasoning: fair. Clear model and robustness checks (alternative causal order, game
  level), but a linear latent path model (product of coefficients) on team-season
  aggregates, no sensitivity analysis for mediator-outcome confounding, and the in-game
  "performance" mediator is partly the outcome itself (shots lead to goals).
- Interests: authors propose and name the model.
- Weigh: use as an example of the design and of where it is weak; do not reuse its
  estimator for a binary win outcome.

## Findings

- [method] HAM: venue affects the outcome directly and through team performance and
  referee decisions; performance also affects referees. Introduction ^f1
  > Here we propose a new theoretical model to simultaneously investigate the direct and indirect effects of the home venue and crowd on the HA
- [method] Earlier work treated in-game performance (shots, dominance) as a proxy for the
  outcome rather than a separate mediator. Introduction ^f2
  > the team performance indicators (e.g. number of attacks, shots—in one word, dominance) are often taken as proxies for the outcome. They are, however, a crucial independent factor that needs to be separated from the actual outcome.
- [stats] Data: 4,356 matches, 224 teams, 12 leagues, 1,131 behind closed doors. Results ^f3
  > In the 2019/20 soccer season, 4356 matches were played by 224 individual teams in 12 different leagues in 8 different European countries
- [stats] Indirect effect of venue through team performance 0.26 with fans vs 0.12
  without; through referees 0.03 vs -0.01; total 0.57 vs 0.36. Results ^f4
  > it was significantly larger when the teams were playing with the fans present (0.26 vs. 0.12—see the upper left box in Fig.  4 )
  > was also (significantly) smaller by almost a third when the fans were absent (+ 0.36) than when they were present (+ 0.57).
- [method] Estimator: Bayesian mixed-effects conditional process analysis (path model on
  latent factors, moderated mediation), teams nested in leagues; pre-match team rating
  (FiveThirtyEight SPI) and match importance as controls on all paths. Methods ^f5
  > The specified model was then analyzed using conditional mixed-effects process analysis 60 in the Bayesian framework 78 .
  > Both were assumed to influence the Outcome directly, as well as indirectly through Team Performance and possibly Referee’s Decisions.
- [method] Unit of analysis is team aggregates per venue and period, not games (games in
  the SI). Results ^f6
  > The smallest units presented here are individual teams and their aggregated results (points and goals) when they played at home and away during the pre- and post-Covid periods
- [method] The order between mediators (performance vs referees) could not be settled from
  season aggregates; possession as a common earlier mediator was tried. Discussion ^f7
  > The direction of the relation between team performance and referees’ bias may be too difficult to disentangle at the macro level of a season.
- [method] Checked, not there: no sensitivity analysis for unmeasured mediator-outcome
  confounding and no counterfactual (natural or interventional) effect definitions;
  indirect effects are path coefficient products. Methods ^f8
- [method] (inferred) For us: the same shape (pre-game factor, in-game mediators, pre-game
  strength control) applied to LoL: draft -> 14:00 state -> win, with player or team
  rating as a control on every path. Their unresolved mediator ordering is our gold vs
  objectives problem, which interventional effects sidestep. ^f9
- [method] (inferred) For us: no sport or esports paper found uses counterfactual
  mediation with a binary result and a sensitivity analysis; a meiolol analysis would be
  new, so method choices must come from the epidemiology sources. ^f10

## Read

- Main text, figure captions, methods.

## Not read

- Supporting information (game-level analysis, alternative causal orders, fit).
- Follow-ups: handball HAM, Euro 2020 HAM.
