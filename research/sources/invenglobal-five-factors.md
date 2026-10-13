---
title: Five Factors that you should know to win League of Legends (MobaChampion via Inven Global, 2019)
url: https://www.invenglobal.com/articles/8188/five-factors-that-you-should-know-to-win-league-of-legends
kind: article
commit:
for: [comp-attribute-features]
looked: 2026-10-13
depth: docs (full article; feature importance chart is an image, not read)
relevance: low
grade: D/weak
description: MobaChampion random forest feature importances on Gold+ games mixing post-game stats with champion attributes; claims heal/tank supports beat damage/CC supports and champion difficulty ratings do not matter
---
# Five Factors that you should know to win League of Legends (MobaChampion via Inven Global, 2019)

Why: any measured effect of champion attribute features (support type, difficulty) on win?

## Assessment

- Evidence: D. No data size, split or metric; random forest importances only, with
  post-game stats (objectives, assists, vision) in the same model, which swamp any
  draft feature.
- Reasoning: weak. Importance ranks, not effect sizes; no held-out comparison.
- Interests: written by MobaChampion, a tier list site, with links to its tier lists.
- Weigh: the support-type and difficulty statements are hints, not measurements.

## Findings

- [method] Method: random forest feature importances ranking factors in a team's win. ^f1
  > Using a modern AI algorithm known as a [Random Forest](https://en.wikipedia.org/wiki/Random_forest), one can extract the most important factors from the data that will lead a team to victory.
- [draft] (claim) Supports that heal or tank win more often than supports with damage or
  CC and no tank or heal; no number given. ^f2
  > the data shows that supports who heal or tank for their teammates win more often than those with superior damage or crowd control abilities with no tank or heal
- [draft] Champion difficulty ratings (one per position, apparently Riot's info rating)
  ranked in the bottom 10 of importances; Gold+ games only. ^f3
  > The 5 champion difficulty ratings were all ranked in the bottom 10. This analysis only includes Gold+ tier matches.
- [method] Checked, not there: data size, patch, how support type was labelled, any
  accuracy or lift from champion attributes; damage mix, team tank count. ^f4

## Read

- Full article text.

## Not read

- The feature importance figure (image).
