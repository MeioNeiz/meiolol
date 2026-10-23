---
status: answered
priority: now
area: stats
parent: patch-transfer
tags: [method/dynamics, method]
description: How do we train neural draft models across patches (which old games to trust, which parts to refit) and evaluate them on the newest patch only?
---
# How do we train neural draft models across patches (which old games to trust, which parts to refit) and evaluate them on the newest patch only?

Feeds: docs/plan/patch-transfer.md (PT2 day-by-day mode, PT4 net). Child of [[patch-transfer]] (ratings-level arms, rolling-origin eval).

## Answer

Evaluate the update procedure, not one fitted model: score each new slice before training
on it, as Google's and Huawei's CTR systems do (C1). Every game was once a newest-patch
game, so a day-by-day replay scores only newest-patch games without starving training,
and arms are compared as paired differences on the same games (C2).

Update: a daily warm start with one pass on the new day matches a full retrain at a
fraction of the cost, and staleness costs more than the retraining method (C3). For the
net, warm-starting a retrain on pooled data generalises worse than a fresh start, which
shrink and perturb fixes; logistic ratings are unaffected (C6). Continued training needs
a re-raised learning rate and a small replay share (C7).

Which parts to refit: tune where the shift lives. With little target data, tuning only
the shifted block beats tuning everything, and the gap closes as target data grows (C4).
A patch is an input-level shift in a few champion-role rows, so refit the patch offsets
and embedding rows and keep the body (C5, inferred). When new per-patch parameters are
added, fit them first with the body frozen (C8). Stream systems give dense layers a slower
cadence than embeddings (C9), but none reopens an existing id whose behaviour changes
abruptly: that part is ours to build (C10).

Which old games to trust: not by a domain classifier, which corrects shifts in which
drafts are played, not in who wins them (C11). Finding stale data needs new-patch labels
or prior knowledge of where it changed (C12). Up-weighting new-patch games beats pruning
old ones (C13), and label-driven down-weighting pays mainly while new data is under ~10%
of old (C14). With a label this noisy, trust is per cell (a champion's or item's old
games), not per game, and per-parameter priors express it better than game weights (C15,
inferred). Predicting a change's effect from the change list: nothing beyond
[[frontier-dynamics]] C6; angle saturated (4 searches found nothing new).

## Claims

- C1: Production streaming CTR systems evaluate by scoring each new slice before training on it (progressive validation). for: [[ctr-trenches-2013#^f1]], [[ctr-trenches-2013#^f2]], [[monolith-2022#^f3]], [[incctr-2020#^f2]]
- C2: Variants compare only on the same data and time range, as a relative difference. for: [[ctr-trenches-2013#^f3]]
- C3: A daily warm start with one pass on the newest data roughly matches a full retrain at a fraction of the cost; updating often matters more than how. for: [[incctr-2020#^f3]], [[incctr-2020#^f4]], [[monolith-2022#^f2]], [[monolith-2022#^f4]]
- C4: With little target data, tuning only the parameters where the shift lives matches or beats tuning all of them; freezing pays less as target data grows. for: [[lee-surgical-ft-2022#^f1]], [[lee-surgical-ft-2022#^f4]], [[lee-surgical-ft-2022#^f5]], [[lee-surgical-ft-2022#^f6]]
- C5 (inferred): A patch is an input-level shift in a few champion-role rows, so the surgical refit is the ratings offsets plus embedding rows on newest-patch games, body and head kept. from: C4, C10
- C6: For non-convex nets a warm-started retrain on pooled data generalises worse than a fresh start, logistic models are unaffected, and shrink and perturb matches the better of the two. for: [[ash-adams-warmstart-2020#^f1]], [[ash-adams-warmstart-2020#^f2]], [[ash-adams-warmstart-2020#^f6]], [[ash-adams-warmstart-2020#^f8]]
- C7: Continued training with a re-raised learning rate and a small replay share matches a fresh retrain on the union; without replay it forgets the old data. for: [[ibrahim-continual-pretrain-2024#^f2]], [[ibrahim-continual-pretrain-2024#^f3]], [[ibrahim-continual-pretrain-2024#^f4]]
- C8: Full fine-tuning distorts features mostly when the head starts far from right; fitting the new head first (LP-FT) avoids it. for: [[kumar-lpft-2022#^f3]], [[kumar-lpft-2022#^f4]]
- C9: Dense layers can update less often than entity embeddings without loss. for: [[monolith-2022#^f6]]
- C10: Published stream systems have no mechanism for an existing entity whose behaviour changes abruptly; per-id learning rates only decay. for: [[incctr-2020#^f5]], [[ctr-trenches-2013#^f8]], [[mwuf-2021#^f10]], [[meta-embedding-2019#^f9]]
- C11: Domain-classifier or density-ratio weighting assumes p(y|x) unchanged and cannot flag old games whose outcome relationship changed. for: [[bickel-2009-discriminative-covariate-shift#^f1]], [[kouw-loog-2018-intro-da#^f2]], [[jiang-zhai-2007-instance-weighting#^f3]]
- C12: Finding which old data is still valid under a p(y|x) shift needs labelled target data or prior knowledge of where it changed. for: [[jiang-zhai-2007-instance-weighting#^f2]], [[kouw-loog-2018-intro-da#^f8]]
- C13: Up-weighting labelled target data (2-20x) beats pruning source data, and combining them is worse than up-weighting alone. for: [[jiang-zhai-2007-instance-weighting#^f6]], [[jiang-zhai-2007-instance-weighting#^f7]], [[jiang-zhai-2007-instance-weighting#^f8]]
- C14: Label-driven down-weighting of old instances pays mainly when new data is under ~10% of old. for: [[dai-2007-tradaboost#^f3]], [[dai-2007-tradaboost#^f4]]
- C15 (inferred): For us trust is per cell (a champion-role's or item's old games), expressed as per-parameter priors loosened by the change list and the new patch's own games, not per-game weights. from: C11, C12, C13, C5
- C16: A new entity should start from the mean or a content-based embedding, not random; the gain fades within a few batches. for: [[mwuf-2021#^f6]], [[mwuf-2021#^f7]], [[meta-embedding-2019#^f7]]

## Disagreements

- Warm start: IncCTR finds a daily warm start matches a retrain (C3, B), Ash and Adams
  find it generalises worse (C6, B). Different regimes: one pass on a small new slice vs
  retraining on the growing union. PT4 in docs/plan/patch-transfer.md tests the daily warm start.
- Freezing: Lee finds freezing beats full tuning with little target data (B), Ibrahim
  finds continued full training fits new data best (B) on a huge new set. Our new patch
  is small on day 0-2 and large by day 7: expect the answer to change by day.

## Open

- Every net source is vision, language or CTR; none has a label as noisy as a win. Replay
  and freezing may matter more here than there.
- Which blocks transfer across a patch on our data (main effects, pairs, comp profiles):
  measured by PT3 in the plan, no source answers it.
- Leads: WiSE-FT, EWC, tiny episodic memories, loss of plasticity, SML, Google's factory
  floor, Kraken (logged in the ledger).
