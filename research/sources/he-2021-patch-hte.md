---
title: Heterogeneous Effects of Software Patches in a Multiplayer Online Battle Arena Game (He, Tran, Jiang, Burghardt, Ferrara, Zheleva, Lerman, 2021)
url: https://arxiv.org/pdf/2110.14632v1
kind: paper
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: listed (whole paper)
relevance: medium
grade: C/weak
description: arXiv preprint (USC ISI, UIC): LoL patches as treatments, before vs after a patch as control vs treated, causal trees for heterogeneous effects on win and kills; 437k matches 2014-16
---
# Heterogeneous Effects of Software Patches in a MOBA Game (He et al. 2021)

Why: the only LoL paper found that frames a patch as a causal treatment; does a
before/after patch design identify a champion's change in strength?

## Assessment

- Evidence: C. Preprint, 437k matches from 2014-16 (Sapienza dataset), top 25 champions,
  causal trees per patch with per-node t-tests, no correction for the many nodes tested,
  no held-out check of effects.
- Reasoning: weak. Calls before/after "as-if random" yet itself notes players change
  what they pick after a patch; reported subgroup effects (18-23 points) are far beyond
  anything a draft can plausibly move.
- Interests: none known (academic).
- Weigh: useful as a cautionary example and for the framing (patch = treatment), not
  for its numbers.

## Findings

- [method/causal] Design: matches just before a patch are the control and matches just
  after the treated, with the authors assuming players fall into each group as if at
  random. ^f1
  > treating the matches that take place before and immediately after a patch
  > users are as-if randomly selected to each group
- [method/causal] They name both biases that matter for us: which champions get changed
  is not random (confounding) and not all players play the same champions (selection).
  ^f2
  > Not all champions are selected to be buffed or nerfed in a single patch (confounding), and not all players play the
- [method/causal] [stats] Reported subgroup effects are implausibly large and only
  t-tested per node: Lucian plus Nami +18%, Jhin plus Fiora +23%. ^f3
  > if Nami is also on the team, the win rate significantly increases by 18%
  > if the team has Fiora in addition to Jhin, the win rate goes up significantly by 23%
- [method/causal] Win rates of champions sharing a role move against each other across
  patches (Lucian and Vayne r = -0.46): a champion's measured win rate depends on what
  its usual opponents are, so a patch to others moves it. ^f4
  > the win rates of Lucian and Vayne are negatively correlated (𝑟 = −0.46, 𝑝 = 0.0002)
- [method/causal] They concede the before/after split is not random: players change
  picks after buffs and nerfs, so selection into a champion shifts at the patch. ^f5
  > Not only is there a potential selection bias, however,
- [method/causal] (inferred) A patch discontinuity identifies the change in "champion as
  played by whoever picks it now", not the change in kit power: after a buff new and
  returning players flock in and dilute mastery, after a nerf only mains stay. To read
  kit power, condition on the picker (mastery, games on the champion) or follow the same
  players across the patch. ^f6

## Read

- Whole paper (abstract, methods, results, discussion).
