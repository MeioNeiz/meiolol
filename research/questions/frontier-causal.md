---
status: answered
priority: soon
area: stats
parent: frontier-experiments
tags: [method/causal, stats, data]
description: How do pick selection and counter-pick response bias champion and matchup win rates in MOBA data, and which causal methods (double ML, pick-order or blind-pick natural experiments, propensity) estimate effects under it?
---
# How do pick selection and counter-pick response bias champion and matchup win rates in MOBA data, and which causal methods (double ML, pick-order or blind-pick natural experiments, propensity) estimate effects under it?

Feeds: docs/plan/lab-frontier.md (gpu-box experiment programme), parent [[frontier-experiments]]

## Answer

Nobody publishes a causal champion or matchup win rate for LoL. Riot's balance team
uses raw win rate by skill bracket, tightened by ban rate. It leaves mastery out on
purpose, as a policy choice, and trusts pick rate only at the very top (C1). A
champion's win rate is a mix over who picks it. About 30-40% of a champion's games are
a player's first 15 on it, and the gap between new and practised players is large
(Rengar 39% vs 51% in our data). Yet mains move the aggregate by at most about 0.4
points, because failing first-timers offset them (C2). The selection that matters for
one player is on mastery and skill, and it is mostly observed: we have each player's
mastery, and the within-pool expertise effect (3.7 points from 10k to 300k) is already
measured (C3). Choices also respond to results: players drop a champion after a loss,
and pick differently after patches (C4).

