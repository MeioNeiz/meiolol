---
title: 'FiveThirtyEight: How we designed the look of our 2020 forecast (Wiederkehr)'
url: https://web.archive.org/web/20201101000000/https://fivethirtyeight.com/features/how-we-designed-the-look-of-our-2020-forecast/
kind: article
commit:
for: [showing-ranges]
looked: 2026-11-04
depth: listed (whole article, Wayback copy; images not seen)
relevance: high
grade: B/fair
description: 538's lead visual journalist on the 2020 forecast design: why readers misread 2016, a grid of simulated maps before any number, the ball swarm of 100 outcomes, cards
---
# FiveThirtyEight: How we designed the look of our 2020 forecast

Why: the design reasoning behind the best-known lay display of a forecast's spread
(the "ball swarm"), written by its designer.

## Assessment

- Evidence: B. First-hand report from the designer of a widely read forecast; no user
  testing reported.
- Reasoning: fair. States goals and what they tried; does not report whether readers
  understood it better.
- Interests: 538 promoting its own product.
- Weigh: trust the design intent; effect on understanding is not measured here.

## Findings

- [ux/trust] The lesson drawn from 2016: readers who saw only the headline number
  thought the model failed; readers of the context did not. ^f1
  > People who were looking only at our top-line forecast numbers, on the other hand, thought we bungled it.
- [ux/uncertainty] The design goal was to show what is not known and what may change,
  not only the estimate. ^f2
  > How do you present a forecast that communicates what we know but also what we don’t know and what might change?
- [ux/uncertainty] Before any number, the page shows a grid of simulated maps, each one
  possible outcome. ^f3
  > First — before we get to any numbers — we give the reader the headline and a sense of the range of possible electoral outcomes in the form of a grid of maps
- [ux/charts] The ball swarm: 100 representative outcomes as dots on a margin axis, each
  hoverable to see its scenario (a quantile dot plot in effect). ^f4
  > the ball swarm shows readers 100 representative electoral outcomes from our model
- [ux/uncertainty] The analogy offered to lay readers is weather, not a coin flip. ^f5
  > Forecasting an election is more like predicting the weather than predicting whether a coin will land on heads or tails
- [ux/layout] Content is split into stand-alone cards, each a different lens, easier to
  fit to phones. ^f6
  > The final version is modular and [the pieces of the forecast are visualized on cards]
- [ux/features] They audited every 2016 chart for what it aimed to do and how well it
  worked before choosing which to keep. ^f7
  > We surveyed past forecasts and documented what every chart aimed to accomplish and how successful we felt it was.
- [ux/uncertainty] Checked, not there: no reader testing or measured comprehension is
  reported for the ball swarm. ^f8
- [ux/uncertainty] (inferred) meio.lol's per-number range is a much smaller object than
  an election; the reusable idea is to show outcomes as countable things on the method
  page (e.g. "10 champions at 52%: about 8 land inside their range"), not a swarm per
  cell. ^f9

## Read

- Whole article text.

## Not read

- The images (sketches, early versions); the design-questions page on netlify.
