---
status: answered
priority: soon
area: stats
parent: frontier-experiments
tags: [method/ceiling, stats]
description: How can we estimate the best achievable accuracy for predicting a ranked game's winner from the draft (and from pre-game info), and how does matchmaking shape that ceiling?
---
# How can we estimate the best achievable accuracy for predicting a ranked game's winner from the draft (and from pre-game info), and how does matchmaking shape that ceiling?

Feeds: docs/plan/lab-frontier.md (gpu-box experiment programme), parent [[frontier-experiments]].
Builds on [[draft-predictor-methods]] C1, C2 (published honest ceiling 53-54%, every
family lands there) and [[live-win-probability]] C8; doesn't redo them.

## Answer

The ceiling is a property of the distribution of the true win probability p given the
inputs: best accuracy E[max(p, 1-p)], best log loss E[H(p)], best AUC a pair formula in
p (C1). Off-the-shelf Bayes error estimators don't fit our case: soft-label estimators
need per-game probabilities, kNN and divergence bounds are asymptotic and every draft is
nearly unique (C2), and plugging a calibrated model's output in gives only that model's
own error, a floor on the ceiling (C3). Learning-curve asymptotes (a N^-b + c) trade c
against b, which is what our fits showed; better-posed forms exist (C6).

What works for near-unique inputs and one outcome each is variance accounting, the same
algebra in sabermetrics (Tango), sports (Aoki's phi), neuroscience noise ceilings and
genomics heritability (C4, C5): estimate how much true spread each block of terms has
beyond binomial luck, sum the blocks, convert. With a Gaussian true logit of sd s,
accuracy is about 50% + 20 s points and log loss gain about s^2 / 8 nats; our shipped
model (54.8%, 0.6855, AUC 0.569) sits exactly at s = 0.25 (C10). So "the draft ceiling
is X%" becomes "the draft blocks hold variance V", e.g. 56% needs s = 0.30 (V 0.09),
58% s = 0.40. Draft carries about 1% of the outcome's information in LoL (7.6 of 693
milli-nats) against 6-10% in Dota (C9).

Matchmaking: Riot's matchmaker targets 50 +/- 1% from MMR before champion select, so it
strips rating signal but not draft signal; what is left pre-game is the draft plus what
MMR misses (champion and role experience, unconverged ratings) (C7). Sport-level
references put crude-favourite upset rates at 36-45%, so a ranked solo queue draft
ceiling far above 57% would be surprising (C8). Recommended (C11): a variance-component
ceiling on held-out residuals per block (champion-role, ally pairs, enemy pairs, whole
comp; then own-seat player terms), checked by label-noise injection, alongside a
Cortes train/test bracket on the existing learning curves and an in-game upper bound
from early-minute models (C12). Our expectation (speculative until run): draft-only
55-56.5%, plus own seat under +1 point.

## Claims

