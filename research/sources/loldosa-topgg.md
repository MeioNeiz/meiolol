---
title: 'Loldosa (롤도사) Discord bot on top.gg'
url: https://top.gg/bot/1518034488460968047
kind: docs
commit: 
for: [postgame-review-compare]
looked: 2026-11-07
depth: listed (whole listing)
relevance: medium
grade: C/fair
description: Loldosa, a 2026 one-developer League Discord bot (1,000+ servers): post-game report card checking the pre-game read, a 20-second review with key moments, gold swing and one fix; improvement ladder ranked by who improved most, streaks, daily challenges, a shared match feed; PRO $3.99 a month, one free review a day
---
# Loldosa (롤도사) Discord bot on top.gg

Why: a 2025-26 entrant's post-game review, paywall line and return hooks, built around a Discord server.

## Assessment

- Evidence: C. One developer, "running in 1,000+ servers", 892 on the listing's counter, 0 votes and 0 reviews on top.gg.
- Reasoning: fair. Concrete features, commands and prices.
- Interests: vendor (the developer).
- Weigh: trust the feature list and prices; review quality unverified; scouting "who's on a smurf" for all ten may clash with Riot's scouting rules (not our sub-question).

## Findings

- [learning] [tools/phase] At game end, a report card that checks the pre-game read against what decided the game. ^f1
  > **The moment it ends** — a report card. Was the pre-game read right? What actually decided the game?
- [learning] [ux/postgame] Within 20 seconds, a full review: key moments on the map, the gold swing when it broke, one concrete fix for next game. ^f2
  > your key moments on the map, how much gold swung when it broke, and one concrete thing to fix next game. Built from your actual match data, not generic advice.
- [needs] Pitched against generic advice: "built from your actual match data". ^f3
  > Built from your actual match data, not generic advice.
- [learning] Improvement ladder ranks server members by who improved most, not highest tier. ^f4
  > **Improvement ladder** (`/improveleague`) — ranked by **who improved most**, not who's highest tier.
- [fun] Daily return hooks named as such: nightly MVP, win streaks, achievements, daily challenges. ^f5
  > **Nightly MVP, win streaks, achievements, daily challenges** — reasons to open the server every day.
- [fun] [tools/accounts] Social hook: a finished game drops a card in the server channel; friends cheer, vote and leave coaching tips. ^f6
  > when a member finishes a game, a card drops in the channel. Cheer, vote on outcomes, leave coaching tips.
- [learning] A multi-game diagnosis across recent games sits beside the single-game review. ^f7
  > | `/diagnose` | Deep skill diagnosis across recent games |
- [tools/paid] Free: a report card every game and one full review a day. PRO: unlimited reviews and coaching, $3.99 a month, $34.99 a year, $79.99 lifetime, 3-day trial. ^f8
  > **Personal free tier** — a post-game prediction report card on every game, plus one full review a day.
  > **3-day trial**, then $3.99/mo · $34.99/yr · $79.99 lifetime.
- [learning] (inferred) Same shape as OP.GG's and Baron Buff's AI reviews ([[opgg-membership#^f2]], [[baronbuff-home#^f2]]): key moments plus one fix; the new part is the friend group as the return loop. ^f9

## Read

- Whole listing

## Not read

- The bot itself (needs a Discord server and a linked Riot ID)
