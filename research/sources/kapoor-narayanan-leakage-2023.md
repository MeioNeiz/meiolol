---
title: Leakage and the Reproducibility Crisis in ML-based Science (Kapoor, Narayanan, 2022/2023)
url: https://arxiv.org/abs/2207.07048
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: skimmed (abstract, 1, 2.4, 2.5, 3, 4 findings 1-2, 5 D1)
relevance: high
grade: A/strong
description: Princeton survey of leakage across 17 fields (329 papers), an 8-type leakage taxonomy, model info sheets, and a civil-war case study where every "complex ML beats LR" claim failed from leakage
---
# Leakage and the Reproducibility Crisis in ML-based Science (Kapoor, Narayanan)

Why: a leakage taxonomy an experiment harness could check feature by feature, and what
a per-model record must argue before a result is trusted.

## Assessment

- Evidence: A. Widely cited (published in Patterns 2023); survey of 20 audit papers
  across 17 fields plus a hands-on reproduction of 12 civil-war papers with code.
- Reasoning: strong. Taxonomy tied to observed cases; limits of info sheets stated
  (unverifiable without computational reproducibility, false assurance).
- Interests: none known; authors promote their own info-sheet template.
- Weigh: snapshot is arXiv v1 (2022); the Patterns version may word things
  differently. Aimed at ML-based science, but L1 to L3 map directly onto a draft model.

## Findings

- [lab] Leakage is widespread: 20 audit papers across 17 fields, 329 papers affected,
  some wildly overoptimistic. Abstract ^f1
  > we find 17 fields where errors have been found, collectively affecting 329 papers and in some cases leading to wildly overoptimistic conclusions.
- [lab] Taxonomy, L1: no clean train-test separation in any pre-processing, modelling
  or evaluation step. Section 2.4 ^f2
  > [L1] Lack of clean separation of training and test dataset. If the training dataset is not separated from the test dataset during all pre-processing, modeling and evaluation steps
- [lab] L1 subtypes: no test set (L1.1); pre-processing such as imputation or
  over/under sampling on the whole dataset (L1.2); feature selection on the whole
  dataset (L1.3); duplicates across train and test (L1.4). Section 2.4 ^f3
  > [L1.2] Pre-processing on training and test set. Using the entire dataset for any pre-processing steps such as imputation or over/under sampling.
  > Feature selection on the entire dataset results in using information about which feature performs well on the test set to make a decision about which features should be included in the model.
  > [L1.4] Duplicates in datasets.
- [lab] L2: illegitimate features, such as a proxy for the outcome or information not
  available at prediction time; judging it needs domain knowledge, so no subtypes. Section 2.4 ^f4
  > One instance when this can happen is if a feature is a proxy for the outcome variable
  > The judgement of whether the use of a given feature is legitimate for a modeling task requires domain knowledge and can be highly problem specific.
- [lab] L3.1 temporal leakage: when predicting the future, no test data may predate the
  training data. Section 2.4 ^f5
  > the test set should not contain any data from a date before the training set.
- [lab] L3.2 non-independence: train and test sharing the same people or units is
  leakage unless the claim is about that same dependence; split by unit (block CV).
  Section 2.4 ^f6
  > In the extreme (but unfortunately common) case, train and test samples come from the same people or units.
  > The traintest split should account for the dependencies in the data
- [lab] L3.3 sampling bias: the test set is not representative of where the claim
  applies (e.g. dropping hard borderline cases). Section 2.4 ^f7
  > Another example is selection bias, which entails choosing a non-representative subset of the dataset for evaluation.
- [lab] Model info sheets ask for three written arguments: clean split, every feature
  legitimate (justification must cover every feature), test drawn from the
  distribution of interest. Section 3.2 ^f8
  > [L1] Clean train-test separation. The researcher needs to argue why the test set does not interact with training data during any of the preprocessing, modeling or evaluation steps
  > Rather, we ask that the justification provided for the legitimacy of the features used in their model should cover every feature used in their model.
- [lab] Limit: info sheet claims cannot be verified without computational
  reproducibility (code, data, environment), and wrong sheets give false assurance. Section 3.4 ^f9
  > First, the claims made in model info sheets cannot be verified in the absence of computational reproducibility.
- [lab] Case study: errors in 4 of 12 civil-war papers, exactly the 4 claiming complex
  ML beats logistic regression; corrected, they do no better than LR (one AUC gap
  0.14 to 0.01). None was visible from reading the paper. Section 4 ^f10
  > We found errors in 4 of the 12 papers—exactly the 4 papers that claimed superior performance of complex ML models over baseline LR models for predicting civil war.
  > the difference between the AUC of the complex ML models and LR models drops from 0.14 to 0.01.
- [lab] [stats] 9 of 12 papers had no significance test or uncertainty for classifier
  comparison; one claimed win had a bootstrap AUC interval of [0.66-0.95]. Section 4 ^f11
  > We found that 9 of the 12 papers for which complete code and data were available included no significance tests or uncertainty quantification for classifier performance comparison
- [lab] Know the limits of prediction: a known bound on achievable accuracy stops
  futile effort and calls for scepticism of results beyond it. Section 5 D1/R1 ^f12
  > we can avoid a futile effort to increase it further and can apply increased skepticism towards results that claim to violate known bounds.
- [lab] (inferred) For meiolol: a sudden jump well past the known level for draft-only
  prediction (docs/model.md: AUC 0.550 from the draft) should trigger a leakage
  audit, not a keep. L3.2 maps to the same player across train and test
  games; L2 to any per-player or per-champion stat computed with the game itself. ^f13

## Read

- Abstract, section 1 contributions, 2.4 taxonomy, 2.5, section 3, section 4 findings
  1-2, section 5 D1

## Not read

- Appendix C (worked info sheets for the civil-war papers), the model info sheet
  template on reproducible.cs.princeton.edu, the Patterns published text
