---
title: 'NN/g: Data Tables: Four Major User Tasks (Laubheimer, 2022)'
url: https://www.nngroup.com/articles/data-tables/
kind: article
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (whole article)
relevance: medium
grade: B/fair
description: Nielsen Norman Group guidance on big data tables: tables beat cards for comparison, four core tasks, frozen headers, importance-ordered columns, zebra striping, hidden-column state
---
# NN/g: Data Tables: Four Major User Tasks (Laubheimer, 2022)

Why: what NN/g says about dense data tables (vs cards) for density without overload.

## Assessment

- Evidence: B. NN/g usability research firm; cites its own eyetracking and testing but
  gives no numbers here.
- Reasoning: fair. Explains why (working memory, eye movement) and trade-offs per
  editing pattern.
- Interests: NN/g sells training; article itself neutral.
- Weigh: workplace tables, not stat sites, but the comparison argument carries over.

## Findings

- [ux/density] Tables beat cards for comparing: adjacent values need no eye travel or
  working memory; cards make readers reorient each time. Tables vs. Cards ^f1
  > A card-based presentation of multivariate data requires users to spatially reorient each time they move their eyes from one card to another, making comparison tasks cognitively effortful and slow.
- [ux/density] Tables are the space-efficient form for comparing records and spotting
  patterns. Summary ^f2
  > Compared to modular presentations such as card-based displays, tables are space efficient and well suited for comparing records and for detecting patterns in the data.
- [ux/layout] First column a human-readable identifier; default column order by
  importance, related columns adjacent. Find records ^f3
  > The default order of the columns should reflect the importance of the data
- [ux/density] Keeping place in a big table: frozen headers, light borders, zebra
  striping, hover highlight of the row. Locating Relevant Info ^f4
  > Borders, zebra striping, and hover-triggered highlighting of a record can all help.
- [ux/layout] Active filters must be visibly signalled. Find records ^f5
  > there should be a clear visual indication that filters are active
- [ux/layout] Crowded inline row actions without text labels are hard to hit and tell
  apart; hiding them behind hover or an Actions menu hurts discovery. Single-Record
  Actions ^f6
  > Crowded, with no text labels, and thus be hard to click and also hard to distinguish
- [ux/layout] Accordions leave clutter: users rarely close them. Single row ^f7
  > users don’t tend to clean up after themselves (i.e., close accordions when they are done with them)

## Read

- Whole article

## Not read

- NN/g "Mobile tables" (big tables on small screens): worth it for the phone layout
