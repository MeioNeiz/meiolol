---
title: 'iTero: How useful is a Champion''s Win Rate? (Mar 2023)'
url: https://www.itero.gg/articles/how-useful-is-a-champions-win-rate
kind: article
commit:
for: [champselect-advice-methods]
looked: 2026-11-06
depth: docs (full article)
relevance: medium
grade: C/fair
description: iTero founder on why raw champion win rates mislead (side, team fit, sample size, stage vs solo queue, player skill), and why its draft AI conditions on them
---
# iTero: How useful is a Champion's Win Rate? (Mar 2023)

Why: does any big companion explain, in its own words, how it treats sample size and
context behind its champ select advice?

## Assessment

- Evidence: C. Founder's blog, Mar 2023; a few quoted win rates, no data sizes or method.
- Reasoning: fair. Names five confounders with examples; the remedy for sample size is
  stated (ranges) but not shown to be what the app does.
- Interests: vendor; frames average win rates as useless to sell its conditional draft AI.
- Weigh: the stated position on ranges is iTero's view, not evidence the app shows them
  (its drafting UI shows 0-5 scores, no ranges: [[itero-drafting-sim-ui]]).

## Findings

- [stats] [ux/uncertainty] Tiny samples: 67% on 3 games is any win rate from 0 to 100%. ^f1
  > If a Champion (such as Top Kayle) has a 67% win rate in 3 games - it might as well read: “win rate between 0-100%”.
- [stats] [ux/uncertainty] With 162 perfectly balanced champions at 100 games each, about 4.6 would top 60% by chance. ^f2
  > if they all played 100 games how many would have over 60% win rate? The answer: 4.6 Champions.
- [ux/uncertainty] Recommends ranges by sample size as the common fix. ^f3
  > A common solution to this is to add ranges based on the sample size.
- [method] [draft] Side matters per champion: Rumble top 46% red side vs 51% blue, so it argues for win rate given side. ^f4
  > Rumble, who has a dismal 46% win rate on Red Side - but 51% on Blue.
- [draft] Team fit moves a pick more than its average: Thresh 50% overall, 54% with Jarvan jungle. ^f5
  > Thresh support sits at the middest of win rates; 50%. However, by simply pairing it with a Jarvan Jungle it rises to 54%.
- [method] Player experience varies per champion: Qiyana mid under 45% on a first game, 55%+ once mastered; Malzahar first timers only 1% down. ^f6
  > Qiyana played in the middle lane has a sub-45% win rate IF that person has never played Qiyana before, rising to 55%+ once the player has mastered her complex kit.
- [method] (claim) Average win rates alone are called useless; the article's stance for its conditional model. ^f7
  > average win rates alone are dog-water useless so please stop using them!
- [stats] Checked, not there: no statement of iTero's own minimum games, shrinkage or how
  the app shows thin data. ^f8

## Read

- Whole article.

## Not read

- Linked tier-list-chal article (stage predictions from solo queue patch changes).
