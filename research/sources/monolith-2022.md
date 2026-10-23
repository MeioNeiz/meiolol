---
title: 'Monolith: Real Time Recommendation System With Collisionless Embedding Table'
url: https://arxiv.org/pdf/2209.07663
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: docs (full paper)
relevance: medium
grade: B/fair
description: Liu et al. (ByteDance, ORSUM@RecSys 2022); production recommender that keeps training after deployment on the live stream (batch pass over history, then online updates), syncs sparse embeddings every minute and dense weights daily, evaluated by train-on-shard-i, test-on-shard-i+1
---
# Monolith: Real Time Recommendation System With Collisionless Embedding Table

Why: how a production embedding model trains on a stream (batch then online), how it
evaluates (next shard), and what it does with stale and rare ids.

## Assessment

- Evidence: B. ByteDance production system (BytePlus Recommend), live A/B test on an
  ads model, plus a Criteo simulation; workshop paper, no error bars on the live test,
  AUC only (no log loss or calibration).
- Reasoning: fair. Explains the dense-vs-sparse sync trade-off and the snapshot
  arithmetic; little ablation beyond sync interval and collisions.
- Interests: authors' own product.
- Weigh: trust the protocol (Algorithm 1) and the direction of the sync-interval
  effect; the 14-18% live AUC "improvement" figure is unexplained (relative to what) and
  not comparable to anything we measure.

## Findings

- [method/dynamics] Two stages: one pass over historical data in batch (used when the
  architecture changes and the model is retrained), then online training on the live
  stream after deployment. 2.2 ^f1
  > Batch training is useful for training historical data when we modify our model architecture and retrain the model
  > After a model is deployed to online serving, the training does not stop but enters the online training stage.
- [method/dynamics] They train each example once: a single pass over the data, not
  several epochs. 2.2 ^f2
  > we only train our dataset for one pass
- [method/dynamics] Evaluation protocol (Algorithm 1, simulated online training on
  Criteo): batch-train on 5 days, split the next 2 days into N chronological shards; for
  each shard, evaluate the current model on it, then train on it (test-then-train,
  i.e. prequential). 3.1.2 ^f3
  > We take 7 days of data from the dataset, and split it to two parts: 5 days of data for batch training, and 2 days for online training.
  > Evaluate online prediction on new data.
- [method/dynamics] Online training beats a frozen batch model on every sync interval,
  and shorter intervals help: average AUC 79.66 (5 h), 79.78 (1 h), 79.80 (30 min) vs
  about 79.43 batch-only. Table 2 ^f4
  > Models with online training performs better than models without.
  > Models with smaller parameter synchronization interval performs better that those with larger interval.
- [method/dynamics] Live A/B on a production ads model: online training gave a
  "significant bump" in serving AUC over batch training (Table 3, 14-18% per day,
  baseline not stated). 3.2.2 ^f5
  > The live A/B experiment between online training and batch training on an Ads model in production also show that there is a significant bump in online serving AUC
- [method/dynamics] Dense weights move much slower than sparse embeddings, so they sync
  embeddings every minute and dense weights once a day with no visible loss. 2.2.3,
  3.2.2 ^f6
  > Dense variables move much slower than sparse embeddings.
  > such inconsistency could be tolerated due to the reason mentioned in (3) as no conspicuous loss has been observed.
- [method/dynamics] New and rare ids: an id enters the table only after a tunable
  number of occurrences; rare ids are judged underfit and not worth keeping. 2.1 ^f7
  > Embeddings corresponding to these infrequent IDs are underfit due to lack of training data
  > First we filter by their occurrences before they are inserted as keys
- [method/dynamics] Stale ids expire after a tunable inactive period, set per table by
  how much that feature depends on history. 2.1 ^f8
  > IDs are timed and set to expire after being inactive for a predefined period of time.
- [method/dynamics] Checked, not there: no special treatment for an id whose behaviour
  changed (no reset, no faster learning rate, no decay of old data); adaptation comes
  only from continuing to train on new examples. Also no log loss, no calibration. ^f9
- [method/dynamics] (inferred) For us: the closest analogue is "warm start from
  yesterday's net, one pass over today's games, score tomorrow's games before training on
  them". Champion-role embeddings play the sparse part and could update daily while the
  DeepSets layers update weekly or per patch. ^f10

## Read

- Full paper (sections 1-5, Algorithm 1, Tables 2-3)

## Not read

- Code (github.com/bytedance/monolith): not needed for the protocol
