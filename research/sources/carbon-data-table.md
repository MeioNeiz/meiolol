---
title: 'IBM Carbon: data table usage'
url: https://carbondesignsystem.com/components/data-table/usage/
kind: docs
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: docs (usage page, searched for mobile, sorting, column guidance)
relevance: low
grade: A/fair
description: Carbon design system data table guidance: header-click sort, 1-2 word column titles, expandable rows; says almost nothing about small screens
---
# IBM Carbon: data table usage

Why: what does a major design system say about dense tables on small screens?

## Assessment

- Evidence: A for the system (IBM, years, many products); but this page is
  desktop-first and carries little for phones.
- Reasoning: fair. Rules are stated with some rationale.
- Interests: own system.
- Weigh: the gap is the finding: use only for sort and header conventions.

## Findings

- [ux/controls] Sort lives in the column header with an arrow icon; unsorted icons
  show only on hover. (inferred) On touch there is no hover, so the sortable columns
  are not signalled until sorted. ^f1
  > Only the sorted column displays an icon, and unsorted icons are only visible on hover.
- [ux/density] Column titles of one or two words; longer wrap to two lines and
  truncate, with the full text in a hover tooltip. ^f2
  > Column titles should stick to one or two words that describe the data in that column.
- [ux/density] Expandable rows are the one dense-data device it offers for small
  space: a row panel reveals more. ^f3
  > The expandable variant helps present large amounts of data in a small space.
- [ux/density] Tables belong in roomy containers, not cramped ones. ^f4
  > Avoid placing data tables inside data tables or smaller containers where the information can feel cramped or needs truncation.
- [ux/density] Checked, not there: any guidance on phone widths, sticky columns,
  horizontal scroll cues, card layouts, column priority or a column picker. ^f5

## Read

- Usage page, searched by keyword for mobile, small, scroll, sticky, sort, column.

## Not read

- Style and code tabs, Carbon's responsive grid docs.
