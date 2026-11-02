---
title: 'Google Analytics: Analytics Insights'
url: https://support.google.com/analytics/answer/9443595
kind: docs
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: docs (whole page)
relevance: medium
grade: A/fair
description: GA4 automated and custom insights: user-set thresholds, ranking by interaction, withheld when data is late
---
# Google Analytics: Analytics Insights

Why: how a product with huge volume decides a change is worth a sentence, and what
thresholds it states. Anomaly rule is in [[ga4-anomaly]].

## Assessment

- Evidence: A for use (GA4 is the dominant web analytics tool); the anomaly page states
  the actual model.
- Reasoning: fair. The anomaly rule is explicit (credible interval, training windows);
  how text is worded is not covered, and cards are mostly metric and change, not prose.
- Interests: vendor.
- Weigh: the pattern to copy is "flag only what leaves its own predicted range, and
  suppress small segments", not the time-series model (we have one number per patch).

## Findings

- [ux/features] Users can set their own rule as a threshold on a metric, e.g. "30-day
  active users - % decrease more than - 20", or "Has anomaly" with no value; up to 50
  custom insights per property. ^f1
  > Metric: Select the metric, condition, and value to set the threshold that triggers the insight. For example: 30-day active users - % decrease more than - 20.
- [ux/features] Insights are cards on the Home page and an Insights dashboard, ranked by
  what the user interacts with; kept one year. Clicking a card gives the details. ^f2
  > Every time you interact with an insight, Analytics Intelligence learns which ones you’re most interested in and ranks your new insights accordingly.
- [ux/uncertainty] Delay of data can cause false alerts, so hourly insights for app
  events are withheld: a case of not saying something when the data is not final. ^f3
  > Delay in the collection of app events would result in inaccurate evaluation of the custom insight, thus triggering false notifications.
- [ux/uncertainty] Checked, not there: no wording rules for the card text, no stated
  hedging language, and no example sentences on these pages. ^f4
- [ux/features] (inferred) For meiolol the analogue of "outside the credible interval"
  is "outside the champion's own interval around the role average"; and the analogue
  of the 0.05% segment floor is a minimum games floor below which no sentence is
  written at all. ^f5

## Read

- Whole page

## Not read

- Trend change detection, Contribution analysis, AI overviews pages (linked in the nav)
