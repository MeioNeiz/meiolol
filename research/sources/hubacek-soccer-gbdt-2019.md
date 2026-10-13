---
title: 'Hubáček, Šourek, Železný 2019: Learning to predict soccer results from relational data with gradient boosted trees'
url: https://link.springer.com/content/pdf/10.1007/s10994-018-5704-6.pdf
kind: paper
commit: 
for: [gnn-match-outcome]
looked: 2026-10-13
depth: docs (sections 1-6, 8, Tables 2, 4, 5)
relevance: medium
grade: B/strong
description: CTU Prague, Machine Learning journal 2019; winner of the 2017 Soccer Prediction Challenge (200k+ games, forward-in-time test); XGBoost on dense rating and form features (pi-ratings, PageRank on the results graph) beat a relational learner on raw facts; ratings carry almost all the signal
---
# Hubáček, Šourek, Železný 2019: Learning to predict soccer results from relational data with gradient boosted trees

Why: (d) GBDT on dense features with a rating as the main input, against a relational
(graph-structured) learner, on a true forward test; and (a)/(c) does a graph-derived
rating (PageRank) add anything over a plain rating?

## Assessment

- Evidence: B. Won a blind challenge whose test games had not yet been played; 200k+
  games; season-by-season retraining; Machine Learning journal.
- Reasoning: strong. Upper and lower baselines (home-rate naive, bookmaker), feature
  group ablation, honest about bookmaker dominance and the small value of extra
  features.
- Interests: none beyond their entry.
- Weigh: soccer teams (persistent, many games each) differ from our ad hoc 5-player
  teams; read for "ratings first, GBDT on top, graph features add crumbs". No LR on the
  same features, so it does not show GBDT beats LR.

## Findings

- [data] Challenge data: over 200,000 past results with only team names and score;
  the test games were future matches. Abstract, section 1 ^f1
  > A dataset of over 200,000 past match outcomes was provided to the contestants.
  > The test set was not only unavailable to the
- [method] Two families: RDN-Boost (relational dependency networks learning from ground
  facts) vs XGBoost on 66 hand-built features (pi-ratings, PageRank of the results
  graph, form, league table context). Sections 3-4, Table 2 ^f2
  > We experimented with both relational and feature-based methods to learn predictive models from the provided data.
- [method] Forward-in-time validation: each season predicted by a model trained on all
  earlier seasons. Section 5.1 ^f3
  > For each season from this validation period, the model was trained on all preceding seasons.
- [method] Feature-based XGBoost classification won (validation RPS 0.2055, challenge
  test 0.2063, first place); the relational learner came close but trained for weeks
  vs hours. Sections 5-7 ^f4
  > Its RPS on the challenge test set was 0.2063, making it the winning predictor of the contest.
  > The training times for RDN-Boost model was on the order of weeks in comparison with a few hours for training the Xgboost model.
- [method] Ablation: pi-ratings alone 0.2067 RPS; adding PageRank and historical
  strength 0.2061; all 66 features 0.2055. The graph feature and form add about 0.0006
  each. Table 5 ^f5
  > each feature set extension leads to a small improvement of the model’s performance.
- [method] Authors' reading: most of the signal is the rating; more features gave very
  small edges. Section 8 ^f6
  > Most of the prediction performance can be attributed to the complex rating metrics, i.e. the pi-ratings and the PageRank
- [method] The bookmaker beat the best model on every league (22,000 games with odds):
  outside information wins. Section 5.3 ^f7
  > It follows that the bookmaker completely dominates the learned classifier’s predictions.
- [method] Checked, not there: no logistic regression or linear model on the same
  features, so GBDT vs LR is not measured; no player-level data at all. ^f8
- [method] (inferred) For us: (d) a GBDT whose main input is a good rating, with dense
  history features around it, is the shape that wins forward tests; but expect the
  trees to add little beyond the rating, and the graph-derived rating (PageRank) to add
  less than a tenth of a percent. Our equivalent is LR player-history terms as a base
  margin and a small GBDT on residual dense features. ^f9

## Read

- Sections 1-6 and 8, Tables 2, 4, 5, Figs 2-3 captions

## Not read

- Section 3.5 portfolio details, appendix league tables
