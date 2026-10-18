---
status: answered
priority: soon
area: stats
tags: [method, stats, draft]
description: How should champion-into-comp effects at several levels (team damage mix, kit groups, per-champion leans, pair and matchup terms) be combined in one additive draft model without double counting, so each part stays a nameable reason?
---
# How should champion-into-comp effects at several levels (team damage mix, kit groups, per-champion leans, pair and matchup terms) be combined in one additive draft model without double counting, so each part stays a nameable reason?

Feeds: how champgroups' kit groups (docs/model.md "Kit groups and a property scan") get
into the admin Draft tester's champion-into-comp terms (draft-comp.json, docs/model.md
"Champions into comps"), and later the champion-page and suggest reasons (docs/plan.md
"Where the app goes next" steps 2-3).

Context (18 Oct): the shipped model (score.zig) has champion strength, ally pairs,
matchups and a team damage-mix term; champcomp adds per-champion-role slopes on 16
enemy and ally traits, shrunk to 0 by empirical Bayes (only Q-test roles keep spread).
champgroups found six kit groups (lists of champions by kit, one shared slope on one
enemy trait) that also show in some members' own champcomp slopes, plus a new trait
(enemy auto-attack build) champcomp lacks. Adding the group terms on top double counts;
a kit prior on a build stat (armour lean) was tried as the shrinkage target and did not
predict better (docs/model.md "Armour tanks into AD").

## Answer

Use the standard multilevel form with group-level predictors (C1): a champion-role's
slope on an enemy trait is drawn around its role's mean plus the coefficients of every
kit group it belongs to, so the champion part is only its deviation from what role and
groups predict, and nothing is counted twice. Fit it in one penalised logistic pass
(penalised IRLS, one variance per role re-estimated between passes, no MCMC; C4), with
group coefficients updated jointly with their members' slopes, as alternating updates
converge slowly and leaving out the member level makes group se far too small (C5).
Every membership counts: a champion in two groups on one trait is in both (C7). Equal
fixed priors on id and attribute columns split credit by the prior ratio, so each
level's variance must be estimated (C8). For naming, centre each champion's part,
seat-weighted, against its role and memberships after the fit; predictions don't move
and role, group and champion parts become unique and add up (C6, C10).

What to expect: shrinking towards what attributes predict beats shrinking to zero out
of sample in recommenders and plus-minus (C2), but the gain sits in thin and new units
and fades with data (C3); a group level adds little where it explains little of the
spread or the unit level is near full pooling (C9, contested; our own armour-lean kit
prior was real but did not predict better). So measure on member seats only (paired
held-out log loss there), leave-one-member-out (does the group without a champion
predict that champion's held-out slope better than the role mean), the drop in tau per
role, a shuffled-membership control and a planted check that the parts sum back.

## Claims

- C1: The standard way to combine group and unit levels of a slope: unit slope ~ N(role mean + sum of group coefficients x membership, tau^2), fitted as cross-level interactions plus random slopes; the unit part is then only its deviation from what role and groups predict. for: [[gelman-hill-2007-ch12-13#^f4]], [[gelman-hill-2007-ch12-13#^f1]], [[gelman-2006-multilevel-can-cant#^f2]], [[agarwal-chen-2009-rlfm#^f2]], [[matano-2018-augmented-apm#^f2]]
- C2: Shrinking towards an attribute prediction beat both shrinkage to zero and attributes alone out of sample, in recommenders and plus-minus. for: [[agarwal-chen-2009-rlfm#^f7]], [[agarwal-chen-2009-rlfm#^f9]], [[matano-2018-augmented-apm#^f4]], [[gelman-2006-multilevel-can-cant#^f4]]
- C3: The gain sits in thin and unseen units and fades as data per unit grows. for: [[agarwal-chen-2009-rlfm#^f8]], [[matano-2018-augmented-apm#^f5]], [[pelechrinis-2026-lrapm#^f4]], [[pelechrinis-2026-lrapm#^f5]], [[gelman-2006-multilevel-can-cant#^f5]]
- C4: Logistic models with several random-effect groups fit without MCMC: penalised IRLS, one penalty per group, an EM or Schall variance update, O(N) per iteration. for: [[ghosh-2022-logistic-crossed-re#^f1]], [[ghosh-2022-logistic-crossed-re#^f2]], [[ghosh-2022-logistic-crossed-re#^f3]], [[ghosh-2022-logistic-crossed-re#^f7]], [[agarwal-chen-2009-rlfm#^f6]]
- C5: Group-level coefficients above unit random effects must be updated jointly with them; leaving the unit level out makes their se far too small. for: [[ghosh-2022-logistic-crossed-re#^f5]], [[ghosh-2022-logistic-crossed-re#^f6]], [[ghosh-2022-logistic-crossed-re#^f9]]
- C6: Coarse and nested parts are identifiable only under a centring rule (functional ANOVA, data-weighted), which can be applied after fitting without changing predictions; the weights matter. for: [[lengerich-2020-purification#^f1]], [[lengerich-2020-purification#^f4]], [[lengerich-2020-purification#^f5]], [[lengerich-2020-purification#^f6]], [[devlin-2020-nba-lineup-spectral#^f2]]
- C7: With overlapping groups every membership must be modelled, or the group variance is understated. for: [[leckie-2019-multiple-membership#^f2]], [[leckie-2019-multiple-membership#^f3]]
- C8: Id and attribute columns side by side under fixed equal priors split credit by the prior ratio, not the data; each level's variance has to be estimated. for: [[stern-2009-matchbox#^f2]], [[stern-2009-matchbox#^f6]], [[ghosh-2022-logistic-crossed-re#^f3]]
- C9: A group level adds little when it explains little of the between-unit spread or the unit level is already near full pooling. for: [[gelman-hill-2007-ch12-13#^f5]], [[gelman-hill-2007-ch12-13#^f7]], [[agarwal-chen-2009-rlfm#^f9]]
- C10 (inferred): For meiolol: one penalised logistic fit of trait + role:trait + group:trait (wide prior) + champion-role:trait slopes with a variance per role estimated in the fit, then each champion's part projected seat-weighted orthogonal to its role and memberships, so role, group and champion reasons sum to the total. from: C1, C4, C5, C6, C7

## Disagreements

## Open

- In house: docs/model.md "Armour tanks into AD" (a build-stat group prior, real but no
  log-loss gain) is the local case for C9; kit lists are a different prior, untested
- Leads not read: GRridge (group-specific ridge penalties), Pilaszy and Tikk 2009 (a few
  ratings beat metadata: the critic's case)

- Statistician: hierarchical / multilevel options for the same slope at three levels
  (role, kit group, champion): nested or crossed random slopes, group-level predictors
  in the shrinkage target (Gelman-Hill style), champion in several groups at once;
  how others fit them at scale (millions of rows) without full Bayes
- Several correlated traits per champion (AP share, tank, CC...): fit jointly or one at
  a time; when does a joint fit split one effect across traits, and how is a part named
- Practitioner: how sports and esports models combine team-style terms with player or
  pair terms (hockey and basketball plus-minus with attribute priors, Dota/LoL draft
  models with hero attributes, recommender systems with side features: hybrid matrix
  factorisation, "attribute-aware" embeddings)
- Explainability: keeping parts additive so a reason's number is its share of the total
  (GA2M, purification of interaction terms, Shapley for grouped terms)
- Critic: when does the group level add nothing (shrinkage target already right),
  how to measure it (paired held-out log loss, as the lab does), and what plants to use
- What would change the answer: a method that measurably beats per-champion shrinkage
  to 0 on held-out games in a comparable setting
