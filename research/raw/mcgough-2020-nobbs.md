# Nowcasting by Bayesian Smoothing: A flexible, generalizable model for real-time epidemic tracking | PLOS Computational Biology

<https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735>

[Skip to main content](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#main-content)

Advertisement

-   [plos.org](https://plos.org/)
-   [Create account](https://community.plos.org/registration/new)
-   [Sign in](https://journals.plos.org/user/secure/login?page=%2Fploscompbiol%2Farticle%3Fid%3D10.1371%2Fjournal.pcbi.1007735)

-   -   
    -   
    -   
    
-   
-   [advanced search](https://journals.plos.org/ploscompbiol/search)
    

-   110
    
    [Save](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735#savedHeader)
    
    [Total Mendeley and Citeulike bookmarks.](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735#savedHeader)
    
-   157
    
    [Citation](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735#citedHeader)
    
    [Paper's citation count computed by Dimensions.](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735#citedHeader)
    
-   15,269
    
    [View](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735#viewedHeader)
    
    [PLOS views and downloads.](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735#viewedHeader)
    
-   53
    
    [Share](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735#discussedHeader)
    
    [Sum of Facebook, Twitter, Reddit and Wikipedia activity.](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735#discussedHeader)
    

Open Access

Peer-reviewed

Research Article

# Nowcasting by Bayesian Smoothing: A flexible, generalizable model for real-time epidemic tracking

-   Sarah F. McGough ,
-   Michael A. Johansson,
-   Marc Lipsitch ,
-   Nicolas A. Menzies

# Nowcasting by Bayesian Smoothing: A flexible, generalizable model for real-time epidemic tracking

-   Sarah F. McGough, 
-   Michael A. Johansson, 
-   Marc Lipsitch, 
-   Nicolas A. Menzies

x

-   Published: April 6, 2020
-   [https://doi.org/10.1371/journal.pcbi.1007735](https://doi.org/10.1371/journal.pcbi.1007735)

-   [Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735)
-   [Authors](https://journals.plos.org/ploscompbiol/article/authors?id=10.1371/journal.pcbi.1007735)
-   [Metrics](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1007735)
-   [Comments](https://journals.plos.org/ploscompbiol/article/comments?id=10.1371/journal.pcbi.1007735)
-   [Media Coverage](http://plos.altmetric.com/details/doi/10.1371/journal.pcbi.1007735)

-   [Abstract](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#abstract0)
-   [Author summary](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#abstract1)
-   [Introduction](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#sec001)
-   [Results](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#sec002)
-   [Discussion](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#sec008)
-   [Materials and methods](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#sec009)
-   [Supporting information](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#sec017)
-   [References](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#references)

-   [Reader Comments](https://journals.plos.org/ploscompbiol/article/comments?id=10.1371/journal.pcbi.1007735)
-   [Figures](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#)

Accessible Data

[

See the data

](https://github.com/sarahhbellum/NobBS/tree/master/data)

This article includes the Accessible Data icon, an experimental feature to encourage data sharing and reuse. [Find out how research articles qualify for this feature.](https://theplosblog.plos.org/2023/07/accessible-data/)

## Abstract

Achieving accurate, real-time estimates of disease activity is challenged by delays in case reporting. “Nowcast” approaches attempt to estimate the complete case counts for a given reporting date, using a time series of case reports that is known to be incomplete due to reporting delays. Modeling the reporting delay distribution is a common feature of nowcast approaches. However, many nowcast approaches ignore a crucial feature of infectious disease transmission—that future cases are intrinsically linked to past reported cases—and are optimized to one or two applications, which may limit generalizability. Here, we present a Bayesian approach, NobBS (Nowcasting by Bayesian Smoothing) capable of producing smooth and accurate nowcasts in multiple disease settings. We test NobBS on dengue in Puerto Rico and influenza-like illness (ILI) in the United States to examine performance and robustness across settings exhibiting a range of common reporting delay characteristics (from stable to time-varying), and compare this approach with a published nowcasting software package while investigating the features of each approach that contribute to good or poor performance. We show that introducing a temporal relationship between cases considerably improves performance when the reporting delay distribution is time-varying, and we identify trade-offs in the role of moving windows to accurately capture changes in the delay. We present software implementing this new approach (R package “NobBS”) for widespread application and provide practical guidance on implementation.

## Author summary

Achieving accurate, real-time estimates of disease activity is challenged by delays in case reporting. However, approaches that seek to estimate cases in spite of reporting delays often do not consider the temporal relationship between cases during an outbreak, nor do they identify characteristics of robust approaches that generalize to a wide range of surveillance contexts with very different reporting delays. Here, we present a smooth Bayesian nowcasting approach that produces accurate estimates that capture the time evolution of the epidemic curve and outperform a previously developed approach. We assess the performance for two diseases and show that relating cases between sequential time points contributes to NobBS’s performance and robustness across surveillance settings.

## Figures

**Citation:** McGough SF, Johansson MA, Lipsitch M, Menzies NA (2020) Nowcasting by Bayesian Smoothing: A flexible, generalizable model for real-time epidemic tracking. PLoS Comput Biol 16(4): e1007735. https://doi.org/10.1371/journal.pcbi.1007735

**Editor:** Bryan Lewis, University of Virginia, UNITED STATES

**Received:** June 24, 2019; **Accepted:** February 17, 2020; **Published:** April 6, 2020

This is an open access article, free of all copyright, and may be freely reproduced, distributed, transmitted, modified, built upon, or otherwise used by anyone for any lawful purpose. The work is made available under the [Creative Commons CC0](https://creativecommons.org/publicdomain/zero/1.0/) public domain dedication.

**Data Availability:** ILI surveillance data are openly-available and cited within the manuscript (Materials & Methods). Dengue surveillance data are available at [https://github.com/sarahhbellum/NobBS/tree/master/data](https://github.com/sarahhbellum/NobBS/tree/master/data).

**Funding:** The project described was supported by Grant Number U54GM088558 from the National Institute Of General Medical Sciences and Grant Number 5T32AI007535 “Epidemiology of Infectious Diseases” from the National Research Service Award ([https://www.nigms.nih.gov/](https://www.nigms.nih.gov/)). The content is solely the responsibility of the authors and does not necessarily represent the official views of the National Institute Of General Medical Sciences, the National Institutes of Health, or the Centers for Disease Control and Prevention. The funders had no role in study design, data collection and analysis, decision to publish, or preparation of the manuscript.

**Competing interests:** The authors have declared that no competing interests exist.

## Introduction

Effective public health action relies on surveillance that is timely and accurate, especially in disease outbreaks\[[1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref001),[2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref002)\]. Specifically, surveillance provides the information required to assess risks, prioritize and allocate resources to public health threats, deploy and discontinue interventions to interrupt transmission, and monitor the impact of those interventions. Ideally, disease surveillance systems should closely track the often fast-changing circumstances of outbreaks, distinguishing true changes in the dynamics from artifacts of reporting.

Despite the importance of timely surveillance data, substantial challenges exist to collect and report case information in real time. Multiple features of the disease and surveillance system contribute to reporting delays, including: delays in symptoms onset after infection; delays in medical care-seeking after onset; delays in providers obtaining and reporting diagnostic information; level of awareness of disease activity influencing care-seeking and reporting; and system-level processing delays, a result of complex and multi-tiered disease reporting and communication systems interacting at multiple administrative levels\[[3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref003)\]. Reporting delays can be further exacerbated in resource-constrained settings. As a consequence, surveillance data are typically not complete until weeks or months after infections have actually occurred, providing an incomplete picture of current disease activity.

Nowcasting, or “predicting the present,” is an approach to mitigate the impact of reporting delays. With origins in the insurance claims and actuarial literature\[[4](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref004),[5](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref005)\], nowcast models aim to estimate the number of occurred-but-not-yet-reported events (e.g. insurance claims, disease cases) at any given time based on an incomplete set of reports. In public health settings, nowcasting approaches have been explored for AIDS in the 1980s and 1990s\[[6](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref006)–[8](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref008)\] as a consequence of the long incubation period from HIV infection until development of AIDS. More recently, nowcasting has been applied to infectious disease outbreaks such as foodborne illness outbreaks\[[9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref009),[10](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref010)\]. These studies draw principally on survival analysis and actuarial techniques to model the reporting delay and draw inferences based on historical patterns. A majority of studies have strictly focused on modeling the reporting delay distribution—a legacy of the actuarial techniques giving rise to many of these approaches—and generally neglect a key feature of outbreaks: that future cases are intrinsically linked to past reported cases, a fact that creates potentially strong autocorrelation in the true number of cases over short time intervals. In other words, the infectious disease transmission process provides an additional signal of the number of cases to be expected in the near future that has not been included in common methods such as the reverse-time hazard model\[[11](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref011),[12](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref012)\] and the chain ladder method\[[13](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref013)\], which model the probability of delays in case reporting and consider the number of cases at successive time points as independent. However, proposals to extend the chain ladder approach to state-space models that account for temporal relationships in reporting have existed in the literature since the development of these techniques\[[13](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref013)–[15](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref015)\] and have been applied in at least one infectious disease context\[[16](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref016)\].

The development of nowcast models is promising for disease surveillance, but equally important is the need to identify and scrutinize the mechanisms by which these approaches are successful in accurately predicting true case reports and, on the other hand, underperform. For example, it is critical to demonstrate performance in a diversity of settings as a majority of disease nowcast models to date have largely focused on performance in specific applications, but not the common challenges that exist across many different diseases. To wit, in this investigation we find that nowcasting is especially challenging when the proportion of cases reported the week they occur (delay 0) is low and reporting delays are highly variable; we know of no investigations that specifically identify models that perform well in these commonly occurring circumstances. As a result, the characteristics of robust and broadly-applicable models are difficult to identify. Additionally, several previous models have largely focused on providing point estimates of the number of cases. Point estimates may be helpful, but quantifying the uncertainty in those estimates is even more important in the context of infectious disease outbreaks because uncertainty is intrinsic, and accounting for plausible outcomes apart from the point prediction is critical.

Here, we implement a relatively disease-agnostic nowcast method in multiple real-world and simulated disease reporting settings, and unpack the features of model structure and implementation that contribute to its performance. We introduce Nowcasting by Bayesian Smoothing (NobBS), a simple and flexible generalized Bayesian model and associated software package for nowcasting infectious diseases. We demonstrate the robustness of this approach in two very different disease surveillance contexts and identify the conditions that favor its application, especially when the reporting delay distribution is time-varying. Specifically, NobBS allows for both uncertainty in the delay distribution and the time evolution of the epidemic curve, producing smooth, time-correlated estimates of cases. We demonstrate that NobBS performs well for weekly nowcasts of (1) dengue cases in Puerto Rico and (2) influenza-like illness (ILI) cases in the United States, requiring no disease-specific parameterization despite the two pathogens being very different (vector-borne vs. directly transmitted) and exhibiting substantially different reporting delays. Lastly, we test NobBS against a previously developed Bayesian nowcast method for surveillance data\[[9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref009)\] and find that NobBS outperforms this established method for both diseases and multiple time periods. In particular, we show that while point estimates of the models are similar when time-to-report distributions are relatively fixed over time, NobBS improves the estimation of uncertainty and accommodates temporal variation in delay probabilities. Our investigation aims to provide deeper insights into these different nowcast approaches and describe the practical implementation of NobBS. We present an R package, “NobBS,” as a tool to complement both routine public health surveillance as well as forecasting efforts.

## Results

We developed a Bayesian approach to nowcast total case numbers using incomplete, time-stamped reported case data based on an estimated delay distribution, intrinsic autocorrelation from the transmission process, and historical case data. Generally, the approach learns from historical information on cases reported at multiple delays (e.g. no delay, 1-week delay, 2-week delay, etc.) from the week of case onset to estimate the reporting delay probability at each delay and the relationship between case counts from week-to-week, and uses this relationship to predict the number of not-yet-reported cases in the present using a log-linear model for the number of cases at each week _t_ and each delay _d_. We tested this approach, NobBS, using two different infectious disease surveillance data sources: dengue surveillance in Puerto Rico, and national notifications of influenza-like illness (ILI) in the United States. Using all of the available data on case reporting delays up to the point of prediction, weekly dengue nowcasts were estimated for the time period December 23, 1991 through November 29, 2010 (989 weeks), and weekly ILI nowcasts were produced over the period June 30, 2014 through September 25, 2017 (170 weeks). For comparison, we generated weekly nowcasts over the same periods using an existing Bayesian approach by Höhle and der Heiden (2014), here referred to as the HH approach\[[9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref009)\]. Briefly, this approach frames the nowcast problem in the context of survival modeling (specifically, a reverse-time discrete hazard model) and estimates the delay distribution to obtain the total number of cases each week at each time _t_. We chose this approach as a comparator because it is the most established and implementable approach, with an existing R package and the most cited in disease surveillance contexts\[[9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref009)\]. To leverage a large amount of historical data to fit the nowcast model while also having a large window over which to assess nowcasts, we used a 104-week (approximately 2-y) moving window dengue and a 27-week (approximately 6-mo) moving window for ILI and tested the sensitivity to window size to inform model implementation. Our primary outcome metric to assess nowcast performance was the logarithmic score, a proper score that evaluates the probability assigned to the observed outcome rather than error associated with a point prediction. For purposes of discussion, we reported the exponentiated form of the mean logarithmic score (the geometric mean of the assigned probabilities) to provide a metric on the scale of 0 (no certainty of the outcome) to 1 (complete certainty of the outcome). In addition, we estimated other metrics describing the performance of point estimates (mean absolute error (MAE), root mean square error (RMSE), and relative root mean square error (rRMSE)) and the 95% prediction interval (PI) coverage, and of these, focus on comparing the rRMSE and 95% PI coverage across approaches.

### Performance in forecasting weekly dengue and influenza incidence

Figs [1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g001) and [2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g002) show weekly dengue and ILI nowcasts for NobBS and the HH approach over multiple seasons for both diseases. [Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t001) summarizes the point and probability-based accuracy metrics for each, where higher accuracy is indicated by higher average scores, lower MAE, RMSE, and rRMSE, and lower distance from 0.95 for the 95% PI coverage. Because the NobBS model accounts for both under-reporting and the autocorrelated progression of transmission across successive weeks, it makes predictions even in weeks when there are no cases reported for the week. Conversely, the HH model does not make nowcasts for weeks in which there are no initial case reports (common in the dengue Puerto Rico data), hence the nowcasts in Figs [1C](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g001) and [2C](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g002) appear as discontinuous lines. To compare models despite these differences, we report accuracy metrics between NobBS and the HH approach for both (1) the full time series of the data and (2) weeks when at least one case was reported in the first week, i.e. the subset of weeks for which both models could make predictions ([Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t001)). We also computed error metrics for the HH model for the full time series by assigning point estimates of 0 cases for nowcasts in weeks without predictions.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1007735.g001)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1007735.g001)

Fig 1. Weekly dengue fever nowcasts for December 23, 1991 through November 29, 2010 using a 2-year moving window.

(A) Weekly NobBS nowcasts along with (B) point estimate and uncertainty accuracy, as measured by the score and the prediction error, are compared to (C) weekly nowcasts by the HH approach with (D) corresponding scores and prediction errors. For nowcasting, the number of newly-reported cases each week (blue line) are the only data available in real-time for that week, and help inform the estimate of the total number of cases that will be eventually reported (red line), shown with 95% prediction intervals (pink bands). The true number of cases eventually reported (black line) is known only in hindsight and is the nowcast target. Historical information on reporting is available within a 104-week moving window (grey shade) and used to make nowcasts. The score (brown line) and the difference between the true and mean estimated number of cases (grey line) are shown as a function of time.

[https://doi.org/10.1371/journal.pcbi.1007735.g001](https://doi.org/10.1371/journal.pcbi.1007735.g001)

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1007735.g002)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1007735.g002)

Fig 2. Weekly ILI nowcasts for June 30, 2014 through September 25, 2017 using a 6-month moving window.

(A) Weekly NobBS nowcasts along with (B) point estimate and uncertainty accuracy, as measured by the score and the prediction error, are compared to (C) weekly nowcasts by the HH approach with (D) corresponding scores and prediction errors. For nowcasting, the number of newly-reported cases each week (blue line) are the only data available in real-time for that week, and help inform the estimate of the total number of cases that will be eventually reported (red line), shown with 95% prediction intervals (pink bands). For the HH approach, the 95% prediction intervals are very narrow and are thus difficult to see. The true number of cases eventually reported (black line) is known only in hindsight and is the nowcast target. Historical information on reporting is available within a 27-week moving window (grey shade) and used to make nowcasts. The score (brown line) and the difference between the true and mean estimated number of cases (grey line) are shown as a function of time.

[https://doi.org/10.1371/journal.pcbi.1007735.g002](https://doi.org/10.1371/journal.pcbi.1007735.g002)

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1007735.t001)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1007735.t001)

Table 1. Performance measures for each nowcast approach by disease (mean % reported with no delay, computed across the complete time period\* of reports).

[https://doi.org/10.1371/journal.pcbi.1007735.t001](https://doi.org/10.1371/journal.pcbi.1007735.t001)

The HH approach made predictions in only 55% of weeks in the dengue time series ([Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t001)). In this subset of weeks, the NobBS approach achieved relatively smooth and accurate tracking of the dengue time series (rRMSE = 0.464, average score = 0.274) despite low proportions of cases reported on the week of onset ([Fig 1A and 1B](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g001)). The 95% PI coverage was 0.85, indicating that the 95% PI included the true number of cases for 85% of the nowcasts. In comparison, the HH approach produced substantially less accurate point estimates and slightly broader uncertainty intervals (rRMSE = 1.24, average score = 0.161, 95% PI coverage = 0.90) with greater fluctuation in nowcasts from week-to-week ([Fig 1C and 1D](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g001)). On average, the HH approach led to more biased estimates and systematically overpredicted the number of cases for both ILI and dengue compared to NobBS. Because many weeks in the dengue data were low incidence, assigning a prediction of 0 to the HH approach’s missing nowcasts improved its rRMSE to 1.14 in the full time series compared to 1.24 for the subset over which nowcasts were generated from the model, though NobBS still surpassed the HH model’s accuracy on this and all other metrics ([Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t001)).

Nowcast point estimates tracked the ILI time series well for both approaches, though point estimates had greater error by all measures for the NobBS approach (NobBS rRMSE = 0.074 vs. HH rRMSE = 0.062; [Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t001)). However, the NobBS approach produced considerably wider prediction intervals (Figs [1C](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g001) and [2C](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g002)) resulting in both higher scores (NobBS average score = 0.218 vs. HH average score = 0.017) and 100% coverage by the 95% prediction intervals compared to 0% coverage for the HH ([Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t001)). We observed that at multiple deciles of the prediction interval, the interval provided conservative coverage, but that the calibration of narrower intervals was better ([S1 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s007)).

To assess the degree of autocorrelation and related smoothness in the NobBS predictions, we calculated the 1-week lagged autocorrelation of predictions (ρa) and compared this to the 1-week lagged autocorrelation of cases (ρc). In addition, we computed metrics reflecting the accuracy of the approaches in capturing the _change_ in cases from week-to-week: the mean absolute error of the change (MAEΔ) and the RMSE of the change (RMSEΔ) ([Table 2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t002)). The magnitude of change was much larger for the ILI data than dengue data, with average absolute value change of 1,312.6 cases/week versus 9.8 cases/week, yet both showed high autocorrelation (ρc = 0.958 for dengue and ρc = 0.972 for ILI). Comparing the full time series, the nowcasts produced by NobBS exhibited high autocorrelation for both diseases (ρa = 0.876 for dengue, 0.973 for ILI) while the HH approach yielded lower autocorrelation for dengue nowcasts, comparatively (ρa = 0.631 for dengue, 0.970 for ILI). For dengue, over the weeks in which at least 1 case was initially reported, the NobBS approach achieved both lower mean absolute difference between predicted and observed changes in cases (NobBS MAEΔ = 23 vs. HH MAEΔ = 50) and lower RMSE of the change (NobBS RMSEΔ = 35.8 vs. HH RMSEΔ = 64.6). In addition, NobBS outperformed the HH approach over the full time series of dengue cases ([Table 2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t002)). For ILI, however, the metrics for the weekly change were similar for the two approaches ([Table 2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t002)).

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1007735.t002)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1007735.t002)

Table 2. Performance measures for estimates of the change in disease incidence from the previous week.

[https://doi.org/10.1371/journal.pcbi.1007735.t002](https://doi.org/10.1371/journal.pcbi.1007735.t002)

### Reporting delays impact nowcast performance

The delay distributions between the reporting systems are strikingly different (Figs [1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g001) and [2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g002), [S2 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s008)). In the case of the dengue surveillance system, which includes specimen collection and laboratory testing, only approximately 4% of cases were processed during the week of onset, on average. In contrast, the U.S. Outpatient Influenza-like Illness (ILI) Surveillance Network (ILINet) captures only syndromic data reported electronically, with over 80% of ILI cases reported, on average, the same week they present (i.e. with no delay). Overall, we observed that the accuracy of nowcast point estimates (rRMSE) was higher for the ILI data compared to dengue, which may be related to the high proportion of cases reported with 0-weeks delay in these data. Large weekly absolute changes in the number of initial case reports also appeared to be related to increased error, particularly for dengue, which had high fluctuations in the number of initial reports over time ([S1 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s002), [S3 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s009)). Note that because of the difference in predictive distribution bin widths based on the number of cases that accrue for influenza vs. dengue (_Materials & Methods_), average scores are not comparable across diseases.

### NobBS improves nowcasting with varying reporting delays

Dengue and ILI also exhibit differences in the _trends_ of reporting delay probabilities _over time_, and we observed strikingly different comparative performance of the two nowcast approaches in these disease settings, namely that the HH approach performed comparably to NobBS for ILI but not for dengue. In the dengue data, we observe a noisier, more time-varying probability of reporting for cases, with more extreme fluctuations in the proportion of initial reports compared to ILI cases, which show more constant (tighter ranges of) reporting probabilities from week-to-week ([S4 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s010)). Independent of the initial proportion of cases reported (high vs. low), we hypothesized that these trends (relatively constant vs. time-varying) are particularly impactful on the performance of the nowcast, and that relatively constant reporting probabilities, as seen in the ILI data, may be linked to the higher accuracy of these predictions.

To test the robustness of the model, we simulated ILI data using the final counts from the true dataset, but imposing a time-varying delay distribution; specifically, with faster initial reporting during weeks of high incidence to reflect heightened awareness of an outbreak and increased urgency of reporting (described in _Materials and Methods_). Using these simulated data, we found that NobBS was relatively robust to changes in reporting delays ([S5 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s011), [S2 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s003)). In the context of stable reporting delays (original ILI data), NobBS performed comparably to the HH model ([Fig 2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g002), [Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t001)). However, in the presence of simulated time-varying reporting delays, NobBS outperformed the HH in terms of confidence (NobBS average score = 0.06 vs. HH average score ≈ 0), point estimates (NobBS rRMSE = 0.302 vs. HH rRMSE = 0.621), and accuracy of the predicted change ([S3 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s004)). Such variations in the delay distribution are a reality in many epidemics\[[17](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref017)\].

Time-varying delays may be explicitly modeled in the HH approach, by pre-specifying the temporal change-points at which the delay distribution is expected to change–information that is rarely known in real-time. We therefore compared NobBS to the HH approach without explicitly modeling a time-varying delay distribution in either method. In the case of ILI and dengue data, we had no reason to believe or anticipate a systematic change in reporting over the time period covered.

### Performance by year

The performance of both approaches in nowcasting ILI was relatively consistent by year across accuracy measures, but there were fluctuations in the year-to-year performance of dengue nowcasts ([Table 3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t003)). Average scores of the dengue nowcasts (from both approaches) tended to be high in years that experienced a very low number of dengue cases (e.g. 2000, 2002, 2004, 2006), and therefore the performance of both approaches declined during higher incidence years. For dengue, the NobBS model was particularly effective at identifying periods of low incidence, with high probabilities assigned to the lowest outcome bin (0–25 cases, details in _Materials and Methods_) when the number of cases eventually reported was low ([S6 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s012)). On the other hand, during periods of high dengue activity, lower probabilities were assigned to the correct bin, reflecting greater uncertainty. Looking specifically at higher incidence time periods (Epidemiologic Weeks 40 through 20 of the following year for ILI, and all weeks in which the number of cases exceeded 50 for dengue), both nowcast approaches were less accurate and more uncertain than during other time periods ([S4 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s005)). Overall, NobBS outperformed the benchmark approach on all performance measures for each year and most higher incidence time periods ([Table 3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t003); [S4 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s005)).

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1007735.t003)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1007735.t003)

Table 3. Annual performance measures for each nowcast model, by disease.

All predicted weeks for each model are compared.

[https://doi.org/10.1371/journal.pcbi.1007735.t003](https://doi.org/10.1371/journal.pcbi.1007735.t003)

Both approaches had their lowest accuracy on three high incidence dengue seasons: 1994, 2007, and 2010 ([Table 3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t003); [S4 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s005); [Fig 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g001)). The average annual scores for these years range between 0.041 and 0.170 across the NobBS and benchmark approaches, and between 0.000 and 0.081 for the high-incidence time periods specifically ([Table 3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t003); [S4 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s005)), falling clearly below the rest of the years and higher incidence time periods in performance. These scores not only reflect unusually poor point estimate predictions as judged by rRMSE, but also the finding that the predictive distribution for weeks in these years for both approaches rarely included the true value of interest (a consequence of dramatic over- or underestimates during times of high disease activity).

### Moving window sizes

We initially used moving windows of 104 weeks for dengue (a longer time series) and 27 weeks for ILI (a shorter time series) to leverage a large number of historical training weeks to train nowcast estimates. Moving windows allow for stable estimation of the recent delay distribution as information from very old and potentially less relevant weeks are forgotten. The size of the moving window reflects how quickly and smoothly changes in the data should be realized by the model: longer moving windows tend to produce smoother estimates, but the model may be less sensitive to abrupt changes in the data (e.g. changes in how quickly cases are reported during an outbreak) or shorter-interval secular trends, e.g. seasonality.

While we chose long moving windows for both diseases to capitalize on data availability, these considerations may affect the choice of moving window size and nowcast performance, depending on the data. In light of this, we experimented with moving windows of different lengths on the dengue data to assess the impact on nowcast performance. We tested moving windows of 5, 12, and 27 weeks (approx. 6 months) on the dengue data and, for each moving window, generated a set of nowcasts for December 1991-November 2010 in order to compare performance measures across all moving window sizes (5, 12, 27, and 104 weeks). A 5-week moving window produced substantially lower accuracy nowcasts (rRMSE = 7.381) with several steep case overestimates in 2007–08 and 2010 ([S7A Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s013)). However, accuracy metrics for moving windows of 12 weeks or longer were similar to those using the full 104 week window (range in rRMSE: 0.6–0.655; average score: 0.35–0.37) ([S5 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s006); [S7 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s013)). While shorter moving windows often produced more accurate estimates of the reporting delay probability ([S8A Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s014)), the estimated variance of the random walk process varied dramatically from week-to-week ([S8B Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s014)) resulting in more dramatic overestimates at certain periods of extreme time-varying delays, suggesting a trade-off between delay estimation accuracy and more stable estimates of weekly cases.

## Discussion

We introduce an approach for Bayesian nowcasting, NobBS, and demonstrate its application in two disease contexts with different reporting systems, investigating the conditions that contribute to successful implementation. We show that NobBS outperforms an existing method in terms of point estimate (reduced RMSE, lower bias) and probabilistic (higher logarithmic score) predictive performance. In particular, NobBS performs well even when the delays in case reporting change over time. We further demonstrate an important trade-off related to moving window sizes for delay distribution estimates; short windows improve the real-time characterization of the delay distribution but are susceptible to over-estimating that variability, potentially decreasing nowcast accuracy. Lacking any disease-specific parameterization, and relying only on historical trends of case reporting as input, this approach can be immediately adapted in a variety of disease settings.

Across diseases, NobBS outperformed the HH approach on accuracy of uncertainty estimates, and produced comparable or better point estimates. For the subset of weeks in which both models could produce forecasts (weeks with at least one case initially reported), point estimates for NobBS were substantially more accurate than the HH model for dengue cases (rRMSE improved by 300%) and slightly less accurate for ILI cases (rRMSE decreased by 19%). However, analysis of the probability distributions of the nowcasts revealed a much more substantial difference; the average score for NobBS was approximately twice as high for dengue and more than 10 times as high for ILI cases ([Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-t001)). This indicates that the NobBS approach assigned much higher probability to the actual outcome, even though point accuracy was somewhat lower for the ILI cases.

While utilizing a similar modeling structure for case reporting delays as the HH model\[[9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref009)\], NobBS introduces a simple dependency between case counts over time; that is, changes in case counts between weeks are assumed to be related via a first-order random walk process on the logarithmic scale. This feature is critical in the context of infectious disease transmission, where the number of true infections in a given week mechanistically depends in part on the number of true infections in previous weeks due to the infectious process, whether the pathogen is transmitted directly or by vectors\[[18](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref018)\]. Hence, variations of autoregressive models are common in disease forecasting\[[19](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref019),[20](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref020)\]. Indeed, a recently published study describes a similar approach to NobBS \[[16](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref016)\], proposing the same model structure (an adaptation of the historic chain-ladder approach) and similar priors (namely, a first-order random walk on the underlying distribution of cases), finding that this approach performed well for two diseases. Two key differences in model structure are that NobBS parameterizes the delay distribution as a Dirichlet as opposed to a random walk, to model the underlying delay distribution as a probability vector, and omits a model intercept. We also aimed to identify and deconstruct the features that contribute to good performance, comparing to a benchmark approach and testing the robustness of NobBS to multiple delay distributions, different moving window sizes, and accuracy metrics. Our results suggest that this approach is robust across disease settings, and offers deeper insights into why: importantly, the temporal dependency between cases in the evolution of an outbreak.

As a result, when reporting delays are time-varying, as is often the case in epidemics\[[17](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref017)\], we show that the NobBS approach is less accurate compared to its performance in a stable delay distribution, but still shows improvement over the HH approach likely because the NobBS approach is informed by the number of cases experienced in previous weeks, not just the delay distribution, making it more robust to larger fluctuations. As mentioned, the HH approach software includes the option to model a time-varying delay explicitly in the nowcast approach, but requires specifying the time at which the delay distribution is expected to change (the change-point), which is generally not known in real-time. In addition, the authors of the HH approach introduce a feature to model the epidemic curve smoothly, however the implementation is bundled with the change-point model, and is therefore not possible to implement without the change-point component. In the case of the ILI and dengue data, there was no reason to believe reporting changed systematically at any point during the years covered by the data used here, and [S4 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s010) illustrates that a change-point model would likely be inappropriate given the irregular fluctuations in the delay probabilities over time. However, both features may improve performance of the HH model depending on the context, in particular when facing time-varying delays.

We also found that the accuracy of predictions is related at least in part to the number of cases reported to the surveillance system in week 0. When a larger proportion of cases were reported with no delay, as was the case for ILI compared to dengue, the point estimate accuracy was higher. This is not surprising, as a large fraction of true cases reported initially leaves fewer cases left to predict.

Further, we observed greater volatility in the nowcasts when the initial number of cases reported increases suddenly from low values. Two weeks in the dengue time series highlight this: August 3, 1998 and August 16, 2010. In those weeks, the number of cases initially increased by 16 and 17, respectively, from the previous week after 10 week with an average absolute change of 2.6 and 1.8 cases, respectively. Because this increase is an outlier in the distribution of reporting delays, in particular for delay _d_ = 0, the model substantially overestimated the true number of cases before correcting the following week. We observed that shorter moving windows either exacerbated this issue (e.g. in 2010) or produced a similar overestimate (e.g. in 1998) ([S7 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s013)), which appears to be a consequence of the volatility in estimating the variance of the random walk process, despite more accurate estimation of the reporting delay probability ([S8 Fig](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s014)). While the smooth, autocorrelated relationship fit in the NobBS model helps reduce the effect of week-to-week variability in early reporting, it remains a challenge. Users should keep in mind these trade-offs when seeking to apply NobBS to their data.

While NobBS mitigates the effects of a time-varying delay distribution on case estimation, i.e. that the history of cases is leveraged to anchor case estimates to recent values, it does not explicitly model temporal changes in that delay; in other words, the estimated probability of a case occurring with delay = _d_ is assumed to apply to all reporting weeks in the moving window. Shorter moving windows can improve estimation of the delay in the presence of changes, but explicitly estimating changes in that distribution may be explored for additional robustness in the presence of systemic changes in reporting. For example, authors in\[[21](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref021)\] propose a smooth estimate of the time-varying reporting delay distribution using p-spline smoothing. Specifying a time-specific change has also been proposed as mentioned previously \[[9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref009)\], but empirical identification of a change point in real-time may be challenging or impossible in the context of nowcasting. The challenge that remains in all described approaches is the ability of the model to pick up on changes in the delay distribution that occur quickly, in other words that may otherwise be smoothed out by splines and long moving windows.

Lastly, the NobBS approach requires a trade-off between flexibility and precision when specifying the moving window size. With a shorter moving window the model will be more sensitive to recent reporting delay data, that could otherwise be “smoothed out” by the additional historical data considered by longer moving windows. While a narrower window allows more flexibility capture time-changes in the delay distribution, estimates of the parameters governing the random walk will be more volatile, with fewer data points from which to be estimated. In our experiments, the combination of shorter moving windows with rapid changes in cases reported produced large estimated variances, which often decreased the accuracy of nowcasts. We note that the moving window size is ultimately a choice by the modeler and should reflect consideration of available data and the desired smoothness of trends to be estimated; we discuss more in _Materials and Methods_.

A strength of the NobBS approach is that it only requires historical data on case reporting, which makes it immediately adaptable in a variety of disease systems that may not have other real-time covariates to inform the nowcasting model (e.g. search engine queries, weather data). However, if these covariates are available, it would be possible to include them directly in the log-linear model (_Materials and Methods_) as additional predictors, as demonstrated by Bastos et al \[[16](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref016)\].

Beyond supporting real-time disease tracking by public health officials, NobBS can complement existing disease forecast efforts by providing more accurate nowcasts to forecasting teams in the place of real-time reporting underestimates. For example, teams participating in the Centers for Disease Control and Prevention Epidemic Prediction Initiative ([https://predict.cdc.gov](https://predict.cdc.gov/)) challenges (e.g. FluSight) use initial surveillance data for forecasting because it is the most up-to-date data available\[[22](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref022)\]. NobBS can help account for later revisions to these data and therefore improve prospective estimates as well, though we note for FluSight this would require nowcasting not only the total number of cases each week, but also the number of patient visits to achieve the ILI% required for forecasts. To provide guidance in the practical implementation of NobBS, we outline considerations for prior choice, window choice, and other features in _Materials and Methods_.

We present an R package, “NobBS,” intended to provide easy and flexible implementation of this approach to a wide audience of public health officials and researchers. This package is available on CRAN ([cran.r-project.org/web/packages/NobBS/index.html](https://cran.r-project.org/web/packages/NobBS/index.html)).

## Materials and methods

### Surveillance data

We collected data on approximately 53,000 cases of dengue in Puerto Rico and 2.77 million cases of ILI in the United States over a 21-year (1092 weeks) and 3.75-year (196 weeks) period, respectively. Time-stamped weekly dengue data for laboratory-confirmed cases of dengue in Puerto Rico were collected by the Puerto Rico Department of Health and Centers for Disease Control and Prevention. The times used for the analysis were the time of onset as reported by the reporting clinician and the time of laboratory report completion. ILI data originated from the U.S. Outpatient Influenza-like Illness Surveillance Network (ILINet), which consolidates information from over 2000 outpatient healthcare providers in the United States who report to the CDC on the number of patients with ILI. The times used for the analysis were the week of ILI-related care seeking and the week when those cases were posted online in FluView ([https://gis.cdc.gov/grasp/fluview/fluportaldashboard.html](https://gis.cdc.gov/grasp/fluview/fluportaldashboard.html)) as collected in the DELPHI epidemiological data API ([https://github.com/cmu-delphi/delphi-epidata](https://github.com/cmu-delphi/delphi-epidata)). ILI data with delays of more than 6 months occasionally had irregularities, so we restricted the analyses to delays of up to 6 months.

### Reporting triangle

Delays in reporting are often structurally decomposed into a (_T_ x _D_) dimensional “reporting triangle,” where _T_ is the most recent week (“now”) and _D_ is the maximum reporting delay, in weeks, observed in the data. The data are right-truncated, since at any given week _t_, delays longer than _T–t_ cannot be observed. For example, at week _t = T_, only the cases reported with delay _d_ = 0 are observable; cases reported with longer delays (i.e. 1- or 2-week delays, _d = 1_ or _d = 2_) will be known in future weeks. In [S6 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s006), we present an example of the reporting triangle using ILI data.

For each week _t_, the goal of nowcasting is to produce estimates for the total number of cases eventually reported, _N__t_, based on an incomplete set of observed cases with delay _d_, _n__t_,_d_. Since not every _n__t_,_d_ is observed for a delay _d_, but will be observed at some unknown time point in the future, _N__t_ = sum(_n__t_,_d_).

Our approach is motivated by modeling the marginal cell counts of the reporting triangle, _n__t_,_d_ in an adaptation of the loglinear chain ladder method developed in actuarial literature\[[13](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref013),[14](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref014)\].

### Bayesian nowcast model

Let _n__t_,_d_ be the number of cases reported for week _t_ with delay _d_. We assume that the underlying cases occur in a Poisson process such that 

We apply this default assumption in the case of the dengue fever data.

We also allow for extra-Poisson variation, that is, when the variance is larger than the mean and a negative binomial process (of which the Poisson is a special case) is more appropriate. We apply this in the case of the influenza (ILI) data:   and p(t,d) is the failure probability at week _t_ and delay _d_, and (r) is the number of failures before stopping.

We then model the mean, _λ__t_,_d_, as a simple log-linear equation  where _α__t_ represents the true epidemiologic signal for week _t_ and _β__d_ as the probability of reporting with delay = _d_. In other words, NobBS contains random effects for week _t_ and the reporting delay _d_. Exponentiating both sides of the equation, . This model is an adaptation of the general chain ladder model, proposed in the actuarial literature as an approach to nowcast the number of claims at time _t_ with delay _d_ with the form _log_ (_λ__t_,_d_) = _μ_+_α__t_+_β__d_ \[[15](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref015)\].

We place prior distributions on _α__t_ and _β__d_ reflecting properties of each parameter. Since _β__d_ represents a probability vector containing delays = 0, …, _D_, we place on it a Dirichlet prior of length _D_:  

The maximum delay _D_ can be identified as the maximum observable delay in the data, which may change as the time series extends, or can be fixed at some value _D_ thought to represent a very long delay. In the latter case, _θ__D_ can be modeled as the probability of delay ≥ _D_. For dengue, we choose to fix _D_ at 10 weeks, since over 99% of the cases observed in the first two years (prior to producing out-of-sample nowcasts) were reported within 10 weeks. For influenza, we chose _D_ to be the longest possible delay within the 27-week moving window, or _D_ = 26. The implications of choosing a maximum delay _D_ within a moving window of _W_ weeks means that the nowcast will include all cases arising with delays greater than or equal to _D_ but less than or equal to _W_, thus excluding all cases with delays greater than _W_ (see the reporting triangle in [S6 Table](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.s006)).

We place weakly informative priors on _θ_ representing a small number of hypothetical total cases (n = 10) distributed across delay bins, loosely representing the empirical probability of reporting delays for each delay _d_ observed in the first two years of data for dengue and the first 6 months of data for ILI (training periods). As a sensitivity, we also placed weak priors on _θ_ treating all delays with equal probability, but there was no material difference in the results.

We allow a dependency between successive _α__t_’s to capture the time evolution and autocorrelation of cases from week-to-week, commonly exhibited by epidemic curves. We therefore model _α__t_ as a first-order random walk:  

Because _α__t_ is in natural log form, this constitutes a geometric random walk.

We place weakly informative priors on the precisions of the Normal distribution, . For the negative binomial stopping-time parameter, r, we place an informative Ga(60,20) prior to reflect belief that the process deviates moderately from the Poisson.

Models were compiled in JAGS on R (v 3.3.2) producing 10,000 posterior samples. Trace plots were visually reviewed for convergence.

### NobBS R package implementation and recommendations

In the R package “NobBS” ([cran.r-project.org/web/packages/NobBS/index.html](https://cran.r-project.org/web/packages/NobBS/index.html)), the nowcast model may be implemented automatically by specifying a data frame with one record (row) per case, with a variable specifying the date of case onset and a variable specifying the date of case report. Dates are assumed to be in a sequence of weeks or months, with no gaps in reporting (i.e. no weeks for which reporting did not happen). By default, the model runs a Poisson log-linear model with no moving window (i.e. all historical data is taken into account), a maximum delay _D_ equal to 1 minus the length of the reporting time series (i.e. if 12 consecutive weeks of report data are provided, the longest possible delay is equal to 11 weeks), and ignoring any delays longer than _D_ (because they are unobserved in the default implementation). By default, a weakly informative Ga(0.01,0.01) prior is placed on the precision of the first-order random walk, , indicating equal weight to a standard deviation of 1 as to a standard deviation of 10,000: in other words, little knowledge about the extent to which the number of cases in the present week differ from the previous week. A weakly informative Dirichlet(_θ__d_…_D_ = 0.1) prior is placed on the vector of delay probabilities, _β__d_, indicating the weak prior belief that the probability of delay _d_ is equal at all delays.

However, in “NobBS” all of these features are customizable and it is possible to leverage existing knowledge or historical information to impose more informative priors on the data. For example, it may be already known in the surveillance field that cases of dengue fever are rarely reported the same week they occur (i.e. that the probability of delay _d_ = 0 is very low), but that most cases are reported within 4 weeks. In this example, it would be possible to design a stronger prior on _β__d_ such that _θ_ = (3,30,50,10,4,3), indicating that out of 100 cases distributed across delays, 3% of cases are expected to be reported with no delay, 30% of cases with a 1-week delay, 50% of cases with a 2-week delay, 10% of cases with a 3-week delay, 4% of cases with a 4-week delay, and 3% of cases with a 5-week delay. In other words, the user may directly parameterize the Dirichlet prior using knowledge of the delay distribution, and the sum of _θ__d_…_D_ is related to the strength of the prior. Historical information (e.g. reporting data from the last several months or years) may also be used to inform the Dirichlet prior, such as through plotting the empirical distribution of delays in case reports. In the present study, for example, the observed delay distribution over the initial model training period was used to inform weakly informative Dirichlet priors for dengue and ILI, with the sum of _θ__d_…_D_ being small.

The shape and rate hyperpriors of the Gamma(shape, rate) prior on  may also be modified to reflect stronger prior knowledge of the relationship between cases from week-to-week, which controls the smoothness of the epidemic curve. Increasing the shape parameter with a more informative prior, e.g. Gamma(10,0.1), can force the differences in cases from week-to-week to be small, resulting in a smoother epidemic curve and mitigating large fluctuations in estimates.

In all cases, keep in mind that the posterior is a compromise between the prior and the likelihood, so with enough weeks of reporting, the observed data can dominate over the prior.

Specifying a moving window size (e.g. a moving window of 27 weeks) may be leveraged for computational advantage (faster runtime) or to reflect the belief that the delay distribution of very old reports is no longer relevant to inform current reports. Alternatively, the user may prefer to let the moving window expand each week, especially to leverage as much prior data as possible to inform the nowcasts in the absence of available historical information. As discussed in Results, the estimation of the parameters is sensitive to how much historical data is used to fit the model, and this decision is up to the user and could depend on the relevant disease reporting system. The moving window acts to consider (or “weight”) all past observations equally, and shortening the moving window reflects the extent to which the user wishes to consider only more recent data as informative–noting also that shorter moving windows produce more volatile estimates of delay probabilities (which generally increases the accuracy of) as well as more volatile estimates of the variance of the random walk (which generally decreases the accuracy of). Still, these parameters may be constrained through their priors as discussed above.

### Nowcast estimates

We produced weekly nowcasts beginning with the 27th week (influenza) and 104th week (dengue) and through the final week of the series. This resulted in 989 weekly out-of-sample estimates of dengue cases and 170 weekly out-of-sample estimates of ILI. The time series of nowcast estimates for both diseases are shown in Figs [1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g001) and [2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi-1007735-g002).

We used a two-year moving window to estimate a stable delay distribution within the window. As a sensitivity, and to gauge the minimum amount of historical information required to produce accurate nowcasts, we also applied moving windows of 5, 12, and 27 weeks (approximately 6 months).

We used as a benchmark for comparison the “nowcast” function of the R package “surveillance” by Höhle and colleagues (described in ref.\[[9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref009)\]) designed to produce Bayesian nowcasts for epidemics using a hierarchical model for _n__t_, _d_ ≤ _T-t_ | _n__t_,_d_, or the observed cases conditional on the expected total number of cases. We applied the function assuming a time-homogenous delay distribution and recommended parameterization described by the authors in [http://staff.math.su.se/hoehle/blog/2016/07/19/nowCast.html](http://staff.math.su.se/hoehle/blog/2016/07/19/nowCast.html), and for comparability, used the same moving window sizes (27 and 104 weeks) to produce nowcasts over the same time periods.

### Model performance metrics

The mean absolute error (MAE), root mean square error (RMSE) and relative root mean square error (rRMSE) are defined, respectively, as:    and were used to quantify the accuracy of point estimates, xi, compared to true case numbers, yi, across the different models at each week _i_.

To quantify the accuracy of the point estimates in capturing the _change_ in cases from week _i-1_ to week _i_, we computed the mean absolute error of the change (MAEΔ) and the RMSE of the change (RMSEΔ):  

To capture smoothness in predictions from week-to-week, we also calculated the lag-1 autocorrelation of predictions (ρa) and cases (ρc) between week _i_ and week _i-1_.  where x = the predicted or true cases at each week _i_.

The logarithmic scoring rule was used to quantify the accuracy of the posterior predictive distribution of the nowcast. Predictive distributions were assigned to a series of bins categorized across possible values of true case counts. We used bin widths of 25 cases for dengue and 1000 cases for influenza, allowing for a larger number of bins for ILI cases based on case ranges of approx. 0–400 for dengue and 4,000–40,000 for ILI. For a predictive distribution with binned probability pi for a given nowcast target, the logarithmic score was calculated as ln(pi). For example, there were 115 cases eventually observed for the week of January 20, 1992. The NobBS nowcast for this week, which assigned a probability of 0.4 to the bin \[100,125), thus received a log score of ln(0.4) = -0.92. As in\[[22](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref022),[23](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref023)\], a very low log score of -10 was assigned for weeks in which the predictive distribution did not include the true case value, for weeks in which the bin probability ≤ e-10. This rule provides a lower limit (-10) to the score of highly inaccurate predictions.

The average log score across all prediction weeks was computed for all models to assess nowcast performance. The exponentiated average log score yields a nowcast score that can be interpreted as the average probability assigned to the bin corresponding to the true number of cases, and is a metric for model comparison purposes used in several other forecast contexts\[[22](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref022),[23](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#pcbi.1007735.ref023)\]. In this paper, we present the exponentiated average log score and refer to this as the average score.

### Simulated ILI data

To simulate ILI data with a time-varying probability of reporting delay _d_ = 0, we drew, for each week, Pr(d = 0) from Unif(0.2, 0.9) for all weeks in which the total number of eventually-observed cases exceeded the mean of the ILI series (14,000 cases), and from Unif(0, 0.65) for all weeks in which the total observed case count was less than or equal to 14,000. This probability was used to calculate the simulated number of cases that would be observed with d = 0, out of the total number of cases that would be eventually observed for that week. The remaining cases were distributed to other delays ranging from 1–52 weeks using NB(0.9,0.4). This produced a rough approximation for a hypothetical scenario in which cases are reported faster (higher probability of d = 0) during weeks with higher disease activity (more cases), representing heightened awareness of an outbreak and increased urgency of reporting. However, it would also be possible to simulate the reverse scenario (slower reporting at weeks of higher incidence, to demonstrate the problem of reporting backfill during an outbreak) by swapping the two uniform priors.

## Supporting information

Nowcasting by Bayesian Smoothing: A flexible, generalizable model for real-time epidemic tracking

Showing 1/14: pcbi.1007735.s001.pdf

Average error (predicted - actual) for weeks where:  
Disease Threshold Δ initial reports >  
threshold  
Δ initial reports <=  
threshold  
Dengue Moderate: 5 cases 61.6 \-1.8  
High: 10 cases 277.0 \-0.2  
ILI Moderate: 1,000 cases \-92.8 \-38.4  
High: 2,500 cases \-198.9 \-37.7

1 / 14

[

fig**share**

](https://figshare.com/articles/dataset/Nowcasting_by_Bayesian_Smoothing_A_flexible_generalizable_model_for_real-time_epidemic_tracking/12088842)

NobBS Average error for moderate and high absolute changes in initial case reports, compared to the previous week.

(PDF)

### [S1 Table.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s001) NobBS Average error for moderate and high absolute changes in initial case reports, compared to the previous week.

[https://doi.org/10.1371/journal.pcbi.1007735.s001](https://doi.org/10.1371/journal.pcbi.1007735.s001)

(PDF)

### [S2 Table.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s002) Comparing model performance on influenza reports with constant and non-constant delay distributions.

[https://doi.org/10.1371/journal.pcbi.1007735.s002](https://doi.org/10.1371/journal.pcbi.1007735.s002)

(PDF)

### [S3 Table.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s003) Performance measures for estimates of the change in ILI incidence from the previous week, comparing constant and non-constant ILI delay distributions.

[https://doi.org/10.1371/journal.pcbi.1007735.s003](https://doi.org/10.1371/journal.pcbi.1007735.s003)

(PDF)

### [S4 Table.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s004) Outbreak performance measures for each nowcast model, by disease.

A dengue outbreak season was defined as weeks for which the number of cases exceeded 50, and an ILI outbreak season was defined per the CDC as Epidemiologic Weeks 40 through Week 20 of the following year.

[https://doi.org/10.1371/journal.pcbi.1007735.s004](https://doi.org/10.1371/journal.pcbi.1007735.s004)

(PDF)

### [S5 Table.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s005) Select performance measures for dengue fever nowcast model with different moving window sizes.

[https://doi.org/10.1371/journal.pcbi.1007735.s005](https://doi.org/10.1371/journal.pcbi.1007735.s005)

(PDF)

### [S6 Table.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s006) Reporting triangle for ILI on June 8, 2015.

The _TxD_ reporting triangle decomposes the number of cases, nt,d, reported for each week _t_ (rows) and each delay _d_ (column), up to a delay of _D_ = 26 weeks within the 27-week moving window. The goal of nowcasting is to predict the missing (NA) nt,d’s.

[https://doi.org/10.1371/journal.pcbi.1007735.s006](https://doi.org/10.1371/journal.pcbi.1007735.s006)

(PDF)

### [S1 Fig.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s007)

**Prediction interval calibration plot for ILI nowcasts showing the percent of true ILI cases contained in the prediction interval (y-axis) at deciles of the prediction interval (x-axis, 10% to 90%).** Perfect calibration is shown by the dotted blue line.

[https://doi.org/10.1371/journal.pcbi.1007735.s007](https://doi.org/10.1371/journal.pcbi.1007735.s007)

(PNG)

### [S2 Fig.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s008)

The delay distribution (grey) and cumulative distribution (red), in weeks, over the full time series for (A) dengue fever and (B) influenza-like illness (ILI) cases.

[https://doi.org/10.1371/journal.pcbi.1007735.s008](https://doi.org/10.1371/journal.pcbi.1007735.s008)

(PNG)

### [S3 Fig.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s009)

Comparing (A) the change in initial case reports (from previous week) to (B) the error of NobBS for dengue fever.

[https://doi.org/10.1371/journal.pcbi.1007735.s009](https://doi.org/10.1371/journal.pcbi.1007735.s009)

(PNG)

### [S4 Fig.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s010)

Weekly reporting delay probabilities for delays up to 17 weeks for (A) dengue fever from 1990–2010 and (B) influenza-like illness from 2014–2017.

[https://doi.org/10.1371/journal.pcbi.1007735.s010](https://doi.org/10.1371/journal.pcbi.1007735.s010)

(PDF)

### [S5 Fig.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s011) Weekly ILI nowcasts for June 30, 2014 through March 14, 2016 using a non-constant (time-varying) delay distribution and 2-year moving window.

(A) NobBS nowcasts along with (B) point estimate and uncertainty accuracy, as measured by the score and the prediction error, are compared to (C) nowcasts by the HH approach with (D) corresponding scores and prediction errors. For nowcasting, the number of newly-reported cases each week (blue line) are the only data available in real-time for that week, and help inform the estimate of the total number of cases that will be eventually reported (red line), shown with 95% prediction intervals (pink bands). For the HH approach, the 95% prediction intervals are very narrow and are thus difficult to see. The true number of cases eventually reported (black line) is known only in hindsight and is the nowcast target. The score (brown line) and the difference between the true and mean estimated number of cases (grey line) are shown as a function of time.

[https://doi.org/10.1371/journal.pcbi.1007735.s011](https://doi.org/10.1371/journal.pcbi.1007735.s011)

(PDF)

### [S6 Fig.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s012)

**Comparing the probability assigned to the bin containing the true number of cases (y-axis) to the true number of cases (x-axis), for weekly dengue fever nowcasts using NobBS.** Vertical dashed lines in grey are used to visualize the bin width of 25 cases.

[https://doi.org/10.1371/journal.pcbi.1007735.s012](https://doi.org/10.1371/journal.pcbi.1007735.s012)

(PNG)

### [S7 Fig.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s013)

**Weekly NobBS dengue fever nowcasts using (A) 5-week moving window, (B) 12-week moving window, and (C) 27-week (approx. 6 month) moving window.** Plots are zoomed in the y-axis to show the details of prediction.

[https://doi.org/10.1371/journal.pcbi.1007735.s013](https://doi.org/10.1371/journal.pcbi.1007735.s013)

(PNG)

### [S8 Fig.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1007735.s014)

**Comparing the (A) estimated reporting delay probabilities for delay _d_ = 0 and (B) estimated inverse variance of the random walk, at moving windows of 5 weeks (blue) and 104 weeks (red) for dengue fever nowcasts.** In (A), the true reporting delay probability at _d_ = 0 can be calculated from the data and is shown in grey.

[https://doi.org/10.1371/journal.pcbi.1007735.s014](https://doi.org/10.1371/journal.pcbi.1007735.s014)

(PNG)

## References

1.  1\. Lipsitch M, Finelli L, Heffernan RT, Leung GM, Redd SC, 2009 H1n1 Surveillance Group. Improving the evidence base for decision making during a pandemic: the example of 2009 influenza A/H1N1. Biosecur Bioterror. 2011;9: 89–115. pmid:21612363
    -   [View Article](https://doi.org/10.1089/bsp.2011.0007 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/21612363 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Improving+the+evidence+base+for+decision+making+during+a+pandemic%3A+the+example+of+2009+influenza+A%2FH1N1+Lipsitch+2011 "Go to article in Google Scholar")
2.  2\. Thacker SB, Berkelman RL, Stroup DF. The Science of Public Health Surveillance. J Public Health Policy. 1989;10: 187. pmid:2745711
    -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735# "Go to article in CrossRef")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/2745711 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=The+Science+of+Public+Health+Surveillance+Thacker+1989 "Go to article in Google Scholar")
3.  3\. Gikas A, Sotiropoulos A, Panagiotakos D, Peppas T, Skliros E, Pappas S. Prevalence, and associated risk factors, of self-reported diabetes mellitus in a sample of adult urban population in Greece: MEDICAL Exit Poll Research in Salamis (MEDICAL EXPRESS 2002). BMC Public Health. 2004;4: 2. pmid:15028111
    -   [View Article](https://doi.org/10.1186/1471-2458-4-2 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/15028111 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Prevalence%2C+and+associated+risk+factors%2C+of+self-reported+diabetes+mellitus+in+a+sample+of+adult+urban+population+in+Greece%3A+MEDICAL+Exit+Poll+Research+in+Salamis+%28MEDICAL+EXPRESS+2002%29+Gikas+2004 "Go to article in Google Scholar")
4.  4\. Kaminsky KS. Prediction of IBNR claim counts by modelling the distribution of report lags. Insur Math Econ. 1987;6: 151–159.
    -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735# "Go to article in CrossRef")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Prediction+of+IBNR+claim+counts+by+modelling+the+distribution+of+report+lags+Kaminsky+1987 "Go to article in Google Scholar")
5.  5\. Lawless JF. Adjustments for reporting delays and the prediction of occurred but not reported events. Can J Stat. 1994;22: 15–31.
    -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735# "Go to article in CrossRef")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Adjustments+for+reporting+delays+and+the+prediction+of+occurred+but+not+reported+events+Lawless+1994 "Go to article in Google Scholar")
6.  6\. Pagano M, Tu XM, De Gruttola V, MaWhinney S. Regression Analysis of Censored and Truncated Data: Estimating Reporting- Delay Distributions and AIDS Incidence from Surveillance Data \[Internet\]. Biometrics. 1994. p. 1203. pmid:7787003
    -   [View Article](https://doi.org/10.2307/2533459 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/7787003 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Regression+Analysis+of+Censored+and+Truncated+Data%3A+Estimating+Reporting-+Delay+Distributions+and+AIDS+Incidence+from+Surveillance+Data+%5BInternet%5D+Pagano+1994 "Go to article in Google Scholar")
7.  7\. Comiskey CM, Ruskin HJ. AIDS in Ireland: the reporting delay distribution and the implementation of integral equation models. Comput Appl Biosci. 1992;8: 579–581. pmid:1468015
    -   [View Article](https://doi.org/10.1093/bioinformatics/8.6.579 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/1468015 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=AIDS+in+Ireland%3A+the+reporting+delay+distribution+and+the+implementation+of+integral+equation+models+Comiskey+1992 "Go to article in Google Scholar")
8.  8\. Cui J, Kaldor J. Changing pattern of delays in reporting AIDS diagnoses in Australia. Aust N Z J Public Health. 1998;22: 432–435. pmid:9659768
    -   [View Article](https://doi.org/10.1111/j.1467-842x.1998.tb01409.x "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/9659768 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Changing+pattern+of+delays+in+reporting+AIDS+diagnoses+in+Australia+Cui+1998 "Go to article in Google Scholar")
9.  9\. Höhle M, an der Heiden M. Bayesian nowcasting during the STEC O104:H4 outbreak in Germany, 2011. Biometrics. 2014;70: 993–1002. pmid:24930473
    -   [View Article](https://doi.org/10.1111/biom.12194 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/24930473 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Bayesian+nowcasting+during+the+STEC+O104%3AH4+outbreak+in+Germany%2C+2011+H%C3%B6hle+2014 "Go to article in Google Scholar")
10.  10\. Salmon M, Schumacher D, Stark K, Höhle M. Bayesian outbreak detection in the presence of reporting delays. Biom J. 2015;57: 1051–1067. pmid:26250543
     -   [View Article](https://doi.org/10.1002/bimj.201400159 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/26250543 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Bayesian+outbreak+detection+in+the+presence+of+reporting+delays+Salmon+2015 "Go to article in Google Scholar")
11.  11\. Lawless JF. Adjustments for reporting delays and the prediction of occurred but not reported events \[Internet\]. Canadian Journal of Statistics. 1994. pp. 15–31.
     -   [View Article](https://doi.org/10.2307/3315826.n1 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Adjustments+for+reporting+delays+and+the+prediction+of+occurred+but+not+reported+events+Lawless+1994 "Go to article in Google Scholar")
12.  12\. Kalbfleisch JD, Lawless JF. Regression Models for Right Truncated Data with Applications to AIDS incubation Times and Reporting Lags. Stat Sin. 1991;1: 19–32.
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Regression+Models+for+Right+Truncated+Data+with+Applications+to+AIDS+incubation+Times+and+Reporting+Lags+Kalbfleisch+1991 "Go to article in Google Scholar")
13.  13\. Kremer E. IBNR-claims and the two-way model of ANOVA \[Internet\]. Scandinavian Actuarial Journal. 1982. pp. 47–55.
     -   [View Article](https://doi.org/10.1080/03461238.1982.10405432 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=IBNR-claims+and+the+two-way+model+of+ANOVA+Kremer+1982 "Go to article in Google Scholar")
14.  14\. Verrall RJ. A state space representation of the chain ladder linear model \[Internet\]. Journal of the Institute of Actuaries. 1989. pp. 589–609.
     -   [View Article](https://doi.org/10.1017/s0020268100036714 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=A+state+space+representation+of+the+chain+ladder+linear+model+Verrall+1989 "Go to article in Google Scholar")
15.  15\. Verrrall R. Statistical methods for the chain ladder technique \[Internet\]. Insurance: Mathematics and Economics. 1994. p. 82.
     -   [View Article](https://doi.org/10.1016/0167-6687\(94\)90725-0 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Statistical+methods+for+the+chain+ladder+technique+Verrrall+1994 "Go to article in Google Scholar")
16.  16\. Bastos L, Economou T, Gomes M, Villela D, Bailey T, Codeço C. Modelling reporting delays for disease surveillance data. arXiv:170909150. 2017; Available: [https://arxiv.org/abs/1709.09150](https://arxiv.org/abs/1709.09150)
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Modelling+reporting+delays+for+disease+surveillance+data+Bastos+2017 "Go to article in Google Scholar")
17.  17\. Noufaily A, Ghebremichael-Weldeselassie Y, Enki DG, Garthwaite P, Andrews N, Charlett A, et al. Modelling reporting delays for outbreak detection in infectious disease data. J R Stat Soc A. 2015;178: 205–222.
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Modelling+reporting+delays+for+outbreak+detection+in+infectious+disease+data+Noufaily+2015 "Go to article in Google Scholar")
18.  18\. Wallinga J, Teunis P. Different epidemic curves for severe acute respiratory syndrome reveal similar impacts of control measures. Am J Epidemiol. 2004;160: 509–516. pmid:15353409
     -   [View Article](https://doi.org/10.1093/aje/kwh255 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/15353409 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Different+epidemic+curves+for+severe+acute+respiratory+syndrome+reveal+similar+impacts+of+control+measures+Wallinga+2004 "Go to article in Google Scholar")
19.  19\. Johansson MA, Reich NG, Hota A, Brownstein JS, Santillana M. Evaluating the performance of infectious disease forecasts: A comparison of climate-driven and seasonal dengue forecasts for Mexico. Sci Rep. 2016;6: 33707. pmid:27665707
     -   [View Article](https://doi.org/10.1038/srep33707 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/27665707 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Evaluating+the+performance+of+infectious+disease+forecasts%3A+A+comparison+of+climate-driven+and+seasonal+dengue+forecasts+for+Mexico+Johansson+2016 "Go to article in Google Scholar")
20.  20\. Yang S, Santillana M, Kou SC. Accurate estimation of influenza epidemics using Google search data via ARGO. Proc Natl Acad Sci U S A. 2015;112: 14473–14478. pmid:26553980
     -   [View Article](https://doi.org/10.1073/pnas.1515373112 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/26553980 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Accurate+estimation+of+influenza+epidemics+using+Google+search+data+via+ARGO+Yang+2015 "Go to article in Google Scholar")
21.  21\. van de Kassteele J, Eilers P, Wallinga J. Nowcasting the number of new symptomatic cases during infectious disease outbreaks using constrained P‐spline smoothing. Epidemiology. 2019;
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting+the+number+of+new+symptomatic+cases+during+infectious+disease+outbreaks+using+constrained+P%E2%80%90spline+smoothing+van+de+Kassteele+2019 "Go to article in Google Scholar")
22.  22\. Reich NG, Brooks LC, Fox SJ, Kandula S, McGowan CJ, Moore E, et al. A collaborative multiyear, multimodel assessment of seasonal influenza forecasting in the United States. Proc Natl Acad Sci U S A. 2019;116: 3146–3154. pmid:30647115
     -   [View Article](https://doi.org/10.1073/pnas.1812594116 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/30647115 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=A+collaborative+multiyear%2C+multimodel+assessment+of+seasonal+influenza+forecasting+in+the+United+States+Reich+2019 "Go to article in Google Scholar")
23.  23\. McGowan CJ, Biggerstaff M, Johansson M, Apfeldorf KM, Ben-Nun M, Brooks L, et al. Collaborative efforts to forecast seasonal influenza in the United States, 2015–2016. Sci Rep. 2019;9: 683. pmid:30679458
     -   [View Article](https://doi.org/10.1038/s41598-018-36361-9 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/30679458 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Collaborative+efforts+to+forecast+seasonal+influenza+in+the+United+States%2C+2015%E2%80%932016+McGowan+2019 "Go to article in Google Scholar")

[Download PDF](https://journals.plos.org/ploscompbiol/article/file?id=10.1371/journal.pcbi.1007735&type=printable)

 

-   [Citation](https://journals.plos.org/ploscompbiol/article/citation?id=10.1371/journal.pcbi.1007735)
-   [XML](https://journals.plos.org/ploscompbiol/article/file?id=10.1371/journal.pcbi.1007735&type=manuscript)

[Print](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735#)

Share

-   [Reddit](https://www.reddit.com/submit?url=https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1007735 "Submit to Reddit")
-   [Facebook](https://www.facebook.com/share.php?u=https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1007735&t=Nowcasting%20by%20Bayesian%20Smoothing:%20A%20flexible,%20generalizable%20model%20for%20real-time%20epidemic%20tracking "Share on Facebook")
-   [LinkedIn](https://www.linkedin.com/shareArticle?url=https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1007735&title=Nowcasting%20by%20Bayesian%20Smoothing:%20A%20flexible,%20generalizable%20model%20for%20real-time%20epidemic%20tracking&summary=Checkout%20this%20article%20I%20found%20at%20PLOS "Add to LinkedIn")
-   [Mendeley](https://www.mendeley.com/import/?url=https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1007735 "Add to Mendeley")
-   [Bluesky](https://bsky.app/intent/compose?text=Checkout%20this%20article%20I%20found%20at%20PLOS:%20https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1007735 "Share on Bluesky")
-   [Email](mailto:?subject=Nowcasting%20by%20Bayesian%20Smoothing:%20A%20flexible,%20generalizable%20model%20for%20real-time%20epidemic%20tracking&body=I%20thought%20you%20would%20find%20this%20article%20interesting.%20From%20PLOS%20Computational%20Biology:%20https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1007735)

  

Advertisement

### Subject Areas

?

-   [Dengue fever](https://journals.plos.org/ploscompbiol/search?filterSubjects=Dengue+fever&filterJournals=PLoSCompBiol&q= "Search for articles about Dengue fever")  
    
    Is the Subject Area **"Dengue fever"** applicable to this article?  
    
-   [Epidemiology](https://journals.plos.org/ploscompbiol/search?filterSubjects=Epidemiology&filterJournals=PLoSCompBiol&q= "Search for articles about Epidemiology")  
    
    Is the Subject Area **"Epidemiology"** applicable to this article?  
    
-   [Infectious disease surveillance](https://journals.plos.org/ploscompbiol/search?filterSubjects=Infectious+disease+surveillance&filterJournals=PLoSCompBiol&q= "Search for articles about Infectious disease surveillance")  
    
    Is the Subject Area **"Infectious disease surveillance"** applicable to this article?  
    
-   [Autocorrelation](https://journals.plos.org/ploscompbiol/search?filterSubjects=Autocorrelation&filterJournals=PLoSCompBiol&q= "Search for articles about Autocorrelation")  
    
    Is the Subject Area **"Autocorrelation"** applicable to this article?  
    
-   [Probability distribution](https://journals.plos.org/ploscompbiol/search?filterSubjects=Probability+distribution&filterJournals=PLoSCompBiol&q= "Search for articles about Probability distribution")  
    
    Is the Subject Area **"Probability distribution"** applicable to this article?  
    
-   [Random walk](https://journals.plos.org/ploscompbiol/search?filterSubjects=Random+walk&filterJournals=PLoSCompBiol&q= "Search for articles about Random walk")  
    
    Is the Subject Area **"Random walk"** applicable to this article?  
    
-   [Influenza](https://journals.plos.org/ploscompbiol/search?filterSubjects=Influenza&filterJournals=PLoSCompBiol&q= "Search for articles about Influenza")  
    
    Is the Subject Area **"Influenza"** applicable to this article?  
    
-   [Infectious diseases](https://journals.plos.org/ploscompbiol/search?filterSubjects=Infectious+diseases&filterJournals=PLoSCompBiol&q= "Search for articles about Infectious diseases")  
    
    Is the Subject Area **"Infectious diseases"** applicable to this article?  
    

-   [Publications](https://plos.org/our-journals/)
-   [PLOS Aging and Health](https://journals.plos.org/agingandhealth/)
-   [PLOS Biology](https://journals.plos.org/plosbiology/)
-   [PLOS Climate](https://journals.plos.org/climate/)
-   [PLOS Complex Systems](https://journals.plos.org/complexsystems/)
-   [PLOS Computational Biology](https://journals.plos.org/ploscompbiol/)
-   [PLOS Digital Health](https://journals.plos.org/digitalhealth/)
-   [PLOS Ecosystems](https://journals.plos.org/ecosystems/)
-   [PLOS Genetics](https://journals.plos.org/plosgenetics/)

-   [PLOS Global Public Health](https://journals.plos.org/globalpublichealth/)
-   [PLOS Medicine](https://journals.plos.org/plosmedicine/)
-   [PLOS Mental Health](https://journals.plos.org/mentalhealth/)
-   [PLOS Neglected Tropical Diseases](https://journals.plos.org/plosntds/)
-   [PLOS One](https://journals.plos.org/plosone/)
-   [PLOS Pathogens](https://journals.plos.org/plospathogens/)
-   [PLOS Sustainability and Transformation](https://journals.plos.org/sustainabilitytransformation/)
-   [PLOS Water](https://journals.plos.org/water/)

-   [Home](https://plos.org/)
-   [Blogs](https://blogs.plos.org/)
-   [Collections](https://collections.plos.org/)
-   [Give feedback](mailto:customercare@plos.org)
-   [LOCKSS](https://journals.plos.org/ploscompbiol/lockss-manifest)

-   [Privacy Policy](https://plos.org/privacy-policy)
-   [Terms of Use](https://plos.org/terms-of-use)
-   [Advertise](https://plos.org/advertise/)
-   [Media Inquiries](https://plos.org/media-inquiries)
-   [Contact](https://plos.org/contact)

 PLOS is a nonprofit 501(c)(3) corporation, #C2354500, based in California, US

### Cookie Preference Center

Our website uses different types of cookies. Optional cookies will only be set with your consent and you may withdraw this consent at any time. Below you can learn more about the types of cookies PLOS uses and register your cookie preferences.

### Customize Your Cookie Preference

+**Strictly Necessary**

Always On

+**Functional**

Off

+**Performance and Analytics**

Off

+**Marketing**

Off

[For more information about the cookies and other technologies used by us, please read our Cookie Policy.](https://plos.org/cookies-policy)
