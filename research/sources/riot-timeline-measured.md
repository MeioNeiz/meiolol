---
title: Measured match-v5 match and timeline responses (EUW, 2026-10-11)
url: https://europe.api.riotgames.com/lol/match/v5/matches/EUW1_8009933221/timeline
kind: dataset
commit:
for: [riot-api-data-depth]
looked: 2026-10-11
depth: ran (2 successful GETs plus one 429, personal key, gzip)
relevance: high
grade: B/strong
description: Our own measurement of one ranked EUW match and its timeline: sizes, frames, event mix, rate headers
---
# Measured match-v5 match and timeline responses (EUW, 2026-10-11)

Why: real size, frame count and event mix of a timeline, and its rate cost, to size a
timeline crawler against personal and production limits.

## Assessment

- Evidence: B. First-hand measurement, but one match (ranked solo, patch 16.20, 24.9 min,
  close to the dev db's mean 1679 s). Sizes scale with game length and event count.
- Reasoning: strong. Raw headers and counts recorded; script in session scratch.
- Interests: ours.
- Weigh: per-match numbers are one sample; treat as order of magnitude (+/- 30%).

## Findings

- [data] Timeline frames are one minute apart: 26 frames for a 1493 s game (frame 0 plus
  one per minute plus a final frame at game end). `raw/riot-timeline-measured.txt` ^f1
  > frameInterval 60000 frames 26 duration_s 1493
  > timestamps [0, 60033, 120054] [1440539, 1493187]
- [data] Timeline is ~9x the summary: 727 KB vs 78 KB as JSON; 63 KB vs 11 KB gzipped on
  the wire. ^f2
  > 727102 tl.json 78461 match.json
  > timeline attempt 2: 200 63205 0.294028
- [data] One game had 999 events, dominated by item, ward, skill and level events; 64
  champion kills, 13 building kills, 8 elite monster kills, 55 turret plates. ^f3
  > frames 26 duration_s 1493 events 999
  > 'ITEM_PURCHASED': 207, 'ITEM_DESTROYED': 175, 'WARD_PLACED': 146, 'SKILL_LEVEL_UP': 141, 'LEVEL_UP': 130, 'CHAMPION_KILL': 64, 'TURRET_PLATE_DESTROYED': 55
- [data] Kill events carry map position, killer, victim, assists, bounty and per-hit
  teamfight damage breakdown; elite monster kills carry monster subtype and position;
  building kills carry lane and tower tier. ^f4
  > "killerId": 9, "position": {"x": 10934, "y": 1286}, "shutdownBounty": 0
  > "monsterSubType": "FIRE_DRAGON", "monsterType": "DRAGON", "position": {"x": 9859, "y": 4427}
  > "laneType": "BOT_LANE", "position": {"x": 10504, "y": 1029}, "teamId": 100, "timestamp": 822472, "towerType": "OUTER_TURRET"
- [data] Ward events give creator and ward type but no position; skill level-ups give slot
  and type. ^f5
  > "creatorId": 4, "timestamp": 34249, "type": "WARD_PLACED", "wardType": "YELLOW_TRINKET"
  > "levelUpType": "NORMAL", "participantId": 4, "skillSlot": 1
- [data] Each participant frame has gold, xp, level, lane and jungle CS, position and 25
  champion stats, so gold@15, xp@15, cs@15 and lane diffs fall out of frame 15 directly. ^f6
  > frame15 p1 {'totalGold': 6208, 'xp': 8791, 'level': 12, 'minionsKilled': 137, 'jungleMinionsKilled': 0, 'position': {'x': 2817, 'y': 13061}}
- [data] The summary already has 129 Riot-computed `challenges` values per participant,
  including lane advantage stats, without a timeline call. ^f7
  > challenges keys 129
- [data] Match and timeline each cost one app-limit request; both methods show a 2000 per
  10 s method limit, so on a personal key the 100 per 2 min app limit binds. ^f8
  > x-app-rate-limit: 100:120,20:1
  > x-method-rate-limit: 2000:10
- [data] The box crawler already uses the whole app budget: our extra call hit 429 with
  the 2-minute window full and a 75 s retry-after. Any timeline crawl must come out of
  the same 100/2 min, not on top. ^f9
  > x-app-rate-limit-count: 100:120,1:1
  > retry-after: 75
- [data] The summary's lane "advantage" values are mostly flags, not amounts: the early and
  full laning-phase gold/xp advantage fields are 0 or 1; max CS advantage on lane opponent
  and max level lead are numbers. So gold@15 diffs and per-minute curves still need the
  timeline. ^f10
  > MIDDLE Ahri 1 0 32.599999994039536 1 82
  > BOTTOM Kalista 1 1 80 3 69

## Read

- Whole measurement record (`raw/riot-timeline-measured.txt`)

## Not read

- Other games: event counts and sizes from a single match; measure on a few hundred from
  the box crawl before sizing storage
