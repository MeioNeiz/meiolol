---
title: 'Lichess blog: New Puzzles are here! (Dec 2020)'
url: https://lichess.org/blog/X-S6gRUAAGjNX4ki/new-puzzles-are-here
kind: article
commit: 
for: [teach-draft]
looked: 2026-10-20
depth: docs (whole post)
relevance: high
grade: A/fair
description: Lichess's launch post for its 2020 puzzle system: puzzles mined from site games with Stockfish, one clear solution, themes, post-puzzle voting and Glicko2 puzzle ratings
---
# Lichess blog: New Puzzles are here! (Dec 2020)

Why: why Lichess rebuilt puzzles the way it did, in its own words.

## Assessment

- Evidence: A. Primary post by the site; the system it describes still runs (see
  [[lichess-puzzle-db]], 6.2 million puzzles in 2026).
- Reasoning: fair. Gives the why for single solutions, themes and voting.
- Interests: none known (charity, open source).
- Weigh: launch-day post; details may have changed since.

## Findings

- [learning] [ux/trust] Feedback on the old set made them insist on one clear solution
  per puzzle. ^f1
  > We took to heart the feedback about the previous Lichess puzzles, and made sure the new ones have a single, crystal-clear solution.
- [learning] Making good puzzles is the hard, expensive part of a puzzle product. ^f2
  > The hardest part of any puzzle-centric chess software is making the puzzles.
- [learning] Themes let a player drill a weakness they suspect (rook endgames, missed
  forks). ^f3
  > You can now tailor your training to your own personal requirements.
- [learning] Some themes stay out of the default mix and appear only when asked for
  (equality: find the narrow path to an even position). ^f4
  > These puzzles will only appear when specifically requested.
- [fun] [ux/features] After each puzzle the player votes thumbs up or down and on which
  themes apply; the vote is about enjoyment. ^f5
  > After finishing each puzzle, you will be prompted to vote on two subjects.
  > it's about whether or not you enjoyed the puzzle
- [learning] Each attempt is a Glicko2 game between player and puzzle; new puzzles start
  volatile and settle within days at Lichess's volume. ^f6
  > Every puzzle attempt is a "game" between you and the puzzle. If you get it right you win, and take your ratings points as the prize.
  > Puzzles that are brand-new will have volatile ratings, and it may take some time for them to find their level.
- [learning] Themed puzzles give fewer rating points because naming the theme is a big
  hint. ^f7
  > you will get less rating points from themed puzzles as the theme gives a significant hint
- [fun] (inferred) The Lichess menu around the post shows the play variants of the same
  puzzles: Puzzle Streak, Puzzle Storm, Puzzle Racer. ^f8
- [learning] Checked, not there: the post says nothing on explanations after a puzzle;
  the solution is the engine line, with no prose why. ^f9

## Read

- Whole post.

## Not read

- The themes study it links; the aimchess rating predictor.
