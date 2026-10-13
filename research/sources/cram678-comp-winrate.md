---
title: League of Legends the affect of Team Composition on Win Rate (Rosenberg, UMich student project)
url: https://cram678.github.io/league-of-legends-data-analysis/
kind: project
commit:
for: [comp-attribute-features]
looked: 2026-10-13
depth: docs (full write-up page; code not read)
relevance: medium
grade: D/weak
description: Student project (UMich) on about 9.6k games: champion class counts from the wiki as win features; class-only models score 0.515-0.516 accuracy, champions plus class counts plus opponent 0.55
---
# League of Legends the affect of Team Composition on Win Rate (Rosenberg, UMich student project)

Why: does a class-tag composition (tank, mage, marksman counts) predict win beyond chance,
and beyond champion ids?

## Assessment

- Evidence: D. One student project, about 9,600 games (115,152 rows at 12 per game, a
  per-player plus team-summary layout that looks like Oracle's Elixir pro data; source
  not named), one random split implied, accuracy only, no ablation.
- Reasoning: weak. The final model adds champion names, class counts and the opponent's
  features at once, so the jump from 0.51 to 0.55 cannot be credited to class counts.
- Interests: none.
- Weigh: the class-only result (near 0.5) is the usable part: coarse class tags alone
  carry almost no win signal. Treat 0.55 as champion-id signal until shown otherwise.

## Findings

- [data] Data: 115,152 rows, 12 per game (5 players plus a team summary per side), so
  about 9,600 games; classes from a hand-made wiki table. ^f1
  > The main data set has a total of 115152 rows with every 12 rows representing a single game between two teams each team has 6 rows of data one for each player and one for an overall team summary.
- [draft] Attribute source: 7 wiki classes (Marksman, Fighter, Slayer, Tank, Mage,
  Controller, Specialist), multi-class champions hand-assigned to one. ^f2
  > some champions were assigned multiple roles by the wiki so I selected one of the roles based on which I believed to be more representative of the champion
- [draft] Per-class win rates sit within a narrow band around 50% (Marksman 50.19%). ^f3
  > The difference between classes is actually relativley small suggesting a relative parity in winrates between classes.
- [draft] Class diversity: teams with 3, 4 or 5 distinct classes have similar median win
  rates; only the spread differs (3 classes: 754 team-games, 4: 8,566, 5: 9,286). ^f4
  > Although the medians arent very different between the three different types of team composition the teams with 5 different classes have a much more concentrated distribution
- [method] Class-only models (class per pick plus number of unique classes, own team
  only) score about chance: gradient boosting 0.516, SVM 0.515. ^f5
  > my attempt with gradient boosting for example had an accuracy of .516 while my attempt with SVM had an accuracy of .515
- [method] Final SVM: champion names, unique-class count, 7 class-count columns, plus the
  opponent's same features (26 inputs): 0.55 accuracy. No ablation of class counts vs
  champion ids. ^f6
  > I decided to add all of those columns except for the opponent the team was facing I think this was likely the most impactful change
- [method] Checked, not there: log loss, AUC, a champion-id-only baseline, a temporal
  split, damage type, CC or any profile feature beyond class. ^f7

## Read

- The GitHub Pages write-up.

## Not read

- Repo code and notebook (github.com/cram678/league-of-legends-data-analysis): would show
  the data source and split.
