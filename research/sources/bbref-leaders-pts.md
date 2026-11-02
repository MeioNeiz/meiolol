---
title: 'Basketball Reference: career points leaders page'
url: https://www.basketball-reference.com/leaders/pts_career.html
kind: dataset
commit:
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: skimmed (header, legend, rank column, ties, links to other leaderboards)
relevance: medium
grade: A/fair
description: Sports Reference leaders page: ranked list with ordinal ranks, active players bold, tied players share a rank, a family of leaderboards per stat
---
# Basketball Reference: career points leaders

Why: the plain "full ranking" a "value (rank)" on a player page links to
([[bbref-jokic#^f5]]).

## Assessment

- Evidence: A. Reference basketball site, decades of use.
- Reasoning: fair. One legend line, no method text on the page.
- Interests: sells Stathead; consent pop-ups sit above the content.
- Weigh: text snapshot only; layout on phone not seen.

## Findings

- [ux/layout] The list is three columns, "Rank | Player | PTS", with the rank as an
  ordinal ("29."), 250 rows per list on one page, split into sections (NBA/ABA, NBA,
  ABA). ^f1
  > | Rank | Player | PTS |
- [ux/density] Ties share a rank by leaving the rank cell empty on the following
  row: Rick Barry is 29, Reggie Miller 25279 with no number; Horace Grant 244, Josh
  Smith blank at 12996. ^f2
  > |   | [Reggie Miller](https://www.basketball-reference.com/players/m/millere01.html)\* | 25279 |
- [ux/layout] Emphasis is one legend line: active players in bold, an asterisk for
  Hall of Fame. Context, not filters. ^f3
  > Active players are listed in **bold**
- [ux/layout] A leaderboard is one of a family per stat: Single Season, Career,
  Active, Progressive, Year-by-Year, Year-by-Year Top 10, Single Game, each its own
  page linked from a menu; the "(13th)" next to a value on a player page links into
  one of them. ^f4
  > [Year-by-Year Top 10](https://www.basketball-reference.com/leaders/pts_top_10.html)
- [ux/uncertainty] Checked, not there: a career leaders list needs no qualification
  filter (counting stat); no minimum or "qualified" text on the page. ^f5
- [ux/layout] Checked, not there: no sort controls, filters, or highlighted reader
  row on the page text. ^f6

## Read

- Header, legend, first rows, ties near ranks 29 and 244, menu of other leaderboards.

## Not read

- Rate-stat leaders (per game, percentages) where qualification rules apply; phone
  layout.
