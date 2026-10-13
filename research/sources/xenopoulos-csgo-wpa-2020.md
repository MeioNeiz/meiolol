---
title: 'Xenopoulos, Doraiswamy and Silva 2020: Valuing player actions in CS:GO (win probability added)'
url: https://arxiv.org/pdf/2011.01324
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (sections IV-VI)
relevance: medium
grade: B/fair
description: NYU 2020 (IEEE BigData) CS:GO paper; XGBoost round win model on 55M game states, each damage event valued as the win probability change it causes, summed per player as WPA, bootstrap spreads
---
# Xenopoulos, Doraiswamy and Silva 2020: Valuing player actions in CS:GO (win probability added)

Why: the clearest esports write-up of win probability added (WPA) per event: how the value
is defined, what the state model conditions on, how uncertainty is reported.

## Assessment

- Evidence: B. Established esports analytics group (awpy); 4,682 LAN matches, 55M train
  and 18M test game states split by date; calibration plot, log loss and Brier reported.
- Reasoning: fair. States its assumptions (similar-skill teams, damage events only) and
  how credit splitting is unsolved; no test of whether WPA per event is biased by state.
- Interests: academic, promotes its own data model and library.
- Weigh: trust the recipe (state model, delta, sum, bootstrap); the event values are
  only as good as the state model's calibration, and the paper says so.

## Findings

- [method] An action's value is the change in estimated win probability between the state
  before and after it; a player's WPA is the sum over all their actions, per round.
  Section IV-B, eq. 5 ^f1
  > We can value the player’s action as the difference in win probability between the two states
  > we can tabulate their Win Probability Added (WPA), defined as the sum of the player’s total action values over all games.
- [method] The victim side is credited with the negative of the value, so values are
  zero-sum between the two teams. Section IV-B ^f2
  > The player on the receiving side of the action (e.g. the player receiving damage) is credited with the negative of V (ai,t ).
- [method] [stats] State model chosen for calibration, because WPA depends on calibrated
  probabilities; XGBoost beat logistic regression and CatBoost (Table II: log loss 0.5353, AUC 0.79).
  Section IV-C, V ^f3
  > Since WPA is highly dependent on obtaining good estimates
  > XGBoost seemed to produce the most well calibrated probabilities
  > We see that all models perform significantly better than the map average benchmark, and that XGBoost performs the best across all metrics.
- [stats] Adjacent states are highly correlated; they rely on a date-split test set
  rather than thinning to one state per round. Section V ^f4
  > many of the training examples are highly correlated, such as adjacent game states.
  > given that the test data is completely independent from the training data
- [stats] Uncertainty by bootstrap: resample rounds with replacement, 100 samples, and
  report the spread of mean WPA per round. Section VI-B ^f5
  > we resample each round a player has taken part in, with replacement. Then, we calculate a player’s WPA per round.
  > using 100 bootstrapped samples.
- [method] The value function takes any two states, so it can value a sequence of
  actions (a whole play) as well as a single event. Section VI-C ^f6
  > Because the value function in Equation 5 takes two arbitrary game states as arguments, we can apply this function on two non-sequential game states.
- [method] Credit for team events (a bomb plant against three defenders) has no clear
  split between players; left as future work. Section VI-D ^f7
  > Oftentimes, these events can have unclear attributions.
- [method] The win model ignores team strength: WPA assumes both teams are of similar
  skill, and they suggest pre-match betting lines or rankings as a fix. Section VI-D ^f8
  > a strong assumption of the WPA framework is that analyzed teams are of similar skill categories.
  > One method to explore in the future is using pre-match betting spread or rankings in the win probability model
- [stats] WPA was more stable month to month (0.40) than KDR (0.38) or HLTV Rating 2.0
  (0.29) for 479 players with 100+ rounds a month (numbers from Table IV). ^f9
  > WPA ATTAINS THE HIGHEST MONTH TO MONTH (M- TO -M) CORRELATION , INDICATING ITS STABILITY.
- [method] (inferred) WPA conditions on the state, so a tower taken while far ahead is
  valued against a win chance already near 1 and gets little; that removes "already
  ahead" only as far as the state model captures the lead (gold, towers, kills). Any lead
  the model misses (better players, better comp) leaks into the event's value. ^f10
- [method] (inferred) For us: per event type, mean of win(after) minus win(before) over
  all occurrences, bootstrap over games for intervals, our win-by-minute model as the
  state model. Adding draft win chance and average rank to the state is the analogue of
  their betting-line fix. ^f11

## Read

- Sections IV (framework, win model), V (results, calibration), VI (discussion)

## Not read

- Section III data model and graph distance (CS:GO specific)
