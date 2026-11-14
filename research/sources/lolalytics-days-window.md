---
title: 'LoLalytics: Mel build page on the 30-day window (patch=30), Nov 2026'
url: https://lolalytics.com/lol/mel/build/?patch=30&tier=all
kind: project
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: skimmed (page text for the window and patch controls)
relevance: medium
grade: A/weak
description: LoLalytics champion page with its patch control set to a 30-day window instead of a patch: what the site offers beside the per-patch bucket, read off the live page
---
# LoLalytics: Mel build page on the 30-day window (patch=30), Nov 2026

Why: does LoLalytics offer anything but a per-patch bucket in a patch's first days?

## Assessment

- Evidence: A for what the page offers (the largest LoL stat site by sample, live page
  read 14 Nov 2026). No method text on the page.
- Reasoning: weak. Controls only, nothing explained.
- Interests: ads.
- Weigh: the options exist; which one a visitor lands on at patch day was not observed
  (16.22 was 10 days old when read).

## Findings

- [tools] [method/dynamics] The patch control takes a day window in place of a patch:
  `patch=30` gives a header reading 30 Days and a sample of 224.8M champion picks across
  ranks, against 19.6M on the 16.22 tier list (Emerald+) the same day. ^f1
  > All Ranks Champions Analysed: 224,787,750
- [tools] [method/dynamics] In a day window the patch is treated as one more bucket: the
  page's own summary calls the window "Patch 30", and nothing weights newer games or
  flags that a balance patch falls inside the window. ^f2
  > Mel middle has a 46.79% win rate in All Ranks on Patch 30
- [tools] The page also lists a Max Days control with Today, 7 Days and 14 Days
  (labels read off the page; which chart it drives not checked). ^f3
- [method/dynamics] Checked, not there: no blend of the new patch with older games, no
  shrinkage, no previous-patch number as a reference on this page (the home page has the
  patch-to-patch change, [[lolalytics-home-patch-ui#^f4]]). The choice between "new
  patch only" and "last N days, unweighted" is left to the reader. ^f4
- [method/dynamics] (inferred) So the largest site's day-0 offer is our two raw modes:
  the patch bucket (available within the hour, [[reddit-day1-patch-data-2021#^f1]]) or a
  day window. Meio's blend has no counterpart there. ^f5

## Read

- Page text: header controls, summary sentence, control labels.

## Not read

- The patch dropdown's full option list (needs a click), the win rate by day chart.
