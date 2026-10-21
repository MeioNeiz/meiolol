# How to extend Elo: a Bayesian perspective

<https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true>

[Skip to main content](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#main)

-   
-   
-   
-   
-   
-   

Mathematics

[Visit our Subject Page](https://www.degruyterbrill.com/publishing/subjects/mathematics) [Browse our collection](https://www.degruyterbrill.com/search?query=*&subjectFacet=MT)

[Home](https://www.degruyterbrill.com/) [Mathematics](https://www.degruyterbrill.com/publishing/subjects/mathematics) [Journal of Quantitative Analysis in Sports](https://www.degruyterbrill.com/journal/key/jqas/html) [Volume 17, Issue 3](https://www.degruyterbrill.com/journal/key/jqas/17/3/html) How to extend Elo: a Bayesian perspective

Article

[

18

](https://badge.dimensions.ai/details/doi/10.1515/jqas-2020-0066?domain=https://www.degruyterbrill.com)

 

# How to extend Elo: a Bayesian perspective

-    

Published/Copyright: January 7, 2021

## Quick Links:

-   [Submit Manuscript (opens in a new tab)](http://mc.manuscriptcentral.com/dgjqas)
-   [View all Issues](https://www.degruyterbrill.com/journal/key/jqas/html#issues)

## 

## Abstract

The Elo rating system, originally designed for rating chess players, has since become a popular way to estimate competitors’ time-varying skills in many sports. Though the self-correcting Elo algorithm is simple and intuitive, it lacks a probabilistic justification which can make it hard to extend. In this paper, we present a simple connection between approximate Bayesian posterior mode estimation and Elo. We provide a novel justification of the approximations made by linking Elo to steady-state Kalman filtering. Our second key contribution is to observe that the derivation suggests a straightforward procedure for extending Elo. We use the procedure to derive versions of Elo incorporating margins of victory, correlated skills across different playing surfaces, and differing skills by tournament level in tennis. Combining all these extensions results in the most complete version of Elo presented for the sport yet. We evaluate the derived models on two seasons of men’s professional tennis matches (2018 and 2019). The best-performing model was able to predict matches with higher accuracy than both Elo and Glicko (65.8% compared to 63.7 and 63.5%, respectively) and a higher mean log-likelihood (−0.615 compared to −0.632 and −0.633, respectively), demonstrating the proposed model’s ability to improve predictions.

Keywords: [correlated skills](https://www.degruyterbrill.com/search?query=keywordValues%3A%28%22correlated%20skills%22%29%20AND%20journalKey%3A%28%22JQAS%22%29&documentVisibility=all&documentTypeFacet=article); [margin of victory](https://www.degruyterbrill.com/search?query=keywordValues%3A%28%22margin%20of%20victory%22%29%20AND%20journalKey%3A%28%22JQAS%22%29&documentVisibility=all&documentTypeFacet=article); [paired comparison modelling](https://www.degruyterbrill.com/search?query=keywordValues%3A%28%22paired%20comparison%20modelling%22%29%20AND%20journalKey%3A%28%22JQAS%22%29&documentVisibility=all&documentTypeFacet=article); [tennis](https://www.degruyterbrill.com/search?query=keywordValues%3A%28%22tennis%22%29%20AND%20journalKey%3A%28%22JQAS%22%29&documentVisibility=all&documentTypeFacet=article)

* * *

**Corresponding author: Martin Ingram**, University of Melbourne School of BioSciences, Parkville, Victoria, Australia, E-mail: martin.ingram@gmail.com

* * *

**Funding source:** Melbourne Research Scholarship

1.  **Author contribution:** All the authors have accepted responsibility for the entire content of this submitted manuscript and approved submission.
    
2.  **Research funding:** This research was supported by Melbourne Research Scholarship.
    
3.  **Conflict of interest statement:** The authors declare no conflicts of interest regarding this article.
    

Appendix

### A Details of the Taylor series expansion

We already noted that the update is given by:

(35) 𝑥\=𝜇𝛿+𝑡′⁡(𝜇𝛿)−𝑡″⁡(𝜇𝛿) ,

and that

(36) 𝑡′⁡(𝛿)\=−𝛿−𝜇𝛿𝜎2𝛿+𝑏⁢(1−𝛾⁡(𝑏⁢𝛿)) .

The second derivative 𝑡″⁡(𝛿) is given by:

𝑡″⁡(𝛿)\=−1𝜎2𝛿−𝑏2⁢𝛾⁡(𝑏⁢𝛿)⁢(1−𝛾⁡(𝑏⁢𝛿)) .

And hence the update is:

𝑥\=𝜇𝛿+𝑏⁢(1−𝛾⁡(𝜇𝛿⁢𝑏))1𝜎2𝛿+𝑏2⁢𝛾⁡(𝜇𝛿⁢𝑏)⁢(1−𝛾⁡(𝜇𝛿⁢𝑏))\=𝜇𝛿+2⁢𝑘⁢(1−𝛾⁡(𝑏⁢𝜇𝛿)) .

### B Derivation of margin of victory update

The likelihood and prior are given, respectively, by:

(37) 𝑝⁡(𝛿)\=𝒩⁡(𝛿|⁢𝜇𝛿,𝜎2𝛿),

(38) 𝑝⁡(𝑦\=1,𝑠⁢|𝛿)\=𝑝⁡(𝑦\=1⁢|𝛿)

(39) 𝑝⁡(𝑠|⁢𝑦\=1,𝛿) \=𝛾⁡((𝑏⁢𝛿))⁢𝒩⁡(𝑠|⁢𝑐1⁢𝛿+𝑐2,𝜎2𝑜⁢𝑏⁢𝑠) .

The log posterior is thus proportional to:

(40) 𝑡⁡(𝛿)∝log⁡𝛾⁡(𝑏⁢𝛿)−12⁢(𝛿−𝜇𝛿𝜎2𝛿)2−12⁢(𝑠−(𝑐1⁢𝛿+𝑐2)𝜎2𝑜⁢𝑏⁢𝑠)2 .

Hence

(41) 𝑡′⁡(𝛿)\=𝑏⁢(1−𝛾⁡(𝑏⁢𝛿))−(𝛿−𝜇𝛿𝜎2𝛿)+𝑐1⁡(𝑠−(𝑐1⁡𝛿+𝑐2)𝜎2𝑜⁢𝑏⁢𝑠) ,

and

(42) 𝑡″⁡(𝛿)\=−𝑏2⁢𝛾⁡(𝑏⁢𝛿)⁢(1−𝛾⁡(𝑏⁢𝛿))−1𝜎2𝛿−𝑐21𝜎2𝑜⁢𝑏⁢𝑠 .

Evaluating these at the prior mean _μ_ _δ_ leads to the update:

(43) 𝑥\=𝜇𝛿+𝑏⁢(1−𝛾⁡(𝑏⁢𝜇𝛿)+𝑐1𝜎2𝑜⁢𝑏⁢𝑠⁢(𝑠−(𝑐1⁢𝜇𝛿+𝑐2)))𝑏2⁢𝛾⁡(𝑏⁢𝜇𝛿)⁢(1−𝛾⁡(𝑏⁢𝜇𝛿))−1𝜎2𝛿−𝑐21𝜎2𝑜⁢𝑏⁢𝑠 ,

(44) \=𝜇𝛿+2⁢𝑘𝑠⁢ℎ⁡𝑎⁢𝑟⁢𝑒⁢𝑑⁡(𝑏⁢(1−𝛾⁡(𝑏⁢𝜇𝛿)))+2⁢𝑘𝑠⁢ℎ⁡𝑎⁢𝑟⁢𝑒⁢𝑑⁡𝑐1𝜎2𝑜⁢𝑏⁢𝑠⁢(𝑠−𝑠𝑝⁢𝑟⁢𝑒⁢𝑑) ,

with 𝑘𝑠⁢ℎ⁡𝑎⁢𝑟⁢𝑒⁢𝑑 and 𝑠𝑝⁢𝑟⁢𝑒⁢𝑑 defined as in the main text.

### C Details of correlated skills derivation

#### C.1 Win/loss only

As stated in the main text, the log posterior is proportional to:

(45) 𝑡𝑤⁢𝑖⁢𝑛⁡(𝜽)∝−12⁢(𝜽−𝝁𝜽)⊺⁢∑−1𝜃(𝜽−𝝁𝜃)+log⁡𝛾⁡(𝑏⁢𝒂⊺⁢𝜽) .

Hence the Jacobian and Hessian functions are given, respectively, by:

(46) 𝒋𝒘𝒊𝒏⁡(𝜽)\=−∑−1𝜃(𝜽−𝝁𝜽)+(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝜽))⁢𝑏⁢𝒂,

(47) 𝑯𝒘𝒊𝒏⁡(𝜽)\=−𝚺−1𝜃−𝛾⁡(𝑏⁢𝒂⊺⁢𝜽)⁢(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝜽))⁢𝑏2⁢𝒂⁢𝒂⊺.

Evaluating these at the prior mean **_μ_** **_θ_** yields:

(48) 𝒋𝒘𝒊𝒏⁡(𝝁𝜽)\=(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽))⁢𝑏⁢𝒂,

(49) 𝑯𝒘𝒊𝒏⁡(𝝁𝜽)\=−∑−1𝜃−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽)⁢(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽))⁢𝑏2⁢𝒂⁢𝒂⊺ ,

as stated in the main text.

#### C.2 Including margin of victory

The log posterior including the margin likelihood is proportional to:

(50) 𝑡𝑚⁢𝑎⁢𝑟⁢𝑔⁡𝑖⁢𝑛⁡(𝜽)∝−12⁢(𝜽−𝝁𝜽)⊺⁢∑−1𝜃(𝜽−𝝁𝜃)+log⁡𝛾⁡(𝑏⁢𝒂⊺⁢𝜽)−12⁢(𝑠−(𝑐1⁢𝒂⊺⁢𝜽+𝑐2)𝜎2𝑜⁢𝑏⁢𝑠)2 ,

(51) \=𝑡𝑤⁢𝑖⁢𝑛⁡(𝜽)−12⁢(𝑠−(𝑐1⁢𝒂⊺⁢𝜽+𝑐2)𝜎2𝑜⁢𝑏⁢𝑠)2 ,

with _t_ _win_ defined as in [Eq. (45)](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_eq_045).

Hence the Jacobian and Hessian functions are given by:

(52) 𝒋𝒎𝒂𝒓𝒈𝒊𝒏⁡(𝜽)\=𝒋𝒘𝒊𝒏⁡(𝜽)+𝑐1𝜎2𝑜⁢𝑏⁢𝑠⁢(𝑠−(𝑐1⁢𝒂⊺⁢𝜽+𝑐2))⁢𝒂,

(53) 𝑯𝒎𝒂𝒓𝒈𝒊𝒏⁡(𝜽)\=𝑯𝒘𝒊𝒏⁡(𝜽)−𝑐21𝜎2𝑜⁢𝑏⁢𝑠⁢𝒂⁢𝒂⊺ .

Evaluating both at the prior mean **_μ_** **_θ_** produces the equations stated in the main text.

### D Comparison between derived update and Glicko

In ([Glickman 1999](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_ref_012 "Glickman, M. E. 1999. “Parameter Estimation in Large Dynamic Paired Comparison Experiments.” Journal of the Royal Statistical Society: Series C (Applied Statistics) 48: 377–94, https://doi.org/10.1111/1467-9876.00159.Search in Google Scholar")), Elo is derived as a special case of a more general approximate Bayesian rating system. Here, we compare the equivalent Elo update derived there with the one in this paper.

[Equation (13)](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_eq_013) in ([Glickman 1999](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_ref_012 "Glickman, M. E. 1999. “Parameter Estimation in Large Dynamic Paired Comparison Experiments.” Journal of the Royal Statistical Society: Series C (Applied Statistics) 48: 377–94, https://doi.org/10.1111/1467-9876.00159.Search in Google Scholar")) recovers Elo as a special case of Glicko under the assumption that the opponents’ skills are known exactly. Considering only a single contest in a period and matching the notation with that used in this paper, the equivalent _k_ becomes:

(54) 𝑘\=𝑏1/𝛿2+1/𝜎2 ,

(55) w⁢h⁡e⁢r⁢e 𝛿2\=\[𝑏2⁢𝛾⁡(𝑏⁢𝜇𝛿)⁢(1−𝛾⁡(𝑏⁢𝜇𝛿))\]−1 .

Since 𝜎2\=𝜎2𝛿/2 , this _k_\-factor is:

(56) 𝑘\=𝑏/21/𝜎2𝛿+(𝑏2/2)⁢𝛾⁡(𝑏⁢𝜇𝛿)⁢(1−𝛾⁡(𝑏⁢𝜇𝛿)) .

This _k_\-factor is almost exactly the same as the one given in [Eq. (17)](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_eq_017), with the exception of the factor of 1/2 in the second term in the denominator. This factor may be due to the assumption that opponents’ skills are known exactly in the derivation.

### E Derivation of approximate log marginal likelihood

The log marginal likelihood for a given match is:

(57) log⁡𝑝⁡(𝑦\=1,𝑠)\=log⁡𝑝⁡(𝑦\=1)+log⁡𝑝⁡(𝑠|⁢𝑦\=1)\=

(58) log⁡\[∫𝑝⁡(𝑦\=1⁢|𝛿)⁢𝑝⁡(𝛿)𝑑𝛿\]+log⁡\[∫𝑝⁡(𝑠|⁢𝑦\=1,𝛿)⁢𝑝⁡(𝛿)𝑑𝛿\]\=log⁡\[∫𝛾⁡(𝑏⁢𝛿)⁢𝒩⁡(𝛿|⁢𝜇𝛿,𝜎2𝛿)𝑑𝛿\]+

(59) log⁡\[∫𝒩⁡(𝑠|⁢𝑐1⁢𝛿+𝑐2,𝜎2𝑜⁢𝑏⁢𝑠)⁢𝒩⁡(𝛿|⁢𝜇𝛿,𝜎2𝛿)𝑑𝛿\] .

The second integral is analytically tractable and reduces to the log density of _s_ given a normal distribution with mean 𝑐1⁢𝜇𝛿+𝑐2 and variance 𝜎2𝑜⁢𝑏⁢𝑠+𝑐21⁢𝜎2𝛿 . The first integral is not analytically tractable but can be approximated well by 𝛾⁢(𝑏⁢𝜇𝛿/𝛼) , where 𝛼\=√1+𝜋⁢𝜎2𝛿⁢𝑏2/8 ([Crooks 2009](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_ref_007 "Crooks, G. E. 2009. Logistic Approximation to the Logistic-Normal Integral. Technical note. available at https://threeplusone.com/pubs/on_logistic_normal.pdf.Search in Google Scholar")). The log marginal likelihood can thus be approximated by:

(60) log⁡𝑝⁡(𝑦\=1,𝑠)≈log⁡𝛾⁢(𝑏⁢𝜇𝛿/𝛼)+log⁡𝒩⁡(𝑠|⁢𝑐1⁢𝜇𝛿+𝑐2,𝜎2𝑜⁢𝑏⁢𝑠+𝑐21⁢𝜎2𝛿) ,

as stated in the main text.

### F Quadrature estimate of the posterior mean

As stated in [Eq. (13)](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_eq_013), the posterior distribution is proportional to:

(61) 𝑝⁡(𝛿|⁢𝑦\=1)∝𝑝⁡(𝛿)⁢𝑝⁡(𝑦\=1⁢|𝛿)\=𝒩⁡(𝛿|⁢𝜇𝛿,𝜎2𝛿)⁢𝛾⁡(𝑏⁢𝛿) .

Hence,

(62) 𝑝⁡(𝛿|⁢𝑦\=1)\=𝑐×𝒩⁡(𝛿|⁢𝜇𝛿,𝜎2𝛿)⁢𝛾⁡(𝑏⁢𝛿) ,

where _c_ is an unknown normalising constant.

We seek the posterior mean of _δ_, that is:

(63) 𝔼⁡\[𝛿|⁢𝑦\=1\]\=∫𝛿⁢𝑝⁡(𝛿|⁢𝑦\=1)𝑑𝛿\=𝑐⁢∫𝛿⁢𝒩⁡(𝛿|⁢𝜇𝛿,𝜎2𝛿)⁢𝛾⁡(𝑏⁢𝛿)𝑑𝛿 .

We first compute _c_ using Gauss-Hermite quadrature:

(64) 1𝑐\=∫𝒩⁡(𝛿|⁢𝜇𝛿,𝜎2𝛿)⁢𝛾⁡(𝑏⁢𝛿)𝑑𝛿.

We then evaluate the integral in [Eq. (63)](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_eq_063) using Gauss-Hermite quadrature a second time and obtain the final result by multiplying its value by _c_.

### G Estimated Grand Slam additions

[Table 8](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_tab_008) shows the players with the largest and smallest estimated Grand Slam additions, as estimated at the end of the 2019 ATP season. Rafael Nadal has the largest estimated addition, adding around 52 rating points when playing at a Grand Slam. Stan Wawrinka also ranks highly which is consistent with his reputation as a “big match player”.**\[7\]** On the other hand, Juan Monaco, Carlos Berlocq and Alexander Zverev are all estimated to perform worse at Grand Slams than at other events.

Table 8:

Grand Slam additions estimated at the end of the 2019 season.

 
| (a) Players with the ten largest Grand Slam additions. | Slam+ |
| --- | --- |
| Rafael Nadal | 51.73 |
| Fernando Verdasco | 33.48 |
| Novak Djokovic | 33.19 |
| Stan Wawrinka | 32.76 |
| Teimuraz Gabashvili | 24.74 |
| Dominic Thiem | 22.64 |
| John Millman | 20.04 |
| Diego Schwartzman | 19.10 |
| Kevin Anderson | 18.66 |
| Andy Murray | 17.88 |
| **(b) Players with the ten smallest Grand Slam additions.** | **Slam+** |
| Federico Delbonis | −13.55 |
| Potito Starace | −13.77 |
| Florian Mayer | −14.02 |
| Gilles Muller | −14.24 |
| Steve Johnson | −14.56 |
| Jack Sock | −15.88 |
| Pablo Cuevas | −17.69 |
| Alexander Zverev | −22.56 |
| Carlos Berlocq | −23.05 |
| Juan Monaco | −23.63 |

### H Equivalence of EKF and Newton-Raphson means

In this section, we show that the approach proposed in [Section 2.5](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_s_002_s_005) leads to the same posterior mean estimate as an extended Kalman filter using a particular choice of measurement error covariance and observation function.

We first state the equations used to update the mean estimate in extended Kalman filtering. Writing the state estimate before the update step as 𝒩⁡(𝝁𝜽,𝚺𝜽) , they can be written as ([Särkkä 2013](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_ref_027 "Särkkä, S. 2013. Bayesian Filtering and Smoothing. Cambridge, UK: Institute of Mathematical Statistics Textbooks, Cambridge University Press.10.1017/CBO9781139344203Search in Google Scholar"), p. 70):

̃𝒚\=𝒛−ℎ⁡(𝝁𝜽) ,𝑺\=𝑮⁡𝚺𝜽⁢𝑮⊺+𝑹 ,𝑲\=𝚺𝜽⁢𝑮⊺⁡𝑺−1 ,𝝁′𝜽\=𝝁𝜽+𝑲⁢̃𝒚 ,

where **_z_** is the vector of observations, _g_( **_x_** ) is a non-linear function from the state vector to the observation vector, **_R_** is the measurement error covariance, and **_G_** is the Jacobian matrix of _g_ evaluated at **_x_** \= **_μ_** **_θ_** , the prior mean. Note that the equations above are typically written with subscripts, e.g. ̃𝒚𝒌 , to denote the update at time step _k_, but we drop these since we consider only a single updating step.

To show the equivalence with our derived approach, we now apply these general equations to the win-only update. We set

𝑔⁡(𝒙)\=𝛾⁡(𝑏⁢𝒂⊺⁢𝒙) ,

which implies

𝑮\=𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽)⁢(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽))⁢𝑏⁢𝒂⊺\=𝜂⁢𝑏⁢𝒂⊺ ,

