---
title: 'NeuralAC: Learning Cooperation and Competition Effects for Match Outcome Prediction (AAAI 2021)'
url: https://ojs.aaai.org/index.php/AAAI/article/download/16528/16335
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (datasets, baselines, Table 2, ablations)
relevance: high
grade: B/fair
description: Gu et al. AAAI 2021; neural pairwise cooperation and competition terms with attention vs BT, LR, TrueSkill, LightGBM, FM (HOI) and OptMatch on Dota 2 (2015, 2018), LoL ARAM and TFT
---
# NeuralAC: Learning Cooperation and Competition Effects for Match Outcome Prediction (AAAI 2021)

Why: how much do learned pairwise synergy and counter terms add over additive hero
strength, and how do GBDT and FM compare, on hero-only inputs at ~0.6-0.8M games.

## Assessment

- Evidence: B. AAAI paper, code public (github.com/firepd/NAC), seven baselines with
  standard packages, four datasets.
- Reasoning: fair. Ablations separate cooperation, competition and attention. But
  random 80/10/10 split, single run, no intervals, no log loss; the LoL set is ARAM.
- Interests: authors' own model.
- Weigh: its +0.03 AUC over LR did not reproduce in [[draftrec-2022#^f4]]'s
  time-split re-implementation (NeuralAC tied LR on Dota, +0.2 points on LoL); treat
  the gain as an upper bound under random splits.

## Findings

- [data] Dota 2 ranked matches from yasp (2015, 800,000) and Varena (2018, 580,270);
  LoL 754,700 matches of a single-lane mode (ARAM, random champions); TFT 800,000.
  Short games filtered (under 15 min Dota, 8 min LoL). Table 1 ^f1
  > We downloaded ranked matches from yasp.co1 and Varena2 , which were played in the years of 2015 and 2018 respectively.
  > we investigate a special game mode, where players are forced to fight on one single line
  > We filter out matches that played less than 15 minutes for Dota2 and 8 minutes for LoL.
- [method] Hero-only inputs, no player skill, justified by matchmaking. ^f2
  > Due to the existence of matchmaking systems, players on both sides have relatively close skills. Therefore, we treat each hero as an individual.
- [method] Random split 80/10/10; metrics AUC and accuracy. ^f3
  > For every dataset, we randomly divided samples into 80% for training, 10% for validating, and 10% for testing.
- [method] Table 2 AUC (accuracy). Dota2015: LR 0.633 (59.6%), LightGBM 0.645
  (60.4%), FM/HOI 0.637, OptMatch 0.633, NeuralAC 0.662 (61.6%). Dota2018: LR 0.612
  (57.8%), LightGBM 0.622 (59.3%), HOI 0.614, OptMatch 0.617, NeuralAC 0.641 (60.1%).
  LoL ARAM: LR 0.635 (59.7%), LightGBM 0.641, OptMatch 0.652, NeuralAC 0.666 (62.1%).
  Bradley-Terry equals LR; TrueSkill on heroes is worst. (Read from the table, which
  pdftotext splits into columns.) ^f4
  > First, NeuralAC outperforms all the other baselines on all datasets
- [method] Ablation: dropping competition (counter) terms costs more than dropping
  cooperation; dropping attention costs little (Dota2015 0.661 vs 0.662). Table 2
  variants ^f5
  > Second, by incorporating cooperation effects, HOI performs better than BT, LR and Trueskill on most datasets.
- [method] (inferred) Under random splits at 0.6-0.8M games, pairwise terms add about
  0.01 (FM, LightGBM) to 0.03 AUC (NeuralAC) over additive LR, i.e. 1-2 accuracy
  points; Dota 2018 is less predictable from heroes than Dota 2015 (0.612 vs 0.633 LR). ^f6

## Read

- Sections 1, datasets, baselines, setup, results, ablations; Table 1-2

## Not read

- Model derivation details (section 3), interpretability figures, appendix