- C1: The best accuracy for a binary outcome is the mean of max(p, 1-p) of the true probability; the optimal AUC is also a function of the true probabilities alone. for: [[ishida-bayes-error-2023#^f1]], [[ishida-bayes-error-2023#^f2]], [[bayes-optimal-ber-auc-2026#^f1]]
- C2: Direct estimators need per-instance probabilities (noise inside the min biases them); kNN bounds hold only asymptotically and extrapolation needs samples exponential in dimension. for: [[ishida-bayes-error-2023#^f3]], [[feebee-2021#^f2]], [[feebee-2021#^f3]]
- C3: Calibrated soft labels are not enough: a calibrated model's plug-in estimate can be far off; isotonic calibration is consistent only if the scores rank inputs in the true order. for: [[jeong-soft-label-ber-2025#^f1]], [[jeong-soft-label-ber-2025#^f2]], [[jeong-soft-label-ber-2025#^f3]], [[bayes-optimal-ber-auc-2026#^f2]]
- C4: The variance a whole feature set explains can be estimated without building the predictor (random effects, REML), and far exceeds what individually tested effects show (45% vs 5% for height). for: [[yang-gcta-height-2010#^f1]], [[yang-gcta-height-2010#^f2]], [[yang-gcta-height-2010#^f3]], [[yang-gcta-height-2010#^f4]]
- C5: True spread = observed spread minus the luck-only spread, judged against a null simulated on the actual schedule; split-half with Spearman-Brown and the analytical noise ceiling give the same quantity without a binomial formula. for: [[gelman-luck-skill#^f1]], [[aoki-luck-sports-2017#^f1]], [[aoki-luck-sports-2017#^f3]], [[lage-noise-ceiling-2019#^f2]], [[lage-noise-ceiling-2019#^f3]]
- C6: Power law with offset fits learning curves best, but asymptote and exponent trade off and no form is universal; training and test error bracket a family's asymptote; genomics uses a fixed two-parameter form with heritability as ceiling. for: [[viering-learning-curves-2022#^f1]], [[viering-learning-curves-2022#^f2]], [[viering-learning-curves-2022#^f4]], [[cortes-learning-curves-1993#^f1]], [[cortes-learning-curves-1993#^f2]], [[daetwyler-genomic-accuracy-2008#^f1]], [[daetwyler-genomic-accuracy-2008#^f3]]
- C7: Riot's matchmaker targets 50 +/- 1% from MMR and misses champion and position familiarity and unconverged ratings; an MMR predictor gets 52.8% under MMR matchmaking, and matchmaking on a predictor removes what it predicts. for: [[riot-dev-matchmaking-real-talk-2018#^f1]], [[riot-dev-matchmaking-real-talk-2018#^f2]], [[moba-cupid-rematchmaking#^f4]], [[moba-cupid-rematchmaking#^f6]]
- C8: Sports upset rates with a crude favourite are 36-45% (soccer 45%, NBA 37%); luck is large even in skill-heavy leagues, which is why complex models rarely beat simple ones. for: [[bennaim-parity-2006#^f1]], [[aoki-luck-sports-2017#^f4]], [[aoki-luck-sports-2017#^f5]]
- C9: Draft-only information is small and smaller at higher skill: Dota picks 6-10% of the outcome's Shannon information; ours is about 1% (inferred from 7.6 milli-nats). for: [[semenov-mlsa16-slides#^f3]]
- C10 (inferred): With a calibrated Gaussian true logit of sd s, accuracy about 50% + 20 s points, log loss gain about s^2 / 8; s 0.25 gives 54.9% / 0.6855 / AUC 0.569 (our shipped model), 0.30 55.9%, 0.35 56.9%, 0.40 57.8%, 0.50 59.6% (scratch simulation, 400k draws). from: C1
- C11 (inferred): Measure the draft ceiling as summed variance components (champion-role, ally pair, enemy pair, residual comp) from held-out residual cells with a simulated null, validated by label noise; own-seat terms the same way. from: C4, C5, C10, C2, C3
- C12 (inferred): A per-minute model that includes the pre-game logit bounds the pre-game ceiling from above (more information can only help); published minute 1-5 AUC 0.63 suggests the bound sits near 59%. for: [[jjzhao-lol-win-probability#^f5]] from: C1

## Disagreements

- kNN and divergence (GHP) estimators are the best lower bounds on real data
  ([[feebee-2021#^f4]], A) vs useless here ([[feebee-2021#^f6]], ours, inferred): their
  test data are embedded images and text with low Bayes error; near 50% the 1NN error is
  about 0.495 even for a 55% Bayes classifier. Settled by running 1NN on our drafts and
  seeing it fall below what the model already reaches.
- Asymptote by curve fitting (POW3, [[viering-learning-curves-2022#^f1]]) vs by
  variance components (C4): the first gives a model family's limit, the second the
  limit of any model on those terms. Running both on the same data settles which is
  usable.

## Open

- Pick selection and matchmaking: true spreads are measured under how people actually
  pick; a ceiling for "a draft picked by meiolol" may differ ([[frontier-causal]]).
- Correlated components: seats share players and patches; summing block variances
  assumes independence. Check by refitting with all blocks at once (REML or HE).
- Patch drift: a true spread per patch is larger than the pooled one; which ceiling the
  app needs (this patch) vs the lab (pooled).
- MIT 2018 thesis on luck vs skill in pro LoL (lead): pro teams, not solo queue.
- 14 searches, about one new source each (curve still growing); MOBA-specific ceiling
  methods: two searches found nothing usable beyond Semenov's information share.
