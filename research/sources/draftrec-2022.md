---
title: 'DraftRec: Personalized Draft Recommendation for Winning in MOBA Games (WWW 2022)'
url: https://arxiv.org/pdf/2204.12750
kind: paper
commit:
for: [draft-predictor-methods, nn-draft-models]
looked: 2026-10-12
depth: docs (setup, outcome results, appendix B)
relevance: high
grade: B/fair
description: WWW 2022 paper; transformer over draft plus player histories; re-implements LR, NN, FM (HOI), OptMatch, NeuralAC on LoL and Dota 2 with a time split
---
# DraftRec: Personalized Draft Recommendation for Winning in MOBA Games (WWW 2022)

Why: which architectures beat logistic regression on draft-only outcome prediction, on a
fair time-split benchmark, and how much player history adds.

## Assessment

- Evidence: B. Peer-reviewed (WWW 2022), code and data public, all baselines
  re-implemented under one protocol with a tuning grid, 10 seeds for recommendation.
  Small data: 280k LoL games (top 0.1%, one season), 50k Dota 2 games (two weeks).
- Reasoning: fair. Honest that LR wins on Dota 2; no AUC or log loss, only accuracy and
  MAE; no confidence intervals beyond a p < 0.01 marker.
- Interests: authors' own model.
- Weigh: the most useful thing is the head-to-head table of model families under one
  time split; the gains from complex draft-only models over LR are under 1 point.

## Findings

- [method] [data] Time split: matches sorted by timestamp, first 85% train, next 5%
  validation, last 10% test. Section 5.1 ^f1
  > we sort the matches by time-stamps and take the first 85% matches as training set, next 5% matches as validation set, and last 10% matches as test set
- [data] LoL data: 279,893 matches of top 0.1% ranked players, 1 Jun to 9 Sep 2021 (one
  season, several patches); Dota 2: 50,000 Kaggle matches from 5 to 18 Nov 2015, mixed
  ranks, average history 2.12 games per player. Table 1, Section 5.1 ^f2
  > matches of the top 0.1% ranked players from June 1, 2021, to September 9, 2021 were collected
  > collected from November 5, 2015 to November 18, 2015. The dataset contains matches from various ranks
- [method] Baselines re-implemented under one protocol: majority class, L2 logistic
  regression, a feed-forward NN, HOI (factorisation machine with pairwise player
  interactions), OptMatch (GNN hero embeddings plus self-attention), NeuralAC
  (attention over synergy and competition). Section 5.2 ^f3
  > HOI [26] : It is based on factorization machines [35] and considers pair-wise interactions between players.
  > We re-implement the aforementioned baselines by strictly following the details of each paper.
- [method] Post-draft accuracy, Table 9. LoL top 0.1%: majority 50.4%, LR 53.2%, NN
  53.4%, HOI (FM) 53.4%, NeuralAC 53.5%, DraftRec without history 54.3%, OptMatch (with
  history) 54.5%, DraftRec 56.2%. Dota 2: majority 51.8%, LR 61.3%, NN 61.1%, HOI 60.8%,
  OptMatch 61.1%, NeuralAC 61.1%, DraftRec 61.1%. (numbers read from Table 9, which
  pdftotext splits into columns) ^f4
- [method] On Dota 2 plain logistic regression was the best post-draft predictor. ^f5
  > However, for the Dota2 dataset, we observed that a simple logistic regression model performed the best.
- [method] Models with players' match histories beat draft-only ones on both datasets
  in the per-turn setting. Section 5.3 ^f6
  > match history information (i.e., OptMatch, DraftRec) show superior performance compared to methods which do not (i.e., LR, NN, HOI, NeuralAC, DraftRec-no-history)
- [method] (inferred) In LoL high elo, draft-only architectures (LR, NN, FM, attention)
  span 53.2 to 54.3% accuracy, about 1 point; adding player history adds about 2 more.
  On 50k mixed-rank Dota games all reach about 61%, no model beats LR. From ^f4. ^f7
- [method] History length: gains from player history converge around the last 50
  games. Appendix B.2 ^f8
  > both DraftRec and OptMatch benefits with longer player match history length 𝐿 and start to converge at 𝐿 = 50
- [method] Metrics are accuracy and mean absolute error only; checked, not there: no
  AUC, log loss or calibration. Section 5.2 ^f9
  > For match outcome prediction task, we consider Accuracy (ACC) and Mean Absolute Error (MAE) as our metrics.
- [method] (inferred) Dota draft-only accuracy (61%) is far above LoL's (53%) on the
  same models; mixed ranks and the 2015 meta (stronger heroes, more imbalance) are
  likely causes, so Dota accuracies do not transfer as targets for ranked LoL. ^f10

- [method] Training setup for all re-implemented models: 2 layers, Adam (0.9, 0.999), gradient clipping at l2 norm 5, 64 dims per attention head. Section 5.2 ^f11
  > we set the number of layers 𝑁 = 2 and used the Adam optimizer with 𝛽 1 = 0.9, 𝛽 2 = 0.999 with gradient clipping when its 𝑙 2 norm exceeds 5.
- [method] Common tuning grid: learning rate {1e-2, 1e-3, 1e-4} with cosine annealing, l2 {1e-2 to 1e-5}, dropout {0, 0.1, 0.2}, hidden size d {64, 128, 256}, batch {256, 512}; history length L {0 to 100} for history models. Checked, not there: chosen values per model, epoch counts, early stopping rule. Section 5.2 ^f12
  > learning rate 𝑙𝑟 ranges from {0.01, 0.001, 0.0001} and anneal with a cosine scheduler
  > dropout rate 𝑝 from {0, 0.1, 0.2}, hidden dimension size 𝑑 from {64, 128, 256}, and batch size from {256, 512}
- [method] Multi-task: DraftRec's outcome head is trained jointly with the champion recommendation head; team vectors are average-pooled player representations, subtracted, then two fully connected layers and a sigmoid. Section 4.3 ^f13
  > We jointly perform the match outcome prediction by comparing the representations of the two teams.
  > we subtract the two team representations and apply two fully-connected layers followed by a sigmoid function

## Read

- Abstract, sections 2, 5.1-5.3, appendix B.1-B.2, Tables 1, 3, 9

- 2026-10-13: section 5.2 training details, outcome head (section 4.3)

## Not read

- Recommendation method details beyond the outcome head, loss weighting between the two heads, user survey (Table 5), feature tables 6-7 (in-game
  stats in the history encoding)
