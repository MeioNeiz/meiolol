---
title: 'Blizzard: Overwatch Hero Statistics page (official win and pick rates)'
url: https://overwatch.blizzard.com/en-us/rates
kind: docs
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (whole page: FAQ text; table not read)
relevance: medium
grade: A/weak
description: Blizzard's own hero win and pick rate page for Overwatch, with a short FAQ stating its patch rule: numbers reset at each patch, up to a day of lag, dashes where data is thin
---
# Blizzard: Overwatch Hero Statistics page (official win and pick rates)

Why: what does a publisher's own stat page do in a new patch's first days?

## Assessment

- Evidence: A for what the page does (the publisher describing its own live page, full
  data, every player). No numbers on thresholds.
- Reasoning: weak. States the rule, not why or what the floor is.
- Interests: Blizzard; a public-relations page as much as a tool.
- Weigh: the rule is stated plainly and is the page's behaviour; the size of "not enough
  data" is unknown.

## Findings

- [tools] [method/dynamics] The stated patch rule is a hard reset: every number is from
  the newest patch's games only, and the page can lag a new patch by up to a day. ^f1
  > All stats are pulled from the start of the most recent patch. When a new update drops, it can take up to a day for the site to catch up.
- [ux/uncertainty] [method/dynamics] Thin cells are blanked, not estimated: a dash where
  there is not enough data, a fresh patch named as one cause. ^f2
  > Those dashes pop up when there isn’t enough data yet. That can happen with rarely picked Heroes, mirrored matchups, or when a patch is still fresh.
- [tools] Pick rate is a share of play time, not of games. ^f3
  > Pick Rate shows how often a Hero is played based on total playtime, compared to all Heroes combined.
- [method/dynamics] Checked, not there: no previous-patch numbers, no blend or carry-over
  from older patches, no stated minimum sample, no interval, no change since last patch. ^f4

## Read

- The page's intro and FAQ text.

## Not read

- The hero table (values load per filter).