Counter-pick response can't be measured from our data. Match-v5 has no pick order:
participants are sorted by role, and ban pickTurn is a slot index. The LCU session the
app reads does have the turn order (C5). Dota data shows win rate varies by pick phase,
partly because only confident specialists pick early (C6). Three searches found no
measured LoL estimate of how much of a matchup win rate is counter-pick selection.
Additive centring (matchup minus both sides' strength), used by us, lolalytics and
Counterwatch, removes strength but not selection (C7).

Methods, best fit first (C13): (1) condition on observed confounders, the seat's
mastery and rank, with within-player comparisons; (2) double ML when the confounder set
is large (rest of draft, ranks, patch), knowing it fixes only regularisation bias and
not unobserved skill (C8); (3) inverse propensity or doubly robust off-policy
evaluation, to ask whether following the lane card wins more, not just whether it
predicts the pick (C9); (4) natural experiments. ARAM's first roll is a uniform draw from
the player's pool; Swiftplay fixes champions before the opponents are known; Dota's
Single Draft served as a (weak) instrument (C10). Patch and hotfix cutoffs identify
"champion as now picked", a compound of kit change and pick response; RD-in-time
checks (picker-mastery continuity, placebo champions, donut) and within-player
comparisons separate them (C11). Dodges (19% of lobbies before 2026, 4% now) and
autofill now matter less (C12).

## Claims

- C1: Riot's balance signal is raw win rate within skill brackets, tightened by ban rate; mastery curves are excluded as policy and pick rate is trusted only at the top; no adjusted win rate added by 2020. for: [[riot-champ-balance-framework-2019#^f1]], [[riot-champ-balance-framework-2019#^f2]], [[riot-champ-balance-framework-2019#^f3]], [[riot-balance-framework-update#^f3]], [[riot-balance-framework-update#^f4]], [[phroxzon-interview-2023#^f4]]
- C2: A champion's win rate mixes its pickers' mastery: many games are early ones, the per-player gap is large for some champions, yet the net effect of mains on the aggregate is at most about 0.4 points. for: [[phroxzon-interview-2023#^f1]], [[phroxzon-interview-2023#^f2]], [[meiolol-learned-player#^f2]], [[riot-champ-balance-framework-2019#^f3]], [[tudelft-dota-iv-poster#^f2]]
- C3: Mastery on the champion is a real within-player effect (3.7 points, 10k to 300k) and is the main observed confounder; confident early pickers win more for that reason. for: [[meiolol-learned-player#^f1]], [[stratz-pick-phase-2017#^f2]]
- C4: Picks respond to outcomes: players drop a champion after a loss and change picks after buffs and nerfs; new champions' early win rates reflect learning, not power. for: [[meiolol-learned-player#^f3]], [[he-2021-patch-hte#^f5]], [[riot-champ-balance-framework-2019#^f4]]
- C5: Match-v5 carries no pick order (role-sorted participants, slot-index ban pickTurn); the LCU champ select session has the turns. for: [[meiolol-pick-order-check#^f1]], [[meiolol-pick-order-check#^f2]], [[meiolol-pick-order-check#^f3]], [[meiolol-pick-order-check#^f4]]
- C6: Where pick order is recorded (Dota pubs), hero win rate varies by pick phase, read as both counter response and picker confidence. for: [[stratz-pick-phase-2017#^f1]], [[stratz-pick-phase-2017#^f2]]
- C7: Matchup tables centre on both sides' overall strength; this removes strength, and Counterwatch notes context selection and swap-out survivorship that centring does not fix. for: [[stratz-pick-phase-2017#^f3]], [[counterwatch-method#^f1]], [[counterwatch-method#^f3]], [[counterwatch-method#^f4]]
- C8: Double ML (orthogonal scores, cross-fitting) removes regularisation and overfitting bias from ML-adjusted effects but needs unconfoundedness; without it the result is an average predictive effect. for: [[chernozhukov-2018-dml#^f1]], [[chernozhukov-2018-dml#^f3]], [[chernozhukov-2018-dml#^f5]]
- C9: Inverse-propensity (IPS, SNIPS) estimators evaluate a recommender without bias on self-selected data; estimated propensities need only beat uniform. for: [[schnabel-2016-recs-treatments#^f2]], [[schnabel-2016-recs-treatments#^f3]]
- C10: Random or blind assignment exists: ARAM's first roll is uniform over the player's available champions (rerolls and bench swaps add choice); Swiftplay fixes champions before matching; Dota Single Draft served as an instrument, moving Meepo from 53.7% to 47.2%. for: [[ask-riot-aram-random#^f1]], [[ask-riot-aram-random#^f2]], [[ask-riot-aram-random#^f3]], [[lolwiki-swiftplay#^f1]], [[lolwiki-swiftplay#^f3]], [[tudelft-dota-iv-poster#^f1]], [[tudelft-dota-iv-poster#^f2]]
- C11: A patch cutoff estimates a compound of the change and behavioural response (untestable sorting); checks are covariate continuity, placebos and donut windows; the one LoL patch study assumed as-if random and found implausible 18-23 point subgroup effects. for: [[hausman-rapson-2018-rdit#^f2]], [[hausman-rapson-2018-rdit#^f3]], [[hausman-rapson-2018-rdit#^f4]], [[he-2021-patch-hte#^f1]], [[he-2021-patch-hte#^f3]]
- C12: Dodged lobbies fell from 19% to 4% and role-parity matching made autofill-vs-main rare, so both now distort played drafts little. for: [[ugg-dodge-rate-2026#^f1]], [[ugg-dodge-rate-2026#^f2]]
- C13 (inferred): Order for us: observed confounders (mastery, rank) and within-player first, DML for wide confounder sets, off-policy value for the lane card, natural experiments to test what remains. from: C2, C3, C5, C8, C9, C10, C11

## Disagreements

- "Mains inflate win rates": Phroxzon (B) says net at most 0.4 points; our data (A) and
  the Meepo IV poster (D) show large per-player gaps. Not a conflict: different
  estimands (aggregate shift vs win chance at a given mastery). A recommender needs the
  second.
- Counter-pick value: coaching sources put the last pick's edge at "3-5%" with no data;
  no source measures it. Settles only with pick order (app users' LCU turns) or a
  blind-vs-draft comparison.

## Open

- Size of counter-pick selection in LoL matchup terms: unmeasured anywhere.
- Is Swiftplay (480) served by match-v5 now? Decides whether the blind comparison is possible.
- How much choice leaks into the final ARAM champion (rerolls, bench): measurable as
  mastery on the played champion against a uniform draw from the player's pool.
- Leads: two TU Delft theses on Dota causal inference (All Random data, g-formula with
  skill); Aalto thesis on pick rate vs win rate (hosts unreachable 21 Oct).
