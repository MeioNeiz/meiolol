---
title: DraftGap web app
url: https://draftgap.com/
kind: docs
commit: 
for: [competitor-first-visit-returning, desktop-app-layout]
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

## Read

- First screen text

## Not read

- Settings (risk level, roles) in the live UI
