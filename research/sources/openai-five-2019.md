---
title: 'Berner et al. 2019: Dota 2 with large scale deep reinforcement learning (OpenAI Five), win probability head'
url: https://arxiv.org/pdf/1912.06680
kind: paper
commit: 
for: [live-win-probability]
looked: 2026-10-13
depth: docs (appendix D auxiliary predictions, D.1, appendix on hero selection)
relevance: medium
grade: A/fair
description: OpenAI Five paper; an auxiliary win probability head on the agent's LSTM, trained with bootstrapped (TD-style) labels per 30-second segment; the same head at game start doubles as the draft evaluator
---
# Berner et al. 2019: Dota 2 with large scale deep reinforcement learning (OpenAI Five), win probability head

Why: the best-resourced sequence model with a live win probability output; how its
target was set and how the draft sits in the same model.

## Assessment

- Evidence: A for the system (canonical, huge compute); the win probability head is a
  side output, shown on one game, with no held-out accuracy or calibration numbers.
- Reasoning: fair. The labelling trick is explained; "a degree of calibration" is
  asserted, not measured.
- Interests: OpenAI showcasing its agent.
- Weigh: borrow the ideas (bootstrapped labels; one model whose t=0 output is the draft
  prediction); trust no numbers, there are none for humans' games.

## Findings

- [method] Win probability is a small fully connected head on the agent's LSTM state,
  i.e. a sequence model over the whole game so far. Appendix D ^f1
  > We added small networks of fully-connected layers that transform LSTM output into predictions of these values.
- [method] Labels are bootstrapped like a value function: on a game's last segment the
  true result, otherwise the model's own prediction at the end of the segment (a
  temporal-difference target). Appendix D ^f2
  > If a segment contains the ground truth label, we use the ground truth label for all time steps in that segment; if not, we use the model’s prediction at the end of the segment as the label.
- [stats] Calibration only asserted, not measured. Appendix D ^f3
  > we find it trains these heads to a degree of calibration and accuracy.
- [method] [draft] The same head at game start, when the heroes are the only varying
  input, is the draft evaluator: the model's t=0 output is its draft win chance.
  Appendix on hero selection ^f4
  > Because the main varying observation that agents see at the start of the game is which heroes are on each team, the win probability at the start of the game estimates the strength of a given matchup.
- [method] Shown on one game: drops on losing three heroes at about minute 5, 95% after
  a three-kill fight at about minute 18. Figure 9 ^f5
  > marched on declaring 95% probability of victory.
- [data] Self-play agents, 17-hero pool; nothing about human ranked games. ^f6
  > Because there are only 4,900,896 combinations of two 5-hero teams from the pool of 17 heroes
- [method] (inferred) Two ideas we can use: (1) a TD-style target (fit minute t towards
  the model's own minute t+1 prediction, the real result at the end) cuts the variance
  of training on final outcomes from early frames; (2) one model with the draft as the
  t=0 input, so its minute-0 output equals a draft model and the draft's weight by
  minute is learnt, not set. ^f7

## Read

- Appendix D (auxiliary predictions), D.1 (finals game), hero selection appendix

## Not read

- Everything about RL training, surgery, scale; skipped earlier for the draft question
