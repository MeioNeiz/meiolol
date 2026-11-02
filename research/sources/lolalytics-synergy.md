---
title: Lolalytics synergy tab (Ahri build page)
url: https://lolalytics.com/lol/ahri/build/?tab=synergy
kind: project
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: skimmed (tab labels and definitions in the rendered page; rows not rendered)
relevance: medium
grade: B/fair
description: Lolalytics' per-champion synergy list: tab names and the exact definitions of its two synergy deltas
---
# Lolalytics synergy tab (Ahri build page)

Why: Lolalytics has no duo tier list; its pair view lives in a champion page's Synergy tab. Read for the definitions and the tab layout.

## Assessment

- Evidence: B. Large site; definitions are the site's own text, shown in tooltips.
- Reasoning: strong on definitions (a formula and a plain sentence each), but the rows did not render in the scripted page, so row layout is not read.
- Interests: ads and subscription.
- Weigh: trust the definitions; row layout (columns, sort) only by analogy with the Counters table beside it, which is read in [[lolalytics-darius-build]].

## Findings

- [ux/features] A champion's Synergy view has its own tab group, parallel to Counters: Common Teammates, Good Synergy, Bad Synergy, Synergy Delta, Normalised Synergy Delta. So a reader switches the sort or filter by tab: most played, best, worst, biggest delta, biggest normalised delta. ^f1
  > Synergy|Common|Common Teammates|Good|Good Synergy|Bad|Bad Synergy|Delta|Synergy Delta|Normalised Delta|Normalised Synergy Delta
- [ux/features] The gain from a pair is defined as the pair's win rate minus the mean of the two solo rates, with a plain sentence beside it. ^f2
  > Synergy Delta = Actual Win Rate Together - (Current Champions Win Rate + Paired Champions Win Rate) / 2. The more positive the value the better the pairing performs than their win rates alone would suggest.
- [ux/features] A second, "normalised" delta compares the pair with an expected pair rate from normalised solo rates, so two strong champions do not look like a synergy just for being strong. ^f3
  > Normalised Synergy Delta = Actual Win Rate Together - Expected Normalised Champions Win Rate Together.
- [ux/density] (inferred) The same two-delta design as its Counters table (Delta 1, Delta 2 with "?" tooltips), so the pair table is the counter table with the partner as the other column: icon, win rate together, delta, normalised delta, pick rate, games. ^f4
- [ux/features] Checked, not there: no duo tier list page and no page for a single pair on the site as read; the pair exists only as a row inside one champion's page. ^f5

## Read

- `raw/lolalytics-synergy.md`: tab labels and definitions extracted from the rendered DOM (the text snapshot of the page drops icons, so champion names were missing).

## Not read

- The synergy rows themselves (they load on tab click).
