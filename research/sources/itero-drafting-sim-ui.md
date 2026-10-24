---
title: iTero Drafting Simulator (Oct 2026)
url: https://www.itero.gg/drafting-simulator
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (one random draft, recommendations, first recommendation's breakdown; rendered text and screenshots)
relevance: high
grade: B/fair
description: iTero's web draft board: ten role slots in two rows of five, a grid of recommended portraits each scored 0-5, and a breakdown panel of sub-scores with pair portraits for synergy and counter
---
# iTero Drafting Simulator (Oct 2026)

Why: lol-site-ui, kind 7: how a draft board is laid out and how a suggestion shows its
reasons. Screenshot data/team/2026-10-24-ui/refs/pool-draft/itero-sim-reasons.png
(gitignored).

## Assessment

- Evidence: B. Same product as the 500k-download app ([[europeangaming-itero-standalone#^f1]]).
- Reasoning: fair. Every sub-score has an (i) tooltip; how they combine is not said.
- Interests: vendor.
- Weigh: the 0-5 scale and the pair-portrait reasons are worth copying; eight sub-scores
  at once is too many.

## Findings

- [ux/layout] Board: one row of ten 55 px portrait slots (five blue, five red, a gap
  between), each with its role icon under it; above it a role picker, Blue/Red toggle,
  Elo bracket or "Use My Account", region; below, Clear Draft, Get Recommendations and
  Model Customization. No bans (screenshot 24 Oct). ^f1
  > Randomize Draft ... Use My Account
- [ux/features] Recommendations are a 5-wide grid of portraits for the chosen role, each
  with one score on a 0-5 scale under it (5.0, 4.9, 4.9 ...), 45 in all; no win rate on
  the grid. ^f2
- [ux/features] Selecting a recommendation fills a breakdown: Overall Score and Laning
  Phase Score as two headline tiles, then Mastery, Champ WR%, Synergy Average, Counter
  Average, AD Ratio and Early Strength Advantage, each with an (i). ^f3
  > Overall Score ... Laning Phase Score ... Counter Average
- [ux/features] [ux/density] Reasons are drawn as pairs: the candidate's portrait
  overlapping each ally (blue ring) with a 0-5 synergy score under it, and each enemy
  (red ring) with a counter score; the lane opponent gets its own pair under "Laning
  Phase Matchups" (screenshot itero-sim-reasons.png). ^f4
  > Laning Phase Matchups
- [ux/features] Team Stats compare both teams: early, mid and late strength advantage,
  AD ratio, total damage and tankiness, my team against enemy team. ^f5
  > Mid Strength Advantage ... Tankiness
- [ux/colour] Scores are coloured teal (good), amber (middling) and red (poor) with no
  key; a 0 mastery shows red (screenshot). ^f6
- [ux/uncertainty] When the lane opponent is not picked, the matchup pair shows a red
  asterisk and a note that it is a blind pick based on averages (screenshot before
  selecting, 24 Oct). ^f7
- [policy] (inferred) A 0-5 score per pair says which pick fits and why without "+X% win
  rate" wording; the one win rate shown is the champion's own (Champ WR%). ^f8

## Read

- Board, recommendations, breakdown for one pick.

## Not read

- Model Customization; Use My Account.
