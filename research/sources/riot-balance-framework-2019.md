---
title: 'Riot 2019: /dev: Champion Balance Framework'
url: https://www.leagueoflegends.com/en-us/news/dev/dev-champion-balance-framework/
kind: docs
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: docs (whole post)
relevance: high
grade: A/fair
description: Riot's public rule (30 May 2019) for which champions get buffed or nerfed each patch: win rate bands per audience (49% floor, 52.5-54.5% ceiling by ban rate), new and reworked champions exempt for about a month while the playerbase learns them
---
# Riot 2019: /dev: Champion Balance Framework

Why: how the balance team decides patch changes tells us what drives champion strength
over time, and whether patch-day jumps are predictable from the previous patch.

## Assessment

- Evidence: A. Riot's own stated policy for the balance team, used in later balance
  posts; 2019, revised in 2020 (thresholds for the top audiences), the solo queue bands
  are what matter here.
- Reasoning: fair. Explains the audiences and why mastery curves are excluded; gives no
  data on how well the bands are met.
- Interests: Riot defending its balance choices to players.
- Weigh: trust it as the decision rule; the bands are targets, not measured outcomes.

## Findings

- [method/dynamics] [stats] Average Play (below the top 10%, about Gold and lower):
  win rate is the main power signal, with ban rate tightening the ceiling; a champion is
  a nerf candidate above 54.5% (or 52.5% at five times the average ban rate) and a buff
  candidate under 49%. Average Play ^f1
  > Win rate tells us most of what we need to know about champions’ power level here
  > Top End: \[54.5%WR if <ABR\] to \[52.5%WR at 5x ABR\]
- [method/dynamics] [stats] Skilled Play (top 10% of solo queue, our Plat+ is roughly
  here): a tighter band, 49% to 54% (52% at five times the average ban rate). ^f2
  > This group contains the top 10% of solo queue players, except the very top players
  > Top End: \[54%WR if <ABR\] to \[52%WR at 5x ABR\]
- [method/dynamics] (inferred) Patches act as a controller: champions outside the band
  are pushed back toward it, so a patch-day jump should be predictable in sign from the
  previous patch's win rate and ban rate (mean reversion at patch boundaries), and
  true strength stays within a few points of 50%. ^f3
- [method/dynamics] [data] New and reworked champions are exempt for about a month,
  because the playerbase is still learning them and launch win rates understate their
  power; Riot plans for expected growth over the first days and weeks. New and Reworked
  Champions ^f4
  > New and updated champs won’t abide by these exact parameters for about one month after release.
  > a champion’s expected power level at release, their expected performance growth over the first few days/weeks
- [method/dynamics] [stats] Mastery curves: experienced players win much more on steep
  champions (Aurelion Sol, Katarina); Riot leaves mastery out of buff and nerf choices.
  Champions With High Mastery Curves ^f5
  > Champions with steep mastery curves, like Aurelion Sol and Katarina, typically have a much higher win rate when played by experienced players than newcomers to the champion.
- [method/dynamics] (inferred) So a champion's raw win rate after a patch mixes power
  with who plays it: a buff draws newcomers to the champion, which lowers its win rate
  for weeks; a dynamic model should condition on the players' mastery, or the drift it
  tracks is partly playerbase mix. ^f6
- [method/dynamics] Checked, not there: no numbers on how big win rate growth after
  launch is, nor on how fast patch effects settle. ^f7

## Read

- Whole post (30 May 2019).

## Not read

- The 2020 framework update (higher MMR audience thresholds).
