---
title: 'U.GG CTO reply to ''u.gg data is garbage'' (Reddit, Apr 2020)'
url: https://devtrackers.gg/leagueoflegends/p/6713cfac-from-the-garbagemen-here-at-u-gg-re-u-gg-data-is-garbage
kind: thread
commit:
for: [champselect-advice-methods]
looked: 2026-11-06
depth: docs (post and Riot reply)
relevance: medium
grade: B/fair
description: U.GG's CTO (2020) agrees low-sample filters mislead and promises a low-sample disclaimer; Riot August apologises, narrows his criticism to thin high-elo and day-one patch data
---
# U.GG CTO reply to 'u.gg data is garbage' (Reddit, Apr 2020)

Why: has U.GG ever said how it handles thin samples and patch-day data?

## Assessment

- Evidence: B. First-hand from U.GG's CTO and Riot's balance lead; 2020, six years old.
- Reasoning: fair. Agrees with the problem, gives a plan, no numbers or threshold.
- Interests: vendor defending its site; Riot staff retracting a public jab.
- Weigh: a 2020 promise; check what the pages show now (our Oct 2026 shots show no flag:
  [[ugg-darius-matchups#^f11]], [[ugg-duo-tier-list#^f5]]). Thread parent:
  [[riot-august-ugg-sample-size]].

## Findings

- [ux/uncertainty] [ux/trust] U.GG accepted it must present thin samples correctly and planned a disclaimer when filters cut the match count. ^f1
  > We plan on implementing a disclaimer when the filters lower the match count (think Ivern in Masters+) cautioning the low sample size.
- [data] Riot's balance lead narrows his point: data gets sketchy at low samples, naming Master or Diamond+ for some champions and day-one patch data. ^f2
  > My criticism comes from how the data gets sketchy when the sample size gets low (master/diamond+ games for some champs, day 1 patch data, etc.).
- [data] He rates the data good for champions' relative strength. ^f3
  > overall their data is good when you want to understand how strong champs are in relation to each other.
- [ux/uncertainty] (inferred) The promised disclaimer is not visible in 2026: U.GG's Oct 2026 counters and duo pages list rows down to 122 games with no flag ([[ugg-darius-matchups#^f11]], [[ugg-list-pages-ui#^f3]]). ^f4

## Read

- Post and the Riot reply as captured by devtrackers.

## Not read

- The CTO's linked technical comment (fogmaa4) on Reddit.
