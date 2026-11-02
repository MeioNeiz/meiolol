---
title: 'NN/g: Mobile Tables: Comparisons and Other Data Tables'
url: https://www.nngroup.com/articles/mobile-tables/
kind: article
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: docs (whole article)
relevance: high
grade: B/fair
description: Amy Schade, NN/g, 2017: sticky headers and left column, a visible scroll cue, user-chosen columns, accordions, for number-heavy tables on phones
---
# NN/g: Mobile Tables: Comparisons and Other Data Tables

Why: how do good sites show a dense numeric table (10+ columns, 50-170 rows) at 390 px?

## Assessment

- Evidence: B. NN/g is a recognised usability research group; the article is
  screenshot-led review of live sites (NRL, Fidelity, Dell, Samsung), not a
  measured study. 2017: before sticky CSS was universal, patterns still stand.
- Reasoning: fair. Says why for each rule (lost context, missed cues) but gives no
  numbers on speed or errors.
- Interests: none (sells training).
- Weigh: trust the cue and sticky guidance; the "select data" advice is for product
  comparison tables, not 170-row sortable rankings. Silent on sorting on phones.

## Findings

- [ux/density] [ux/layout] Number-heavy tables fit more columns: NRL player stats
  showed 11 columns without scrolling, using logos and abbreviated headings, at the
  cost of jargon only fans decode. ^f1
  > For a number-heavy table, narrower columns may work, allowing more columns to be visible.
  > The National Rugby League’s player statistics were numeric and allowed 11 columns to be displayed on the screen without horizontal scrolling.
- [ux/density] Rotating the phone is a last resort: gains columns, loses rows,
  dictates how the user holds the phone. ^f2
  > what you gain in column space, you lose in row space.
- [ux/density] [ux/layout] Sticky column headers for any table taller than one
  screen: without them users lose what the table shows. ^f3
  > For any table that fills more than a single vertical screen, sticky column headers help users know what they are looking at.
- [ux/density] [ux/controls] Horizontal scroll is acceptable for large tables on
  mobile only if it is apparent: cut-off elements or arrows work best, dots are
  overlooked. Arrows belong inside the data, not above. ^f4
  > for such scrolling to work, it must be apparent that there is more data beyond the horizontal fold.
  > Dots are sometimes used, but are typically harder for users to notice and understand than arrows or cut-off elements.
- [ux/density] [ux/layout] Lock the leftmost (row header) column when scrolling
  sideways; Fidelity also cut the last column off slightly as a cue. ^f5
  > the leftmost column, which is typically a column of row headers, should be locked in place, so users can see the necessary labels at all times.
- [ux/controls] [ux/density] Letting users pick which attributes show suits
  tasks that need only some columns; choosing the item first (one smoothie, one
  size toggle) does not support comparison because users must remember numbers. ^f6
  > The second solution is to provide users control over the specific details they see.
  > engaging in lots of mental work that people are notoriously bad at.
- [ux/density] [ux/controls] Accordions group related attributes and double as an
  overview of what the table holds (Samsung). ^f7
  > The accordions also acted as an overview of content, letting users know what information was available about products.
- [ux/density] Fix the content before the layout: a usable large-screen table first;
  mobile is a reason to reconsider which attributes are there. ^f8
  > You must first create a usable table for a large screen before translating it to a small one.
- [ux/density] Checked, not there: how to sort on a phone, any measured effect of
  sticky columns or cues, accessibility of any pattern, tables with 50+ rows. ^f9

## Read

- Whole article.

## Not read

- NN/g video "How to Fit Big Tables on Small Screens" (4 min): might add current advice.
