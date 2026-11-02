---
title: 'Sports Reference blog: Row Isolation'
url: https://www.sports-reference.com/blog/2019/10/row-isolation-added-to-sports-reference-sites/
kind: article
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Sports Reference (Basketball, Baseball, FBref) lets readers select rows and hide the rest, on desktop and mobile, to compare rows in long stat tables
---
# Sports Reference blog: Row Isolation

Why: how does a mature stats site help comparing rows when a phone shows a few at a time?

## Assessment

- Evidence: B. The most-used stats reference sites; post is a short feature note.
- Reasoning: weak. Announces, does not justify.
- Interests: own product.
- Weigh: it tells us what the site does, not how the phone table itself is laid out; I
  could not get a 390 px screenshot (`browse` has no viewport option).

## Findings

- [ux/density] [ux/controls] Select rows, then "Show Only Selected Rows" fades out
  the rest so the chosen rows can be compared; "Show All Rows" returns. Works on
  mobile too, for tables without row summing. ^f1
  > Now, when you select a row on a table, a popup will appear with a button: "Show Only Selected Rows".
  > This will work on both desktop and mobile.
- [ux/density] (inferred) A mature stats site answers "compare row 5 with row 90" by
  shrinking the table to chosen rows, not by a card layout. ^f2
- [ux/density] Checked, not there: how the table scrolls or what sticks at phone width,
  how sort is changed on a phone. ^f3

## Read

- Whole post.

## Not read

- Live basketball-reference or FBref pages at phone width.
