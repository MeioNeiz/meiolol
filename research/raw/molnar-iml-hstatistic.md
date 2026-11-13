# 21  Feature Interaction – Interpretable Machine Learning

<https://christophm.github.io/interpretable-ml-book/interaction.html>

We use cookies

We use cookies and other tracking technologies to improve your browsing experience on our website, to show you personalized content and targeted ads, to analyze our website traffic, and to understand where our visitors are coming from.

[Interpretable Machine Learning](https://christophm.github.io/interpretable-ml-book/)

-   [About the Book](https://christophm.github.io/interpretable-ml-book/)
    
-   [1  Introduction](https://christophm.github.io/interpretable-ml-book/intro.html)
    
-   [2  Interpretability](https://christophm.github.io/interpretable-ml-book/interpretability.html)
    
-   [3  Goals of Interpretability](https://christophm.github.io/interpretable-ml-book/goals.html)
    
-   [4  Methods Overview](https://christophm.github.io/interpretable-ml-book/overview.html)
    
-   [5  Data and Models](https://christophm.github.io/interpretable-ml-book/data.html)
    
-   Interpretable Models
    
    -   [6  Linear Regression](https://christophm.github.io/interpretable-ml-book/limo.html)
        
    -   [7  Logistic Regression](https://christophm.github.io/interpretable-ml-book/logistic.html)
        
    -   [8  GLM, GAM and more](https://christophm.github.io/interpretable-ml-book/extend-lm.html)
        
    -   [9  Decision Tree](https://christophm.github.io/interpretable-ml-book/tree.html)
        
    -   [10  Decision Rules](https://christophm.github.io/interpretable-ml-book/rules.html)
        
    -   [11  RuleFit](https://christophm.github.io/interpretable-ml-book/rulefit.html)
        
-   Local Model-Agnostic Methods
    
    -   [12  Ceteris Paribus Plots](https://christophm.github.io/interpretable-ml-book/ceteris-paribus.html)
        
    -   [13  Individual Conditional Expectation (ICE)](https://christophm.github.io/interpretable-ml-book/ice.html)
        
    -   [14  LIME](https://christophm.github.io/interpretable-ml-book/lime.html)
        
    -   [15  Counterfactual Explanations](https://christophm.github.io/interpretable-ml-book/counterfactual.html)
        
    -   [16  Scoped Rules (Anchors)](https://christophm.github.io/interpretable-ml-book/anchors.html)
        
    -   [17  Shapley Values](https://christophm.github.io/interpretable-ml-book/shapley.html)
        
    -   [18  SHAP](https://christophm.github.io/interpretable-ml-book/shap.html)
        
-   Global Model-Agnostic Methods
    
    -   [19  Partial Dependence Plot (PDP)](https://christophm.github.io/interpretable-ml-book/pdp.html)
        
    -   [20  Accumulated Local Effects (ALE)](https://christophm.github.io/interpretable-ml-book/ale.html)
        
    -   [21  Feature Interaction](https://christophm.github.io/interpretable-ml-book/interaction.html)
        
    -   [22  Functional Decomposition](https://christophm.github.io/interpretable-ml-book/decomposition.html)
        
    -   [23  Permutation Feature Importance](https://christophm.github.io/interpretable-ml-book/feature-importance.html)
        
    -   [24  Leave One Feature Out (LOFO) Importance](https://christophm.github.io/interpretable-ml-book/lofo.html)
        
    -   [25  Surrogate Models](https://christophm.github.io/interpretable-ml-book/global.html)
        
    -   [26  Prototypes and Criticisms](https://christophm.github.io/interpretable-ml-book/proto.html)
        
-   Neural Network Interpretation
    
    -   [27  Learned Features](https://christophm.github.io/interpretable-ml-book/cnn-features.html)
        
    -   [28  Saliency Maps](https://christophm.github.io/interpretable-ml-book/pixel-attribution.html)
        
    -   [29  Detecting Concepts](https://christophm.github.io/interpretable-ml-book/detecting-concepts.html)
        
    -   [30  Adversarial Examples](https://christophm.github.io/interpretable-ml-book/adversarial.html)
        
    -   [31  Influential Instances](https://christophm.github.io/interpretable-ml-book/influential.html)
        
-   Beyond the Methods
    
    -   [32  Evaluation of Interpretability Methods](https://christophm.github.io/interpretable-ml-book/evaluation.html)
        
    -   [33  Story Time](https://christophm.github.io/interpretable-ml-book/storytime.html)
        
    -   [34  The Future of Interpretability](https://christophm.github.io/interpretable-ml-book/future.html)
        
    -   [35  Translations](https://christophm.github.io/interpretable-ml-book/translations.html)
        
-   [36  Citing this Book](https://christophm.github.io/interpretable-ml-book/cite.html)
    
-   [37  Acknowledgments](https://christophm.github.io/interpretable-ml-book/acknowledgements.html)
    
-   Appendices
    
    -   [A  Machine Learning Terms](https://christophm.github.io/interpretable-ml-book/what-is-machine-learning.html)
        
    -   [B  Math Terms](https://christophm.github.io/interpretable-ml-book/math-terms.html)
        
    -   [C  R packages used](https://christophm.github.io/interpretable-ml-book/r-packages.html)
        
    -   [D  References](https://christophm.github.io/interpretable-ml-book/references.html)
        

## Table of contents

-   [What are feature interactions?](https://christophm.github.io/interpretable-ml-book/interaction.html#what-are-feature-interactions)
-   [Friedman’s H-statistic](https://christophm.github.io/interpretable-ml-book/interaction.html#friedmans-h-statistic)
-   [Examples](https://christophm.github.io/interpretable-ml-book/interaction.html#examples)
-   [Strengths](https://christophm.github.io/interpretable-ml-book/interaction.html#strengths)
-   [Limitations](https://christophm.github.io/interpretable-ml-book/interaction.html#limitations)
-   [Software and alternatives](https://christophm.github.io/interpretable-ml-book/interaction.html#software-and-alternatives)

-   [View source](https://github.com/christophM/interpretable-ml-book/blob/main/interaction.qmd)
-   [Report an issue](https://github.com/christophM/interpretable-ml-book/issues/new)

### Buy Book

 [Paperback](https://www.amazon.com/Interpretable-Machine-Learning-Making-Explainable/dp/3911578032) [E-Book & PDF](https://leanpub.com/interpretable-machine-learning)

1.  [Global Model-Agnostic Methods](https://christophm.github.io/interpretable-ml-book/pdp.html)
2.  [21  Feature Interaction](https://christophm.github.io/interpretable-ml-book/interaction.html)

# 21  Feature Interaction

When features interact with each other in a prediction model, the prediction cannot be expressed as the sum of the feature effects because the effect of one feature depends on the value of the other feature. Aristotle’s predicate “The whole is greater than the sum of its parts” applies in the presence of interactions.

## What are feature interactions?

If a machine learning model makes a prediction based on two features, we can decompose the prediction into four terms: a constant term, a term for the first feature, a term for the second feature, and a term for the interaction between the two features. The interaction between two features is the change in the prediction that occurs by varying the features after considering the individual feature effects.

For example, a model predicts the value of a house, using house size (big or small) and location (good or bad) as features, which yields four possible predictions, see [Table 21.1](https://christophm.github.io/interpretable-ml-book/interaction.html#tbl-house-price).

Table 21.1: Example predictions for house prices without interactions

| Location | Size | Prediction |
| --- | --- | --- |
| good | big | 300,000 |
| good | small | 200,000 |
| bad | big | 250,000 |
| bad | small | 150,000 |

We decompose the model prediction into the following parts: A constant term (150,000), an effect for the size feature (+100,000 if big; +0 if small), and an effect for the location (+50,000 if good; +0 if bad). This decomposition fully explains the model predictions. There’s no interaction effect because the model prediction is a sum of the single feature effects for size and location. When you make a small house big, the prediction always increases by 100,000, regardless of location. Also, the difference in prediction between a good and a bad location is 50,000, regardless of size.

Let’s now look at an example with interaction in [Table 21.2](https://christophm.github.io/interpretable-ml-book/interaction.html#tbl-house-price-interaction).

Table 21.2: Example predictions for house prices with interactions

| Location | Size | Prediction |
| --- | --- | --- |
| good | big | 400,000 |
| good | small | 200,000 |
| bad | big | 250,000 |
| bad | small | 150,000 |

We decompose the prediction table into the following parts: A constant term (150,000), an effect for the size feature (+100,000 if big; +0 if small), and an effect for the location (+50,000 if good; +0 if bad). For this table, we need an additional term for the interaction: +100,000 if the house is big and in a good location. So for a big house in a good location, we have: 150,000 (base) + 50,000 (good location) + 100,000 (big) + 100,000 (interaction) = 400,000. This is an interaction between size and location because, in this case, the difference in prediction between a big and a small house depends on the location.

One way to estimate the interaction strength is to measure how much of the variation of the prediction depends on the interaction of the features. This measurement is called H-statistic, introduced by Friedman and Popescu ([2008](https://christophm.github.io/interpretable-ml-book/references.html#ref-friedman2008predictive)).

## Friedman’s H-statistic

We are going to deal with two cases: First, a two-way interaction measure that tells us whether and to what extent two features in the model interact with each other; second, a total interaction measure that tells us whether and to what extent a feature interacts in the model with all the other features. In theory, arbitrary interactions between any number of features can be measured, but these two are the most interesting cases.

If two features do not interact, we can decompose the [partial dependence function](https://christophm.github.io/interpretable-ml-book/pdp.html) as follows (assuming the partial dependence functions are centered at zero):

PDjk(xj,xk)\=PDj(xj)+PDk(xk)

where PDjk(xj,xk) is the 2-way partial dependence function of both features, and PDj(xj) and PDk(xk) are the partial dependence functions of the single features.

Likewise, if a feature has no interaction with any of the other features, we can express the prediction function f^(x) as a sum of partial dependence functions, where the first summand depends only on j and the second on all other features except j:

f^(x)\=PDj(xj)+PD−j(x−j)

where PD−j(x−j) is the partial dependence function that depends on all features except the j\-th feature.

This decomposition expresses the partial dependence (or full prediction) function without interactions (between features j and k, or respectively j and all other features). In a next step, we measure the difference between the observed partial dependence function and the decomposed one without interactions. We calculate the variance of the output of the partial dependence (to measure the interaction between two features) or of the entire function (to measure the interaction between a feature and all other features). The amount of the variance explained by the interaction (difference between observed and no-interaction PD) is used as an interaction strength statistic. The statistic is 0 if there is no interaction at all, and 1 if all of the variance of the PDjk or f^ is explained by the sum of the partial dependence functions. An interaction statistic of 1 between two features means that each single PD function is constant, and the effect on the prediction only comes through the interaction. The H-statistic can also be larger than 1, which is more difficult to interpret. This can happen when the variance of the 2-way interaction is larger than the variance of the 2-dimensional partial dependence plot.

Mathematically, the H-statistic proposed by Friedman and Popescu for the interaction between feature j and k is:

Hjk2\=∑i\=1n\[PDjk(xj(i),xk(i))−PDj(xj(i))−PDk(xk(i))\]2∑i\=1n(PDjk(xj(i),xk(i)))2

The same applies to measuring whether a feature j interacts with any other feature:

Hj2\=∑i\=1n\[f^(x(i))−PDj(xj(i))−PD−j(x−j(i))\]2∑i\=1n(f^(x(i)))2

The H-statistic is expensive to evaluate because it iterates over all data points, and at each point the partial dependence has to be evaluated, which in turn is done with all n data points. In the worst case, we need 2n2 calls to the machine learning model’s predict function to compute the two-way H-statistic (j vs. k) and 3n2 for the total H-statistic (j vs. all). To speed up the computation, we can sample from the n data points. This has the disadvantage of increasing the variance of the partial dependence estimates, which makes the H-statistic unstable. So if you are using sampling to reduce the computational burden, make sure to sample enough data points.

Friedman and Popescu also propose a test statistic to evaluate whether the H-statistic differs significantly from zero. The null hypothesis is the absence of interaction. To generate the interaction statistic under the null hypothesis, you must be able to adjust the model so that it has no interaction between feature j and k or all others. This is not possible for all types of models. Therefore, this test is model-specific, not model-agnostic, and as such not covered here.

The interaction strength statistic can also be applied in a classification setting if the prediction is a probability.

## Examples

Let’s see what feature interactions look like in practice! We analyze the interactions between features in a random forest trained to predict [penguin sex](https://christophm.github.io/interpretable-ml-book/data.html#penguins), given body measurements; see [Figure 21.1](https://christophm.github.io/interpretable-ml-book/interaction.html#fig-interaction-penguins) on the top. The body mass has the highest interaction strength. After looking at the feature interactions of each feature with all other features, we can select one of the features and dive deeper into all the 2-way interactions between the selected feature and the other features. Body mass has the strongest interaction, so let’s take a deeper look in [Figure 21.1](https://christophm.github.io/interpretable-ml-book/interaction.html#fig-interaction-penguins) on the bottom. The plot shows that body mass interacts mostly with bill depth and species.

Figure 21.1: Top: The interaction strength (H-statistic) for each feature with all other features for a random forest predicting P(female). Bottom: The 2-way interaction strengths (H-statistic) between body mass and all other features.

Bonus: We are interested in all interaction by species, which I visualize in [Figure 21.2](https://christophm.github.io/interpretable-ml-book/interaction.html#fig-interaction-penguins-by-species). Especially for body mass, the interaction strengths differ between species.

Figure 21.2: The interaction strength (H-statistic) for each feature with all other features for a random forest by species predicting P(female).

## Strengths

The interaction H-statistic has an **underlying theory** through the partial dependence decomposition.

The H-statistic has a **meaningful interpretation**: The interaction is defined as the share of variance that is explained by the interaction.

Since the statistic is **dimensionless**, it is comparable across features and even across models.

The statistic **detects all kinds of interactions**, regardless of their particular form.

With the H-statistic, it’s also possible to analyze arbitrary **higher-order interactions** such as the interaction strength between 3 or more features.

## Limitations

The first thing you will notice: The interaction H-statistic takes a long time to compute because it’s **computationally expensive**.

The computation involves estimating marginal distributions. These **estimates also have a certain variance** if we do not use all data points. This means that as we sample points, the estimates also vary from run to run, and the **results can be unstable**. I recommend repeating the H-statistic computation a few times to see if you have enough data to get a stable result.

It’s unclear whether an interaction is significantly greater than 0. We would need to conduct a statistical test, but this **test is not (yet) available in a model-agnostic version**.

Concerning the test problem, it is difficult to say when the H-statistic is large enough for us to consider an interaction “strong.”

Also, the **H-statistic can be larger than 1**, which makes the interpretation difficult.

When the total effect of two features is weak but mostly consists of interactions, then the H-statistic will be very large. These spurious interactions require a small denominator of the H-statistic and are made worse when features are correlated. **A spurious interaction can be over-interpreted** as a strong interaction effect when, in reality, both features play a minor role in the model. A possible remedy is to visualize the unnormalized version of the H-statistic, which is the square root of the numerator of the H-statistic ([Inglis, Parnell, and Hurley 2022](https://christophm.github.io/interpretable-ml-book/references.html#ref-inglis2022visualizing)). This scales the H-statistic to the same level as the response, at least for regression, and puts less emphasis on spurious interactions.

Hjk∗\=∑i\=1n\[PDjk(xj(i),xk(i))−PDj(xj(i))−PDk(xk(i))\]2

The H-statistic tells us the strength of interactions, **but it does not tell us how the interactions look like**. That’s what [partial dependence plots](https://christophm.github.io/interpretable-ml-book/pdp.html) are for. A meaningful workflow is to measure the interaction strengths and then create 2D-partial dependence plots for the interactions you are interested in.

The interaction statistic works under the assumption that we can shuffle features independently. If the features correlate strongly, the assumption is violated and **we integrate over feature combinations that are very unlikely in reality**. That’s the same problem that partial dependence plots have. Correlated features can lead to large values of the H-statistic.

Sometimes the results are strange, and for small simulations **do not yield the expected results**. But this is more of an anecdotal observation.

## Software and alternatives

For the examples in this book, I used the R package `iml`, which is available on [CRAN](https://cran.r-project.org/web/packages/iml) and the development version on [GitHub](https://github.com/christophM/iml). There are other implementations, which focus on specific models: The R package [pre](https://cran.r-project.org/web/packages/pre/index.html) implements [RuleFit](https://christophm.github.io/interpretable-ml-book/rulefit.html) and the H-statistic. The R package [gbm](https://github.com/gbm-developers/gbm3) implements gradient boosted models and the H-statistic. In Python, you can find an implementation in the [PiML package](https://selfexplainml.github.io/PiML-Toolbox/_build/html/index.html).

The H-statistic is not the only way to measure interactions:

Variable Interaction Networks (VIN) by Hooker ([2004](https://christophm.github.io/interpretable-ml-book/references.html#ref-hooker2004discovering)) is an approach that decomposes the prediction function into main effects and feature interactions. The interactions between features are then visualized as a network. Unfortunately, no software is available yet.

Partial dependence-based feature interaction by Greenwell, Boehmke, and McCarthy ([2018](https://christophm.github.io/interpretable-ml-book/references.html#ref-greenwell2018simple)) measures the interaction between two features. This approach measures the feature importance (defined as the variance of the partial dependence function) of one feature conditional on different, fixed points of the other feature. If the variance is high, then the features interact with each other; if it’s zero, they do not interact. The corresponding R package `vip` is available on [GitHub](https://github.com/koalaverse/vip). The package also covers partial dependence plots and feature importance.

[20  Accumulated Local Effects (ALE)](https://christophm.github.io/interpretable-ml-book/ale.html)

[22  Functional Decomposition](https://christophm.github.io/interpretable-ml-book/decomposition.html)

[Privacy Policy](https://christophm.github.io/interpretable-ml-book/html/privacy-policy.html) | [Impressum](https://christophmolnar.com/impressum)

[Cookie Preferences](https://christophm.github.io/interpretable-ml-book/interaction.html#)
