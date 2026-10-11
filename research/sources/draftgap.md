---
title: DraftGap (vigovlugt/draftgap) README, FAQ and data pipeline
url: https://github.com/vigovlugt/draftgap
kind: project
commit: 872c6d5cebfec186fdebb14005fd42b2bf84ad22
for: [riot-production-key]
looked: 2026-10-11
depth: code (README, FAQ dialog, dataset riot.ts and lolalytics; issue list)
relevance: medium
grade: B/fair
description: Open-source stats-based champ select pick recommender (web + Tauri desktop, LCU sync); data from Lolalytics, not Riot API
---
# DraftGap (vigovlugt/draftgap) README, FAQ and data pipeline

Why: closest open-source precedent to meiolol (desktop app syncing with champ select, ranked pick suggestions); does it hold or need a Riot production key?

## Assessment

- Evidence: B. Created 2022-11, 69 stars, 17 forks, 3 contributors, MIT, release v3.2.2 on 2026-10-10: in use and maintained for ~4 years.
- Reasoning: fair. FAQ explains method and data source honestly, including shortcomings.
- Interests: none known (free, no ads seen in code).
- Weigh: tells us a champ select recommender with team win rates can operate for years; says nothing about Riot approval because it sidesteps the Riot API entirely.

## Findings

- [tools] [ux] Site plus desktop app that syncs with champ select and suggests champions from matchup and duo stats. `README.md` ^f1
  > DraftGap.com is a site and desktop application which helps you pick and draft your League of Legends team. It suggests champions based on the meta, their matchups with every opponent champion and every ally duo.
  > download the app, which integrates with the League client to automatically synchronize with the current draft in champ select.
- [tools] [ux] Shows win rates of each team comp after each candidate pick, i.e. live team win probability during champ select. `FAQDialog.tsx` ^f2
  > It calulates the winrate of each team comp after picking a possible champion, and shows this in the table.
- [data] [policy] Stats come from Lolalytics, not Riot match-v5; dataset code only calls Data Dragon on Riot's side. `FAQDialog.tsx`, `apps/dataset/src/riot.ts` ^f3
  > The data used are the current Emerald+ Lolalytics solo/duo winrates from all regions of the last 30 days.
  > https://ddragon.leagueoflegends.com/api/versions.json
- [policy] (inferred) So DraftGap needs no Riot API key at all; its continued operation is not evidence about production key approval, only about Riot tolerating an LCU-reading pick recommender. ^f4
- [policy] Checked, not there: no mention of Riot approval, production key, registration or the "isn't endorsed" boilerplate in README or FAQ; no GitHub issue (16 total) about Riot policy, Vanguard or removed features. ^f5
- [method] Explicitly stats-only, no opinions; not ML. `FAQDialog.tsx` ^f6
  > using just data is the most objective way to make a decision.

## Read

- `README.md`, `FAQDialog.tsx`, `apps/dataset/src/riot.ts`, `lolalytics/index.ts` head; titles of all 16 issues, bodies of #8, #12, #20 (technical, nothing on policy)

## Not read

- draftgap.com live site footer/legal (might carry boilerplate)
