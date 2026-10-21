---
title: 'Muschalik, Fumagalli, Baniecki, Kolpaczki, Hammer, Hüllermeier 2024: shapiq: Shapley interactions for machine learning'
url: https://arxiv.org/pdf/2410.01649
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-2, 3 exact computer, 4.1)
relevance: medium
grade: B/strong
description: NeurIPS 2024 datasets and benchmarks (LMU, Bielefeld, Warsaw, Paderborn); Python package unifying exact and approximate Shapley values and any-order Shapley interactions (k-SII, STII, FSII, Möbius), with a benchmark of 11 games; exact computation for small player counts, ground truth precomputed up to 16 players; pairwise interactions much more faithful than plain SHAP
---
# Muschalik et al. 2024: shapiq

Why: practical tooling and the trade-offs between interaction indices, for a 10-seat
draft model where exact computation is feasible.

## Assessment

- Evidence: B. NeurIPS 2024 benchmark track, maintained open-source package from the
  groups that proposed SHAP-IQ and k-SII; 2,042 precomputed benchmark games.
- Reasoning: strong. Defines every index, says which axioms each keeps and when to
  choose which; measured faithfulness by order.
- Interests: authors' package.
- Weigh: trust the definitions and faithfulness comparison; their games are not noisy
  near-coin-flip outcomes.

## Findings

- [method/interpret] At the highest order Shapley interactions become the Möbius
  interactions: each coalition's isolated joint contribution, summing to every
  coalition's worth. Section 1 ^f1
  > the SIs yield the Möbius Interaction (MI), or Möbius transform [27, 35, 69].
  > captures the isolated joint contribution, which allows to additively describe every coalition’s worth by a sum of the contained MIs.
- [method/interpret] The package computes 18 indices exactly for small games
  (k-SII, Shapley-Taylor, Faith-Shap, Möbius among them); exact computation hits its
  limit as player count grows; ground truth was precomputed up to 16 players. Section 3 ^f2
  > The shapiq.ExactComputer class provides an interface for computing 18 interaction indices and game-theoretic concepts, including the MIs
  > For n > 16, where pre-computing a game and ground truth values becomes computationally prohibitive
- [method/interpret] Faithfulness rises with explanation order; pairwise interactions
  are already a large improvement over plain Shapley values; when higher-order effects
  dominate, a higher order is needed. Section 4.1 ^f3
  > pairwise interactions (k = 2) already yield a strong improvement in faithfulness.
  > If higher-order interactions dominate, then SIs require a larger explanation order to maintain faithfulness.
- [method/interpret] Index choice: FSII and FBII optimise faithfulness; Shapley-Taylor
  projects all higher-order effects onto the top order; k-SII stays consistent with
  SII and is their recommended default. Section 4.1 ^f4
  > STII projects all higher-order interactions to the top-order SIs, and k-SII is consistent with SII.
  > Pracitioners may choose SIs tailored to their specific application, where k-SII is a good default choice for shapiq.
- [method/interpret] Checked, not there: uncertainty across model seeds or data,
  aggregation of local interactions into a global table, a value function for
  categorical "absent" players. ^f5
- [method/interpret] (inferred) Our draft is a 10-player game: exact Möbius over seats
  (1,024 coalitions) per draft is within the package's exact range, so we never need
  approximators; the open design choice is the value function (what an absent seat
  is: average over legal replacement champions in that role), which fixes the meaning
  of every pair and triple ([[bordt-nshapley-gam-2023#^f5]]). ^f6

## Read

- Abstract, 1, 2 (definitions), 3 (exact computer, games), 4.1.

## Not read

- 4.2-4.3 (approximator benchmarks), appendices.
