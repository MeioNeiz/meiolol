---
title: 'Finviz: stock screener overview table'
url: https://finviz.com/screener.ashx
kind: dataset
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (fold screenshot; text snapshot is only site chrome)
relevance: medium
grade: A/fair
description: Finviz screener, dark theme: filters on top, 20 rows of 5,607 stocks, numbers coloured by sign
---
# Finviz: stock screener overview table

Why: a very dense dark table that traders read all day.

## Assessment

- Evidence: A. Long-running, popular screener.
- Reasoning: weak (no text about the design).
- Interests: sells Elite.
- Weigh: findings from screenshot finviz-screener.png
  (`data/team/2026-10-19-night/design-shots/`); text snapshot holds no table.

## Findings

- [ux/density] Rows are about 20 px with 13 px text, no row stripes, thin column rules;
  about 20 rows and 11 columns in 400 px. Numbers right-aligned in their columns, text
  left-aligned. (seen in screenshot finviz-screener.png) ^f1
- [ux/colour] Only signed columns are coloured: Change % green when up, red when down;
  Price takes the same colour as the day's change; P/E is green when low. Everything
  else is plain grey-white, so colour stays rare and meaningful.
  (seen in screenshot finviz-screener.png) ^f2
- [ux/layout] View tabs over the same rows (Overview, Valuation, Financial,
  Performance, Technical, Charts, Maps): one set of rows, many column sets, instead of
  one table with 60 columns. (seen in screenshot finviz-screener.png) ^f3
- [ux/layout] Filters are a compact grid of labelled dropdowns above the table, all
  defaulting to Any, with Descriptive, Fundamental, Technical tabs.
  (seen in screenshot finviz-screener.png) ^f4

## Read

- Fold screenshot.

## Not read

- Charts view (small multiples of price charts per row).
