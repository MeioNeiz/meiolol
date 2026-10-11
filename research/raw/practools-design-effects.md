# Design Effects and Effective Sample Size

<https://cran.r-universe.dev/PracTools/doc/Design-effects.html>

# Design Effects and Effective Sample Size

Sample size calculation should reflect the complexity of the survey design by accounting for the weighting, stratification, and clustering in the survey design. A shortcut method of computing a total sample size that will yield a target level of precision is to compute a sample size using a simple random sampling (SRS) formula and then adjust by a design effect. Design effects may also be of interest to analysts to better understand how much the standard errors of their estimates are affected by complex design features.

The **design effect** (_deff_) is the ratio of the variance of a survey statistic under the complex design to the variance of the survey statistic under an SRS. The SRS variance can be for with- or without-replacement sampling; both usages can be found in the literature. Represented as a formula, the design effect is: 𝑑⁢𝑒⁢𝑓⁡𝑓⁡(ˆ𝜃)\=𝑉𝑐⁢𝑜⁢𝑚⁢𝑝⁢𝑙⁢𝑒⁢𝑥⁡(ˆ𝜃)𝑉𝑆⁢𝑅⁢𝑆⁡(ˆ𝜃) where ˆ𝜃 is an estimator of a chosen parameter.

Given a survey dataset, _deff_’s can be computed directly by estimating both the complex sample variance and the SRS variance and taking the ratio. In specific cases, formulas have been derived that account for different features of sample designs and analysis variables. Some of these are available in the PracTools package (Valliant et al. 2023).

A _deff_ is specific to a particular estimator. The _deff_’s for estimated mean per capita income and the estimated proportion of persons who have received the latest coronavirus booster shot may be quite different even if both come from the same survey.

The **effective sample size** is the sample size for an estimator ˆ𝜃 from a complex sample divided by the design effect of ˆ𝜃, i.e. 𝑛𝑒⁢𝑓⁡𝑓 \=𝑛/𝑑⁢𝑒⁢𝑓⁡𝑓⁡(ˆ𝜃).

In other words, the effective sample size is the size of an SRS that would yield the same variance as that produced by the complex design. For example, if a complex sample of n=1000 elements has a design effect of 1.25 for some estimate, the effective sample size is 𝑛𝑒⁢𝑓⁡𝑓 \=1000/1.25 \=800. That is, the complex sample of 1000 is only as precise as an SRS of 800 given the design effect formula implicit in this example. Different design effect formulas may be derived for different sample designs and different covariate data, as described below.

This vignette provides an overview on design effect components and formulas, discusses the PracTools design effect functions that estimate the design effects and gives examples on when and how to apply them.

## Design Effect Components

Complex sample variances can be affected by three components:

1.  Weighting  
    
2.  Stratification
3.  Clustering

In general, clustering increase the design effect (and decrease the effective sample size) while stratification decreases the design effect. Weighting can either increase or decrease complex sample variances, depending on how the weights are derived. Different design effect formulas applied over these components will result in different final design effects. These are reviewed below in the context of the design effect components.

### Weighting

The most common formula for the weighting component of the design effect is the one proposed by Kish (1965), where:

𝑑⁢𝑒⁢𝑓⁡𝑓𝐾\=1+𝑟⁡𝑒⁢𝑙⁢𝑣⁢𝑎⁢𝑟⁡(𝐰)\=1+𝐶⁢𝑉2⁡(𝐰)\=1+1𝑛⁢𝑛∑𝑖\=1(𝑤𝑖−¯𝑤)2/¯𝑤2,

𝐰 is the vector of sample weights and _relvar_ denotes relvariance. Kish’s formula only accounts for an increase in variance due to having unequal weights and is derived under some extremely restrictive assumptions. It applies to a stratified, simple random sample (STSRS). If all strata population variances are equal, a proportional allocation is optimal for estimating a mean. Since all weights are equal in a proportionally allocated STSRS, any departure from that where the relvariance of the weights is non-zero will be suboptimal, leading to 𝑑⁢𝑒⁢𝑓⁡𝑓𝐾 \>1. Practitioners often use Kish’s deff even when the sample is more complicated than STSRS because 𝑑⁢𝑒⁢𝑓⁡𝑓𝐾 is so easy to compute.

