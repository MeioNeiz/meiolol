---
title: 'Large Language Models for Automated Data Science: Introducing CAAFE for Context-Aware Automated Feature Engineering (Hollmann, Müller, Hutter, 2023)'
url: https://arxiv.org/pdf/2305.03403
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (abstract, 1, 2.2.1, 3, 4, 5, conclusion, appendix E.1, F)
relevance: medium
grade: B/fair
description: NeurIPS 2023 paper: an LLM proposes one feature-engineering code block per iteration from the dataset description, kept only if mean validation AUC and accuracy improve over 10 splits
---
# CAAFE: Context-Aware Automated Feature Engineering (Hollmann, Müller, Hutter, 2023)

Why: how does an LLM propose features, how are they validated, and what did it gain;
closest published analogue to an agent proposing model features from domain context.

## Assessment

- Evidence: B. NeurIPS 2023, Freiburg AutoML group (TabPFN authors); code at
  automl/CAAFE, 203 stars, 37 forks, last push 2024-12. 14 small datasets (up to 2,000
  rows), 5 seeds each.
- Reasoning: fair. Clear method and an ablation (semantic blinding), and it admits its
  keep/reject rule is not a statistical test. Gains are concentrated in a few datasets;
  no correction for testing ten candidates per run against the same validation splits.
- Interests: authors' own method, evaluated with their own TabPFN.
- Weigh: trust the loop shape and the blinding ablation; discount the size of the
  average gain for our setting (tiny datasets where one engineered feature can solve
  the task, unlike our near-noise effects).

## Findings

- [lab] [method] Loop: the LLM writes one code block of features per iteration; the
  block is kept only if validation performance beats the current best, otherwise
  rejected and the data left unchanged. `3` ^f1
  > If P ′ exceeds the performance P achieved by training on Dtrain and evaluating on Dvalid , the feature is kept
  > Otherwise, the feature is rejected and Dtrain and Dvalid remain unchanged.
- [lab] Prompt contents: user dataset description, feature names, data types, percent
  missing, 10 random rows; summary statistics from the train split only; a code
  template and chain-of-thought (meaning and usefulness, inputs, sample values, then
  code). `3` ^f2
  > E 10 random rows from the dataset - this provides information on the feature scale, encoding,
  > first providing the high-level meaning and usefulness of the generated feature, providing the names of features used to generate it, retrieving sample values it would need to accept and finally writing a line of code.
- [lab] Each feature must carry a written justification of its usefulness, and the LLM
  is told to drop features made redundant. `3` ^f3
  > the LLM is instructed to create valuable features for a subsequent prediction task and to provide justifications for the added feature’s utility. It is also instructed to drop unnecessary features
- [lab] [stats] Acceptance rule: mean change in accuracy and ROC AUC over ten random
  validation splits, kept when the average of both is above 0; ten iterations per run,
  TabPFN as the fast evaluator. `3` ^f4
  > The performance is measured on the current dataset with ten random validation splits
  > with the mean change of accuracy and ROC AUC used to determine if the changes of a code block are kept, i.e. when the average of both is greater than 0.
- [stats] The authors admit the keep rule is not a statistical test. `conclusion` ^f5
  > The testing procedure for adding features is not based on statistical tests, and could be improved using techniques of previous feature engineering works.
- [method] [lab] Rationale: domain context acts as a prior that narrows a vast
  feature space to meaningful candidates, easing multiple testing. `2.2.1` ^f6
  > By incorporating semantic and contextual information, feature engineering techniques can be limited to semantically meaningful features enhancing the performance by mitigating issues with multiple testing and computational complexity
- [method] Result with GPT-4: mean ROC AUC 0.798 to 0.822 with TabPFN, better on 11 of
  14 datasets; GPT-3.5 improved only 6 of 14. `5` ^f7
  > If it is used with GPT-4, we improve average ROC AUC performance from 0.798 to 0.822
  > If we use CAAFE with GPT-3.5 only, we can see that it performs clearly worse than with GPT-4, and only improves performance on 6/14 datasets.
- [method] (inferred) The average gain is carried by a few datasets: in Table 1
  tic-tac-toe goes from 0.6989 to 0.9536 and balance-scale from 0.8444 to 0.882, while
  most others move by under 0.01. `table 1` ^f8
- [method] Gains vary with whether simple code can express a better mapping and with
  the quality of the dataset description. `5` ^f9
  > There is great variability in the improvement size depending on whether (1) a problem is amenable to feature engineering
- [lab] [method] Semantic blinding (no feature names or description) cut GPT-4's mean
  AUROC from 0.822 to 0.8, close to no feature engineering: the context does the work.
  `E.1` ^f10
  > We find a strong drop in performance from an average AUROC of 0.822 to 0.8 over all datasets for GPT-4.
- [lab] Cost: 4:43 minutes per dataset, 90% LLM generation and 10% evaluation; 7.4% of
  generated features were faulty code, recovered by passing the error back. `5` ^f11
  > CAAFE takes 4:43 minutes to run on each dataset, 90% of the time is spent on the LLM’s code generation and 10% on the evaluation of the generated features.
  > CAAFE generates 52 faulty features (7.4%) in the generation stage, from which it recovers
- [lab] Checked, not there: no model errors or residuals in the prompt. The LLM sees
  the description, schema, sample rows, the template, and back from each block only
  its before and after scores (figure 4) or an execution error, so proposals are
  context-led, not diagnosis-led. ^f12

## Read

- Abstract, 1, 2.2.1, 3 (method, prompt, technical setup), 4, 5, conclusion and
  limitations, appendix E.1 (semantic blinding), F (iterations, cost).

## Not read

- 2.1-2.2 related work, appendix A-D, G (dataset details), full prompt (figure 5).
