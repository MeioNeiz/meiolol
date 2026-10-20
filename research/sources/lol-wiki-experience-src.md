---
title: 'League of Legends Wiki: Experience (champion), wikitext'
url: https://wiki.leagueoflegends.com/en-us/Experience_(champion)?action=raw
kind: docs
commit:
for: [kill-vs-farm-value]
origin: lol-wiki-experience
looked: 2026-10-20
depth: docs (kill and comeback templates)
relevance: high
grade: B/fair
description: Wikitext of the wiki's Experience (champion) page, which carries the per-level kill XP values the rendered page hides in a tooltip
---
# League of Legends Wiki: Experience (champion), wikitext

Why: the rendered page shows kill XP only as "42 – 990"; the wikitext has each level.

## Assessment

- Evidence: B. Same page as [[lol-wiki-experience]]; values cite Riot's 13.4 notes.
- Reasoning: fair. Explicit values with a formula note.
- Interests: none.
- Weigh: trust; same origin as the rendered page.

## Findings

- [data] [learning] Solo kill XP by slain champion level: 42, 114, 144, 174, 204, 234,
  308, 392, 486, 590 for levels 1 to 10, then +50 a level (640 at 11, 690 at 12, 990 at
  18). The step from 6 to 10 is the steep part (+74, +84, +94, +104). ^f1
  > 42; 114; 144; 174; 204; 234; 308; 392; 486; 590; then + 50*x
- [data] Shared (assisted) kill XP total: 66.6% of solo for slain levels 1 to 6, 82% at
  7 and 8, 90% at 9+, split among sharers. ^f2
  > 66.6% of the solo bounty until level 6, then 82% of the solo bounty at levels 7 and 8, then 90% of the solo bounty at levels 9+
- [learning] Level difference modifier: linear 20% per level after the first, penalty
  bounded at -60%. ^f3
  > Linear interpolation by 20% per decimal level after 1 decimal level of difference. This has a lower bound at -60% for the penalty.
- [learning] (inferred) Against a cannon wave (3 melee 62 + 3 casters 31 + cannon 75 =
  354 XP before 14:00, 292 after), a solo kill on a level 2 victim (114) is worth 0.32
  of the wave (wave about 3.1x), level 7 (308) 0.87 / 1.05, level 8 (392) 1.11 / 1.34,
  level 12 (690) 1.95 / 2.36. The video's 3x, about equal at 8 and double at 12 hold
  for solo kills on equal-level victims; the crossover is level 8 before 14:00 and
  level 7 after. ^f4
- [learning] (inferred) An assisted kill splits less: at level 8 the total is 392 x
  0.82 = 321, about 161 each for two, under half a cannon wave; so for a gank with an
  assist the XP crossover moves to about level 11 or 12 (two sharers, 90% at 9+:
  level 11 = 640 x 0.9 / 2 = 288). ^f5

## Read

- Champion kill bounty and comeback templates, patch history lines for 13.4 and 10.8
