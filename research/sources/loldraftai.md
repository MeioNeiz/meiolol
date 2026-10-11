---
title: LoLDraftAI public monorepo archive (May 2025 state)
url: https://github.com/Looyyd/loldraftai-monorepo-public
kind: project
commit: 10e7e2f86a0a0d0efb71ea3e3b128a96cd89d105
for: [riot-production-key]
looked: 2026-10-11
depth: code (README, data-collection rate limiter, desktop footer, correction blog post)
relevance: high
grade: C/fair
description: Public archive of LoLDraftAI: deep learning draft win predictor trained on Riot API ranked matches, with desktop app
---
# LoLDraftAI public monorepo archive (May 2025 state)

Why: the nearest precedent to meiolol's design (ML model trained on Riot ranked match data, desktop champ select app); how does it collect data and present itself to Riot?

## Assessment

- Evidence: C. Single contributor, 8 stars, archive created 2025-08, code state May 2025 (later development private). The live product is still running (see [[loldraftai-site]]).
- Reasoning: fair. README and blog are candid about metrics and a data bug.
- Interests: commercial product's own repo.
- Weigh: shows exactly the meiolol pattern in production; nothing in the repo says whether or how Riot approved it, so the production key is inferred from rate limits only.

## Findings

- [tools] [method] Hosts a deep learning model predicting match outcome from draft only; desktop app downloadable. `README.md` ^f1
  > hosts a deep learning model that predicts and analyzes League of Legends matches from draft only.
- [data] Collects summoners and matches from the Riot API into Postgres, exported to parquet for training. `README.md` ^f2
  > A Postgresql database(Standard_B4ms (4 vCores)) for storing the league api data(Summoners and Matches).
- [data] [policy] Match collector is rate limited at 100 requests per 10 seconds, above development key limits. `apps/data-collection/src/scripts/processMatches.ts` ^f3
  > reservoir: 100,
  > reservoirRefreshInterval: 10 * 1000,
- [policy] (inferred) 100 requests per 10 s far exceeds a development key's 100 per 2 minutes, so the collector almost certainly runs on a production (or at least personal-with-raised-limits) key. Not confirmed anywhere in the repo. ^f4
- [policy] Desktop app and site carry Riot's "isn't endorsed" boilerplate. `apps/desktop/src/components/Layout.tsx` ^f5
  > LoLDraftAI isn't endorsed by Riot Games and doesn't reflect the
- [method] Reported draft-only model accuracy 56.1% (solo queue), 56.8% (pro). `README.md` ^f6
  > Accuracy: 56.1%
- [data] A region-default bug duplicated EUW matches across regions, inflating claimed accuracy until fixed (to 55%). `correction-reddit-post/page.tsx` ^f7
  > This new model has an accuracy of 55%.
- [policy] Checked, not there: no mention of Riot approval, production key, RSO, Vanguard or removed features in README or grep of md/ts/tsx/py. ^f8

## Read

- `README.md`, `processMatches.ts` lines 1-70, desktop `Layout.tsx` footer, correction blog post; grep for policy terms over the repo

## Not read

- `apps/desktop` LCU integration details; `apps/machine-learning` README (method question, not policy)
