---
title: "Kim, Reinecke, Hullman (CHI 2017): Explaining the Gap: Visualizing One's Predictions Improves Recall and Comprehension of Data"
url: https://mucollective.northwestern.edu/files/2017-ExplainingTheGap-CHI.pdf
kind: paper
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: skimmed (abstract, results, discussion)
relevance: medium
grade: A/strong
description: CHI 2017 best paper: controlled Mechanical Turk experiments (378 participants, 9 conditions) showing that asking viewers to predict data before seeing it, then showing the gap, improves recall and comprehension
---
# Kim, Reinecke, Hullman (CHI 2017): Explaining the Gap

Why: evidence on what makes data engaging and memorable rather than dry, beyond
opinion pieces.

## Assessment

- Evidence: A. Peer-reviewed CHI best paper, preregistered power analysis (0.8 power,
  42 per condition), mixed models; Hullman is a leading uncertainty-vis researcher.
- Reasoning: strong. Hypotheses stated up front, text vs visual compared, limits
  (dataset familiarity) discussed.
- Interests: none.
- Weigh: effects are a few points of recall error on simple charts; engagement is the
  authors' interpretation, recall and comprehension are what was measured.

## Findings

- [ux/features] Predicting (and self-explaining) before seeing the data beat a control
  group on recall and comprehension, also for people with little prior knowledge.
  Abstract ^f1
  > We find that participants who are prompted to reflect on their prior knowledge by predicting and self-explaining data outperform a control group in recall and comprehension.
- [ux/features] Size of effect: Predict-Explain recalled each value about 4 points (out
  of 100) closer than the control. Results ^f2
  > more accurate at recalling the voting percentage by 4.08% out of 100%
- [ux/features] (claim) Prediction engages curiosity; once a user has invested attention
  they are open to feedback. Discussion ^f3
  > first prompting a user to make predictions is likely to engage a user’s curiosity.
- [ux/features] (claim) Personalisation: showing the user's own region first may
  increase engagement while giving context. Design space ^f4
  > identifying and initially presenting marks depicting the user’s region based on their IP address may increase engagement while providing useful context for the user.
- [ux/features] Predicting only a few points still lowered recall error across all
  points. Discussion ^f5
  > a designer need not require a user to predict every data point in the visualization to engage users with the entire dataset.
- [ux/features] (inferred) For meio.lol: "guess your matchup win rate, then see it" or
  the user's own champion first are evidence-backed engagement forms, cheaper than prose.
  ^f6

## Read

- Abstract, intro, results (visual conditions), discussion and design space

## Not read

- Text-condition results in detail, supplementary materials
