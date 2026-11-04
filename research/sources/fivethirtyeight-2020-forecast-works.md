---
title: 'FiveThirtyEight: How our 2020 presidential forecast works (Silver, Aug 2020)'
url: https://web.archive.org/web/20201101000000/https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/
kind: article
commit:
for: [showing-ranges]
looked: 2026-11-04
depth: listed (whole article, Wayback copy; the live URL now redirects to ABC News)
relevance: high
grade: A/strong
description: Nate Silver's methodology article for the 2020 forecast: what changed, three steps, four named sources of uncertainty, 40,000 simulations, scope disclaimer, calibration claim
---
# FiveThirtyEight: How our 2020 presidential forecast works

Why: the best-known lay-reader method page for a model with uncertainty; how it is
structured and how it explains where the spread comes from.

## Assessment

- Evidence: A. Forecasts published since 2008, widely read; the canonical example of a
  public model method page.
- Reasoning: strong. Explains each choice and its costs, states scope limits, names
  what the model does not cover.
- Interests: a media brand defending its 2016 record (the opening says so).
- Weigh: trust the structure as a pattern; the calibration claim is theirs, backed by
  a separate page not read here.

## Findings

- [ux/trust] The method page opens with track record: the model is claimed to be well
  calibrated, explained as a plain frequency. ^f1
  > Candidates who our models claim have a 30 percent chance of winning really do win their races about 30 percent of the time
- [ux/trust] It opens with a "what's different" list before the full walk-through, so
  returning readers see changes first. ^f2
  > In the end, our model still isn’t _that_ different from 2016’s, but let’s run through the list of changes.
- [ux/uncertainty] Uncertainty is broken into four named sources, each defined in one
  plain sentence (national drift, Election Day error, correlated state error,
  state-specific error). ^f3
  > here are the four types of uncertainty that the model tries to account for
  > **State-specific error**, an error relative to our forecast that affects only one state.
- [ux/uncertainty] Thin data widens the range rather than hiding the row: unpolled
  states get more error, explained with a named example. ^f4
  > This tends to be relatively small, and is primarily a function of the volume of polling in each state, especially in states that have had no polling at all.
  > If you’re wondering why Trump’s chances are higher than you might expect in Oregon, for example, it’s partly because there have been no polls there as of forecast launch.
- [ux/trust] A scope disclaimer says what the model does not cover. ^f5
  > It does _not_ account for the possibility of extraconstitutional shenanigans by Trump or by anyone else
- [stats] Few past cases: they pool a long history and use fat tails rather than trust
  recent precise years. ^f6
  > Given the small sample sizes, we also use a [fat-tailed distribution](https://en.wikipedia.org/wiki/Fat-tailed_distribution) for many of the error co
- [ux/uncertainty] The spread is a formula readers can see: drift scales with the cube
  root of days left times an uncertainty index. ^f7
  > _Constant x (Days Until Election)^⅓ x Uncertainty Index_
- [ux/trust] Ends with a plain invitation to report errors. ^f8
  > Got any other questions or see anything that looks wrong? Please [drop us a line]
- [ux/features] One forecast version only; the polling average is shown as a separate
  "snapshot", distinct from the projected outcome. ^f9
  > Our [polling averages](https://projects.fivethirtyeight.com/polls/president-general/national/) are the best way to reflect the current snapshot of the race, but the snapshot is not the same as the projected Election Day outcome.
- [ux/uncertainty] (inferred) For meio.lol: the method page should name the sources of
  spread per number in one line each (game-to-game luck in the sample, patch drift
  since the data, thin cell pulled to its parent) and say plainly why a thin cell's
  range is wide, with one named example (an off-role pick). ^f10
- [ux/trust] (inferred) Copy the order: track record first (our truth score: how often
  the 80% range held), then what changed, then how it works, then what it does not
  cover, then a contact line. ^f11
- [ux/features] (inferred) 538's snapshot vs forecast split maps to meio.lol's raw
  (30 days, patch) vs model numbers: show both, named differently, so readers see the
  raw count is not the estimate. ^f12

## Read

- Whole article (Wayback 1 Nov 2020 copy).

## Not read

- projects.fivethirtyeight.com/checking-our-work (calibration plots): separate note.
- 2016 user's guide.
