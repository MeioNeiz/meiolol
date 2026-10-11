---
title: 'Robinson: Understanding empirical Bayes estimation (using baseball statistics)'
url: http://varianceexplained.org/r/empirical_bayes_baseball/
kind: article
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: listed (whole post)
relevance: high
grade: B/fair
description: Widely read tutorial (2015) on beta-binomial empirical Bayes shrinkage of proportions, later a book; the pseudo-count recipe for win rates
---
# Robinson: Understanding empirical Bayes estimation (using baseball statistics)

Why: the standard practical recipe for shrinking thin proportions (matchup win rates,
first blood or lane-kill chance), and a plain-language framing for our method page.

## Assessment

- Evidence: B. Well-known blog post by a data scientist (then Stack Overflow), turned
  into the book "Introduction to Empirical Bayes"; tutorial, not a validation study.
- Reasoning: fair. Explains why, admits its simplifications in an appendix.
- Interests: none known.
- Weigh: recipe is sound and matches Brown's normal version ([[brown-2008-batting-eb]]);
  the 500 at-bat filter for fitting the prior is a shortcut he flags himself.

## Findings

- [stats] Hard minimum-count filters throw away information; shrinkage is the
  alternative. ^f1
  > One approach is to filter out all cases that don’t meet some minimum, but this isn’t always an option: you’re throwing away useful information.
- [stats] [method] Two steps: estimate the distribution of the quantity over all units,
  then use it as the prior for each unit. ^f2
  > Estimate the overall distribution of your data.
  > Use that distribution as your prior for estimating each average.
- [stats] [method] With a beta prior the update is pseudo-counts: add alpha0 to
  successes and alpha0 + beta0 to the total; one line of code. ^f3
  > it’s as simple as adding α0α0 to the number of hits, and α0+β0α0+β0 to the total number of at-bats.
  > float estimate = (successes + 78.7) / (total + 303.5);
- [stats] Prior strength fitted from real data was about 300 pseudo at-bats for career
  batting averages: a 4/10 batter is estimated at 0.264, a 300/1000 batter at 0.29. ^f4
  > This comes up with α0\=78.661α0\=78.661 and β0\=224.875β0\=224.875.
- [stats] Shrinkage depends on evidence: little data moves a lot, much data barely. ^f5
  > if we have very little evidence (4 hits out of 10) we move it a lot, if we have a lot of evidence (300 hits out of 1000) we move it only a little.
- [stats] Better priors depend on known factors (era, team, position), i.e. a
  hierarchical model; he recommends fitting the prior on all data weighted by evidence
  (beta-binomial ML) rather than a filtered subset. ^f6
  > In reality, we’d expect that it depends on some known factors.
  > Really, we should use all of our data to estimate the distribution, but give _more consideration_ to the players with a higher number of at-bats.
- [stats] [method] (inferred) For matchup win rates: shrink toward the additive
  expectation p0 (from both champions' overall win rates) with pseudo-count m:
  (wins + m * p0) / (games + m), m fitted per role by method of moments. ^f7
- [stats] (inferred) Plain-language line for our method page: "Extraordinary outliers
  require extraordinary evidence". ^f8
  > _Extraordinary outliers require extraordinary evidence_.

## Read

- Whole post including appendix

## Not read

- Follow-up posts (credible intervals, beta-binomial regression on n) and the book
