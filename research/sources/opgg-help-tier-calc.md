---
title: 'OP.GG Help: champion tier calculation explained'
url: https://help.op.gg/hc/en-us/articles/31089225669017-champion-tier-calculation-explained
kind: docs
commit:
for: [champselect-advice-methods]
looked: 2026-11-06
depth: docs (whole article)
relevance: medium
grade: B/weak
description: OP.GG's help answer on champion tiers (updated about 9 months before Nov 2026): Platinum+ ranked games, a proprietary score mixing win, pick and ban rate with gold, XP, CC, KDA and damage; OP Tier for the top
---
# OP.GG Help: champion tier calculation explained

Why: what does OP.GG say its tier, the headline number beside every pick, is made of?

## Assessment

- Evidence: B. OP.GG's own help centre, the largest League site; 13 of 17 found it helpful.
- Reasoning: weak. Lists inputs, "among others"; no weights, no sample rule.
- Interests: vendor.
- Weigh: trust the inputs list; the base bracket (Platinum+) may be stale against the
  site's Emerald+ default.

## Findings

- [method] [tools] Tiers come from Platinum+ ranked games through a proprietary algorithm. ^f1
  > Champion tiers are calculated using data extracted from ranked games of Platinum tier and above, through our proprietary algorithm.
- [method] The tier mixes outcome and in-game performance stats: pick and ban rate, win rate, gold, XP, crowd control, KDA, damage taken and dealt, among others. ^f2
  > The tier calculation includes various metrics such as pick and ban rates, win rates, gold, experience, crowd control, KDA, damage taken, and damage dealt, among others.
- [ux/controls] Filters: server, tier and patch. ^f3
  > Champion tiers can be filtered by server, tier, and patch version to view the desired statistical data.
- [ux/features] OP Tier marks the champions with the best combined score. ^f4
  > OP Tier is awarded to champions with the greatest power (Over Power).
- [ux/uncertainty] Checked, not there: no weights, minimum games, ranges or patch-day rule. ^f5
- [method] (inferred) Folding KDA, gold and damage into a strength tier rewards champions that pad stats, not only those that win; a pick ranked by it is not ranked by win chance. ^f6

## Read

- Whole article.

## Not read

- Other Champions-section articles (lane kill rate, expert builds).
