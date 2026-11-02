---
title: 'Datawrapper Academy: How to create a table'
url: https://www.datawrapper.de/academy/how-to-create-a-table
kind: docs
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: docs (whole page)
relevance: high
grade: B/fair
description: Datawrapper's table tool docs: sticky first column, mobile fallback to one card per row under 450 px, per-column hide on mobile, header-click sort, pagination
---
# Datawrapper Academy: How to create a table

Why: what does a tool built for journalists' dense tables offer on phones?

## Assessment

- Evidence: B. Tool used by many newsrooms, so its defaults are a tested compromise;
  docs state options, not why or any usage data.
- Reasoning: weak. Describes switches, no trade-offs.
- Interests: product docs; every option is presented as good.
- Weigh: the 450 px card fallback and "Show on" are real shipped patterns. Costs
  (comparing rows, accessibility) are not discussed here; see roselli-tables-css-display.

## Findings

- [ux/density] [ux/layout] Mobile fallback turns each row into a card on screens
  narrower than 450 px, so phone readers do not scroll sideways. ^f1
  > Mobile fallback switches your table to a layout where each row becomes a card, on screens narrower than 450px.
- [ux/density] [ux/controls] Columns can be hidden on mobile individually (a
  column priority by hand). ^f2
  > You can also decide to hide some columns on mobile, with Show on in the Customize columns panel
- [ux/density] [ux/layout] Sticky first column is an option, for wide tables
  scrolled sideways, so readers know which row they are on. ^f3
  > Make first column sticky: keeps the first column in place while readers scroll sideways through a wide table, so they always know which row they're looking at.
- [ux/controls] Readers sort by clicking a column header; the author can turn sort
  off per column. ^f4
  > Readers can also sort your table themselves, by clicking on a column header.
- [ux/density] Pagination: 20 rows per page by default; fewer when the table sits in
  the middle of an article. ^f5
  > Rows per page decides how many rows readers see at once (the default is 20 rows).
- [ux/density] Rank column numbers rows and does not move when readers re-sort. ^f6
  > The ranks don't move, even if readers sort the table in a different way.
- [ux/controls] Checked, not there: how sort is operated in the card layout, any
  column picker for readers, scroll cue. ^f7

## Read

- Whole page (via `browse text`; the fetch was a JS shell).

## Not read

- Linked pages on customising sort order and disabling sorting.
