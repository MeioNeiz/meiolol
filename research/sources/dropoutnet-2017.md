---
title: 'DropoutNet: Addressing Cold Start in Recommender Systems'
url: https://proceedings.neurips.cc/paper/2017/file/dbd22ba3bd0df8f385bdac3e9f8be207-Paper.pdf
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: docs (sections 1, 4, 5.1)
relevance: medium
grade: B/fair
description: Volkovs, Yu, Poutanen (layer6.ai, NeurIPS 2017); a net takes both an item's learnt preference vector and its content features, trained with the preference input dropped at random, so one model serves warm items (ids) and cold items (content)
---
# DropoutNet: Addressing Cold Start in Recommender Systems

Why: the standard recipe for combining an id representation with a content one (text,
kit) without losing warm accuracy, the shape of a "champion id plus text embedding"
model that must also score new champions.

## Assessment

- Evidence: B. NeurIPS 2017, widely cited, code public (layer6ai-labs/DropoutNet);
  benchmarks are recommender recall, not win prediction; a reviewer called it not very
  novel.
- Reasoning: fair. Clear mechanism and a dropout-rate sweep.
- Interests: authors' own method.
- Weigh: trust the mechanism and the warm/cold trade-off curve; sizes are for
  recommendation recall.

## Findings

- [method/pretrain] Method: the net gets both the id-derived latent vector and content;
  during training a random fraction of items have their id input set to zero, so the
  model learns to fall back on content. 4.2 ^f1
  > In each mini-batch a fraction of users and items is selected at random and their preference inputs are set to 0 before passing the mini-batch to the model.
- [method/pretrain] With the id input present, the objective is minimised by ignoring
  content; dropped pairs force content use; the balance acts like hybrid interpolation. 4.2 ^f2
  > pairs with dropout encourage the model to only use content information, while pairs without dropout encourage it to ignore content and simply reproduce preference input.
- [method/pretrain] CiteULike sweep: warm accuracy drops less than 1% until the dropout
  rate reaches 0.7; cold accuracy rises with dropout, and even 0.1 improves it by over
  60% over none. 5.1 ^f3
  > warm start accuracy remains virtually unchanged decreasing by less than 1% until dropout reaches 0.7 where it rapidly degrades
  > without dropout cold start performance is poor and even dropout of 0.1 improves it by over 60%
- [method/pretrain] Content-only item representations (DeepMusic) were worse on warm
  items than id-based models: content alone loses preference information. 5.1 ^f4
  > This can be attributed to the fact that in DeepMusic item latent representations are functions of content only and thus lack preference information.
- [method/pretrain] (inferred) For us: give a champion-role term both its learnt id
  value and a content vector (text or kit embedding, pretrained stat profile), and drop
  the id input for a random share of seats in training; warm champions keep their
  accuracy and a new or reworked champion gets a content-based estimate. In a shrunk
  GLM the same idea is a content-predicted prior mean (RLFM, augmented APM). ^f5

## Read

- Abstract, 1, 4 (model and training), 5.1 (CiteULike)

## Not read

- 5.2 RecSys 2017 challenge results, 4.3 transforms for partial preference data
