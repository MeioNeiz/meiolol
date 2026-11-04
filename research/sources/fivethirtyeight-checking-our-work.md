---
title: 'FiveThirtyEight: How good are FiveThirtyEight forecasts? (Checking our work)'
url: https://web.archive.org/web/20220105161212/https://projects.fivethirtyeight.com/checking-our-work/
kind: docs
commit:
for: [showing-ranges]
looked: 2026-11-04
depth: listed (page text, Jan 2022 Wayback copy; charts not seen)
relevance: high
grade: A/strong
description: 538's public track-record page: calibration plots with binned predictions against outcomes, Brier skill scores against an unskilled baseline, per forecast since 2008, downloadable data
---
# FiveThirtyEight: Checking our work

Why: the closest public analogue to meio.lol's truth page (E9): a forecaster grading
its own probabilities for lay readers, and how it explains the grading.

## Assessment

- Evidence: A. Covers every major 538 forecast since 2008; data public on GitHub.
- Reasoning: strong. Defines both measures in plain words, gives a worked example,
  explains why one forecast scores lower, lists exclusions and weighting.
- Interests: grading itself; the conclusion is favourable, but data is downloadable.
- Weigh: trust the format; the verdicts are theirs.

## Findings

- [ux/trust] Two measures, explained in a sentence each: calibration (things said 30%
  happen about 30%) and skill against an unskilled baseline from historical averages. ^f1
  > we’re looking at two main things: the calibration of a forecast — that is, whether events that we said would happen 30 percent of the time actually happened about 30 percent of the time — and how our forecast compared with an unskilled estimate that relies solely on historical averages
- [ux/charts] Calibration plot: predictions grouped into bins (37.5 to 42.5% is the "40
  percent" bin), each bin's mean forecast against its actual rate, judged by distance
  from the 45-degree line. ^f2
  > we’ll throw every prediction that gave a team between a 37.5 percent and 42.5 percent chance of winning into the same “40 percent” group
- [ux/trust] Teaches with a worked example first (MLB games), before the full list of
  forecasts. ^f3
  > To show you how they work, we’ll use our MLB game predictions, which span the last five seasons.
- [ux/trust] Admits a weakness alongside calibration: well calibrated but rarely
  confident, which the skill score then captures. ^f4
  > But it also shows that we rarely went out on a limb and gave any team a high chance of winning.
- [ux/uncertainty] Explains why a low skill score can be the sport, not the model: MLB
  is near a coin flip. ^f5
  > That’s primarily because there’s a lot of uncertainty in baseball, so finding an edge over the unskilled estimate — which is essentially a coin flip in this case — is difficult.
- [ux/trust] The page says single predictions cannot be judged alone; only groups can. ^f6
  > Indeed, single predictions are hard to judge on their own.
- [ux/trust] The baseline is not naive 50-50 where a known effect exists: it includes
  home advantage. ^f7
  > The unskilled estimates for sports games incorporate home-field advantage by using each sport's historical home team winning percentage in its forecasts
- [stats] Daily-updated forecasts are weighted by one over the number of updates, so
  each event counts once; confidence intervals use the same weights. ^f8
  > we weighted each update by the inverse of the number of updates issued
- [ux/trust] Rules stated: only forecasts published before the event; certain 0 and
  100% forecasts dropped; only the default model each year; data downloadable. ^f9
  > All probabilities were published by FiveThirtyEight before the corresponding events occurred.
  > [Download this data](https://github.com/fivethirtyeight/checking-our-work-data).
- [ux/trust] Framed as accountability: a single place readers return to as forecasts
  are added. ^f10
  > we’ve created a single place where we hope you’ll come back as we add future forecasts and help keep us honest
- [ux/trust] (inferred) meio.lol's truth page maps closely: the 80% range coverage per
  kind is the calibration plot (coverage against 80%, by width or games bin), and the
  raw 30 days / raw patch comparison is the skill score against an unskilled baseline;
  name the baseline as plainly as 538 does ("the patch's raw win rate so far"). ^f11
- [ux/trust] (inferred) Copy the rules list: estimates frozen before the games they are
  scored on, each cell counted once however often it was rebuilt, data downloadable. ^f12
- [ux/uncertainty] (inferred) Copy the "calibrated but timid" admission: report range
  width (sharpness) beside coverage, so a too-wide 80% range that always holds does not
  read as a win. ^f13

## Read

- Landing page text (explainer, notes).

## Not read

- Per-forecast pages (presidential, sports); the charts themselves (images).
- github.com/fivethirtyeight/checking-our-work-data.
