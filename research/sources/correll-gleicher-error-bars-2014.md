---
title: 'Correll and Gleicher 2014: Error Bars Considered Harmful'
url: https://graphics.cs.wisc.edu/Papers/2014/CG14/Preprint.pdf
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-05
depth: listed (abstract, 2-3 design, 4.2-4.4 results, 5 summary and limits)
relevance: high
grade: A/fair
description: IEEE TVCG 2014 (authors' preprint), MTurk lay readers: bar charts with error bars cause within-the-bar bias and all-or-nothing reading; gradient and violin plots of the same mean and error fix both at low cost
---
# Correll and Gleicher 2014: Error Bars Considered Harmful

Why: what does a hard range bar make a lay reader do wrong, and do gradient (faded)
bands help?

## Assessment

- Evidence: A. IEEE TVCG (VIS) paper, three crowd-sourced experiment sets on general
  audiences (368, 96 and 48 participants), much cited; Gleicher a senior vis researcher.
- Reasoning: fair. Clear design goals and hypotheses, ANCOVAs; admits no difference
  found between gradient and violin, practical effect size unclear, low stakes tasks.
- Interests: the authors propose the alternatives.
- Weigh: the bias against bars-with-whiskers is solid; the gains are a few points
  (83% to 89% follow-the-mean). The plots are of a mean with a t interval, which is
  our case (a win rate with a range), framed as polls and weather.

## Findings

- [ux/uncertainty] Bars with error bars carry two biases: values inside the bar look
  likelier (within-the-bar), and the whiskers are read all or nothing. 5 Summary ^f1
  > Within-the-bar bias: the glyph of a bar provides a false metaphor of containment, where values within the bar are seen as likelier than values outside the bar.
  > Binary interpretation: values are within the margins of error, or they are not.
- [ux/uncertainty] The binary reading also makes viewers overstate effect sizes when
  comparing two bars. 5 Summary ^f2
  > makes viewers overestimate effect sizes in comparisons.
- [ux/uncertainty] Within-the-bar bias measured: with bar charts, outcomes below the mean
  (inside the bar) were rated significantly likelier than those above; not so for any
  symmetric encoding (gradient, violin, box). 4.2.1 ^f3
  > participants in the bar chart condition considered red dots below the mean (and so within the visual area of the bar) significantly more likely than those above the bar. This effect was not significant for any of the remaining, symmetric encodings.
- [ux/uncertainty] [ux/charts] Symmetric encodings got more readers to follow the mean
  (violin 89.2%, gradient 88.5%, box 87.4% vs bar 83.2%), and gradient and violin gave
  more confidence. 4.2.1 ^f4
  > (violin: 89.2% of trials, gradient: 88.5%, box: 87.4%) than with bar charts (83.2%).
- [ux/charts] The gradient plot: solid inside the 95% interval, alpha fading outside by
  the t cdf; the fuzzy edge is meant as a "beneficial difficulty" against false
  precision. 3.2 ^f5
  > In practice, since the inverse cumulative probability function decays so rapidly, there is a block of solid color surrounded by “fuzzy” edges.
  > we believe that this imprecision is a “beneficial difficulty” [14] as it discourages artificially precise comparisons where there is a great deal of uncertainty associated with the data.
- [ux/uncertainty] Moving the margin of error to text does not help: readers followed
  the mean in 62.2% of trials (vs 91.6% with drawn bars) yet were more confident.
  4.3.1-4.3.2 ^f6
  > bars (91.6% of trials) than with bar charts with only textual margins of error (62.2%).
  > additionally they are unjustifiably more confident in their incorrect judgments.
- [ux/uncertainty] Lay readers can reason about mean and error by eye: confidence in "A
  wins" rose gradually as the p-value fell, with no cliff at 0.05, and the alternatives
  gave more appropriate doubt. Fig. 8, 4.4.2 ^f7
  > participants in general become gradually more confident on average with decreases in p-value.
  > encourage more appropriate doubt about inferences from samples to populations.
- [ux/charts] Checked, not there: no difference between gradient and violin plots for
  decisions; either over error bars. 5.1 ^f8
  > Our data do not support the use of one over the other for decisions tasks
- [ux/trust] Readers may prefer a familiar but worse encoding; unfamiliar gradient and
  violin plots still worked for a general audience. 5 Summary ^f9
  > the cost of using alternate encodings appears to be low: even though the ones tested are unfamiliar, they still offer performance advantages to a general audience.
  > viewers might prefer to see familiar but known suboptimal encodings.
- [ux/uncertainty] (inferred) For meio.lol: a number with a capped range bar invites
  "in or out" readings and inflated gaps; a dot with a soft fading band, or a value
  coloured without whiskers, avoids both. Do not drop the range into a footnote: text-only
  margins made readers worse and surer. ^f10

## Read

- Abstract, sections 2-3, 4.2-4.4 results and discussions, 5 summary and limitations.

## Not read

- Experiment stimuli and data tables (supplementary site).
