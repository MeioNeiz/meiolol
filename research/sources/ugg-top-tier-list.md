---
title: 'U.GG: top lane tier list (patch 26.20)'
url: https://u.gg/lol/top-lane-tier-list
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (rendered text plus fold and full-page screenshots)
relevance: high
grade: B/fair
description: U.GG's top lane tier list: a collapsed icon grid of the top tiers above a ranked table of tier, win rate, pick rate, ban rate, counter-pick icon strip and matches
---
# U.GG: top lane tier list (patch 26.20)

Why: how a tier list packs about 50 champions and five numbers each into one screen.

## Assessment

- Evidence: B. Top-two LoL stats site ([[similarweb-opgg-competitors#^f3]]); live page.
- Reasoning: weak. No method shown on the page beyond "data science approach".
- Interests: vendor.
- Weigh: colours read off screenshots
  (data/team/2026-10-19-night/design-shots/ugg-top-tier-list*.png).

## Findings

- [ux/layout] Page states sample and freshness up front, above the table. ^f1
  > Ranked Solo / Last Updated: a day ago /
  > Champions Analyzed: 21,339,380
- [ux/layout] Two views stacked: a grid of champion icons grouped under tier badges (win rate and games under each icon), collapsed behind "Click to Expand", then the full ranked table (seen in screenshot ugg-top-tier-list.png). ^f2
- [ux/density] Table columns: rank, role, champion, tier, win rate, pick rate, ban rate, counter picks, matches. ^f3
  > Rank||Role||Champion||Tier||Win Rate||Pick Rate||Ban Rate||Counter Picks||Matches
- [ux/density] Counter picks are a strip of seven small champion icons in one cell, so a list of names costs one row height (seen in screenshot ugg-top-tier-list-full.png). ^f4
- [ux/colour] Tier letters carry their own colour (S+ orange, S and A blue), and win rate is blue only above about 51.5%, white otherwise; the sorted win rate column has a lighter band (seen in screenshot ugg-top-tier-list-full.png). ^f5
- [ux/uncertainty] Failure: sorted by win rate, so the list opens with Zed at 0.7% pick rate and 15,903 matches above Malphite at 7.4% and 158,038; nothing marks the thinner rows. ^f6
  > Zed||S||52.17%||0.7%||24.1%||15,903
- [ux/colour] Failure: tier and win rate disagree visibly (Zed S, Anivia A and Malphite S+ all blue at about 52%), and the page never says what a tier means (seen in screenshot ugg-top-tier-list-full.png). ^f7

## Read

- Whole page text; screenshots at 1440 wide

## Not read

- Classic and Duo tier lists; filters
