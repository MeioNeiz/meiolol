---
title: 'Leetify: How does Leetify Rating actually work? (Nov 2024)'
url: https://leetify.com/blog/leetify-rating-explained/
kind: docs
commit:
for: [postgame-review-compare]
looked: 2026-11-06
depth: docs (whole article)
relevance: high
grade: A/fair
description: Leetify's current explainer of its CS2 match rating: zero-centred average per round of win probability change, kill credit split 35/30/20/15, five verdict bands, performance not skill, separate Aim Rating
---
# Leetify: How does Leetify Rating actually work?

Why: Leetify's headline per-match number, the CS2 analogue of chess.com Accuracy.

## Assessment

- Evidence: A. Leetify is the most used CS2 stats and review site; the vendor's own
  method page (Nov 2024, still linked as current; a clutch weighting tweak in Mar 2026).
- Reasoning: fair to strong: states inputs, the split, the bands, and what it ignores.
- Interests: vendor.
- Weigh: the bands and the framing (performance vs skill) are what transfer.

## Findings

- [ux/postgame] Leetify Rating is a per-match number centred on zero, shown on the post
  match page and profile; positive did well, negative poorly. ^f1
  > Leetify Rating is a number centered around zero. It can be positive or negative. Positive numbers mean you've done well, while negative numbers mean you've done poorly.
- [ux/postgame] [ux/trust] Five verdict bands turn the number into a word: Great, Good,
  Average, Subpar, Poor (above +5.12 is Great; within 2.09 of zero is Average). ^f2
  > Great: Above +5.12
  > Average: -2.09 to +2.09
- [ux/trust] They tell players to read it on a bell curve: most players in an even game
  are average. ^f3
  > When you see your Leetify Rating, it helps to visualize the number on a bell curve to understand your performance.
- [method] It is the average per round of rating gained, from the change in round win
  probability each kill causes (economy, players alive, which side killed last). ^f4
  > The Leetify Rating you see on the scoreboard is the average Leetify Rating you gained in each round.
  > The size of the kill reward is based entirely on the **Change in Win Probability**.
- [method] Credit for a kill is shared: 35% killer, 30% damage dealers, 15% flash
  assist, 20% the traded teammate; the death's loss goes only to the one who died. ^f5
  > 35% for the player who got the kill
  > the punishment for deaths is placed only on the person who died.
- [method] Win probabilities come from every CS2 match on HLTV (pro play), not from the
  player's own rank. ^f6
  > The percentages for every situation are based on historical data from every Counter-Strike 2 match played on HLTV.
- [ux/trust] Framed as performance, not skill: a lower-ranked friend with a higher
  rating did better in their games, not necessarily better. ^f7
  > Leetify Rating is a performance metric, not a skill metric.
- [ux/trust] FAQ answers the "great game but low rating" complaint: low-impact kills
  (rifles vs pistols, last man in 5v1) and costly deaths in 1v1 and 2v2. ^f8
  > Low impact kills could be getting kills in rounds where your opponents have pistols when you have rifles, or getting the kill on the last player when your team is already up in a 5v1.
- [ux/postgame] Aim Rating is a separate score for mechanics; Leetify Rating is impact on
  winning; the two can disagree. ^f9
  > Leetify Rating is meant to measure your overall impact on winning the game, while Aim Rating measures your mechanical ability.
- [ux/postgame] [fun] The pitch is social: celebrate best plays, compare with friends,
  see who carried, in automatic match reports. ^f10
  > Celebrate your best plays, compare accomplishments with your friends, and see who carried with our automatic match reports.

## Read

- Whole article and FAQ.

## Not read

- Charts (images); Rating Breakdown tab post (2023); Mar 2026 clutch update.
