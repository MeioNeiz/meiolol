---
title: 'FanGraphs: The 2022 ZiPS projections are coming (Szymborski)'
url: https://blogs.fangraphs.com/the-2022-zips-projections-are-coming
kind: article
commit:
for: [showing-ranges]
looked: 2026-11-04
depth: skimmed (method intro and percentile passages; team tables not read)
relevance: medium
grade: A/fair
description: Dan Szymborski's yearly ZiPS introduction: how the projection system works, why the headline projection is a midpoint, 10th and 90th percentile outcomes, and how readers misread them
---
# FanGraphs: The 2022 ZiPS projections are coming

Why: how a mainstream sports projection system explains its percentile ranges to fans,
and where the ranges show (or don't).

## Assessment

- Evidence: A. ZiPS has run since 2002 and is published on FanGraphs every year; the
  author built it.
- Reasoning: fair. Explains the midpoint and the percentiles plainly with a counting
  example; no calibration numbers given here.
- Interests: author's own system; FanGraphs membership upsell on the page.
- Weigh: trust the explanation and the misreading example.

## Findings

- [ux/uncertainty] The headline projection is called a midpoint, and the 10th and 90th
  percentiles are explained by how often players should fall outside them. ^f1
  > the bottom-line projection is, in layman’s terms, only a midpoint
  > 10% of players are “supposed” to fail to meet their 10th percentile projection and 10% of players are supposed to pass the 90th percentile forecast
- [ux/trust] The author says this confuses readers, and shows the misreading with a
  count: three players projected at .300 does not mean three .300 hitters. ^f2
  > This point can create a surprising amount of confusion.
  > ZiPS thought there would, on average, be 34 hitters with at least 100 plate appearances to eclipse .300, not three. In the end, there were 25
- [ux/uncertainty] Most projection systems hide their percentile ranges, which is
  where differences in uncertainty between players would show. ^f3
  > Most projection systems don’t show you their whole range of percentile outcomes
- [tools/paid] FanGraphs puts Steamer percentile projections behind membership. ^f4
  > We have handedness, percentile, and context neutral projections available for Members only.
- [ux/trust] The system only adds a data source once it is shown to improve accuracy. ^f5
  > I believe in cautious, conservative design, so data is only included once I have confidence in improved accuracy
- [ux/uncertainty] (inferred) meio.lol should explain its 80% range the ZiPS way, by
  counting: "of 100 matchups shown at 52%, about 10 end the patch above the top of
  their range and 10 below", and show the measured counts from the truth test beside
  it. ^f6
- [ux/uncertainty] (inferred) The "top of the list is not the top of reality" point
  applies to tier lists: if 20 champions show above 52%, more than the few with ranges
  wholly above 52% will finish there; the method page can say so. ^f7

## Read

- Introductory method sections and the passages on percentiles and breakouts.

## Not read

- Team projection tables; comments.
