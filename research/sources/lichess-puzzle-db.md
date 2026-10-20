---
title: 'Lichess open database: puzzles export'
url: https://database.lichess.org/
kind: dataset
commit: 
for: [teach-draft]
looked: 2026-10-20
depth: docs (Puzzles panel)
relevance: high
grade: A/fair
description: Lichess's CC0 export of 6.2 million rated, tagged puzzles, with the field list and how puzzles are generated, rated and voted
---
# Lichess open database: puzzles export

Why: how the largest puzzle product builds puzzles from real games and sets difficulty.

## Assessment

- Evidence: A. Lichess puzzles are played by millions; the export is the live set
  (6,157,341 puzzles, updated 2026-10-05).
- Reasoning: fair. States what is done, not why.
- Interests: none known (non-profit, CC0).
- Weigh: snapshot is the Puzzles panel only (the page's tabs hid it from the browser
  snapshot; text taken from the page HTML).

## Findings

- [learning] [fun] Puzzles are mined from real games: 600 million analysed games, the
  interesting positions re-checked by an engine, then tagged automatically. ^f1
  > We went through 600,000,000 analysed games from the Lichess database, and re-analyzed interesting positions with Stockfish NNUE at 40 meganodes.
  > The resulting puzzles were then automatically tagged
- [learning] Puzzle difficulty is learnt, not set: each attempt is a Glicko2 rated game
  between player and puzzle, so puzzles and players share one rating scale. ^f2
  > each attempt to solve is considered as a Glicko2 rated game between the player and the puzzle
- [learning] A puzzle has one right answer: every solution move is an only move, any other
  loses a lot (mate in one excepted). ^f3
  > All player moves of the solution are "only moves". I.e. playing any other move would considerably worsen the player position.
- [ux/features] The puzzle starts after the opponent's move, so the player first sees what
  just happened, then answers. ^f4
  > The position to present to the player is after applying the first move to that FEN. The second move is the beginning of the solution.
- [fun] [ux/trust] Players vote; votes are weighted by whether the voter solved it and by
  rating gap, and give popularity and refine tags. ^f5
  > votes are weighted by various factors such as whether the puzzle was solved successfully or the solver's puzzle rating in comparison to the puzzle's
  > Finally, player votes refine the tags and define popularity.
- [ux/features] Each puzzle keeps a link to the game it came from, its themes, opening and
  rating deviation. ^f6
  > PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags,DailyDate
- [fun] A daily puzzle is picked from the set. ^f7
  > it indicates the date when the puzzle was featured as a daily puzzle
- [learning] (inferred) For meio.lol: a draft puzzle can be mined the same way, a real
  champ select at the point of one pick, with the answer the pick whose win rate gap over
  the others is large (an only move); rate puzzles and visitors on one scale from attempts. ^f8

## Read

- The Puzzles panel of database.lichess.org.

## Not read

- The other panels (games, evals, openings); the tagger source (lichess-puzzler repo).
