---
title: 'meiolol: blind pick ranking (J2) and matchup spreads (own results, Oct 2026)'
url: docs/model.md
kind: dataset
commit: 5b2ce85b
for: [blind-pick-safety]
looked: 2026-11-02
depth: listed (model.md "Blind pick ranking (J2)"; learned.md lines on blind ranking and matchup spread)
relevance: high
grade: A/strong
description: Our own pre-declared test of safer blind rankings (low end, spread) against ranking as if the lane opponent were average, on 86k held-out games, plus our noise-corrected matchup spreads by role
---
# meiolol: blind pick ranking (J2) and matchup spreads (own results, Oct 2026)

Why: the evidence the app's blind ranking rests on, to set beside MachineLoLing's
blindability.

## Assessment

- Evidence: A. Pre-declared variants, dev then one test look on 85,904 held-out games;
  spreads from method of moments on 269k games and the additive v2 fit on 134k.
- Reasoning: strong. Names its own confound (low-end offsets track popularity).
- Interests: our own; that is why the test was pre-declared.
- Weigh: the J2 opponent weights are the role's meta, not the opponents a blind pick
  actually meets; pick order is not in the data.

## Findings

- [method] [draft] Ranking blind as if the lane opponent were average is as good as any safer ranking tried (25th/10th percentile, mean minus spread, rating lower bound). `docs/model.md` J2 ^f1
  > Before your lane opponent picks, ranking as if they were average is as good as any safer ranking we tried
  > Result: no ranking gains on every measure.
- [method] The safer offsets correlate -0.58 to -0.66 with log role games, so they push popular champions down and partly measure popularity. ^f2
  > The safer lists push popular champions down, so they partly measure popularity, not safety.
- [method] The expected lane term is about 0 by construction: the base rating already averages the champion over its real opponents. ^f3
  > the fitted base rating already averages the champion over its real opponents
- [method] Not tried: spreads with each pair's posterior variance taken out (score.termVar); pick order is not in the match data, so counter-picked seats can't be split out. ^f4
  > a spread with each pair's posterior variance taken out (score.termVar) wasn't tried
- [draft] [stats] Noise-corrected lane matchups differ by about 2 points in top and mid, 1.2 bot, 1.0 support, 0.7 jungle once both champions' win rates are allowed for. `docs/learned.md` ^f5
  > Once the two champions' own win rates are allowed for, lane matchups still differ by about 2 points in top and mid, 1.2 in bot, 1.0 in support and 0.7 in jungle
- [draft] In additive v2, mid matchups spread 1.7-2.1 points, top 2.2-2.5; cross-role, mid vs enemy bot and bot vs enemy support 0.8-1.1; among allies only bot and support show (1.3-1.6). ^f6
  > mid 1.7-2.1, support 1.2-1.5, bot 1.1-1.3, jungle 1.0-1.4; mid vs enemy bot and bot vs enemy support 0.8-1.1. Among allies only bot and support show (1.3-1.6).

## Read

- The J2 section of docs/model.md whole; the three learned.md lines

## Not read

- src/blindpick.zig (the code behind `meiolol eval --blind`)
