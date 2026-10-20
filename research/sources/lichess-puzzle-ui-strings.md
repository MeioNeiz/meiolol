---
title: 'Lichess lila source: puzzle UI strings (translation/source/puzzle.xml)'
url: https://raw.githubusercontent.com/lichess-org/lila/master/translation/source/puzzle.xml
kind: project
commit: 
for: [teach-draft]
looked: 2026-10-20
depth: code (translation/source/puzzle.xml)
relevance: medium
grade: A/fair
description: The English source strings of Lichess's puzzle screens, showing the feedback a solver sees per move, after a puzzle and in Puzzle Streak and the dashboard
---
# Lichess lila source: puzzle UI strings (translation/source/puzzle.xml)

Why: what feedback Lichess gives during and after a puzzle (the explain-after part), from
the shipped text rather than a summary.

## Assessment

- Evidence: A. lichess-org/lila, 18,863 stars, pushed 2026-10-19; these strings are what
  millions of solvers see.
- Reasoning: weak. Strings only, no rationale.
- Interests: none known.
- Weigh: strings show what exists, not layout or order; a string can be unused.

## Findings

- [ux/features] Per-move feedback is terse: Best move!, Keep going…, and
  the wrong-move line below; no prose
  explanation of why. ^f1
  > That's not the move!
- [fun] [ux/features] After a puzzle: did you like it, vote, or jump straight on; the
  link back to the source game is shown (From game %s). ^f2
  > Did you like this puzzle?
- [learning] Difficulty is a player choice on top of the rating match (easier, harder). ^f3
  > Difficulty level
- [learning] [ux/trust] Lichess says the rating is not a competition, only a way to pick
  puzzles at the right level. ^f4
  > Note that puzzles are not a competition. Your rating helps select the most appropriate puzzles for your skill level.
- [fun] Puzzle Streak: progressively harder puzzles, no clock, one wrong move ends it,
  one skip per run. ^f5
  > Solve progressively harder puzzles and build a win streak. There is no clock, so take your time. One wrong move, and it's game over! But you can skip one move per session.
- [learning] The dashboard names weak themes to train and strong ones, and keeps failed
  puzzles to replay (%s to replay). ^f6
  > Train these to optimise your progress!
  > You perform the best in these themes
- [learning] Puzzles can come from the player's own games. ^f7
  > View puzzles from a player's games
- [learning] (inferred) Lichess teaches by the position, not by words: the explanation is
  the move itself, the theme name and the game it came from. A draft puzzle on
  meio.lol would need more said after the answer (why this pick wins, with numbers),
  since draft has no forced line to replay. ^f8

## Read

- translation/source/puzzle.xml.

## Not read

- The UI code (ui/puzzle) that orders these; the analysis board shown after solving.
