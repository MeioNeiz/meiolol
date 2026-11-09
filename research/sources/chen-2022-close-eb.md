---
title: 'Chen 2022: Empirical Bayes when estimation precision predicts parameters (CLOSE)'
url: https://arxiv.org/html/2212.14444v6
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: docs (sections 1, 2, 3.4, 4, 5)
relevance: high
grade: A/strong
description: Econometrica 2026 paper (arXiv 2212.14444): EB where the true effect's mean and spread both depend on the standard error (conditional location-scale, CLOSE); Opportunity Atlas simulation and coupled-bootstrap selection test
---
# Chen 2022: Empirical Bayes when estimation precision predicts parameters (CLOSE)

Why: rare picks (large standard error) win less, and our ranges on rare cells were too
narrow until we fitted a spread per popularity band. Is there a published method where
the prior mean AND spread depend on precision, and what did it gain?

## Assessment

- Evidence: A. Econometrica 2026; minimax regret theory, a calibrated simulation over
  15 outcomes with 1,000 draws, and a coupled-bootstrap test of a real selection
  policy (Bergman et al. 2024); code on GitHub (jiafengkevinchen/close).
- Reasoning: strong. Shows where the assumption bites and where it does not (mean rank
  after covariates), and that simple parametric versions are competitive.
- Interests: author's own method against standard EB.
- Weigh: Gaussian model with known sigma_i; our win rates need a transform or the
  binomial version. The structure (mean and spread as functions of sigma or n) is what
  we already do by bands; the paper gives a principled smooth version and a validation
  tool.

## Findings

- [stats/eb] Standard Gaussian EB assumes precision independence (standard errors do not
  predict true effects); this is often wrong and rejected in data. Abstract ^f1
  > Gaussian empirical Bayes methods usually maintain a _precision independence_ assumption: The unknown parameters of interest are independent from the known standard errors of the estimates. This assumption is often theoretically questionable and empirically rejected.
- [stats/eb] Imposing it wrongly can make shrinkage decisions worse than no shrinkage.
  Section 1 ^f2
  > Inappropriately imposing it can harm empirical Bayes decisions, possibly even making them underperform decisions without shrinkage.
- [stats/eb] Mechanism: shrinking to the unconditional mean systematically misplaces the
  noisy units when sigma and theta correlate (there, noisy tracts were better; for us,
  rare picks are worse). Section 1 ^f3
  > If θi and σi are positively correlated, such shrinkage tends to systematically _underestimate_ true mobility of high-σi tracts.
- [stats/eb] CLOSE: theta given sigma = m0(sigma) + s0(sigma) * tau, tau from one shape
  G0 (mean 0, variance 1); estimate m0 and s0 as conditional moments of Y given sigma,
  standardise, then fit G0 by NPMLE. Covariates can enter m0 and s0. Sections 2.3-2.4 ^f4
  > The function m0​(⋅) translates the _location_ of the distribution and the function s0​(⋅) controls the _scaling_.
  > researchers can choose instead to model m0​(σi,Xi) and s0​(σi,Xi) that include these covariates
- [stats/eb] Step 1 by moments: m(sigma) = E[Y | sigma], s^2(sigma) = E[(Y - m)^2 |
  sigma] - sigma^2, floored at 0; a parametric choice is m linear in log sigma and
  log s^2 linear in log sigma. Sections 2.4.1, 4.1 ^f5
  > close\-gauss (parametric) implements close\-gauss, where [close–step 1] models the conditional moments parametrically as m0​(σi,a)\=a1+a2​log⁡σi and s02​(σi,b)\=exp⁡(b1+b2​log⁡σi)
- [stats/eb] For binary-outcome means a variance-stabilising (arcsine) transform removes
  the mechanical sigma-theta link, but n can still predict theta and should then be
  modelled. Section 2.4 ^f6
  > However, it is still possible that ni predicts θi, and when that happens, proper modeling of θi|ni
- [stats/eb] Calibrated simulation, 15 outcomes, no covariates: median share of the
  oracle's MSE gain captured was 31% (Gaussian EB under independence), 50% (NPMLE under
  independence), 86% (close-npmle). Section 4.1 ^f7
  > the median proportion of possible gains captured by independent-gauss is only 31%. This value is 50% for independent-npmle, and 86% for close\-npmle.
- [stats/eb] With covariates the gap shrank where they absorbed the dependence (mean
  rank) and stayed large elsewhere; simple parametric CLOSE was competitive. Section 4.1 ^f8
  > simple parametric models for (m0,s0,G0) remain competitive and significantly improve upon methods that assume precision independence
- [stats/eb] [stats/scoring] Top-third selection, coupled bootstrap (90-10 split): standard
  EB without covariates underperformed raw estimates for nearly all 15 outcomes;
  close-npmle's gain over it was a median 260% of basic EB's own value. Section 4.2 ^f9
  > independent-gauss without covariates underperforms for nearly all variables
  > the improvement of close\-npmle over independent-gauss is on median 260% of the value of basic empirical Bayes
- [stats/scoring] Coupled bootstrap: split each estimate into two by adding and
  subtracting Gaussian noise, giving unbiased loss estimates for any rule without
  assuming the prior model. Section 3.4 ^f10
  > The validity of this validation depends only on the Gaussianity ([1])—without assuming (θi,σi) are random nor assuming the location-scale model ([2.4]).
- [stats/eb] (inferred) For meiolol: our hinge prior lines in log popularity are m0, and
  the per-band spread is a stepwise s0; CLOSE says fit s0 smoothly (log s^2 linear or
  hinged in log games) by moments on the same residuals, then optionally an NPMLE shape
  on standardised cells (koenker-mizera). Our next-week check plays the role of the
  coupled bootstrap. ^f11

## Read

- Abstract, Sections 1, 2 (model, CLOSE steps, alternatives), 3.4, 4, 5.

## Not read

- Section 3 proofs and robustness (3.2); OA2.2 alternatives; OA3.4 (sigma treated as a
  covariate).
