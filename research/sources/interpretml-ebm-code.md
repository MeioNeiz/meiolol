---
title: 'InterpretML (interpretml/interpret): EBM code, categoricals, FAST, purify'
url: https://github.com/interpretml/interpret
kind: project
commit: 003136ef4c8beb24dd30a4b5626871b788be9acd
for: [frontier-interactions]
looked: 2026-11-13
depth: code (glassbox/_ebm.py fit and docstring, _ebm_core boost/rank/preprocessor, libebm nominal and pair partition code, hyperparameters.md, issue 629)
relevance: high
grade: A/fair
description: Reference GA2M implementation (EBM); nominal mains get one bin per category, a per-step gradient sort and rare-category pooling, but FAST and pair boosting cut categories in index order; purification is a separate utility, off by default
---
# InterpretML (interpretml/interpret): EBM code, categoricals, FAST, purify

Why: would an EBM fit on 10 nominal seats of ~170 champions (45 seat pairs, up to ~29k
cells each, outcome near a coin flip, 1.4-3.5M games) be a meaningful Python
cross-check of our shrunk main + pair-cell logistic model, and with which settings.

## Assessment

- Evidence: A. Created 2019-05 (Microsoft Research origin), 6,979 stars, 801 forks, 55
  contributors, MIT, release v0.7.8 on 2026-03-17, last push 2026-11-09; the native
  core is mostly one author (Paul Koch). Nominal handling (Fisher sort, cat_smooth,
  min_cat_samples) is recent: v0.6.9, 2025-01. Issue 629 (open, 2025-08 to 2026-05) is
  first-hand from the maintainer with his own 10,000-row repro; two users report the
  effect on interpret 0.7.0 to 0.7.8, screenshots only.
- Reasoning: fair. Code is commented with the reasons; the hyperparameter page is frank
  that reg_alpha, reg_lambda, cat_smooth and min_cat_samples have no tuning guidance
  yet. No benchmark shown in what was read. Docs lag the code (FAQ still says 8 bags
  and 10 interactions; code has 14 and "3x").
- Interests: the project's own tool.
- Weigh: findings citing .py or .cpp are what the code does at this commit; those
  citing hyperparameters.md or docstrings are what the docs say. Nothing here was run:
  the behaviour on 170-level nominal pairs is inferred from the code, and the fit time
  at millions of rows is unknown. In the issue, "minimal effect on final model
  performance" is the maintainer's benchmark memory, not shown, and is about accuracy,
  not about which level gets which score.

## Findings

- [method/interpret] A categorical feature gets one bin per distinct value at both the
  main and the pair level; max_bins and max_interaction_bins only limit continuous cuts
  (and private binning). 170 champions stay 170 bins, plus missing and unseen.
  `_ebm_core/_preprocessor.py` ^f1
  > categories = dict(zip(map(str, uniques), count(1)))
  > unique_val_counts[feature_idx] = len(categories)
