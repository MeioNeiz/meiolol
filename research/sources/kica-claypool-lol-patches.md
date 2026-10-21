---
title: "Kica, La Manna, O'Donnell, Paolillo, Claypool 2016: Nerfs, Buffs and Bugs, Analysis of the Impact of Patching on League of Legends"
url: https://web.cs.wpi.edu/~claypool/papers/lol-crawler/paper.pdf
kind: paper
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: docs (whole paper)
relevance: medium
grade: C/fair
description: WPI student project with Claypool (2016): 164 LoL patches, 7,710 patch notes classified as numeric, utility or quality of life and buff, nerf or neutral, against per-patch champion win rates from 465k NA ranked games (Seasons 4-6); correlation only, no forecast
---
# Kica, La Manna, O'Donnell, Paolillo, Claypool 2016: Nerfs, Buffs and Bugs, Analysis of the Impact of Patching on League of Legends

Why: can patch notes (counts or sizes of buffs and nerfs) predict a champion's win rate
change, i.e. give a prior for the patch-day jump?

## Assessment

- Evidence: C. Student project paper (WPI, Claypool), one region, Seasons 4-6, 465k
  games; plots and anecdotes, no held-out prediction or effect size for buffs minus
  nerfs.
- Reasoning: fair. Honest about where counts fail, with worked outliers.
- Interests: none known.
- Weigh: trust the taxonomy and the outliers as cautions; the "patches keep win rates
  near 50%" result is descriptive.

## Findings

- [method/dynamics] [data] Patch notes are mostly gameplay changes (median 34 per
  patch, 26 numeric) and can be classified by keywords into numeric, utility and quality
  of life, then buff, nerf or neutral; automatic keyword classification got precision
  94.3% and recall 65.7%, the rest by hand. Sections III-B, V-B ^f1
  > The precision and recall were 94.3% and 65.7%, respectively.
  > Numeric changes are the most common, perhaps because they are the easiest to code, and have a median of 26 changes per patch.
- [method/dynamics] [stats] Champions further from 50% get patched more, buffs for low
  and nerfs for high: the balance process pulls win rates back toward 50%. Section V-C ^f2
  > as the win rate moves farther from 50% the number of changes in that patch for that champion increases
  > champions with win rates further from 50% are patched most
- [method/dynamics] [stats] Per-patch champion win rates are near normal, mostly 45-55%,
  with thinner tails than normal, which the authors put down to Riot trimming outliers.
  Section V-A ^f3
  > the bulk of the distribution is between 45-55%
- [method/dynamics] [stats] Counting buffs and nerfs does not reliably predict the
  change: Urgot lost win rate after a patch of 8 buffs as new players flocked to him
  (pick rate 0.5% to 1%); Kalista gained 4.9% after three nerfs, likely from changes to
  other champions. Section V-C ^f4
  > The influx of players that chose him after the patch likely had not previously played Urgot regularly
  > Her win rate increased by 4.9% with no real explanation, as the nerfs were unambiguously negative.
  > simply counting patch changes does not always accurately predict the effects on win rates
- [method/dynamics] (inferred) Two lessons for a patch-notes prior: a champion's own
  buff count is a weak, noisy signal (and a pick-rate surge after a buff can reverse
  it via newcomers), and indirect effects through other champions' changes are real;
  a prior should use signed numeric sizes and the previous win rate, and be checked
  against a "mean reversion only" prior. ^f5
- [method/dynamics] Checked, not there: no regression of win rate change on signed
  buff size, no held-out test, no control for who plays the champion. ^f6

## Read

- Whole paper (8 pages).

## Not read

- The LoL Crawler site (gone).