However, 𝑑⁢𝑒⁢𝑓⁡𝑓𝐾 is not always relevant in surveys where variances differ across strata, where subgroups are intentionally sampled at different rates, and/or where different subgroups have substantially different response rates. Having unequal weights in those situations is desirable and can more nearly meet analytic goals than having equal weights will.

### Stratification

Chen and Rust (2017) formulate a design effect that can be broken into the three components listed above. The Chen-Rust formula for the stratum ℎ component of the design effect is:

𝑑⁢𝑒⁢𝑓⁡𝑓𝑠⁢𝑡⁢𝑟⁢𝑎⁢𝑡,ℎ\=𝑊2ℎ⁢𝑛𝑛ℎ⁢𝜎2ℎ𝜎2

where 𝑊ℎ \=𝑁ℎ/𝑁 and 𝜎2 is the population unit variance. Stratification with an efficient allocation to strata will reduce the design effect (i.e. increase the effective sample size). When the sample is allocated optimally over the strata, then the design effect is necessarily less than or equal to one (Cochran (1977), Section 5.6). Stratification is most effective when the 𝑦’s for elements within each strata are homogeneous and the 𝑦‘s for elements between strata (i.e., 𝑦’s in different strata) are heterogeneous. As Kish states, the variance decreases “to the degree that the stratum means diverge and that homogeneity exists within strata.” (Kish (1965), pg. 76). In sum, good stratification design increases effective sample size.

### Clustering

The clustering formula takes into account the variability in each PSU cluster. The greater the homogeneity of the cluster, the more the design effect increases. The stratum ℎ formula is:

𝑑⁢𝑒⁢𝑓⁡𝑓𝑐⁢𝑙⁢𝑢⁢𝑠,ℎ\=1+𝜌ℎ⁢(𝑛∗ℎ−1)

where 𝜌ℎ is the intraclass correlation coefficient in stratum ℎ, which measures the homogeneity of the cluster, and 𝑛∗ℎ is a type of weighted average number of sampling elements taken from each cluster. Consequently, clustering typically increases the design effect. As can be seen, as the homogeneity 𝜌 increases and as cluster sample size 𝑛∗ℎ increases, the design effect increases. In some special cases, 𝑛∗ℎ reduces to the unweighted average number of sample elements per cluster, ¯𝑛.

### Combined Formula

Chen and Rust (2017) combine the above formulas across strata so that:

𝑑⁢𝑒⁢𝑓⁡𝑓\=𝐻∑ℎ\=1𝑑⁢𝑒⁢𝑓⁡𝑓𝑠⁢𝑡⁢𝑟⁡𝑎⁢𝑡,ℎ×𝑑⁢𝑒⁢𝑓⁡𝑓𝑤⁢𝑡⁢𝑠,ℎ×𝑑⁢𝑒⁢𝑓⁡𝑓𝑐⁢𝑙⁢𝑢⁢𝑠,ℎ\=𝐻∑ℎ\=1𝑊2ℎ⁢𝑛𝑛ℎ⁢𝜎2ℎ𝜎2⁢\[1+𝑟⁡𝑒⁢𝑙⁢𝑣⁢𝑎⁢𝑟ℎ⁡(𝐰)\]⁢\[1+𝜌ℎ⁢(𝑛∗ℎ−1)\]

where 𝑑⁢𝑒⁢𝑓⁡𝑓(⁡𝑤⁢𝑡⁢𝑠,ℎ) \=1 +𝑟⁡𝑒⁢𝑙⁢𝑣⁢𝑎⁢𝑟ℎ⁡(𝐰) is the Kish deff for weights within stratum ℎ.

