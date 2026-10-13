---
status: answered
priority: now
area: stats
tags: [method, data]
description: How do live win-probability models in LoL and Dota 2 predict the winner from draft and in-game state, and what beat what?
---
# How do live win-probability models in LoL and Dota 2 predict the winner from draft and in-game state, and what beat what?

Feeds: meiolol-state (P(win | draft, full state at minute t), importance by minute) and
meiolol-draftpath (how drafts win, draft vs state over time, mediation through the early
lead); coordinator meiolol-bd. Jacob: accurate win prediction from draft plus in-game
state, and how much each thing matters.

## Answer

On team-total state the model family barely matters: logistic regression, random forests
and gradient-boosted trees land within about a point of each other at every stage; an MLP
did worse (C1). Gains come from features and from letting game time interact with them:
per-minute-window models beat one pooled model (C3). The pre-game (draft) prior's added
value fades with time; in Dota a state-only model passed a prior-only one at about 15
minutes, and stacking the prior's output with the state model's works (C2). No fair
comparison shows a sequence model beating a per-frame one: the widely quoted high
sequence numbers are a gold-regression R2 on overlapping random windows or scores on
each game's last window (C4). Neural win models come out miscalibrated and temperature
scaling brings them to about 1% ECE; no source reports calibration by minute (C5). Fair
evaluation: clock minutes (not "% of game length", unknown live), a game-level and
ideally time-ordered split, metrics per minute band; late-band accuracy covers only games
still running (C6). OpenAI Five trains its win head on its own next prediction (the
result only at the end) and its minute-0 output doubles as a draft evaluator (C7).

Reference numbers on ranked match-v5 data (C8): XGBoost by band, AUC / log loss, 1-5 min
0.629/0.667, 6-10 0.733/0.604, 11-15 0.823/0.515, 16-20 0.862/0.461, 21-25 0.905/0.388,
26-30 0.909/0.381, 31-45 0.866/0.455 (9.6k games); 75.9% accuracy and 0.9% ECE overall,
55.8% at 0-4 minutes to 84.8% at 24-28 (400k games).

Do this (meiolol-state, C9): one row per game-minute (or per bucket), LightGBM and a
smooth logistic, minute interacting; baselines LR on gold diff only and LR on everything.
Features: blue-minus-red diffs (gold, XP, level, CS, per-role gold), kills, towers by tier
and lane, plates, dragons by type, soul state, grubs, herald, barons, baron and elder buff
time left, inhibitor respawn timers from event times, 3-minute change in each diff,
average rank. Draft: the frozen draft model's out-of-fold logit as a feature, plus a
per-band stack logit = a(t) draft + b(t) state to show the fade. Weight each game once per
band. Split by match, test on the latest days. Report log loss, Brier, AUC and ECE
(equal-mass bins) per band with game-bootstrap intervals; headline mean log loss over
minutes 5-20 and each band's gain over gold-diff-only. A GRU over frames only as a
challenger, kept if it wins per-band log loss.

## Claims

- C1: On team-total state, LR and gradient-boosted trees are within about a point; an MLP did worse. for: [[hodge-2019-win-prediction#^f10]], [[lol-realtime-2023#^f4]], [[jjzhao-lol-win-probability#^f4]]
- C2: The pre-game prior's added value fades with game time; state-only passes prior-only at about 15 minutes in Dota; stacking prior and state outputs works. for: [[yang-dota-realtime-2016#^f4]], [[yang-dota-realtime-2016#^f5]], [[yang-dota-realtime-2016#^f9]]
- C3: Game time must interact with state: per-minute-window models beat a pooled one. for: [[yang-dota-realtime-2016#^f8]], [[hodge-2019-win-prediction#^f9]]
- C4: No fair comparison shows a sequence model beating a frame model; high sequence numbers come from wrong targets or leaky splits. for: [[akhmedov-dota-ml-2021#^f1]], [[akhmedov-dota-ml-2021#^f3]], [[pletinka-dota-timeslice-2025#^f3]], [[jalovaara-lol-wpa-items-2024#^f13]] against: [[yang-dota-realtime-2016#^f7]]
- C5: Neural win models need post-hoc calibration; temperature scaling cut ECE from 4.47% to 1.11%. for: [[kim-calibrated-moba-2020#^f5]], [[jalovaara-lol-wpa-items-2024#^f7]], [[pletinka-dota-timeslice-2025#^f4]]
- C6: Fair evaluation uses clock minutes, a game-level time-ordered split and per-band metrics; "% of game length" is unknown live. for: [[hodge-2019-win-prediction#^f7]], [[hodge-2019-win-prediction#^f8]], [[jjzhao-lol-win-probability#^f2]], [[yang-dota-realtime-2016#^f6]], [[lol-realtime-2023#^f2]]
- C7: OpenAI Five's win head is trained toward its own later prediction, the result only at the end; its minute-0 output serves as a draft evaluator. for: [[openai-five-2019#^f2]], [[openai-five-2019#^f4]]
- C8: Reference ranked-LoL numbers: AUC 0.63 at 1-5 minutes to 0.91 at 26-30; 75.9% accuracy, ECE 0.9%; LR on gold diff alone about 73% at 10 minutes. for: [[jjzhao-lol-win-probability#^f5]], [[jalovaara-lol-wpa-items-2024#^f7]], [[jalovaara-lol-wpa-items-2024#^f15]], [[cmu-capstone-lol-wp-2024#^f4]], [[sbgames-2026-minute-win-prob#^f2]]
- C9 (inferred): Our recipe in the Answer. from: C1, C2, C3, C4, C5, C6

## Disagreements

- Sequences: a 2016 trend model beat LR before minute 20 (Yang, weak) vs no fair
  evidence elsewhere. A GRU challenger on our per-band log loss settles it.

## Open

- Calibration by minute band: not reported anywhere.
- Leads: Silva et al. 2018 (RNN on 7,621 pro LoL games, 63.9% to 83.5% by minute; full
  text not found); Ke et al. CoG 2022 (Dota team-fight sequence models).
