---
title: 'STRATZ: How much does pick phase matter? (Dota 2, 2017)'
url: https://stratz.medium.com/how-much-does-pick-phase-matter-c87207eb5ebc
kind: article
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: listed (whole post; tables are images, not read)
relevance: medium
grade: C/fair
description: Dota 2 stats site's short post on hero win rate by pick phase in all-pick pubs, and its selection reading of first-pick win rates
---
# STRATZ: How much does pick phase matter? (Dota 2, 2017)

Why: Dota match data records pick order; what did a stats site see when splitting hero
win rates by when the hero was picked?

## Assessment

- Evidence: C. Stats site with full pub data; the tables are images, so no numbers
  could be quoted; 2017, one patch era.
- Reasoning: fair. Gives the selection explanation explicitly for first-pick win rates.
- Interests: STRATZ promoting its hero pages.
- Weigh: the direction (win rate varies by pick phase, partly through who dares pick
  early) is the point; sizes unverified.

## Findings

- [method/causal] [draft] Dota pub data splits hero win rate by pick phase; some heroes
  win more picked first, some last, some do not care. ^f1
  > These are the heroes who have the lowest standard deviation of win-rate at different pick phases.
- [method/causal] Their reading of high first-pick win rates on hard mid heroes is
  selection, not draft value: only confident, experienced players first-pick them. ^f2
  > They are 1st picking Shadow Fiend or Ember because they are experienced and win more with it!
- [method/causal] [stats] Matchup "advantage" is the matchup win rate minus the one
  expected from both heroes' overall win rates, the same additive centring as ours. ^f3
  > Advantage is calculated by estimating the **expected** winrate of hero X against hero Y based upon their individual average winrates.
- [method/causal] (inferred) So pick order carries two signals that a matchup table
  mixes: the counter-pick response (the later picker chose with knowledge of the
  opponent) and picker confidence (who is willing to pick early). LoL match-v5 hides
  both; Dota data shows they are real. ^f4

## Read

- Text of the post; tables (images) not read.
