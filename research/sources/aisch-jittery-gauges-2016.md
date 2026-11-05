---
title: 'Gregor Aisch: Why we used jittery gauges in our live election forecast'
url: https://www.vis4.net/blog/2016/11/jittery-gauges-election-forecast/
kind: article
commit:
for: [showing-ranges]
looked: 2026-11-05
depth: docs (whole post and comments, Wayback copy July 2018; live page 404)
relevance: high
grade: B/fair
description: NYT graphics editor's own explanation of the 2016 election needle: jitter bounded by the 25th to 75th percentile, shrinking through the night; reader stress; missing annotation admitted
---
# Gregor Aisch: Why we used jittery gauges (NYT needle, 2016)

Why: the designer's own account of the best-known "needle" for an uncertain headline
number: what the jitter meant, why not a bare percentage, and what went wrong.

## Assessment

- Evidence: B. First-hand report by an NYT graphics editor who built it; the needle
  was seen by millions and reused in later elections ([[reuters-institute-nyt-needle-2024]]).
- Reasoning: fair. Explains why and answers critics; no reader testing.
- Interests: defends his own team's design.
- Weigh: trust the description of what the needle did; the claim that jitter conveyed
  uncertainty better than numbers is opinion, not measured.

## Findings

- [ux/uncertainty] The needle jittered within the 25th to 75th percentile of simulated
  outcomes, so the swing narrowed as the forecast firmed up through the night. ^f1
  > "having the dial fluctuate a small amount – bound by the 25th and 75 percentile of simulated outcomes"
  > "As the night went on, the gauges fluctuated less and less as our forecast became more precise."
- [ux/uncertainty] Besides the motion, the gauge drew the 25-75 range as a pie slice
  with the 5-95 range too: a static band under a moving needle. ^f2
  > "The range was displayed as pie chart slice on the gauge, along with the 5-95th range."
- [ux/uncertainty] [ux/trust] Why not just the win chance: lay readers cannot tell what
  75% or 85% means, and read the median as the one outcome. (claim) ^f3
  > "most people aren’t very good at interpreting a probability scale"
  > "most people would read the median outcome as _the one_ most likely outcome, as opposed to _one of many_ very likely outcomes"
- [ux/trust] The motion caused distress and was called irresponsible; readers took
  random wobble for a trend, and the page had no note saying what the motion meant,
  which Aisch admits they forgot. ^f4
  > "It made people nervous because it implied a TREND where none existed."
  > "I agree on the annotation. That’s something we just forgot to add"
- [ux/uncertainty] (claim) Animation chosen over listing the percentiles, which the
  team judged weaker at conveying the uncertainty. ^f5
  > "was more successful at conveying the uncertainty around our forecast than simply listing what those percentiles were"

## Read

- Whole post and the first comments (to Nov 17, 2016).

## Not read

- Andy Kirk's linked take (visualisingdata.com); the original needle page.
