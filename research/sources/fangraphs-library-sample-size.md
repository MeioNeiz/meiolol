---
title: 'FanGraphs Library: Sample Size (stabilisation points)'
url: https://library.fangraphs.com/principles/sample-size/
kind: docs
commit:
for: [showing-ranges]
looked: 2026-11-04
depth: listed (whole page)
relevance: high
grade: A/fair
description: FanGraphs' glossary page for lay fans on sample size: stabilisation as a gradual curve, Carleton's 0.7 correlation cut points per stat, practical advice on April hot streaks
---
# FanGraphs Library: Sample Size (stabilisation points)

Why: how the best-known stats site for lay fans explains thin data, and whether it
gives readers a per-stat "how many games before this means much" number.

## Assessment

- Evidence: A. FanGraphs Library is the standard sabermetrics glossary; 2010, updated
  2017; Carleton's cut points are the canonical "stabilisation" numbers.
- Reasoning: fair. Explains the idea plainly and warns against reading it as a switch;
  the cut points are copied from Baseball Prospectus without their method.
- Interests: none known.
- Weigh: trust the framing (gradual, per stat); the cut points are baseball numbers.

## Findings

- [ux/uncertainty] The page frames sample size as how far to trust a number, written
  for lay fans, with a "skip to the numbers" link at the top. ^f1
  > If you’re just looking for the numbers, skip ahead by clicking
- [ux/uncertainty] Stabilisation is explained as gradual, not a threshold: there is no
  point where a stat becomes trustworthy. ^f2
  > there is no one point at which something stabilizes. Things become stable over time, at a given speed.
- [stats] Carleton's definition: the sample size where the stat correlates 0.7 with
  another sample of the same size (R squared .49); the page notes he warned against
  the word. ^f3
  > the correlation between that sample and another sample of the same size is 0.7 (i.e. R^2 of .49)
- [ux/uncertainty] Each stat needs a different sample, so the page gives a separate
  number per stat (strikeout rate 60 PA, walk rate 120, OBP 460, BABIP 820 BIP in the
  lists). ^f4
  > strikeout rate starts to communicate useful information in fewer than 100 PA while BABIP for a pitcher can take three years
- [ux/charts] Later work replaced the single cut point with a reliability curve per
  stat at every 10 PA, showing early games teach most. ^f5
  > they plot the reliability measure for each 10 PA increment to better show the nature of stabilization
  > the first 200 PA are much more important than the second 200 PA for understanding K%
- [ux/uncertainty] The worked example is a hot April: 85 PA at a high rate should move
  belief a little, not change the verdict. ^f6
  > Those 85 PA give you some idea that he might be improving, but they are not sufficient to change your mind completely.
- [ux/trust] The stated aim is to stop readers reacting to noise. ^f7
  > The goal of these “stabilization” or “reliability” numbers is to prevent you from reacting to data that is still highly susceptible to random chance.
- [ux/uncertainty] Checked, not there: no interval or error bar on any number; thin
  data is handled only by teaching the reader the cut points. ^f8
- [ux/uncertainty] (inferred) meio.lol's analogue: a per-kind "games until half signal"
  number (win rate, matchup, item share) computed from our own shrinkage weight
  (prior n where the cell weight reaches 0.5), stated on the method page as a curve, not
  a cut-off. ^f9

## Read

- Whole page, including the cut-point lists and further reading.

## Not read

- "A Long-Needed Update on Reliability" (interactive reliability curves).
- Baseball Prospectus "Reliably Stable (You Keep Using That Word)" (Carleton's own
  caveats).
