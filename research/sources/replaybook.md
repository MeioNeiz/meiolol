---
title: ReplayBook (fraxiinus/ReplayBook) README and release stats
url: https://github.com/fraxiinus/ReplayBook
kind: project
commit: f53c18bb901f2b07d1198e1ac87a254c17700a79
for: [league-tools-landscape]
looked: 2026-10-11
depth: docs (README, release download counts and issue titles via gh)
relevance: medium
grade: B/fair
description: Open-source Windows replay file manager for League (.rofl), ~120k release downloads; depends on local replay files Riot is now restricting
---
# ReplayBook (fraxiinus/ReplayBook) README and release stats

Why: what replay/learning tools exist outside the stats sites, and how exposed are they
to Riot's replay changes?

## Assessment

- Evidence: B. Created 2019-09, 450 stars, 60 forks, 19 contributors, GPL-3.0; latest release 1.7.9 (2025-09-01) with 23,034 downloads, ~120k downloads across all releases (gh api, 2026-10-11).
- Reasoning: fair; README is practical.
- Interests: donations via ko-fi.
- Weigh: real niche use; no Riot API key needed (local files), so no evidence about key approval.

## Findings

- [learning] [tools] Free open-source manager for downloaded replay files. `README.md` ^f1
  > ReplayBook is a free open-source tool that helps you organize and manage your downloaded replay files
- [market] Release downloads: about 120k in total, 23k for the latest release (counted via GitHub API, not in README). ^f2
- [data] Fragile to Riot format changes: replays from two patches lacked metadata and are unsupported. `README.md` ^f3
  > Replays from 14.9 through 14.10 do not contain metadata and are not supported by ReplayBook.
- [policy] [learning] (inferred) Riot's 26.20/26.21 private replay change, which removes replay downloads from third-party apps and sites ([[lol-patch-26-20#^f2]]), puts replay-based learning tools at risk; tools built on Riot API match and timeline data are not affected. ^f4
- [learning] Checked, not there: no issue yet about the 26.20 replay restrictions (search on 2026-10-11). ^f5

## Read

- `README.md`; release list and last 15 issue titles via gh.

## Not read

- Source code (.rofl parsing).
