---
title: 'Jalovaara 2024: Win probability estimation in esports, win probability added for League of Legends items (Aalto MSc thesis)'
url: https://sal.aalto.fi/publications/pdf-files/theses/mas/tjal24a_public.pdf
kind: paper
commit:
for: [effect-isolation, live-win-probability]
looked: 2026-10-13
depth: docs (sections 1, 4, 5)
relevance: high
grade: C/fair
description: Aalto master's thesis; DNN in-game win model on 400k ranked match-v5 games of patch 14.15 (75.9% accuracy, ECE 0.9%), then mean win probability added per item over its effect window, separating selection (mean initial win chance) from impact
---
# Jalovaara 2024: Win probability estimation in esports, win probability added for League of Legends items (Aalto MSc thesis)

Why: the closest prior work to what we want: WPA on solo queue match-v5 timelines, with
an explicit split between "chosen when ahead" and "what it adds".

## Assessment

- Evidence: C. Master's thesis; 400k ranked games on one patch, 50k held out, ECE and
  reliability diagrams by time band. Item case study on one champion, 8,206 purchases;
  differences called significant with no test or interval.
- Reasoning: fair. Clear formal definitions and an honest list of challenges (selection
  bias, variance, specificity vs sample size); no causal check of the WPA estimates.
- Interests: academic.
- Weigh: trust the data recipe and the W vs delta-W split; the item values themselves are
  unproven (no intervals). Applies directly to objectives with the same machinery.

## Findings

- [method] Names the bias we care about: some actions are taken when already ahead (or
  as a last resort), inflating (or deflating) their raw win rates. Section 4.2 ^f1
  > Some actions are only taken by players to secure wins when they are already ahead or as a last resort in desperate situations, inflating or deflating their win rates, respectively.
- [method] Win probability added for an action is win chance at the end of its effect
  window minus at its start (end of game if the effect lasts). Section 4.3, eq. 4 ^f2
  > The final state 𝑧 (𝑖) is the last game state affected by 𝑎 (𝑖) .
  > In these cases, 𝑧 should by default be set to the terminal game state, i.e., the last known state of the match.
- [method] [stats] Two statistics per action: mean initial win chance (selection: is it
  taken in winning states) and mean win probability added (impact), averaged over many
  similar states. Section 4.3 ^f3
  > The mean initial win probability 𝑊 𝑋 (𝑎) measures the systemic bias in data points where action 𝑎 is selected in specific game states 𝑥 ∈ 𝑋.
  > The mean win probability added Δ𝑊 𝑋 (𝑎) measures the average impact of taking action 𝑎 in the context of 𝑋.
- [stats] A single event's delta is not a reliable estimate (variance, other players);
  only averages over many similar states are. Section 4.3 ^f4
  > the win probability added Δ𝑊 (𝑑 (𝑖) ) is not a reliable estimate for the impact of 𝑎 (𝑖) ; Δ𝑊 (𝑑 (𝑖) ) is affected by variance and external factors
- [data] Data: 400k ranked games of patch 14.15 from the Riot API, 350k train and 50k test;
  one state per minute plus a state at every key event; one state sampled per 5-minute
  interval to cut correlated rows. Section 5.1 ^f5
  > we used the LoL API [39] to collect a data set of 400 000 Ranked matches played on Patch 14.15.
  > we divide matches into 5-minute intervals and sample one game state uniformly per interval.
- [method] State features: per-player position, level, gold, damage dealt and taken,
  K/D/A; per-team voidgrubs, dragons, barons, turrets, inhibitors; time; average rank as
  the only pre-game feature. Table 5 ^f6
  > Rank              Average rank (skill level) of the players.
  > Voidgrubs         Cumulative number of Voidgrubs killed per team.
- [stats] Model: 75.9% accuracy, ECE 0.90% on 5.65M held-out states; accuracy 55.8% at
  0-4 minutes rising to 84.8% at 24-28, then falling late. Section 5.1 ^f7
  > On this set, the model achieves an aggregate accuracy of 75.9% with an ECE of 0.90%.
  > The accuracy starts at 55.8% and increases with time, peaking at 84.8% in the [24, 28]-minute interval.
- [stats] Example of the selection split: Heartsteel has the higher raw win rate (54.15%)
  but is bought in better states (W 53.66%), and adds less (+0.66 points) than Titanic
  Hydra (+1.46 points). Table 7 ^f8
  > Heartsteel is purchased in more winning situations than Titanic Hydra.
  > Titanic Hydra seems significantly better than the other items, with a Δ𝑊 of 1.46%.
- [stats] Their own stated limit: a trade-off between how specific the state set is and
  sample size. Section 6 ^f9
  > they suffer from a fundamental trade-off between specificity and sample size.
- [stats] Checked, not there: no intervals or tests on delta-W, no objective (dragon,
  baron) values, no check that the state model removes the "already ahead" bias. ^f10
- [method] (inferred) The effect-window choice matters for objectives: Baron's window is
  its buff (about 3 minutes, then until the push resolves); measuring to game end folds
  in everything after. A fixed short window (e.g. 2 to 5 minutes) is the VAEP-style
  answer and is less noisy. ^f11
- [method] (inferred) Their recipe on our data, per event type: W (selection) and
  delta-W (impact) by minute band and lead band, game-clustered bootstrap for intervals,
  and a gold equivalent from the model's win-per-gold slope at that minute. ^f12

- [method] The win model is per state, not a sequence: earlier states are ignored,
  assuming momentum is negligible (as found in traditional sports). Section 5.1 ^f13
  > In this approach, the win probability is estimated based on a single game state; the previous game states are not considered
  > Thus, we do not account for any in-game momentum effects, but previous research has shown that these effects are negligible, at least in traditional sports [13, 19].
- [method] Secondary report of Silva et al. 2018 (the first LoL in-game RNN): 7,621 pro
  games 2015-2018, pre-game categorical inputs plus in-game time series, accuracy 63.9%
  at 5 minutes to 83.5% at 25. Section 3.2 ^f14
  > They used a data set consisting of 7 621 professional LoL matches played between 2015 and 2018.
  > in-game prediction accuracies ranging from 63.9% at the start of a match (𝑡 = 5 min) to 83.5% at the later stages of a match (𝑡 = 25 min).
- [stats] Accuracy falls after the 24-28 minute band: fewer training states late, or
  Elder and long death timers making late games swingier. Section 5.1 ^f15
  > The accuracy decreases in the last three time intervals, likely due to the model having less training data in these match stages.
  > the Elder Dragon combined with long death timers create comeback opportunities for the losing teams

## Read

- Sections 1, 4 (formal method), 5 (data, model, Shen case)

## Not read

- Section 3 literature review in detail (leads: Kim et al. 2020 calibrated MOBA winner
  predictor; Choi et al. on beta-distributed LoL win probabilities; Robberechts et al.
  2021 Bayesian in-game win probability in soccer)
