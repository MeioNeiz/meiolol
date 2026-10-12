---
title: 'How Does He Saw Me? A Recommendation Engine for Picking Heroes in Dota 2 (Stanford CS229, 2013)'
url: https://cs229.stanford.edu/proj2013/PerryConley-HowDoesHeSawMeARecommendationEngineForPickingHeroesInDota2.pdf
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (full report)
relevance: medium
grade: C/fair
description: Stanford CS229 student project 2013, the origin of the much-cited 69.8% Dota 2 draft-only accuracy; one-hot LR and weighted kNN on 57k very-high-skill games
---
# How Does He Saw Me? A Recommendation Engine for Picking Heroes in Dota 2 (Stanford CS229, 2013)

Why: the 69.8% draft-only accuracy every later Dota paper cites; what data, split and
caveats sit behind it.

## Assessment

- Evidence: C. Course project, 56,691 games, one month, random split, single run.
  Much cited, rarely re-checked.
- Reasoning: fair. Learning curves shown; clear features; no intervals or log loss.
- Interests: none.
- Weigh: the 69.8% is real for 2013 very-high-skill Dota on a random split, not a
  target for other games or a time split. The side-swap averaging is a cheap trick
  worth copying.

## Findings

- [data] 56,691 matches, 5 Nov to 7 Dec 2013, "very-high" skill (about top 8%), modes
  including all random and random draft, games with leavers removed; random 90/10
  split. Section III ^f1
  > We used Valve’s Steam web API [4] to pull data for 56691 matches between November 5 and December 7.
  > The skill level of the players is “very-high,” which corresponds to roughly the top 8% of players.
  > No players leave the match before the game is completed.
  > We exported 90% of the matches from our database to form a training set of 51,022 matches.
- [method] Features: 216-dim one-hot, one block per side (Radiant heroes, Dire
  heroes). Section IV.A ^f2
- [method] [data] Side-swap averaging at prediction: score the match as is and with
  the teams swapped, average p and 1 - p_swapped, so the model uses both side
  configurations. Section IV.B ^f3
  > Calculate the overall probability overall_prob as the average of rad_prob and (1 − dire_prob)
- [method] LR learning curve plateaus: test accuracy approaches 69.8% at about 18,000
  training games; train and test accuracy close (no overfitting, so more data does not
  help an additive model). Section IV.C ^f4
  > The test accuracy of our model asympotitcally approaches 69.8% at about an 18,000 training set size
- [method] Weighted kNN (pair and higher interactions via match similarity) reached
  67.4% in CV and nearly 70% at 50,000 games, still rising, i.e. interaction models
  need more data than LR before they pay. Section IV.D ^f5
  > The test accuracy of our model monotonically increases with training set size up to nearly 70% for around 50,000 training matches.
- [tools] Dota2cp, an earlier LR draft predictor, reported 63% accuracy. Section II ^f6
  > Given two teams of five heroes, the author reports a 63% accuracy of predicting the winning team.
- [method] (inferred) Random-hero modes (all random, random draft) in the sample
  make hero strength vary more than in chosen drafts, which may inflate draft-only
  accuracy relative to a pure draft queue. ^f7

## Read

- Full report (sections I-IV, learning curves)

## Not read

- Nothing material