- [method/interpret] Nominal main effects: at every boosting step the native code pools
  categories with fewer than min_cat_samples samples into one bin, sorts the rest by
  gradient sum over (hessian + cat_smooth), then splits that order with a tree of
  max_leaves leaves. `shared/libebm/PartitionOneDimensionalBoosting.cpp` ^f2
  > if(bNominal && pBin->GetCountSamples() < cCategorySamplesMin) {
  > val1 /= (hess1 + m_categoricalSmoothing);
- [method/interpret] The changelog says this is Fisher (1958), as in LightGBM, added in
  v0.6.9 (2025-01-06) with gain_scale, min_cat_samples and cat_smooth. `CHANGELOG.md`
  ^f3
  > use Fischer (1958) for handling categorical values. This is the same method employed by LightGBM.
- [method/interpret] [stats] The docs say defaults are min_cat_samples=10 and
  cat_smooth=10.0, and that rarer categories are combined. cat_smooth enters only the
  sort key in the code read, not the leaf value. Class docstring, `glassbox/_ebm.py` ^f4
  > min_cat_samples : int, default=10
  > Minimum number of samples in order to treat a category separately. If lower than this threshold
  > cat_smooth : float, default=10.0
- [method/interpret] The docs give no tuning advice yet for the nominal and penalty
  knobs (reg_alpha, reg_lambda, max_delta_step, gain_scale, min_cat_samples,
  cat_smooth). `docs/interpret/hyperparameters.md` ^f5
  > guidance: Needs investigation before we offer guidance on tuning. Until then, experimentally try [5, 10, 15, 20]
- [method/interpret] Only single-feature nominal terms get the nominal treatment: the
  gain_scale factor is applied when the term has one feature, and the native call for
  terms of two or more dimensions takes no nominal, min-category or smoothing argument.
  `_ebm_core/_boost.py`, `shared/libebm/GenerateTermUpdate.cpp` ^f6
  > if contains_nominals and len(term_features[term_idx]) == 1:
  > # penalize nominals a bit because they benefit from sorting categories
  > } else if(1 == cRealDimensions) {
- [method/interpret] Checked, not there: no nominal or categorical handling (sort,
  shuffle, pooling) in the pair code: PartitionMultiDimensionalTree.cpp,
  PartitionMultiDimensionalStraight.cpp and CalcInteractionStrength.cpp contain neither
  word. A pair update sums contiguous ranges of bin indexes on each axis.
  `shared/libebm/PartitionMultiDimensionalTree.cpp` ^f7
  > aDimensions[iTreeDim].m_iHigh = iSplit;
  > // each dimension requires 2 tree nodes, plus one for the last
- [method/interpret] FAST as coded: for a pair, sweep every cut x on feature 0 and y on
  feature 1 (bin index order), take the gain of the four quadrants on the residual
  gradients after the mains, keep the best, subtract the unsplit gain, divide by total
  weight. One 2x2 block split scores the whole pair.
  `shared/libebm/PartitionMultiDimensionalStraight.cpp`, `CalcInteractionStrength.cpp`
  ^f8
  > aDimensions[0].m_iHigh = x + 1;
  > aDimensions[1].m_iHigh = y + 1;
  > // For non-purified, there would be an update even without a split, so the parent partial gain
  > bestGain /= totalWeight;
- [method/interpret] Smoothing rounds use random cut points, for nominal terms too
  (nominal_smoothing is hard-coded True); the random-split file has no shuffle or
  nominal handling at this commit, so those rounds cut categories in index order
  (the maintainer says the same, ^f28). `_ebm_core/_boost.py`, `glassbox/_ebm.py`,
  `shared/libebm/PartitionRandomBoosting.cpp` ^f9
  > term_boost_flags_local |= Native.TermBoostFlags_RandomSplits
  > nominal_smoothing = True
- [method/interpret] No heredity: FAST scores every pair of features; each outer bag
  ranks them, ranks are averaged over bags, the best `interactions` pairs are kept.
  `glassbox/_ebm.py` ^f10
  > combinations(range(n_features_in), 2)
  > pair_ranks[indices] = old_mean + (
  > boost_groups = heapq.nsmallest(
- [method/interpret] The docs say the default is "3x" pairs (three per feature) for
  classification, a count or an explicit list of tuples can be given instead, and more
  pairs tends to help accuracy; the count is meant to be picked for readability.
  Class docstring, `docs/interpret/hyperparameters.md` ^f11
  > interactions : int, float, str, or list of tuples of feature indices, default="3x"
  > In terms of model performance, introducing more interactions tends to improve model accuracy.
- [method/interpret] Two stages: pairs are boosted on top of the frozen main-effect
  scores of the same bag, the GA2M order ([[lou-ga2m-2013#^f3]]). `glassbox/_ebm.py`
  ^f12
  > init_scores=scores_bags[idx],
  > term_features=boost_groups,
- [method/interpret] Purification is not part of a default fit or of the global
  explanation: both develop options are off, FAST uses the non-purified gain, and
  explain_global has no purify call. Terms are only mean-centred. `develop.py`,
  `_ebm_core/_utils.py`, `glassbox/_ebm.py` ^f13
  > "purify_boosting": False,
  > "purify_result": False,
  > interaction_flags = Native.CalcInteractionFlags_Default
- [method/interpret] `interpret.utils.purify(scores, weights)` is the stand-alone
  Lengerich purification ([[lengerich-2020-purification]]): returns the pure tensor,
  the main-effect impurities and an intercept, weighted by the cell weights given.
  `utils/_purify.py` ^f14
  > result will be a pair where the weighted sum along any row or column is zero, and the two main effects
- [method/interpret] [stats] Regularisation in a default classifier is early-stopped
  boosting with tiny steps and bag averaging, not a penalty: learning rate 0.015, 14
  outer bags, 15% validation per bag, stop after 100 rounds without gain, L1 and L2
  both 0. Class docstring, `glassbox/_ebm.py` ^f15
  > learning_rate : float, default=0.015
  > outer_bags : int, default=14
  > reg_lambda : float, default=0.0
  > early_stopping_rounds : int, default=100
- [method/interpret] [stats] Leaf limits: min_samples_leaf 4 and min_hessian 1e-4 by
  default; the docs say min_samples_leaf matters little on large data and that
  max_leaves applies to mains only. `docs/interpret/hyperparameters.md` ^f16
  > On larger datasets this parameter seems to have little effect.
  > The max_leaves parameter only applies to main effects.
- [method/interpret] The docs say outer bags give the error bars and smooth the graphs;
  the final term is the average over bags and the bag standard deviation is published.
  More than 14 bags is said to add nothing. Class docstring, `faq.ipynb`,
  `hyperparameters.md` ^f17
  > Outer bags are used to generate error bounds and help with smoothing the graphs.
  > The outputs of these models are averaged together to produce the final EBM, and the standard deviation of estimates for each region of the graph is published as the error bar.
  > Increasing outer bags beyond 14 provides no observable benefit.
- [method/interpret] The docs say greedy steps are mixed with cyclic ones (greedy_ratio
  10 by default), and that smoothing rounds are an initial highly regularised phase (75
  for classification, mains and pairs). Class docstring ^f18
  > The proportion of greedy boosting steps relative to cyclic boosting steps.
  > Number of initial highly regularized rounds to set the basic shape of the main effect feature graphs.
- [method/interpret] A hidden develop option adds an L2 penalty to every term that
  contains a nominal feature (cat_l2, default 0.0), pairs included; reg_lambda itself
  is passed to both boosting and FAST. `_ebm_core/_boost.py` ^f19
  > reg_lambda_local += develop.get_option("cat_l2")
- [method/interpret] Memory as coded in estimate_mem: three float32 arrays (score,
  gradient, hessian) per sample per outer bag, a bit-packed copy of the data per bag,
  and three float64 tensors per term per bag; pair tensors above 1,048,576 cells are
  skipped by FAST (strength 0). `glassbox/_ebm.py`,
  `shared/libebm/CalcInteractionStrength.cpp` ^f20
  > n_bytes_per_item = n_scores * n_samples * self.outer_bags * np.float32().nbytes
  > # boosting requires 1 score, 1 gradient, and often 1 hessian per score, per sample, per outer_bag
  > max_cardinality = 1048576
- [method/interpret] Checked, not there: no statement of fit time or row scaling in the
  files read. ^f21
- [method/interpret] [stats] (inferred) On our data the mains are a fair cross-check:
  one bin per champion per seat, Fisher-sorted two-leaf steps, champions under 10 games
  in a bag pooled, bag-averaged. It is an early-stopped unpenalised logistic fit of the
  same one-hot design, so main effects should agree with ours up to our shrinkage of
  rare champions. ^f22
- [method/interpret] [stats] (inferred) The pair terms are not a cross-check of our
  pair cells. FAST scores a seat pair by its best split into four blocks of
  alphabetically contiguous champions (^f8), and pair boosting moves such blocks (^f7),
  so "Yasuo with Malphite" is only reachable as the overlap of many label-order
  rectangles. With a few dozen games per cell and a near coin-flip outcome, early
  stopping ends long before single cells resolve; what comes out is a surface smoothed
  along champion names, and the FAST ranking of the 45 seat pairs depends on the label
  order. ^f23
- [method/interpret] (inferred) If we run it anyway: feature_types all 'nominal';
  smoothing_rounds=0 and interaction_smoothing_rounds=0 (^f9, ^f30); interactions as the
  explicit list of the pairs we model, to skip FAST (^f10); then purify each pair tensor
  with `purify(term_scores_, bin_weights_)` before comparing with our cells (^f13,
  ^f14). A cell-level variant that keeps the nominal treatment: feed each seat pair as
  one nominal feature (champion A|champion B, up to ~29k levels) with interactions=0,
  so the Fisher sort and min_cat_samples act on cells (^f2). Untested. ^f24
- [method/interpret] (inferred) Memory at 3.5M games, 45 pairs and 14 bags by the
  estimate_mem formula: about 0.6 GB of per-sample arrays, about 0.45 GB of pair
  tensors (172 x 172 cells x 45 x 3 x 14 x 8 bytes), and the per-bag pair datasets,
  which its loose multiplier puts near 9 GB. Order of 10 GB; call estimate_mem before
  a real run. Time is the unknown. ^f25
- [method/interpret] Issue 629: a user reported that renaming nominal levels (prefixing
  each with its rank by mean response) moved a low-importance feature to most
  important. `issues/629.md`, issue body ^f26
  > I had a categorical feature whose importance was quite low before the transformation, and it is the most important feature after this transformation.
- [method/interpret] The maintainer says the Fisher sort applies only in the greedy
  boosting phase; during smoothing rounds cut points are random and categories sit in
  alphanumeric order. `issues/629.md`, comment 2025-08-20 ^f27
  > Fischer is only applied to categoricals during the greedy boosting phase.
  > During that phase the categories in the categorical features are placed in alphanumeric sorted order.
- [method/interpret] He confirmed in May 2026 (interpret 0.7.8) that the random-cut code
  used in smoothing does not shuffle categories; the planned fix is a shuffle per
  smoothing round, other designs not yet benchmarked. `issues/629.md`, comments
  2026-05-24 and 2026-05-25 ^f28
  > That is in PartitionRandomBoosting.cpp, and it doesn't (currently) do shuffling.
  > I think for the next release I will just do randomized shuffling of the categories during each smoothing round.
- [method/interpret] With smoothing_rounds=0 the result no longer depends on level order
  (maintainer on synthetic data, user on his own). `issues/629.md`, comments 2025-08-20
  ^f29
  > I tried this on a synthetic dataset, and the results were invariant to changes in the category order.
  > Indeed, setting smoothing_rounds=0 makes the alphanumeric order irrelevant.
- [method/interpret] The maintainer says smoothing exists for continuous features and
  that for an all-nominal dataset turning it off makes sense. `issues/629.md`, comment
  2026-05-22 ^f30
  > we do smoothing entirely for the benefit of continuous features.  If your dataset consisted entirely of nominals, turning off smoothing rounds would make sense, although I suspect the benefit of doing this is small.
- [method/interpret] (claim) He says the smoothing phase barely changes final accuracy,
  greedy rounds rebalance importances afterwards, and the choice only picks one member
  of a Rashomon set of GAMs. `issues/629.md`, comment 2026-05-25 ^f31
  > from previous benchmarking I can say that the smoothing phase has a fairly minimal effect on the final model performance.
  > there's a kind of Rashmon set for GAMs when features are correlated, so this choice is biasing the model towards one of them.
- [method/interpret] A user with high-cardinality nominals saw effects that look smooth
  along the alphabetical order of levels. `issues/629.md`, comment 2026-05-22 ^f32
  > I was experimenting with high-cardinality nominal categoricals and noticed that the learned effects appeared “smooth” when plotted along the alphabetically sorted levels.
- [method/interpret] Checked, not there: the user's question whether the fix will cover
  interaction smoothing rounds got no answer; the thread says nothing about pair terms
  on nominal features. `issues/629.md` ^f33

## Read

- `python/interpret-core/interpret/glassbox/_ebm.py`: EBMClassifier docstring and
  defaults, fit (bins, flags, FAST, pair stage), estimate_mem.
- `_ebm_core/_boost.py`, `_rank_interactions.py`: whole. `_preprocessor.py`:
  categorical branch and construct_bins. `_utils.py`: process_bag_terms.
- `utils/_purify.py` (docstring), `develop.py` (options).
- `shared/libebm/PartitionOneDimensionalBoosting.cpp` (CompareBin, nominal branch),
  `GenerateTermUpdate.cpp` (dispatch), `PartitionMultiDimensionalStraight.cpp` (sweep),
  `PartitionMultiDimensionalTree.cpp` and `CalcInteractionStrength.cpp` (skimmed and
  grepped), `PartitionRandomBoosting.cpp` (grepped).
- `docs/interpret/hyperparameters.md`: whole. `faq.ipynb`, `CHANGELOG.md`: grepped.
- Issue 629 "Order of nominal feature levels change the results": body and all 11
  comments (2025-08-18 to 2026-05-25), saved as `issues/629.md`; screenshots not seen.

## Not read

- `shared/libebm/Purify.cpp`, `ebm_stats.hpp` (gain and update formulas with reg_alpha
  and reg_lambda), `PartitionMultiDimensionalFull.cpp` (the develop-only full
  interaction score), `_measure_interactions.py` (stand-alone FAST).
- Issues 495 (computational complexity) and 630 (memory use): leads for fit time.
- Nothing was run.
