---
title: Learning Dota 2 Team Compositions (Agarwala and Pearce, Stanford CS229 2014)
url: https://cs229.stanford.edu/proj2014/Atish%20Agarwala,%20Michael%20Pearce,%20Learning%20Dota%202%20Team%20Compositions.pdf
kind: paper
commit:
for: [comp-attribute-features]
looked: 2026-10-13
depth: docs (whole paper)
relevance: high
grade: C/fair
description: Stanford CS229 student report; Dota 2 LR with hero-profile (PCA of pro average stats) within-team and cross-team second-order terms instead of hero ids; 57% vs 62% for ids, 40k games
---
# Learning Dota 2 Team Compositions (Agarwala and Pearce, Stanford CS229 2014)

Why: the closest Dota analogue of our plan: hero profiles from average end-of-game stats,
then within-team and cross-team interaction terms over those profiles.

## Assessment

- Evidence: C. Student project; 40,000 public games from one patch, mixed skill (skill
  filter broken in the API), random 90/10 split, d chosen on the test set.
- Reasoning: fair; reports a negative result honestly and reasons about why.
- Interests: none known.
- Weigh: small data and test-set tuning; the important part is the design (profiles
  replaced ids rather than adding to them) and the failure mode it explains.

## Findings

- [data] 40,000 matches from one patch (Oct to Dec 2014), All Pick and Captain's Mode, no
  leavers, mixed skill; hero profiles from about 1,500 pro games on DatDota. ^f1
  > We downloaded information on 40,000 matches in the
  > time period from 10/1/14 to 12/3/14.
  > Our match data contained a mix of low, middle, and high
  > level play which may have added noise to the data.
- [method] Hero profile: per-hero average pro stats (kills, deaths, assists, last hits,
  GPM, XPM, hero damage, tower damage, hero healing, damage taken, neutral gold...),
  standardised, then PCA. ^f2
  > We then ran PCA on the average statistics to derive vectors ~x of composite statistics for each hero.
- [method] [draft] 2nd Order PCA model: LR on team sums of PCA scores, plus cross-team
  products (antisymmetric) and within-team products of team sums; d=7 components. ^f3
  > Logistic regression on a second order polynomial of PCA scores.
  > This model gives some non-linear interaction terms while taking advantage of PCA to give dimen-
- [method] [draft] Sorted PCA model: heroes sorted by first PCA component (a late-game
  carry axis), then each slot compared with the enemy hero in the same slot, so it
  matches heroes playing similar roles. ^f4
  > the first PCA component roughly
  > corresponded to the strength of the hero in the late game.
  > it compares strengths of heroes with other heroes
  > who are likely playing similar roles.
- [method] Result on a random 10% hold-out: hero-id LR 62%; both profile models 57%. The
  profile models replaced ids, they did not add to them. ^f5
  > The full heroes model had a prediction accuracy of 62% while both PCA models had an accuracy of 57%.
- [method] [draft] Their reading: average stats lose per-hero strength, and heroes used
  in several roles average out; the id model wins because players already draft
  balanced teams, so marginal hero strength is what predicts. ^f6
  > much of the accuracy of the full heroes model comes
  > from the fact that players are usually choosing teams with reasonable hero balance
  > The PCA components are still missing specific information about each hero which
  > contribute to a hero's relative strength.
- [draft] The id model's best team stacks five high win rate heroes of the same role;
  the profile models' best teams look like balanced real drafts. So ids predict better,
  profiles recommend more plausibly. ^f7
  > The full heroes model leverages the imbalance of the game to make win predictions.
- [method] Planned but not done: ids plus profile interactions together. ^f8
  > We also plan on seeing if we can combine the best of both the full heroes model and our various
- [method] (inferred) For us: profile interactions must sit on top of per-champion
  ratings (residual terms), not replace them; and a profile-only recommender is a guard
  against stacking one role, a job the role-assigned draft already does in LoL. ^f9

## Read

- Whole paper (5 pages)

## Not read

- Nothing left
