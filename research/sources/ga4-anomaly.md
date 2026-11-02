---
title: 'Google Analytics: Anomaly detection (how insights are flagged)'
url: https://support.google.com/analytics/answer/9517187
kind: docs
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: docs (whole page)
relevance: medium
grade: A/fair
description: GA4 anomaly rule: outside a Bayesian credible interval, training windows, and a 0.05% minimum segment size

---
# Google Analytics: Anomaly detection (how insights are flagged)

Why: what rule decides a change is worth surfacing. Companion to [[ga4-insights]].

## Assessment

- Evidence: A for use (GA4); the page states the actual rule.
- Reasoning: fair. Explicit model and windows, no wording rules.
- Interests: vendor.
- Weigh: copy "outside its own predicted range" and the minimum-size floor, not the
  time-series model.

## Findings

- [ux/uncertainty] Automated insights flag a change only when the actual value falls
  outside a credible interval predicted from history (Bayesian state-space model), not
  at any change. Training window by period: hourly 2 weeks, daily 90 days, weekly 32
  weeks. ^f1
  > flags the datapoint as an anomaly if the actual value falls outside the credible interval. For detection of hourly anomalies, the training period is 2 weeks. For detection of daily anomalies, the training period is 90 days.
- [ux/uncertainty] A segment-level insight needs a minimum size: a segment is surfaced
  only if anomalous and it comprises at least 0.05% of the users on that property
  (metrics normalised by users in the segment, PCA across segments, run weekly). ^f2
  > If any particular segment demonstrates anomalous behavior across any metric and comprises at least 0.05% of the users on that property, we surface those segments as anomalies.

## Read

- Whole page

## Not read

- Trend change detection, Contribution analysis
