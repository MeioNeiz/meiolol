---
title: 'Framed: daily movie frame game (Oct 2026)'
url: https://framed.wtf/
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (six skipped guesses to the end screen; rendered text and screenshots)
relevance: high
grade: B/fair
description: Framed: guess a film from up to six frames, each wrong or skipped guess reveals the next frame; the end screen shows the answer, share squares, what other players guessed and the community guess distribution
---
# Framed: daily movie frame game (Oct 2026)

Why: lol-site-ui, kind 8: how a daily game shows feedback and the community after the
answer. Screenshots data/team/2026-10-24-ui/refs/puzzle/framed-guess3.png,
framed-end.png (gitignored).

## Assessment

- Evidence: B. Long-running Wordle-era daily game (#1688), several modes.
- Reasoning: n/a (product).
- Interests: ads and merch on the end screen.
- Weigh: the community statistics on the end screen are the idea to borrow.

## Findings

- [ux/puzzle] One 710 px frame, numbered tabs 1-6 under it (revealed ones clickable),
  a search field with Submit (empty submit skips), and the guess list as rows with a red
  square for each miss; "6 GUESSES REMAINING" counts down (screenshot 24 Oct). ^f1
  > 6 GUESSES REMAINING
- [ux/puzzle] End screen: the answer, six coloured squares and a Share button in one
  line. ^f2
  > THE ANSWER WAS: ... Psycho ... SHARE
- [ux/puzzle] [ux/charts] Community results after the answer: the ten titles other
  players guessed at this guess, as bars with the answer in green and wrong ones in red,
  and the share of players solving on each guess. ^f3
  > Top 10 titles for guess #6
  > GUESS DISTRIBUTION
  > 1 (7.6%) ... Failed (28%)
- [ux/puzzle] Checked, not there: no explanation of the answer beyond the title; the
  frames are the explanation. ^f4
- [ux/layout] An ad sits between the answer and the community stats, and a merch card
  after it (screenshot framed-end.png). ^f5

## Read

- One full classic round.

## Not read

- Stats page, archive, other modes.
