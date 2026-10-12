---
title: Riot August on stats-site sample sizes (2020, devtrackers)
url: https://devtrackers.gg/leagueoflegends/p/8fc2d1be-riot-august-u-gg-data-is-garbage
kind: thread
commit:
for: [riot-api-data-depth]
looked: 2026-10-11
depth: listed (whole devtracker thread)
relevance: medium
grade: B/fair
description: Riot balance lead on when aggregate win rates are trustworthy; U.GG co-founder replies
---
# Riot August on stats-site sample sizes (2020, devtrackers)

Why: how much data per champion or matchup a stats tool needs before numbers mean anything,
from someone who uses this data for balance.

## Assessment

- Evidence: B. First-hand opinion of Riot's then lead champion designer (balance), 2020;
  a reddit comment, no numbers beyond one example. U.GG co-founder replies in thread.
- Reasoning: fair. Explains why (sample size, early patch, high elo), no thresholds.
- Interests: Riot defending balance calls against data-site numbers; U.GG defending itself.
- Weigh: direction is credible; no concrete minimum sample. 2020, before match-v5.

## Findings

- [data] [method] Aggregate sites are good for relative balance in Plat+ but poor for exact
  win rates, especially Diamond+ and Master+, because samples are too small. ^f1
  > Sites like lolalytics and u.gg are great for determining relative balance (how good is champ x vs. the rest of the roster) in plat+ for champs who aren't critically unpopular.
  > They're a lot worse at determining exact winrate/power levels of a given champ, especially at Diamond+ or Master+ levels of play.
- [data] Early in a patch, after only a few days, even Plat+ data is unreliable. ^f2
  > it gets even worse early in a patch when only a few days of data have been collected (at that point even plat+ data is unreliable).
- [data] [ux/uncertainty] [ux/trust] Example of a misleading number: 59% win rate on 120 games, which he says
  should not be shown at all. ^f3
  > look at how broken 59% winrate Ivern is at master+" and then I see the data they're referencing has only 120 games
- [data] U.GG says it competes on speed of pulling from the API within rate limits and
  of aggregation. ^f4
  > Speed in how quickly we can grab data from Riot's API within the limits of their rate limits
- [data] Checked, not there: no recommended minimum games per champion or matchup. ^f5

## Read

- Whole thread as captured by devtrackers.gg

## Not read

- Original reddit thread beyond Riot and U.GG replies
