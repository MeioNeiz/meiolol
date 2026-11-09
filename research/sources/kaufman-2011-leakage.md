---
title: 'Kaufman, Rosset and Perlich 2011: Leakage in data mining: formulation, detection, and avoidance'
url: https://www.cs.umb.edu/~ding/history/470_670_fall_2011/papers/cs670_Tran_PreferredPaper_LeakingInDataMining.pdf
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: docs (abstract, sections 3.1, 3.4, 4, 5)
relevance: medium
grade: A/fair
description: KDD 2011 paper (course-hosted copy) defining leakage as target information that should not be available, the no-time-machine rule, legitimacy tags with learn-predict separation, and detection by surprise; competition case studies
---
# Kaufman, Rosset and Perlich 2011: Leakage in data mining: formulation, detection, and avoidance

Why: the stored rank is a feature recorded after the outcome. What does the canonical
leakage paper prescribe when records carry one late time stamp and the fix is partial?

## Assessment

- Evidence: A. The standard citation on leakage (KDD 2011, extended in TKDD 2012);
  Perlich and Rosset won several KDD Cups. No experiments: cases and a definition.
- Reasoning: fair. Clear formalism and remedies; little on correcting a leak once it is
  in historical data beyond warning it is hard.
- Interests: none known.
- Weigh: trust the framing (time-stamp every observation, cut by time); the paper says
  nothing about statistical correction, which is Keogh-Bartlett's ground.

## Findings

- [method] [data] Leakage: information about the target that should not legitimately be
  available to the model. Abstract ^f1
  > leakage is essentially the introduction of information about the data mining target, which should not be legitimately available to mine from.
- [method] No-time-machine rule: a legitimate feature only carries information from
  before (or at most at) the target's time. Section 3.1 ^f2
  > it is implicitly required that a legitimate model only build on features with information from a time earlier (or sometimes, no later) than that of the target.
- [method] [data] Avoidance: time-stamp every observation (legitimacy tags), then cut by
  time so each target only sees inputs legitimate for it. Section 4.1 ^f3
  > Legitimacy tagging is implemented by timestamping every observation. Learn-predict separation is implemented by a cut at some point in time that segments training from evaluation examples.
- [data] The usual cause: databases overwrite records without stamping each update, so a
  record carries one late time stamp. Section 4.1 ^f4
  > Updates to database records are usually not timestamped and not stored separately, and at best whole records end up with one time-stamp.
- [method] Fixing leakage in data without legitimacy tags often only partly works, and
  can make things worse. Section 5 ^f5
  > It may be possible to partly plug the leak but not to seal it completely, and it is not uncommon that an attempt to fix leakage only makes it worse.
- [method] Detection: a feature, or overall performance, that is surprisingly strong
  against prior expectation merits checking for legitimacy. Section 5 ^f6
  > A substantial divergence from this expected performance is surprising and merits testing the most informative observations the model is based on more closely for legitimacy.
- [method] Leakage also enters through design choices (features, model and
  hyperparameter selection) made after seeing illegitimate data. Section 3.4 ^f7
  > This form of leakage is perhaps the most dangerous as an evaluator may not be able to identify it even when she
- [method] Checked, not there: no method to correct a leaky feature statistically, nor
  anything on a feature whose leak grows with a known lag. ^f8
- [data] (inferred) For meiolol: the rank history from 13 Oct is the legitimacy tag
  (rank stamped before game start); games before it carry one stamp, the store time,
  which is ^f4 exactly. ^f5 argues for treating the older games' rank as a different,
  weaker feature (or imputing, Keogh-Bartlett) rather than "fixing" it by a lag rule. ^f9

## Read

- Abstract, Sections 3.1, 3.4, 4 and 5.

## Not read

- Section 2 (case list), TKDD 2012 extension (causal-graph view of leakage).
