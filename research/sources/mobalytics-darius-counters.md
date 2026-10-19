---
title: 'Mobalytics: Darius counters (patch 26.20)'
url: https://mobalytics.gg/lol/champions/darius/counters
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (page innerText, fold and full-page screenshots)
relevance: high
grade: B/fair
description: Mobalytics counter page: best and worst picks as tabs, a pinned Overall Average row above the opponents, tinted rows, written counter tips beside the table
---
# Mobalytics: Darius counters (patch 26.20)

Why: how a major site anchors per-opponent win rates so a reader knows what "good" is.

## Assessment

- Evidence: B. Major LoL site ([[similarweb-mobalytics-gg]]); live page.
- Reasoning: fair. Defines its list in one sentence.
- Interests: vendor (desktop app).
- Weigh: text snapshot is the page's innerText (the Markdown fetch only got the nav).

## Findings

- [ux/layout] A pinned first row gives the champion's overall win rate and matches, so every opponent's number below reads against it. ^f1
  > Overall Average 50.3% 150 765
- [ux/layout] Best and worst picks are two tabs of one list, each with a one-line definition of how it is sorted. ^f2
  > These champs are strong against Darius at most phases of the game. They’re listed based on their win rate against Darius.
- [ux/colour] Rows above the average get a dark green row tint that fades out further down the list, a whole-row heat cue rather than a coloured number (seen in screenshot mobalytics-darius-counters-full.png). ^f3
- [ux/density] Roomy rather than dense: 48 px round portraits, rows about 66 px tall, only three columns (WR, matches, a guide link), about 10 rows per screen (seen in screenshot mobalytics-darius-counters-full.png). ^f4
- [ux/layout] Templated summary sentence at the top names the best counters and the champions Darius beats. ^f5
  > the best counters for Darius Top are Teemo, Dr. Mundo, Wukong, Gangplank and Quinn

## Read

- Page innerText; screenshots

## Not read

- Per-matchup pages (see [[mobalytics-darius-vs-garen]])
