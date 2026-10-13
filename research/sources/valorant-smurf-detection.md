---
title: 'VALORANT Systems Health Series: Smurf Detection (Riot Brian Chang, 2022)'
url: https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-smurf-detection/
kind: docs
commit:
for: [pregame-player-skill]
looked: 2026-10-13
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Riot VALORANT A/B test of automated smurf MMR adjustment; smurf games stomp 32%, adjusted smurfs reach target MMR in about 4 games while unadjusted ones are ~3 divisions off after 10; detection method withheld
---
# VALORANT Systems Health Series: Smurf Detection (Riot Brian Chang, 2022)

Why: how much do smurfs (new accounts of experienced players) distort a rating, and how
fast does it converge; relevant to our new-account and few-games slots.

## Assessment

- Evidence: B. Riot's own randomised test (50% of detected smurfs adjusted, 50%
  control), NA then global; numbers given for stomp rate and convergence. Detection
  method withheld.
- Reasoning: fair. Clear test design; stomp rate is a coarse outcome; no false positive
  rate for the detector.
- Interests: Riot showing progress on a top complaint.
- Weigh: trust the direction and the convergence numbers for VALORANT; LoL has no
  published equivalent here (LoL's 2025 alt-account linking is in
  [[riot-dev-streamer-mode-2025]]).

## Findings

- [stats] Before adjustment, 32% of games with a smurf ended in a stomp (a win by 8 or
  more rounds). ^f1
  > For reference, before the changes, the stomp rate for smurfs was a whopping 32%
- [method] Randomised test: half the detected smurfs had MMR adjusted, half left as a
  control. ^f2
  > we started off by adjusting MMRs for only 50% of the detected smurfs, while leaving the other 50% alone (this is called the control group).
- [stats] Adjusted smurfs came within 1% of the target stomp rate; the control group
  still stomped in 25% of games. ^f3
  > were within 1% of our target stomp rate,** while the 50% of detected smurfs that we didn't adjust in our control group were still stomping in 25% of their matches!
- [stats] Convergence: adjusted smurfs reached their right MMR in as few as 4 games;
  unadjusted ones were still about 3 divisions off after 10 games. ^f4
  > smurfs that we adjusted were landing in their appropriate MMR in as little as 4 matches
  > whereas the smurfs left alone in the control group were still ~3 divisions away from their correct MMR after playing 10 matches.
- [data] Most alternate accounts exist to play with friends of different rank; overall
  smurf counts fell about 17% after detection and party-rule changes. ^f5
  > By far the most common reason that players have for creating alternate accounts is to play competitively with friends of different ranks.
- [method] (inferred) For us: a low-games account at a low rank is ambiguous (new player
  or smurf). Total account level, champion mastery points far above the account's games
  in our data, and a high early win rate are pre-game signals of an experienced player
  on a new account; mastery before the game partly captures it. A per-slot "rating is
  unconverged" feature (few ranked games this season) lets the model trust rank less
  there. Riot's own correction suggests these slots converge within about 10 games. ^f6

## Read

- Whole post (parts 1-3)

## Not read

- Linked VALORANT systems health posts (AFK, queue dodge, intro)
