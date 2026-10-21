---
title: 'DraftFM: A Foundation Model for Day-Zero Drafting in Magic: The Gathering'
url: https://arxiv.org/pdf/2608.19568
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: docs (abstract, sections 1-2.2.2)
relevance: high
grade: C/strong
description: Ward 2026 arXiv preprint; MTG pick model with no card ids, cards as frozen structured features plus a sentence embedding of rules text, trained on 149M picks from 29 sets, scored zero-shot on 3 whole held-out sets; reviews LLM-as-policy and multi-set transfer work
---
# DraftFM: A Foundation Model for Day-Zero Drafting in Magic: The Gathering

Why: closest analogue to "text embeddings for new or rare champions": a game whose
entities (cards) are replaced wholesale every few months, so cold start is the whole
problem.

## Assessment

- Evidence: C. Single independent author, one month old, not reviewed; but huge data
  (170M picks), whole-set holdouts declared in advance, a sealed prospective forecast
  with hashes. Target is human pick agreement, not win.
- Reasoning: strong. Separates within-set from day-zero regimes, says why each number
  can't be compared, lists what the features exclude.
- Interests: none known.
- Weigh: trust the design lessons and the literature summary (Bertram 2024a, 2025);
  no ablation of text versus structured features, so the text embedding's own share is
  unknown.

## Findings

- [method/pretrain] Cards enter only as a frozen 775-dim vector: 391 structured
  features plus a 384-dim sentence embedding of type line and rules text; no card or
  set ids, no usage statistics. Abstract, 2.2.2 ^f1
  > Every card is represented by 775 numbers. Of these, 391 are structured features and 384 form a text embedding.
  > It contains no card-identity, set-identity, artist, price, image, or post-release performance feature.
- [method/pretrain] Text encoder: frozen bge-small-en-v1.5, the card's own name
  replaced so the name can't act as a hidden id; computed once per card. 2.2.2 ^f2
  > embedding of the card’s type line and rules text from the frozen BAAI/bge-small-en-v1.5 sentence encoder
  > A card’s own name is replaced before embedding so that a known proper noun cannot act as a hidden card identifier.
- [method/pretrain] [data] Scale and result: 1.6M-parameter net on 149M picks from 29
  sets; held-out whole sets 50.8%, 60.4%, 56.7% top-1 pick agreement, against 68.6%
  in-distribution (within-set models with card ids reach 66-71%). Abstract, 1 ^f3
  > A 1.6-million-parameter network fitted on 149 million human picks from 29 expansions predicts held-out picks in three expansions withheld in their entirety, reaching 50.8%, 60.4%, and 56.7% top-1 agreement
  > Our own in-distribution validation agreement is 68.6%, squarely inside the 66–71% band the within-set literature reports
- [method/pretrain] LLM as the predictor failed (Bertram 2025, reported here):
  zero-shot GPT-4o agreed with humans 43%, below expert hand ratings (44.5%), and
  giving it full rules text lowered accuracy; 7-8B models fine-tuned on 1M picks still
  trailed small MLPs. 1 ^f4
  > Zero-shot GPT-4o agrees with human picks 43% of the time on Kamigawa: Neon Dynasty, below the expert-tuned ratings above, and supplying each card’s full rules text in the prompt lowers its accuracy further.
  > they still trail small supervised multilayer perceptrons at far higher inference cost
- [method/pretrain] Design lesson the author draws: frozen text embedding as a
  feature, not an LLM as the policy. 1 ^f5
  > The design lesson we take is to use a frozen text embedding as a feature, not a language model as the policy.
- [method/pretrain] Bertram et al. 2024a (reported): semantic card representations are
  needed to score unseen cards, and multi-set training, not the representation alone,
  buys transfer; best unseen-set 55.4% used post-release usage statistics; features
  only, single-set training, 33.6-35.6%. 1, 2.2.1 ^f6
  > showed that multi-set pretraining, not the representation alone, is what buys transfer
  > Their day-one-feasible representation, features only, reaches 33.6% to 35.6% on unseen sets under single-set training
- [method/pretrain] Checked, not there: no ablation of the text embedding against the
  structured features alone, and no win or outcome target (pick agreement only;
  outcome evaluation deferred to a later note). ^f7
- [method/pretrain] (inferred) For us: champions are not replaced wholesale (one new
  champion every few months, a few reworks), so the day-zero regime is a small slice;
  ids plus a feature prior (rather than features instead of ids) fits our case, and
  the 68.6% vs 51-60% gap is the price of dropping ids where they are learnable. ^f8

## Read

- Abstract, sections 1, 2.1, 2.2.1, 2.2.2 (representation)

## Not read

- Section 3 width comparison and per-pick behaviour, section 4 sealed HOB forecast
  (outcome evaluation not yet published)
