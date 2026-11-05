---
title: Kingman's formula (Wikipedia)
url: https://en.wikipedia.org/wiki/Kingman%27s_formula
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole page)
relevance: medium
grade: B/fair
description: Encyclopaedia entry for Kingman's G/G/1 waiting time approximation (VUT equation), most accurate near saturation
---
# Kingman's formula (Wikipedia)

Why: a second reference for the waiting time approximation and when it holds.

## Assessment

- Evidence: B. Encyclopaedia restating Kingman (1961), with the original cited
- Reasoning: fair. Statement only, no derivation; the formula image didn't snapshot
  (the variables are defined in text)
- Interests: none
- Weigh: use for the statement and "accurate near saturation"; the formula itself is
  quoted in harchol-balter-practitioner-queueing

## Findings

- [devflow/agents] Kingman's formula (VUT equation) approximates mean waiting time in a
  G/G/1 queue as a product of utilisation, variability and service time terms. ^f1
  > Kingman's formula, also known as the VUT equation, is an approximation for the mean waiting time in a G/G/1 queue.
  > The formula is the product of three terms which depend on utilization (U), variability (V) and service time (T).
- [devflow/agents] It is most accurate close to saturation (from Kingman's 1961 heavy
  traffic paper), the regime where waits explode. ^f2
  > It is known to be generally very accurate, especially for a system operating close to saturation.
- [devflow/agents] Variables: rho = lambda/mu is utilisation, ca and cs the coefficients
  of variation of inter-arrival and service times. ^f3
  > is the utilization, _ca_ is the coefficient of variation for arrivals
- [devflow/agents] Checked, not there: no multiserver (G/G/c, M/M/c) form on this page.
  ^f4

## Read

- whole page
