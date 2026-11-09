---
title: 'Sheng et al. 2021: STAR, one model to serve all (multi-domain CTR)'
url: https://arxiv.org/pdf/2101.11427
kind: paper
commit:
for: [context-aware-models]
looked: 2026-11-06
depth: docs (abstract, sections 3.3-3.5, 4.1-4.4)
relevance: medium
grade: B/fair
description: Alibaba CIKM 2021 paper; one CTR model for 19 (later 60+) ad domains with shared weights times per-domain weights, per-domain normalisation and a domain-indicator side network; offline AUC per domain and online A/B lift
---
# Sheng et al. 2021: STAR, one model to serve all (multi-domain CTR)

Why: context-aware-models, regions sub-question: what a shared-plus-specific structure
gains over one shared model with a per-domain offset, measured at scale.

## Assessment

- Evidence: B. Deployed since 2020 on 60+ domains in Alibaba display ads, online A/B
  test; offline on one day of billions of examples, 19 domains. Production data not
  public, so not reproducible; single train/test day, no error bars.
- Reasoning: fair. Ablations separate the parts (per-domain normalisation, star weights,
  domain side network); no study of when sharing fails beyond a hypothesis.
- Interests: authors' own method, compared against their own baselines.
- Weigh: trust the ordering and the ablation; the abstract says 8.0% CTR and 6.0% RPM,
  the introduction says 6% CTR and 8% RPM (an inconsistency in the paper).

## Findings

- [method] Setting: 19 business domains, train on one day, test on the next; domains
  differ in CTR from 1.27% to 12.03%; most items shared across domains, users partly
  (8.52% overlap for two domains). Section 4.1 ^f1
  > domain with the highest CTR (domain #15) is 12.03% while domain with the lowest CTR (domain #13) is only 1.27%
- [method] Each domain's layer weights = shared weights element-wise times the domain's
  weights (biases added); shared weights learn from all examples, a domain's only from
  its own. Section 3.4 ^f2
  > The shared parameters are updated through the gradient of all examples, while the domain-specific parameters are only updated through examples within this domain.
- [method] Overall AUC: mixed-data Base 0.6364, Shared Bottom 0.6398, MMoE 0.6403,
  Cross-Stitch 0.6415, STAR 0.6506; an adversarial model that hides the domain
  (MulANN) 0.6353, below Base. Table 2 ^f3
  > Note that the performance of MulANN is worse than the Base model, which proves obscuring domain difference hurts the modeling of multi-domain CTR prediction.
- [method] Implicit-sharing models lost to the single mixed model in some domains (5,
  6, 16); STAR beat Base in all 19, which the authors credit to domain parameters
  seeing only their own domain's data. Section 4.2 ^f4
  > in some domains, the AUCs of Shared Bottom, MMoE, and CrossStitch are worse than the Base model, e.g., domain # 5, #6, and #16.
- [method] Ablation: per-domain normalisation alone (a per-domain shift and scale of
  the hidden layer, plus per-domain moving moments) lifts Base from 0.6364 to 0.6485;
  star weights alone 0.6455; both 0.6506. So the cheap per-domain offset and scale
  takes about 85% of the full gain. Table 3 ^f5
  > We observe that using star topology FCN and PN separately can outperform the Base model. Bring them together can further boost performance.
- [method] Partitioned normalisation is global scale times domain scale plus global
  bias plus domain bias. Section 3.3 ^f6
  > where 𝛾, 𝛽 are the global scale and bias, and 𝛾𝑝 , 𝛽𝑝 are the domainspecific scale and bias parameters.
- [method] Feeding the domain indicator straight to a small side network whose output
  adds to the logit improved every method (figure only, no numbers). Section 4.3.3 ^f7
  > We observe that the auxiliary network improves all methods consistently.
- [method] Online A/B over the previous production model (Base): +8.0% CTR, +6.0% RPM.
  Table 5 ^f8
  > The introduction of STAR brings +8.0% overall CTR lift and +6.0% overall RPM lift in our online A / B test.
- [method] Changing domain mix over a day destabilised online training; a shuffled
  sliding buffer of recent samples fixed it. Section 4.4 ^f9
  > If we train the model directly in the chronological order, the changes in data percentage over time will cause the instability of model learning.
- [method] (inferred) For us: our model already has the "per-domain offset" (g for
  EUW1); STAR's evidence says the next gain is a per-region scale on shared terms (a
  multiplicative region factor on the patch move d(patch)), not a free per-region
  copy of everything. Their 19 domains carry billions of rows; our one region-vs-rest
  split has far less per cell. ^f10
- [method] Checked, not there: no learnt covariance between domains, no small-data
  domain study, no measure of how gains depend on a domain's size. ^f11

## Read

- Sections 3-4 and tables 2-5, from pdftotext of the arXiv PDF.

## Not read

- Related-work section in detail; figure 7 (calibration per domain, PCOC) numbers.
