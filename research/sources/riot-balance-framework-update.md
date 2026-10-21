---
title: "/dev: Balance Framework Update (Riot Summoner's Rift team, 2020-06-30)"
url: https://www.leagueoflegends.com/en-gb/news/dev/dev-balance-framework-update/
kind: article
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: listed (whole post)
relevance: medium
grade: A/fair
description: Riot's one-year review of the Champion Balance Framework: tighter win rate bands, Elite widened to top 0.5% for win rate samples, predicted vs actual win rate change after each patch
---
# /dev: Balance Framework Update (Riot Summoner's Rift team, 2020-06-30)

Why: did Riot move to adjusted win rates after a year of the framework?

## Assessment

- Evidence: A. Riot's balance team on its own process. Origin is separate from the
  2019 post but same team.
- Reasoning: fair; explains each change, no numbers on noise.
- Interests: Riot.
- Weigh: confirms raw win rate by tier stayed the measure in 2020.

## Findings

- [method/causal] [stats] Elite was widened from the top 0.1% to the top 0.5% purely to
  get enough games for a win rate, keeping the same "win rate given ban rate" metric. ^f1
  > This required us to expand Elite from the top 0.1% to the top 0.5%, since Elite's original size was too small to provide enough matches for reliable win rate numbers.
- [method/causal] Riot predicts each patch's win rate change and compares it with the
  actual change afterwards: the closest thing in the post to a causal check, and the one
  place a patch is treated as an intervention. ^f2
  > We now compare our estimated win rate changes to the actual win rates following the patch
- [method/causal] OP bands for Average and Skilled were tightened by half a point; no
  selection or mastery adjustment was added. ^f3
  > We tightened the OP bands for both Average and Skilled play by 0.5% each
- [method/causal] Checked, not there: no skill-adjusted, mastery-adjusted or
  pick-order-adjusted win rate anywhere in the update. ^f4

## Read

- Whole post.
