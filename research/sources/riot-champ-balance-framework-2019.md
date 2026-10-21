---
title: '/dev: Champion Balance Framework (Riot, 2019)'
url: https://www.leagueoflegends.com/en-au/news/dev/dev-champion-balance-framework/
kind: article
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: listed (whole post)
relevance: high
grade: A/fair
description: Riot's published rules for flagging champions as over or underpowered: raw win rate bands by skill audience, tightened by ban rate; pick rate trusted only at the top; mastery curves deliberately left out
---
# /dev: Champion Balance Framework (Riot, 2019)

Why: does Riot's balance team adjust win rates for who picks a champion (mastery, skill),
or use raw win rates?

## Assessment

- Evidence: A. Riot's own statement of the rule its balance team uses; years of patches
  follow it (the 2020 update says so).
- Reasoning: fair. Explains each audience and why mastery is left out; no statistics on
  how noisy or confounded the win rates are.
- Interests: Riot defending its balance calls to players.
- Weigh: it shows what Riot measures, not that raw win rate is unbiased; their aim
  (fairness of a patch) differs from ours (the right pick for one player).

## Findings

- [method/causal] [stats] For Average and Skilled play Riot's power signal is the raw
  win rate within the tier, with a band that tightens as the ban rate rises above the
  average ban rate; no adjustment for who plays the champion is described. ^f1
  > Win rate tells us most of what we need to know about champions’ power level here, and combined with their ban rate, gives us a good view of what is too strong
  > Top End: \[54.5%WR if <ABR\] to \[52.5%WR at 5x ABR\]
- [method/causal] Only at the top of solo queue does Riot read picks as revealed power
  (presence = pick plus ban rate), on the argument that those players choose well;
  pick rate is not a power signal at other tiers. ^f2
  > these players have mastered the game to such an extent that their champion select behaviors can be trusted as accurate representations of power level
  > we notably do not consider pick rate a strong indicator of power at any other solo queue tier
- [method/causal] [stats] Mastery curves are deliberately left out of buff and nerf
  decisions, a policy choice (don't punish players who invest in a champion), not a
  statistical one; Riot acknowledges steep curves give experienced players much higher
  win rates. ^f3
  > Champions with steep mastery curves, like Aurelion Sol and Katarina, typically have a much higher win rate when played by experienced players than newcomers to the champion.
  > We are intentionally leaving out mastery curve data when considering which champions to buff or nerf
- [method/causal] New and reworked champions are exempt for about a month because their
  measured win rate reflects the player base still learning them, not their power. ^f4
  > we can expect the champions’ actual power levels to be much different from their statistical performance around launch
- [method/causal] Popularity is not read as power: some champions are played a lot
  whatever their strength. ^f5
  > play rate doesn’t seem to have a significant correlation to power level
- [method/causal] (inferred) So Riot's numbers are raw, selection-laden win rates by
  tier: a champion picked mostly by one-tricks or mostly by first-timers is judged on
  its pickers as well as its kit. For a recommender aimed at one player on one champion,
  the selection Riot ignores is the part we must model. ^f6

## Read

- Whole post.
