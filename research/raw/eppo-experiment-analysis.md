# Introduction | The Eppo Docs

<https://docs.geteppo.com/experiment-analysis/>

[Skip to main content](https://docs.geteppo.com/experiment-analysis/#__docusaurus_skipToContent_fallback)

**Webinar: How Delivery Hero Uses Switchbacks to Drive Marketplace Innovation**   Watch the recording  [here →](https://www.youtube.com/watch?v=4sUDhv3AFrg)

[Login](https://eppo.cloud/)[Get a Demo](https://www.geteppo.com/get-access)

-   Getting Started
    
    -   [About Eppo](https://docs.geteppo.com/)
    -   [Analysis quickstart](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [SDK quickstart](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Contextual Bandit quickstart](https://docs.geteppo.com/bandit-quickstart/)
    -   [Switchback quickstart](https://docs.geteppo.com/switchback-quickstart/)
-   Core Concepts
    
    -   [Flag and Experiment Configuration](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Data Management](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Experiment Analysis](https://docs.geteppo.com/experiment-analysis/#)
        
        -   [Introduction](https://docs.geteppo.com/experiment-analysis/)
        -   [Configuration](https://docs.geteppo.com/experiment-analysis/configuration/)
            
        -   [Reading Results](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Results Deep Dive](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Program Management](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Best practices](https://docs.geteppo.com/experiment-analysis/best-practices/)
        -   [Clustered analysis](https://docs.geteppo.com/experiment-analysis/clustered-analysis/)
        -   [Diagnostics](https://docs.geteppo.com/experiment-analysis/diagnostics/)
        -   [Experiment tags](https://docs.geteppo.com/experiment-analysis/experiment-tags/)
        -   [Holdout Analysis](https://docs.geteppo.com/experiment-analysis/holdouts/)
        -   [Switchback experiments](https://docs.geteppo.com/experiment-analysis/switchbacks/)
    -   [Contextual Bandits](https://docs.geteppo.com/experiment-analysis/#)
        
-   SDKs
    
    -   [Introduction](https://docs.geteppo.com/sdks/)
    -   [Architecture](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Concepts](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [SDK keys and environments](https://docs.geteppo.com/sdks/sdk-keys/)
    -   [Event Logging](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Client SDKs](https://docs.geteppo.com/sdks/client-sdks/)
        
        -   [JavaScript](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Android](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Dart & Flutter](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [iOS](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [React Native](https://docs.geteppo.com/experiment-analysis/#)
            
    -   [Server SDKs](https://docs.geteppo.com/sdks/server-sdks/)
        
        -   [Node](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [.NET](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [PHP](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Python](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Java](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Go](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Rust](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Ruby](https://docs.geteppo.com/experiment-analysis/#)
            
        -   [Elixir](https://docs.geteppo.com/experiment-analysis/#)
            
    -   [Datadog integration](https://docs.geteppo.com/sdks/datadog/)
    -   [Best Practices](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Eppo Developer Tools - Chrome Extension](https://docs.geteppo.com/sdks/developer-tools-extension/)
    -   [Using Eppo SDK with pre-forking servers](https://docs.geteppo.com/sdks/preforking/)
-   Guides
    
    -   [Introduction](https://docs.geteppo.com/guides/)
    -   [Marketing Integrations](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Engineering Tutorials](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Metadata](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Advanced Experimentation Topics](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Migrations](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Debugging Metrics](https://docs.geteppo.com/guides/debugging-metrics/)
-   Reference
    
    -   [Statistics](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Administration](https://docs.geteppo.com/experiment-analysis/#)
        
    -   [Architecture and Security](https://docs.geteppo.com/reference/architecture-and-security/)
    -   [REST API](https://docs.geteppo.com/reference/api/)
    -   [Webhooks](https://docs.geteppo.com/reference/webhook/)

-   
-   Core Concepts
-   Experiment Analysis
-   Introduction

# Experiment Analysis

Once you have started to collect data on some experiments, you'll want to start reviewing the results! Eppo allows you to see experiment results across multiple experiments, zoom in on a specific experiment, estimate global impact, and then slice and dice those results by looking at different segments and metric cuts.

## Viewing multiple experiments[​](https://docs.geteppo.com/experiment-analysis/#viewing-multiple-experiments "Direct link to Viewing multiple experiments")

When you click on the **Experiments** tab of the **Analysis** section, you will see the **experiment list view**, which shows all of your experiments. You can filter this list by experiment name, timeframe, status, entity, team, creator, primary metric, or just show experiments you have **starred**.

The experiment list view, showing a list of experiments that can be filtered and searched.

## Overview of an experiment's results[​](https://docs.geteppo.com/experiment-analysis/#overview-of-an-experiments-results "Direct link to Overview of an experiment's results")

Clicking on the name of an experiment will take you to the **experiment detail view**, which shows the effects of each treatment variation, compared to control. Within each variation, for each metric that you have added to the experiment, we display the (per subject) **average value for the control variation**, as well as the estimate of the relative lift (that is, the percentage change from the control value) caused by that treatment variation.

In this example, the control value of `Total Purchase Value` is ​**15.63** (per subject), and variation B is estimated to increase that by **4.68%**. For `Add-to-Cart Conversion`, the control value is **55%**, because it has been set to display as a percentage, and the lift is **8%**: this means that the add-to-cart conversion rate that would be expected from shipping the treatment is _108% times the control rate of 55%_, that is, 59.4%.

If you hover over the lift, you can see the metric values for both control and treatment variations, as well as the sum of the underlying fact(s) and the number of subjects assigned to each variation.

In this example, the total purchase value _per assigned subject_ is ​**15.63** for control and **16.36** for treatment, and the total purchase value _across all assigned subjects_ is **812,884.95** for control and **851,526.71** for treatment. There are **52,004** subjects assigned to control, and **52,039** assigned to treatment.

caution

Depending on the metric settings, we may [cap outliers](https://docs.geteppo.com/data-management/metrics/simple-metric/#outlier-handling) in the raw data in order to improve the quality of our lift estimates, and so the average and total values displayed in this popover might differ from those displayed in other tools.

In addition, in many cases (in particular, if [CUPED](https://docs.geteppo.com/statistics/cuped/) is enabled), we perform additional processing on the data before estimating the lift (such as correcting for imbalances across variations along different dimensions). For this reason, the lift displayed on the details page may not match the lift calculated directly from the numbers in this popover.

See [Basics of estimating lift](https://docs.geteppo.com/statistics/confidence-intervals/) for more information on how we estimate lift in different circumstances.

To the right of the details page, we display the estimated lift graphically as a black vertical bar, as well as a confidence interval that shows the values of the lift that we consider plausible given the observed data from the experiment. The precise definition of _plausible_ is determined by, among other things, the confidence level, which defaults to 95%: we set the lower and upper bounds of the confidence interval such that it will contain the true lift at least 95% (or whatever confidence level you've selected) of the time.[1](https://docs.geteppo.com/experiment-analysis/#user-content-fn-confident) In addition, Eppo has several different [methods for calculating the confidence intervals](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/), which can be set at the company or experiment level.

Where does the uncertainty come from?

Randomly allocating users to each variation means that the lift we observe in the experiment data should be a good estimate[2](https://docs.geteppo.com/experiment-analysis/#user-content-fn-goodest) of the lift you would observe if you shipped the treatment. However, any time you estimate something for a whole population using measurements from just a _portion_ of that population (in this case, the subjects in the treatment variation), there's a risk that the sample you chose to observe behaves differently from the population as a whole. Specifically, there's always a chance that a bunch of really active subjects, instead of being evenly split across variations, happened to end up concentrated in the control variation or the treatment variation; that would mean that the lift you observed in the experiment would be lower or higher, respectively, than what you'd observe if you shipped the treatment. This is the uncertainty represented by the confidence interval.[3](https://docs.geteppo.com/experiment-analysis/#user-content-fn-uncertainty) (This is why [CUPED](https://docs.geteppo.com/statistics/cuped/), which corrects some of this imbalance, can often greatly reduce the width of the confidence intervals.)

If you hover over the confidence interval, you will see precise values for the upper and lower bounds for this confidence interval:

In this case, based on our statistical analysis of the experiment data, our best estimate of the lift caused by this treatment is **4.68%**, and we are 95% confident that the lift is between **1.76%** and **7.61%**. Since a lift of 0% does not fall within that range, the confidence interval is highlighted in green.

If the confidence interval is entirely above or below zero, it means that the data is consistent with the treatment moving the metric up or down, respectively. In this case, the confidence interval bar itself, as well as the lift estimate, will be highlighted green if the movement is _good_ (in which case there will also be a 🎉 symbol in the lift estimate box), and red if the movement is _bad_.

Green/red means _good_/_bad_ not _up_/_down_

In general, a positive lift will be _good_ (colored green) and a negative lift will be _bad_ (colored red). However, for metrics such as page load time or app crashes, a higher number is _bad_. We call these reversed metrics. If you've set the "Desired Change" field in the [fact definition](https://docs.geteppo.com/data-management/definitions/fact-sql/) to "Metric Decreasing", then positive lifts will be in red and negative lifts will be in green.

The confidence level is set as part of the [analysis plan](https://docs.geteppo.com/experiment-analysis/configuration/analysis-plans/), and you can change the company-wide default on the [Admin tab](https://docs.geteppo.com/administration/setting-statistical-analysis-plan-defaults/) or set an experiment-specific confidence level on the [experiment Set Up page](https://docs.geteppo.com/experiment-analysis/configuration/analysis-plans/). The confidence level being used for any experiment is displayed on the experiment detail page below the table of metric results:

The confidence level is displayed at the bottom of the metric results table.

### Multivariate comparisons[​](https://docs.geteppo.com/experiment-analysis/#multivariate-comparisons "Direct link to Multivariate comparisons")

By default, Eppo groups by variation first and shows all metric result for a given variation together. As an option, you can also choose to view "By Metric" which groups by metric first and shows how all variants compare to Control for each metric.

To toggle views, simply choose the "By Metric" option from the View dropdown.

This example shows results broken out by metric, allowing for multivariate comparisons at a glance.

### Impact accounting[​](https://docs.geteppo.com/experiment-analysis/#impact-accounting "Direct link to Impact accounting")

The main **Confidence intervals** tab () displays the experiment results observed _for subjects in the experiment_, but you may want to understand the treatment effect _globally_; a large lift in an experiment that targets a tiny portion of your users might have a negligible business impact.

You can click on the [**Impact accounting**](https://docs.geteppo.com/experiment-analysis/reading-results/global-lift/) icon () to show, for each metric, the coverage (the share of all events that are part of the experiment) and global lift (the expected increase in the metric if the treatment variation were rolled out to 100%, as a percentage of the global total metric value).

In this example, the impact accounting view shows that, since the experiment has been active, only **81.8%** of `Total Upgrades to Paid Plan` events were done by subjects that had been assigned to any variation in the experiment. This means that, while the lift _among subjects in the experiment_ is **6.06%**, since 18.2% of events are done by subjects who would not have been affected by the treatment, the top-line number of upgrades is only expected to go up by **4.93%**.

### Statistical details[​](https://docs.geteppo.com/experiment-analysis/#statistical-details "Direct link to Statistical details")

In general, the confidence intervals will provide the information you need to make a ship/no-ship decision. However, if you want to see additional statistical details, you can click on the **Statistical details** icon () to display them. The actual values being shown will differ based on which [analysis method](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/) is being used: sequential and fixed-sample methods will show the frequentist statistics, while Bayesian statistics will differ to reflect the different decision-making processes compatible with that method.

This example shows frequentist statistics, described in detail below.

#### Frequentist statistics[​](https://docs.geteppo.com/experiment-analysis/#frequentist-statistics "Direct link to Frequentist statistics")

Frequentist analysis methods (that is, sequential and fixed-sample) will show the following three statistics:

1.  ​Standard error: The [standard error](https://en.wikipedia.org/wiki/Standard_error) of the lift, expressed in percentage points.
    
2.  ​p-value: The [p-value](https://en.wikipedia.org/wiki/P-value) represents the likelihood that an A/A test (that is, an experiment where the treatment is identical to the control) would produce a lift of a magnitude (that is, ignoring the sign) at least as large as the one observed in the data. The p-value directly corresponds to the bounds of the confidence interval: if your confidence level is 95%, for example, a p-value less than 0.05 (that is, 1−951001−10095​) means that the confidence interval around the lift will _just_ exclude zero.
    
3.  ​Z-score: Also called the [standard score](https://en.wikipedia.org/wiki/Standard_score), the Z-score represents how far away the observed lift is from zero, measured as a number of [standard deviations](https://en.wikipedia.org/wiki/Standard_deviation). The Z-score is simply a transformation of the p-value: it provides no additional information, but it is sometimes easier to use, particularly when the p-value is very small.
    

#### Bayesian statistics[​](https://docs.geteppo.com/experiment-analysis/#bayesian-statistics "Direct link to Bayesian statistics")

[Bayesian methods](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/#bayesian-analysis) rely on a different way of thinking about probabilities, and thus use different statistics to summarize the results of an experiment.

1.  ​Probability Beats Control: The probability that the treatment variation is superior to the control variation; in other words, the chance that the lift is good (positive for most metrics, but negative for reversed metrics (e.g. latency: lower latency is better)
    
2.  ​Probability > Precision: Bayesian analyses comparing two distributions (in our case the average metric values in the treatment variation compared to the average metric values in the control variation) sometimes refer to the [Region of Practical Equivalence (ROPE)](https://journals.sagepub.com/doi/10.1177/2515245918771304), which is the amount of difference between the distributions that is, practically speaking, trivial. In other words, we might care not just about whether the treatment is strictly better than control, but whether it is better _enough_ that the difference is meaningful (in business terms). Since the precision represents the smallest lift that the business cares about, it is also a useful boundary for the ROPE.
    
    For example, if the precision for a metric was a 5% lift, this statistic would calculate the portion of the posterior lift distribution that is _above_ 5% (assuming positive lift is good).
    
3.  ​Risk: The _expected metric lift_ (measured in lift terms, that is, as a percentage of the control value) _if_ the lift were in fact negative: E(X∣X<0)E(X∣X<0) (or, for reversed metrics, positive). In other words, even if the bulk of the distribution indicates that the treatment is better than control, some portion is going to be on the other side: there's some chance that in fact _control_ is better than _treatment_. The risk measures, in that case, what the expected value (that is, the average of all lifts weighted by their likelihood under the posterior distribution) of the lift would be.
    
4.  ​Loss: The expected value of the loss function min⁡(X,0)min(X,0) (reversed for reversed metrics). Note that this is the same as the probability control beats treatment multiplied by risk.
    

## Segments and filters[​](https://docs.geteppo.com/experiment-analysis/#segments-and-filters "Direct link to Segments and filters")

You are able to filter experiment results to specific subgroups by selecting the filter menu at the top right corner. We provide two distinct options to filter results.

### Segments[​](https://docs.geteppo.com/experiment-analysis/#segments "Direct link to Segments")

Segments are pre-specified subsets of users based on multiple attributes. For example, you might have a "North America mobile users", created by filtering for Country = 'Canada', 'USA', or 'Mexico', and Device = 'Mobile'. You can then attach such a segment to any experiment and Eppo pre-computes experiment results for such a subgroup.

Note that when you first add a segment to an experiment, you have to manually refresh the results to compute the results for the segment.

### Single property filter[​](https://docs.geteppo.com/experiment-analysis/#single-property-filter "Direct link to Single property filter")

For quick investigations, we also provide the single property filter: here you can select a single property (e.g. Country) and single value (e.g. 'USA'). These results are available immediately -- no need to manually refresh the results.

## Explores[​](https://docs.geteppo.com/experiment-analysis/#explores "Direct link to Explores")

You can also further investigate the performance of an individual metric by clicking on navigator icon the next to the metric name. This will take you to the [Metric explore](https://docs.geteppo.com/experiment-analysis/deep-dive/explores/) page where you can further slice the experiment results by different properties that have been configured, for example user persona, or browser, etc.

## Footnotes[​](https://docs.geteppo.com/experiment-analysis/#footnote-label "Direct link to Footnotes")

1.  For more on how we define confidence intervals, how to interpret them, and a precise technical definition of what it means to be "X% confident", see [Lift estimates and confidence intervals](https://docs.geteppo.com/statistics/confidence-intervals/). [↩](https://docs.geteppo.com/experiment-analysis/#user-content-fnref-confident)
    
2.  In technical terms, it is _consistent_, meaning that it gets closer to the true lift as the number of subjects in the experiment increases. [↩](https://docs.geteppo.com/experiment-analysis/#user-content-fnref-goodest)
    
3.  Note that there are other sources of uncertainty that are _not_ included in how the confidence interval is calculated. For example, if you start your experiment in June, but don't ship it until December, the behavior of users after being exposed to the treatment in production may be very different from the behavior observed during the experiment: there may be seasonal differences in how users react to the treatment, perhaps; there may be external circumstances (like trends, or different economic conditions) that have changed and affect how users react to the treatment; or (especially if your product is growing and adding more and more users) the _users_ that use the product in December might be different than those that were part of the experiment in June. [↩](https://docs.geteppo.com/experiment-analysis/#user-content-fnref-uncertainty)
    

[Edit this page](https://github.com/Eppo-exp/eppo-docs/tree/main/docs/experiment-analysis/index.md)

[

Previous

Source Diagnostics

](https://docs.geteppo.com/data-management/source-diagnostics/)[

Next

Creating Experiment Analyses

](https://docs.geteppo.com/experiment-analysis/configuration/)

-   [Viewing multiple experiments](https://docs.geteppo.com/experiment-analysis/#viewing-multiple-experiments)
-   [Overview of an experiment's results](https://docs.geteppo.com/experiment-analysis/#overview-of-an-experiments-results)
    -   [Multivariate comparisons](https://docs.geteppo.com/experiment-analysis/#multivariate-comparisons)
    -   [Impact accounting](https://docs.geteppo.com/experiment-analysis/#impact-accounting)
    -   [Statistical details](https://docs.geteppo.com/experiment-analysis/#statistical-details)
-   [Segments and filters](https://docs.geteppo.com/experiment-analysis/#segments-and-filters)
    -   [Segments](https://docs.geteppo.com/experiment-analysis/#segments)
    -   [Single property filter](https://docs.geteppo.com/experiment-analysis/#single-property-filter)
-   [Explores](https://docs.geteppo.com/experiment-analysis/#explores)

Links

-   [Eppo](https://www.geteppo.com/)
-   [Blog](https://www.geteppo.com/blog)
-   [Eppo application](https://eppo.cloud/)
-   [Product updates](https://updates.eppo.cloud/)

Reference

-   [API reference](https://eppo.cloud/api/docs#/)
-   [Security](https://www.geteppo.com/security)

Copyright © 2026 Eppo, Inc.