This formula has the advantage that the component parts of the design effect can be individually calculated and understood. However, as discussed above, the Kish design effect equal to 1 +𝑟⁡𝑒⁢𝑙⁢𝑣⁢𝑎⁢𝑟⁡(𝐰) does not fully account for the possibility that the estimators may be more efficient than the relvariance of their weights implies. This is particularly true for probability proportional to size sampling or for the general regression estimator.

## Modeled Design Effect Estimates

Several more sophisticated design effects described below have been developed by later authors. Spencer (2000) derived a _deff_ for an estimated total (not means) of 𝑦’s assuming that the 𝑦 variable can be modeled by the linear regression model:

𝑦𝑖\=𝛼+𝛽⁢𝑃𝑖+𝜀𝑖

where 𝑤𝑖 \=1/(𝑛⁢𝑃𝑖) is the weight for sample element 𝑖 and the 𝜖𝑖’s are independent errors with mean 0 and common variance. The estimator of the total used by Spencer was the Horvitz-Thompson estimator (or 𝜋\-estimator). Spencer’s design effect formula then adjusts the design effect of the weights by the model 𝑅2, regression coefficients, and variance of the model. When the model variance is large and the 𝑅2 is low, Kish’s design effect and Spencer’s design effect are close.

Henry and Valliant (2015) generalized the _deff_ to a general regression estimator (GREG) that includes auxiliary variables under the model: 𝑦𝑖\=𝛼+𝐱𝑇𝑖⁢𝛽+𝜀𝑖 where 𝐱𝑖 is a vector of covariates used in the GREG.

Unlike the Spencer and Henry design effects, the Chen & Rust design effect (2017) considers clustering but does not account for any covariates when deriving their _deff_. The model they assume includes strata and clustering and is an extension of work by Gabler et al. (1999):

