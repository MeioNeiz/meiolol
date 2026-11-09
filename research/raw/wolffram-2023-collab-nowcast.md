# Collaborative nowcasting of COVID-19 hospitalization incidences in Germany | PLOS Computational Biology

<https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394>

[Skip to main content](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#main-content)

Advertisement

-   [plos.org](https://plos.org/)
-   [Create account](https://community.plos.org/registration/new)
-   [Sign in](https://journals.plos.org/user/secure/login?page=%2Fploscompbiol%2Farticle%3Fid%3D10.1371%2Fjournal.pcbi.1011394)

-   -   
    -   
    -   
    
-   
-   [advanced search](https://journals.plos.org/ploscompbiol/search)
    

-   14
    
    [Save](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394#savedHeader)
    
    [Total Mendeley and Citeulike bookmarks.](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394#savedHeader)
    
-   35
    
    [Citation](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394#citedHeader)
    
    [Paper's citation count computed by Dimensions.](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394#citedHeader)
    
-   3,848
    
    [View](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394#viewedHeader)
    
    [PLOS views and downloads.](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394#viewedHeader)
    
-   8
    
    [Share](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394#discussedHeader)
    
    [Sum of Facebook, Twitter, Reddit and Wikipedia activity.](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394#discussedHeader)
    

Open Access

Peer-reviewed

Research Article

# Collaborative nowcasting of COVID-19 hospitalization incidences in Germany

-   Daniel Wolffram ,
-   Sam Abbott,
-   Matthias an der Heiden,
-   Sebastian Funk,
-   Felix Günther,
-   Davide Hailer,
-   Stefan Heyder,
-   Thomas Hotz,
-   Jan van de Kassteele,
-   Helmut Küchenhoff,
-   Sören Müller-Hansen,
-   Diellë Syliqi,
-   Alexander Ullrich,
-    \[ ... \],
-   Johannes Bracher
-   \[ view all \]

# Collaborative nowcasting of COVID-19 hospitalization incidences in Germany

-   Daniel Wolffram, 
-   Sam Abbott, 
-   Matthias an der Heiden, 
-   Sebastian Funk, 
-   Felix Günther, 
-   Davide Hailer, 
-   Stefan Heyder, 
-   Thomas Hotz,  …
-   Jan van de Kassteele, 
-   Helmut Küchenhoff

x

-   Published: August 11, 2023
-   [https://doi.org/10.1371/journal.pcbi.1011394](https://doi.org/10.1371/journal.pcbi.1011394)

-   [Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394)
-   [Authors](https://journals.plos.org/ploscompbiol/article/authors?id=10.1371/journal.pcbi.1011394)
-   [Metrics](https://journals.plos.org/ploscompbiol/article/metrics?id=10.1371/journal.pcbi.1011394)
-   [Comments](https://journals.plos.org/ploscompbiol/article/comments?id=10.1371/journal.pcbi.1011394)
-   [Media Coverage](http://plos.altmetric.com/details/doi/10.1371/journal.pcbi.1011394)
-   [Peer Review](https://journals.plos.org/ploscompbiol/article/peerReview?id=10.1371/journal.pcbi.1011394)

-   [Abstract](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#abstract0)
-   [Author summary](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#abstract1)
-   [1 Introduction](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#sec001)
-   [2 Methods](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#sec002)
-   [3 Results](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#sec008)
-   [4 Discussion](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#sec016)
-   [Supporting information](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#sec017)
-   [Acknowledgments](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#ack)
-   [References](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#references)

-   [Reader Comments](https://journals.plos.org/ploscompbiol/article/comments?id=10.1371/journal.pcbi.1011394)
-   [Figures](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#)

## Abstract

Real-time surveillance is a crucial element in the response to infectious disease outbreaks. However, the interpretation of incidence data is often hampered by delays occurring at various stages of data gathering and reporting. As a result, recent values are biased downward, which obscures current trends. Statistical nowcasting techniques can be employed to correct these biases, allowing for accurate characterization of recent developments and thus enhancing situational awareness. In this paper, we present a preregistered real-time assessment of eight nowcasting approaches, applied by independent research teams to German 7-day hospitalization incidences during the COVID-19 pandemic. This indicator played an important role in the management of the outbreak in Germany and was linked to levels of non-pharmaceutical interventions via certain thresholds. Due to its definition, in which hospitalization counts are aggregated by the date of case report rather than admission, German hospitalization incidences are particularly affected by delays and can take several weeks or months to fully stabilize. For this study, all methods were applied from 22 November 2021 to 29 April 2022, with probabilistic nowcasts produced each day for the current and 28 preceding days. Nowcasts at the national, state, and age-group levels were collected in the form of quantiles in a public repository and displayed in a dashboard. Moreover, a mean and a median ensemble nowcast were generated. We find that overall, the compared methods were able to remove a large part of the biases introduced by delays. Most participating teams underestimated the importance of very long delays, though, resulting in nowcasts with a slight downward bias. The accompanying prediction intervals were also too narrow for almost all methods. Averaged over all nowcast horizons, the best performance was achieved by a model using case incidences as a covariate and taking into account longer delays than the other approaches. For the most recent days, which are often considered the most relevant in practice, a mean ensemble of the submitted nowcasts performed best. We conclude by providing some lessons learned on the definition of nowcasting targets and practical challenges.

## Author summary

Current trends in epidemiological indicators are often obscured by the fact that recent values are still incomplete. This is due to reporting delays and other types of delays. Statistical nowcasting methods can be used to account for these biases and reveal yet unobserved trends, thereby improving situational awareness and supporting public health decision-making. While numerous methods exist for this purpose, little is known about their behavior in real-time settings and their relative performance. In this paper, we compared eight different nowcasting methods in an application to COVID-19 hospitalization incidences in Germany from November 2021 to April 2022. Additionally, we combined the predictions of these methods to create so-called ensemble nowcasts. Our findings indicate that while all methods yielded practically useful results, some systematic biases in nowcasts occurred and the remaining uncertainty was generally underestimated. Combined ensemble nowcasts showed promising performance relative to individual models and thus represent a promising avenue for future research.

## Figures

**Citation:** Wolffram D, Abbott S, an der Heiden M, Funk S, Günther F, Hailer D, et al. (2023) Collaborative nowcasting of COVID-19 hospitalization incidences in Germany. PLoS Comput Biol 19(8): e1011394. https://doi.org/10.1371/journal.pcbi.1011394

**Editor:** James M. McCaw, The University of Melbourne, AUSTRALIA

**Received:** April 14, 2023; **Accepted:** July 28, 2023; **Published:** August 11, 2023

**Copyright:** © 2023 Wolffram et al. This is an open access article distributed under the terms of the [Creative Commons Attribution License](http://creativecommons.org/licenses/by/4.0/), which permits unrestricted use, distribution, and reproduction in any medium, provided the original author and source are credited.

**Data Availability:** The authors confirm that all data underlying the findings are fully available without restriction. The nowcasts collected for this study are available in a GitHub repository ([https://github.com/KITmetricslab/hospitalization-nowcast-hub](https://github.com/KITmetricslab/hospitalization-nowcast-hub)), with a stable release published at [https://zenodo.org/record/7828604](https://zenodo.org/record/7828604). The repository also contains the truth data used for evaluation. Code to reproduce results and figures are provided at [https://github.com/dwolffram/hospitalization-nowcast-hub-evaluation](https://github.com/dwolffram/hospitalization-nowcast-hub-evaluation). A list of the participants’ code repositories can be found in Section C in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001).

**Funding:** J. Bracher acknowledges support from the Helmholtz Foundation via the project SIMCARD, while M. Schienle acknowledges support from the Helmholtz Foundation via the projects SIMCARD and COCAP. J. Bracher, D. Wolffram and M. Schienle were moreover supported by the German Federal Ministry of Education and Research (BMBF) via the project RESPINOW. J. Bracher’s work has been partly funded by the Deutsche Forschungsgemeinschaft (DFG, German Research Foundation) - project number 512483310. D. Wolffram is grateful for support from the Klaus Tschira Foundation. D. Wolffram’s contribution was moreover supported by the Helmholtz Association under the joint research school HIDSS4Health - Helmholtz Information and Data Science School for Health. S. Abbott and S. Funk were supported by The Wellcome Trust (210758/Z/18/Z). F. Günther was supported by NordForsk (grant no. 105572). The funders had no role in study design, data collection and analysis, decision to publish, or preparation of the manuscript.

**Competing interests:** The authors have declared that no competing interests exist.

## 1 Introduction

During infectious disease outbreaks, real-time surveillance data contributes to situational awareness and risk management, informing resource planning and control measures. However, the timely interpretation of epidemiological indicators is often hampered by the preliminary nature of real-time data. Due to reporting delays, the most recent data points are usually incomplete and subject to retrospective upward corrections. This bias can lead to incorrect conclusions about current trends. Statistical _nowcasting_ methods aim to remedy this problem by predicting how strongly preliminary data points are still going to be corrected upwards, taking into account the associated uncertainty. Nowcasts thus help to uncover current trends which are not yet visible in reported numbers.

Problems of this type have been extensively researched across various disciplines; e.g., in econometrics, the gross domestic product and the inflation rate are routinely nowcasted \[[1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref001)\]. Methods for preliminary count data as encountered in the present work originated in the actuarial sciences, where they were developed to handle insurance claims data \[[2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref002)\]. In epidemiology, the problem of delayed reporting has been treated in diverse contexts, including the HIV pandemic \[[3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref003)\], foodborne Escherichia coli outbreaks \[[4](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref004)\], the 2009 influenza pandemic \[[5](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref005)\] and mosquito-borne diseases like malaria \[[6](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref006)\] and dengue \[[7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref007), [8](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref008)\]. During the COVID-19 pandemic, the problem has seen growing interest, and new approaches tailored to a variety of settings have been suggested \[[9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref009)–[14](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref014)\]. There is thus an ever-growing number of methods to statistically correct reporting delays. However, two important aspects are rarely addressed in the current literature. Firstly, few studies assess the performance of methods in real-time settings. The papers we are aware of—with \[[14](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref014)\] as an exception—contain only retrospective case studies which risk smoothing over some of the difficulties occurring in real time (e.g., major data revisions, time pressure on analysts). Also, few studies include comparisons with existing methods. While occasionally one additional model is applied for comparison \[[8](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref008), [11](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref011), [13](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref013)\], systematic comparative assessments are lacking. Our work fills this gap by examining multiple procedures in real time, thus providing a realistic picture of nowcast performance and the arising practical challenges. By bringing together several different models, our study is moreover the first able to assess the potential of combined ensemble nowcasts.

We evaluate the different nowcasting approaches in an application to German 7-day hospitalization incidences. These have played an important role in the management of the pandemic in Germany. Indeed, in November 2021, they were defined as the key indicator to determine levels of non-pharmaceutical interventions. Via a system of thresholds \[[15](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref015)\], they played an important role in the management of the pandemic, in particular in the fall and winter of 2021. Nowcasting is of particular importance for this indicator due to the way it was defined. As will be detailed in Section 2.1, the official German hospitalization numbers published by Robert Koch Institute (RKI) are aggregated by the reporting date of the associated positive test rather than the date of hospital admission. The total time span between the case report and the hospitalization report (i.e. the “delay” that has to be predicted) thus consists of two parts: the time between the report of the positive test and hospital admission and the actual reporting delay between hospitalization and the reporting thereof. This definition led to some criticism in the public discourse but was defended as a necessary compromise between timeliness and data quality by RKI \[[16](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref016)\]. [Fig 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g001) illustrates the nowcasting task in the context of the 7-day hospitalization incidence. It shows real-time nowcasts from 1 December 2021, 1 February 2022, and 1 April 2022. Comparison with a more stable data version from 8 August 2022 shows that in these instances, the nowcasts were able to correctly reveal the actual trends, which differed sharply from the apparent declines found in the data as available at the time of nowcasting.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g001)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g001)

Fig 1. Illustration of the nowcasting task.

Data available in real time (colored lines) is incomplete, and especially for recent dates, the values are considerably lower than the final corrected values (black line). Nowcasts (blue-shaded areas) aim to predict in real time what the final data points will be. The light gray line shows the initially reported value as available on the respective date.

[https://doi.org/10.1371/journal.pcbi.1011394.g001](https://doi.org/10.1371/journal.pcbi.1011394.g001)

The present work is based on a collaborative platform, the _COVID-19 Nowcast Hub_, which we launched soon after the hospitalization incidence became the guideline value for the German pandemic policy. It served to collect and combine real-time nowcasts from several models on a daily basis. The approach builds upon the _COVID-19 Forecast Hubs_, which during the pandemic were run in the US \[[17](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref017)\], Germany and Poland \[[18](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref018)\], and later the entire European Economic Area, Switzerland and the UK \[[19](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref019)\]. These Hubs showed that combining different epidemiological models into an ensemble can produce more robust predictions, confirming results from forecasting challenges like _FluSight_ on seasonal influenza \[[20](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref020)\]. We aimed for compatibility with the Forecast Hub ecosystem in many technical and methodological aspects, in particular by following the same submission format and evaluation criteria \[[21](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref021)\]. This way we contribute to a growing evidence base on predictive epidemic modeling in real time.

The remainder of the manuscript is structured as follows. In Section 2, we introduce the 7-day hospitalization incidence as defined by RKI and outline the agreed-upon nowcast targets. We present the individual nowcasting methods and ensemble approaches, as well as the prespecified evaluation criteria. Section 3 presents the results of our formal performance evaluation, followed by qualitative observations on periods of unusual reporting patterns or the emergence of a new variant. We then assess the impact of model revisions as well as the sensitivity of the results to the exact definition of the nowcast target. Section 4 concludes with a discussion.

## 2 Methods

To facilitate a transparent assessment, we preregistered our evaluation study, specifying the criteria to assess the submitted nowcasts. The study protocol was deposited at the registry of the Open Science Foundation on 23 November 2021 \[[22](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref022)\]. In some instances, we had to deviate from the protocol. These are detailed in the respective subsections and summarized in Table A1 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001).

### 2.1 Definition of the COVID-19 7-day hospitalization incidence

Data on the German COVID-19 hospitalization incidence was published in a daily rhythm by Robert Koch Institute \[[23](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref023)\]. By its official definition \[[24](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref024)\], it is given by the number of hospitalized COVID-19 cases among cases reported over a 7-day period relative to 100,000 inhabitants. As illustrated in [Fig 2](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g002), hospitalizations are thus aggregated by the case reporting date, more precisely, when a case was digitally registered by a local health authority, rather than the date of hospital admission (though the two may coincide). We will refer to this case reporting date as the _reference date_ in the following. We note that the hospitalization is not required to occur during the 7-day window mentioned previously, nor is COVID-19 required to be the main reason for hospitalization. When new hospitalizations are added to the record, they may thus change the value of the 7-day hospitalization incidence for past periods, depending on how much time has passed between the positive test, the time of hospitalization, and ultimately its reporting. Therefore, the initially reported value of the hospitalization incidence is merely an approximation and tends to be lower than the actual value.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g002)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g002)

Fig 2. Illustration of 7-day hospitalization incidences via individual-level timelines.

The reference date by which hospitalizations are counted is the date when the positive test of an ultimately hospitalized person is reported (green dots). However, hospitalizations only become known after they take place (red triangles) and are reported (blue squares). Individuals A-E are included in the 7-day hospitalization incidence of date _t_ because their reference date falls within a 7-day window from _t_ − 6 until _t_, even though some are reported as hospitalized later (individuals D and E). These hospitalizations only appear in the data with a delay and thus need to be predicted using a nowcasting method on day _t_. In principle, it is also possible that positive test, hospitalization and reporting all take place on the same day, as for individual C. In this case, there is no delay problem. We note that even though individuals F and G are hospitalized or reported within the period _t_ − 6 to _t_, they are not counted in the 7-day hospitalization incidence for day _t_ because the positive test is reported before _t_ − 6. Individual H is not included because its reference date is after _t_.

[https://doi.org/10.1371/journal.pcbi.1011394.g002](https://doi.org/10.1371/journal.pcbi.1011394.g002)

To illustrate the extent of these revisions, [Fig 3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g003) shows the fraction of the 7-day hospitalization incidence that was reported 0–70 days after the respective reference date. Same-day values covered 50–60% of the ultimately reported hospitalizations, with a slight upward trend over the study period (left panel). Around 85% were reached after 14 days and even after 70 days, there were upward corrections of more than 3%. As illustrated in the second panel, same-day reporting completeness varied considerably across states. In Bremen (HB) it exceeded 75%, whereas it was below 50% in Saxony (SN) and Hamburg (HH). Reporting completeness was also variable across age groups and weekdays (third and fourth panels). A detailed display of temporal variations in initial reporting completeness across states can be found in Fig A1 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001). It should be noted that initial reporting completeness can also depend on the overall strain on the health system, and delays tend to be longer in times of high caseloads \[[25](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref025)\].

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g003)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g003)

Fig 3. Completeness of 7-day hospitalization incidences 0 to 70 days after the respective reference date.

First panel: temporal development over the considered study period, aggregated over states and age groups. Second: by state, ordered by initial reporting completeness (see Fig A1 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001) for the definition of abbreviations). Third: by age group. Fourth: by weekday.

[https://doi.org/10.1371/journal.pcbi.1011394.g003](https://doi.org/10.1371/journal.pcbi.1011394.g003)

As mentioned before, thresholds of 3, 6, and 9 per 100,000 population were introduced in the fall of 2021 and used to determine the necessary extent of non-pharmaceutical interventions \[[15](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref015)\]. These were applied to the initial value of the hospitalization incidence as reported on the respective day without any retrospective completion. This value is also referred to as the _frozen value_. For illustration, these frozen values were added to [Fig 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g001) (light gray line). We note that due to the temporal and geographic differences shown in [Fig 3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g003), the same frozen value can translate to rather different final values of the hospitalization incidence.

### 2.2 Nowcast targets and study period

The goal of the collected nowcasts was to predict how much the preliminary values of the hospitalization incidence were still going to change. Specifically, on each day during the period from Monday 22 November 2021 to Friday 29 April 2022, a prediction needed to be issued for the final value the 7-day hospitalization incidence would take for that day and the previous 28 days. In the study protocol, we defined the final state to be predicted as the time series available on 8 August 2022. This date was chosen to be 100 days after the end of our study period. Originally, teams were asked to provide nowcasts for all working days of the study period, excluding a Christmas break. However, as all teams fully automated their approaches, we were able to collect nowcasts on weekends and public holidays and include them in the study.

Teams were asked to issue nowcasts for the national level as well as for the 16 German states and seven different age groups (as available in public RKI data; 00–04, 05–14, 15–34, 35–59, 60–79 and 80+ years). No age-specific nowcasts at the state level were generated. To quantify prediction uncertainty, a probabilistic format was adopted, where teams had to submit seven quantiles (2.5%, 10%, 25%, 50%, 75%, 90%, 97.5%) of the predictive distribution in addition to the mean. Following the procedure in the various COVID-19 Forecast Hubs, our main analysis examined all outcomes on their original count scales, i.e. not standardized by population. This means that the relative size of states or age strata is reflected in the weight they receive in the overall evaluation \[[21](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref021)\].

In the study protocol, we also defined a retrospective study period reaching from 1 July 2021 to 19 November 2021. The motivation was to compare the retrospective performance on historical data available during model development to prospective performance under real-world conditions. However, due to time constraints, only two teams provided complete sets of retrospective nowcasts prior to the beginning of the prospective study. We therefore chose to omit this aspect. Instead, we added an evaluation of retrospective nowcasts from four revised models to the main study period from 22 November 2021 to 29 April 2022.

### 2.3 Overview of models

Nowcasts from eight independently run models were collected for the duration of our study. Six of them were contributed by groups of academics, one by the Robert Koch Institute (RKI) and one by the data science team of the newspaper _Süddeutsche Zeitung_ (SZ). A short description of the different methods is provided in [Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-t001) (see also \[[26](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref026)–[32](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref032)\]). Most approaches took preliminary hospitalization numbers as their only input, applying various techniques to model delay distributions and the underlying time series of hospitalizations. Only the ILM model took a different approach by including the number of confirmed cases as an explanatory variable. Approaches also differed in terms of the methods used for inference, uncertainty quantification, the flexibility and complexity of their delay distribution and time series models, as well as the maximum delay considered (ranging from 35 to 84 days). Some models obtained nowcasts at a coarser spatial or age resolution by hierarchically aggregating nowcasts generated for finer strata. Models were typically not fitted to the entire available data set, but only a recent subset, the size of which again differed by team.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.t001)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.t001)

Table 1. Description of contributed nowcast models.

[https://doi.org/10.1371/journal.pcbi.1011394.t001](https://doi.org/10.1371/journal.pcbi.1011394.t001)

### 2.4 Ensemble approaches

On a daily basis, all submissions that were available at 2pm were combined to generate an ensemble nowcast, see [Fig 4](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g004) for an illustration. We created the two following ensembles.

-   For the MeanEnsemble each predictive quantile was obtained as the arithmetic mean of the respective quantiles of the member nowcasts. The ensemble mean was obtained as the mean of the submitted predictive means.
-   For the MedianEnsemble the same procedure was applied using the median rather than the arithmetic mean for aggregation.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g004)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g004)

Fig 4. Illustration of an ensemble approach.

A set of individual nowcasts can be combined into an ensemble nowcast with different aggregation approaches. Here, the ensemble is computed as the quantile-wise mean of all nowcasts.

[https://doi.org/10.1371/journal.pcbi.1011394.g004](https://doi.org/10.1371/journal.pcbi.1011394.g004)

This direct aggregation at the level of quantiles rather than, e.g., probability density functions, is known as _Vincentization_ \[[33](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref033)\]. A discussion of its properties and differences to the aggregation of density functions can be found in \[[34](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref034)\]. As the expected number of contributed models was moderate, the MeanEnsemble was expected to be better-behaved than the MedianEnsemble, which can produce oddly shaped distributions in such settings \[[18](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref018)\]. The MeanEnsemble was therefore prespecified as the primary ensemble approach (unlike in e.g. \[[17](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref017)\] or \[[18](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref018)\]).

We note that when using these aggregation approaches, quantile crossing can occur, meaning that the reported quantiles may not consistently increase with their nominal level \[[35](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref035)\]. To address this, one straightforward approach is to sort the quantiles in ascending order, which can improve the overall performance and coherence of the ensemble nowcasts \[[36](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref036)\]. Regrettably, this consideration was overlooked in our real-time ensemble, leading to some instances of quantile crossing. These were primarily caused by missing entries for a specific quantile level in one of the member models, as mentioned in Table A4 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001). As this occurred only in a small fraction of instances, we consider the impact on overall results negligible.

### 2.5 Evaluation metrics

_Proper scoring rules_ are an established tool to evaluate probabilistic forecasts \[[37](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref037)\], or, in our setting, nowcasts. They are constructed such that they encourage honest forecasting, i.e., forecasters optimize their expected score by reporting their true beliefs about the future. Put differently, there is no way of “gaming” the system and obtaining improved scores by reporting modified versions of one’s actual prediction. As in our setting nowcasts consist of three nested central prediction intervals, a natural choice is the interval score \[[37](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref037)\]. For an interval \[_l_, _u_\] at the level (1 − _α_), _α_ ∈ (0, 1), reaching from the \- to the \-quantile of the predictive distribution _F_, it is defined as (1) where  is the indicator function and _y_ is the realized value. Here, the first term characterizes the spread of the predictive distribution, the second penalizes overprediction (observations fall below the prediction interval) and the third term penalizes underprediction. To assess all submitted quantiles of the predictive distribution jointly we use the weighted interval score (WIS; \[[21](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref021)\]), which is a weighted average of interval scores at different nominal levels and the absolute error. For _N_ nested prediction intervals it is defined as (2) where _m_ is the predictive median and in our setting _N_ = 3 and _α_1 = 0.5, _α_2 = 0.2, _α_3 = 0.05. We note that it is equivalent to the mean pinball loss across the respective quantile levels, which is often employed in quantile regression \[[21](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref021)\]. The WIS approximates the widely used continuous ranked probability score (CRPS) and can be interpreted as a generalization of the absolute error to probabilistic predictions. It is negatively oriented, meaning that lower values are better. The decomposition of the interval score into spread, overprediction, and underprediction also translates to the WIS and can be used to enhance the interpretability of results.

To put results into perspective, we defined the simplistic baseline model FrozenBaseline which applies no correction and just issues the current data version as its deterministic nowcast (i.e., with all quantiles set to the same value). This allowed us to compute relative scores  characterizing the improvement over the uncorrected time series. Here, lower values are better, and values below 1 imply that the nowcasts reduce the error of the uncorrected time series. We note that while the study protocol specified that a baseline model was to be included, its definition was only agreed upon later. We note that the KIT model was originally conceived as a baseline model, but later considered too complex for this purpose; in the preregistration, it is therefore referred to as a “reference model”.

To assess the central tendency of nowcasts we used the mean absolute error for predictive medians and the mean squared error for predictive means (i.e., for each functional we use the respective _consistent scoring function_ \[[38](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref038)\]). To evaluate calibration, i.e., the statistical consistency between nowcasts and observations, we consider the empirical coverage of the 50% and 95% prediction intervals,  In case of missing submissions, i.e., if a team failed to provide a nowcast on a given day, nowcasts could be filled in retrospectively. To assess whether this had a substantial impact on the comparative evaluation, we applied a pairwise comparison scheme as described in \[[17](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref017)\] to compare models using only the sets of nowcast tasks treated in real time by each model. Details can be found in Section D in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001).

## 3 Results

### 3.1 Completeness of submissions

All participating teams produced nowcasts over the entire study period and only rarely failed to submit nowcasts in time (see Table A2 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001)). In most cases, missing nowcasts were filled in retrospectively. In very few cases (0.3% of all targets; see Table A3 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001)) it was not possible to obtain submissions from all teams; to handle these cases we chose to slightly deviate from the study protocol and omit the respective targets in our evaluation. The ILM model did not provide state-level nowcasts, while the RKI model did not include age-stratified results. Moreover, the RKI model only provided point nowcasts and two quantiles in real time (at levels 2.5% and 97.5%); the remaining quantiles were only provided in retrospect. We encountered some more minor difficulties, e.g., due to missing quantiles for certain targets; we summarize these and the chosen solutions in Table A4 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001).

### 3.2 Visual inspection of nowcasts

For a first impression of nowcast performance, [Fig 5](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g005) shows same-day nowcasts at the national level (i.e., at each date the respective nowcast with a horizon of 0 days is shown). [Fig 6](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g006) shows the same for nowcasts 14 days back in time (i.e., for each day the nowcast issued 14 days later is shown). Displayed are the median predictions along with the central 50% and 95% prediction intervals. The light gray line shows the data as available when the nowcast was issued (which in [Fig 5](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g005) corresponds to the _frozen values_), and the red line shows the respective final value as available on 8 August 2022. In both figures, it can be seen that nowcasts from all models are generally close to the final values to be predicted. However, considerable variability in interval widths is apparent, ranging from rather wide (KIT) to very narrow intervals (LMU, RKI). Some models, in particular KIT and SZ, display pronounced weekday patterns in their same-day nowcasts, which to a lower degree also carry through to the ensemble nowcasts. For the nowcasts 14 days back in time we observe a slight downward bias in the central tendency, the only exception being the ILM model. As most of the concerned models moreover feature quite narrow prediction intervals, these often do not cover the final values.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g005)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g005)

Fig 5. Nowcasts with a horizon of 0 days back.

Same-day nowcasts of the 7-day hospitalization incidence as issued on each day of the study period. Nowcasts are shown for the German national level.

[https://doi.org/10.1371/journal.pcbi.1011394.g005](https://doi.org/10.1371/journal.pcbi.1011394.g005)

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g006)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g006)

Fig 6. Nowcasts with a horizon of 14 days back.

Nowcasts of the 7-day hospitalization incidence as issued 14 days after the respective date. Nowcasts are shown for the German national level.

[https://doi.org/10.1371/journal.pcbi.1011394.g006](https://doi.org/10.1371/journal.pcbi.1011394.g006)

### 3.3 Formal evaluation

To consolidate the qualitative findings from the previous section, we turn to a formal evaluation and consider evaluation scores and interval coverage rates. [Fig 7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g007) displays the mean and relative WIS values achieved by different models for the three considered aggregation levels (national level, states, and age groups). The left column shows mean scores (on the absolute and relative scale) across all strata and horizons, decomposed into contributions of spread, underprediction, and overprediction. The middle and right panels show the mean WIS and relative WIS by horizon, respectively (-28 to 0 days; see Section 2.5). At the national level and across age groups, the overall scores of the ILM model were considerably lower than the scores of all other models. The stratification by horizon indicates that it performed especially well for nowcasts seven or more days back. For the most recent days (-3 to 0 at the national level, -6 to 0 for age groups) the MeanEnsemble performed best. Across states, the MeanEnsemble outperformed the other models for horizons of -11 to 0 days. For horizons of -28 to -12 days, the KIT model achieved the best scores, which (by a narrow margin) led to the best overall result pooled across horizons. The relative scores indicate that, pooled over all horizons, most models were able to reduce the error of the uncorrected time series (FrozenBaseline) by roughly 80% (relative WIS of 0.2), while the ILM model achieved a reduction of about 90% (relative WIS 0.1). It is notable that ILM achieved almost constant improvements across horizons, while the improvements achieved by the other models were quite modest for horizons further into the past. To allow for a more detailed exploration of results we provide a display of the distribution of model ranks across individual nowcasting tasks (Fig A7 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001)) and of scores over time (Fig A11 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001)). Similarly to \[[17](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref017)\], we find that the MeanEnsemble reliably achieved above-average performance across all locations and age groups (almost never ranking in the bottom). Additionally, stratified results by day of the week are shown in Fig A8 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001). For KIT and SZ, which did not account for weekday effects, we indeed observe performance differences for different weekdays. Fig A9 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001) further shows nowcasts by KIT as issued on different weekdays, with a tendency for underprediction on Mondays and many cases of overprediction on Fridays or Saturdays. As seen in Fig A10 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001), ILM on the other hand did not exhibit any such differences by weekday.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g007)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g007)

Fig 7. Score-based performance.

Shown is the mean WIS for the national level (top) and averaged across states (middle) and age groups (bottom). The first panel in each row displays the average across all horizons (on the absolute and relative scales). The decomposition into nowcast spread, underprediction, and overprediction (see Section 2.5) is represented by blocks of different color intensities. The absolute error is indicated by a diamond (⋄). The second and third panels in each row show the mean WIS and the relative WIS, respectively, stratified by horizon.

[https://doi.org/10.1371/journal.pcbi.1011394.g007](https://doi.org/10.1371/journal.pcbi.1011394.g007)

Figs A4 and A5 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001) summarize results in terms of mean absolute errors of predictive medians and mean squared errors of predictive means in the same format as in [Fig 7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g007). The ILM model again performed favorably. Among the remaining models, RIVM shows good performance, in many cases outperforming the ensembles. The KIT model, on the other hand, which performed relatively well on WIS, achieved below-average results.

Empirical coverage rates of the 50% and 95% prediction intervals are displayed in [Fig 8](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g008). Results are stratified by aggregation level (national, states, age groups) and nowcast horizon (-28 days to 0 days). The best calibration was achieved by the ILM model, with coverage rates close to the nominal levels at most horizons. Only for short horizons of -10 to 0 days coverage dropped moderately. In contrast, the KIT model achieved higher coverage rates for horizons between -4 and 0 days, which considerably dropped for nowcasts further into the past. All other models were overconfident and did not reach the respective nominal coverage levels. As for KIT, coverage was lower for nowcasts further back in time, for some models to a point where only a few observations were covered at -28 days.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g008)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g008)

Fig 8. Empirical coverage of the prediction intervals.

Shown is the coverage for the national level (top), across states (middle), and across age groups (bottom). The first panel in each row displays the overall coverage of the 50% and 95% prediction intervals across all horizons. The second and third panels in each row show the empirical coverage of the 50% and 95% prediction intervals, respectively, stratified by horizon. The dashed lines indicate the desired nominal levels.

[https://doi.org/10.1371/journal.pcbi.1011394.g008](https://doi.org/10.1371/journal.pcbi.1011394.g008)

To assess the impact of retrospective fill-in nowcasts for missing submissions, we recomputed relative WIS values using only real-time submissions and the pairwise comparison scheme from \[[17](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref017)\]. As can be seen from Table A5 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001) the results barely change, indicating that fill-in nowcasts did not have a relevant impact on overall scores. Furthermore, as designated in the study protocol, we reran the evaluation using hospitalization incidences per 100,000 population rather than absolute hospitalization counts. The results are displayed in Fig A12 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001) and do not differ qualitatively from those in [Fig 7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g007).

As we consider the nowcasts for the most recent days the most relevant from a public health perspective, we conclude with an additional non-preregistered summary of scores across horizons -7 to 0 days. [Fig 9](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g009) shows the average weighted interval scores and interval coverage rates. For this subset of nowcasting tasks, the MeanEnsemble outperformed the individual models in all three categories, closely followed by ILM. The KIT model reaches close to nominal coverage, while the other models are again overconfident.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g009)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g009)

Fig 9. Scores and coverage on short horizons.

Shown are the mean WIS with absolute errors (top) and the empirical coverage (bottom) across horizons from 0 to -7 days.

[https://doi.org/10.1371/journal.pcbi.1011394.g009](https://doi.org/10.1371/journal.pcbi.1011394.g009)

### 3.4 Interpretation of evaluation results

As some of the presented results may seem contradictory at first sight, we provide some additional interpretations. Firstly, the opposing trends in absolute and relative WIS across horizons in [Fig 7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g007) can be interpreted as follows. All nowcasts—including the FrozenBaseline—get closer to the later observed final value as time passes and more complete data accumulates; thus, the absolute WIS decreases. However, most models seemed to have more difficulties predicting the small number of late additions than the bulk of early additions, leading to higher relative WIS. A possible explanation is that modelers needed to make a choice on which maximum delay to take into account. In light of [Fig 3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g003), the values of around 40 days as chosen by most teams may have been too low and led models to ignore a non-negligible fraction of hospitalizations still to be added. As can be seen from [Fig 5](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g005), the resulting bias got largely absorbed in the overall uncertainty for same-day nowcasts. For the horizon of -14 days ([Fig 6](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g006)), on the other hand, it caused a visible shift between nowcasts and final values, which likewise led to insufficient coverage of prediction intervals.

The maximum delay chosen may also explain why the ILM model, which used a value of 80 rather than 40 days, was the best-performing individual method. However, the model also differed from the others in its general approach, using a regression on case incidences in addition to preliminary hospitalization numbers. We will attempt to shed more light on this aspect in Section 3.6. As a last relevant difference to most other models, the ILM approach based uncertainty intervals directly on the errors of past real-time nowcasts, an approach close to the idea of conformal prediction \[[39](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref039)\]. A similar approach was also taken by the KIT model (see Section E in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001)). The fact that these two models achieved the best calibration indicates that this approach may quantify nowcast uncertainty more realistically than standard model-based uncertainty intervals.

The decomposition of the WIS into components for spread, overprediction, and underprediction \[[21](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref021)\], displayed in the left column of [Fig 7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g007), is informative on the challenges the different approaches faced. Penalties for underprediction make up a very large part of the overall scores for all models except for ILM. This confirms the observation of a downward bias from [Fig 6](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g006).

The best-performing individual models ILM and KIT issued predictive distributions with higher variability than the other models, indicated by the larger spread component. As can be seen from the diamond symbols in [Fig 7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g007) and in more detail from Fig A4 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001), the KIT model did not issue particularly accurate point predictions (predictive medians). A likely reason is the lack of weekday effects, see Figs A8 and A9 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001). Its lower WIS values were primarily a result of better uncertainty quantification.

### 3.5 Impact of unusual reporting patterns and changes in virus properties

The nowcasting models in our study assumed either that the probability of hospitalization given a positive test remains roughly constant (the ILM model) or that the delay distribution in hospitalizations does so (all other models). In [Fig 10](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g010), we therefore show four examples where these assumptions were violated. In mid-November 2021, hospitals in Saxony were overwhelmed \[[40](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref040)\], leading to disruptions in the reporting system. As a consequence, initial reporting completeness dropped rather suddenly. This led the majority of models to underpredict, leading to an ensemble nowcast that was too low, as illustrated in [Fig 10A](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g010). We note that in this instance we were aware that nowcasts for Saxony were likely unreliable and issued a warning on our website. [Fig 10B](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g010) shows an unusual reporting pattern from the state of Bremen from early 2022. Here, a relevant number of reported hospitalizations got removed from the record on 12 and 13 January, presumably due to faulty initial reporting. Nowcasts issued up to 11 January were thus considerably above the final data version from 8 August. [Fig 10C and 10D](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g010) show issues arising after the Easter weekend of 2022, when initial reporting was considerably lower than usual. As can be seen in [Fig 10C](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g010), this led to too low ensemble nowcasts on Tuesday, 19 April. Also, over the following days, it seems to have caused issues in the fitting of certain models. As an example, [Fig 10D](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g010) shows the Epiforecasts output for Lower Saxony on 20 April. It features an excessively wide prediction interval, likely as a reaction to rapidly shifting delay distributions in the previous days. The MeanEnsemble, shown in green, was strongly affected by this unusual behavior of a member nowcast, while the more robust MedianEnsemble remained unaffected.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g010)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g010)

Fig 10. Examples of time points when delay distributions were subject to sudden changes.

**(A)** Saxony, nowcast made on 22 November 2021: overwhelmed hospitals lead to severe underreporting and thus too low nowcasts. **(B)** Bremen, nowcast made on 11 January 2022: some incorrect entries got removed from the records, resulting in a downward correction and thus too high nowcasts. **(C)** Germany, nowcast made on 19 April 2022: following the Easter weekend with lower than usual initial reporting coverage, nowcasts were considerably too low. **(D)** Lower Saxony, nowcasts made on 20 April: after the Easter weekend, Epiforecasts issued very wide nowcast intervals, presumably due to numerical problems. The dashed lines indicate the time when the nowcasts were made. (Incidentally, in example (A), the horizons of 0 days and 1 day back were missing, see Table A3 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001)).

[https://doi.org/10.1371/journal.pcbi.1011394.g010](https://doi.org/10.1371/journal.pcbi.1011394.g010)

A last noteworthy particularity is the behavior of the ILM model in January 2022, following the transition from the Delta to the Omicron variant. The Omicron variant is known to have lower clinical severity than the Delta variant \[[41](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref041)\], meaning that during the transition the ratio of hospitalizations and confirmed cases gradually declined. For the ILM model, which assumes this ratio to remain constant, this led to an upward bias in nowcasts, which can be discerned from [Fig 5](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g005) as an upward bump not present in the other models.

### 3.6 Retrospective variations of models

We next aim to shed some more light on how different modeling choices impact performance and how learnings from our study period facilitated the improvement of methods. To this end, we assess the performance of four variations of previously discussed models, which were applied retrospectively:

-   The LMU team implemented a new approach to generate uncertainty intervals, which like the ILM and KIT methods is based on past nowcast errors.
-   The RKI team obtained nowcasts by aggregating over finer strata and originally assumed independence across strata to generate prediction intervals at the aggregate level. This was changed to an assumption of strong correlations across strata, leading to wider prediction intervals.
-   The KIT team reran its model with an increased maximum delay of 80 days, in contrast to the 40 days used in real time. This also required an increased length of training data, which was set to 100 days.
-   Conversely, the ILM model was rerun with a maximum delay of 42 rather than 84 days, which is comparable to the maximum delays used by the remaining models. This was not meant as an improvement but as an adjustment to assess the impact of longer/shorter maximum delays.

The results are shown in [Fig 11](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g011). They indicate improvements across all aggregation levels and horizons for the revised LMU, RKI, and KIT models. In particular across age groups, the KIT model now came close to the performance the ILM model achieved in real time. The coverage proportion of prediction intervals was increased for all three models, with the updated KIT model even leaning towards over-coverage (too wide intervals). The LMU and RKI models, on the other hand, remained overconfident. Decreasing the maximum delay in the ILM model slightly reduced the overall performance on the national level, while average scores across age groups remained almost unchanged. The score decomposition shows that the adjusted model tended to underpredict (similarly to the other models), while the original model tended to overpredict. Possible explanations will be discussed in Section 4.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g011)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g011)

