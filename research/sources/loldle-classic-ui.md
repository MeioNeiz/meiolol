---
title: 'LoLdle Classic mode: guess, feedback grid, clues (Oct 2026)'
url: https://loldle.net/classic
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (first screen, four guesses, desktop and phone; rendered text and screenshots)
relevance: high
grade: B/fair
description: LoLdle Classic: type a champion, each guess becomes a row of eight attribute tiles (green, orange, red, up/down arrows), clue unlocks count down by tries; phone scrolls the row sideways
---
# LoLdle Classic mode: guess, feedback grid, clues (Oct 2026)

Why: lol-site-ui, kind 8 (daily games): the League daily game players know, how a
guess and its feedback look. Earlier notes: [[loldle-site]] (modes, funding),
[[lol-loldle-launch]]. Screenshots data/team/2026-10-24-ui/refs/puzzle/
loldle-classic.png, loldle-feedback.png, loldle-phone.png (gitignored).

## Assessment

- Evidence: B. About 2M visits a month ([[similarweb-loldle#^f4]]), live since 2022.
- Reasoning: n/a (product).
- Interests: ad funded (664 consent partners, sticky bottom ad, app-store banner on
  phone).
- Weigh: the guess row and the clue countdown are proven; the colour key panel is the
  thing Jacob rules out.

## Findings

- [ux/puzzle] First screen: logo, six mode icons, four small icons (stats, streak flame
  with count, changelog, help), one instruction box and one input with an arrow button;
  about 15 words of instruction. ^f1
  > Guess today's League of Legends champion!
  > Type any champion to begin.
- [ux/puzzle] Social proof and yesterday's answer under the input. ^f2
  > people already found out!
  > Yesterday's champion was #1569 Yuumi
- [ux/puzzle] [ux/density] Each guess adds a row on top: champion icon then seven
  attribute tiles about 70 px square, filled green (match), orange (partial) or red
  (no), and release year as a red tile with an up or down arrow; tiles flip in one by one
  (screenshot 24 Oct). ^f3
  > Gender ... Position(s) ... Species ... Resource ... Range type ... Region(s) ... Release year
- [ux/puzzle] Hints unlock by tries: three greyed clue icons with a countdown under each
  (quote in 2 tries, ability in 8, splash in 14 after four guesses). ^f4
  > Quote Clue ... in 2 tries
- [ux/colour] A "Color indicators" panel under the grid explains the five tile states,
  with a close button. ^f5
  > Color indicators ... Correct ... Partial ... Incorrect ... Higher ... Lower
- [ux/layout] Phone at 390 px: the eight-column row does not fit; four and a half tiles
  show, with a "Scroll horizontally to see more" line and a compact-view button under it
  (screenshot loldle-phone.png). ^f6
- [ux/puzzle] (inferred) The streak lives in a flame icon with a number in the header,
  not a stats page; the phone banner sells the app on not losing it ("Never lose your
  flame again with daily notifications"), seen in screenshot. ^f7

## Read

- Classic mode, four guesses.

## Not read

- The win screen and share text (answer not found); other modes.
