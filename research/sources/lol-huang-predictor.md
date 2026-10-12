---
title: League of Legends Win Predictor (Huang, Kim, Leung, Northwestern EECS 349, 2015)
url: http://thomasythuang.github.io/League-Predictor/
kind: project
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (whole project page)
relevance: medium
grade: D/weak
description: 2015 student project claiming 91-93% pre-game accuracy from players' champion win rates on 300 test games; a textbook leakage case
---
# League of Legends Win Predictor (Huang, Kim, Leung, Northwestern EECS 349, 2015)

Why: an often-cited 90%+ pre-game claim from player-champion win rates; check for leakage.

## Assessment

- Evidence: D. Class project, 300 train and 300 test games, Weka defaults.
- Reasoning: weak. Takes 92.8% at face value; never asks when the win rates were read.
- Interests: none.
- Weigh: the numbers only show how strongly a win rate that contains the game predicts
  the game. Cited as the precedent in [[lol-hall-history-nn]].

## Findings

- [data] Features: each player's overall win rate on the champion they play in the match,
  pulled from the API; 300 train and 300 test matches. ^f1
  > the overall winrate for each player for the champion that they are using
- [method] Results: champion picks alone 64% (Naive Bayes); per-player champion win rates
  91%; summed per team 92.8%. ^f2
  > we found a very significant increase up to 91% on the testing set with Naive Bayes
- [method] One team's summed win rate alone gave 89%, from a single decision-tree
  threshold. ^f3
  > The best result on the testing set was J48 decision tree at 89%.
- [method] Checked, not there: nothing on whether win rates were read before the match or
  exclude it. ^f4
- [method] (inferred) Leakage: a career champion win rate read after the match includes
  it, and for players with few games on the champion it nearly is the label. One team's
  five numbers cannot honestly predict 89% of matchmade games when every clean pre-game
  study lands at 55-60% ([[lol-player-champion-experience#^f2]]). ^f5

## Read

- Whole page

## Not read

- abstract.pdf (same content, shorter)