Fig 11. Evaluation of retrospective model variations.

Comparison of variations of the ILM, KIT, LMU, and RKI models and the same models as submitted in real time. Shown are the mean WIS with absolute errors (top) and the empirical coverage (bottom). Results are comparable to those from Figs [7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g007) and [8](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g008).

[https://doi.org/10.1371/journal.pcbi.1011394.g011](https://doi.org/10.1371/journal.pcbi.1011394.g011)

### 3.7 Sensitivity of results to definition of final data

In our study protocol, we specified that the final state of the time series to be predicted was the version available on 8 August 2022, i.e., 100 days after the end of the study period. However, as we became aware of the fact that data revisions could occur with considerably longer delays than initially expected, we performed a sensitivity analysis to assess the impact of this choice. [Fig 12](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g012) shows how the average WIS aggregated over horizons and different levels of stratification (i.e., the results shown in the left column of [Fig 7](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g007)) change when using a different data version as the final one. It can be seen that the average scores of all models, except for ILM, increase in parallel as newer data versions are used. The increase for KIT is slightly more gradual. This is because these models tend to underpredict, and as time passes and more additions are made to the data, this problem is exacerbated. For the ILM model, which tends to overpredict, average scores initially decline and then plateau, leading to an even more pronounced lead relative to the other models. As can be seen from Fig A6 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001), using a later data version for evaluation, ILM ultimately also surpasses the ensemble when restricting results to horizons 0 to 7 days back.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g012)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g012)

