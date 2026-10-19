---
title: 'Basketball Reference: Nikola Jokic player page'
url: https://www.basketball-reference.com/players/j/jokicni01.html
kind: dataset
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (summary strip, per game table, legends; screenshots)
relevance: high
grade: A/fair
description: Sports Reference basketball player page: summary strip, season-by-season tables with league leaders in bold
---
# Basketball Reference: Nikola Jokic player page

Why: the archetype of a dense stat page that stays readable with plain tables.

## Assessment

- Evidence: A. Running since 2000s, the reference basketball stats site.
- Reasoning: fair. Conventions explained by one-line legends under tables.
- Interests: stats site with Stathead subscription.
- Weigh: screenshots bbref-jokic.png (fold, with consent and promo pop-ups),
  bbref-jokic-pergame.png (`data/team/2026-10-19-night/design-shots/`).

## Findings

- [ux/density] League leader is shown by bold type in the cell, no colour: one legend
  line under each table explains it. ^f1
  > **Bold** season totals indicate player led league.
- [ux/density] The per game table holds about 30 numeric columns and 11 seasons in
  about 300 px: 23 px rows, right-aligned figures, small caps-like red headers, thin
  rules, a bold career row at the bottom. No colour on numbers at all; bolding is the
  only emphasis. (seen in screenshot bbref-jokic-pergame.png) ^f2
- [ux/layout] Above the tables a summary strip shows 8 to 10 headline numbers in two
  rows, this season and career, so the career average is the built-in reference for
  this season. (seen in screenshot bbref-jokic.png) ^f3
- [ux/layout] Awards ride along at the end of each season row as short codes (MVP-1,
  AS, NBA1), linked: context sits in the row, not in a separate block.
  (seen in screenshot bbref-jokic-pergame.png) ^f4
- [ux/layout] Honours and leaderboard rankings appear as "value (rank)", e.g. points
  among active players: rank next to the value instead of a second table. ^f5
  > [Active](https://www.basketball-reference.com/leaders/pts_active.html) 18009 (13th)
- [ux/layout] Tables offer "Hide Partial Rows", "Glossary" and "Switch to Widescreen
  View" controls above them; regular season and playoffs are tabs.
  (seen in screenshot bbref-jokic-pergame.png) ^f6

## Read

- Summary, per game table, legends, leaderboards section heading.

## Not read

- Advanced, shooting and play-by-play tables.
