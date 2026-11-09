---
title: 'Mobalytics: Gamer Performance Index Explained'
url: https://mobalytics.gg/gpi/
kind: docs
commit: 
for: [postgame-review-compare]
looked: 2026-11-06
depth: listed (whole page; seven of eight skill tabs are images, only Fighting rendered as text)
relevance: high
grade: B/weak
description: Mobalytics' GPI explainer (old page, still served, 2026 footer): eight skills scored 0 to 100 by machine learning, 0 like Bronze and 100 like Challenger; Fighting broken into Duels, Picks, Skirmishes, Teamfights, Stat Contribution
---
# Mobalytics: Gamer Performance Index Explained

Why: what GPI scores, on what scale, and against whom it compares a player.

## Assessment

- Evidence: B. Vendor's own explainer for its core feature, still linked from the footer ("Company: GPI"); the text dates from the open beta (it still says "Sign up to get access to the Mobalytics Open Beta") but the page is served in 2026.
- Reasoning: weak. Names the inputs, not the model or weights.
- Interests: vendor.
- Weigh: trust the scale and the comparison basis (rank ladder); the "machine learning" and "positioning, decision making" inputs are unverified claims.

## Findings

- [learning] GPI scores eight areas of play from 0 to 100 and uses them to name a play style, strengths and weaknesses. ^f1
  > Our GPI scores eight critical areas of your play on a scale from 0 to 100. Using these scores, we’re able to define your play style and pinpoint your strengths and weaknesses.
- [learning] [ux/trust] The comparison basis is the whole rank ladder: near 0 plays a skill like a Bronze player, 100 like the best Challengers. ^f2
  > the closer you are to zero the more like a Bronze player you are at that skill. On the opposite end, a score of 100 puts you at the top of your game, like the best Challenger players.
- [learning] Pitched as going past the plain numbers other sites show, to personal insights. ^f3
  > our goal is to go above and beyond the simple statistical numbers that other sites give and provide you with personalized insights to level up your game.
- [learning] (claim) Fighting is computed from kills and assists, damage dealt and taken, fight frequency, positioning and trade decisions; split into Duels, Picks, Skirmishes, Teamfights and Stat Contribution. ^f4
  > It’s calculated based on your kills and assists, the damage you deal and receive, fight frequency, positioning, and decision making during trades and skirmishes.
- [learning] Stat Contribution is judged relative to the player's role and champion type. ^f5
  > Measures your ability to do your job in fights relative to your role and the type of champions you play.
- [learning] The page admits a single skill score does not make a player good overall. ^f6
  > being able to farm like Doublelift doesn’t necessarily translate to playing like him.
- [ux/trust] (inferred) A 0-100 score anchored to Bronze and Challenger is a verdict on the player, not a fact about a game; the inputs ("decision making") cannot be checked by the player. ^f7

## Read

- Whole page (Fighting tab text; the other seven skill tabs did not render as text)

## Not read

- mobalytics.gg/lol/lp/gpi and /lol/lp/progress-analysis (current landing pages linked in the footer)
