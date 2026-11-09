---
title: 'LoLTheory blog: What is LoLTheory? (Apr 2026, updated Aug 2026)'
url: https://blog.loltheory.gg/what-is-loltheory/
kind: article
commit: 
for: [champselect-advice-methods]
looked: 2026-11-07
depth: docs (whole post)
relevance: high
grade: C/fair
description: LoLTheory founder's product overview: champ select score = win rate minus risk, three experience modes (personalised from last 10 patches, fixed 25 games, classic raw), flex-pick lane probabilities, ban advice weighted by pick likelihood, builds optimised as a package
---
# LoLTheory blog: What is LoLTheory? (Apr 2026, updated Aug 2026)

Why: the most method-explicit commercial draft tool; what it ranks by and how it handles
player experience and uncertainty.

## Assessment

- Evidence: C. Vendor's own blog by its founder (self-described ex-Master, data science
  background); no figures, no held-out results.
- Reasoning: fair. Names the biases it corrects and its modes; never says how risk or the
  experience adjustment is estimated.
- Interests: vendor; free champ select, paid overlay.
- Weigh: trust as a description of what the app shows; claims of correcting bias are
  unverified.

## Findings

- [tools] [method] Champ select ranking: a win rate and a score per champion, live as both
  teams pick; score is win rate minus a "risk" term for the chance the pick hurts the team. ^f1
  > Score = win rate minus risk, where risk is the quantifiable chance a pick could hurt your team.
- [method] [draft] Ban advice weighs both how well an enemy champion does against your team
  and how likely the enemy is to pick it, using teammates' hovers. ^f2
  > accounting for both how well the enemy champion performs against your team and how likely the enemy is to actually pick it.
- [method] [draft] Flex picks: enemy lane probabilities enter both win rate and score, and are
  shown on hover. ^f3
  > The system factors in the chance enemies don't go to their expected lane, adjusting both win rate and score calculations.
- [method] [stats] Own-pool input: Personalised mode uses the player's ranked history from the
  last 10 patches; Fixed assumes 25 games on every champion; Classic uses raw win rates and
  is called the most responsive to meta shifts. ^f4
  > Personalized — uses your ranked game history from the last 10 patches.
  > Fixed — assumes 25 games on every champion.
  > Classic — works from raw win rates without experience adjustments. The most responsive to meta shifts.
- [method] Builds (runes, items, spells, skills) are optimised together for the matchup, not
  taken from separate highest-win-rate lists; locking one item re-optimises the rest. ^f5
  > Runes, items, summoner spells, and skill order — recommended as a single package, not independently.
- [method/causal] (claim) Item recommendations correct biases in raw item win rates: snowball
  items, defensive items, player experience. ^f6
  > snowball items, defensive items, and player experience effects all distort raw win rates.
- [tools/paid] Champ select features free without limits; the in-game overlay has a free tier
  (1 game a day, stackable to 5), premium unlimited. ^f7
  > Champion select features are fully free with no limits.
- [stats] [ux/uncertainty] Checked, not there: no game counts, minimum sample, intervals,
  accuracy, log loss or held-out test; "risk" is not defined beyond the sentence in ^f1. ^f8

## Read

- Whole post

## Not read

- Recommendation modes post is noted as [[loltheory-recommendations]]
