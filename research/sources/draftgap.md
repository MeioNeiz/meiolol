---
title: DraftGap (vigovlugt/draftgap) README, FAQ and data pipeline
url: https://github.com/vigovlugt/draftgap
kind: project
commit: 872c6d5cebfec186fdebb14005fd42b2bf84ad22
for: [riot-production-key, curve-statistics-method, league-apps-feature-matrix]
looked: 2026-10-11
depth: code (README, FAQ dialog, dataset riot.ts and lolalytics; issue list; core draft analysis, ratings, risk level; desktop LCU integration main.rs, LolClientContext.tsx, lcu-api.ts)
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

- [tools] [ux/features] Site plus desktop app that syncs with champ select and suggests champions from matchup and duo stats. `README.md` ^f1
  > DraftGap.com is a site and desktop application which helps you pick and draft your League of Legends team. It suggests champions based on the meta, their matchups with every opponent champion and every ally duo.
  > download the app, which integrates with the League client to automatically synchronize with the current draft in champ select.
- [tools] [ux/features] Shows win rates of each team comp after each candidate pick, i.e. live team win probability during champ select. `FAQDialog.tsx` ^f2
  > It calulates the winrate of each team comp after picking a possible champion, and shows this in the table.
- [data] [policy] Stats come from Lolalytics, not Riot match-v5; dataset code only calls Data Dragon on Riot's side. `FAQDialog.tsx`, `apps/dataset/src/riot.ts` ^f3
  > The data used are the current Emerald+ Lolalytics solo/duo winrates from all regions of the last 30 days.
  > https://ddragon.leagueoflegends.com/api/versions.json
- [policy] (inferred) So DraftGap needs no Riot API key at all; its continued operation is not evidence about production key approval, only about Riot tolerating an LCU-reading pick recommender. ^f4
- [policy] Checked, not there: no mention of Riot approval, production key, registration or the "isn't endorsed" boilerplate in README or FAQ; no GitHub issue (16 total) about Riot policy, Vanguard or removed features. ^f5
- [method] [ux/trust] Explicitly stats-only, no opinions; not ML. `FAQDialog.tsx` ^f6
  > using just data is the most objective way to make a decision.

- [stats] [method] Matchup expectation is additive on an Elo-like logit scale:
  expected rating = rating(A's role win rate) - rating(B's role win rate), with
  rating(w) = -400 log10(1/w - 1). `packages/core/src/draft/analysis.ts`,
  `packages/core/src/rating/ratings.ts` ^f7
  > export function winrateToRating(w: number) {
  > return -400 * Math.log10(1 / w - 1);
- [stats] [method] [ux/uncertainty] Thin matchups are shrunk with pseudo-games: priorGames games at the
  additive expected win rate are added to the observed wins and games, then the
  matchup's rating is reported as the deviation from that expectation.
  `packages/core/src/draft/analysis.ts` ^f8
  > wins: priorGames * expectedWinrate,
  > const rating = actualRating - expectedRating;
- [stats] Both directions of a matchup are averaged (A's wins vs B, B's losses vs A)
  before shrinking. `packages/core/src/draft/analysis.ts` ^f9
  > const wins = (matchupStats.wins + enemyLosses) / 2;
- [stats] [ux/uncertainty] Prior strength is a user setting ("risk level"): 3000, 2000, 1000
  (medium), 500 or 250 pseudo-games; fixed constants, not estimated from data.
  `packages/core/src/risk/risk-level.ts` ^f10
  > export const priorGamesByRiskLevel: Record<RiskLevel, number> = {
- [ux/uncertainty] FAQ frames prior strength as trust in small samples versus finding niche
  counters. `FAQDialog.tsx` ^f11
  > The risk level is a measure of how much to trust small
  > sample sizes in the data.
- [stats] (inferred) A 1000-game prior means a matchup needs about 1000 games before its
  own data counts as much as the additive baseline: far stronger than Lolalytics' 100
  game display floor ([[lolalytics-counters-threshold#^f1]]), and close to what Tango's
  k = luck variance / talent variance gives for small win-rate effects (inferred:
  sd of true matchup deviation 1.5 points gives k = 0.25 / 0.015^2, about 1100). ^f12

- [tools/phase] [method] Champ select: the Tauri desktop app finds the League client by
  reading the LeagueClientUx process command line (PowerShell Get-CimInstance on Windows,
  ps elsewhere) for the app port and remoting auth token, then calls the local LCU over
  HTTPS with basic auth user "riot". `apps/frontend/src-tauri/src/main.rs` ^f13
  > let port_regex = "--app-port=([0-9]+)";
  > let password_regex = "--remoting-auth-token=([a-zA-Z0-9_-]+)";
- [tools/phase] Read-only LCU use: four GET endpoints only (champ select session, current
  summoner, grid champions, pickable champion ids); no write, hover or lock call.
  `apps/frontend/src-tauri/src/main.rs` ^f14
  > get_lcu_response(&state, "lol-champ-select/v1/session").await
  > get_lcu_response(&state, "lol-champ-select/v1/pickable-champion-ids").await
- [tools/phase] [ux/features] Champ select: polls every 500 ms in champ select, 1 s in the
  main menu, 2 s when the client is not found. `LolClientContext.tsx` ^f15
  > [ClientState.InChampSelect]: 500,
- [tools/phase] [ux/features] Champ select: syncs both teams' picks with assigned roles,
  shows allies' hover intent (pick intent of other allies), and greys champions the player
  does not own. `LolClientContext.tsx` ^f16
  > selection.championPickIntent &&
  > const ownedChampions = await getPickableChampionIds();
- [ux/features] An import of the client's favourite champions per position exists but is
  disabled (prompt kept repeating). `LolClientContext.tsx` ^f17
  > // Disabled: favourites import prompt repeats, likely because WebView2 drops recent localStorage writes.
- [tools/accounts] Checked, not there: no login, account or sign-in code in the frontend;
  identity is only the local client's current summoner, used to reset filters on the
  player's own pick. ^f18

## Read

- `packages/core/src/draft/analysis.ts` (analyzeMatchups), `rating/ratings.ts`, `risk/risk-level.ts`
- `README.md`, `FAQDialog.tsx`, `apps/dataset/src/riot.ts`, `lolalytics/index.ts` head; titles of all 16 issues, bodies of #8, #12, #20 (technical, nothing on policy)
- `apps/frontend/src-tauri/src/main.rs`, `src/contexts/LolClientContext.tsx`, `src/api/lcu-api.ts` (2026-10-22, for league-apps-feature-matrix)

## Not read

- draftgap.com live site footer/legal (might carry boilerplate)
