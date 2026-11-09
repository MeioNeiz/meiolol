---
title: 'Bonab et al. 2021: Cross-market product recommendation (XMarket, FOREC)'
url: https://arxiv.org/pdf/2109.05929
kind: paper
commit:
for: [context-aware-models]
looked: 2026-11-06
depth: docs (abstract, sections 3-4 market analysis, 6.2-6.4)
relevance: medium
grade: B/fair
description: CIKM 2021 paper (UMass, Amsterdam) defining cross-market recommendation on Amazon data from 18 markets; FOREC pre-trains on a pair of markets, forks and fine-tunes for the target; measures which source market helps which target
---
# Bonab et al. 2021: Cross-market product recommendation (XMarket, FOREC)

Why: context-aware-models, regions sub-question: does data from another market help a
target market's estimates, how is the source chosen, and when does it not help.

## Assessment

- Evidence: B. Public dataset (XMarket, 52.5M interactions, 18 markets), started a
  RecSys workshop series; 7 target markets x 7 sources = 49 pairs. Gains are ranking
  metrics (nDCG@10 with 99 sampled negatives), far from our shares and rates.
- Reasoning: fair. Reports pairs where the method loses and a data-size study, but
  hypotheses for the losses are untested; table numbers garbled in pdftotext, so only
  stated figures used.
- Interests: authors' own method and dataset.
- Weigh: take the qualitative lessons (source choice matters, similarity is not
  geography, tiny targets lose); the 24% figure is against a weak single-market NMF.

## Findings

- [method] FOREC averages 24% and up to 50% better nDCG@10 than a single-market NMF,
  using one auxiliary market per target. Abstract ^f1
  > FOREC improves on average 24% and up to 50% in terms of nDCG@10,
- [method] Even the simple baseline (one NMF trained on both markets, sharing item
  and user parameters) gains from the other market's data. Section 6.2 ^f2
  > we observe that even our simple baselines are able to utilize to some degree the cross-market data provided and improve the target market’s recommendation performance.
- [method] Which source market helps differs per target; the best source was picked on
  validation nDCG, and "us" as a fixed source helped every target but was not the best
  for all. Section 6.2 ^f3
  > even though us is not the best source market for all target markets in terms of performance boost (see Best-Src scenario), comparing with the single market results, it can be observed that us helps all of the tested target markets
- [method] Market similarity (cosine of item purchase counts) is highest among de, fr
  and uk; us, ca and mx share items but buy differently, so shared catalogue or
  geography does not mean shared behaviour. Section 4 ^f4
  > we observe the highest rate of similarity between de, fr, and uk, highlighting the similarities in European markets. On the other hand, we see that the American countries do not share much in common.
- [method] With only 10% of the target's training data, the single-market model beat
  the cross-market ones; transfer paid only once the target had some minimum data.
  The authors guess pre-training pulls parameters too far toward the source. Section
  6.4 ^f5
  > On the extremely small target market size (10% of the data), we see that single market NMF model as well as NMF++ are performing better.
  > some minimum amount of training data in the target market is essential for the cross-market models that we examined in order to be able to make use of the auxiliary source market.
- [method] (inferred) For us this is the M11 picture in another field: markets move
  alike in clusters that geography does not predict (KR and VN apart, JP/SG/TW/OCE
  with EUW1 and NA), so a region weight learnt from data beats a fixed grouping; and
  when EUW1's own data is thin (patch day 0), a transfer that leans on others can do
  worse than EUW1 alone unless its weight is shrunk with EUW1's sample size. ^f6
- [method] Checked, not there: no learnt covariance across markets, no multi-source
  weighting (one auxiliary market at a time, left for future work), no temporal or
  lead-lag use. ^f7

## Read

- Abstract, market analysis, results 6.2-6.4 from pdftotext of the arXiv PDF.

## Not read

- Table 3 per-market numbers (garbled columns); MAML details (section 5).
