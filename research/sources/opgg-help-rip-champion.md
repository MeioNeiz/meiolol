---
title: 'OP.GG Help: What is an RIP champion?'
url: https://help.op.gg/hc/en-us/articles/31089402615705-What-is-an-RIP-champion
kind: docs
commit:
for: [champselect-advice-methods]
looked: 2026-11-06
depth: docs (whole article)
relevance: high
grade: B/fair
description: OP.GG's only stated sample rule: champion positions under 0.5% pick rate get no analysis; a champion under it in every role is an RIP champion with a greyscale portrait, back once samples suffice
---
# OP.GG Help: What is an RIP champion?

Why: does any big tool state a sample floor and say how thin data is shown?

## Assessment

- Evidence: B. OP.GG's help centre (updated about a year before Nov 2026).
- Reasoning: fair. States the rule and why (reliability), how it shows and when it lifts.
- Interests: vendor.
- Weigh: a pick-rate floor, not a game count, so the floor in games varies with the
  filter's total volume (a narrow region or rank gives far fewer games at 0.5%).

## Findings

- [stats] [ux/uncertainty] Data is shown only for champion positions with at least 0.5% pick rate, for reliability. ^f1
  > OP.GG only provides information for champion positions with a pick rate of at least 0.5% to ensure data reliability.
- [ux/uncertainty] A champion under 0.5% in every position is an RIP champion: no champion analysis at all. ^f2
  > If a champion's pick rate is below 0.5% in all positions, that champion is considered an RIP champion and champion analysis will not be available.
- [ux/uncertainty] Thin data is shown as a greyscale portrait, re-enabled once enough games arrive. ^f3
  > RIP champions are displayed with a grayscale portrait and will be reactivated once sufficient data samples are collected.
- [ux/controls] [ux/uncertainty] A broader filter (Global) brings back data for nearly all RIP champions. ^f4
  > If the champion analysis stats filter is set to a broader region such as Global, analysis data for nearly all champions—including those usually marked as RIP—will be available.
- [stats] (inferred) The floor is relative: 0.5% of a narrow slice (one region, Master+, early patch) can be a few hundred games or fewer, so the same rule hides little where data is thinnest. ^f5
- [ux/uncertainty] Checked, not there: no rule for matchups, duos or builds, nor any range. ^f6

## Read

- Whole article.
