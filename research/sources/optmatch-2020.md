---
title: 'Gong et al. 2020: OptMatch, optimized matchmaking via high-order interactions (NetEase Fuxi, KDD)'
url: https://linxiagong.github.io/OptMatch/KDD2020_OptMatch.pdf
kind: paper
commit: 
for: [gnn-match-outcome]
looked: 2026-10-13
depth: docs (sections 3-6, appendix B, Tables 1-8)
relevance: high
grade: B/fair
description: NetEase Fuxi KDD 2020 applied paper; hero synergy and suppression graphs embedded with LINE, players as pick-weighted averages of hero vectors plus stat features, attention team net; time split, LoL 187k games; pretrained graph embeddings tie a learnt embedding layer
---
# Gong et al. 2020: OptMatch, optimized matchmaking via high-order interactions (NetEase Fuxi, KDD)

Why: (b) does a hero graph from co-play and who-beat-whom, embedded then fed to a
predictor, beat plain id embeddings? (c) do they build a player graph?

## Assessment

- Evidence: B. KDD applied track, NetEase production (online test on Fever
  Basketball), four datasets incl. LoL 187,588 games, time split 80/20, five baselines.
  Code repo fuxiAIlab/OptMatch (16 stars, last push Aug 2020).
- Reasoning: fair. Has the key ablation (pretrained graph embedding vs embedding
  layer). But accuracy only, single run, no CIs; the LoL and Dota sets' origin, player
  features and how unseen test players are handled are not described.
- Interests: authors' production system.
- Weigh: the LoL headline (LR 0.599 to OptMatch 0.661) mixes player identity, player
  stats and hero vectors; it is not a graph-vs-no-graph comparison. The clean graph
  comparison (Table 8) is a tie.

## Findings

- [method] Hero2Vec: two hero graphs from match records, a signed synergy graph
  (co-wins minus co-losses) and a directed suppression graph (who beat whom), embedded
  with LINE-style first and second-order proximity. Section 4.2 ^f1
  > To construct the synergy graph, we go through the winning and losing teams respectively and build an edge between each pair of heroes.
  > suppression is a directional relation, which indicates that one hero ℎ𝑎 defeated another hero ℎ𝑏 .
- [method] No player graph in practice: a heterogeneous player-hero graph is named as
  an option, but players are encoded as the average of their picked heroes' vectors
  plus mastery, for deployment efficiency. Section 4.3.2 ^f2
  > the projection can be performed by building and learning a heterogeneous graph that contains the several relationships among players, among heroes and inbetween. Whereas, for the concern of deployment efficiency, we adopt a straightforward solution, which projects the players through average-pooling over their hero-selection
- [method] Each player also gets hand-built record features (on Fever Basketball: game
  count, wins, losses, per-game averages, MVP rate); the net is a self-attention team
  encoder over players, with separate heads for synergy, suppression and feature
  vectors summed. Sections 4.3.1, 4.4, Table 5 ^f3
  > The final output is the weighted sum of those prediction values.
- [data] Datasets: Dota2 50,000 games, 10,815 players; LoL 187,588 games, 139
  champions, 43,706 players; NBA 3,342; Fever Basketball (3v3) 851,648 games, 33,873
  players. Table 1 ^f4
  > LOL(League of Legends) contains 187,588 matches, 139 heroes and 43,706 players.
- [method] Time split: games sorted by time, first 80% train, last 20% test; embeddings
  and player features from training games only. Section 5.2 ^f5
  > Matches are sorted by the time for each dataset. Then we take the first 80% matches as the training set and the remaining 20% matches as the test set.
- [method] Table 2 accuracy, LoL: LR 0.599, XGBoost 0.613, BalanceNet 0.624,
  Blade-Chest 0.636, HOI 0.639, OptMatch without attention 0.655, OptMatch 0.661.
  Dota2: LR 0.596, XGBoost 0.602, HOI 0.628, OptMatch 0.652. Fever Basketball: LR
  0.613, XGBoost 0.639, OptMatch 0.660. ^f6
  > We can observe that OptMatch-Net significantly outperforms all the compared baselines across all the datasets and prediction tasks.
- [method] Pretrained graph embeddings vs a learnt embedding layer inside the same net
  (Fever Basketball): 0.639 vs 0.637 accuracy; the graph only saves training time
  (24.85 s vs 259.59 s). Appendix B, Table 8 ^f7
  > pre-trained embedding vectors lead to comparable performance with adding the embedding layer in the neural network.
- [method] Removing the relational (hero-graph) vectors and keeping player features
  only worsens score-difference error by 5.6% to 23.6% (Fever Basketball). Table 3 ^f8
  > The results in Table 3 show a performance decrease of 5.6% to 23.6%.
- [method] Graph edge definitions matter about as much as the model: synergy weight
  choices move OptMatch from 0.625 to 0.639 and LR from 0.594 to 0.619; none wins
  everywhere. Appendix B.3.1, Tables 6-7 ^f9
  > It’s important to note that no definition of link weights is promised to outperform the others.
- [method] Checked, not there: what player features the LoL and Dota baselines get, how
  test players absent from training are encoded, log loss, intervals, a LR or GBDT on
  the same player features plus hero ids as a fair baseline. ^f10
- [method] (inferred) For us: (b) a co-play or win graph over champions gives the same
  accuracy as learning champion embeddings end to end (0.639 vs 0.637), so it is not
  worth a run for accuracy. The big LoL lift over LR (0.599 to 0.661) most likely comes
  from player history features on a 187k-game set with repeated players, the lever we
  already use, not from the graph. ^f11

## Read

- Sections 3-6 (framework, Hero2Vec, Player2Vec, OptMatch-Net, datasets, split,
  results), appendix B (features, link weights, pretrained vs embedding layer)

## Not read

- Online planning and matchmaking optimisation (section 4.5), NBA appendix
- Project page fuxiailab.github.io/OptMatch (dataset details, LoL source)
