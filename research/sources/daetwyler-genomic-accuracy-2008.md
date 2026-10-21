---
title: 'Daetwyler, Villanueva, Woolliams 2008: Accuracy of predicting the genetic risk of disease using a genome-wide approach'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC2561058/
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (abstract, derivation, discussion; equations are images, not in the text)
relevance: high
grade: A/fair
description: PLoS ONE 2008; closed-form accuracy of genomic prediction as a function of records per effect times heritability, the standard sample-size formula in animal and human genomics
---
# Daetwyler, Villanueva, Woolliams 2008: Accuracy of predicting the genetic risk of disease using a genome-wide approach

Why: genomics has a two-parameter learning curve with an explicit ceiling (the
heritability) and an effective number of effects; it might pin down what our a*N^-b + c
fits could not.

## Assessment

- Evidence: A. Standard formula in genomic selection (hundreds of citations, used for
  study design in livestock and human genetics); simulations agree.
- Reasoning: fair. Clear derivation; assumes independent loci and additive effects.
- Interests: none known.
- Weigh: the functional form transfers (accuracy rises with N h^2 / M); M for drafts
  is an effective number of independent effects to be fitted, not a count of features.

## Findings

- [method/ceiling] Accuracy of prediction depends on the product of heritability and
  records per effect, lambda = n_P / n_G times h^2 (the known form: r^2 = lambda h^2 /
  (1 + lambda h^2), so variance explained = h^2 times that). Derivation ^f1
  > Therefore accuracy is seen to be a function of the product of the observed heritability and the ratio of the number of phenotypes recorded to the number of loci involved, λ .
- [method/ceiling] Same summary for binary disease traits, via a liability scale.
  Abstract ^f2
  > they are best summarized as the product of the ratio of number of phenotypic records per number of risk loci and the observed heritability.
- [method/ceiling] The formula is an upper bound for real estimators, a ceiling at each
  sample size. Abstract ^f3
  > The predictions represent an upper bound of accuracy which may be achievable with improved effect estimation methods.
- [method/ceiling] Worked number: 1000 loci, 10,000 records, accuracy 0.71. Discussion ^f4
  > consider n G  = 1000 loci with effects greater than 0, n P  = 10,000 phenotypes and , then the predicted accuracy is obtained with λ  = 10, and will be 0.71.
- [method/ceiling] Methods using all loci at once approach the bound faster than
  significance-threshold ones. Discussion ^f5
  > might be expected to approach the upper bound of r gĝ faster than methods which impose significance thresholds
- [method/ceiling] (inferred) For us: fit R2(N) = h2 * N h2 / (N h2 + M) (R2 = variance
  of the logit explained, from paired log loss gains over coin) to our nested-size
  learning curves per model family; h2 is that family's ceiling and M its effective
  number of effects. Two parameters with a fixed shape, where a*N^-b + c leaves c free. ^f6

## Read

- Abstract, derivation (population and case-control), discussion.

## Not read

- Appendix S1 (second order correction), simulation tables.
