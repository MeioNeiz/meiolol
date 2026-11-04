---
title: 'The Economist: How The Economist presidential forecast works (2020, with Gelman and Heidemanns)'
url: https://web.archive.org/web/20201101033556/https://projects.economist.com/us-2020-forecast/president/how-this-works
kind: article
commit:
for: [showing-ranges]
looked: 2026-11-04
depth: listed (whole method page, Wayback 1 Nov 2020 copy; forecast page charts not seen)
relevance: high
grade: A/strong
description: The Economist's 2020 model method page for lay readers: fundamentals prior, poll adjustment, Bayesian update in 20,000 simulations; frames the range as the product, a changelog that widened uncertainty, open source code
---
# The Economist: How the presidential forecast works (2020)

Why: a second method page, from a Bayesian model built with Gelman, to compare with
538 on how a shrink-to-prior model's ranges are explained to lay readers.

## Assessment

- Evidence: A. Major publication, model with Columbia statisticians, code public
  (github.com/TheEconomist/us-potus-model).
- Reasoning: strong. Explains each step, the techniques by name and plain meaning,
  worked numbers, and a dated fix that admitted too little uncertainty.
- Interests: publisher; first-ever forecast, so no track record to show.
- Weigh: trust the explanation pattern; its 2020 ranges were criticised as too narrow
  (see the dated fix, and Gelman's own later posts, not read).

## Findings

- [ux/uncertainty] Frames the point estimate as certain to be wrong and the range as
  what the model is for. ^f1
  > Technically, the output of this model is guaranteed to be wrong.
  > What the model is actually producing of value is the estimate of uncertainty around that prediction.
- [ux/uncertainty] Explains a range in nested plain words with numbers: a decent chance
  in a narrow band, a very good chance in a wider one, virtually no chance outside. ^f2
  > there is probably a decent chance that he ends up between 51% and 52%, a very good chance he finishes between 49% and 54%, and virtually no chance that he secures less than 46% or more than 57%.
- [ux/uncertainty] Shows that range width changes the verdict: a 52% estimate loses 30%
  of the time with a wide range, 0.4% with a narrow one. ^f3
  > Because of all of this uncertainty, such a candidate would have a fairly high 30% probability of losing the popular vote.
  > and a probability of losing the popular vote of just 0.4%.
- [ux/uncertainty] Gives two real past cases at the extremes of width (1960 wide, 2004
  narrow) with the outcome. ^f4
  > there was so much uncertainty that the 95% confidence interval for the Republican Party’s vote share stretched from 42.7% to 64.7%
  > (Mr Bush wound up getting 51.1%, virtually identical to our central estimate of 51.2%.)
- [stats] The range width is itself modelled and tested on held-out elections, not
  assumed. ^f5
  > we fit another model using elastic-net regularisation and leave-one-out cross-validation to explicitly predict the expected range of error for any given prediction
- [ux/uncertainty] Thin data leans on the prior, said in one sentence a lay reader can
  follow. ^f6
  > it will emphasise the prior more early in the race or in thinly-polled states
- [ux/uncertainty] Says the stated sampling margin of error understates the real
  error, and names the missing part (non-sampling error). ^f7
  > However, this number only contemplates one potential source of error
- [ux/trust] Machine-learning terms are named and then glossed, with a joke about how
  they sound. ^f8
  > we borrow two techniques from the world of machine learning, with appropriately inscrutable names
- [ux/trust] A dated changelog admits bugs that gave too little uncertainty and says
  how much the headline moved. ^f9
  > We fixed a series of medium-sized bugs in the model that collectively caused too little uncertainty in our forecast.
  > In sum, these changes caused Joe Biden’s chances of winning the popular vote and electoral college to each decrease by roughly two percentage points.
- [ux/trust] Defines success as surprises happening about as often as stated. ^f10
  > But as long as such “black-swan” events happen roughly as much as we expect them to—neither too often nor too infrequently—our model will be doing its job.
- [ux/trust] Publishes the source code and invites readers to run it. ^f11
  > In another first, we are [publishing the source code]
- [ux/features] The method page is one tab beside the forecast ("National forecast",
  "How this works"), always one click away. ^f12
  > [National forecast](https://projects.economist.com/us-2020-forecast/president)
- [ux/uncertainty] (inferred) The nested-band sentence is the model for meio.lol's
  range tooltip: "Darius vs Garen: about 52%; 8 in 10 chance the true rate is between
  50 and 54" with the games count, rather than a bare "80% CI". ^f13
- [ux/trust] (inferred) meio.lol's method page should keep a dated changelog of range
  changes ("ranges widened on 4 Nov: coverage was 71%, now 80%"), as this page did. ^f14
- [ux/uncertainty] (inferred) Its "thinly polled states lean on the prior" maps to
  meio.lol's thin cells pulled to the parent (role, champion): say on the method page
  what each kind is pulled toward. ^f15

## Read

- Whole method page, including the 5 Aug 2020 update.

## Not read

- The forecast page charts; the GitHub model code; Gelman's later blog posts on the
  model's tails.