Fig 12. Sensitivity of the scores to the chosen “final” data.

Shown is the mean WIS computed with different data versions as the target. The version prespecified in the study protocol is 8 August 2022, marked by a vertical line. Top left: national level. Top right: averaged over states. Bottom left: averaged over age groups. The bottom right panel overlays the national-level data as of 8 August and 31 December to illustrate the importance of late revisions.

[https://doi.org/10.1371/journal.pcbi.1011394.g012](https://doi.org/10.1371/journal.pcbi.1011394.g012)

The original target allowed revisions until the final date of 8 August 2022, meaning that for different reference dates, adjustments could be made over time periods of different lengths (e.g., the hospitalization incidence for the first reference date in our study period could be completed over a longer time than that of the last reference date). Denoting the hospitalizations for reference date _t_ reported with a delay of _d_ days by _x__t_,_d_, the nowcasting target _y__t_ can formally be written as  where the first sum represents a 7-day window ending in date _t_ and the second sum accumulates the hospitalizations with reference date _t_ − _i_ reported until .

An alternative to choosing one specific data version as the nowcast target is a “rolling” approach that considers delayed reports for each reference date _t_ up to a specified maximum delay _D_. The nowcast target _z__t_ then becomes  In this case, the data for each reference date has the same amount of time to be revised. See Fig A3 in [S1 Appendix](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.s001) for an illustration of these differently defined target time series. [Fig 13](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g013) shows the results this approach yields for a maximum delay of 40 days, which corresponds roughly to the maximum delay used by most teams. As this target definition is better aligned with the practical implementations teams chose, it is not a surprise that the mean WIS values are lower and coverage is higher. The ILM model (in its adjusted version with a maximum delay of 42 days) now shows quite similar performance to the other approaches, with a tendency to overpredict. The score components for the other models are more balanced and the ensemble nowcasts clearly lead the field. Retrospectively, we think that this definition of targets might have been a more coherent and operationally meaningful approach, see Section 4 for a discussion.

Download:

-   [
    
    PNG
    
    larger image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=large&id=10.1371/journal.pcbi.1011394.g013)
-   [
    
    TIFF
    
    original image
    
    ](https://journals.plos.org/ploscompbiol/article/figure/image?download&size=original&id=10.1371/journal.pcbi.1011394.g013)

Fig 13. Performance based on the alternative target with a maximum delay of 40 days.

Shown are the mean WIS with absolute errors (top) and the empirical coverage (bottom) computed with respect to a revised target defined as the number of hospitalizations reported with a delay of up to 40 days. For the ILM model we used the revised model with a maximum delay of 42 days and also recomputed the ensembles with these revised nowcasts. For the other models, the assumed maximum delays are approximately aligned with the redefined target, see [Table 1](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-t001).

[https://doi.org/10.1371/journal.pcbi.1011394.g013](https://doi.org/10.1371/journal.pcbi.1011394.g013)

## 4 Discussion

In this paper, we presented results from a preregistered study to evaluate probabilistic real-time nowcasts of the 7-day hospitalization incidence in Germany from November 2021 to April 2022. We found that all models were able to correct for a large part of the biases caused by reporting delays. Further, we identified calibration of uncertainty intervals as a major challenge, as the empirical coverage rates achieved by most models were considerably below the respective nominal levels. Reasons for insufficient coverage likely include too inflexible modeling of dispersion and delay distributions, and also the fact that most teams truncated delay distributions at a too short maximum delay. The exception was the ILM model which also stood out in terms of score-based performance for the national level and across age groups, and to a lesser degree the KIT model. These two models incorporated uncertainty quantification using past real-time nowcast errors which proved advantageous when compared to the standard model-based uncertainty intervals.

Our analyses from Sections 3.6 and 3.7 suggest that the success of the ILM model arose from the interplay of two aspects. On the one hand, it used a maximum delay that is longer than those of the other models, but, judging by [Fig 3](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi-1011394-g003), still somewhat too short. On the other hand, the model appears to have a tendency to slightly overpredict the number of hospitalizations added up to a given maximum delay. As these two aspects work in different directions, the resulting nowcasts are overall well-aligned with the defined target (data version from 8 August 2022). Whether nowcasts taking into account case incidence inherently perform better needs to be explored in future work. A combination of different data streams may reduce the dependence of nowcasts on certain assumptions, such as the constant completeness of initial reports. The Epiforecasts and SU models have been extended in this direction. In an application to COVID-19 deaths in Sweden \[[42](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref042)\], the inclusion of reported cases and intensive care admissions as leading indicators indeed led to improved predictions.

The MeanEnsemble, along with the KIT model, performed best across federal states (for which the ILM model did not provide nowcasts). Also, it showed very good relative performance for horizons -7 to 0 days, as well as for the revised “rolling” target. We therefore conclude that ensemble approaches are a promising avenue in order to improve disease nowcasting. However, our case study also illustrates a limitation of unweighted ensembles. The ensemble may have been imbalanced in the sense that a majority of its members followed similar strategies and had similar weaknesses (specifically a downward bias due to neglecting very long delays). A weighted ensemble could have capitalized on the strengths of the ILM model, which followed a conceptually different approach and could have served as a counterbalance. However, it is not obvious how ensemble members can be assigned weights in real time in a nowcasting setting. This represents an interesting future research area.

A difficulty we encountered in terms of our study design is that results depend on which data version is used as the “final” one (i.e., the values against which nowcasts are evaluated; Section 3.7). As the choice of 8 August 2022 was preregistered and known to all participating teams, the prediction task was well-defined, and we stuck to this choice for our main analysis. Nonetheless, this definition, which was based on the assumption that data would be stable after 100 days, turned out not to be ideal in retrospect. In particular, it implies that for the first day of our study period (22 November 2021), retrospective additions could accumulate over 259 days, while for the last (29 April 2022) this was restricted to 100 days. Defining the nowcast target in a “rolling” fashion as explored in Section 3.7 might have been a more appropriate choice. This would have been a more clearly defined modeling task, and modelers would not have had to choose a maximum delay for their models themselves.

The question of whether additions should be ignored from a certain maximum delay onward is closely linked to what these additions actually mean and whether they are relevant from a public health perspective. As mentioned in Section 2.1, the 7-day hospitalization incidence also contains hospitalizations that are not primarily due to COVID-19. These hospitalizations have been found to represent a considerable fraction \[[43](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref043)\]. It seems plausible that very long delays are due to large time differences between the positive test and hospital admission, in which case the share of hospitalizations that are not primarily due to COVID-19 may be high. Also, it can be questioned whether hospitalizations a long time after a positive test are relevant for the real-time assessment of healthcare burden. Both aspects strengthen the case for limiting nowcasting to hospitalizations reported up to a carefully chosen maximum delay.

The definition of the _frozen_ values used by the Robert Koch Institute when applying legally defined thresholds can be seen as a strong form of discarding delayed hospitalizations. It has the advantage of simplicity and unambiguity, which are required for actionable guidelines in a legal context. After all, it seems difficult to integrate complex statistical methods with many tuning parameters into a binding legal document. An important downside, however, is that the same _frozen_ value can mean rather different things at different time points and in different locations, due to differences in initial reporting completeness. We thus argue that outside of purely legal considerations, nowcasts can provide a more thorough picture of current developments.

All nowcasts generated within the presented collaborative project are available in a public repository (see data availability statement). Time-stamped versions of hospitalization data as available at different points in time can be retrieved from the commit history of the repository as well as directly from Robert Koch Institute \[[23](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref023)\]. We hope that this data can be of use as a benchmarking system for future nowcasting methods. In this context, we note, however, that the present paper is a comparison of _nowcasting systems_, which are given by a statistical model, but also various additional analytical choices, in particular the assumed maximum delay and the length of training data used at each time point. These decisions can have a substantial impact on predictive performance (see Section 3.6) and are easier to get right in hindsight than in real time. To ensure a fair comparison, it may therefore be reasonable to use the “rolling” target as discussed in Section 3.7.

The nowcasts produced for this project were routinely displayed by numerous German-speaking media, including _Die Zeit_, _Neue Zürcher Zeitung_ and _Norddeutscher Rundfunk_. While some displays were limited to the point nowcasts (predictive medians), others made the predictive uncertainty clearly visible. This development should be further encouraged by scientists advising the media on the display of epidemiological data and models. In this context, we also note that data journalists were overall hesitant to use the ensemble nowcasts and prioritized individual nowcasts based on methods described in peer-reviewed publications. Interestingly, the best-performing models in our study were the MeanEnsemble and the yet unpublished ILM approach. However, our analyses show that all compared approaches provided a good qualitative impression of current incidence trends and levels, and we consider each of them a helpful addition and improvement over showing uncorrected data.

To conclude, we highlight some advantages of the collaborative nowcasting approach adopted in our study. The ensemble nowcast not only showed strong relative performance but was also the most consistently available nowcast, with almost all other models unavailable due to technical problems on some days during the study period. Additionally, our collaborative approach fostered frequent exchange and interaction among modelers via bi-weekly coordination calls, creating a valuable platform for knowledge sharing, feedback, and collaboration on methodological advancements. Through these interactions, the project facilitated model improvements, as seen for the LMU, RKI and KIT approaches in Section 3.6, and fostered discussion on new methodological topics beyond the scope of the present article. For example, the _Epinowcast community_ ([https://www.epinowcast.org/](https://www.epinowcast.org/)) was established to build and assess real-time analysis tools, publically available in the R package epinowcast \[[26](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#pcbi.1011394.ref026)\]. The benefits of our collaborative approach demonstrate the importance of ongoing communication and cooperation in the development and refinement of epidemiological models, particularly during rapidly evolving public health crises such as infectious disease outbreaks.

## Supporting information

Supplementary material.

Collaborative nowcasting of COVID-19 hospitalization incidences in  
Germany – S1 Appendix  
Daniel Wolffram1, 2, Sam Abbott3, 4, Matthias an der Heiden5, Sebastian Funk3, 4, Felix  
G¨unther6, Davide Hailer1, Stefan Heyder7, Thomas Hotz7, Jan van de Kassteele8, Helmut  
K¨uchenhoff9, 10, S¨oren M¨uller-Hansen11, Diell¨e Syliqi9, Alexander Ullrich5, Maximilian  
Weigert9, 10, Melanie Schienle1, 2, and Johannes Bracher1, 2  
1Chair of Statistical Methods and Econometrics, Karlsruhe Institute of Technology (KIT), Karlsruhe, Germany  
2Computational Statistics Group, Heidelberg Institute for Theoretical Studies (HITS), Heidelberg, Germany  
3Department of Infectious Disease Epidemiology, London School of Hygiene & Tropical Medicine, London, UK  
4Centre for Mathematical Modelling of Infectious Diseases, London School of Hygiene & Tropical Medicine, London,  
UK  
5Robert Koch Institute, Berlin, Germany  
6Department of Mathematics, Stockholm University, Stockholm, Sweden  
7Institute of Mathematics, Technische Universit¨at Ilmenau, Ilmenau, Germany  
8Center for Infectious Disease Control, National Institute for Public Health and the Environment (RIVM),  
Bilthoven, the Netherlands  
9Statistical Consulting Unit StaBLab, Department of Statistics, Ludwig Maximilian University of Munich, Munich,  
Germany  
10Munich Center for Machine Learning (MCML), Munich, Germany  
11S¨uddeutsche Zeitung, Munich, Germany  
1

A Supplementary FiguresSL SN ST TH  
NI NW RP SH  
HB HE HH MV  
BB BE BW BY  
Jan Mar May Jan Mar May Jan Mar May Jan Mar May  
0.00  
0.25  
0.50  
0.75  
1.00  
0.00  
0.25  
0.50  
0.75  
1.00  
0.00  
0.25  
0.50  
0.75  
1.00  
0.00  
0.25  
0.50  
0.75  
1.00  
Fraction of final report  
Days after  
initial report  
70+  
70  
49  
28  
14  
7  
2  
0  
Fig A1: Temporal development of the reporting completeness in the 16 German states. Shown  
is the reported fraction of the final 7-day hospitalization incidences 0 to 70 days after the respective reference  
date. Abbreviations of federal states: BB = Brandenburg, BE = Berlin, BW = Baden-W¨urttemberg, BY  
\= Bavaria, HB = Bremen, HE = Hessen, HH = Hamburg, MV = Mecklenburg-Vorpommern, NI = Lower  
Saxony, NW = North Rhine-Westphalie, RP = Rhineland Pallatinate, SH = Schleswig Holstein, SL =  
Saarland, SN = Saxony, ST = Saxony Anhalt, TH = Thuringia.  
2

[Download](https://ndownloader.figstatic.com/files/41974006)

[

fig**share**

](https://figshare.com/articles/journal_contribution/Supplementary_material_/23934853)

### [S1 Appendix.](https://journals.plos.org/ploscompbiol/article/file?type=supplementary&id=10.1371/journal.pcbi.1011394.s001) Supplementary material.

Additional figures, explanations, and in-depth information.

[https://doi.org/10.1371/journal.pcbi.1011394.s001](https://doi.org/10.1371/journal.pcbi.1011394.s001)

(PDF)

## Acknowledgments

We would like to thank Tilmann Gneiting for his helpful comments and feedback on the evaluation approach.

## References

1.  1\. Giannone D, Reichlin L, Small D. Nowcasting: The real-time informational content of macroeconomic data. Journal of Monetary Economics. 2008;55(4):665–676.
    -   [View Article](https://doi.org/10.1016/j.jmoneco.2008.05.010 "Go to article")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting%3A+The+real-time+informational+content+of+macroeconomic+data+Giannone+2008 "Go to article in Google Scholar")
2.  2\. England PD, Verrall RJ. Stochastic claims reserving in general insurance. British Actuarial Journal. 2002;8(3):443–518.
    -   [View Article](https://doi.org/10.1017/S1357321700003809 "Go to article")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Stochastic+claims+reserving+in+general+insurance+England+2002 "Go to article in Google Scholar")
3.  3\. Cox DR, Medley GF. A process of events with notification delay and the forecasting of AIDS. Philosophical Transactions of the Royal Society of London B, Biological Sciences. 1989;325(1226):135–145. pmid:2572012
    -   [View Article](https://doi.org/10.1098/rstb.1989.0078 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/2572012 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=A+process+of+events+with+notification+delay+and+the+forecasting+of+AIDS+Cox+1989 "Go to article in Google Scholar")
4.  4\. Höhle M, an der Heiden M. Bayesian nowcasting during the STEC O104:H4 outbreak in Germany, 2011. Biometrics. 2014;70(4):993–1002. pmid:24930473
    -   [View Article](https://doi.org/10.1111/biom.12194 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/24930473 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Bayesian+nowcasting+during+the+STEC+O104%3AH4+outbreak+in+Germany%2C+2011+H%C3%B6hle+2014 "Go to article in Google Scholar")
5.  5\. Donker T, van Boven M, van Ballegooijen W, van’t Klooster T, Wielders C, Wallinga J. Nowcasting pandemic influenza A/H1N1 2009 hospitalizations in the Netherlands. European Journal of Epidemiology. 2011;26(3):195–201. pmid:21416274
    -   [View Article](https://doi.org/10.1007/s10654-011-9566-5 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/21416274 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting+pandemic+influenza+A%2FH1N1+2009+hospitalizations+in+the+Netherlands+Donker+2011 "Go to article in Google Scholar")
6.  6\. Menkir TF, Cox H, Poirier C, Saul M, Jones-Weekes S, Clementson C, et al. A nowcasting framework for correcting for reporting delays in malaria surveillance. PLOS Computational Biology. 2021;17(11):e1009570. pmid:34784353
    -   [View Article](https://doi.org/10.1371/journal.pcbi.1009570 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/34784353 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=A+nowcasting+framework+for+correcting+for+reporting+delays+in+malaria+surveillance+Menkir+2021 "Go to article in Google Scholar")
7.  7\. Bastos LS, Economou T, Gomes MF, Villela DA, Coelho FC, Cruz OG, et al. A modelling approach for correcting reporting delays in disease surveillance data. Statistics in Medicine. 2019;38(22):4363–4377. pmid:31292995
    -   [View Article](https://doi.org/10.1002/sim.8303 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/31292995 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=A+modelling+approach+for+correcting+reporting+delays+in+disease+surveillance+data+Bastos+2019 "Go to article in Google Scholar")
8.  8\. McGough SF, Johansson MA, Lipsitch M, Menzies NA. Nowcasting by Bayesian Smoothing: A flexible, generalizable model for real-time epidemic tracking. PLOS Computational Biology. 2020;16(4):e1007735. pmid:32251464
    -   [View Article](https://doi.org/10.1371/journal.pcbi.1007735 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/32251464 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting+by+Bayesian+Smoothing%3A+A+flexible%2C+generalizable+model+for+real-time+epidemic+tracking+McGough+2020 "Go to article in Google Scholar")
9.  9\. Günther F, Bender A, Katz K, Küchenhoff H, Höhle M. Nowcasting the COVID-19 pandemic in Bavaria. Biometrical Journal. 2021;63(3):490–502. pmid:33258177
    -   [View Article](https://doi.org/10.1002/bimj.202000112 "Go to article")
    -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/33258177 "Go to article in PubMed")
    -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting+the+COVID-19+pandemic+in+Bavaria+G%C3%BCnther+2021 "Go to article in Google Scholar")
10.  10\. Seaman SR, Samartsidis P, Kall M, De Angelis D. Nowcasting COVID-19 deaths in England by age and region. Journal of the Royal Statistical Society: Series C (Applied Statistics). 2022;71(5):1266–1281. pmid:35942006
     -   [View Article](https://doi.org/10.1111/rssc.12576 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/35942006 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting+COVID-19+deaths+in+England+by+age+and+region+Seaman+2022 "Go to article in Google Scholar")
11.  11\. Jersakova R, Lomax J, Hetherington J, Lehmann B, Nicholson G, Briers M, et al. Bayesian imputation of COVID-19 positive test counts for nowcasting under reporting lag. Journal of the Royal Statistical Society: Series C (Applied Statistics). 2022;71(4):834–860. pmid:35601481
     -   [View Article](https://doi.org/10.1111/rssc.12557 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/35601481 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Bayesian+imputation+of+COVID-19+positive+test+counts+for+nowcasting+under+reporting+lag+Jersakova+2022 "Go to article in Google Scholar")
12.  12\. Li T, White LF. Bayesian back-calculation and nowcasting for line list data during the COVID-19 pandemic. PLOS Computational Biology. 2021;17(7):1–22. pmid:34252078
     -   [View Article](https://doi.org/10.1371/journal.pcbi.1009210 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/34252078 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Bayesian+back-calculation+and+nowcasting+for+line+list+data+during+the+COVID-19+pandemic+Li+2021 "Go to article in Google Scholar")
13.  13\. Hawryluk I, Hoeltgebaum H, Mishra S, Miscouridou X, Schnekenberg RP, Whittaker C, et al. Gaussian process nowcasting: application to COVID-19 mortality reporting. In: Proceedings of the Thirty-Seventh Conference on Uncertainty in Artificial Intelligence. vol. 161 of Proceedings of Machine Learning Research. PMLR; 2021. p. 1258–1268.
     
14.  14\. Greene SK, McGough SF, Culp GM, Graf LE, Lipsitch M, Menzies NA, et al. Nowcasting for Real-Time COVID-19 Tracking in New York City: An Evaluation Using Reportable Disease Data From Early in the Pandemic. JMIR Public Health Surveill. 2021;7(1):e25538. pmid:33406053
     -   [View Article](https://doi.org/10.2196/25538 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/33406053 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting+for+Real-Time+COVID-19+Tracking+in+New+York+City%3A+An+Evaluation+Using+Reportable+Disease+Data+From+Early+in+the+Pandemic+Greene+2021 "Go to article in Google Scholar")
15.  15\. German Federal Government. Videoschaltkonferenz der Bundeskanzlerin mit den Regierungschefinnen und Regierungschefs der Länder am 18. November 2021; 18 November 2021 \[Cited 19 July 2023\]. Available from: [https://www.bundesregierung.de/resource/blob/974430/1982598/defbdff47daf5f177586a5d34e8677e8/2021-11-18-mpk-data.pdf](https://www.bundesregierung.de/resource/blob/974430/1982598/defbdff47daf5f177586a5d34e8677e8/2021-11-18-mpk-data.pdf).
     
16.  16\. Norddeutscher Rundfunk. Nach MPK-Beschluss: Verwirrung um Hospitalisierungsinzidenz; 20 November 2021 \[Cited 19 July 2023\]. Available from: [https://www.ndr.de/nachrichten/info/Nach-MPK-Beschluss-Verwirrung-um-Hospitalisierungsinzidenz,hospitalisierungsinzidenz100.html](https://www.ndr.de/nachrichten/info/Nach-MPK-Beschluss-Verwirrung-um-Hospitalisierungsinzidenz,hospitalisierungsinzidenz100.html).
     
17.  17\. Cramer EY, Ray EL, Lopez VK, Bracher J, Brennen A, Castro Rivadeneira AJ, et al. Evaluation of individual and ensemble probabilistic forecasts of COVID-19 mortality in the United States. Proceedings of the National Academy of Sciences. 2022;119(15):e2113561119. pmid:35394862
     -   [View Article](https://doi.org/10.1073/pnas.2113561119 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/35394862 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Evaluation+of+individual+and+ensemble+probabilistic+forecasts+of+COVID-19+mortality+in+the+United+States+Cramer+2022 "Go to article in Google Scholar")
18.  18\. Bracher J, Wolffram D, Deuschel J, Görgen K, Ketterer JL, Ullrich A, et al. A pre-registered short-term forecasting study of COVID-19 in Germany and Poland during the second wave. Nature Communications. 2021;12(1):5173. pmid:34453047
     -   [View Article](https://doi.org/10.1038/s41467-021-25207-0 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/34453047 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=A+pre-registered+short-term+forecasting+study+of+COVID-19+in+Germany+and+Poland+during+the+second+wave+Bracher+2021 "Go to article in Google Scholar")
19.  19\. Sherratt K, Gruson H, Johnson H, Niehus R, Prasse B, Sandmann F, et al. Predictive performance of multi-model ensemble forecasts of COVID-19 across European nations. eLife. 2023;12:e81916. pmid:37083521
     -   [View Article](https://doi.org/10.7554/eLife.81916 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/37083521 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Predictive+performance+of+multi-model+ensemble+forecasts+of+COVID-19+across+European+nations+Sherratt+2023 "Go to article in Google Scholar")
20.  20\. Reich NG, Brooks LC, Fox SJ, Kandula S, McGowan CJ, Moore E, et al. A collaborative multiyear, multimodel assessment of seasonal influenza forecasting in the United States. Proceedings of the National Academy of Sciences. 2019;116(8):3146–3154. pmid:30647115
     -   [View Article](https://doi.org/10.1073/pnas.1812594116 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/30647115 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=A+collaborative+multiyear%2C+multimodel+assessment+of+seasonal+influenza+forecasting+in+the+United+States+Reich+2019 "Go to article in Google Scholar")
21.  21\. Bracher J, Ray EL, Gneiting T, Reich NG. Evaluating epidemic forecasts in an interval format. PLOS Computational Biology. 2021;17(2):e1008618. pmid:33577550
     -   [View Article](https://doi.org/10.1371/journal.pcbi.1008618 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/33577550 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Evaluating+epidemic+forecasts+in+an+interval+format+Bracher+2021 "Go to article in Google Scholar")
22.  22\. Bracher J, Wolffram D, the COVID-19 Nowcast Hub team and participants. Study Protocol: Comparison and combination of COVID-19 hospitalization nowcasts in Germany; Deposited 23 November 2021. Registry of the Open Science Foundation, [https://osf.io/mru75/](https://osf.io/mru75/).
     
23.  23\. Robert Koch Institute. COVID-19-Hospitalisierungen in Deutschland; 12 January 2023. Available from: [https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen\_in\_Deutschland](https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland).
     
24.  24\. German Federal Ministry of Health. FAQ zur Hospitalisierungsinzidenz; 7 October 2021 \[Cited 19 July 2023\]. Available from: [https://www.bundesgesundheitsministerium.de/coronavirus/hospitalisierungsinzidenz.html](https://www.bundesgesundheitsministerium.de/coronavirus/hospitalisierungsinzidenz.html).
     
25.  25\. Tolksdorf K, Haas W, Schuler E, Wieler LH, Schilling J, Hamouda O, et al. Syndromic surveillance for severe acute respiratory infections (SARI) enables valid estimation of COVID-19 hospitalization incidence and reveals underreporting of hospitalizations during pandemic peaks of three COVID-19 waves in Germany, 2020-2021; 2022 \[Posted 13 February 2022\]. medRxiv \[Preprint\]. Available from: [https://www.medrxiv.org/content/10.1101/2022.02.11.22269594v1](https://www.medrxiv.org/content/10.1101/2022.02.11.22269594v1).
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Syndromic+surveillance+for+severe+acute+respiratory+infections+%28SARI%29+enables+valid+estimation+of+COVID-19+hospitalization+incidence+and+reveals+underreporting+of+hospitalizations+during+pandemic+peaks+of+three+COVID-19+waves+in+Germany%2C+2020-2021+Tolksdorf+2022 "Go to article in Google Scholar")
26.  26\. Abbott S, Lison A, Funk S, Pearson C, Gruson H. epinowcast: Flexible hierarchical nowcasting; 2021. Available from: [https://github.com/epinowcast/epinowcast](https://github.com/epinowcast/epinowcast).
     
27.  27\. Heyder S, Hotz T. The ILM-prop model: method and code; 2023. Available from: [https://github.com/Stochastik-TU-Ilmenau/ILM-prop](https://github.com/Stochastik-TU-Ilmenau/ILM-prop).
     
28.  28\. Fritz C, De Nicola G, Rave M, Weigert M, Khazaei Y, Berger U, et al. Statistical modelling of COVID-19 data: Putting generalized additive models to work. Statistical Modelling. 2022;0(0).
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Statistical+modelling+of+COVID-19+data%3A+Putting+generalized+additive+models+to+work+Fritz+2022 "Go to article in Google Scholar")
29.  29\. Schneble M, De Nicola G, Kauermann G, Berger U. Nowcasting fatal COVID-19 infections on a regional level in Germany. Biometrical Journal. 2021;63(3):471–489. pmid:33215765
     -   [View Article](https://doi.org/10.1002/bimj.202000143 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/33215765 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting+fatal+COVID-19+infections+on+a+regional+level+in+Germany+Schneble+2021 "Go to article in Google Scholar")
30.  30\. van de Kassteele J, Eilers PH, Wallinga J. Nowcasting the number of new symptomatic cases during infectious disease outbreaks using constrained P-spline smoothing. Epidemiology (Cambridge, Mass). 2019;30(5):737. pmid:31205290
     -   [View Article](https://doi.org/10.1097/EDE.0000000000001050 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/31205290 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Nowcasting+the+number+of+new+symptomatic+cases+during+infectious+disease+outbreaks+using+constrained+P-spline+smoothing+van+de+Kassteele+2019 "Go to article in Google Scholar")
31.  31\. an der Heiden M, Hamouda O. Schätzung der aktuellen Entwicklung der SARS-CoV-2- Epidemie in Deutschland—Nowcasting. Epidemiologisches Bulletin. 2020;2020(17):10–15.
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Sch%C3%A4tzung+der+aktuellen+Entwicklung+der+SARS-CoV-2-+Epidemie+in+Deutschland%E2%80%94Nowcasting+an+der+Heiden+2020 "Go to article in Google Scholar")
32.  32\. Lawless JF. Adjustments for reporting delays and the prediction of occurred but not reported events. Canadian Journal of Statistics. 1994;22(1):15–31.
     -   [View Article](https://doi.org/10.2307/3315826.n1 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Adjustments+for+reporting+delays+and+the+prediction+of+occurred+but+not+reported+events+Lawless+1994 "Go to article in Google Scholar")
33.  33\. Genest C. Vincentization revisited. The Annals of Statistics. 1992; p. 1137–1142.
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Vincentization+revisited+Genest+1992 "Go to article in Google Scholar")
34.  34\. Lichtendahl KC, Grushka-Cockayne Y, Winkler RL. Is It Better to Average Probabilities or Quantiles? Management Science. 2013;59(7):1594–1611.
     -   [View Article](https://doi.org/10.1287/mnsc.1120.1667 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Is+It+Better+to+Average+Probabilities+or+Quantiles%3F+Lichtendahl+2013 "Go to article in Google Scholar")
35.  35\. Koenker R. Quantile regression. vol. 38. Cambridge University Press; 2005.
     
36.  36\. Chernozhukov V, Fernández-Val I, Galichon A. Quantile and probability curves without crossing. Econometrica. 2010;78(3):1093–1125.
     -   [View Article](https://doi.org/10.3982/ECTA7880 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Quantile+and+probability+curves+without+crossing+Chernozhukov+2010 "Go to article in Google Scholar")
37.  37\. Gneiting T, Raftery AE. Strictly proper scoring rules, prediction, and estimation. Journal of the American Statistical Association. 2007;102(477):359–378.
     -   [View Article](https://doi.org/10.1198/016214506000001437 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Strictly+proper+scoring+rules%2C+prediction%2C+and+estimation+Gneiting+2007 "Go to article in Google Scholar")
38.  38\. Ehm W, Gneiting T, Jordan A, Krüger F. Of quantiles and expectiles: consistent scoring functions, Choquet representations and forecast rankings. Journal of the Royal Statistical Society: Series B (Statistical Methodology). 2016;78(3):505–562.
     -   [View Article](https://doi.org/10.1111/rssb.12154 "Go to article")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Of+quantiles+and+expectiles%3A+consistent+scoring+functions%2C+Choquet+representations+and+forecast+rankings+Ehm+2016 "Go to article in Google Scholar")
39.  39\. Shafer G, Vovk V. A Tutorial on Conformal Prediction. Journal of Machine Learning Research. 2008;9(12):371–421.
     -   [View Article](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394# "Go to article in CrossRef")
     -   [Google Scholar](http://scholar.google.com/scholar?q=A+Tutorial+on+Conformal+Prediction+Shafer+2008 "Go to article in Google Scholar")
40.  40\. Berliner Morgenpost. Triage in Sachsen: Kliniken bereiten sich auf Schlimmes vor; 23 November 2021 \[Cited 19 July 2023\]. Available from: [https://www.morgenpost.de/vermischtes/article233915811/corona-sachsen-triage-intensivstationen-ueberlastung.html](https://www.morgenpost.de/vermischtes/article233915811/corona-sachsen-triage-intensivstationen-ueberlastung.html).
     
41.  41\. Wolter N, Jassat W, Walaza S, Welch R, Moultrie H, Groome M, et al. Early assessment of the clinical severity of the SARS-CoV-2 omicron variant in South Africa: a data linkage study. The Lancet. 2022;10323:437–446. pmid:35065011
     -   [View Article](https://doi.org/10.1016/S0140-6736\(22\)00017-4 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/35065011 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Early+assessment+of+the+clinical+severity+of+the+SARS-CoV-2+omicron+variant+in+South+Africa%3A+a+data+linkage+study+Wolter+2022 "Go to article in Google Scholar")
42.  42\. Bergström F, Günther F, Höhle M, Britton T. Bayesian nowcasting with leading indicators applied to COVID-19 fatalities in Sweden. PLOS Computational Biology. 2022;18(12):1–17. pmid:36477048
     -   [View Article](https://doi.org/10.1371/journal.pcbi.1010767 "Go to article")
     -   [PubMed/NCBI](http://www.ncbi.nlm.nih.gov/pubmed/36477048 "Go to article in PubMed")
     -   [Google Scholar](http://scholar.google.com/scholar?q=Bayesian+nowcasting+with+leading+indicators+applied+to+COVID-19+fatalities+in+Sweden+Bergstr%C3%B6m+2022 "Go to article in Google Scholar")
43.  43\. Heinsch M, Schmid-Johannsen J. Mit oder wegen Corona im Krankenhaus? So bedingt aussagekräftig sind die BW-Daten; 4 February 2022 \[Cited 19 July 2023\]. Available from: [https://www.swr.de/swraktuell/baden-wuerttemberg/was-sagt-die-hospitalisierungsinzidenz-in-der-omikron-welle-aus-100.html](https://www.swr.de/swraktuell/baden-wuerttemberg/was-sagt-die-hospitalisierungsinzidenz-in-der-omikron-welle-aus-100.html).
     

[Download PDF](https://journals.plos.org/ploscompbiol/article/file?id=10.1371/journal.pcbi.1011394&type=printable)

 

-   [Citation](https://journals.plos.org/ploscompbiol/article/citation?id=10.1371/journal.pcbi.1011394)
-   [XML](https://journals.plos.org/ploscompbiol/article/file?id=10.1371/journal.pcbi.1011394&type=manuscript)

[Print](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394#)

Share

-   [Reddit](https://www.reddit.com/submit?url=https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1011394 "Submit to Reddit")
-   [Facebook](https://www.facebook.com/share.php?u=https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1011394&t=Collaborative%20nowcasting%20of%20COVID-19%20hospitalization%20incidences%20in%20Germany "Share on Facebook")
-   [LinkedIn](https://www.linkedin.com/shareArticle?url=https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1011394&title=Collaborative%20nowcasting%20of%20COVID-19%20hospitalization%20incidences%20in%20Germany&summary=Checkout%20this%20article%20I%20found%20at%20PLOS "Add to LinkedIn")
-   [Mendeley](https://www.mendeley.com/import/?url=https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1011394 "Add to Mendeley")
-   [Bluesky](https://bsky.app/intent/compose?text=Checkout%20this%20article%20I%20found%20at%20PLOS:%20https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1011394 "Share on Bluesky")
-   [Email](mailto:?subject=Collaborative%20nowcasting%20of%20COVID-19%20hospitalization%20incidences%20in%20Germany&body=I%20thought%20you%20would%20find%20this%20article%20interesting.%20From%20PLOS%20Computational%20Biology:%20https%3A%2F%2Fdx.plos.org%2F10.1371%2Fjournal.pcbi.1011394)

  

Advertisement

### Subject Areas

?

-   [Epidemiology](https://journals.plos.org/ploscompbiol/search?filterSubjects=Epidemiology&filterJournals=PLoSCompBiol&q= "Search for articles about Epidemiology")  
    
    Is the Subject Area **"Epidemiology"** applicable to this article?  
    
-   [Age groups](https://journals.plos.org/ploscompbiol/search?filterSubjects=Age+groups&filterJournals=PLoSCompBiol&q= "Search for articles about Age groups")  
    
    Is the Subject Area **"Age groups"** applicable to this article?  
    
-   [COVID 19](https://journals.plos.org/ploscompbiol/search?filterSubjects=COVID+19&filterJournals=PLoSCompBiol&q= "Search for articles about COVID 19")  
    
    Is the Subject Area **"COVID 19"** applicable to this article?  
    
-   [Pandemics](https://journals.plos.org/ploscompbiol/search?filterSubjects=Pandemics&filterJournals=PLoSCompBiol&q= "Search for articles about Pandemics")  
    
    Is the Subject Area **"Pandemics"** applicable to this article?  
    
-   [Virus testing](https://journals.plos.org/ploscompbiol/search?filterSubjects=Virus+testing&filterJournals=PLoSCompBiol&q= "Search for articles about Virus testing")  
    
    Is the Subject Area **"Virus testing"** applicable to this article?  
    
-   [Hospitalizations](https://journals.plos.org/ploscompbiol/search?filterSubjects=Hospitalizations&filterJournals=PLoSCompBiol&q= "Search for articles about Hospitalizations")  
    
    Is the Subject Area **"Hospitalizations"** applicable to this article?  
    
-   [Hospitals](https://journals.plos.org/ploscompbiol/search?filterSubjects=Hospitals&filterJournals=PLoSCompBiol&q= "Search for articles about Hospitals")  
    
    Is the Subject Area **"Hospitals"** applicable to this article?  
    
-   [Public and occupational health](https://journals.plos.org/ploscompbiol/search?filterSubjects=Public+and+occupational+health&filterJournals=PLoSCompBiol&q= "Search for articles about Public and occupational health")  
    
    Is the Subject Area **"Public and occupational health"** applicable to this article?  
    

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
