# Confidence intervals | The Eppo Docs

<https://docs.geteppo.com/statistics/confidence-intervals/>

[Skip to main content](https://docs.geteppo.com/statistics/confidence-intervals/#__docusaurus_skipToContent_fallback)

**Webinar: How Delivery Hero Uses Switchbacks to Drive Marketplace Innovation**   Watch the recording  [here →](https://www.youtube.com/watch?v=4sUDhv3AFrg)

[Login](https://eppo.cloud/)[Get a Demo](https://www.geteppo.com/get-access)

-   Getting Started
    
    -   [About Eppo](https://docs.geteppo.com/)
    -   [Analysis quickstart](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [SDK quickstart](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Contextual Bandit quickstart](https://docs.geteppo.com/bandit-quickstart/)
    -   [Switchback quickstart](https://docs.geteppo.com/switchback-quickstart/)
-   Core Concepts
    
    -   [Flag and Experiment Configuration](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Data Management](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Experiment Analysis](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Contextual Bandits](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
-   SDKs
    
    -   [Introduction](https://docs.geteppo.com/sdks/)
    -   [Architecture](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Concepts](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [SDK keys and environments](https://docs.geteppo.com/sdks/sdk-keys/)
    -   [Event Logging](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Client SDKs](https://docs.geteppo.com/sdks/client-sdks/)
        
        -   [JavaScript](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [Android](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [Dart & Flutter](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [iOS](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [React Native](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
    -   [Server SDKs](https://docs.geteppo.com/sdks/server-sdks/)
        
        -   [Node](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [.NET](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [PHP](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [Python](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [Java](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [Go](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [Rust](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [Ruby](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
        -   [Elixir](https://docs.geteppo.com/statistics/confidence-intervals/#)
            
    -   [Datadog integration](https://docs.geteppo.com/sdks/datadog/)
    -   [Best Practices](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Eppo Developer Tools - Chrome Extension](https://docs.geteppo.com/sdks/developer-tools-extension/)
    -   [Using Eppo SDK with pre-forking servers](https://docs.geteppo.com/sdks/preforking/)
-   Guides
    
    -   [Introduction](https://docs.geteppo.com/guides/)
    -   [Marketing Integrations](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Engineering Tutorials](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Metadata](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Advanced Experimentation Topics](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Migrations](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Debugging Metrics](https://docs.geteppo.com/guides/debugging-metrics/)
-   Reference
    
    -   [Statistics](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
        -   [Introduction](https://docs.geteppo.com/statistics/)
        -   [Confidence intervals](https://docs.geteppo.com/statistics/confidence-intervals/)
            
            -   [Analysis methods](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/)
            -   [Statistical nitty-gritty](https://docs.geteppo.com/statistics/confidence-intervals/statistical-nitty-gritty/)
        -   [Sample size calculator](https://docs.geteppo.com/statistics/sample-size-calculator/)
            
        -   [Global Lift](https://docs.geteppo.com/statistics/global-lift/)
        -   [CUPED++](https://docs.geteppo.com/statistics/cuped/)
        -   [Interaction Detection](https://docs.geteppo.com/statistics/interaction-detection/)
        -   [Multiple testing correction](https://docs.geteppo.com/statistics/multiple-testing/)
        -   [Sample Ratio Mismatch](https://docs.geteppo.com/statistics/sample-ratio-mismatch/)
    -   [Administration](https://docs.geteppo.com/statistics/confidence-intervals/#)
        
    -   [Architecture and Security](https://docs.geteppo.com/reference/architecture-and-security/)
    -   [REST API](https://docs.geteppo.com/reference/api/)
    -   [Webhooks](https://docs.geteppo.com/reference/webhook/)

-   
-   Reference
-   Statistics
-   Confidence intervals

# Confidence intervals

This page goes into more depth about the different methods Eppo provides for estimating lifts caused by a treatment and calculating confidence intervals around those lifts. In addition, we provide advice on how to choose between the different methods and the implications each method has for interpreting experiment results.

For information on how to find the lift estimates and confidence intervals in Eppo, and the essentials of using experiment results to make ship/no-ship decisions, see the main [Interpreting experiments](https://docs.geteppo.com/experiment-analysis/) page.

## Basics of estimating lift[​](https://docs.geteppo.com/statistics/confidence-intervals/#estimating-lift "Direct link to Basics of estimating lift")

In order to provide effect estimates consistently across all metric types (counts, rates, percentages, etc.), we use the relative lift between treatment and control (that is, Treatment−ControlControlControlTreatment−Control​), rather than their absolute difference. This means that the lift is always expressed as a _percentage of the metric value in the control group_. That is, a lift of 5% means the average metric value among subjects in the treatment variant is 5% higher than the average among subjects in the control variant.

note

If the estimate for Control is close to zero, that ratio becomes unreliable. We do not compute the relative lift when the Control is less than 10 standard deviations around zero. This corresponds to Kuethe's criterion for an accurate Normal approximation.[1](https://docs.geteppo.com/statistics/confidence-intervals/#user-content-fn-diaz-frances-rubio)

For a lot of metrics, this is pretty straightforward: if the average revenue per subject in the control variant was $10, a 5% lift would mean that the average revenue in the treatment variant was $10.50, a 50-cent increase. For _percentage_ and _ratio_ metrics, however, such as conversion rates and click through rates, there are some pitfalls to interpreting relative lifts. A 5% lift in retention rate (that is, share of users returning to the product after a period of time) from a control baseline of 20% would mean the treatment retention rate is **21%** (a 1-percentage-point increase), _not_ 25%. For ratio metrics, such as clicks per page impression, if the denominator (in this case, number of page impressions) goes _down_ by 10%, while the numerator (clicks) goes _up_ by 10%, the ratio goes _up_ not by 20% (that is, 10%−(−10%)10%−(−10%)), but by **22%** (that is, 100%+10%100%−10%\=110%90%100%−10%100%+10%​\=90%110%​).

The simplest way to calculate the lift is to get the difference in the average (per subject) metric value between each treatment variant and corresponding control variant, and then divide that by the control average to produce a _relative_ value. However, there are a number of methods we can use to improve on this naive calculation. For example, because we randomly allocate users to each variant, we can expect that there will be random differences between the users in each variant (perhaps a lot of really unengaged users were randomly assigned to the treatment variant, say); using [CUPED](https://docs.geteppo.com/statistics/cuped/) can make it easier to get a reliable estimate of the lift by mitigating these random fluctuations. Another example is [winsorization](https://en.wikipedia.org/wiki/Winsorizing), which reduces the impacts of extreme outliers.

caution

For any metric where you have elected to use [winsorization](https://docs.geteppo.com/data-management/metrics/simple-metric/) to handle outliers, the metric totals displayed in the tooltip when hovering over the lift are the _winsorized_ totals, not raw values.

The end result of these more sophisticated methods is that we show _estimated lifts_, rather than just the raw percentage change between variants, and therefore the numbers on our dashboards might not line up with back-of-the-envelope calculations.

info

If you use [Bayesian analysis](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/#bayesian-analysis), the estimated lift might be _quite_ different from the naive calculation, because the prior can influence the estimate a lot, particularly if the sample size is not large. For an accessible explanation with a worked example, see [Why Bayesian lift doesn't match (Treatment − Control) / Control](https://docs.geteppo.com/guides/advanced-experimentation/bayesian-lift-vs-naive/).

## Basics of calculating confidence intervals[​](https://docs.geteppo.com/statistics/confidence-intervals/#basics-of-calculating-confidence-intervals "Direct link to Basics of calculating confidence intervals")

The confidence intervals around the estimated lift show the range of lifts that could be plausibly supported by the data from the experiment; lifts outside that confidence interval are possible, but unlikely. (The exact meaning of "plausible" and "unlikely" depend on the particular [methodology](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/), of course.[2](https://docs.geteppo.com/statistics/confidence-intervals/#user-content-fn-ci-defn)) If the entire confidence interval is above zero, then it is unlikely for the true lift to be zero, or negative: the experiment data indicates that the treatment had a positive effect on that metric (and vice versa if the entire confidence interval is _below_ zero).

The distance between the lift estimate and the lower (or upper[3](https://docs.geteppo.com/statistics/confidence-intervals/#user-content-fn-symmetric)) bound of the confidence interval is called the _precision_; the width of the confidence interval is twice the precision. In order for the confidence interval to be entirely above or below zero, the precision needs to be less than the lift estimate itself. In other words, the confidence interval needs to be _narrow_ enough to exclude zero.

In general, the width of a particular confidence interval is determined by four factors:

1.  **How spread out the metric values are.**
    
    If different subjects tend to have similar metric values, then the range of plausible values will be smaller.[4](https://docs.geteppo.com/statistics/confidence-intervals/#user-content-fn-varreduc)
    
2.  **How many subjects are in the experiment (that is, the _sample size_).**
    
    Even if a metric tends to have values within a fairly narrow range, if we have only observed a few subjects in the experiment, it's possible that we (by unlucky chance) happened to observe outliers with unusually extreme (high or low) metric values. The more subjects we can observe a given metric for, the more likely it is that the sample of subjects that are in the experiment will be representative of the population as a whole (and therefore the more confident we can be that the true lift is close to the lift from our sample).
    
3.  **The [confidence level](https://docs.geteppo.com/experiment-analysis/configuration/analysis-plans/#confidence-level) specified for the experiment (which is 95% by default), which dictates _how_ confident we want to be.**
    
    The confidence level represents how often we want the true lift to be inside the confidence interval, and thus the confidence interval needs to be wide enough to ensure that is true: the _higher_ the confidence **level**, the _wider_ the confidence **interval**.
    
4.  **The [analysis method](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/) being used**
    
    Although the confidence level indicates how confident we want to be in our lift estimate, the analysis method dictates _under what circumstances_ we can have that level of confidence. For example, fixed-sample analysis only guarantees a given confidence level if you make a decision based on a single examination of the experiment results, while sequential analysis guarantees a confidence level no matter how many times you look at the results (there are of course other requirements for those guarantees to hold). In order to achieve the stronger guarantees, however, the sequential method will produce wider confidence intervals for the same data than the fixed-sample method.
    

## Footnotes[​](https://docs.geteppo.com/statistics/confidence-intervals/#footnote-label "Direct link to Footnotes")

1.  See [Díaz-Francés and Rubio (2004), "On the Existence of a Normal Approximation to the Distribution of the Ratio of Two Independent Normal Random Variables."](https://www.researchgate.net/profile/F-Rubio/publication/257406150_On_the_existence_of_a_normal_approximation_to_the_distribution_of_the_ratio_of_two_independent_normal_random_variables/links/53d7a18a0cf2e38c632ddabc/On-the-existence-of-a-normal-approximation-to-the-distribution-of-the-ratio-of-two-independent-normal-random-variables.pdf) for more details on the validity of the normal approximation. [↩](https://docs.geteppo.com/statistics/confidence-intervals/#user-content-fnref-diaz-frances-rubio)
    
2.  Indeed, the very term "confidence interval" is only used in the [frequentist](https://en.wikipedia.org/wiki/Frequentist_inference) framework, while [Bayesian](https://en.wikipedia.org/wiki/Bayesian_inference) methods use "credible interval" to describe a similar (though distinct!) concept. For simplicity, we'll use "confidence interval" throughout, and discuss the distinction with Bayesian credible intervals [here](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/#bayesian-analysis). [↩](https://docs.geteppo.com/statistics/confidence-intervals/#user-content-fnref-ci-defn)
    
3.  We use symmetric confidence intervals, so the upper and lower bounds are the same distance from the lift estimate. [↩](https://docs.geteppo.com/statistics/confidence-intervals/#user-content-fnref-symmetric)
    
4.  In technical terms, this is called the _variance_, and it's one of the reasons we put a lot of emphasis on _variance reduction_ through methods like CUPED and winsorization: reducing the variance of the metric (by controlling for, and therefore removing, random variation) makes the confidence intervals narrower, which makes it easier to tell when a treatment has an effect. [↩](https://docs.geteppo.com/statistics/confidence-intervals/#user-content-fnref-varreduc)
    

[Edit this page](https://github.com/Eppo-exp/eppo-docs/tree/main/docs/statistics/confidence-intervals/index.md)

[

Previous

Introduction

](https://docs.geteppo.com/statistics/)[

Next

Analysis methods

](https://docs.geteppo.com/statistics/confidence-intervals/analysis-methods/)

-   [Basics of estimating lift](https://docs.geteppo.com/statistics/confidence-intervals/#estimating-lift)
-   [Basics of calculating confidence intervals](https://docs.geteppo.com/statistics/confidence-intervals/#basics-of-calculating-confidence-intervals)

Links

-   [Eppo](https://www.geteppo.com/)
-   [Blog](https://www.geteppo.com/blog)
-   [Eppo application](https://eppo.cloud/)
-   [Product updates](https://updates.eppo.cloud/)

Reference

-   [API reference](https://eppo.cloud/api/docs#/)
-   [Security](https://www.geteppo.com/security)

Copyright © 2026 Eppo, Inc.
