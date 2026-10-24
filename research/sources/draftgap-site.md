---
title: DraftGap web app
url: https://draftgap.com/
kind: docs
commit: 
for: [competitor-first-visit-returning, desktop-app-layout, lol-site-ui]
looked: 2026-10-17
depth: skimmed (first screen text)
relevance: medium
grade: B/weak
description: DraftGap's web app, Oct 2026: opens straight onto an empty ally and opponent draft board with a sorted win-rate list of every champion, patch 26.20, no sign-in
---
# DraftGap web app

Why: what a draft tool's first visit looks like when the tool is the homepage.

## Assessment

- Evidence: B. The live page through real Chrome; repo already read ([[draftgap]]).
- Reasoning: weak. No text beyond the tool.
- Interests: vendor (open source, free).
- Weigh: client-rendered; filters and settings not in text.

## Findings

- [ux/layout] Opens directly on the draft board: ally and opponent at 50.00, five pick slots each. ^f1
- [ux/features] Suggestion list is champion and win rate, sorted, before any pick (Zilean 55.76 first). ^f2
- [data] Header says the patch and freshness. ^f3
  > Patch 26.20Last updated about 4 hours ago
- [ux/features] Checked, not there: no sign-in, account, explanation text or onboarding on the first screen. ^f4

- [ux/desktop] At 1440 px: ALLY and OPPONENT columns at the edges, each headed by the team's
  estimated win rate in very large type (50.00) over five tall PICK 1..5 slots (the
  active one lighter); the middle has tabs DRAFT and DRAFT ANALYSIS, a search, an ALLY /
  OPPONENT toggle and role filter buttons, then one list of suggestions (role icon,
  champion icon, name in upper case condensed type, WINRATE in blue, info button), top
  win rate first; near-black background, no colour but the numbers (seen in screenshot
  draftgap-site.png, 23 Oct). ^f5

- [ux/features] 24 Oct (lol-site-ui): picking a champion fills the slot with its splash
  art and a lock, and both team numbers update (ally 60.38, opponent 39.62) with a thin
  blue/red bar under the logo; the list then re-sorts by the team's win rate with that
  pick (orange above about 60). Screenshots in data/team/2026-10-24-ui/refs/pool-draft/
  (gitignored): draftgap-picked.png. ^f6
- [ux/features] The (i) on a row opens a dialog for that pick: four tiles (CHAMPION,
  MATCHUPS, DUOS, WINRATE, each a win rate), a MATCHUPS table (ally, winrate, WINNER
  arrow, opponent, winrate) and a DUOS table of the pick with each ally; thin duo samples
  carry an amber warning triangle; a LOLALYTICS button links out (screenshot
  draftgap-reason.png). ^f7
- [ux/features] DRAFT ANALYSIS tab: the same four tiles for both teams, then Ally and
  Opponent overview tables (role, champion, base, matchup, duo) (screenshot
  draftgap-analysis.png). ^f8
- [ux/features] A star column in the list marks favourite champions: the only pool
  feature, a filter on the same list (screenshot). ^f9
- [ux/layout] Phone at 390 px: the ally column fills the screen, with ALLY, DRAFT and
  OPPONENT as three tabs pinned at the bottom (screenshot draftgap-phone.png). ^f10
- [policy] (inferred) Every number is a win rate to two decimals (team 60.38, each pick
  53.59): the "+X% win rate" framing meio.lol's rules exclude. ^f11

## Read

- First screen text

## Not read

- Settings (risk level, roles) in the live UI
