---
title: 'Vectorizing string entries for data processing on tables: when are larger language models better?'
url: https://arxiv.org/pdf/2312.09634
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: docs (abstract, sections I-III.A, IV.B-C, conclusion)
relevance: medium
grade: B/fair
description: Grinsztajn, Kim, Oyallon, Varoquaux (INRIA, 2023); benchmark of 30+ string embeddings, language models included, for table columns with text entries, 14 tasks at 500-5000 rows with a GBDT downstream
---
# Vectorizing string entries for data processing on tables: when are larger language models better?

Why: the main measured study of language-model embeddings of categorical or text
entries as table features, the generic version of "embed champion text".

## Assessment

- Evidence: B. INRIA SODA (skrub, scikit-learn authors), 14 tasks, 7-fold CV, many
  models; arXiv preprint.
- Reasoning: fair. Clear regime split with a simple diagnostic; rows capped at 5000.
- Interests: authors maintain skrub's MinHashEncoder, the baseline.
- Weigh: the regime (500-5000 rows, many unseen strings) is the opposite of ours
  (1.4M games, ~170 champions each seen thousands of times); use it only for the
  thin-data end and for the choice of encoder.

## Findings

- [method/pretrain] Two regimes: for "dirty categories" (similar strings, low n-gram
  diversity) language models add little to nothing over string models; for diverse
  entries they help, and bigger is better. Abstract ^f1
  > For dirty categories, pretrained language models bring little-to-no benefit compared to simpler string models.
  > For diverse entries, we show that larger language models improve data processing.
- [method/pretrain] Gain over MinHash is uneven: about zero for slightly under half the
  useful columns, significant for the rest. IV.B ^f2
  > We see approximately zero gain for slightly less than half of the columns and significant gains for the other half.
- [method/pretrain] MTEB rank carries over in the diverse regime; very large decoder
  LLMs (Llama, Mistral, Pythia) add nothing significant over e5-v2. IV.C, Fig. 5 ^f3
  > across all, very large models (Llama, sentence-t5, Pythia, mistral...) bring no significant benefits compared to e5-v2.
  > To date, e5 (v2) [26] stands out as an excellent compromise.
- [data] Sample sizes held below 5000 rows; GBDT downstream; 7 CV folds. III.A ^f4
  > we limit ourselves to sample sizes below 5000
- [method/pretrain] Target encoding, the usual high-cardinality fix, breaks on
  categories unseen in training; text embeddings don't. II.B ^f5
  > it breaks when dealing with categories not seen during the training (out-of-vocabulary problem).
- [method/pretrain] (inferred) For us: champion names are ids, not diverse text; what
  could carry information is a description (abilities, patch notes), embedded with a
  small sentence encoder (e5 or bge class), not a 7B LLM. Gains measured here are at
  thousands of rows and unseen strings, so the expected gain for a champion seen
  thousands of times is near zero; only new or rare champion-roles are in their regime. ^f6
- [method/pretrain] Checked, not there: no result above 5000 rows, no id-embedding
  baseline alongside the text embedding, no log loss. ^f7

## Read

- Abstract, I, II, III.A, IV.B-C, conclusion

## Not read

- Fuzzy-join benchmark (IV, not our problem); appendix dimension sweeps
