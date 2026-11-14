---
title: 'Yancey and Settles 2020: A Sleeping, Recovering Bandit Algorithm for Optimizing Recurring Notifications (KDD)'
url: https://research.duolingo.com/papers/yancey.kdd20.pdf
kind: paper
commit: 
for: [stat-site-retention]
looked: 2026-11-14
depth: skimmed (abstract, sections 1-3, online results)
relevance: medium
grade: A/strong
description: Duolingo's KDD 2020 paper on choosing daily reminder templates; online A/B on millions of reminders, novelty decay of repeated messages
---
# Yancey and Settles 2020: A Sleeping, Recovering Bandit Algorithm for Optimizing Recurring Notifications (KDD)

Why: how big is the effect of a well-run recurring reminder, and what wears it out?

## Assessment

- Evidence: A. Peer-reviewed KDD paper, offline replay on 200M+ reminders and an online
  A/B test at Duolingo scale (300M users).
- Reasoning: strong. Explains the novelty and eligibility problems, alternatives tried.
- Interests: Duolingo's own team reporting its own system.
- Weigh: effects are on top of an already tuned reminder system, so small; the baseline
  value of having a daily reminder at all is not measured here.

## Findings

- [retention] Choosing reminder wording better raised daily active users 0.5% and new
  user retention 2% over a strong baseline. ^f1
  > crease in total daily active users (DAUs) and a 2 % increase in new
- [retention] Repeating the same message wears it out; a template not seen recently
  works better (novelty effect), so the system penalises recent repeats. ^f2
  > We surmised that this was due to a kind of “novelty effect”: tem-
- [retention] Many apps rely on daily emails and push notifications to keep users
  engaged. ^f3
  > notifications to increase and maintain user engagement. The multi-
- [retention] (inferred) For meio.lol: a reminder's lift comes from fresh, relevant
  content each time; a weekly message about the player's own new games is naturally
  fresh, a fixed "come back" line is not. ^f4

## Read

- Abstract, introduction, the novelty and eligibility sections, offline and online
  results (two-column text; quotes taken from single-column lines).

## Not read

- Appendix on production architecture.
