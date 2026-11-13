# Explainable Boosting Machine — InterpretML documentation

<https://interpret.ml/docs/ebm.html>

[Skip to main content](https://interpret.ml/docs/ebm.html#main-content)

-   [Getting Started](https://interpret.ml/docs/index.html)

-   [API Reference](https://interpret.ml/docs/interpret.html)
-   [Algorithms](https://interpret.ml/docs/algorithms.html)
    
    -   [Glassbox Models](https://interpret.ml/docs/glassbox.html)
        
        -   [Explainable Boosting Machine](https://interpret.ml/docs/ebm.html#)
        -   [Automatic Piecewise Linear Regression (APLR)](https://interpret.ml/docs/aplr.html)
        -   [Linear Model](https://interpret.ml/docs/lr.html)
        -   [Decision Tree](https://interpret.ml/docs/dt.html)
        
    -   [Blackbox Explainers](https://interpret.ml/docs/blackbox.html)
    -   [Differentially Private Models](https://interpret.ml/docs/privacy.html)
    
-   [Hyperparameters](https://interpret.ml/docs/hyperparameters.html)
-   [EBM internals](https://interpret.ml/docs/ebm-internals.html)
-   [Visualizations](https://interpret.ml/docs/framework.html)
-   [Deployments](https://interpret.ml/docs/deployment-guide.html)
-   [Development](https://interpret.ml/docs/development.html)
-   [What the FAQ](https://interpret.ml/docs/faq.html)
-   [Examples](https://interpret.ml/docs/examples.html)

# Explainable Boosting Machine[#](https://interpret.ml/docs/ebm.html#explainable-boosting-machine "Permalink to this heading")

Links to API References: [ExplainableBoostingClassifier](https://interpret.ml/docs/python/api/ExplainableBoostingClassifier.html), [ExplainableBoostingRegressor](https://interpret.ml/docs/python/api/ExplainableBoostingRegressor.html)

_See the reference paper for full details \[[1](https://interpret.ml/docs/ebm.html#lou2013accurate-ebm)\]._ [Link](https://www.cs.cornell.edu/~yinlou/papers/lou-kdd13.pdf)

## Summary

Explainable Boosting Machine (EBM) is a tree-based, cyclic gradient boosting Generalized Additive Model with automatic interaction detection. EBMs are often as accurate as state-of-the-art blackbox models while remaining completely interpretable.

## How it Works

As part of the framework, InterpretML also includes a new interpretability algorithm – the Explainable Boosting Machine (EBM). EBM is a glassbox model, designed to have accuracy comparable to state-of-the-art machine learning methods like Random Forest and Boosted Trees, while being highly intelligibile and explainable. EBM is a generalized additive model (GAM) of the form:

g(E\[y\])\=β0+∑fj(xj)

where g is the link function that adapts the GAM to different settings such as regression or classification.

EBM has a few major improvements over traditional GAMs \[[2](https://interpret.ml/docs/ebm.html#hastie1987generalized-ebm)\]. First, EBM learns each feature function fj using modern machine learning techniques such as bagging and gradient boosting. The boosting procedure is carefully restricted to train on one feature at a time in round-robin fashion using a very low learning rate so that feature order does not matter. It round-robin cycles through features to mitigate the effects of co-linearity and to learn the best feature function fj for each feature to show how each feature contributes to the model’s prediction for the problem. Second, EBM can automatically detect and include pairwise interaction terms of the form:

g(E\[y\])\=β0+∑fi(xi)+∑fi,j(xi,xj)

which further increases accuracy while maintaining intelligibility. EBM is a fast implementation of the GA2M algorithm \[[1](https://interpret.ml/docs/ebm.html#lou2013accurate-ebm)\], written in C++ and Python. The implementation is parallelizable, and takes advantage of joblib to provide multi-core and multi-machine parallelization. The algorithmic details for the training procedure, selection of pairwise interaction terms, and case studies can be found in \[[1](https://interpret.ml/docs/ebm.html#lou2013accurate-ebm), [3](https://interpret.ml/docs/ebm.html#lou2012intelligible-ebm), [4](https://interpret.ml/docs/ebm.html#caruana2015intelligible-ebm)\].

EBMs are highly intelligible because the contribution of each feature to a final prediction can be visualized and understood by plotting fj. Because EBM is an additive model, each feature contributes to predictions in a modular way that makes it easy to reason about the contribution of each feature to the prediction.

To make individual predictions, each function fj acts as a lookup table per feature, and returns a term contribution. These term contributions are simply added up, and passed through the link function g to compute the final prediction. Because of the modularity (additivity), term contributions can be sorted and visualized to show which features had the most impact on any individual prediction.

To keep the individual terms additive, EBM pays an additional training cost, making it somewhat slower than similar methods. However, because making predictions involves simple additions and lookups inside of the feature functions fj, EBMs are one of the fastest models to execute at prediction time. EBM’s light memory usage and fast predict times makes it particularly attractive for model deployment in production.

If you find video as a better medium for learning the algorithm, you can find a conceptual overview of the algorithm below: 

## Code Example

The following code will train an EBM classifier for the adult income dataset. The visualizations provided will be for both global and local explanations.

import numpy as np
import pandas as pd
from sklearn.model\_selection import train\_test\_split
from sklearn.metrics import roc\_auc\_score

from interpret.glassbox import ExplainableBoostingClassifier
from interpret import show

df \= pd.read\_csv(
    "https://archive.ics.uci.edu/ml/machine-learning-databases/adult/adult.data",
    header\=None)
df.columns \= \[
    "Age", "WorkClass", "fnlwgt", "Education", "EducationNum",
    "MaritalStatus", "Occupation", "Relationship", "Race", "Gender",
    "CapitalGain", "CapitalLoss", "HoursPerWeek", "NativeCountry", "Income"
\]
X \= df.iloc\[:, :\-1\]
y \= df.iloc\[:, \-1\]

seed \= 42
np.random.seed(seed)
X\_train, X\_test, y\_train, y\_test \= train\_test\_split(X, y, test\_size\=0.20, random\_state\=seed)

ebm \= ExplainableBoostingClassifier()
ebm.fit(X\_train, y\_train)

auc \= roc\_auc\_score(y\_test, ebm.predict\_proba(X\_test)\[:, 1\])
print("AUC: {:.3f}".format(auc))

AUC: 0.931

show(ebm.explain\_global())

Select Component to Graph

ExplainableBoostingClassifier\_0

  
  
  
  

show(ebm.explain\_local(X\_test\[:5\], y\_test\[:5\]), 0)

Select Component to Graph

ExplainableBoostingClassifier\_1

  
  
  
  

## Further Resources

-   [Paper: GA2M](https://www.cs.cornell.edu/~yinlou/papers/lou-kdd12.pdf)
    
-   [Paper: InterpretML Framework](https://arxiv.org/pdf/1909.09223.pdf)
    
-   [Video: The Science Behind InterpretML: Explainable Boosting Machine](https://www.youtube.com/watch?v=MREiHgHgl0k)
    

## Bibliography

\[1\] Yin Lou, Rich Caruana, Johannes Gehrke, and Giles Hooker. Accurate intelligible models with pairwise interactions. In Proceedings of the 19th ACM SIGKDD international conference on Knowledge discovery and data mining, 623–631. 2013. [Paper Link](https://www.cs.cornell.edu/~yinlou/papers/lou-kdd13.pdf)

\[2\] Trevor Hastie and Robert Tibshirani. Generalized additive models: some applications. Journal of the American Statistical Association, 82(398):371–386, 1987.

\[3\] Yin Lou, Rich Caruana, and Johannes Gehrke. Intelligible models for classification and regression. In Proceedings of the 18th ACM SIGKDD international conference on Knowledge discovery and data mining, 150–158. 2012. [Paper Link](https://www.cs.cornell.edu/~yinlou/papers/lou-kdd12.pdf)

\[4\] Rich Caruana, Yin Lou, Johannes Gehrke, Paul Koch, Marc Sturm, and Noemie Elhadad. Intelligible models for healthcare: predicting pneumonia risk and hospital 30-day readmission. In Proceedings of the 21th ACM SIGKDD international conference on knowledge discovery and data mining, 1721–1730. 2015. [Paper Link](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/06/KDD2015FinalDraftIntelligibleModels4HealthCare_igt143e-caruanaA.pdf)

[

previous

Glassbox Models

](https://interpret.ml/docs/glassbox.html "previous page")[

next

Automatic Piecewise Linear Regression (APLR)

](https://interpret.ml/docs/aplr.html "next page")

By The InterpretML Contributors

© Copyright 2023.
