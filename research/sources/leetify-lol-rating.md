---
title: 'Leetify: League of Legends Leetify Rating (beta, May 2025)'
url: https://leetify.com/blog/league-of-legends-updates-leetify-rating
kind: article
commit: 
for: [postgame-review-compare, competitor-steal-beat-avoid]
looked: 2026-11-09
depth: listed (whole post)
relevance: medium
grade: C/fair
description: Leetify's launch post for its League per-game rating, a weighted blend of four stat categories with named bands; a CS2 review tool entering League game review
---
# Leetify: League of Legends Leetify Rating (beta, May 2025)

Why: Leetify is praised in CS2 for review ([[leetify-rating-2024]]); did it bring the same
win-probability rating to League, a direct rival to our game review?

## Assessment

- Evidence: C. A vendor launch post for a beta; no numbers on users or validation.
- Reasoning: fair. Explains weights and bands, admits gaps (not role specific, whole
  match only), but gives no reason for the weights.
- Interests: vendor.
- Weigh: trust what it shows and how it is framed; nothing says the score predicts
  winning.

## Findings

- [tools] [ux/postgame] Leetify added a per-game League rating to its match reports and
  profiles in May 2025, labelled a first beta. ^f1
  > You can now view your Leetify Rating for League of Legends on your match reports! This is the very first beta version of the LoL Leetify Rating
- [method] Unlike its CS2 rating (win probability per round, [[leetify-rating-2024#^f4]]),
  the League rating is a fixed weighted blend: Combat 40%, Economy 35%, Utility 15%, Map
  Control 10%. ^f2
  > These categories are: Combat, Economy, Utility, and Map Control.
- [ux/trust] Shown as a number from zero (average about 0.8) with five named bands, from
  Poor (0.74 or less) to Exceptional (1.10+). ^f3
  > we learned that the average rating will be around 0.8
  > 1.10+: Exceptional Performance
- [ux/postgame] Checked, not there: no moments, no timeline; the score covers the whole
  match, so a strong early game is cancelled by a weak late one. ^f4
  > your rating is dependent on your performance the entire match
- [ux/trust] They admit it is not role specific and will give outlier scores in beta. ^f5
  > this may not encompass every single metric that contributes to each role’s individual strengths and weaknesses
  > You may see outlier scores in your games here and there while the LLR is in beta
- [ux/postgame] Return pitch is celebration and friends: best plays, comparing with
  friends, who carried. ^f6
  > Celebrate your best plays, compare accomplishments with your friends, and see who carried with our automatic match reports.
- [ux/postgame] (inferred) The League version drops what made the CS2 rating credible
  (credit only for what moved the win), landing on the same stat-blend score players
  distrust in Mobalytics and OP.GG ([[postgame-review-compare]] C9). ^f7

## Read

- Whole post (13 May 2025)

## Not read

- Post-Match Journal post (lead): out-of-game factors vs win rate
- Any later League rating version
