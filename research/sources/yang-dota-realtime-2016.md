---
title: 'Yang, Qin, Lei 2016: Real-time eSports match result prediction (Dota 2)'
url: https://arxiv.org/pdf/1701.03162
kind: paper
commit: 
for: [live-win-probability]
looked: 2026-10-13
depth: docs (whole paper)
relevance: high
grade: C/fair
description: CMU 2016 workshop paper (NIPS 2016 format); Dota 2 win prediction from prior (hero, player MMR, player-on-hero history) plus per-minute gold, XP and deaths diffs, combined by stacking or concatenation; accuracy by minute
---
# Yang, Qin, Lei 2016: Real-time eSports match result prediction (Dota 2)

Why: the earliest paper that combines a pre-game model with per-minute state and shows
the pre-game part fading by minute; also tests one model across minutes vs one per
minute.

## Assessment

- Evidence: C. Student workshop paper; 78k matches (20.6k with per-minute data), very
  high skill public games; accuracy only, read off a figure; no calibration or log
  loss; random 9:1 split by match.
- Reasoning: fair. Explains each design choice and admits ASM's independence and
  bigram assumptions; does not note that accuracy at minute t is over games still
  running at t (survivorship).
- Interests: none.
- Weigh: trust the shapes (prior fades, per-minute models beat one pooled model);
  the absolute numbers (93.73% at minute 40) are not comparable to ours.

## Findings

- [data] Data: 78,362 very high skill Dota 2 matches from the API, 20,631 with
  per-minute replay data (gold, XP, deaths per player). Section 3 ^f1
  > we use Dota 2 API3 to crawl 78362 matches participated by 19790 players with ‘very high’ skill level4
  > only 20631 out of 78362 matches contain gameplay information in our dataset.
- [method] State features are only team-mean gold, XP and deaths, as Radiant minus Dire
  per minute; a 5-minute window of them feeds the model at minute t. Sections 4.2, 5.2 ^f2
  > Each team’s real-time information can be represented by averaging the five players’ gold, experience and deaths at each minute.
  > When making a prediction at time t, we feed time-series data at time t − 5, t − 4, ..., t − 1 as features into the LR.
- [method] [draft] Pre-game side: hero one-hot (226), hero attributes, hero-vs-hero win
  rates, player MMR and player-on-hero history; player-on-hero history alone gives
  69.90%, heroes alone about 60%, all 71.49%. Table 2 ^f3
  > hero-player combined feature is the single most informative feature, achieving 69.90% prediction accuracy by itself.
- [method] Two ways to add the pre-game model: concatenate prior features with the
  window into one LR, or stack: a new LR over the prior LR's output and the state
  model's output. Section 5.3 ^f4
  > In method 1, we concatenate the 5-minutes-window time-series features with prior features and train a LR. In method 2 we train a new LR on top of the output of prior LR (Yp ) and the output of the real-time ASM model (Yr ).
- [method] [draft] The prior's added value fades by minute: the gap between state-only
  and state-plus-prior models shrinks over the game; state-only models pass prior-only
  after about 15 minutes. Section 6.2, Figure 6 ^f5
  > all four real-time models (blue lines and red lines) achieve better accuracy when fed with real-time information longer than 15 minutes.
  > Notice that the gap between blue solid line and blue dashed line is diminishing.
  > Prior features lose prediction power as match lasts longer.
- [method] Headline 93.73% at minute 40 vs 69% for prior only at minute 40; the
  minute-40 set is only games still running then. Section 6.2 ^f6
  > When predicting at the 40th minutes, accuracy achieves as high as 93.73%, in spark contrast to the 69% accuracy when we only use prior feature to predict at the 40th minute (Figure 7).
- [method] A sequence model of the trend (their ASM, a discrete transition model per
  outcome) beat LR on the current window before 20 minutes, when teams are close.
  Section 6.2 ^f7
  > The ASM approach (blue solid) performs better than LR (red solid) when using real-time features less than 20 minutes.
- [method] One LR per minute window beat one LR pooled over all minutes: the same gold
  lead means different things at minute 10 and 40. Section 7.2, Figure 8 ^f8
  > For example, gaining 1000 gold from 35 minute to 40 minute have different effect comparing to that from 5 minute to 10 minute.
  > Figure 8 shows that this time-specific model (Blue solid line) outperforms previous LR (Red solid line) in most time.
- [stats] Pre-game-only accuracy drops with game length: under 65% for games over 55
  minutes. Section 7.1 ^f9
  > For matches longer than 55 minutes, only less than 65% accuracy is achieved.
- [data] Split: random 9:1 by match, player history statistics computed without test
  matches; so frames of one game never cross the split. Section 6 ^f10
  > We split matches into training and testing dataset with ratio of 9:1.
  > When obtaining statistics from match history, we exclude matches in the test dataset.
- [stats] Checked, not there: no log loss, AUC, Brier or calibration; numbers by
  minute only in a figure. ^f11
- [method] (inferred) For us: time must interact with every state feature (minute as
  a GBDT feature does this; for a linear model, per-minute-band fits), and stacking a
  frozen draft model's logit as one feature is a cheap, tested way to add the draft. ^f12

## Read

- Whole paper (9 pages)
