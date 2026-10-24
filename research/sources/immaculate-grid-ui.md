---
title: 'Immaculate Grid (Baseball): daily 3x3 trivia grid (Oct 2026)'
url: https://www.immaculategrid.com/
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (first screen behind modals, then the grid on phone; rendered text and screenshots)
relevance: medium
grade: B/fair
description: Sports Reference's daily grid: name a player for each of nine row-by-column cells, nine guesses, score plus a rarity score from how few others chose your answer
---
# Immaculate Grid (Baseball): daily 3x3 trivia grid (Oct 2026)

Why: lol-site-ui, kind 8: a stats site's daily game, the closest analogue to a stats
site adding a puzzle. Screenshots data/team/2026-10-24-ui/refs/puzzle/
immaculate-phone.png, immaculate-desktop-modal.png (gitignored).

## Assessment

- Evidence: B. Sports Reference, grid #1301, now six sports.
- Reasoning: n/a (product).
- Interests: Sports Reference accounts (a sign-up modal over the how-to on first visit).
- Weigh: the grid and rarity are the ideas; the first visit is two modals deep.

## Findings

- [ux/puzzle] A 3x3 grid: three column categories and three row categories as text
  headers, nine empty cells about 95 px square on phone; tapping a cell opens a player
  search (screenshot immaculate-phone.png). ^f1
  > GRID #1301 ... 2000+ HITS CAREER
- [ux/puzzle] Nine guesses for nine cells, a big counter and a Give Up button. ^f2
  > GUESSES LEFT ... Give Up
- [ux/puzzle] Each category explains itself on tap rather than on the page. ^f3
  > Tap on a logo or category for help.
- [ux/puzzle] (claim) After nine guesses the game scores correct answers and a rarity
  score from how obscure the answers were, i.e. how few other players chose them
  (about modal, screenshot immaculate-desktop-modal.png). ^f4
- [ux/layout] First visit on desktop: an About and How to play modal, then a Sports
  Reference sign-up modal over it, before the grid is visible (screenshot 24 Oct). ^f5
- [ux/puzzle] Links to Previous Grids and Today's Results beside the grid number. ^f6
  > Previous Grids ... Today's Results

## Read

- First screen and grid.

## Not read

- A full game and the results page.
