---
title: DeepLoL summoner profile (BUILT#2603, EUW)
url: https://www.deeplol.gg/summoner/euw/BUILT-2603
kind: docs
commit: 
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: listed
relevance: high
grade: B/fair
description: DeepLoL profile, Oct 2026: AI-Score per game (0 to 100) with MVP/ACE and place in the game, AI Tier Prediction, a "Fate" label per game, LP graph, recently played with and against, OTP build and Live Game tabs; free, ad-funded, no login
---
# DeepLoL summoner profile (BUILT#2603, EUW)

Why: DeepLoL's AI score and what is free.

## Assessment

- Evidence: B. Live page, 1568 words of text; matches the player's U.GG record (560W 432L).
- Reasoning: weak. Scores and labels with no method on the page (a "What's AI-Score" link only).
- Interests: vendor.
- Weigh: shows what a free site gives everyone; the score's meaning is unknown ([[deeplol-home#^f4]]).

## Findings

- [tools/phase] [learning] Post game: every match gets an AI-Score (0 to 100) and the player's place in the game (MVP, ACE, 3rd, 8th). ^f1
- [learning] Each game also gets a "Fate" label (Solid, Balanced, Messy, Doomed), and the profile a summary ("Messy (Top 67%)"). ^f2
  > Messy (Top 67%)
- [learning] An "AI Tier Prediction" on the profile summary, a rank estimate from the scores. ^f3
  > AI Tier Prediction
- [ux/features] Between games: LP graph over the last 30 days with peak, recent champions with KDA and win rate, recently played with and against (other players' names and records). ^f4
  > Recently Played With (Recent 20 Games)
- [tools/phase] Tabs: Summary, Champions, OTP Build, Live Game. ^f5
- [tools/accounts] Pros and streamers register through a help desk form; the profile links to a pro page. ^f6
  > PRO/STRM Registration
- [tools/paid] [tools/accounts] Checked, not there: no login, premium tier, ad-free option or claim/verify on the page; ad-funded with 664 consent partners. ^f7
- [policy] (inferred) Ranking all ten players in each game by score (MVP to 10th) is a public grade of other players; a stronger version of what meiolol avoids. ^f8

## Read

- Summary tab, logged out.

## Not read

- The AI-Score explainer (a modal, not in the text); Live Game tab.
