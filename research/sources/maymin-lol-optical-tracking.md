---
title: 'Maymin 2018: An open-sourced optical tracking and advanced eSports analytics platform for League of Legends (Sloan)'
url: https://global-uploads.webflow.com/5f1af76ed86d6771ad48324b/5ff4ac99b18b32db04079ef8_An%20Open-Sourced%20Optical%20Tracking%20and%20Advanced%20eSports%20Analytics%20Platform%20for%20League%20of%20Legends.pdf
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (sections 1-4, tables 3-6)
relevance: medium
grade: C/weak
description: Maymin's Sloan 2018 paper (precursor of his 2021 JQAS "Smart kills and worthless deaths"); spectator-scraped solo queue games, a per-minute logistic win model, kills and deaths split by win probability change
---
# Maymin 2018: An open-sourced optical tracking and advanced eSports analytics platform for League of Legends (Sloan)

Why: the one LoL paper we know that values kills and deaths by the change in in-game win
probability. The 2021 JQAS version ("Smart kills and worthless deaths") is paywalled; this
Sloan paper is its open precursor with the same method.

## Assessment

- Evidence: C. Sloan research paper competition; several million solo queue games
  scraped from spectator mode, ~150k on one patch for the stat sections. No test-set
  accuracy, calibration plot or coefficients for the in-game win model are reported.
- Reasoning: weak on the event-value part: an event counts as "smart" if win probability
  rose after it, with no attempt to separate the event from the state it happened in.
- Interests: author's own platform and app.
- Weigh: useful as the LoL instance of WPA (win probability before vs after an event)
  and for its feature choice; no effect sizes per objective to reuse.

## Findings

- [method] In-game win model: logistic regression per minute on minutes elapsed and each
  team's kills, towers and large monsters killed; deliberately few features so a phone
  app could compute it live. Section 3.1 ^f1
  > These features are: the red and the blue team’s kills, towers, and large monsters killed. We also chose to look at each incremental minute rather than every second.
  > The machine learning model we used was logistic regression.
- [method] [stats] Within-game correlation handled by sampling one random minute per game,
  giving independent rows. Section 3.1 ^f2
  > To counteract this issue, and because we had the luxury of millions of games, we chose a random minute from each game, leaving us with millions of independent rows.
- [method] Gold difference left out of the win model on purpose: argued to mislead late
  and to be hidden from players in game. Section 3.1 ^f3
  > Notably absent from our model is the total gold for each team.
  > total enemy gold is not revealed to players in game and must be estimated.
- [method] Event value is the sign of the win probability change across the event: a
  smart kill raises it, a worthless death does not. Section 3.3 ^f4
  > depending on if the team’s probability of winning increased or decreased following the event.
  > let us call a worthless death one that did not increase your team’s win probability and a smart kill one that did.
- [data] Several million games scraped by spectating from a Challenger seed list; the
  stat sections use ~150,000 games from the latest patch. Section 3, footnote 2 ^f5
  > By this process, we scraped several million games.
  > we focused on the ~150,000 games from the latest patch for the purposes of this section
- [method] Post-game win probability chart annotated automatically at local minima and
  maxima (e.g. a lost dragon at 35%). Section 4.1.3 ^f6
  > We further extend this standard type of graph with automatic annotations indicating key states of the game at local minima and maxima.
- [stats] Checked, not there: no per-event or per-objective win probability values, no
  intervals, no control for the team already being ahead beyond the state features. ^f7
- [method] (inferred) Our timelines give the same features (kills, towers, monsters by
  type, per minute), so this is a lower bound on our win-by-minute model; the "before vs
  after" delta is cheap but bundles the event with whatever else happened in the gap. ^f8

## Read

- Sections 1-3.4, 4.1.3, 4.2 (stat bundle regressions)

## Not read

- The 2021 JQAS paper itself (paywalled, De Gruyter): may add coefficients or validation
- Section 4.1.1-4.1.2 (app screens), fast and frugal trees
