---
title: 'AutoElicit: Using Large Language Models for Expert Prior Elicitation in Predictive Modelling'
url: https://arxiv.org/pdf/2411.17284
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: docs (abstract, 1, 5.1-5.2)
relevance: medium
grade: B/fair
description: Capstick, Krishnan, Barnaghi (ICML 2025); LLMs asked for Gaussian priors on each feature's weight in a linear model, mixed over 100 task descriptions; gains over N(0,1) priors at tens to hundreds of labelled rows on clinical tasks
---
# AutoElicit: Using Large Language Models for Expert Prior Elicitation in Predictive Modelling

Why: the measured version of "LLM knowledge as a prior for a linear model", the shape
an LLM prior on champion strength or kit terms would take.

## Assessment

- Evidence: B. ICML 2025, 1 synthetic, 4 public and 1 private clinical dataset, 3+
  LLMs, memorisation tests; tiny datasets (the private one 371 labelled days).
- Reasoning: fair. Honest about memorisation and about LLMs returning N(0,1) when
  unsure; the baseline is an uninformative prior, not a tuned ridge.
- Interests: authors' own method.
- Weigh: the gain is a small-data effect by construction; nothing tells us about a
  model with thousands of games per parameter.

## Findings

- [method/pretrain] Method: the LLM gives a Gaussian prior per feature weight of a
  linear model, for each of 100 paraphrased task descriptions; the mixture is the prior. 4 ^f1
  > Given an LLM M and task T , we obtain a single Gaussian prior for each feature, for each task description Ik by asking
- [method/pretrain] Claimed result: priors substantially reduce error over uninformative
  priors with fewer labels, and beat in-context learning. Abstract ^f2
  > AutoElicit yields priors that can substantially reduce error over uninformative priors, using fewer labels, and consistently outperform in-context learning.
- [method/pretrain] The gain fades with data: on the synthetic task an order of
  magnitude lower MSE after 5 examples, equal after 20. 5.2 ^f3
  > the LLM-elicited priors provide an order of magnitude lower test MSE compared to an uninformative prior after 5 observed examples and an equivalent MSE after 20
- [method/pretrain] On a private task (unseen by the LLM; 78 people, 371 labelled days)
  every elicited prior beat the uninformative one at all training sizes. 5.1-5.2 ^f4
  > This dataset contains 78 people and 371 positive or negative days of UTI.
  > all AutoElicit priors provide greater accuracy over the uninformative prior for all training sizes
- [method/pretrain] When unsure, GPT-3.5 returned N(0,1) priors, giving no gain;
  newer models gave better priors. 5.2 ^f5
  > GPT-3.5-turbo responded with an uninformative prior when unsure of its knowledge
- [method/pretrain] LLM in-context prediction only inconsistently approximates Bayesian
  inference on real data. 1 ^f6
  > We find that the language model inconsistently approximates Bayesian inference on real-world datasets.
- [method/pretrain] (inferred) For us: our champion-role terms have thousands of games
  each, far past the 20-row point where the synthetic gain vanished; an LLM prior could
  only matter for a new champion or a rework in its first days, and an LLM's knowledge
  of League balance is likely stale or memorised from win-rate sites, which a time
  split must guard. ^f7

## Read

- Abstract, 1, 4 (method outline), 5.1-5.2

## Not read

- Appendices (cost, memorisation tests, per-dataset curves, Bayes factor selection)
