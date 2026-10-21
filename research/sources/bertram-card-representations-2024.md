---
title: 'Learning With Generalised Card Representations for Magic: The Gathering'
url: https://arxiv.org/pdf/2407.05879
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: docs (whole paper)
relevance: high
grade: B/fair
description: Bertram, Fürnkranz, Müller (JKU Linz, Alberta; IEEE CoG 2024); same pick model with one-hot, random-vector, text-plus-feature, image and usage-statistic card inputs, scored on seen cards and on whole unseen sets; ~100M picks
---
# Learning With Generalised Card Representations for Magic: The Gathering

Why: the cleanest ablation found of id versus text-derived entity representations with
plenty of data: does content help where ids are learnable, or only for unseen pieces?

## Assessment

- Evidence: B. Established game-AI group (Fürnkranz, Müller), CoG 2024, 100M picks,
  one controlled table varying only the input. Random 80/20 split within sets (not
  time); one seed per row; target is human pick agreement, not win.
- Reasoning: fair. Interprets the null on seen cards plainly; admits unexplained
  results (features plus meta barely beat features).
- Interests: none known.
- Weigh: trust the qualitative pattern of Table II (identical on seen, different on
  unseen); differences under ~0.5 points on the seen set have no error bars.

## Findings

- [method/pretrain] Table II, trained on NEO only (~5M picks), top-1 on held-out NEO:
  one-hot 67.80%, random vectors 67.87%, text plus features 67.76%, features plus meta
  68.07%, all inputs 68.00%. On unseen sets: random 23.79% (chance), features 33.57%,
  meta statistics alone (16 numbers) 42.14%, all inputs 42.87%. VI.A ^f1
- [method/pretrain] With enough data on a set, card representation doesn't matter: even
  random vectors match semantic features; content matters only for unseen cards. VI.A ^f2
  > The Random model is still able to accurately model decisions in NEO, thus showing that with sufficient data on a set, generalised knowledge is not required.
  > From this experiment, the initial card representation appears largely irrelevant when CPR is used to construct an embedding space for known cards.
- [method/pretrain] Text features are encoded as a sentence-transformer embedding of
  the full card text, appended to numerical and categorical features. IV.B ^f3
  > append a textembedding of the full card text generated with a sentence transformer [12].
- [method/pretrain] For unseen cards, 16 usage statistics (pick and win rates) beat the
  text-and-feature representation, and the authors suspect the model used only shallow
  features such as colour. VI.A ^f4
  > The Meta model with only 16 features based on meta attributes achieves among the best accuracy on unseen sets
  > with limited data, models do not generate rich semantics of cards but rather use shallow features like their colour
- [method/pretrain] Pretraining on 75M picks across sets and fine-tuning on one known set
  gave no gain over random initialisation, and fine-tuning on one set made others
  worse (forgetting). Fine-tuning on the new set lifted it from 55.44% to 62.27%. VI.B,
  Table III ^f5
  > We find that fine-tuning on NEO barely improves accuracy on the set and does not achieve better overall results than random initialisation.
  > This again shows that when regarding a known, fixed set of cards, generalised knowledge of card semantics seems to not affect accuracy.
- [method/pretrain] Checked, not there: no win or outcome target, no time split within a
  set, no thin-card (rare) breakdown among seen cards. ^f6
- [method/pretrain] (inferred) For us: our ~170 champions are all "seen" with thousands
  of games each, the regime where representation was irrelevant. Content (text, kit)
  can only pay on new champions, reworks and thin champion-roles, and even there a
  few usage statistics beat text. ^f7

## Read

- Whole paper

## Not read

- Related CPR paper (arXiv 2407.05898, contextual InfoNCE)
