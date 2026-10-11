---
title: "Gelman blog: Quantifying luck vs. skill in sports (Tango's regression to the mean)"
url: https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/
kind: article
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: listed (post and first comments)
relevance: high
grade: A/fair
description: Andrew Gelman's blog quoting Phil Birnbaum's derivation of Tom Tango's sabermetric regression-to-the-mean rule, with Gelman's verdict that it is hierarchical Bayes
---
# Gelman blog: Quantifying luck vs. skill in sports (Tango's regression to the mean)

Why: the simplest closed-form shrinkage rule from sports analytics: estimate talent
variance as observed variance minus luck variance, then add k games of average.

## Assessment

- Evidence: A. Tango's method is the standard in sabermetrics for decades (Birnbaum,
  FanGraphs); Gelman, a leading Bayesian statistician, confirms it is hierarchical Bayes
  with a point estimate of the group variance.
- Reasoning: fair. Full algebra by Birnbaum; Gelman's comment is short.
- Interests: none known.
- Weigh: derived for win/loss (binomial) but the algebra is general: replace .25/g by
  sigma^2/n for gold diffs.

## Findings

- [stats] [method] Tango's method: talent variance = observed variance between teams
  minus the theoretical luck variance; luck from the binomial. ^f1
  > var(performance) = var(talent) + var(luck)
  > Second, figure out the theoretical standard deviation of luck over a season, using the binomial approximation to normal.
- [stats] [method] The regression constant k is the number of games where luck SD
  equals talent SD; add k games of league-average performance to every record. ^f2
  > now, find the number of games for which the SD(luck) equals SD(talent), or 0.058. It turns out that’s about 74 games
  > any time you want to regress a team’s record to the mean, take 74 games of .500 ball (37-37), and add them to the actual performance.
- [stats] k does not depend on the sample size: the same pseudo-games are added to an
  8-game or a 162-game record; k = within-unit variance / talent variance. ^f3
  > For every “g” games of observed performance, we want .25/t^2 games of average performance.
  > So no matter whether you’re regressing a team over 1 game, or 10 games, or 20 games, or 162 games, you can always add \*the same number of average games\* and get the right answer!
- [stats] Weight on the observed value is t^2/v^2, the reliability (r-squared of
  outcome on talent). ^f4
  > Expected talent = average + t^2/v^2 (X – mean)
- [stats] Gelman: this is hierarchical Bayes with a point estimate of the group-level
  variance, as in BDA chapter 2. ^f5
  > they’re doing hierarchical Bayes with a point estimate for the group-level variance.
- [stats] Insurance credibility theory (Buhlmann) uses the same N/(N+K) weight, K the
  ratio of within- to between-individual variance. Comment ^f6
  > There is a well-known N/(N+K) formula for assigning weight to the individual’s experience, where K is based on the ratio of within-individual and between-individual variance.
- [stats] [method] (inferred) For a matchup curve at minute t: k_t = sigma_t^2 / tau_t^2,
  where sigma_t^2 is the within-matchup game-to-game variance of gold diff at t and
  tau_t^2 the between-matchup variance of true interaction effects; estimate =
  (n * observed + k_t * baseline) / (n + k_t). This is also the "games to stabilise"
  number to publish. ^f7

## Read

- Post and the first two comments

## Not read

- Remaining 27 comments; Birnbaum's original blog post (same text quoted)
