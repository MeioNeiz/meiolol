# Conditional variable importance for random forests | BMC Bioinformatics | Springer Nature Link

<https://link.springer.com/article/10.1186/1471-2105-9-307>

## Your privacy, your choice

We use essential cookies to make sure the site can function. We, and our 90 , also use optional cookies and similar technologies for advertising, personalisation of content, usage analysis, and social media.

By accepting optional cookies, you consent to allowing us and our partners to store and access personal data on your device, such as browsing behaviour and unique identifiers. Some third parties are outside of the European Economic Area, with varying standards of data protection. See our [privacy policy](https://link.springer.com/privacystatement) for more information on the use of your personal data. Your consent choices apply to springer.com and applicable subdomains.

You can find further information, and change your preferences via 'Manage preferences'.  
You can also change your preferences or withdraw consent at any time via 'Your privacy choices', found in the footer of every page.

We use cookies and similar technologies for the following purposes:

### Store and/or access information on a device

### Personalised advertising and content, advertising and content measurement, audience research and services development

  

[Skip to main content](https://link.springer.com/article/10.1186/1471-2105-9-307#main)

BMC journals have moved to Springer Nature Link. [Learn more about website changes.](https://support.springernature.com/en/support/solutions/articles/6000281876-springer-nature-brand-websites-are-moving-to-springer-nature-link)

[Log in](https://idp.springer.com/auth/personal/springernature?redirect_uri=https://link.springer.com/article/10.1186/1471-2105-9-307)

[Find a journal](https://link.springer.com/journals/) [Publish with us](https://www.springernature.com/gp/authors) [Track your research](https://link.springernature.com/home/)

[Search](javascript:;)

[Saved research](https://link.springer.com/saved-research)

[Cart](https://order.springer.com/public/cart)

1.  [Home](https://link.springer.com/)
2.  [BMC Bioinformatics](https://link.springer.com/journal/12859)
3.  Article

# Conditional variable importance for random forests

-   Methodology article
-   [Open access](https://www.springernature.com/gp/open-science/about/the-fundamentals-of-open-access-and-open-research)
-   Published: 11 July 2008

-   Volume 9, article number 307 (2008)
-   [Cite this article](https://link.springer.com/article/10.1186/1471-2105-9-307#citeas)

You have full access to this [open access](https://www.springernature.com/gp/open-science/about/the-fundamentals-of-open-access-and-open-research) article

[Download PDF](https://link.springer.com/content/pdf/10.1186/1471-2105-9-307.pdf)

  [BMC Bioinformatics](https://link.springer.com/journal/12859) [Aims and scope](https://link.springer.com/journal/12859/aims-and-scope) [Submit manuscript](https://submission.nature.com/new-submission/12859/3)

-   [Carolin Strobl](https://link.springer.com/article/10.1186/1471-2105-9-307#auth-Carolin-Strobl-Aff1),
-   [Anne-Laure Boulesteix](https://link.springer.com/article/10.1186/1471-2105-9-307#auth-Anne_Laure-Boulesteix-Aff2),
-   [Thomas Kneib](https://link.springer.com/article/10.1186/1471-2105-9-307#auth-Thomas-Kneib-Aff1),
-   [Thomas Augustin](https://link.springer.com/article/10.1186/1471-2105-9-307#auth-Thomas-Augustin-Aff1) &
-   [Achim Zeileis](https://link.springer.com/article/10.1186/1471-2105-9-307#auth-Achim-Zeileis-Aff3) 

-   111k Accesses
    
-   2939 Citations
    
-   92 Altmetric
    
-   5 Mentions
    
-   [Explore all metrics](https://link.springer.com/article/10.1186/1471-2105-9-307/metrics)
    

## Abstract

### Background

Random forests are becoming increasingly popular in many scientific fields because they can cope with "small n large p" problems, complex interactions and even highly correlated predictor variables. Their variable importance measures have recently been suggested as screening tools for, e.g., gene expression studies. However, these variable importance measures show a bias towards correlated predictor variables.

### Results

We identify two mechanisms responsible for this finding: (i) A preference for the selection of correlated predictors in the tree building process and (ii) an additional advantage for correlated predictor variables induced by the unconditional permutation scheme that is employed in the computation of the variable importance measure. Based on these considerations we develop a new, conditional permutation scheme for the computation of the variable importance measure.

### Conclusion

The resulting conditional variable importance reflects the true impact of each predictor variable more reliably than the original marginal approach.

### Similar content being viewed by others

### [Intervention in prediction measure: a new approach to assessing variable importance for random forests](https://link.springer.com/article/10.1186/s12859-017-1650-8?fromPaywallRec=false)

Article Open access 02 May 2017

### [Variable Importance](https://link.springer.com/chapter/10.1007/978-3-030-56485-8_4?fromPaywallRec=false)

Chapter © 2020

### [Conditional permutation importance revisited](https://link.springer.com/article/10.1186/s12859-020-03622-2?fromPaywallRec=false)

Article Open access 14 July 2020

### Explore related subjects

Discover the latest articles, books and news in related subjects, suggested using machine learning.

-   [Applied Probability](https://link.springer.com/subjects/applied-probability)
-   [Logical Analysis](https://link.springer.com/subjects/logical-analysis)
-   [Multivariate Analysis](https://link.springer.com/subjects/multivariate-analysis)
-   [Probability and Statistics in Computer Science](https://link.springer.com/subjects/probability-and-statistics-in-computer-science)
-   [Forest Ecology](https://link.springer.com/subjects/forest-ecology)
-   [Biostatistics](https://link.springer.com/subjects/biostatistics)
-   [Statistical Methods in Psychological Science](https://link.springer.com/subjects/statistical-methods-in-psychological-science)

## 1 Background

Within the past few years, random forests \[[1](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR1 "Breiman L: Random Forests. Machine Learning 2001, 45: 5–32. 10.1023/A:1010933404324")\] have become a popular and widely-used tool for non-parametric regression in many scientific areas. They show high predictive accuracy and are applicable even in high-dimensional problems with highly correlated variables, a situation which often occurs in bioinformatics. Recently, the variable importance measures yielded by random forests have also been suggested for the selection of relevant predictor variables in the analysis of microarray data, DNA sequencing and other applications \[[2](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR2 "Lunetta KL, Hayward LB, Segal J, Eerdewegh PV: Screening Large-Scale Association Study Data: Exploiting Interactions Using Random Forests. BMC Genetics 2004, 5: 32. 10.1186/1471-2156-5-32")–[5](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR5 "Qi Y, Bar-Joseph Z, Klein-Seetharaman J: Evaluation of Different Biological Data and Computational Classification Methods for Use in Protein Interaction Prediction. Proteins 2006, 63(3):490–500. 10.1002/prot.20865")\].

Identifying relevant predictor variables, rather than only predicting the response by means of some "black-box" model, is of interest in many applications. By means of variable importance measures the candidate predictor variables can be compared with respect to their impact in predicting the response or even their causal effect (see, e.g., \[[6](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR6 "Laan M: Statistical Inference for Variable Importance. International Journal of Biostatistics 2006, 2: Article 2. [
http://www.bepress.com/ijb/vol2/iss1/2/
]")\] for assumptions necessary for interpreting the importance of a variable as a causal effect). In this case a key advantage of random forest variable importance measures, as compared to univariate screening methods, is that they cover the impact of each predictor variable individually as well as in multivariate interactions with other predictor variables. For example, Lunetta et al. \[[2](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR2 "Lunetta KL, Hayward LB, Segal J, Eerdewegh PV: Screening Large-Scale Association Study Data: Exploiting Interactions Using Random Forests. BMC Genetics 2004, 5: 32. 10.1186/1471-2156-5-32")\] find that genetic markers relevant in interactions with other markers or environmental variables can be detected more efficiently by means of random forests than by means of univariate screening methods like Fisher's exact test. In the analysis of amino acid sequence data Segal et al. \[[7](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR7 "Segal MR, Cummings MP, Hubbard AE: Relating Amino Acid Sequence to Phenotype: Analysis of Peptide-binding Data. Biometrics 2001, 57(2):632–643. 10.1111/j.0006-341X.2001.00632.x")\] also point out the necessity to consider interactions between sequence positions. Tree-based methods like random forests can help identify relevant predictor variables even in such high dimensional settings involving complex interactions. Therefore, the impact of different amino acid properties, some of which have been shown to be relevant in DNA and protein evolution \[[8](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR8 "Xia X, Li WH: What Amino Acid Properties Affect Protein Evolution? Journal of Molecular Evolution 1998, 47(5):557–564. 10.1007/PL00006412")\], for predicting peptide binding is investigated in our application example in Section 4. However, we will find in this application example, as often in practical problems, that many predictor variables are highly correlated.

The issue of correlated predictor variables is prominent in, but not limited to, applications in genomics and other high-dimensional problems. Therefore, it is important to note that in any non-experimental scientific study, where the predictor variable settings cannot be manipulated independently by the investigator, the distinction between the marginal and the conditional effect of a variable is crucial.

Consider, for example, the apparent correlation between rates of complication after surgery and mortality in hospitals, that was investigated by Silber and Rosenbaum \[[9](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR9 "Silber JH, Rosenbaum PR: A Spurious Correlation Between Hospital Mortality and Complication Rates. The Importance of Severity Adjustment. Journal of Urology 1998, 160: 288–289. 10.1016/S0022-5347(01)63150-1")\]. It is plausible to believe that the mortality rate of a hospital depends on the rate of complications – or even that the mortalities are caused by the complications. However, when severity of illness is taken into account, the correlation disappears \[[9](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR9 "Silber JH, Rosenbaum PR: A Spurious Correlation Between Hospital Mortality and Complication Rates. The Importance of Severity Adjustment. Journal of Urology 1998, 160: 288–289. 10.1016/S0022-5347(01)63150-1")\].

This phenomenon is known as a spurious correlation (see also Stigler \[[10](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR10 "Stigler SM: Correlation and Causation: A Comment. Perspectives in Biology and Medicine 2005, 48: 88–94. Supplement")\] for a historical example). In the hospital mortality example, the spurious correlation is caused by the fact that hospitals that treat many serious cases have both higher complication and mortality rates. However, when conditioning on severity of illness (i.e. comparing only patients with similar severity of illness), mortality is no longer associated with complications.

If you consider this as a prediction problem, once the truly influential background variable (severity of illness) is known, it is clear that the remaining covariate (complication rate) provides no or little additional information for predicting the response (mortality rate). From a statistical point of view, however, this distinction can only be made by a conditional importance measure.

We will point out throughout this chapter that correlations between predictor variables – regardless of whether they arise from small-scale characteristics, such as proximities between genetic loci in organisms, or large-scale characteristics, such as similarities in the clientele of hospitals – severely affect the original random forest variable importance measures, because they can be considered as measures of marginal importance, even though what is of interest in most applications is the conditional effect of each variable. To make this distinction more clear, let us shortly review previous suggestions from the literature for measuring or illustrating variable importance in classification and regression trees (termed "classification trees" in the following for brevity, while all results apply to both classification and regression trees) and random forests: Breiman \[[11](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR11 "Breiman L: Statistical Modeling: The Two Cultures. Statistical Science 2001, 16(3):199–231. 10.1214/ss/1009213726")\] displays the change in the response variable over the range of one predictor variable in "partial dependence plots" (see also \[[12](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR12 "Feraud R, Clerot F: A Methodology to Explain Neural Network Classification. Neural Networks 2002, 15(2):237–246. 10.1016/S0893-6080(01)00127-7")\] for a related approach). This may remind of the interpretation of model coefficients in linear models. However, whether the effect of a variable is interpretable as conditional on all other variables, as in linear models, may not be guaranteed in other models – and we will point out explicitly below that this is not the case in classification trees or random forests.

The permutation accuracy importance, that is described in more detail in Section 2.3, follows the rationale that a random permutation of the values of the predictor variable is supposed to mimic the absence of the variable from the model. The difference in the prediction accuracy before and after permuting the predictor variable, i.e. with and without the help of this predictor variable, is used as an importance measure. The actual permutation accuracy importance measure will be termed "permutation importance" in the following, while the general concept of the impact of a predictor variable in predicting the response is termed "variable importance". The alternative variable importance measure used in random forests, the Gini importance, is based on the principle of impurity reduction that is followed in most traditional classification tree algorithms. However, it has been shown to be biased when predictor variables vary in their number of categories or scale of measurement \[[13](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR13 "Strobl C, Boulesteix AL, Zeileis A, Hothorn T: Bias in Random Forest Variable Importance Measures: Illustrations, Sources and a Solution. BMC Bioinformatics 2007, 8: 25. 10.1186/1471-2105-8-25")\], because the underlying Gini gain splitting criterion is a biased estimator and can be affected by multiple testing effects \[[14](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR14 "Strobl C, Boulesteix AL, Augustin T: Unbiased Split Selection for Classification Trees Based on the Gini Index. Computational Statistics & Data Analysis 2007, 52: 483–501. 10.1016/j.csda.2006.12.030")\]. Therefore, we will focus on the permutation importance in the following, that is reliable when subsampling without replacement – instead of bootstrap sampling – is used in the construction of the forest \[[13](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR13 "Strobl C, Boulesteix AL, Zeileis A, Hothorn T: Bias in Random Forest Variable Importance Measures: Illustrations, Sources and a Solution. BMC Bioinformatics 2007, 8: 25. 10.1186/1471-2105-8-25")\].

Based on the permutation importance, schemes for variable selection and for providing statements of the "significance" of a predictor variable (instead of a merely descriptive ranking of the variables w.r.t. their importance scores) have been derived: Breiman and Cutler \[[15](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR15 "Breiman L, Cutler A: Random Forests – Classification Manual (website accessed in 12/2007).[
http://www.math.usu.edu/~adele/forests/
]")\] suggest a simple significance test that, however, shows poor statistical properties \[[16](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR16 "Strobl C, Zeileis A: Danger: High Power! – Exploring the Statistical Properties of a Test for Random Forest Variable Importance. Proceedings of the 18th International Conference on Computational Statistics, Porto, Portugal 2008.")\]. An approach for variable selection in large scale screening studies is introduced by Diaz-Uriarte and Alvarez de Andres \[[17](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR17 "Diaz-Uriarte R, Alvarez de Andrés S: Gene Selection and Classification of Microarray Data Using Random Forest. BMC Bioinformatics 2006, 7: 3. 10.1186/1471-2105-7-3")\], who suggest a backward elimination strategy. This approach has been shown to provide a reasonable selection of genes in many situations and is freely available in an R package \[[18](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR18 "Diaz-Uriarte R: GeneSrF and varSelRF: A Web-based Tool and R Package for Gene Selection and Classification Using Random Forest. BMC Bioinformatics 2007, 8: 328. 10.1186/1471-2105-8-328")\], that also provides different plots for comparing the performance on the original data set to those on a data set with randomly permuted values of the response variable. The latter mimics the overall null hypothesis that none of the predictor variables is relevant and may serve as a baseline for significance statements. A similar approach is followed by Rodenburg et al. \[[19](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR19 "Rodenburg W, Heidema AG, Boer JM, Bovee-Oudenhoven IM, Feskens EJ, Mariman EC, Keijer J: A Framework to Identify Physiological Responses in Microarray Based Gene Expression Studies: Selection and Interpretation of Biologically Relevant Genes. Physiological Genomics 2008, 33: 78–90. 10.1152/physiolgenomics.00167.2007")\]. However, some recent simulation studies indicate that the performance of the variable importance measures may not be reliable when predictor variables are correlated: Even though Archer and Kimes \[[20](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR20 "Archer KJ, Kimes RV: Empirical characterization of random forest variable importance measures. Computational Statistics & Data Analysis 2008, 52(4):2249–2260. 10.1016/j.csda.2007.08.015")\] show in their extensive simulation study that the Gini importance can identify influential predictor variables out of sets of correlated covariates in many settings, the preliminary results of the simulation study of Nicodemus and Shugart \[[21](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR21 "Nicodemus K, Shugart YY: Impact of Linkage Disequilibrium and Effect Size on the Ability of Machine Learning Methods to Detect Epistasis in Case-Control Studies. Abstract volume of the Sixteenth Annual Meeting of the International Genetic Epidemiology Society, North Yorkshire, UK 2007, 31(6):611.")\] indicate that the ability of the permutation importance to detect influential predictor variables in sets of correlated covariates is less reliable than that of alternative machine learning methods and highly depends on the number of previously selected splitting variables mtry. These studies, as well as our simulation results, indicate that random forests show a preference for correlated predictor variables, that is also carried forward to any significance test or variable selection scheme constructed from the importance measures.

In this work we aim at providing a deeper understanding of the underlying mechanisms responsible for the observations of \[[20](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR20 "Archer KJ, Kimes RV: Empirical characterization of random forest variable importance measures. Computational Statistics & Data Analysis 2008, 52(4):2249–2260. 10.1016/j.csda.2007.08.015")\] and \[[21](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR21 "Nicodemus K, Shugart YY: Impact of Linkage Disequilibrium and Effect Size on the Ability of Machine Learning Methods to Detect Epistasis in Case-Control Studies. Abstract volume of the Sixteenth Annual Meeting of the International Genetic Epidemiology Society, North Yorkshire, UK 2007, 31(6):611.")\]. In addition to this, we want to broaden the scope of considered problems to the comparison of the influence of correlated and uncorrelated predictor variables. For this type of problem we introduce a new, conditional permutation importance for random forests, that better reflects the true importance of predictor variables. Our approach is motivated by the visual means of illustration introduced by Nason et al. \[[22](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR22 "Nason M, Emerson S, Leblanc M: CARTscans: A Tool for Visualizing Complex Models. Journal of Computational and Graphical Statistics 2004, 13(4):1–19. 10.1198/106186004X11417")\]: In their "CARTscans" plots they not only display the marginal influence of a predictor variable, like the partial dependence plots of Breiman \[[11](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR11 "Breiman L: Statistical Modeling: The Two Cultures. Statistical Science 2001, 16(3):199–231. 10.1214/ss/1009213726")\], but the influence of continuous predictor variables separately for the levels of two other, categorical predictor variables, namely a conditional influence plot.

As pointed out above, in the case of correlated predictor variables it is important to distinguish between conditional and marginal influence of a variable, because a variable that may appear influential marginally might actually be independent of the response when considered conditional on another variable. In this respect the approach of \[[22](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR22 "Nason M, Emerson S, Leblanc M: CARTscans: A Tool for Visualizing Complex Models. Journal of Computational and Graphical Statistics 2004, 13(4):1–19. 10.1198/106186004X11417")\] is an important improvement, but in its current form is only applicable for categorical covariates. Therefore our aim in this work is to provide a general scheme that can be used both for illustrating the effect of a variable and for computing its permutation importance conditional on relevant covariates of any type. While the conditioning scheme of \[[22](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR22 "Nason M, Emerson S, Leblanc M: CARTscans: A Tool for Visualizing Complex Models. Journal of Computational and Graphical Statistics 2004, 13(4):1–19. 10.1198/106186004X11417")\] can be considered as a full-factorial cross-tabulation based on two categorical predictor variables, our conditioning scheme is based on a partition of the entire feature space that is determined directly by the fitted random forest model.

In the following Section 2 we will outline how ensembles of classification trees are constructed and illustrate in a simulation study why correlated predictor variables tend to be overselected. Then we will review the construction of the original permutation importance before we introduce a new permutation scheme that we suggest for the construction of a conditional permutation importance measure. The advantage of this measure over the currently-used one is illustrated in the results of our simulation study in Section 3 and in the application to peptide-binding data in Section 4.

## 2 Methods

In random forests and the related method bagging, an ensemble of classification trees is created by means of drawing several bootstrap samples or subsamples from the original training data and fitting a single classification tree to each sample. Due to the random variation in the samples and the instability of the single classification trees, the ensemble will consist of a diverse set of trees. For prediction, a vote (or average) over the predictions of the single trees is used and has been shown to highly outperform the single trees: By combining the prediction of a diverse set of trees, bagging utilizes the fact that classification trees are instable but on average produce the right prediction. This understanding has been supported by several empirical studies (see, e.g., \[[23](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR23 "Breiman L: Bagging Predictors. Machine Learning 1996, 24(2):123–140.")–[26](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR26 "Dietterich TG: An Experimental Comparison of Three Methods for Constructing Ensembles of Decision Trees: Bagging, Boosting, and Randomization. Machine Learning 2000, 40(2):139–157. 10.1023/A:1007607513941")\]) and especially the theoretical results of Bühlmann and Yu \[[27](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR27 "Bühlmann P, Yu B: Analyzing Bagging. The Annals of Statistics 2002, 30(4):927–961. 10.1214/aos/1031689014")\], who could show that the improvement in the prediction accuracy of ensembles is achieved by means of smoothing the hard cut decision boundaries created by splitting in single classification trees, which in return reduces the variance of the prediction.

In random forests, another source of diversity is introduced when the set of predictor variables to select from is randomly restricted in each split, producing even more diverse trees. In addition to the smoothing of hard decision boundaries, the random selection of splitting variables in random forests allows predictor variables that were otherwise outplayed by their competitors to enter the ensemble. Even though these variables may not be optimal with respect to the current split, their selection may reveal interaction effects with other variables that otherwise would have been missed and thus work towards the global optimality of the ensemble.

The classification trees, from which the random forests are built, are built recursively in that the next splitting variable is selected by means of locally optimizing a criterion (such as the Gini gain in the traditional CART algorithm \[[28](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR28 "Breiman L, Friedman JH, Olshen RA, Stone CJ: Classification and Regression Trees. New York: Chapman and Hall; 1984.")\]) within the current node. This current node is defined by a configuration of predictor values, that is determined by all previous splits in the same branch of the tree (see, e.g., \[[29](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR29 "Hastie T, Tibshirani R, Friedman JH: The Elements of Statistical Learning. New York: Springer; 2001.")\] for illustrations). In this respect the evaluation of the next splitting variable can be considered conditional on the previously selected predictor variables, but regardless of any other predictor variable. In particular, the selection of the first splitting variable involves only the marginal, univariate association between that predictor variable and the response, regardless of all other predictor variables. However, this search strategy leads to a variable selection pattern where a predictor variable that is per se only weakly or not at all associated with the response, but is highly correlated with another influential predictor variable, may appear equally well suited for splitting as the truly influential predictor variable. We will illustrate this point in more detail in the following simulation study.

### 2.1 Simulation design

A simulation study was set up in order to illustrate the treatment of correlated predictor variables in ensemble methods based on classification trees. Data sets were generated according to a linear model with twelve predictor variables _y_ _i_ \= _β_1·_x__i_,1\+ ⋯ + _β_12·_x__i_,12\+ _ε_ _i_ , with εi~i.i.d.N(0,0.5). The predictor variables were sampled from a multivariate normal distribution _X_1,..., _X_12 ~ _N_(0, **Σ**) where the covariance structure **Σ** was chosen such that all variables have unit variance _σ__j_, _j_\= 1 and only the first four predictor variables are block-correlated with _σ__j_, _j'_\= 0.9 for _j_ ≠ _j'_ ≤ 4, while the rest were independent with _σ__j_, _j'_\= 0. Of the twelve predictor variables only six were influential, as indicated by their coefficients in Table [1](https://link.springer.com/article/10.1186/1471-2105-9-307#Tab1). A covariance structure of this type was already used for illustrating the effect of correlations by Archer and Kimes \[[20](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR20 "Archer KJ, Kimes RV: Empirical characterization of random forest variable importance measures. Computational Statistics & Data Analysis 2008, 52(4):2249–2260. 10.1016/j.csda.2007.08.015")\]. However, while their study mainly aimed at identifying one influential predictor out of a correlated set, here we also want to compare the importance scores of predictor variables with equally large coefficients, while some of the predictor variables are correlated and others are not: _X_1,..., _X_4 and _X_5,..., _X_8 share the same coefficient pattern, while only _X_1,..., _X_4 are correlated. From the generated data sets, random forests were built with the cforest function from the party package \[[30](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR30 "Hothorn T, Hornik K, Zeileis A: party: A Laboratory for Recursive Part(y)itioning.[
http://CRAN.R-project.org/package=party
]"), [31](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR31 "Hothorn T, Hornik K, Zeileis A: Unbiased Recursive Partitioning: A Conditional Inference Framework. Journal of Computational and Graphical Statistics 2006, 15(3):651–674. 10.1198/106186006X133933")\] in the R system for statistical computing \[[32](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR32 "R Development Core Team:R: A Language and Environment for Statistical Computing. R Foundation for Statistical Computing, Vienna, Austria; 2008. [
http://www.R-project.org/
]")\]. Different values for the parameter mtry, that regulates the number of randomly preselected splitting variables, were considered to be able to investigate the mechanisms responsible for the results of Nicodemus and Shugart \[[21](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR21 "Nicodemus K, Shugart YY: Impact of Linkage Disequilibrium and Effect Size on the Ability of Machine Learning Methods to Detect Epistasis in Case-Control Studies. Abstract volume of the Sixteenth Annual Meeting of the International Genetic Epidemiology Society, North Yorkshire, UK 2007, 31(6):611.")\]. Default settings were used for all other parameters.

**Table 1 Simulation design. Regression coefficients of the data generating process.**

[Full size table](https://link.springer.com/article/10.1186/1471-2105-9-307/tables/1)

### 2.2 Illustration of variable selection

We find in the panel on the left hand side of Figure [1](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig1) that in the first splits of all trees, where the variables are considered only marginally with respect to their association to the response, those variables (_X_3 and _X_4) correlated with highly influential predictors are selected equally often as the highly influential predictor variables (_X_1 and _X_2 as well as _X_5 and _X_6) for mtry = 1, where no competitors are available and the correlated predictors can serve as replacements of the influential ones (the fact that the non-influential predictor variables _X_8 through _X_12 are selected almost equally often is only due to the lax choice of the stop criterion). When mtry increases and the highly influential variables may be available as predominant competitors in some splits those variables (_X_3 and _X_4) correlated with highly influential predictors are selected less often than the highly influential correlated ones (_X_1 and _X_2) themselves, but more often than even the highly influential uncorrelated ones (_X_5 and _X_6). When we consider all splits of all trees in the panel on the right hand side of Figure [1](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig1), the correlated predictors loose most of their advantage because variable selection is now conditional on the previously chosen variables in the same branch of the tree, that may include the truly influential correlated predictors. However, since variable selection is not conditional on all (or at least all correlated) variables, there is still a preference for the correlated variables with low and zero coefficients (_X_3 and _X_4 over _X_7 and _X_8), with a similar dependency on mtry.

**Figure 1**

[Full size image](https://link.springer.com/article/10.1186/1471-2105-9-307/figures/1)

**Selection rates**. Relative selection rates for twelve variables in the first splits (left) and in all splits (right) of all trees in random forests built with different values for mtry.

This selection pattern is due to the locally optimal variable selection scheme used in recursive partitioning, that considers only one variable at a time and conditional only on the current branch. However, since this characteristic of tree-based methods is a crucial means of reducing computational complexity (and any attempts to produce globally optimal partitions are strictly limited to low dimensional problems at the moment \[[33](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR33 "van Os BJ, Meulman J: Globally Optimal Tree Models. In Abstract Book of the 3rd World Conference on Computational Statistics & Data Analysis of the International Association for Statistical Computing, Cyprus, Greece. Edited by: Azen S, Kontoghiorghes E, Lee JC. Matrix Computations and Statistics Group; 2005:79.")\]), it shall remain untouched here.

### 2.3 The permutation importance

The rationale of the original random forest permutation importance is the following: By randomly permuting the predictor variable _X_ _j_ , its original association with the response _Y_ is broken. When the permuted variable _X_ _j_ , together with the remaining non-permuted predictor variables, is used to predict the response for the out-of-bag observations, the prediction accuracy (i.e. the number of observations classified correctly) decreases substantially if the original variable _X_ _j_ was associated with the response. Thus, Breiman \[[1](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR1 "Breiman L: Random Forests. Machine Learning 2001, 45: 5–32. 10.1023/A:1010933404324")\] suggests the difference in prediction accuracy before and after permuting _X_ _j_ , averaged over all trees, as a measure for variable importance, that we formalize as follows: Let ℬ¯(t) be the out-of-bag (oob) sample for a tree _t_, with _t_ ∈ {1,..., _ntree_}. Then the variable importance of variable _X_ _j_ in tree _t_ is

VI(t)(Xj)\=∑i∈ℬ¯(t)I(yi\=y^i(t))|ℬ¯(t)|−∑i∈ℬ¯(t)I(yi\=y^i,πj(t))|ℬ¯(t)|

(1)

where y^i(t)\=f(t)(xi) is the predicted class for observation _i_ before and y^i,πj(t)\=f(t)(xi,πj) is the predicted class for observation _i_ after permuting its value of variable _X_ _j_ , i.e. with xi,πj\=(xi,1,...,xi,j−1,xπj(i),j,xi,j+1,...,xi,p). (Note that _VI_(_t_)(**X** _j_ ) = 0 by definition, if variable _X_ _j_ is not in tree _t_.) The raw variable importance score for each variable is then computed as the mean importance over all trees: VI(Xj)\=∑t\=1ntreeVI(t)(xj)ntree

In standard implementations of random forests an additional scaled version of the permutation importance (often called _z_\-score), that is achieved by dividing the raw importance by its standard error, is provided. However, since recent results \[[16](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR16 "Strobl C, Zeileis A: Danger: High Power! – Exploring the Statistical Properties of a Test for Random Forest Variable Importance. Proceedings of the 18th International Conference on Computational Statistics, Porto, Portugal 2008."), [17](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR17 "Diaz-Uriarte R, Alvarez de Andrés S: Gene Selection and Classification of Microarray Data Using Random Forest. BMC Bioinformatics 2006, 7: 3. 10.1186/1471-2105-7-3")\] indicate that the raw importance _VI_(**X** _j_ ) has better statistical properties, we will only consider the unscaled version here.

### 2.4 Types of independence

We know that the original permutation importance overestimates the importance of correlated predictor variables. Part of this artefact may be due to the preference of correlated predictor variables in early splits as illustrated in Section 2.2. However, we also have to take into account the permutation scheme that is employed in the computation of the permutation importance. In the following we will first outline what notion of independence corresponds to the current permutation scheme of the random forest permutation importance. Then we will introduce a more sensible permutation scheme that better reflects the true impact of predictor variables.

It can help our understanding to consider the permutation scheme in the context of permutation tests \[[34](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR34 "Good P: Permutation, Parametric, and Bootstrap Tests of Hypotheses. 3rd edition. New York: Springer Series in Statistics; 2005.")\]: Usually a null hypothesis is considered that implies the independence of particular (sets of) variables. Under this null hypothesis some permutations of the data are permitted because they preserve the structure determined by the null hypothesis. If, for example, the response variable _Y_ is independent from all predictor variables (global null hypothesis) a permutation of the (observed) values of _Y_ affects neither the marginal distribution of _Y_ nor the joint distribution of _X_1,..., _X_ _p_ and _Y_, because the joint distribution can be factorized as _P_(_Y_, _X_1,..., _X_ _p_ ) = _P_(_Y_)·_P_(_X_1,..., _X_ _p_ ) under the null hypothesis. If, however, the null hypothesis is not true, the same permutation will lead to a deviation in the joint distribution or some reasonable test statistic computed from it. Therefore, a change in the distribution or test statistic caused by the permutation can serve as an indicator that the data do not follow the independence structure we would expect under the null hypothesis.

With this framework in mind, we can now take a second look at the random forest permutation importance and ask: Under which null hypothesis would this permutation scheme be permitted? If the data are actually generated under this null hypothesis the permutation importance will be (a random value from a distribution with mean) zero, while any deviation from the null hypothesis will lead to a change in the prediction accuracy, that is used as a test statistic here, and thus will be detectable as an increase in the value of the permutation importance.

We find that the original permutation importance, where one predictor variable _X_ _j_ is permuted against both the response _Y_ and the remaining (one or more) predictor variables _Z_ = _X_1,..., _X__j_\-1, _X__j_+1,..., _X_ _p_ as illustrated in the left panel of Figure [2](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig2), corresponds to a null hypothesis of independence between _X_ _j_ and both _Y_ and _Z_:

**Figure 2**

[Full size image](https://link.springer.com/article/10.1186/1471-2105-9-307/figures/2)

Permutation scheme for the original marginal (left) and for the newly suggested conditional (right) permutation importance.

_H_0 : _X_ _j_ ⊥ _Y_, _Z_ or equivalently _X_ _j_ ⊥ _Y_ ∧ _X_ _j_ ⊥ _Z_

Under this null hypothesis the joint distribution can be factorized as

P(Y,Xj,Z)\=H0P(Y,Z)⋅P(Xj).

(3)

What is crucial when we want to understand why correlated predictor variables are preferred by the original random forest permutation importance is that a positive value of the importance corresponds to a deviation from this null hypothesis – that can be caused by a violation of either part: the independence of _X_ _j_ and _Y_, or the independence of _X_ _j_ and _Z_. However, from these two aspects only one is of interest when we want to assess the impact of _X_ _j_ to help predict _Y_, namely the question if _X_ _j_ and _Y_ are independent. This aim, to measure only the impact of _X_ _j_ on _Y_, would be better reflected if we could create a measure of deviation from the null hypothesis that _X_ _j_ and _Y_ are independent under a given correlation structure between _X_ _j_ and the other predictor variables, that is determined by our data set. To meet this aim we suggest a conditional permutation scheme, where _X_ _j_ is permuted only within groups of observations with _Z_ = _z_, to preserve the correlation structure between _X_ _j_ and the other predictor variables as illustrated in the right panel of Figure [2](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig2).

This permutation scheme corresponds to the following null hypothesis

_H_0 : (_X_ _j_ ⊥ _Y_)|_Z_, (4)

where the conditional distribution can be factorized under the null hypothesis as

P(Y,Xj|Z)\=H0P(Y|Z)⋅P(Xj|Z)orP(Y|Xj,Z)\=H0P(Y|Z),

(5)

which is the definition of conditional independence.

In the special case where _X_ _j_ and _Z_ are independent both permutation schemes will give the same result, as illustrated by our simulation results below. When _X_ _j_ and _Z_ are correlated, however, the original permutation scheme will lead to an apparent increase in the importance of correlated predictor variables, that is due to deviations from the uninteresting null hypothesis of independence between _X_ _j_ and _Z_.

### 2.5 A new, conditional permutation scheme

Technically, any kind of conditional assessment of the importance of one variable conditional on another one is straightforward whenever the variables to be conditioned on, _Z_, are categorical as in \[[22](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR22 "Nason M, Emerson S, Leblanc M: CARTscans: A Tool for Visualizing Complex Models. Journal of Computational and Graphical Statistics 2004, 13(4):1–19. 10.1198/106186004X11417")\]. However, for our aim to conditionally permute the values of _X_ _j_ within groups of _Z_ = _z_, where _Z_ can contain potentially large sets of covariates of different scales of measurement, we want to supply a grid that (i) is applicable to variables of different types, (ii) is as parsimonious as possible, but (iii) is also computationally feasible. Our suggestion is to define the grid within which the values of _X_ _j_ are permuted for each tree by means of the partition of the feature space induced by that tree. The main advantages of this approach are that this partition was already learned from the data during model fitting, contains splits in categorical, ordered and continuous predictor variables and can thus serve as an internally available means for discretizing the feature space.

In principle, any partition derived from a classification tree can be used to define the permutation grid. Here we used partitions produced by unbiased conditional inference trees \[[31](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR31 "Hothorn T, Hornik K, Zeileis A: Unbiased Recursive Partitioning: A Conditional Inference Framework. Journal of Computational and Graphical Statistics 2006, 15(3):651–674. 10.1198/106186006X133933")\], that employ binary splitting as in the standard CART algorithm \[[28](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR28 "Breiman L, Friedman JH, Olshen RA, Stone CJ: Classification and Regression Trees. New York: Chapman and Hall; 1984.")\]. This means that, if _k_ is the number of categories of an unordered or ordered categorical variable, up to _k_, but potentially less than _k_, subsets of the data are separated.

Continuous variables are treated in the same way: Every binary split in a variable provides one or more cutpoints, that can induce a more or less fine graded grid on this variable. By using the grid resulting from the current tree we are able to condition in a straightforward way not only on categorical, but also on continuous variables and create a grid that may be more parsimonious than the full factorial approach of \[[22](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR22 "Nason M, Emerson S, Leblanc M: CARTscans: A Tool for Visualizing Complex Models. Journal of Computational and Graphical Statistics 2004, 13(4):1–19. 10.1198/106186004X11417")\]. Only in one aspect we suggest to leave the recursive partition induced by a tree: Within a tree structure, each cutpoint refers to a split in a variable only within the current node (i.e. a split in a variable may not bisect the entire sample space but only partial planes of it). However, for ease of computation, we suggest that the conditional permutation grid uses all cutpoints as bisectors of the sample space (the same approach is followed by \[[22](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR22 "Nason M, Emerson S, Leblanc M: CARTscans: A Tool for Visualizing Complex Models. Journal of Computational and Graphical Statistics 2004, 13(4):1–19. 10.1198/106186004X11417")\]). This leads to a more fine graded grid, and may in some cases result in small cell frequencies inducing greater variation (even though our simulation results indicate that in practice this is not a critical issue). From a theoretical point of view, however, conditioning too strictly has no negative effect, while a lack of conditioning produces artefacts as observed for the unconditional permutation importance.

In summary the conditional permutation importance is derived as follows:

1.  1.
    
    In each tree compute the oob-prediction accuracy before the permutation as in Equation [1](https://link.springer.com/article/10.1186/1471-2105-9-307#Equ1): ∑i∈ℬ¯(t)I(yi\=y^i(t))|ℬ¯(t)|.
    
2.  2.
    
    For all variables _Z_ to be conditioned on: Extract the cutpoints that split this variable in the current tree and create a grid by means of bisecting the sample space in each cutpoint.
    
3.  3.
    
    Within this grid permute the values of _X_ _j_ and compute the oob-prediction accuracy after permutation: ∑i∈ℬ¯(t)I(yi\=y^i,πj|Z(t))|ℬ¯(t)|, where y^i,πj|Z(t)\=f(t)(xi,πj|Z) is the predicted classes for observation _i_ after permuting its value of variable _X_ _j_ within the grid defined by the variables _Z_.
    
4.  4.
    
    The difference between the prediction accuracy before and after the permutation accuracy again gives the importance of _X_ _j_ for one tree (see Equation [1](https://link.springer.com/article/10.1186/1471-2105-9-307#Equ1)). The importance of _X_ _j_ for the forest is again computed as an average over all trees.
    

To determine the variables _Z_ to be conditioned on, the most conservative – or rather overcautious -strategy would be to include all other variables as conditioning variables, as was indicated by our initial notation. A more intuitive choice is to include only those variables whose empirical correlation with the variable of interest _X_ _j_ exceeds a certain moderate threshold, as we do with the Pearson correlation coefficient for continuous variables in the following simulation study and application example. For the more general case of predictor variables of different scales of measurement the framework promoted by Hothorn et al. \[[31](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR31 "Hothorn T, Hornik K, Zeileis A: Unbiased Recursive Partitioning: A Conditional Inference Framework. Journal of Computational and Graphical Statistics 2006, 15(3):651–674. 10.1198/106186006X133933")\] provides p-values of conditional inference tests as measures of association. The p-values have the advantage that they are comparable for variables of all types and can serve as an intuitive and objective means for selecting the variables _Z_ to be conditioned on in any problem. Another option is to let the user himself select certain variables to condition on, if, e.g., a hypothesis of interest includes certain independencies.

Note however, that neither a high number of conditioning variables nor a high overall number of variables in the data set poses a problem for the conditional permutation approach: The permutation importance is computed individually for each tree and then averaged over all trees. Correspondingly, the conditioning grid for each tree is determined by the partition of that particular tree only. Thus, even if in principle the stability of the permutation may be affected by small cell counts in the grid, practically the complexity of the grid is limited by the depth of each tree.

The depth of the tree, however, does not depend on the overall number of predictor variables, but on various other characteristics of the data set (most importantly the ratio of relevant vs. noise variables, that is usually low, for example in genomics) in combination with tuning parameter settings (including the number of randomly preselected predictor variables, the split selection criterion, the use of stopping criteria and so forth). Lin and Jeon \[[35](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR35 "Lin Y, Jeon Y: Random Forests and Adaptive Nearest Neighbors. Journal of the American Statistical Association 2006, 101(474):578–590. 10.1198/016214505000001230")\] even point out that limiting the depth of the trees in random forests may prove beneficial w.r.t. prediction accuracy in certain situations.

Another important aspect is that the conditioning variables, especially if there are many, may not necessarily appear all together with the variable of interest in each individual tree, but different combinations may be represented in different trees if the forest is large enough.

## 3 Results

For the simulation design introduced in Section 2.1, Figure [3](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig3) shows the median and interquartile range (over 500 iterations) of the importance scores of each variable for the different permutation schemes: the original marginal permutation and the newly suggested conditional permutation scheme. The set of variables _Z_ to be conditioned on was chosen here to include all variables with an empirical correlation _r_ ≥ .2.

**Figure 3**

[Full size image](https://link.springer.com/article/10.1186/1471-2105-9-307/figures/3)

**Permutation importance**. Median permutation importance for marginal (dashed) and conditional (solid) permutation scheme along with inter-quartile range. Note that the ordering of variables in the plot is arbitrary.

We find that the pattern of the coefficients induced in the data generating process is not reflected by the importance values computed with the ordinary permutation scheme. With this scheme the importance scores of the correlated predictor variables are highly overestimated. This effect is most pronounced for small values of mtry, because correlated variables have a higher chance to end up in a top position in a tree when their correlated competitors are not available.

For the conditional permutation scheme the importance scores better reflect the true pattern: The correlated variables _X_1 and _X_2 with the same coefficient show an almost equal level of importance as the uncorrelated variables _X_5 and _X_6, while the importance of _X_3 and _X_4, that are correlated but have a lower or zero coefficient, decrease. For the variables with small and zero coefficients we still find a difference between the correlated and uncorrelated variables, such that for the correlated variables the importance values are still overestimated – however to a much lesser extent than with the unconditional permutation scheme. This remaining disadvantage of the uncorrelated predictor variables may be due to the fact that for most values of mtry these variables are selected less often and in lower positions in the tree (see Figure [1](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig1)) and thus have a lower chance to produce a high importance value. The degree of the preference of correlated predictor variables also depends on the choice of mtry and is most pronounced for small values of mtry, as expected from the selection frequencies. On the other hand, we find in Figure [3](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig3) that the variability of the importance increases for large values of mtry, and the prediction accuracy is expected to be higher for smaller values of mtry. Another interesting feature of the conditional permutation scheme is that the variability of the conditional importance is lower than that of the unconditional importance within each level of mtry.

With respect to the identifiability of few influential predictors from a set of correlated and other noise variables (which was the task in \[[20](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR20 "Archer KJ, Kimes RV: Empirical characterization of random forest variable importance measures. Computational Statistics & Data Analysis 2008, 52(4):2249–2260. 10.1016/j.csda.2007.08.015")\] and \[[21](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR21 "Nicodemus K, Shugart YY: Impact of Linkage Disequilibrium and Effect Size on the Ability of Machine Learning Methods to Detect Epistasis in Case-Control Studies. Abstract volume of the Sixteenth Annual Meeting of the International Genetic Epidemiology Society, North Yorkshire, UK 2007, 31(6):611.")\]), we can see from the importance scores for _X_1,..., _X_3 in comparison to that of _X_4 that the conditional importance reflects the same pattern as the unconditional importance, however with a notably smaller variation that may improve the identifiability. In the comparison of potentially influential correlated and uncorrelated predictor variables on the other hand, the conditional importance is much better suited as a means of comparison than the original importance. For piecewise constant functions, that can be more easily addressed with recursive partitioning methods, the beneficial effect of conditioning is even stronger than presented here.

## 4 Example: Relating amino acid sequence to phenotype in peptide-binding data

As an application example we consider peptide-binding data that were previously analysed with recursive partitioning techniques by Segal et al. \[[7](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR7 "Segal MR, Cummings MP, Hubbard AE: Relating Amino Acid Sequence to Phenotype: Analysis of Peptide-binding Data. Biometrics 2001, 57(2):632–643. 10.1111/j.0006-341X.2001.00632.x")\]. The data set includes 105 variables for a total of _n_ = 310 amino acid sequences. The response to be predicted is a binding property that can be coded as a binary variable (binding/no binding). The remaining variables available in this data set correspond to 13 amino acid properties for each of the eight considered amino acid positions. These 13 properties include, e.g. volume, polarity, bulkiness, flexibility, aromaticity, and charge, yielding in total 104 continuous predictor variables. A random forest with 1000 trees and mtry = 104 (which corresponds to bagging \[[23](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR23 "Breiman L: Bagging Predictors. Machine Learning 1996, 24(2):123–140."), [24](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR24 "Breiman L: Arcing Classifiers. The Annals of Statistics 1998, 26(3):801–849. 10.1214/aos/1024691079")\] as a special case of a random forest where mtry is equal to the number of candidate predictors and variable selection is not randomly restricted) was fit to the data set. The permutation importance was computed either with the unconditional or the conditional permutation scheme. The resulting importance scores are displayed in Figure [4](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig4) (note that the absolute values of the scores should not be interpreted). The few predictor variables whose importance scores reach highest or even exceed the plotting area would be selected for further analysis by any means. However, for some of the variables with the next smaller importance scores the ranking strongly depends on the permutation scheme. We will focus our illustration on the ranking of three exemplary predictor variables, "h2y8", "flex8" and "pol3", that are highlighted in Figure [4](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig4): We find in the unconditional view in the top panel of Figure [4](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig4) that "h2y8" and "flex8" appear to be of higher importance than "pol3" (ranks "h2y8": 8, "flex8": 9, "pol3": 11). However, in the conditional view in the bottom panel of Figure [4](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig4) their order is reversed and it turns out that "pol3" is really more important than "h2y8" and "flex8"(ranks "h2y8": 9, "flex8": 8, "pol3": 7). This change in the ranks of the predictor variables is most pronounced for large mtry as expected, but similar effects can be observed for smaller values.

**Figure 4**

[Full size image](https://link.springer.com/article/10.1186/1471-2105-9-307/figures/4)

**Example: peptide-binding data**. Marginal (top) and conditional (bottom) permutation importance of 104 predictors of peptide-binding.

When exploring the reason why the importances of "h2y8" and "flex8" are moderated by conditioning, while the importance of "pol3" remains almost constant, we find that "h2y8" and "flex8" are correlated with influential covariates, while "pol3" is only correlated with non-influential covariates. For example, "h2y8" is highly correlated with the polarity at position eight "pol8", that is indicated by the \* symbol in in Figure [4](https://link.springer.com/article/10.1186/1471-2105-9-307#Fig4). The variable "pol8" shows a high importance (that is however also moderated by conditioning) and was already found to be influential by Segal et al. \[[7](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR7 "Segal MR, Cummings MP, Hubbard AE: Relating Amino Acid Sequence to Phenotype: Analysis of Peptide-binding Data. Biometrics 2001, 57(2):632–643. 10.1111/j.0006-341X.2001.00632.x")\], who note that it may approximate an effect of the eighth position in the original sequence data, while the results of Xia and Li \[[8](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR8 "Xia X, Li WH: What Amino Acid Properties Affect Protein Evolution? Journal of Molecular Evolution 1998, 47(5):557–564. 10.1007/PL00006412")\] indicate an effect of the amino acid property polarity itself.

This shows that importance rankings in data sets that contain complex correlations between predictor variables can be severely affected by the underlying permutation scheme: When the conditional permutation is used, the importance scores of correlated predictor are moderated such that the truly influential predictor variables have a higher chance to be detected.

## 5 Discussion and conclusion

We have investigated the sources of preferences in the variable importance measures of random forests in favor of correlated predictor variables and suggested a new, conditional permutation scheme for the computation of the variable importance measure. This new, conditional permutation scheme uses the partition that is automatically provided by the fitted model as a conditioning grid and reflects the true impact of each predictor variable better than the original, marginal approach. Even though the conditional permutation cannot entirely eliminate the preference for correlated predictor variables, it has been shown to provide a more fair means of comparison that can help identify the truly relevant predictor variables. Our simulation results also illustrate the impact of the choice of the random forest tuning parameter mtry: While the default value mtry = p is often found to be optimal with respect to prediction accuracy in empirical studies \[[36](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR36 "Svetnik V, Liaw A, Tong C, Culberson JC, Sheridan RP, Feuston BP: Random Forest: A Classification and Regression Tool for Compound Classification and QSAR Modeling. Journal of Chemical Information and Computer Sciences 2003, 43(6):1947–1958. 10.1021/ci034160g")\], our findings indicate that in the case of correlated predictor variables different values of mtry should be considered. However, it should also be noted that any interpretation of random forest variable importance scores can only be sensible when the number of trees is chosen sufficiently large such that the results produced with different random seeds do not vary systematically. Only then it is assured that the differences between, e.g., unconditional and conditional importance are not only due to random variation.

The conditional permutation importance will be freely available in the next release of the party package for recursive partitioning \[[30](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR30 "Hothorn T, Hornik K, Zeileis A: party: A Laboratory for Recursive Part(y)itioning.[
http://CRAN.R-project.org/package=party
]"), [31](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR31 "Hothorn T, Hornik K, Zeileis A: Unbiased Recursive Partitioning: A Conditional Inference Framework. Journal of Computational and Graphical Statistics 2006, 15(3):651–674. 10.1198/106186006X133933")\] in the R system for statistical computing \[[32](https://link.springer.com/article/10.1186/1471-2105-9-307#ref-CR32 "R Development Core Team:R: A Language and Environment for Statistical Computing. R Foundation for Statistical Computing, Vienna, Austria; 2008. [
http://www.R-project.org/
]")\].

## References

1.  Breiman L: Random Forests. _Machine Learning_ 2001, 45: 5–32. 10.1023/A:1010933404324
    
    [Article](https://doi.org/10.1023%2FA%3A1010933404324)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Random%20Forests&journal=Machine%20Learning&doi=10.1023%2FA%3A1010933404324&volume=45&pages=5-32&publication_year=2001&author=Breiman%2CL) 
    
2.  Lunetta KL, Hayward LB, Segal J, Eerdewegh PV: Screening Large-Scale Association Study Data: Exploiting Interactions Using Random Forests. _BMC Genetics_ 2004, 5: 32. 10.1186/1471-2156-5-32
    
    [Article](https://link.springer.com/article/10.1186/1471-2156-5-32)  [PubMed Central](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC545646)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=15588316)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Screening%20Large-Scale%20Association%20Study%20Data%3A%20Exploiting%20Interactions%20Using%20Random%20Forests&journal=BMC%20Genetics&doi=10.1186%2F1471-2156-5-32&volume=5&publication_year=2004&author=Lunetta%2CKL&author=Hayward%2CLB&author=Segal%2CJ&author=Eerdewegh%2CPV) 
    
3.  Bureau A, Dupuis J, Falls K, Lunetta KL, Hayward B, Keith TP, Eerdewegh PV: Identifying SNPs Predictive of Phenotype Using Random Forests. _Genetic Epidemiology_ 2005, 28(2):171–182. 10.1002/gepi.20041
    
    [Article](https://doi.org/10.1002%2Fgepi.20041)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=15593090)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Identifying%20SNPs%20Predictive%20of%20Phenotype%20Using%20Random%20Forests&journal=Genetic%20Epidemiology&doi=10.1002%2Fgepi.20041&volume=28&issue=2&pages=171-182&publication_year=2005&author=Bureau%2CA&author=Dupuis%2CJ&author=Falls%2CK&author=Lunetta%2CKL&author=Hayward%2CB&author=Keith%2CTP&author=Eerdewegh%2CPV) 
    
4.  Huang X, Pan W, Grindle S, Han X, Chen Y, Park SJ, Miller LW, Hall J: A Comparative Study of Discriminating Human Heart Failure Etiology Using Gene Expression Profiles. _BMC Bioinformatics_ 2005, 6: 205. 10.1186/1471-2105-6-205
    
    [Article](https://link.springer.com/article/10.1186/1471-2105-6-205)  [PubMed Central](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC1224853)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=16120216)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=A%20Comparative%20Study%20of%20Discriminating%20Human%20Heart%20Failure%20Etiology%20Using%20Gene%20Expression%20Profiles&journal=BMC%20Bioinformatics&doi=10.1186%2F1471-2105-6-205&volume=6&publication_year=2005&author=Huang%2CX&author=Pan%2CW&author=Grindle%2CS&author=Han%2CX&author=Chen%2CY&author=Park%2CSJ&author=Miller%2CLW&author=Hall%2CJ) 
    
5.  Qi Y, Bar-Joseph Z, Klein-Seetharaman J: Evaluation of Different Biological Data and Computational Classification Methods for Use in Protein Interaction Prediction. _Proteins_ 2006, 63(3):490–500. 10.1002/prot.20865
    
    [Article](https://doi.org/10.1002%2Fprot.20865)  [PubMed Central](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3250929)  [CAS](https://link.springer.com/articles/cas-redirect/1:CAS:528:DC%2BD28XksFait7o%3D)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=16450363)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Evaluation%20of%20Different%20Biological%20Data%20and%20Computational%20Classification%20Methods%20for%20Use%20in%20Protein%20Interaction%20Prediction&journal=Proteins&doi=10.1002%2Fprot.20865&volume=63&issue=3&pages=490-500&publication_year=2006&author=Qi%2CY&author=Bar-Joseph%2CZ&author=Klein-Seetharaman%2CJ) 
    
6.  Laan M: Statistical Inference for Variable Importance. _International Journal of Biostatistics_ 2006, 2: Article 2. \[[http://www.bepress.com/ijb/vol2/iss1/2/](http://www.bepress.com/ijb/vol2/iss1/2/)\]
    
    [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Statistical%20Inference%20for%20Variable%20Importance&journal=International%20Journal%20of%20Biostatistics&volume=2&publication_year=2006&author=Laan%2CMvan%20der) 
    
7.  Segal MR, Cummings MP, Hubbard AE: Relating Amino Acid Sequence to Phenotype: Analysis of Peptide-binding Data. _Biometrics_ 2001, 57(2):632–643. 10.1111/j.0006-341X.2001.00632.x
    
    [Article](https://doi.org/10.1111%2Fj.0006-341X.2001.00632.x)  [CAS](https://link.springer.com/articles/cas-redirect/1:STN:280:DC%2BD38%2FhsVeguw%3D%3D)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=11414594)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Relating%20Amino%20Acid%20Sequence%20to%20Phenotype%3A%20Analysis%20of%20Peptide-binding%20Data&journal=Biometrics&doi=10.1111%2Fj.0006-341X.2001.00632.x&volume=57&issue=2&pages=632-643&publication_year=2001&author=Segal%2CMR&author=Cummings%2CMP&author=Hubbard%2CAE) 
    
8.  Xia X, Li WH: What Amino Acid Properties Affect Protein Evolution? _Journal of Molecular Evolution_ 1998, 47(5):557–564. 10.1007/PL00006412
    
    [Article](https://link.springer.com/article/10.1007/PL00006412)  [CAS](https://link.springer.com/articles/cas-redirect/1:CAS:528:DyaK1cXntFWhsLc%3D)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=9797406)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=What%20Amino%20Acid%20Properties%20Affect%20Protein%20Evolution%3F&journal=Journal%20of%20Molecular%20Evolution&doi=10.1007%2FPL00006412&volume=47&issue=5&pages=557-564&publication_year=1998&author=Xia%2CX&author=Li%2CWH) 
    
9.  Silber JH, Rosenbaum PR: A Spurious Correlation Between Hospital Mortality and Complication Rates. The Importance of Severity Adjustment. _Journal of Urology_ 1998, 160: 288–289. 10.1016/S0022-5347(01)63150-1
    
    [Article](https://doi.org/10.1016%2FS0022-5347%2801%2963150-1)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=A%20Spurious%20Correlation%20Between%20Hospital%20Mortality%20and%20Complication%20Rates.%20The%20Importance%20of%20Severity%20Adjustment&journal=Journal%20of%20Urology&doi=10.1016%2FS0022-5347%2801%2963150-1&volume=160&pages=288-289&publication_year=1998&author=Silber%2CJH&author=Rosenbaum%2CPR) 
    
10.  Stigler SM: Correlation and Causation: A Comment. _Perspectives in Biology and Medicine_ 2005, 48: 88–94. Supplement
     
     [Article](https://doi.org/10.1353%2Fpbm.2005.0045)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Correlation%20and%20Causation%3A%20A%20Comment&journal=Perspectives%20in%20Biology%20and%20Medicine&doi=Supplement&volume=48&pages=88-94&publication_year=2005&author=Stigler%2CSM) 
     
11.  Breiman L: Statistical Modeling: The Two Cultures. _Statistical Science_ 2001, 16(3):199–231. 10.1214/ss/1009213726
     
     [Article](https://doi.org/10.1214%2Fss%2F1009213726)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Statistical%20Modeling%3A%20The%20Two%20Cultures&journal=Statistical%20Science&doi=10.1214%2Fss%2F1009213726&volume=16&issue=3&pages=199-231&publication_year=2001&author=Breiman%2CL) 
     
12.  Feraud R, Clerot F: A Methodology to Explain Neural Network Classification. _Neural Networks_ 2002, 15(2):237–246. 10.1016/S0893-6080(01)00127-7
     
     [Article](https://doi.org/10.1016%2FS0893-6080%2801%2900127-7)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=12022511)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=A%20Methodology%20to%20Explain%20Neural%20Network%20Classification&journal=Neural%20Networks&doi=10.1016%2FS0893-6080%2801%2900127-7&volume=15&issue=2&pages=237-246&publication_year=2002&author=Feraud%2CR&author=Clerot%2CF) 
     
13.  Strobl C, Boulesteix AL, Zeileis A, Hothorn T: Bias in Random Forest Variable Importance Measures: Illustrations, Sources and a Solution. _BMC Bioinformatics_ 2007, 8: 25. 10.1186/1471-2105-8-25
     
     [Article](https://link.springer.com/article/10.1186/1471-2105-8-25)  [PubMed Central](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC1796903)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=17254353)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Bias%20in%20Random%20Forest%20Variable%20Importance%20Measures%3A%20Illustrations%2C%20Sources%20and%20a%20Solution&journal=BMC%20Bioinformatics&doi=10.1186%2F1471-2105-8-25&volume=8&publication_year=2007&author=Strobl%2CC&author=Boulesteix%2CAL&author=Zeileis%2CA&author=Hothorn%2CT) 
     
14.  Strobl C, Boulesteix AL, Augustin T: Unbiased Split Selection for Classification Trees Based on the Gini Index. _Computational Statistics & Data Analysis_ 2007, 52: 483–501. 10.1016/j.csda.2006.12.030
     
     [Article](https://doi.org/10.1016%2Fj.csda.2006.12.030)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Unbiased%20Split%20Selection%20for%20Classification%20Trees%20Based%20on%20the%20Gini%20Index&journal=Computational%20Statistics%20%26%20Data%20Analysis&doi=10.1016%2Fj.csda.2006.12.030&volume=52&pages=483-501&publication_year=2007&author=Strobl%2CC&author=Boulesteix%2CAL&author=Augustin%2CT) 
     
15.  Breiman L, Cutler A: Random Forests – Classification Manual (website accessed in 12/2007).\[[http://www.math.usu.edu/~adele/forests/](http://www.math.usu.edu/~adele/forests/)\]
     
16.  Strobl C, Zeileis A: Danger: High Power! – Exploring the Statistical Properties of a Test for Random Forest Variable Importance. _Proceedings of the 18th International Conference on Computational Statistics, Porto, Portugal_ 2008.
     
     [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Danger%3A%20High%20Power%21%20%E2%80%93%20Exploring%20the%20Statistical%20Properties%20of%20a%20Test%20for%20Random%20Forest%20Variable%20Importance&publication_year=2008&author=Strobl%2CC&author=Zeileis%2CA) 
     
17.  Diaz-Uriarte R, Alvarez de Andrés S: Gene Selection and Classification of Microarray Data Using Random Forest. _BMC Bioinformatics_ 2006, 7: 3. 10.1186/1471-2105-7-3
     
     [Article](https://link.springer.com/article/10.1186/1471-2105-7-3)  [PubMed Central](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC1363357)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=16398926)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Gene%20Selection%20and%20Classification%20of%20Microarray%20Data%20Using%20Random%20Forest&journal=BMC%20Bioinformatics&doi=10.1186%2F1471-2105-7-3&volume=7&publication_year=2006&author=Diaz-Uriarte%2CR&author=Alvarez%20de%20Andr%C3%A9s%2CS) 
     
18.  Diaz-Uriarte R: GeneSrF and varSelRF: A Web-based Tool and R Package for Gene Selection and Classification Using Random Forest. _BMC Bioinformatics_ 2007, 8: 328. 10.1186/1471-2105-8-328
     
     [Article](https://link.springer.com/article/10.1186/1471-2105-8-328)  [PubMed Central](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2034606)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=17767709)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=GeneSrF%20and%20varSelRF%3A%20A%20Web-based%20Tool%20and%20R%20Package%20for%20Gene%20Selection%20and%20Classification%20Using%20Random%20Forest&journal=BMC%20Bioinformatics&doi=10.1186%2F1471-2105-8-328&volume=8&publication_year=2007&author=Diaz-Uriarte%2CR) 
     
19.  Rodenburg W, Heidema AG, Boer JM, Bovee-Oudenhoven IM, Feskens EJ, Mariman EC, Keijer J: A Framework to Identify Physiological Responses in Microarray Based Gene Expression Studies: Selection and Interpretation of Biologically Relevant Genes. _Physiological Genomics_ 2008, 33: 78–90. 10.1152/physiolgenomics.00167.2007
     
     [Article](https://doi.org/10.1152%2Fphysiolgenomics.00167.2007)  [CAS](https://link.springer.com/articles/cas-redirect/1:CAS:528:DC%2BD1cXmt1Wisrs%3D)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=18162501)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=A%20Framework%20to%20Identify%20Physiological%20Responses%20in%20Microarray%20Based%20Gene%20Expression%20Studies%3A%20Selection%20and%20Interpretation%20of%20Biologically%20Relevant%20Genes&journal=Physiological%20Genomics&doi=10.1152%2Fphysiolgenomics.00167.2007&volume=33&pages=78-90&publication_year=2008&author=Rodenburg%2CW&author=Heidema%2CAG&author=Boer%2CJM&author=Bovee-Oudenhoven%2CIM&author=Feskens%2CEJ&author=Mariman%2CEC&author=Keijer%2CJ) 
     
20.  Archer KJ, Kimes RV: Empirical characterization of random forest variable importance measures. _Computational Statistics & Data Analysis_ 2008, 52(4):2249–2260. 10.1016/j.csda.2007.08.015
     
     [Article](https://doi.org/10.1016%2Fj.csda.2007.08.015)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Empirical%20characterization%20of%20random%20forest%20variable%20importance%20measures&journal=Computational%20Statistics%20%26%20Data%20Analysis&doi=10.1016%2Fj.csda.2007.08.015&volume=52&issue=4&pages=2249-2260&publication_year=2008&author=Archer%2CKJ&author=Kimes%2CRV) 
     
21.  Nicodemus K, Shugart YY: Impact of Linkage Disequilibrium and Effect Size on the Ability of Machine Learning Methods to Detect Epistasis in Case-Control Studies. _Abstract volume of the Sixteenth Annual Meeting of the International Genetic Epidemiology Society, North Yorkshire, UK_ 2007, 31(6):611.
     
     [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Impact%20of%20Linkage%20Disequilibrium%20and%20Effect%20Size%20on%20the%20Ability%20of%20Machine%20Learning%20Methods%20to%20Detect%20Epistasis%20in%20Case-Control%20Studies&journal=Abstract%20volume%20of%20the%20Sixteenth%20Annual%20Meeting%20of%20the%20International%20Genetic%20Epidemiology%20Society%2C%20North%20Yorkshire%2C%20UK&volume=31&issue=6&publication_year=2007&author=Nicodemus%2CK&author=Shugart%2CYY) 
     
22.  Nason M, Emerson S, Leblanc M: CARTscans: A Tool for Visualizing Complex Models. _Journal of Computational and Graphical Statistics_ 2004, 13(4):1–19. 10.1198/106186004X11417
     
     [Article](https://doi.org/10.1198%2F106186004X11417)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=CARTscans%3A%20A%20Tool%20for%20Visualizing%20Complex%20Models&journal=Journal%20of%20Computational%20and%20Graphical%20Statistics&doi=10.1198%2F106186004X11417&volume=13&issue=4&pages=1-19&publication_year=2004&author=Nason%2CM&author=Emerson%2CS&author=Leblanc%2CM) 
     
23.  Breiman L: Bagging Predictors. _Machine Learning_ 1996, 24(2):123–140.
     
     [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Bagging%20Predictors&journal=Machine%20Learning&volume=24&issue=2&pages=123-140&publication_year=1996&author=Breiman%2CL) 
     
24.  Breiman L: Arcing Classifiers. _The Annals of Statistics_ 1998, 26(3):801–849. 10.1214/aos/1024691079
     
     [Article](https://doi.org/10.1214%2Faos%2F1024691079)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Arcing%20Classifiers&journal=The%20Annals%20of%20Statistics&doi=10.1214%2Faos%2F1024691079&volume=26&issue=3&pages=801-849&publication_year=1998&author=Breiman%2CL) 
     
25.  Bauer E, Kohavi R: An Empirical Comparison of Voting Classification Algorithms: Bagging, Boosting, and Variants. _Machine Learning_ 1999, 36(1–2):105–139. 10.1023/A:1007515423169
     
     [Article](https://doi.org/10.1023%2FA%3A1007515423169)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=An%20Empirical%20Comparison%20of%20Voting%20Classification%20Algorithms%3A%20Bagging%2C%20Boosting%2C%20and%20Variants&journal=Machine%20Learning&doi=10.1023%2FA%3A1007515423169&volume=36&issue=1%E2%80%932&pages=105-139&publication_year=1999&author=Bauer%2CE&author=Kohavi%2CR) 
     
26.  Dietterich TG: An Experimental Comparison of Three Methods for Constructing Ensembles of Decision Trees: Bagging, Boosting, and Randomization. _Machine Learning_ 2000, 40(2):139–157. 10.1023/A:1007607513941
     
     [Article](https://doi.org/10.1023%2FA%3A1007607513941)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=An%20Experimental%20Comparison%20of%20Three%20Methods%20for%20Constructing%20Ensembles%20of%20Decision%20Trees%3A%20Bagging%2C%20Boosting%2C%20and%20Randomization&journal=Machine%20Learning&doi=10.1023%2FA%3A1007607513941&volume=40&issue=2&pages=139-157&publication_year=2000&author=Dietterich%2CTG) 
     
27.  Bühlmann P, Yu B: Analyzing Bagging. _The Annals of Statistics_ 2002, 30(4):927–961. 10.1214/aos/1031689014
     
     [Article](https://doi.org/10.1214%2Faos%2F1031689014)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Analyzing%20Bagging&journal=The%20Annals%20of%20Statistics&doi=10.1214%2Faos%2F1031689014&volume=30&issue=4&pages=927-961&publication_year=2002&author=B%C3%BChlmann%2CP&author=Yu%2CB) 
     
28.  Breiman L, Friedman JH, Olshen RA, Stone CJ: _Classification and Regression Trees_. New York: Chapman and Hall; 1984.
     
     [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Classification%20and%20Regression%20Trees&publication_year=1984&author=Breiman%2CL&author=Friedman%2CJH&author=Olshen%2CRA&author=Stone%2CCJ) 
     
29.  Hastie T, Tibshirani R, Friedman JH: _The Elements of Statistical Learning_. New York: Springer; 2001.
     
     [Book](https://link.springer.com/book/10.1007/978-0-387-21606-5)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=The%20Elements%20of%20Statistical%20Learning&doi=10.1007%2F978-0-387-21606-5&publication_year=2001&author=Hastie%2CT&author=Tibshirani%2CR&author=Friedman%2CJH) 
     
30.  Hothorn T, Hornik K, Zeileis A: party: A Laboratory for Recursive Part(y)itioning.\[[http://CRAN.R-project.org/package=party](http://cran.r-project.org/package=party)\]
     
31.  Hothorn T, Hornik K, Zeileis A: Unbiased Recursive Partitioning: A Conditional Inference Framework. _Journal of Computational and Graphical Statistics_ 2006, 15(3):651–674. 10.1198/106186006X133933
     
     [Article](https://doi.org/10.1198%2F106186006X133933)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Unbiased%20Recursive%20Partitioning%3A%20A%20Conditional%20Inference%20Framework&journal=Journal%20of%20Computational%20and%20Graphical%20Statistics&doi=10.1198%2F106186006X133933&volume=15&issue=3&pages=651-674&publication_year=2006&author=Hothorn%2CT&author=Hornik%2CK&author=Zeileis%2CA) 
     
32.  R Development Core Team:_R: A Language and Environment for Statistical Computing_. R Foundation for Statistical Computing, Vienna, Austria; 2008. \[[http://www.R-project.org/](http://www.r-project.org/)\]
     
     [Google Scholar](http://scholar.google.com/scholar_lookup?&title=R%3A%20A%20Language%20and%20Environment%20for%20Statistical%20Computing&publication_year=2008) 
     
33.  van Os BJ, Meulman J: Globally Optimal Tree Models. In _Abstract Book of the 3rd World Conference on Computational Statistics & Data Analysis of the International Association for Statistical Computing, Cyprus, Greece_. Edited by: Azen S, Kontoghiorghes E, Lee JC. Matrix Computations and Statistics Group; 2005:79.
     
     [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Globally%20Optimal%20Tree%20Models&publication_year=2005&author=van%20Os%2CBJ&author=Meulman%2CJ) 
     
34.  Good P: _Permutation, Parametric, and Bootstrap Tests of Hypotheses_. 3rd edition. New York: Springer Series in Statistics; 2005.
     
     [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Permutation%2C%20Parametric%2C%20and%20Bootstrap%20Tests%20of%20Hypotheses&publication_year=2005&author=Good%2CP) 
     
35.  Lin Y, Jeon Y: Random Forests and Adaptive Nearest Neighbors. _Journal of the American Statistical Association_ 2006, 101(474):578–590. 10.1198/016214505000001230
     
     [Article](https://doi.org/10.1198%2F016214505000001230)  [CAS](https://link.springer.com/articles/cas-redirect/1:CAS:528:DC%2BD2sXms1ymsA%3D%3D)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Random%20Forests%20and%20Adaptive%20Nearest%20Neighbors&journal=Journal%20of%20the%20American%20Statistical%20Association&doi=10.1198%2F016214505000001230&volume=101&issue=474&pages=578-590&publication_year=2006&author=Lin%2CY&author=Jeon%2CY) 
     
36.  Svetnik V, Liaw A, Tong C, Culberson JC, Sheridan RP, Feuston BP: Random Forest: A Classification and Regression Tool for Compound Classification and QSAR Modeling. _Journal of Chemical Information and Computer Sciences_ 2003, 43(6):1947–1958. 10.1021/ci034160g
     
     [CAS](https://link.springer.com/articles/cas-redirect/1:CAS:528:DC%2BD3sXos1Wiu7s%3D)  [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=14632445)  [Google Scholar](http://scholar.google.com/scholar_lookup?&title=Random%20Forest%3A%20A%20Classification%20and%20Regression%20Tool%20for%20Compound%20Classification%20and%20QSAR%20Modeling&journal=Journal%20of%20Chemical%20Information%20and%20Computer%20Sciences&doi=10.1021%2Fci034160g&volume=43&issue=6&pages=1947-1958&publication_year=2003&author=Svetnik%2CV&author=Liaw%2CA&author=Tong%2CC&author=Culberson%2CJC&author=Sheridan%2CRP&author=Feuston%2CBP) 
     

[Download references](https://citation-needed.springer.com/v2/references/10.1186/1471-2105-9-307?format=refman&flavour=references)

## Acknowledgements

A–LB was supported by the Porticus Foundation in the context of the International School for Technical Medicine and Clinical Bioinformatics.

The authors would like to thank Torsten Hothorn for providing essential help with accessing and processing cforest objects.

## Author information

### Authors and Affiliations

1.  Department of Statistics, Ludwig-Maximilians-Universität Munchen, Ludwigstraße 33, D-80539, München, Germany
    
    Carolin Strobl, Thomas Kneib & Thomas Augustin
    
2.  Sylvia Lawry Centre for Multiple Sclerosis Research, Hohenlindener Straße 1, D-81677, München, Germany
    
    Anne-Laure Boulesteix
    
3.  Department of Statistics and Mathematics, Wirtschaftsuniversität Wien, Augasse 2 – 6, A-1090, Wien, Austria
    
    Achim Zeileis
    

### Corresponding author

Correspondence to [Carolin Strobl](mailto:carolin.strobl@stat.uni-muenchen.de).

## Additional information

### Authors' contributions

CS defined the research question, suggested the conditional variable importance, set up and performed the simulation experiments and drafted the manuscript. A–LB analyzed the peptide-binding data. TK, TA and AZ contributed to the theoretical understanding and presentation of the problem. All authors contributed to and approved the final version of the manuscript.

## Authors’ original submitted files for images

Below are the links to the authors’ original submitted files for images.

### [Authors’ original file for figure 1 (download PDF )](https://media.springernature.com/original/springer-static/esm/art%3A10.1186%2F1471-2105-9-307/MediaObjects/12859_2008_2292_MOESM1_ESM.pdf)

### [Authors’ original file for figure 2 (download JPEG )](https://media.springernature.com/original/springer-static/esm/art%3A10.1186%2F1471-2105-9-307/MediaObjects/12859_2008_2292_MOESM2_ESM.jpeg)

### [Authors’ original file for figure 3 (download PDF )](https://media.springernature.com/original/springer-static/esm/art%3A10.1186%2F1471-2105-9-307/MediaObjects/12859_2008_2292_MOESM3_ESM.pdf)

### [Authors’ original file for figure 4 (download PDF )](https://media.springernature.com/original/springer-static/esm/art%3A10.1186%2F1471-2105-9-307/MediaObjects/12859_2008_2292_MOESM4_ESM.pdf)

## Rights and permissions

This article is published under license to BioMed Central Ltd. This is an Open Access article distributed under the terms of the Creative Commons Attribution License ([http://creativecommons.org/licenses/by/2.0](http://creativecommons.org/licenses/by/2.0)), which permits unrestricted use, distribution, and reproduction in any medium, provided the original work is properly cited.

[Reprints and permissions](https://s100.copyright.com/AppDispatchServlet?title=Conditional%20variable%20importance%20for%20random%20forests&author=Carolin%20Strobl%20et%20al&contentID=10.1186%2F1471-2105-9-307&copyright=Strobl%20et%20al%3B%20licensee%20BioMed%20Central%20Ltd.&publication=1471-2105&publicationDate=2008-07-11&publisherName=SpringerNature&orderBeanReset=true&oa=CC%20BY)

## About this article

### Cite this article

Strobl, C., Boulesteix, AL., Kneib, T. _et al._ Conditional variable importance for random forests. _BMC Bioinformatics_ **9**, 307 (2008). https://doi.org/10.1186/1471-2105-9-307

[Download citation](https://citation-needed.springer.com/v2/references/10.1186/1471-2105-9-307?format=refman&flavour=citation)

-   Received01 April 2008
    
-   Accepted11 July 2008
    
-   Published11 July 2008
    
-   DOIhttps://doi.org/10.1186/1471-2105-9-307
    

### Share this article

Anyone you share the following link with will be able to read this content:

Provided by the Springer Nature SharedIt content-sharing initiative

### Keywords

-   [Random Forest](https://link.springer.com/search?query=Random%20Forest&facet-discipline=%22Life%20Sciences%22)
-   [Importance Measure](https://link.springer.com/search?query=Importance%20Measure&facet-discipline=%22Life%20Sciences%22)
-   [Importance Score](https://link.springer.com/search?query=Importance%20Score&facet-discipline=%22Life%20Sciences%22)
-   [Amino Acid Property](https://link.springer.com/search?query=Amino%20Acid%20Property&facet-discipline=%22Life%20Sciences%22)
-   [Permutation Scheme](https://link.springer.com/search?query=Permutation%20Scheme&facet-discipline=%22Life%20Sciences%22)

-   
-   
-   

-   [Abstract](https://link.springer.com/article/10.1186/1471-2105-9-307#Abs1)
-   [1 Background](https://link.springer.com/article/10.1186/1471-2105-9-307#Sec1)
-   [2 Methods](https://link.springer.com/article/10.1186/1471-2105-9-307#Sec2)
-   [3 Results](https://link.springer.com/article/10.1186/1471-2105-9-307#Sec8)
-   [4 Example: Relating amino acid sequence to phenotype in peptide-binding data](https://link.springer.com/article/10.1186/1471-2105-9-307#Sec9)
-   [5 Discussion and conclusion](https://link.springer.com/article/10.1186/1471-2105-9-307#Sec10)
-   [References](https://link.springer.com/article/10.1186/1471-2105-9-307#Bib1)
-   [Acknowledgements](https://link.springer.com/article/10.1186/1471-2105-9-307#Ack1)
-   [Author information](https://link.springer.com/article/10.1186/1471-2105-9-307#author-information)
-   [Additional information](https://link.springer.com/article/10.1186/1471-2105-9-307#additional-information)
-   [Authors’ original submitted files for images](https://link.springer.com/article/10.1186/1471-2105-9-307#Sec11)
-   [Rights and permissions](https://link.springer.com/article/10.1186/1471-2105-9-307#rightslink)
-   [About this article](https://link.springer.com/article/10.1186/1471-2105-9-307#article-info)

Advertisement

## Footer Navigation

### Discover content

-   [Journals A-Z](https://link.springer.com/journals/a/1)
-   [Books A-Z](https://link.springer.com/books/a/1)
-   [Subjects A-Z](https://link.springer.com/subjects)

### Publish with us

-   [Journal finder](https://link.springer.com/journals)
-   [Publish your research](https://www.springernature.com/gp/authors)
-   [Language editing](https://authorservices.springernature.com/go/sn/?utm_source=SNLinkfooter&utm_medium=Web&utm_campaign=SNReferral)
-   [Open access publishing](https://www.springernature.com/gp/open-science/about/the-fundamentals-of-open-access-and-open-research)

### Products and services

-   [Our products](https://www.springernature.com/gp/products)
-   [Librarians](https://www.springernature.com/gp/librarians)
-   [Societies](https://www.springernature.com/gp/societies)
-   [Partners and advertisers](https://www.springernature.com/gp/partners)

### Our brands

-   [Springer](https://link.springer.com/brands/springer)
-   [Nature Portfolio](https://www.nature.com/nature-portfolio)
-   [BMC](https://link.springer.com/brands/bmc)
-   [Palgrave Macmillan](https://link.springer.com/brands/palgrave)
-   [Apress](https://link.springer.com/brands/apress)
-   [Discover](https://link.springer.com/brands/discover)

### Corporate Navigation

-   
-   [Your US state privacy rights](https://www.springernature.com/gp/legal/ccpa)
-   [Accessibility statement](https://link.springer.com/accessibility)
-   [Terms and conditions](https://link.springer.com/termsandconditions)
-   [Privacy policy](https://link.springer.com/privacystatement)
-   [Help and support](https://support.springernature.com/en/support/home)
-   [Legal notice](https://link.springer.com/legal-notice)
-   [Cancel contracts here](https://support.springernature.com/en/support/solutions/articles/6000255911-subscription-cancellations)

145.40.153.13

Not affiliated

© 2026 Springer Nature