𝐸𝑀⁡(𝑦ℎ⁡𝑖⁢𝑗)\=𝜇ℎ,   𝐶⁢𝑜⁢𝑣𝑀⁡(𝑦ℎ⁡𝑖⁢𝑗,𝑦ℎ′⁡𝑖′⁢𝑗′)\=⎧{ {⎨{ {⎩𝜎2ℎℎ\=ℎ′,𝑖\=𝑖′,𝑗\=𝑗′,𝜌ℎ⁢𝜎2ℎℎ\=ℎ′,𝑖\=𝑖′,𝑗≠𝑗′,0  otherwise.

They do provide a useful decomposition of the _deff_ for a weighted mean estimator into factors due to stratification, clustering, and unequal weighting that we listed in the _Combined Formula_ section above.

In sum, the survey practitioner needs to understand the complexity of the survey design and the potential value in modeling for estimating the design effect. The above is intended to frame and assist in this understanding.

## PracTools Design Effect Functions

PracTools has the following design effect functions: `deff`, `deffCR`, `deffH`, `deffK`, and `deffS`. `deff` is a wrapper function in that it calls `deffCR`, `deffH`, `deffK`, or `deffS` depending on the `type=` option. The following table compares the PracTools design effect functions:

  
| Function name | Parameters | Description |
| :-- | :-- | :-- |
| deffCR | w = vector of weights for a sample | Chen-Rust design effect for an estimated mean from a stratified, clustered, two-stage sample. Produces design effects by weights, strata, and cluster at the strata level and overall. |
|  | strvar = vector of stratum identifiers |  |
|  | clvar = vector of cluster identifiers |  |
|  | Wh = vector of the proportions of elements that are in each stratum |  |
|  | nest = whether cluster IDs numbered within strata |  |
|  | y = vector of sample values of an analysis variable |  |
| deffH | w = vector of inverses of selection probabilities for a sample | Henry design effect for single-stage samples when a general regression estimator is used for a total. |
|  | y = vector of the sample values of an analysis variable |  |
|  | x = matrix of covariates used to construct a GREG estimator of the total |  |
| deffK | w = vector of weights for a sample | Kish design effect due to unequal weights. |
| deffS | p = vector of 1-draw selection probabilities | Spencer design effect for an estimated total from a single-stage sample selected by PPS. |
|  | w = vector of weights for a sample |  |
|  | y = vector of the sample values of an analysis variable |  |

**Example 1: smho.N874 dataset** PracTools comes with the `smho.N874` data set, which is a data frame of 874 observations from the 1998 Survey of Mental Health Organizations (SMHO). It contains two variables of importance here: EXPTOTAL, which is a variable of analytic interest, and BEDS, which may be used as a measure of size in probability proportional to size (PPS) sampling. The following code is used to create the inputs for `deffK`, `deffS`, and `deffH`.

```
## libraries needed for example 
library(PracTools) 
library(sampling) 
library(ggplot2) 

## Use PracTools smho.N874 data set 
data(smho.N874) 
## Remove hosp.type == 4 as it is out-patient and has no BEDS 
smho <- smho.N874[smho.N874$hosp.type != 4, ] 
## Use co-variate BEDS for MOS 
## Re-code BEDS to have a minimum MOS of 5 
smho$BEDS[smho$BEDS <= 5] <- 5 
## Create 1-draw probability vector based on BEDS 
smho$pi1 <- inclusionprobabilities(smho$BEDS, 1) 
## Create vector for sampling n=50 
pik <- inclusionprobabilities(smho$BEDS, 50) 
## Create sample 
seed <- 20230802 
set.seed(seed) 
sample    <- UPrandomsystematic(pik = pik) 
smho.samp <- smho[sample == 1, ] 
## Create vector of weights 
wgt       <- 1/pik[sample == 1] 
```

The Kish design effect requires just the weights, while the Spencer requires a vector of sample length for the 1-draw probabilities, the weights of the sample, and the analytic variable that is regressed on the 1-draw probabilities.

```
## Kish 
deffK(wgt) 
[1] 6.263141 
## Spencer 
deffS(p = smho.samp$pi1, 
      w = wgt, 
      y = smho.samp$EXPTOTAL) 
[1] 0.7130517 
```

As can be seen, Spencer’s _deff_ is substantially below Kish’s _deff_, and more crucially, below 1 (i.e. the effective sample size increases). Spencer’s _deff_ suggests that PPS sampling on BEDS is more efficient than just simple random sampling for the analytic variable of interest. On the other hand, the Kish _deff_ is completely misleading since it says that SRS would be a much more efficient design. A regression of EXPTOTAL on the 1-draw weights derived from BEDS confirms this point.

```
summary(lm(smho$EXPTOTAL ~ smho$pi1)) 
lm(formula = smho$EXPTOTAL ~ smho$pi1) 

Residuals: 
      Min        1Q    Median        3Q       Max  
-67989801  -4123670  -1897337   1655133 138295163  

Coefficients: 
             Estimate Std. Error t value Pr(>|t|)     
(Intercept) 3.628e+06  5.742e+05   6.318 4.62e-10 *** 
smho$pi1    6.144e+09  2.304e+08  26.670  < 2e-16 *** 
--- 
Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1 
Residual standard error: 12880000 on 723 degrees of freedom 
Multiple R-squared:  0.4959,   Adjusted R-squared:  0.4952  
F-statistic: 711.3 on 1 and 723 DF,  p-value: < 2.2e-16 
```

Figure 1. Plot of expenditure totals per hospital vs. 1-draw selection probabilities

The plot with a regression line with an intercept shows a fairly strong relationship and suggests that PPS sampling with respect to BEDS is efficient. (In this example, a no-intercept model would be a better fit, but the Spencer deff is derived with the assumption that the model has an intercept.)

Henry’s design effect uses a matrix of covariates to build the model. The covariates used below for a GREG estimator of the total of EXPTOTAL are described in the help file for `smho.N874`.

```
## Create matrix of covariates 
x <- cbind(smho.samp$BEDS, 
           smho.samp$SEENCNT, 
           smho.samp$EOYCNT, 
           as.factor(smho.samp$FINDIRCT), 
           as.factor(smho.samp$hosp.type)) 
deffH(w = wgt, 
      x = x, 
      y = smho.samp$EXPTOTAL) 
[1] 0.6549418 
```

This is consistent with Spencer’s design effect in saying that the design is more efficient than SRS but also that the GREG estimator is more efficient than the 𝜋\-estimator.

**Example 2: NHANES 2017-2018** The National Health and Nutrition Examination Survey is a program of studies designed to assess the health and nutritional status of adults and children in the United States. While the COVID pandemic caused a break in operations, it has typically run on a two-year schedule. The data used here are from the 2017 – 2018 NHANES ([https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017)}). The datasets, DEMO\_J.XPT, BMX\_J.XPT, and BPX\_J.XPT, used below can be downloaded from that site. For the example here, the following code recreates the data set:

```
library(haven) 
nhanes.demo <- read_xpt("C:/NHANES/DEMO_J.XPT") 
nhanes.bm   <- read_xpt("C:/NHANES/BMX_J.XPT") 
nhanes.bp   <- read_xpt("C:/NHANES/BPX_J.XPT") 
library(dplyr) 
nhanes.demo <- nhanes.demo %>% select(SEQN, SDMVPSU, SDMVSTRA, WTMEC2YR) 
nhanes.bm   <- nhanes.bm   %>% select(SEQN, BMXHT,   BMXWT,    BMXBMI) 
nhanes.bp   <- nhanes.bp   %>% select(SEQN, BPXSY1,  BPXDI1) 
## Combine data sets 
nhanes      <- inner_join(nhanes.demo, nhanes.bm, by = "SEQN") 
nhanes      <- inner_join(nhanes,      nhanes.bp, by = "SEQN") 
```

Using the `deffCR` function in PracTools on BMXHT (Standing Height in centimeters):

```
deffCR(w      = nhanes.na.rm$WTMEC2YR, 
       strvar = nhanes.na.rm$SDMVSTRA, 
       Wh     = NULL, 
       clvar  = nhanes.na.rm$SDMVPSU, 
       nest   = TRUE, 
       y      = nhanes.na.rm$BMXHT)  ## Note: Missing BMXHT values have been removed 

$`strata components` 
      stratum  nh          rhoh     cv2wh   deff.w       deff.c     deff.s 
 [1,]     134 434 -0.0104060072 1.3777530 2.377753 5.358045e-02 0.06902480 
 [2,]     135 548 -0.0063819241 1.2210056 2.221006 1.793669e-01 0.08717926 
 [3,]     136 595 -0.0059338153 1.5680748 2.568075 3.162617e-01 0.06054293 
 [4,]     137 489 -0.0109846523 1.6919849 2.691985 1.156024e-05 0.05199803 
 [5,]     138 543 -0.0078028704 1.4940016 2.494002 1.506828e-01 0.04321209 
 [6,]     139 563 -0.0081864680 1.2916004 2.291600 2.348559e-03 0.06166823 
 [7,]     140 531 -0.0010210084 1.1654563 2.165456 8.755365e-01 0.06117508 
 [8,]     141 609 -0.0067846425 1.1206941 2.120694 3.259820e-02 0.09565024 
 [9,]     142 633 -0.0045075356 0.7718338 1.771834 1.889764e-01 0.13253047 
[10,]     143 459 -0.0083420387 1.2122912 2.212291 1.259705e-01 0.10672679 
[11,]     144 608  0.0043127129 1.5729769 2.572977 1.517876e+00 0.05435944 
[12,]     145 525 -0.0006598233 1.4624627 2.462463 9.296262e-01 0.05791430 
[13,]     146 519 -0.0073484461 0.9075594 1.907559 7.618830e-03 0.09556860 
[14,]     147 513 -0.0099422966 2.2498915 3.249891 1.529503e-01 0.04799347 
[15,]     148 447  0.0064413472 1.1482058 2.148206 1.675286e+00 0.01386007 

$`overall deff` 
[1] 0.7259837 
```

As the example shows, `deffCR` provides the design effects by weights, cluster, and strata, and includes the overall design effect. As the overall design effect is less than one, the benefits of stratification are obvious here.

For BMXBMI (Body Mass Index), a very different overall deff is calculated.

```
$`strata components` 
      stratum  nh         rhoh     cv2wh   deff.w       deff.c     deff.s 
 [1,]     134 433 -0.011048345 1.3841270 2.384127  0.000807066 0.05788729 
 [2,]     135 547  0.016890014 1.2234169 2.223417  3.164102451 0.07694603 
 [3,]     136 595 -0.005566258 1.5680748 2.568075  0.358614475 0.04902415 
 [4,]     137 487 -0.010918010 1.7022363 2.702236  0.014372671 0.04966114 
 [5,]     138 542  0.002112249 1.4931232 2.493123  1.229605157 0.03612878 
 [6,]     139 562 -0.003298061 1.2890828 2.289083  0.598349310 0.06717454 
 [7,]     140 531 -0.004601001 1.1654563 2.165456  0.439126324 0.06773169 
 [8,]     141 609  0.013328540 1.1206941 2.120694  2.900476535 0.08671762 
 [9,]     142 631 -0.005571733 0.7734050 1.773405  0.002095250 0.14670977 
[10,]     143 458  0.105498156 1.2145247 2.214525 12.012659877 0.09520918 
[11,]     144 608  0.012497688 1.5729769 2.572977  2.500738233 0.06217566 
[12,]     145 524 -0.005311942 1.4622187 2.462219  0.434586798 0.07055294 
[13,]     146 518  0.080413254 0.9046178 1.904618 11.854614598 0.10125102 
[14,]     147 513 -0.008847636 2.2498915 3.249891  0.246211683 0.04876794 
[15,]     148 447  0.018572947 1.1482058 2.148206  2.947117560 0.01564027 

$`overall deff` 
[1] 6.822108 
```

Here, the design effect is much greater than 1. However, this is driven largely by high `deff.c` values in strata 10 and 13. An advantage to using `deffCR` is that it allows the researcher to explore differences in the design effect at the stratum level and look for unusual situations.

## Design Effect in the survey package

The `survey` package also calculates design effects, using the definitional formula given at the beginning of this vignette, 𝑑⁢𝑒⁢𝑓⁡𝑓⁡(ˆ𝜃) \=𝑉𝑐⁢𝑜⁢𝑚⁢𝑝⁢𝑙⁢𝑒⁢𝑥⁡(ˆ𝜃)𝑉𝑆⁢𝑅⁢𝑆⁡(ˆ𝜃), by directly estimating the numerator and denominator given the input data. This is a common approach among packages that handle survey data. 𝑉𝑐⁢𝑜⁢𝑚⁢𝑝⁢𝑙⁢𝑒⁢𝑥⁡(ˆ𝜃) is calculated using all features of a design (weights, clusters, strata) while 𝑉𝑆⁢𝑅⁢𝑆⁡(ˆ𝜃) is an estimate of variance of the same parameter as it would be estimated from an SRS. While there is other literature available on the `survey` package (e.g., see Lumley (2010), Lumley (2020)), the basics are illustrated here using the 2017-2018 NHANES data file.

```
## Call survey library
library(survey)
## Create survey design object
deff.dsn <- svydesign(ids     = ~SEQN,
                      strata  = ~SDMVSTRA,
                      weights = ~WTMEC2YR,
                      nest    = TRUE,
                      data    = nhanes)
## Calculate mean and total for BMI, after removing missing values
## deff=TRUE option provides the design effect
> svymean(~BMXBMI, deff.dsn, na.rm = TRUE, deff=TRUE)
           mean       SE   DEff
BMXBMI 27.67122  0.12744 2.0359
> svytotal(~BMXBMI, deff.dsn, na.rm = TRUE, deff=TRUE)
            total         SE   DEff
BMXBMI 8554169950  125687156 20.723
```

Note the difference in design effect for the mean and the total, illustrating that the design effect is specific to the parameter being estimated. Here, the only difference in the variable is mean vs. total of BMXBMI. Also, different design effect formulas will yield different design effect calculations. The Chen-Rust _deff_ of about 6.82 for mean BMXBMI is considerably different from the `survey` package _deff_ of 2.04. The Chen-Rust _deff_ is computed assuming model (1) for 𝑦 while the survey package directly estimates the _deff_ with no model assumptions. Since model (1) may be incorrect, the two are not guaranteed to be equal; both are greater than 1, conveying the point that the design is less precise than an SRS of the same size would be. It should be noted that the `survey` package provides only the final summary design effect based on the formula above with no decomposition into components for stratification, clustering, and weighting.

## Intraclass Correlation Coefficient

Given design effects from previous surveys, the intraclass correlation coefficient 𝜌, which measures the homogeneity within clusters, can be approximated from the formula, 𝑑⁢𝑒⁢𝑓⁡𝑓𝑐⁢𝑙⁢𝑢⁢𝑠⁡(ˆ𝜃) \=1 +𝜌⁢(¯𝑛−1), which comes from the variance for an estimated mean or total. Solving that equation for gives:

𝜌\=𝑑⁢𝑒⁢𝑓⁡𝑓𝑐⁢𝑙⁢𝑢⁢𝑠⁡(ˆ𝜃)−1¯𝑛−1

where 𝑑⁢𝑒⁢𝑓⁡𝑓𝐶⁢𝑙⁢𝑢⁢𝑠⁡(ˆ𝜃) is the cluster design effect for the estimator ˆ𝜃 and ¯𝑛 is the average number of elements sampled from each cluster. (Note that since an estimator is also based on a specific 𝑦, we could subscript 𝜌 with a 𝑦 to emphasize that dependence.)

`deffCR` evaluates a more elaborate estimate than expression (2) of 𝜌ℎ for each stratum of a stratified, two-stage design. Consequently, the output from `deffCR` (rhoh in the example above) will differ from values computed from the simpler formula in (2).

Kish suggests a mnemonic for 𝜌, pronounced “roh”, can be remembered as “rate of homogeneity,” and observes that in practice, “the distribution of the population in those clusters is generally not random. Instead, it is characterized by some homogeneity that tends to increase the variance of the sample.” The measure of that homogeneity is roh. Because, in a complex survey, the design effect is typically greater than one, negative values of roh are uncommon and only occur when the cluster means are more uniform than random. Also note that even a small positive roh can have a big impact on the design effect if ¯𝑛 is large.

## Design Effect and Sample Size Calculations

Recall that the design effect is computed for a specific estimate. The design effect for different estimates can be very different, even if they are from the same sample and use the same weights. When developing a sample size, it is good to look at the design effects of several of the variables of interest, and not just one. This is often done using the design effects from similar or previous surveys.

Looking at the 2017-2018 NHANES data set again, we can calculate the overall _deff_ for the following estimated means: height (BMXHT), weight (BMXWT), body mass index (BMXBMI), systolic blood pressure (BPXSY1), diastolic blood pressure (BPXDI1), and hypertension (BPXSY1 > 130 or BPXDI1 > 80). The following table shows:

| 2017-2018 NHANES Variable | Design Effect (deffCR) |
| :-- | :-- |
| Height | 0.7259837 |
| Weight | 3.8322210 |
| Body Mass Index | 6.8221081 |
| Systolic Blood Pressure | 2.5758779 |
| Diastolic Blood Pressure | 7.1351104 |
| Hypertension | 2.4553125 |

As can be seen, there is a lot of variation in the design effects, even with such related variables as height and weight. The survey practitioner is advised to calculate design effects on many variables and get a sense of the overall design effects and potential risks to the analytic objectives if the sample size is too small for many, but not all, variables.

Using deffs from earlier surveys can have serious limitations even if the new sample is for an updated version of the previous one. If the new design will have different strata or cluster definitions than the last, _deff_’s from the previous survey may not apply to the new design. If response rates in the new sample are likely to be substantially different from those of the earlier survey, this must also be considered when determining a sample size. Finally, an overall _deff_ for a two-stage (or more than two-stage) sample does not separate the first- and second-stage sample sizes. Additional calculations are needed for those; e.g., see Valliant et al. (2018), ch. 9.

## Conclusion

Sample size formulas exist which account for the survey design complexity. (See the vignette, “Selection of Appropriate PracTools Sample Size Function” at [https://CRAN.R-project.org/package=PracTools](https://cran.r-project.org/package=PracTools).) While these sample size formulas can account for design complexities (like stratification and clustering), they do not typically account for the effect of weighting. Using a _deff_ to compute a sample size is a shortcut method to getting the total sample size, but it does not tell the sample designer how to allocate the sample to strata or to different stages in a multistage sample. It should be also remembered that the design effect can vary from one variable to the next. Modeling approaches to estimating the design effect, as found in Chen and Rust (2017) and Henry and Valliant (2015), may be helpful. The survey practitioner is advised to use the design-appropriate sample size formula and compute design effects on important variables and consider modeling so as to ensure that the effective sample size will meet the analytic requirements.

## References

Chen, S., and K. F. Rust. 2017. “An Extension of Kish’s Formula for Design Effects to Two- and Three-Stage Designs with Stratification.” _Journal of Survey Statistics and Methodology_ 5 (2): 111–30.

Cochran, W. G. 1977. _Sampling Techniques_. John Wiley & Sons, Inc.

Gabler, S., S. Haeder, and P. Lahiri. 1999. “A Model Based Justification of Kish’s Formula for Design Effects for Weighting and Clustering.” _Survey Methodology_ 25 (1): 105–6.

Henry, K. A., and R. Valliant. 2015. “A Design Effect Measure for Calibration Weighting in Single–Stage Samples.” _Survey Methodology_ 41: 315–31.

Kish, L. 1965. _Survey Sampling_. John Wiley & Sons, Inc.

Lumley, T. 2010. _Complex Surveys: A Guide to Analysis Using R_. John Wiley & Sons, Inc.

Lumley, T. 2020. _Survey: Analysis of Complex Survey Samples, Version 4.2-1_. [https://CRAN.R-project.org/package=survey](https://cran.r-project.org/package=survey).

Spencer, B. D. 2000. “An Approximate Design Effect for Unequal Weighting When Measurements May Correlate with Selection Probabilities.” _Survey Methodology_ 26 (2): 137–38.

Valliant, R., J. A. Dever, and F. Kreuter. 2018. _Practical Tools for Designing and Weighting Survey Samples_. 2nd ed. Springer-Verlag.

Valliant, R., J. A. Dever, and F. Kreuter. 2023. _PracTools: Tools for Designing and Weighting Survey Samples, Version 1.4_. [https://CRAN.R-project.org/package=PracTools](https://cran.r-project.org/package=PracTools).

-   -   [Design Effect Components](https://cran.r-universe.dev/PracTools/doc/Design-effects.html#design-effect-components)
    -   [Modeled Design Effect Estimates](https://cran.r-universe.dev/PracTools/doc/Design-effects.html#modeled-design-effect-estimates)
    -   [PracTools Design Effect Functions](https://cran.r-universe.dev/PracTools/doc/Design-effects.html#practools-design-effect-functions)
    -   [Design Effect in the survey package](https://cran.r-universe.dev/PracTools/doc/Design-effects.html#design-effect-in-the-survey-package)
    -   [Intraclass Correlation Coefficient](https://cran.r-universe.dev/PracTools/doc/Design-effects.html#intraclass-correlation-coefficient)
    -   [Design Effect and Sample Size Calculations](https://cran.r-universe.dev/PracTools/doc/Design-effects.html#design-effect-and-sample-size-calculations)
    -   [Conclusion](https://cran.r-universe.dev/PracTools/doc/Design-effects.html#conclusion)
    -   [References](https://cran.r-universe.dev/PracTools/doc/Design-effects.html#references)
