---
title: 'iTero: Pro AI Predicted Champion Tier List, Patch 12.11 Results (Jul 2022)'
url: https://www.itero.gg/articles/tier-list-results
kind: article
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (whole article text; result tables are images, not read)
relevance: low
grade: D/fair
description: iTero (vendor) scores its own pre-patch champion tier list for pro play on patch 12.11 against the patch's games in the four major leagues; one patch, a few hundred games, the top tier lost
---
# iTero: Pro AI Predicted Champion Tier List, Patch 12.11 Results (Jul 2022)

Why: an example of a per-patch champion forecast declared before the games and scored
after. Skipped on 23 Oct for the draft-method question (no method, tiny samples); read
here only for the forecast-then-score format and its result.

## Assessment

- Evidence: D. One patch, pro play only, 15 to 274 games per tier, no intervals, no
  baseline (last patch's win rate would be the obvious one), model undescribed.
- Reasoning: fair. States the rule before the games, shows the miss, corrects raw win
  rate for team strength with bookmaker odds.
- Interests: vendor (sells a companion app); the article is marketing.
- Weigh: the format (declare, wait, score, publish the misses) is sound; the numbers
  carry nothing. Whether the series went on past 12.12 was not checked.

## Findings

- [method/dynamics] The forecast is declared before the patch is played and scored
  after: a tier per champion for pro play, pass when each tier outperforms the one
  below. ^f1
  > "Once all the major regions have finished playing on said patch, we’ll compare the predictions to the actual results."
- [method/dynamics] [stats] Result on 12.11: A 53.4%, B 52.9%, C 48.6%, D 20%, but the
  top tier lost (S 46.7%), sunk by one champion (Volibear jungle, 24 games, 37.5%). ^f2
  > "The only outlier was S-tier where the win rate was 46.7% for the Champions that should have been our strongest performers."
- [method/causal] Raw win rate is corrected for who picks the champion: wins divided by
  the wins bookmaker odds expected of the teams that played it. ^f3
  > "Because it’s being played only by the best teams, **the win rate is inflated** not by the performance of the Champion but by the strength of the team!"
- [method/dynamics] Checked, not there: no description of the model or of what it reads
  from the patch (notes, stat diffs, previous results), no baseline forecast, no
  intervals, no score over several patches. ^f4
- [method/dynamics] (inferred) Tiers of a few hundred pro games cannot tell a forecast
  from luck (a 24-game champion moved the top tier 7 points). Our own declared test on
  16.23 scores tens of thousands of games a day, per champion-role, against A1 and A2:
  the format is the same, the power is not. ^f5

## Read

- Whole article text.

## Not read

- Result tables (images) and the 12.12 list; https://itero.gg/esports/tier-list-results
  (accumulated results, if it still exists).
