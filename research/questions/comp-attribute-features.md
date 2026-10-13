---
status: answered
priority: soon
area: stats
tags: [method, draft]
description: Which team-composition features built from champion attributes (damage type mix and balance, frontline/tankiness, crowd control, range/poke vs engage, healing vs anti-heal, scaling) have measured, non-additive effects on win in LoL or Dota 2 data, how big, and how were they built?
---
# Which team-composition features built from champion attributes (damage type mix and balance, frontline/tankiness, crowd control, range/poke vs engage, healing vs anti-heal, scaling) have measured, non-additive effects on win in LoL or Dota 2 data, how big, and how were they built?

Feeds: comp features campaign (coordinator meiolol-2c; model agent meiolol-0d): which
champion-profile interactions to try on top of additive win ratings; docs/model.md.
Profiles come from src/lab/api.zig `SeatStat` (damage by type, taken by type, mitigated,
CC time, heals, shields, armour/MR at 15, attack range). A sum over a team is already
inside a logistic per-champion model; only non-additive within-team terms, cross-team
interactions and profile priors can add.

## Answer

Almost nothing is measured where it matters: no LoL or Dota study tested
champion-attribute composition terms on top of champion ids against an ids-only
baseline on held-out games (C2). The one direct test of profile interactions *instead*
of ids lost by 5 points (Dota, 40k games, average pro end-of-game stats compressed by
PCA, within- and cross-team second-order terms: 57% vs 62%), because averages drop each
hero's own strength and players already draft balanced teams (C1). So profile terms
must be residuals on top of per-champion ratings (C9).

Measured composition effects, all raw and without a champion baseline: in LoL, iTero's
1M+ solo games show teams at 20-80% AD damage at ~50%, under 20% AD ~41% and over 80%
~44%, with few games at the extremes and no word on whether AD share is champion
averages or realised damage (C3). That is the only measurement of a "mixed damage"
penalty; its stated mechanism (tanks stack one resist) is asserted, and no armour vs MR
or "Rammus into AP" interaction is measured anywhere (C4). "No frontline" is folklore
in LoL; Honor of Kings, where roles are free, has large raw role-mix effects (8-54% win)
concentrated in rare degenerate teams, and pairwise role terms carry almost all the
prediction gain (+0.9-1.6 pp over player info, 3-5-way terms add nothing) (C5, C6).
Coarse class tags alone predict at chance (C7). Class-based priors help only with
little data (C8). CC totals, range/poke vs engage, healing vs anti-heal and scaling:
no measurement found in either game (C2).

Power at our size (C10): a standardised interaction is detectable from ~0.36 pp per SD
at 150k games by coefficient z, a 10% prevalence flag from ~1.2 pp, but a dev log loss
gain above +-0.0005 needs ~1.6 pp per SD; interactions need ~16x the data of a main
effect and significant low-power estimates overstate ~3x. Ranked for 100-200k games
(C11): (1) damage-type imbalance hinge within team, (2) my damage concentration x
enemy tankiness or resist lean, (3) a profile prior for rare champion-roles, (4) a
no-frontline flag, (5) CC flag or my CC x enemy mobility; skip heal vs anti-heal
(item-side), poke vs engage, scaling (a team sum is additive). Sources searched: 3+
angles each, discovery curve slowing (last searches found nothing new).

## Claims

- C1: Dota hero-profile interaction terms (PCA of average pro stats, within and cross team) used instead of hero ids predicted worse on a random hold-out: 57% vs 62%. for: [[agarwala-pearce-2014#^f5]], [[agarwala-pearce-2014#^f6]]
- C2: No LoL or non-LoL study measured attribute, role or class features on top of champion ids against an ids-only baseline on held-out data; none measured CC, poke/engage, heal/anti-heal or scaling terms. for: [[agarwala-pearce-2014#^f8]], [[viggiato-trouncing-2020#^f7]], [[hok-team-composition-2019#^f7]], [[cram678-comp-winrate#^f7]], [[itero-draft-sq#^f8]]
- C3: LoL solo queue raw win rate dips outside 20-80% team AD damage share, AP-heavy worse (about -9 and -6 pp read off a chart), with no counts, champion control or definition of the share. for: [[itero-draft-sq#^f2]], [[itero-draft-sq#^f3]], [[itero-draft-sq#^f4]], [[itero-draft-sq#^f8]]
- C4: The resist-stacking mechanism for the damage-mix penalty is asserted, not measured; no armour vs MR interaction measured. for: [[itero-draft-sq#^f5]], [[itero-draft-sq#^f6]]
- C5: With free role choice, role composition has large raw effects (8.3-53.6% win) concentrated in rare degenerate comps; more distinct roles win more. for: [[hok-team-composition-2019#^f2]], [[hok-team-composition-2019#^f3]]
- C6: Role composition adds 0.9-1.6 pp accuracy over player info (no hero-id baseline); two-role combinations capture almost all of it. for: [[hok-team-composition-2019#^f5]], [[hok-team-composition-2019#^f6]]
- C7: Coarse class tags alone predict LoL wins at about chance (0.515). for: [[cram678-comp-winrate#^f5]], [[cram678-comp-winrate#^f4]], [[bcappu-high-elo-draft#^f5]]
- C8: Class-based priors help a champion model only with little data. for: [[loldraftai#^f14]]
- C9 (inferred): Fit profile terms as residuals on top of per-champion ratings, second order at most. from: C1, C6
- C10: Interactions need about 16x the sample of a main effect; significant low-power estimates overstate about 3x. for: [[gelman-interactions-16x#^f1]], [[gelman-interactions-16x#^f3]], [[gelman-interactions-16x#^f4]]
- C11 (inferred): Rank for 100-200k LoL games: damage imbalance hinge, damage x enemy tankiness/resist lean, profile prior, no-frontline flag, CC terms; skip heal, poke, scaling. from: C3, C4, C5, C8, C9, C10

## Disagreements

- Damage-mix size: iTero's raw -6 to -9 pp (C, vendor, unadjusted) against no adjusted
  measurement at all. Confounding (off-meta, autofill, troll picks make one-type comps)
  would inflate it. Settled by our own hinge term on top of ratings, from profile
  averages.
- Profiles vs ids: Agarwala (C) replaced ids and lost; Honor of Kings (B) found role
  terms useful but had no id baseline. Not in conflict: both point to residual terms.

## Open

- Our own measurement (meiolol-0d [b5e038], src/lab/cand/win-comp): adjusted effect
  of each ranked term on dev, in pp per SD with its SE.
- Bucket counts for extreme AD share in our data (how rare is <20% or >80%).
- Leads: Mobalytics archetype method, BanPickMaker thesis, Ask Riot 2019 damage types,
  SBGames 2017, UNESP CISTI 2017, Semenov 2016 role counts (paywalled).
