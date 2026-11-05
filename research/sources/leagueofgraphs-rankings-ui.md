---
title: 'League of Graphs: progressions and snowballing stats (archive copy)'
url: https://www.leagueofgraphs.com/champions/progressions
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-11-05
depth: skimmed (Wayback copies: screenshots and text at 1440)
relevance: high
grade: A/weak
description: League of Graphs' per-stat champion rankings, Wayback copies (Apr 2026): patch progressions and snowballing stats
---
# League of Graphs: progressions and snowballing stats (archive copy)

Why: how per-stat champion ranking pages look on the site Jacob named as the model for /rankings. Shots: data/team/2026-11-05-meionotes/cmp-lists-shots/ (cmp-lists batches, data/team/2026-11-05-meionotes/cmp-lists.md).

## Assessment

- Evidence: A. Long-running LoL stats site; archive copies (live blocks headless Chrome and browse with a Cloudflare challenge).
- Reasoning: weak. Pages, not write-ups; nothing says why.
- Interests: vendor; ads.
- Weigh: layout and what is shown, from text and screenshots; numbers are theirs for one day.

## Findings

- [ux/features] Progressions: two full lists side by side, win rate and popularity, each with a value bar and a change bar coloured by sign, sorted by the change. ^f1
  > Popularity Progression
- [ux/layout] Snowballing stats: four panels on one page (ahead and behind, at 10 and 20 minutes by kill lead), six champions each with win rate in that state, overall and the difference, then a See more button (seen in screenshot log-snowballing-stats-top.png). ^f2
- [ux/features] The snowballing threshold is kills (2/0, 3/1 at 10), not gold (seen in screenshot log-snowballing-stats-top.png). ^f3
- [ux/layout] The title is the only text on each panel (seen in screenshot log-snowballing-stats-top.png). ^f4

## Read

- progressions, snowballing-stats, champions/stats: archive screenshots and text

## Not read

- Live numbers (archive leaves script-loaded numbers blank in snowballing and stats)
