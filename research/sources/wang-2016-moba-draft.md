---
title: Predicting MOBA Game Outcome Based on Hero Draft Data (Wang, NCIRL MSc 2016)
url: https://norma.ncirl.ie/2523/1/weiqiwang.pdf
kind: paper
commit:
for: [comp-attribute-features]
looked: 2026-10-13
depth: docs (abstract, related work, data, results)
relevance: low
grade: C/fair
description: NCIRL MSc thesis; LR and NN on Semenov's 5M Dota 2 games (very high skill, 912k); its related work is the main secondary report of role and hero-relationship features in early Dota work
---
# Predicting MOBA Game Outcome Based on Hero Draft Data (Wang, NCIRL MSc 2016)

Why: a search hit for Dota hero attribute features; turned out to be ids plus game
length, but its related work summarises the early role and interaction attempts.

## Assessment

- Evidence: C. MSc thesis; own result on 912,501 very high skill games, 5-fold CV.
- Reasoning: fair; reports a null result plainly.
- Interests: none known.
- Weigh: the related-work numbers are secondary (student reports, mixed setups); use as
  leads, check primaries.

## Findings

- [method] [draft] Secondary report: Agarwala and Pearce 2014 clustered hero roles by
  PCA of performance stats (kills, deaths, GPM) to model hero interactions; with
  interactions 57% accuracy, without 62%. ^f1
  > To cluster the roles of different heroes,
  > they used PCA analysis of the heroes' performance statistics
  > Their new model only achieved 57% accuracy while
  > their model without hero interactions achieved 62% accuracy.
- [method] Secondary report: Yang et al. 2014 added 50 hand-picked two-hero combinations,
  not better than Conley and Perry's plain LR; Kalyanaraman 2015 used hero roles
  implicitly (GA plus LR ensemble, 74.1%); Kinkade and Lim 72.9% by adding hero win
  rates. ^f2
  > Kalyanaraman (2015) first used hero roles as one of the input feature implicitly.
  > Kinkade and Lim (n.d.) got 72.9% accuracy using
- [method] Own result: one-hot hero LR on 912,501 very high skill games, 5-fold CV,
  60.38%; adding binned game length 61.04%; NN no better. Plateau near 200,000 games. ^f3
  > Without the duration feature, a logistic regression
  > with 5-fold cross validation produced an accuracy of 60.38%.
  > the performance of logistic regression on the test set reaches plateau at
  > around 200,000 training set size.
- [method] Checked, not there: no hero role, attribute or composition feature in its own
  models. ^f4

## Read

- Abstract, introduction, related work, data pre-processing, results, Table 1

## Not read

- NN tuning details
