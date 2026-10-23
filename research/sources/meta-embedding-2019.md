---
title: 'Warm Up Cold-start Advertisements: Improving CTR Predictions via Learning to Learn ID Embeddings'
url: https://arxiv.org/pdf/1904.11547
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: docs (sections 1-4)
relevance: medium
grade: B/fair
description: Pan, Li, Ao, Tang, He (SIGIR 2019, Meta-Embedding); a small generator maps a new ad's content features to its initial id embedding, meta-trained on old ads by simulating a cold-start batch and one gradient step of warm-up, with the base CTR model frozen; evaluated cold and after 1-3 warm-up mini-batches
---
# Warm Up Cold-start Advertisements: Improving CTR Predictions via Learning to Learn ID Embeddings

Why: the standard reference for initialising a new id's embedding from content and
making its first few updates count, and for an evaluation that tracks loss as a new
entity's games arrive (cold, warm-a, warm-b, warm-c).

## Assessment

- Evidence: B. SIGIR 2019, widely cited (MWUF and later cold-start work compare
  against it); three public datasets, six base models, three runs each; offline only,
  no production deployment.
- Reasoning: fair. Clear objective and protocol; explains the mixed cases; gains shrink
  on the large datasets, which they admit.
- Interests: authors' own method.
- Weigh: trust the protocol and the direction; on large data the gains are small
  (log loss 0.2-1.5% cold) and the random-init baseline catches up within a few
  batches.

## Findings

- [method/dynamics] Id embeddings need many labelled examples; a new id starts near
  zero and predicts badly (cold start); small ids stay undertrained. 1, 2 ^f1
  > For each ad, a large number of labeled examples are needed to train a reasonable ID embedding.
- [method/dynamics] Two goals, both measured: lower loss with no labelled data (cold
  start) and faster fitting after a few examples (warm-up). 1 ^f2
  > Better at cold-start: When making predictions for a new ad with no labeled data, one should make predictions with a smaller loss
  > Faster at warming-up: After observing a small number of labeled samples, one should speed up the model fitting
- [method/dynamics] Method: a generator maps the ad's content features to its initial
  embedding; it is trained on old ids as if new: loss on batch a with the generated
  embedding, one gradient step, loss on batch b; objective alpha l_a + (1 - alpha) l_b,
  alpha 0.1. 3.2, 3.3.2 ^f3
  > To unify these two losses, we propose our final loss function for Meta-Embedding as a weighted sum of la and lb
  > We simply set α to 0.1 for all our experiments.
- [method/dynamics] The base model's shared weights are frozen while the generator
  trains; only new-id embeddings change. 3.2 ^f4
  > when training the Meta-Embedding, we freeze θ and do no update it during the whole process.
- [method/dynamics] Generator is light: reuse the base model's (frozen) feature
  embeddings, pool them, one dense layer with tanh, no bias, L2. 3.3.1 ^f5
  > Finally, we use a dense layer to get the outputs, which is the only trainable part of the generator.
- [method/dynamics] Evaluation: pre-train on old ids, then for each new id score a
  hold-out set cold, then after each of three warm-up mini-batches (a, b, c), log loss
  and AUC relative to a random-init cold baseline. 4.3.2 ^f6
  > For each new ad, we train on 3 mini-batches one by one as if they were the warming-up data, named batch-a, -b, and -c, each with K instances.
- [method/dynamics] Gains are large on small MovieLens (log loss over 15% lower cold for
  some models) but small on the big datasets: KDD Cup log loss -1.52% cold and -4.40%
  vs -3.79% after three warm-up batches; Tencent -0.19% cold. Table 2, 4.4 ^f7
  > An interesting finding is that the relative improvement was more significant on smaller datasets (MovieLens) than the larger ones.
- [method/dynamics] Mixed cases: on Tencent CVR, Wide and Deep with random init overtook
  Meta-Embedding after the third warm-up batch. 4.4 ^f8
  > For Wide & Deep in the Tencent CVR data (see Figure 7), the baseline tended to surpass Meta-Embedding after the third warm-up update.
- [method/dynamics] Checked, not there: only brand-new ids; nothing for an existing id
  whose behaviour changes (no re-initialisation or re-warm-up of a known id). ^f9
- [method/dynamics] (inferred) For us: a buffed or nerfed champion is not cold, it has
  a prior that is now biased. The transferable part is the evaluation (loss on the new
  patch's games after 0, 1k, 5k, 20k games of that champion) and the "learn to adapt in
  one step" objective, which could meta-train how far a champion-role embedding should
  move per patch game. A truly new champion could get its first embedding from its stat
  profile through a frozen-trunk generator. ^f10

## Read

- Sections 1-4 (method, set-up, Table 2, discussion of Figures 6-8)

## Not read

- Figures (image values), conclusion