where we have defined the scalar quantity 𝜂\=𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽)⁢(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽)) to simplify notation in the following. Please note that here, to be consistent with the Kalman filtering literature, the Jacobian is written as a row vector, while other Jacobians in this paper are written as column vectors.

The other equations thus become:

𝑺\=𝜂2⁢𝑏2⁢𝒂⊺⁢𝚺𝜽⁢𝒂+𝑹

and

𝑲\=𝜂⁢𝑏⁢𝚺𝜽⁢𝒂⁢(𝜂2⁢𝑏2⁢𝒂⊺⁢𝚺𝜽⁢𝒂+𝑹)−1 ,

implying the following update to the mean:

(65) 𝝁′𝜽\=𝝁𝜽+𝜂⁢𝑏⁢𝚺𝜽⁢𝒂⁢(𝜂2⁢𝑏2⁢𝒂⊺⁢𝚺𝜽⁢𝒂+𝑹)−1⁢(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽)) ,

where _z_ has been set to 1, reflecting the winning outcome.

The approach derived in this paper in [Section 2.5](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_s_002_s_005) has

𝒋𝒘𝒊𝒏⁡(𝝁𝜽)\=(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽))⁢𝑏⁢𝒂 ,𝑯𝒘𝒊𝒏⁡(𝝁𝜽)\=−𝚺−1𝜃−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽)⁢(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽))⁢𝑏2⁢𝒂⁢𝒂⊺ ,

