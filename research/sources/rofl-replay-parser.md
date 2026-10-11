---
title: ROFL (Mowokuma/ROFL) replay file parser README
url: https://github.com/Mowokuma/ROFL
kind: project
commit: 7181c9a745881cad9e14b79653c48af0d2fcd824
for: [league-tools-landscape]
looked: 2026-10-11
depth: docs (README)
relevance: medium
grade: C/fair
description: Archived Rust parser that pulls per-second positions and ward placements from .rofl replays because the Riot API lacks them
---
# ROFL (Mowokuma/ROFL) replay file parser README

Why: how do position and ward heatmap tools get their data, and is it via the Riot API?

## Assessment

- Evidence: C. Created 2025-01, 41 stars, 6 forks, 1 contributor, no licence, archived after 2025-03.
- Reasoning: fair; states why it exists and what the API lacks.
- Interests: none.
- Weigh: the API gap it names (positions at 1-minute frames, no ward positions) should be checked against match-v5 timeline by the API-depth reader; the replay route is now closing ([[lol-patch-26-20#^f2]]).

## Findings

- [data] [learning] Says the Riot API gives player positions only per minute and no ward positions, so ward heatmaps need replay files. `README.md` ^f1
  > Player positions are only available on a 1-minute interval basis, making it impossible to accurately track player movement patterns throughout the game.
  > No information about wards on the map is provided.
- [data] Parses .rofl to get per-second champion positions and ward position, type, duration, owner role and team. `README.md` ^f2
  > Extract champions position(x, y) in intervals of one sec.
- [learning] Goals are learning analytics: optimal jungle paths per champion and movement patterns versus outcome. `README.md` ^f3
  > Attempt to statistically determine the optimal jungle path for a given champion.
- [market] (inferred) Archived after about six weeks by its single author; typical lifespan of hobby replay-analysis projects. ^f4
- [policy] [data] (inferred) Riot's 26.20/26.21 replay restriction removes the only route to this granular data for third parties; a Riot-friendly tool cannot depend on .rofl parsing. ^f5

## Read

- `README.md`.

## Not read

- `src/` (packet decoding).
