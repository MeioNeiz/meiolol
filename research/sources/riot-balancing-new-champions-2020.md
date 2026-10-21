---
title: 'Riot 2020: /dev: Balancing New Champions'
url: https://www.leagueoflegends.com/en-us/news/dev/dev-balancing-new-champions/
kind: docs
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: docs (whole post)
relevance: high
grade: B/fair
description: Riot Summoner's Rift team (6 Jul 2020) on mastery curves and why new champions and VGUs now launch at their long-term balance, so their win rates start low and climb as players learn them
---
# Riot 2020: /dev: Balancing New Champions

Why: the playerbase learning curve after a release or rework: how large and how long,
from the only party with all the data.

## Assessment

- Evidence: B. Riot's balance team, first-hand, on internal data; the mastery curve
  figure is not reproduced in the snapshot and no per-champion numbers are given beyond
  the rules of thumb.
- Reasoning: fair. Explains the trade-off and both approaches; numbers are rough.
- Interests: Riot justifying weak launches to players.
- Weigh: trust the direction and order of size (a few points over the first weeks);
  measure the shape on our own games when a new champion or VGU lands.

## Findings

- [method/dynamics] [stats] A champion's early win rate understates its power while
  players learn it; Riot balances new releases on a projected mastery curve, not on
  launch win rate. Understanding Champion Mastery Curves ^f1
  > This means that a champion’s early win rate alone doesn’t necessarily reflect their “real” power level.
- [method/dynamics] [stats] Size: even an easy champion gains about 4% win rate over a
  player's first ~15 games on it, and hard ones (Yasuo, Katarina, Nidalee) keep rising
  to the 100th game and beyond. ^f2
  > Even an easy-to-learn champion with a low mastery curve will likely increase in win rate by 4% over the first ~15 games played.
  > players learning new champions will sometimes continue to see growth up to (or beyond) their 100th game
- [method/dynamics] Since 2020 (from Fiddlesticks), new champions and VGUs launch at
  their long-term balance, so they look weak at first and climb; before that they were
  tuned to be on par after two weeks live. ^f3
  > We now release new champions and VGUs at what we believe to be their long-term balance state
  > we’ve released new champions such that their win rates were on par with other champs once they’d been live for two weeks
- [method/dynamics] [stats] The opponents learn too: Neeko lost win rate after her first
  week as players learned to play against her, so a release has two learning curves
  with opposite signs. ^f4
  > there was even a pronounced “playing against the champion” learning curve, where we actually saw her start to lose win rate after her first week
- [method/dynamics] [stats] Rules of thumb: 55% in the first patch should not happen,
  and under 45% in the first days can mean a lasting problem for a champion with a long
  mastery tail; nerf cycles after release used to run 6-12 months. ^f5
  > Champions winning 55% of their games within the first patch shouldn't happen
  > the extended cycle of nerfs that often persist for 6–12 months after the release of a champion
- [method/dynamics] (inferred) For a dynamic champion model: a release or VGU is a
  known change point with an expected rising trend (a linear or saturating kernel on
  days since release), not a random walk; much of that trend is the mix of players'
  games on the champion, which our mastery terms (lanecard.Expertise) already partly
  carry. ^f6
- [method/dynamics] Checked, not there: no time course for ordinary balance patches
  (only releases), no per-champion curves in text. ^f7

## Read

- Whole post (6 Jul 2020).

## Not read

- Mastery curve chart (image), the 2020 balance framework update linked as Blog 1.
