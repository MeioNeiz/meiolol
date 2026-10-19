---
title: 'Finviz: S&P 500 market map (heat map)'
url: https://finviz.com/map.ashx
kind: dataset
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (fold screenshot; text snapshot is only site chrome)
relevance: high
grade: A/fair
description: Finviz treemap heat map of S&P 500 stocks, size by market cap, colour by daily change on a 7-step red-black-green scale, dark theme
---
# Finviz: S&P 500 market map (heat map)

Why: the best-known heat map of hundreds of numbers on a dark background.

## Assessment

- Evidence: A. Finviz maps are widely used and copied by trading sites.
- Reasoning: fair. One legend sentence, no method.
- Interests: sells Elite subscriptions.
- Weigh: text snapshot is navigation and promo only (the map is a canvas); findings
  are from screenshot finviz-map.png (`data/team/2026-10-19-night/design-shots/`).

## Findings

- [ux/colour] Diverging scale with a dark (near-black grey) neutral centre, so
  unchanged stocks melt into the dark background and only movers stand out: red
  losers, green gainers, brighter the further from zero. (seen in screenshot
  finviz-map.png) ^f1
- [ux/colour] The legend is 7 discrete steps, -3% to +3% in 1% steps, shown as a strip
  of labelled swatches under the map; the colour saturates at plus or minus 3%, so a
  +5% stock looks like +3%. Clamping keeps the middle steps far apart.
  (seen in screenshot finviz-map.png) ^f2
- [ux/colour] Red against green with similar lightness at the poles: not safe for
  red-green colour-blind readers (cf. [[crameri-misuse-colour-2020#^f2]]); the sign is
  repeated in the label (+1.38%), which rescues it. (seen in screenshot finviz-map.png) ^f3
- [ux/density] Size is a second variable (market cap): tile area, with the ticker and
  the change printed inside and the font scaling with the tile; tiles too small get
  ticker only, then nothing. (seen in screenshot finviz-map.png) ^f4
- [ux/layout] Grouped by sector then industry, each group with a caps label: the
  map is a small-multiples grid of related tiles. Side controls switch Map, Bubbles,
  Matrix, size by Market or Equal. (seen in screenshot finviz-map.png) ^f5

## Read

- Fold screenshot.

## Not read

- Hover tooltips (per-stock sparkline popups), other map filters.
