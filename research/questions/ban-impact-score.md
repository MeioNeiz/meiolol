---
status: decided
decision: docs/plan/site.md#Champion page (Ban impact, J20)
priority: soon
area: stats
tags: [stats, draft, ux/uncertainty]
description: How do stat sites score a champion's ban value (lolalytics PBI), and how should meiolol handle small samples?
---
# How do stat sites score a champion's ban value (lolalytics PBI), and how should meiolol handle small samples?

Feeds: docs/plan/site.md "Ban impact" (J20); later the picker's ban options (B3, Q3)

## Answer

LoLalytics' PBI is the champion's win rate edge over the tier average times its pick
rate when not banned, pick / (100 - ban) (C1). It uses the raw win rate (C2), so a
thin champion's lucky edge counts in full; only its low pick rate keeps it small. Ours
(C3): the same shape, edge from a win rate shrunk toward the role's average by
pseudo-games (C4), so a few hundred games cannot carry a large edge. Shown as "ban
impact" beside pick, ban, win rate and games, never as "best ban" or a win rate gain.

## Claims

- C1: PBI = (win - tier average) x 100 x pick / (100 - ban). for: [[lolalytics-pbi-tooltip#^f1]]
- C2: LoLalytics states no sample floor or shrinkage for PBI. for: [[lolalytics-tierlist-pbi#^f3]], [[lolalytics-pbi-tooltip#^f3]]
- C3 (inferred): meiolol's ban impact = shrunk edge x pick when available, per role. from: C1, C4
- C4: Shrinking a rate toward its group's mean by pseudo-counts handles thin samples. for: [[robinson-eb-baseball#^f3]], [[robinson-eb-baseball#^f5]]

## Disagreements

## Open

- Whether a ban should weigh the enemy's chance of picking it only (PBI) or also the
  ally's (a ban removes it from both sides): PBI ignores the ally side; in solo queue
  the ally side is symmetric, so the ranking is the same.
- Matchup-aware bans (vs the pool's hard lanes, B3) need the same score per opponent.
