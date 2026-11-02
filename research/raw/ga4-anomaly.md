# [GA4] Anomaly detection - Analytics Help

<https://support.google.com/analytics/answer/9517187>

[Skip to main content](https://support.google.com/analytics/answer/9517187#hcfe-content)

[Analytics Help](https://support.google.com/analytics)

[Sign in](https://accounts.google.com/ServiceLogin?hl=en&passive=true&continue=http://support.google.com/analytics/answer/9517187&ec=GAZAdQ)

-   [Help Center](https://support.google.com/analytics/?hl=en)
-   [Community](https://support.google.com/analytics/community?hl=en&help_center_link=CIPxxAQSF1tHQTRdIEFub21hbHkgZGV0ZWN0aW9u)
-   [Announcements](https://support.google.com/analytics/announcements/10707884)

[Analytics](https://www.google.com/analytics/) [Contact us](https://support.google.com/analytics/gethelp)

-   Get started with Analytics
-   Collect and manage data
-   Report and explore
-   Advertising and attribution
-   Audiences and remarketing
-   Manage accounts, properties, and users
-   Google Analytics 360
-   Policies and data privacy

-   [Analytics Intelligence](https://support.google.com/analytics/topic/10333392?hl=en&ref_topic=9228654)
-   [\[GA4\] Anomaly detection](https://support.google.com/analytics/answer/9517187)

# \[GA4\] Anomaly detection

Anomaly detection is a statistical technique that Analytics Intelligence uses to identify anomalies in time-series data for a given metric, and anomalies within a segment at the same point of time.

## Identifying anomalies in metrics over time

Intelligence applies a [Bayesian state-space time series model](http://people.ischool.berkeley.edu/~hal/Papers/2013/pred-present-with-bsts.pdf) to the historic data to predict the value of the most recent datapoint in the time series. The model produces a prediction and a [credible interval](https://en.wikipedia.org/wiki/Credible_interval) that we use to evaluate the observed metric.

Using historical data, Analytics Intelligence predicts the value of the metric at the current time period and flags the datapoint as an anomaly if the actual value falls outside the credible interval. For detection of hourly anomalies, the training period is 2 weeks. For detection of daily anomalies, the training period is 90 days. For detection of weekly anomalies, the training period is 32 weeks.

## Identifying anomalies within a segment at the same point in time

While time-series based anomaly detection uses historical data to flag a single metric within a single dimension value, we also provide anomaly detection simultaneously over several metrics and dimension values, at a point in time.

In this approach we use [principal components analysis](https://en.wikipedia.org/wiki/Principal_component_analysis) (PCA) to leverage the correlation structure of the metrics along with [cross-validation](https://en.wikipedia.org/wiki/Cross-validation_\(statistics\)) to flag anomalies.

First, we identify the set of dimensions and metrics that will undergo the PCA. Based on all possible dimension values, we create multiple segments, then normalize each metric by the number of users within a segment. Next, we run the PCA for those segments and normalized metrics. If any particular segment demonstrates anomalous behavior across any metric and comprises at least 0.05% of the users on that property, we surface those segments as anomalies. Currently we do this analysis every week.

Choose a section to give feedback on

## Was this helpful?

## Need more help?

[

Post to the help community Get answers from community members

](https://support.google.com/analytics/community?hl=en&help_center_link=CIPxxAQSF1tHQTRdIEFub21hbHkgZGV0ZWN0aW9u)[

Contact us Tell us more and we’ll help you get there

](https://support.google.com/analytics/gethelp)

## [Analytics Intelligence](https://support.google.com/analytics/topic/10333392?hl=en&ref_topic=9228654)

-   [Analytics Insights](https://support.google.com/analytics/answer/9443595?hl=en&ref_topic=10333392)
-   [\[GA4\] Anomaly detection](https://support.google.com/analytics/answer/9517187#)
-   [\[GA4\] Trend change detection](https://support.google.com/analytics/answer/12207035?hl=en&ref_topic=10333392)
-   [\[GA4\] Contribution Analysis](https://support.google.com/analytics/answer/10388660?hl=en&ref_topic=10333392)
-   [Recommendations](https://support.google.com/analytics/answer/12147430?hl=en&ref_topic=10333392)
-   [Benchmarking](https://support.google.com/analytics/answer/16388466?hl=en&ref_topic=10333392)
-   [AI overviews](https://support.google.com/analytics/answer/15598263?hl=en&ref_topic=10333392)

©2026 Google

-   [Privacy Policy](https://www.google.com/intl/en/privacy.html)
-   [Terms of Service](https://www.google.com/accounts/TOS)

Language

English‎

Send feedback on...

 

[Google Help](https://support.google.com/)

[-   Help Center](https://support.google.com/analytics/?hl=en)

[-   Get started with Analytics](https://support.google.com/analytics/topic/14090456?hl=en&ref_topic=3544742,2986333,)[-   Collect and manage data](https://support.google.com/analytics/topic/14132937?hl=en&ref_topic=3544742,2986333,)[-   Report and explore](https://support.google.com/analytics/topic/9228654?hl=en&ref_topic=3544742,2986333,)[-   Advertising and attribution](https://support.google.com/analytics/topic/10595744?hl=en&ref_topic=3544742,2986333,)[-   Audiences and remarketing](https://support.google.com/analytics/topic/9303474?hl=en&ref_topic=3544742,2986333,)[-   Manage accounts, properties, and users](https://support.google.com/analytics/topic/9303569?hl=en&ref_topic=3544742,2986333,)[-   Google Analytics 360](https://support.google.com/analytics/topic/10985992?hl=en&ref_topic=3544742,2986333,)[-   Policies and data privacy](https://support.google.com/analytics/topic/1008008?hl=en&ref_topic=3544742,2986333,)

[-   Community](https://support.google.com/analytics/community?hl=en&help_center_link=CIPxxAQSF1tHQTRdIEFub21hbHkgZGV0ZWN0aW9u)[-   Analytics](https://www.google.com/analytics/)

[-   Privacy Policy](https://www.google.com/intl/en/privacy.html)[-   Terms of Service](https://www.google.com/accounts/TOS)-   Submit feedback

## What is the issue with this selection?

Inaccurate - doesn't match what I see in the product

Hard to understand - unclear or translation is wrong

Missing info - relevant but not comprehensive

Irrelevant - doesn’t match the title and / or my expectations

Minor errors - formatting issues, typos, and / or broken links

Other suggestions - ideas to improve the content

## Share additional info or suggestions

​

​

Do not share any personal info

By continuing, you agree Google uses your answers, [account & system info](https://support.google.com/analytics/answer/9517187#) to improve services, per our [Privacy](https://myaccount.google.com/privacypolicy?hl=en) & [Terms](https://policies.google.com/terms?hl=en).
