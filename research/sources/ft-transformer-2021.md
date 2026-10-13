---
title: 'Gorishniy et al. 2021: Revisiting Deep Learning Models for Tabular Data (FT-Transformer)'
url: https://arxiv.org/abs/2106.11959
kind: paper
commit: 
for: [draft-predictor-methods, nn-draft-models]
looked: 2026-10-12
depth: skimmed (abstract, 1-3, 4.1-4.5 protocol and takeaways, supplementary E-F tuning spaces)
relevance: medium
grade: A/strong
description: NeurIPS 2021 Yandex benchmark of tabular DL (MLP, ResNet, FT-Transformer, TabNet, NODE...) vs GBDT on 11 datasets of 20k to 1.2M rows under one tuning protocol
---
# Gorishniy et al. 2021: Revisiting Deep Learning Models for Tabular Data

Why: at our scale (10^5 to 10^7 rows), which neural baseline is worth trying, how it
compares with GBDT, and what the tuning and ensembling protocol costs.

## Assessment

- Evidence: A. NeurIPS 2021, widely cited, code released, same protocol for every
  model, 15 seeds per configuration.
- Reasoning: strong. Admits the benchmark leans DL-friendly and that GBDT wins on
  some sets; reports training cost as a limitation.
- Interests: authors propose FT-Transformer.
- Weigh: datasets are larger than Grinsztajn's (20k to 1.2M rows) but mostly
  numerical; no high-cardinality sparse categorical set like ours.

## Findings

- [method] No universally superior solution between GBDT and deep models; a tuned
  ResNet-like MLP is a strong baseline and FT-Transformer wins most of their tasks.
  Abstract ^f1
  > We also compare the best DL models with Gradient Boosted Decision Trees and conclude that there is still no universally superior solution.
- [method] Tuning makes plain MLP and ResNet competitive; MLP stays a good sanity
  check. Section 4.4 ^f2
  > Tuning makes simple models such as MLP and ResNet competitive, so we recommend tuning baselines when possible.
- [method] Protocol: Optuna TPE (Bayesian) tuning on the validation set, 15 seeds per
  tuned config, ensembles of 5 averaged models; comparing ensembles because GBDT is
  itself an ensemble and DL benefits more from ensembling. Section 4.3, 4.5 ^f3
  > For each model, on each dataset, we obtain three ensembles by splitting the 15 single models into three disjoint groups of equal size and averaging predictions of single models within each group.
  > GBDT is essentially an ensembling technique and we expect that deep architectures will benefit more from ensembling
- [method] Cost: FT-Transformer needs more hardware and time than ResNet; attention is
  quadratic in the number of features. Section 3.3 ^f4
  > FT-Transformer requires more resources (both hardware and time) for training than simple models such as ResNet
- [method] DL beating GBDT on most of their tasks reflects a benchmark tilted to
  DL-friendly problems; tuned GBDT dominates on some. Section 4.5 ^f5
  > the fact that DL models outperform GBDT on most of the tasks does not mean that DL solutions are “better” in any sense. In fact, it only means that the constructed benchmark is slightly biased towards “DL-friendly” problems.
- [method] (inferred) With 10 categorical slots, FT-Transformer is a Set-Transformer-like
  model over pick tokens; tokens are few, so the cost concern is training time per
  epoch, not attention size. ^f6
- [method] Training protocol: AdamW, no learning rate schedule, a predefined batch size
  per dataset, early stopping with patience 16 epochs; categoricals as embeddings of one
  shared size. Section 4.3 ^f7
  > We do not apply learning rate schedules.
  > we set patience = 16 for all algorithms.
  > For Neural Networks, we use embeddings of the same dimensionality for all categorical features.
- [method] Default FT-Transformer (an untuned educated guess): 3 layers, embedding size
  192, 8 heads, ReGLU with FFN factor 4/3, attention dropout 0.2, FFN dropout 0.1,
  residual dropout 0, AdamW lr 1e-4, weight decay 1e-5 (0 for tokenizer, LayerNorm,
  biases). Table 12 ^f8
  > Table 12 describes the configuration of FT-Transformer referred to as “default” in the main text.
  > the configuration is a result of an “educated guess” and we did not invest much resources in its tuning.
  > 0.0 for Feature Tokenizer, LayerNorm and biases
- [method] Ensembles of the default FT-Transformer were about as good as ensembles of
  tuned ones. Section 4.5 ^f9
  > Interestingly, the ensemble of default FT-Transformers performs quite on par with the ensembles of tuned FT-Transformers.
- [method] FT-Transformer tuning space: 1-4 layers (1-6 on large sets), embedding 64-512,
  residual dropout {0, U[0, 0.2]} (0 on large sets), attention and FFN dropout U[0, 0.5],
  FFN factor U[2/3, 8/3], lr LogUniform[1e-5, 1e-3] (3e-5 to 3e-4 on large sets),
  weight decay LogUniform[1e-6, 1e-3], 100 Optuna iterations (50 on large sets). Table 13 ^f10
  > (A) UniformInt[1, 4], (B) UniformInt[1, 6]
  > (A) LogUniform[1e-5, 1e-3], (B) LogUniform[3e-5, 3e-4]
- [method] Tuning outcomes: attention dropout always helped and FFN dropout was usually
  non-zero, but residual-branch dropout was rarely chosen; PreNorm kept optimisation
  simple without warmup. E.1 ^f11
  > We observed that the attention dropout is always beneficial and FFN-dropout is also usually set by the tuning process to some non-zero value.
  > it is rarely set to non-zero values by the tuning process.
- [method] ResNet tuning space: 1-8 blocks (1-16 large), width 64-512 (64-1024 large),
  hidden factor U[1, 4], hidden dropout U[0, 0.5], residual dropout {0, U[0, 0.5]},
  lr LogUniform[1e-5, 1e-2], weight decay {0, LogUniform[1e-6, 1e-3]}; tuned inner
  dropout usually above outer, outer often 0. Table 14, F.1 ^f12
  > the inner dropout rate (not the last one) of one block was usually set to higher values compared to the outer dropout rate. Moreover, the latter one was set to zero in many cases.
  > (A,B) LogUniform[1e-5, 1e-2]
- [method] MLP tuning space: 1-8 layers (1-16 large), width 1-512 (1-1024 large),
  dropout {0, U[0, 0.5]}, lr LogUniform[1e-5, 1e-2], weight decay {0, LogUniform[1e-6,
  1e-3]}, 100 iterations. Table 15 ^f13
  > Table 15: MLP hyperparameter space.
  > (A) UniformInt[1, 512], (B) UniformInt[1, 1024]
- [method] Batch size values per dataset in Table 7 were lost in the text snapshot
  (column not extracted). ^f14

## Read

- Abstract, 1, 3 (MLP, ResNet, FT-Transformer), 4.1-4.5
- Supplementary E.1-E.2 (architecture notes, default config, Table 13), F.1-F.2 (Tables 14-15)

## Not read

- 4.6 FT-Transformer vs ResNet on synthetic data, 5 analysis, supplementary timings
- Table 7 batch sizes (garbled in raw/; check the PDF)
