---
title: 'Eppo docs: Experiment Analysis (reading results)'
url: https://docs.geteppo.com/experiment-analysis/
kind: docs
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: docs (whole page)
relevance: high
grade: A/strong
description: Eppo's results page: lift as a black bar in a CI bar coloured green/red only when it excludes zero, hover for bounds in a sentence, Bayesian stats (probability beats control, ROPE, risk, loss) behind a details icon
---
# Eppo docs: Experiment Analysis (reading results)

Why: how a careful experiment tool shows estimate, interval, colour and Bayesian
"chance to beat".

## Assessment

- Evidence: A for what the product shows (Eppo, now part of Datadog; widely used).
- Reasoning: strong for docs. Explains why intervals exist, what colour means, what the
  interval leaves out.
- Interests: vendor docs.
- Weigh: written for analysts; the hover sentence and good/bad colouring are the parts
  that carry to lay readers.

## Findings

- [ux/charts] [ux/uncertainty] Lift drawn as a black vertical bar with its confidence
  interval bar around it. Overview ^f1
  > "we display the estimated lift graphically as a black vertical bar, as well as a confidence interval that shows the values of the lift that we consider plausible given the observed data"
- [ux/uncertainty] Hovering gives the result as a plain sentence: best estimate, then
  "95% confident" it lies between two bounds. Overview ^f2
  > "our best estimate of the lift caused by this treatment is 4.68%, and we are 95% confident that the lift is between 1.76% and 7.61%"
- [ux/colour] The bar and estimate turn green or red only when the interval excludes
  zero; colour means good or bad, not up or down. Overview ^f3
  > "will be highlighted green if the movement is _good_ (in which case there will also be a 🎉 symbol in the lift estimate box), and red if the movement is _bad_."
  > "Green/red means _good_/_bad_ not _up_/_down_"
- [ux/uncertainty] Bayesian mode shows "Probability Beats Control" and "Probability >
  Precision" (a minimum worthwhile difference, ROPE) behind a statistical details icon,
  not in the main view. Bayesian statistics ^f4
  > "Probability Beats Control: The probability that the treatment variation is superior to the control variation"
  > "we might care not just about whether the treatment is strictly better than control, but whether it is better _enough_ that the difference is meaningful"
- [ux/uncertainty] Risk (expected lift if it is in fact bad) and Loss (chance control
  wins times risk) are also there, also in the details panel. Bayesian statistics ^f5
  > "Note that this is the same as the probability control beats treatment multiplied by risk."
- [ux/trust] Main view is the interval; extra statistics are opt-in. Statistical details ^f6
  > "In general, the confidence intervals will provide the information you need to make a ship/no-ship decision."
- [ux/trust] The docs say what the interval leaves out (season, trends, changing users),
  i.e. sampling error only. Footnote 3 ^f7
  > "Note that there are other sources of uncertainty that are _not_ included in how the confidence interval is calculated."
- [ux/uncertainty] Hover over the lift shows each side's value and the number of
  subjects. Overview ^f8
  > "If you hover over the lift, you can see the metric values for both control and treatment variations, as well as the sum of the underlying fact(s) and the number of subjects assigned to each variation."

## Read

- whole page

## Not read

- analysis-methods page (sequential vs Bayesian details)