which are used in a single Newton-Raphson step:

𝝁′𝜽\=𝝁𝜽−𝑯−1⁡(𝝁𝜽)⁢𝒋⁡(𝝁𝜽) ,

yielding

(66) 𝝁′𝜽\=𝝁𝜽+(𝚺−1𝜽+𝜂⁢𝑏2⁢𝒂⁢𝒂⊺)−1⁢(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽))⁢𝑏⁢𝒂 .

We thus see that for the two updates in [Eqs. (65) and (66)](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#j_jqas-2020-0066_eq_065%20j_jqas-2020-0066_eq_066) to be equivalent, we must have

(𝚺−1𝜽+𝜂⁢𝑏2⁢𝒂⁢𝒂⊺)−1⁢𝒂\=𝜂⁢𝚺𝜽⁢𝒂⁢(𝜂2⁢𝑏2⁢𝒂⊺⁢𝚺𝜽⁢𝒂+𝑹)−1 .

We rewrite the matrix inverse term on the left hand side using the Sherman-Morrison formula, yielding:

(𝚺−1𝜽+𝜂⁢𝑏2⁢𝒂⁢𝒂⊺)−1\=𝚺𝜽+𝜂⁢𝑏2⁢𝚺𝜽⁡(𝒂⊺⁢𝚺𝜽⁡𝒂)−𝜂⁢𝑏2⁢𝚺𝜽⁡𝒂⁢𝒂⊺⁢𝚺𝜽𝜂⁢𝑏2⁢𝒂⊺⁢𝚺𝜽⁡𝒂+1 .

Multiplying this expression by **_a_** and making use of the associativity of matrix multiplication, the second and third terms in the numerator cancel, leaving

𝚺𝜽⁢𝒂⁢(𝜂⁢𝑏2⁢𝒂⊺⁢𝚺𝜽⁢𝒂+1)−1\=𝜂⁢𝚺𝜽⁢𝒂⁢(𝜂2⁢𝑏2⁢𝒂⊺⁢𝚺𝜽⁢𝒂+𝜂)−1 ,

which is identical to the EKF update if

𝜂\=𝑹\=𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽)⁢(1−𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽)) ,

