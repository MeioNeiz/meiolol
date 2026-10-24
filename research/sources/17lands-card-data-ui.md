---
title: '17Lands: card data (MTG Arena draft)'
url: https://www.17lands.com/card_data?expansion=FRA&format=PremierDraft&time_period=ALL_TIME
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900)
relevance: medium
grade: B/fair
description: 17Lands card data: a grades view (tier grid by colour column and grade row) and a table view with column groups toggled by checkboxes, each rate beside its count
---
# 17Lands: card data (MTG Arena draft)

Why: a non-League tier grid and table from a data-first community site.
Shots: data/team/2026-10-24-ui/refs/tier-list/17lands-card-*.png.

## Assessment

- Evidence: B. Widely used by MTG drafters; live page.
- Reasoning: fair (metric definitions linked).
- Interests: community, Patreon.
- Weigh: screenshots.

## Findings

- [ux/layout] Two views of one data set, Grades and Table, as a big two-way switch (seen in screenshot 17lands-card-data.png). ^f1
  > Use this tool to explore individual card-level data in each format
- [ux/layout] Grades view is a grid: colours as columns, grades (A+, A, A-...) as rows, each card a small tile with its win rate; hover shows the card image (seen in screenshot 17lands-card-data.png). ^f2
- [ux/density] Table view puts each rate beside its own count (# GP then GP WR, # OH then OH WR), and checkboxes turn column groups on or off; an export button sits above (seen in screenshot 17lands-card-table.png). ^f3

## Read

- Page text; two desktop shots

## Not read

- Metric definitions page
