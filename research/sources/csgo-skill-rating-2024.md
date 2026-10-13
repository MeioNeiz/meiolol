---
title: 'Skill Issues: An Analysis of CS:GO Skill Rating Systems (Bober-Irizar, Dua, McGuinness, 2024)'
url: https://arxiv.org/pdf/2410.02831
kind: paper
commit:
for: [pregame-player-skill]
looked: 2026-10-13
depth: docs (whole paper; Table I numbers from the text)
relevance: low
grade: C/fair
description: Cambridge student paper; Elo, Glicko2, TrueSkill per team and per player on 9.9k pro CS:GO matches with simulated matchmaking; per-player TrueSkill best at 64.1%; random 50/50 split, no time
---
# Skill Issues: An Analysis of CS:GO Skill Rating Systems (Bober-Irizar, Dua, McGuinness, 2024)

Why: a lead from [[draft-predictor-methods]]: which rating system predicts team-game
outcomes best, and per-player vs per-team ratings.

## Assessment

- Evidence: C. Student project, 9,929 professional and semi-pro matches (HLTV,
  2017-2022), 100 runs per cell; random 50/50 split ignoring time.
- Reasoning: fair. Clear framework; the question (which matchups to sample) is
  matchmaking design, not outcome prediction from history.
- Interests: none known; their Weighted acquisition function is the favoured side.
- Weigh: pro teams with fixed rosters are unlike solo queue; a random split lets later
  results inform earlier ones. Only the relative order of systems carries over.

## Findings

- [data] Data: 9,929 pro and semi-pro CS:GO matches 2017-2022 from hltv.org, split at
  random 50/50 into training and evaluation, time ignored. ^f1
  > For the analysis, we used all matches with a greater than or equal to “1 star” team rating between 2017-2022, for a total of 9,929 matches.
  > and evaluation set using a random 50/50 split.
- [stats] Per-player TrueSkill (10 ratings per match) beats all per-team systems by
  about 1 point, best 64.1%. ^f2
  > The TSPlayers emulator beats all other approaches by around 1%, giving us the best achieved average accuracy of 64.1%.
- [stats] Among per-team systems, Glicko2 beat TrueSkill and Elo, most with few
  training matches. ^f3
  > We find that among the team-based skill rating systems, Glicko2 provides better performance across the board, with greater gains with fewer training matches.
- [stats] Prior work cited: TrueSkill on CS:GO 62% (Makarov et al.); Dehpanah et al.
  found new players hard to fold in. ^f4
  > They analysed TrueSkill on CS:GO games and observed a 62% accuracy [11].
  > incorporation of new players into the model proved tricky, and deteriorated the performance of these rating systems.
- [method] Choosing matches the model is unsure about (likeliest draw) adds 1-1.5
  points over random selection at equal training size. ^f5
  > The LikeliestDraw and CrossEntropy AFs select matchups which the emulator is unsure about, and this yields an improvement of 1-1.5% over random matchups from the dataset.
- [method] (inferred) For us: pro CS:GO ratings reach 62-64% because pro matches are
  not skill-balanced; solo-queue LoL is matchmade, so the same systems sit near 50-55%
  ([[dehpanah-team-skill-aggregation#^f3]], [[lol-skill-decomposition#^f4]]). The one
  transferable point: ratings per player beat ratings per team by about a point. ^f6

## Read

- Whole paper: framework, emulators, acquisition functions, data, results, sensitivity

## Not read

- Table I cell by cell (only the text's summary numbers used)