which is the variance of a Bernoulli random variable with success probability 𝛾⁡(𝑏⁢𝒂⊺⁢𝝁𝜽) and thus is a reasonable choice for the measurement error variance.

## References

Assimakis, N., and M. Adam. 2014. “Iterative and Algebraic Algorithms for the Computation of the Steady State Kalman Filter Gain.” _International Scholarly Research Notices_ 2014: 417623, [https://doi.org/10.1155/2014/417623](https://doi.org/10.1155/2014/417623).[Search in Google Scholar](https://scholar.google.com/scholar?q=Assimakis%2C%20N.%2C%20and%20M.%20Adam.%202014.%20%E2%80%9CIterative%20and%20Algebraic%20Algorithms%20for%20the%20Computation%20of%20the%20Steady%20State%20Kalman%20Filter%20Gain.%E2%80%9D%20International%20Scholarly%20Research%20Notices%202014%3A%20417623%2C%20.)

Banfield, D., A. P. Ingersoll, and C. L. Keppenne. 1996. “_A Steady-State Kalman Filter for Assimilating Data from a Single Polar Orbiting Satellite_.” _Journal of the Atmospheric Sciences_ 52: 737–53. [https://doi.org/10.1175/1520-0469(1995)052<0737:ASSKFF>2.0.CO;2](https://doi.org/10.1175/1520-0469\(1995\)052%3c0737:ASSKFF%3e2.0.CO;2).[10.1175/1520-0469(1995)052<0737:ASSKFF>2.0.CO;2](https://doi.org/10.1175/1520-0469\(1995\)052%3C0737:ASSKFF%3E2.0.CO;2)[Search in Google Scholar](https://scholar.google.com/scholar?q=Banfield%2C%20D.%2C%20A.%20P.%20Ingersoll%2C%20and%20C.%20L.%20Keppenne.%201996.%20%E2%80%9C%20A%20Steady-State%20Kalman%20Filter%20for%20Assimilating%20Data%20from%20a%20Single%20Polar%20Orbiting%20Satellite%20.%E2%80%9D%20Journal%20of%20the%20Atmospheric%20Sciences%2052%3A%20737%E2%80%9353.%20.)

Boice, J. 2019. How Our MLB Predictions Work. Also available at [https://fivethirtyeight.com/methodology/how-our-mlb-predictions-work/](https://fivethirtyeight.com/methodology/how-our-mlb-predictions-work/).[Search in Google Scholar](https://scholar.google.com/scholar?q=Boice%2C%20J.%202019.%20How%20Our%20MLB%20Predictions%20Work.%20Also%20available%20at%20.)

Bradbury, J., R. Frostig, P. Hawkins, M. J. Johnson, C. Leary, D. Maclaurin, and S. Wanderman-Milne. 2018. JAX: Composable Transformations of Python + NumPy Programs. Also available at [http://github.com/google/jax](http://github.com/google/jax).[Search in Google Scholar](https://scholar.google.com/scholar?q=Bradbury%2C%20J.%2C%20R.%20Frostig%2C%20P.%20Hawkins%2C%20M.%20J.%20Johnson%2C%20C.%20Leary%2C%20D.%20Maclaurin%2C%20and%20S.%20Wanderman-Milne.%202018.%20JAX%3A%20Composable%20Transformations%20of%20Python%C2%A0%2B%C2%A0NumPy%20Programs.%20Also%20available%20at%20.)

Bradley, R. A., and M. E. Terry. 1952. “Rank Analysis of Incomplete Block Designs: The Method of Paired Comparisons.” _Biometrika_ 39: 324–45, [https://doi.org/10.1093/biomet/39.3-4.324](https://doi.org/10.1093/biomet/39.3-4.324).[Search in Google Scholar](https://scholar.google.com/scholar?q=Bradley%2C%20R.%20A.%2C%20and%20M.%20E.%20Terry.%201952.%20%E2%80%9CRank%20Analysis%20of%20Incomplete%20Block%20Designs%3A%20The%20Method%20of%20Paired%20Comparisons.%E2%80%9D%20Biometrika%2039%3A%20324%E2%80%9345%2C%20.)

Carbone, J., T. Corke, and F. Moisiadis. 2016. “The Rugby League Prediction Model: Using an Elo-Based Approach to Predict the Outcome of National Rugby League (NRL) Matches.” _International Educational Scientific Research Journal_ 2: 26–30, [https://doi.org/10.21276/2455-295X](https://doi.org/10.21276/2455-295X).[Search in Google Scholar](https://scholar.google.com/scholar?q=Carbone%2C%20J.%2C%20T.%20Corke%2C%20and%20F.%20Moisiadis.%202016.%20%E2%80%9CThe%20Rugby%20League%20Prediction%20Model%3A%20Using%20an%20Elo-Based%20Approach%20to%20Predict%20the%20Outcome%20of%20National%20Rugby%20League%20%28NRL%29%20Matches.%E2%80%9D%20International%20Educational%20Scientific%20Research%20Journal%202%3A%2026%E2%80%9330%2C%20.)

Crooks, G. E. 2009. Logistic Approximation to the Logistic-Normal Integral. Technical note. available at [https://threeplusone.com/pubs/on\_logistic\_normal.pdf](https://threeplusone.com/pubs/on_logistic_normal.pdf).[Search in Google Scholar](https://scholar.google.com/scholar?q=Crooks%2C%20G.%20E.%202009.%20Logistic%20Approximation%20to%20the%20Logistic-Normal%20Integral.%20Technical%20note.%20available%20at%20.)

Dangauthier, P., R. Herbrich, T. Minka, and T. Graepel. 2008. “Trueskill through Time: Revisiting the History of Chess.” In _Advances in Neural Information Processing Systems_, Vol. 20, 337–44. Red Hook, NY: Curran Associates, Inc. Also available at [https://papers.nips.cc/paper/3331-trueskill-through-time-revisiting-the-history-of-chess](https://papers.nips.cc/paper/3331-trueskill-through-time-revisiting-the-history-of-chess).[Search in Google Scholar](https://scholar.google.com/scholar?q=Dangauthier%2C%20P.%2C%20R.%20Herbrich%2C%20T.%20Minka%2C%20and%20T.%20Graepel.%202008.%20%E2%80%9CTrueskill%20through%20Time%3A%20Revisiting%20the%20History%20of%20Chess.%E2%80%9D%20In%20Advances%20in%20Neural%20Information%20Processing%20Systems%20%2C%20Vol.%2020%2C%20337%E2%80%9344.%20Red%20Hook%2C%20NY%3A%20Curran%20Associates%2C%20Inc.%20Also%20available%20at%20.)

Elo, A. E. 1978. _The Rating of Chess Players, Past and Present_. Arco Pub.[Search in Google Scholar](https://scholar.google.com/scholar?q=Elo%2C%20A.%20E.%201978.%20The%20Rating%20of%20Chess%20Players%2C%20Past%20and%20Present%20.%20Arco%20Pub.)

Fahrmeir, L., and G. Tutz. 1994. “Dynamic Stochastic Models for Time-Dependent Ordered Paired Comparison Systems.” _Journal of the American Statistical Association_ 89: 1438–49, [https://doi.org/10.1080/01621459.1994.10476882](https://doi.org/10.1080/01621459.1994.10476882).[Search in Google Scholar](https://scholar.google.com/scholar?q=Fahrmeir%2C%20L.%2C%20and%20G.%20Tutz.%201994.%20%E2%80%9CDynamic%20Stochastic%20Models%20for%20Time-Dependent%20Ordered%20Paired%20Comparison%20Systems.%E2%80%9D%20Journal%20of%20the%20American%20Statistical%20Association%2089%3A%201438%E2%80%9349%2C%20.)

Gelman, A., J. B. Carlin, H. S. Stern, D. B. Dunson, A. Vehtari, and D. B. Rubin. 2013. _Bayesian Data Analysis_, 3rd ed. Boca Raton, FL, USA: CRC Press. Also available at [http://www.stat.columbia.edu/∼gelman/book/](http://www.stat.columbia.edu/%7Egelman/book/).[10.1201/b16018](https://doi.org/10.1201/b16018)[Search in Google Scholar](https://scholar.google.com/scholar?q=Gelman%2C%20A.%2C%20J.%20B.%20Carlin%2C%20H.%20S.%20Stern%2C%20D.%20B.%20Dunson%2C%20A.%20Vehtari%2C%20and%20D.%20B.%20Rubin.%202013.%20Bayesian%20Data%20Analysis%20%2C%203rd%20ed.%20Boca%20Raton%2C%20FL%2C%20USA%3A%20CRC%20Press.%20Also%20available%20at%20.)

Glickman, M. E. 1999. “Parameter Estimation in Large Dynamic Paired Comparison Experiments.” _Journal of the Royal Statistical Society: Series C (Applied Statistics)_ 48: 377–94, [https://doi.org/10.1111/1467-9876.00159](https://doi.org/10.1111/1467-9876.00159).[Search in Google Scholar](https://scholar.google.com/scholar?q=Glickman%2C%20M.%20E.%201999.%20%E2%80%9CParameter%20Estimation%20in%20Large%20Dynamic%20Paired%20Comparison%20Experiments.%E2%80%9D%20Journal%20of%20the%20Royal%20Statistical%20Society%3A%20Series%20C%20%28Applied%20Statistics%29%2048%3A%20377%E2%80%9394%2C%20.)

Gneiting, T., and A. E. Raftery. 2007. “Strictly Proper Scoring Rules, Prediction, and Estimation.” _Journal of the American Statistical Association_ 102: 359–78, [https://doi.org/10.1198/016214506000001437](https://doi.org/10.1198/016214506000001437).[Search in Google Scholar](https://scholar.google.com/scholar?q=Gneiting%2C%20T.%2C%20and%20A.%20E.%20Raftery.%202007.%20%E2%80%9CStrictly%20Proper%20Scoring%20Rules%2C%20Prediction%2C%20and%20Estimation.%E2%80%9D%20Journal%20of%20the%20American%20Statistical%20Association%20102%3A%20359%E2%80%9378%2C%20.)

Humpherys, J., P. Redd, and J. West. 2012. “A Fresh Look at the Kalman Filter.” _SIAM Review_ 54: 801–23, [https://doi.org/10.1137/100799666](https://doi.org/10.1137/100799666).[Search in Google Scholar](https://scholar.google.com/scholar?q=Humpherys%2C%20J.%2C%20P.%20Redd%2C%20and%20J.%20West.%202012.%20%E2%80%9CA%20Fresh%20Look%20at%20the%20Kalman%20Filter.%E2%80%9D%20SIAM%20Review%2054%3A%20801%E2%80%9323%2C%20.)

Hvattum, L. M., and H. Arntzen. 2010. “Using ELO Ratings for Match Result Prediction in Association Football.” _International Journal of Forecasting_ 26: 460–70, [https://doi.org/10.1016/j.ijforecast.2009.10.002](https://doi.org/10.1016/j.ijforecast.2009.10.002).[Search in Google Scholar](https://scholar.google.com/scholar?q=Hvattum%2C%20L.%20M.%2C%20and%20H.%20Arntzen.%202010.%20%E2%80%9CUsing%20ELO%20Ratings%20for%20Match%20Result%20Prediction%20in%20Association%20Football.%E2%80%9D%20International%20Journal%20of%20Forecasting%2026%3A%20460%E2%80%9370%2C%20.)

Ingram, M. 2019. “A Point-Based Bayesian Hierarchical Model to Predict the Outcome of Tennis Matches.” _Journal of Quantitative Analysis in Sports_ 15: 313–25, [https://doi.org/10.1515/jqas-2018-0008](https://doi.org/10.1515/jqas-2018-0008).[Search in Google Scholar](https://scholar.google.com/scholar?q=Ingram%2C%20M.%202019.%20%E2%80%9CA%20Point-Based%20Bayesian%20Hierarchical%20Model%20to%20Predict%20the%20Outcome%20of%20Tennis%20Matches.%E2%80%9D%20Journal%20of%20Quantitative%20Analysis%20in%20Sports%2015%3A%20313%E2%80%9325%2C%20.)

Karlis, D., and I. Ntzoufras. 2008. “Bayesian Modelling of Football Outcomes: Using the Skellam’s Distribution for the Goal Difference.” _IMA Journal of Management Mathematics_ 20: 133–45, [https://doi.org/10.1093/imaman/dpn026](https://doi.org/10.1093/imaman/dpn026).[Search in Google Scholar](https://scholar.google.com/scholar?q=Karlis%2C%20D.%2C%20and%20I.%20Ntzoufras.%202008.%20%E2%80%9CBayesian%20Modelling%20of%20Football%20Outcomes%3A%20Using%20the%20Skellam%E2%80%99s%20Distribution%20for%20the%20Goal%20Difference.%E2%80%9D%20IMA%20Journal%20of%20Management%20Mathematics%2020%3A%20133%E2%80%9345%2C%20.)

Kovalchik, S. A. 2016. “Searching for the GOAT of Tennis Win Prediction.” _Journal of Quantitative Analysis in Sports_ 12: 127–38, [https://doi.org/10.1515/jqas-2015-0059](https://doi.org/10.1515/jqas-2015-0059).[Search in Google Scholar](https://scholar.google.com/scholar?q=Kovalchik%2C%20S.%20A.%202016.%20%E2%80%9CSearching%20for%20the%20GOAT%20of%20Tennis%20Win%20Prediction.%E2%80%9D%20Journal%20of%20Quantitative%20Analysis%20in%20Sports%2012%3A%20127%E2%80%9338%2C%20.)

Kovalchik, S. 2020. “Extension of the Elo Rating System to Margin of Victory.” _International Journal of Forecasting_ 36: 1329–41. [https://doi.org/10.1016/j.ijforecast.2020.01.006](https://doi.org/10.1016/j.ijforecast.2020.01.006).[Search in Google Scholar](https://scholar.google.com/scholar?q=Kovalchik%2C%20S.%202020.%20%E2%80%9CExtension%20of%20the%20Elo%20Rating%20System%20to%20Margin%20of%20Victory.%E2%80%9D%20International%20Journal%20of%20Forecasting%2036%3A%201329%E2%80%9341.%20.)

Kovalchik, S. A., and M. Ingram. 2018. “Estimating the Duration of Professional Tennis Matches for Varying Formats.” _Journal of Quantitative Analysis in Sports_ 14: 13–23, [https://doi.org/10.1515/jqas-2017-0077](https://doi.org/10.1515/jqas-2017-0077).[Search in Google Scholar](https://scholar.google.com/scholar?q=Kovalchik%2C%20S.%20A.%2C%20and%20M.%20Ingram.%202018.%20%E2%80%9CEstimating%20the%20Duration%20of%20Professional%20Tennis%20Matches%20for%20Varying%20Formats.%E2%80%9D%20Journal%20of%20Quantitative%20Analysis%20in%20Sports%2014%3A%2013%E2%80%9323%2C%20.)

Mangan, S., and K. Collins. 2016. “A Rating System for Gaelic Football Teams: Factors that Influence Success.” _International Journal of Computer Science in Sport_ 15: 78–90, [https://doi.org/10.1515/ijcss-2016-0006](https://doi.org/10.1515/ijcss-2016-0006).[Search in Google Scholar](https://scholar.google.com/scholar?q=Mangan%2C%20S.%2C%20and%20K.%20Collins.%202016.%20%E2%80%9CA%20Rating%20System%20for%20Gaelic%20Football%20Teams%3A%20Factors%20that%20Influence%20Success.%E2%80%9D%20International%20Journal%20of%20Computer%20Science%20in%20Sport%2015%3A%2078%E2%80%9390%2C%20.)

Minka, T. P. 2001. “_Expectation Propagation for Approximate Bayesian Inference_.” In Proceedings of the Seventeenth Conference on Uncertainty in Artificial Intelligence, UAI’01. San Francisco, CA, USA: Morgan Kaufmann Publishers Inc., 362–9.[Search in Google Scholar](https://scholar.google.com/scholar?q=Minka%2C%20T.%20P.%202001.%20%E2%80%9C%20Expectation%20Propagation%20for%20Approximate%20Bayesian%20Inference%20.%E2%80%9D%20In%20Proceedings%20of%20the%20Seventeenth%20Conference%20on%20Uncertainty%20in%20Artificial%20Intelligence%2C%20UAI%E2%80%9901.%20San%20Francisco%2C%20CA%2C%20USA%3A%20Morgan%20Kaufmann%20Publishers%20Inc.%2C%20362%E2%80%939.)

Morris, B., C. Bialik, and J. Boice. 2016. How We’re Forecasting the 2016 U.S. Open. Also available at [https://fivethirtyeight.com/features/how-were-forecasting-the-2016-us-open/](https://fivethirtyeight.com/features/how-were-forecasting-the-2016-us-open/).[Search in Google Scholar](https://scholar.google.com/scholar?q=Morris%2C%20B.%2C%20C.%20Bialik%2C%20and%20J.%20Boice.%202016.%20How%20We%E2%80%99re%20Forecasting%20the%202016%20U.S.%20Open.%20Also%20available%20at%20.)

Neumann, C., J. Duboscq, C. Dubuc, A. Ginting, A. M. Irwan, M. Agil, A. Widdig, and A. Engelhardt. 2011. “Assessing Dominance Hierarchies: Validation and Advantages of Progressive Evaluation with Elo-Rating.” _Animal Behaviour_ 82: 911–21. [https://doi.org/10.1016/j.anbehav.2011.07.016](https://doi.org/10.1016/j.anbehav.2011.07.016).[Search in Google Scholar](https://scholar.google.com/scholar?q=Neumann%2C%20C.%2C%20J.%20Duboscq%2C%20C.%20Dubuc%2C%20A.%20Ginting%2C%20A.%20M.%20Irwan%2C%20M.%20Agil%2C%20A.%20Widdig%2C%20and%20A.%20Engelhardt.%202011.%20%E2%80%9CAssessing%20Dominance%20Hierarchies%3A%20Validation%20and%20Advantages%20of%20Progressive%20Evaluation%20with%20Elo-Rating.%E2%80%9D%20Animal%20Behaviour%2082%3A%20911%E2%80%9321.%20.)

Särkkä, S. 2013. _Bayesian Filtering and Smoothing_. Cambridge, UK: Institute of Mathematical Statistics Textbooks, Cambridge University Press.[10.1017/CBO9781139344203](https://doi.org/10.1017/CBO9781139344203)[Search in Google Scholar](https://scholar.google.com/scholar?q=S%C3%A4rkk%C3%A4%2C%20S.%202013.%20Bayesian%20Filtering%20and%20Smoothing%20.%20Cambridge%2C%20UK%3A%20Institute%20of%20Mathematical%20Statistics%20Textbooks%2C%20Cambridge%20University%20Press.)

Silver, N., J. Boice, and N. Paine. 2019. How Our NFL Predictions Work. Also available at [https://fivethirtyeight.com/methodology/how-our-nfl-predictions-work/](https://fivethirtyeight.com/methodology/how-our-nfl-predictions-work/).[Search in Google Scholar](https://scholar.google.com/scholar?q=Silver%2C%20N.%2C%20J.%20Boice%2C%20and%20N.%20Paine.%202019.%20How%20Our%20NFL%20Predictions%20Work.%20Also%20available%20at%20.)

Sipko, M., and W. Knottenbelt. 2015. _Machine Learning for the Prediction of Professional Tennis Matches. MEng Computing Final Year Project_, Imperial College London, London, UK. Also available at [https://www.doc.ic.ac.uk/teaching/distinguished-projects/2015/m.sipko.pdf](https://www.doc.ic.ac.uk/teaching/distinguished-projects/2015/m.sipko.pdf).[Search in Google Scholar](https://scholar.google.com/scholar?q=Sipko%2C%20M.%2C%20and%20W.%20Knottenbelt.%202015.%20Machine%20Learning%20for%20the%20Prediction%20of%20Professional%20Tennis%20Matches.%20MEng%20Computing%20Final%20Year%20Project%20%2C%20Imperial%20College%20London%2C%20London%2C%20UK.%20Also%20available%20at%20.)

Stefani, R. 2011. “The Methodology of Officially Recognized International Sports Rating Systems.” _Journal of Quantitative Analysis in Sports_ 7: 10, [https://doi.org/10.2202/1559-0410.1347](https://doi.org/10.2202/1559-0410.1347).[Search in Google Scholar](https://scholar.google.com/scholar?q=Stefani%2C%20R.%202011.%20%E2%80%9CThe%20Methodology%20of%20Officially%20Recognized%20International%20Sports%20Rating%20Systems.%E2%80%9D%20Journal%20of%20Quantitative%20Analysis%20in%20Sports%207%3A%2010%2C%20.)

Weng, R. C., and C.-J. Lin. 2011. “A Bayesian Approximation Method for Online Ranking.” _Journal of Machine Learning Research_ 12: 267–300. Also available at [http://jmlr.org/papers/v12/weng11a.html](http://jmlr.org/papers/v12/weng11a.html).[Search in Google Scholar](https://scholar.google.com/scholar?q=Weng%2C%20R.%20C.%2C%20and%20C.-J.%20Lin.%202011.%20%E2%80%9CA%20Bayesian%20Approximation%20Method%20for%20Online%20Ranking.%E2%80%9D%20Journal%20of%20Machine%20Learning%20Research%2012%3A%20267%E2%80%93300.%20Also%20available%20at%20.)

Wilson, K. C. 1972. “An Optimal Control Approach to Designing Constant Gain Filters.” _IEEE Transactions on Aerospace and Electronic Systems_ AES-8: 836–42, [https://doi.org/10.1109/taes.1972.309615](https://doi.org/10.1109/taes.1972.309615).[Search in Google Scholar](https://scholar.google.com/scholar?q=Wilson%2C%20K.%20C.%201972.%20%E2%80%9CAn%20Optimal%20Control%20Approach%20to%20Designing%20Constant%20Gain%20Filters.%E2%80%9D%20IEEE%20Transactions%20on%20Aerospace%20and%20Electronic%20Systems%20AES-8%3A%20836%E2%80%9342%2C%20.)

**Received:** 2020-06-05

**Accepted:** 2020-12-09

**Published Online:** 2021-01-07

**Published in Print:** 2021-09-27

© 2020 Walter de Gruyter GmbH, Berlin/Boston

You are currently not able to access this content.

Not sure if you should have access? Please log in using an institutional account to see if you have access to view or download this content.

[

Purchase Article

$42.00

](https://checkout.degruyterbrill.com/cart?name%7C%7C1e240ee20ed6e4d1c859c43cda5bb122d4350722ed665be43158bfb806291450=How+to+extend+Elo:+a+Bayesian+perspective&category%7C%7C519e3d0a377bd2b1235dc2974bd49a931d254a757334e714ee78cb91116fab5c=electronic&url%7C%7C442a3d01c8e9ee8f781e973a662252e201c3926cd1067ecb39fed51d4245ee69%7C%7Copen=https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0066/html&price%7C%7C53231a9c27c7284ca5c6cba3290383b1bacf61f59ae40f11e8f931bd4ddfe05e=42.00USD&code%7C%7C337b36f9cdb60d9d7238f300549379ceae13ff4508fd249216b0ba8dc1bee140=lang%3Den%7Csubject%3DMT-09%7C10.1515/jqas-2020-0066&image%7C%7C15d4799775d7e654be2b757f16262c633a2f5342dae3e4caa5cd87665e881c25%7C%7Copen=https://www.degruyterbrill.com/document/cover/journal_key/JQAS/thumbnail&Web%7C%7Ceb4e9879378abdbd13538ef882aeabfe57da6331e0051fa749bdca308036c9fe%7C%7Copen=https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0066/html&Format%7C%7C04ebda62f66e09df4a554a06cfb8642df41c17525922c6a0d51aae4abc4cece3=electronic&quantity_max%7C%7C81da5641fc44ff5814fe6e3edaf3b6c15c670316dfea15eafa5932b8d5139a82=1&_ga_item_id%7C%7C59fe5463a3c5a8008c8b916331c8c7f20a98f345bc5483948c6c1d47c081ad6e=10.1515/jqas-2020-0066&template_set=EN_USD)

or

[

Purchase Article

$42.00

](https://checkout.degruyterbrill.com/cart?name%7C%7C1e240ee20ed6e4d1c859c43cda5bb122d4350722ed665be43158bfb806291450=How+to+extend+Elo:+a+Bayesian+perspective&category%7C%7C519e3d0a377bd2b1235dc2974bd49a931d254a757334e714ee78cb91116fab5c=electronic&url%7C%7C442a3d01c8e9ee8f781e973a662252e201c3926cd1067ecb39fed51d4245ee69%7C%7Copen=https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0066/html&price%7C%7C53231a9c27c7284ca5c6cba3290383b1bacf61f59ae40f11e8f931bd4ddfe05e=42.00USD&code%7C%7C337b36f9cdb60d9d7238f300549379ceae13ff4508fd249216b0ba8dc1bee140=lang%3Den%7Csubject%3DMT-09%7C10.1515/jqas-2020-0066&image%7C%7C15d4799775d7e654be2b757f16262c633a2f5342dae3e4caa5cd87665e881c25%7C%7Copen=https://www.degruyterbrill.com/document/cover/journal_key/JQAS/thumbnail&Web%7C%7Ceb4e9879378abdbd13538ef882aeabfe57da6331e0051fa749bdca308036c9fe%7C%7Copen=https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0066/html&Format%7C%7C04ebda62f66e09df4a554a06cfb8642df41c17525922c6a0d51aae4abc4cece3=electronic&quantity_max%7C%7C81da5641fc44ff5814fe6e3edaf3b6c15c670316dfea15eafa5932b8d5139a82=1&_ga_item_id%7C%7C59fe5463a3c5a8008c8b916331c8c7f20a98f345bc5483948c6c1d47c081ad6e=10.1515/jqas-2020-0066&template_set=EN_USD)

From the journal

[Journal of Quantitative Analysis in Sports](https://www.degruyterbrill.com/journal/key/jqas/html) [Volume 17 Issue 3](https://www.degruyterbrill.com/journal/key/jqas/17/3/html)

Published by

[How to publish with us](https://www.degruyterbrill.com/publishing/for-authors) [See all our Titles](https://www.degruyterbrill.com/search?query=*&documentVisibility=all&documentTypeFacet=book&publisherFacet=De+Gruyter)

Readers are also interested in:

[

An option pricing framework for valuation of football players: transfer windows and release clauses

](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2026-0043/html?recommended=sidebar)

[

Assessing course difficulty and variables affecting finish times in amateur cross country running races

](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2024-0093/html?recommended=sidebar)

[

Movement dynamics in elite female soccer athletes: the quantile cube approach

](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2025-0014/html?recommended=sidebar)

Search journal Search the content of this journal

[https://doi.org/10.1515/jqas-2020-0066](https://doi.org/10.1515/jqas-2020-0066)

Keywords for this article

[correlated skills](https://www.degruyterbrill.com/search?query=keywordValues%3A%28correlated+skills%29&documentVisibility=all&documentTypeFacet=article); [margin of victory](https://www.degruyterbrill.com/search?query=keywordValues%3A%28margin+of+victory%29&documentVisibility=all&documentTypeFacet=article); [paired comparison modelling](https://www.degruyterbrill.com/search?query=keywordValues%3A%28paired+comparison+modelling%29&documentVisibility=all&documentTypeFacet=article); [tennis](https://www.degruyterbrill.com/search?query=keywordValues%3A%28tennis%29&documentVisibility=all&documentTypeFacet=article)

[Skip Articles in the same Issue](https://www.degruyterbrill.com/unauthorizedDownload/10.1515/jqas-2020-0066?action=Downloading+PDF&countDenial=true&download=true#footer-newsletter-link)

## Articles in the same Issue

1.  [Frontmatter](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2021-frontmatter3/html)
2.  Research articles
3.  [Winning and losing streaks in the National Hockey League: are teams experiencing momentum or are games a sequence of random events?](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0077/html)
4.  [The middle-seed anomaly: why does it occur in some sports tournaments but not others?](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0065/html)
5.  [A Skellam regression model for quantifying positional value in soccer](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2019-0122/html)
6.  How to extend Elo: a Bayesian perspective
7.  [A mixed effects multinomial logistic-normal model for forecasting baseball performance](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0007/html)
8.  [Distributed lag models to identify the cumulative effects of training and recovery in athletes using multivariate ordinal wellness data](https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0051/html)

Sign up now to receive a 20% welcome discount

[Subscribe to our newsletter](https://www.degruyterbrill.com/publishing/about-us/news-insights/newsletter)

Institutional Access

[How does access work?](https://www.degruyterbrill.com/how-access-works)

Winner of the OpenAthens UX Award 2026

-   
-   
-   
-   
-   

-   [Our privacy policy](https://www.degruyterbrill.com/publishing/our-privacy-policy)
-   [Our cookie policy](https://www.degruyterbrill.com/publishing/our-cookie-policy)
-   [Accessibility](https://www.degruyterbrill.com/publishing/accessibility)
-   [General terms and conditions](https://www.degruyterbrill.com/publishing/terms-conditions)
-   [Legal Notice](https://www.degruyterbrill.com/publishing/legal-notice)
-   [Order cancellation](https://www.degruyterbrill.com/contactForm?role=other&request=generalInquiry&inquiryTemplate=cancelOrder)

Have an idea on how to improve our website?

[Please write us.](https://www.degruyterbrill.com/contactForm?role=other&request=generalInquiry)

© 2026 De Gruyter Brill

Cookie information

We use cookies and other technologies. Some of them are necessary for the website to function and are always set. Cookies for website analysis are not required and are set only with your consent. Some services for analysis process personal data in the USA. With your consent to use these services, you also consent to the processing of your data in the USA. Your consent is voluntary and can be revoked at any time.

[For more information, please see our Cookie Policy.](https://www.degruyterbrill.com/publishing/our-cookie-policy)
