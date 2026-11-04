---
title: 'Fernandes, Walls, Munson, Hullman, Kay 2018: Uncertainty Displays Using Quantile Dotplots or CDFs Improve Transit Decision-Making'
url: https://mucollective.northwestern.edu/files/2018-UncertainBusDecisions-CHI.pdf
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: listed (abstract, conditions, results, discussion, conclusion)
relevance: high
grade: A/strong
description: CHI 2018 incentivised MTurk experiment on bus decisions: quantile dotplots (50 dots best, 20 close) and CDFs gave better, more consistent decisions than point estimates; single-interval text was erratic depending on the level shown (85% as bad as no uncertainty)
---
# Fernandes et al. 2018: Quantile dotplots or CDFs improve transit decisions

Why: do uncertainty displays improve decisions (not just probability reading), and does
a single stated interval in words work?

## Assessment

- Evidence: A. CHI 2018 honourable mention, incentivised repeated decisions (40 trials),
  Bayesian models of mean and spread of decision quality, open data and code.
- Reasoning: strong. Compares 9 conditions incl. text at 3 interval levels; discusses
  why text is fragile.
- Interests: the authors created quantile dotplots.
- Weigh: effects are a few points of payoff, but consistent; Master Turkers, US only.
  Sample size not found in the parts read.

## Findings

- [ux/uncertainty] Quantile dotplots with 50 outcomes gave decisions at 97% of optimal
  payoff, 5 points above point estimates, and more consistent. Abstract ^f1
  > "Decisions with quantile dotplots with 50 outcomes were (1) better on average, having expected payoffs 97% of optimal"
- [ux/uncertainty] [ux/charts] CDF plots did nearly as well; both beat text, which
  depended on the interval level given. Abstract ^f2
  > "Cumulative distribution function plots performed nearly as well, and both outperformed textual uncertainty, which was sensitive to the probability interval communicated."
- [ux/uncertainty] Text with an 85% interval was poor, close to showing no uncertainty;
  60% and 99% text did nearly as well as 20 dots. Discussion ^f3
  > "Meanwhile, decisions produced by text85 were poor, and exhibited little learning."
- [ux/uncertainty] A single stated interval cannot be adapted to each reader's own risk
  tolerance; displays of the whole distribution can. Discussion ^f4
  > "Because text intervals show only one interval estimate, people cannot adapt their decisions as easily to the costs and benefits of a particular situation."
- [ux/trust] People may read 85% and 99% as the same "high chance", leading to
  overconfidence. Discussion ^f5
  > "people may also interpret 85% and 99% intervals as communicating nearly the same thing"
- [ux/uncertainty] Dotplots gave the worst-off users better decisions: 20 dots matched
  99% text on average but with less spread. Results ^f6
  > "dot20 likely supports better decisions for the worst-performing users compared to text99"
- [ux/uncertainty] Displays that let people read probabilities accurately also gave
  better decisions, which the authors expect to carry to other domains. Conclusion ^f7
  > "The types of displays that we have found to be the best for supporting decision-making in the transit have also been shown to be more accurate at estimating probability intervals more generally"
- [ux/uncertainty] (inferred) "80% range: 49 to 54%" in words alone is the fragile kind
  of display here: readers may treat 80% as near certain; a dot or quantile strip on
  demand gives them the whole spread. ^f8

## Read

- abstract, conditions (text intervals, PDF-interval, CDF, dotplots), results, discussion,
  conclusion

## Not read

- payoff model details; supplement
