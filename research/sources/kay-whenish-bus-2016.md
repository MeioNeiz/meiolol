---
title: 'Kay, Kola, Hullman, Munson 2016: When (ish) is My Bus? User-centered Visualizations of Uncertainty in Everyday, Mobile Predictive Systems'
url: https://vis.mit.edu/classes/6.859/readings/pdfs/Kay-WhenishIsMyBus.pdf
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: listed (abstract, quantile dotplot design, results on variance and confidence, discussion)
relevance: high
grade: A/strong
description: CHI 2016 paper introducing quantile dotplots: 541 transit-app users estimated probabilities more consistently and confidently from a 20-dot quantile dotplot than from a density plot; 100 dots lost the gain
---
# Kay et al. 2016: When (ish) is My Bus? (quantile dotplots)

Why: how to show one uncertain number on a small screen to everyday users.

## Assessment

- Evidence: A. CHI paper, 541 real transit-app users (after 9 removed), Bayesian
  beta regression with priors from Hullman 2015, power stated; origin of quantile
  dotplots, now widely used (ggdist, forecasting).
- Reasoning: strong. Survey, design process and experiment; limits stated (glanceability,
  visual appeal, lab not field).
- Interests: the authors propose the design.
- Weigh: the gain over density plots is modest (about 1.15 times lower variance); the
  stronger signal is higher, better calibrated confidence with 20 dots. Sample skews male
  and technical, like League players.

## Findings

- [ux/uncertainty] [ux/charts] Quantile dotplots: draw evenly spaced quantiles as dots,
  so a reader counts dots to get a chance (3 of 50 dots = 6%). Figure 2 ^f1
  > "By using quantiles we facilitate interval estimation from frequencies"
  > "if we are willing to miss our bus 3/50 times, we can count 3 dots"
- [ux/uncertainty] 20-dot dotplots cut the spread of people's probability estimates about
  1.15 times compared with density plots, and raised confidence. Abstract ^f2
  > "quantile dotplots reduce the variance of probabilistic estimates by ~1.15 times compared to density plots and facilitate more confident estimation by end-users"
- [ux/uncertainty] 100 dots did no better than a density plot: too many to count, so
  read as area. Results: variance ^f3
  > "dotplot-100 has similar variance to density, consistent with people estimating area instead of counting dots"
- [ux/uncertainty] Recommendation: few enough dots that groups can be seen at a glance
  (subitizing, under about 5 per column). Discussion ^f4
  > "Thus, we recommend discrete outcome plots with few enough outcomes to take advantage of subitizing."
- [ux/trust] Only with 20 dots did people's confidence track their accuracy. Results: confidence ^f5
  > "At least with dotplot-20, people have some ability to assess how good their own estimates are."
- [ux/trust] Most users wanted uncertainty shown; a minority did not, some because it
  moves blame for a bad decision onto them. Discussion ^f6
  > "most respondents said they appreciated the idea of representing uncertainty"
  > "Five feared that, if given uncertainty information, they would become responsible for making decisions"
- [ux/charts] Dotplots were rated less visually appealing than density plots. Discussion ^f7
  > "were also rated less visually appealing"
- [ux/uncertainty] A point estimate alone conveys false precision; the design must
  balance it against glanceability (point prominent but not alone). Design requirements ^f8
  > "glanceability/false precision tradeoff"
- [ux/uncertainty] (inferred) For a single win rate on a detail page, a 20-dot quantile
  dotplot of the 80% predictive spread lets a lay reader count "how many of 20 outcomes
  are above 50%"; in dense tables a bar stays better (space). ^f9

## Read

- abstract, intro, quantile dotplot section, results (variance, confidence), discussion

## Not read

- survey details, layout comparison, bias results
