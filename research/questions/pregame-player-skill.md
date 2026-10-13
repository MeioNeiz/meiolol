---
status: answered
priority: now
area: stats
tags: [method, stats]
description: How do the best systems model a player's pre-game skill?
---
# How do the best systems model a player's pre-game skill?

Feeds: meiolol-f7's player-history nets (internal scope) and the 55-57% target
([[draft-predictor-methods]] C11). Our player-history terms beat every draft model about
4x (docs/learned.md: 53.2% to 54.5% on test).

## Answer

The best-documented system, TrueSkill 2, went from 52% to 68% held-out accuracy on 3M
Halo 5 games after a 23M-game history, by adding terms only where a subgroup's actual win
rate departed from the model's expectation (C1, C2). Its terms: experience (new players
win 45%, 49% after 10 games), quits, previous-game performance, squads, and one base
skill with a shrunk per-mode offset (C3, C4). Most of its gain does not transfer: squads
(89% win rate at 10+) barely exist in solo/duo, and no per-term accuracy ablation is
given (C2). Expect a point or two, not 16.

Per-role or per-character skill: every shipped system ended at one shared skill plus
shrunk offsets, not independent ratings. Valve replaced separate Core and Support MMRs
with one MMR plus five role handicaps; Riot links per-position MMRs so an off-role start
is about a tier lower; TrueSkill 2 proposes the same per LoL or Dota character but does
not measure it (C4, C5). Off-role play costs enough for Riot to act on, partly absorbed
by matchmaking now (C5); our own field ranking found no detectable autofill effect on
the same champion and role (docs/learned.md, Field ranking A1).

Thin history is the main obstacle: Elo, Glicko and TrueSkill scored about 49-50% on a
sparse LoL sample (52k games, 324k players), even for players with 100+ games (C6); with
our 16 days, a rating alone will be weak, and the prior when there is no history (rank at
start, mastery points) matters most. Form, tilt and sessions: LoL win rate falls over 10%
within sessions of 3+ games, but players stop after losses, which inflates it, and no
source measures a held-out gain; earlier work found 0.1-0.3 points (C7). Smurfs are a
real cold-start case: unadjusted ones stayed about 3 divisions off after 10 games (C8).

Methods for us, best first (C9): (1) player base plus champion and role offsets shrunk by
games observed, with mastery points as the experience prior; (2) rank at start as the
base prior plus an "unconverged" flag; (3) off-role share and experience/lapse terms;
(4) batch smoothing over the history (TrueSkill Through Time) using only earlier games;
(5) session and form features, only as a time-split test. First, run TrueSkill 2's
calibration check on our test games: per bucket (games on champion, days since last
game, previous result, rank) actual minus predicted win rate; a bucket off by 2+ points
names a missing term (C10).

## Claims

- C1: TrueSkill 2 builds the model by metrics: a term is added only when a subgroup's actual win rate departs from the expected one, and kept if it closes the gap. for: [[trueskill2-2018#^f5]]
- C2: TrueSkill 2 raised time-split accuracy from 52% to 68% on 3M Halo 5 games; squads drive a large part (89% win rate at 10+ vs 49-52% expected); no per-term ablation. for: [[trueskill2-2018#^f3]], [[trueskill2-2018#^f4]], [[trueskill2-2018#^f6]]
- C3: Experience matters for new players (45% at 0 games to 49% at 10+) and reproduces the lapse effect; a quit last game also lowers the next win rate. for: [[trueskill2-2018#^f7]], [[trueskill2-2018#^f9]], [[trueskill2-2018#^f10]]
- C4: Shipped systems model per-mode or per-role skill as one shared skill plus shrunk offsets, not independent ratings. for: [[trueskill2-2018#^f11]], [[trueskill2-2018#^f12]], [[valve-dota2-ranked-roles-2020#^f1]], [[valve-dota2-ranked-roles-2020#^f2]], [[riot-dev-ranked-2019-positions#^f1]], [[riot-dev-ranked-2019-positions#^f5]]
- C5: Off-role play costs about a tier in Riot's example; position-aware matchmaking raised off-position win rates. for: [[riot-dev-ranked-2019-positions#^f3]], [[riot-dev-state-of-ranked-2019#^f1]]
- C6: Ratings built on sparse LoL history predict at about chance (49-50% for Elo, Glicko and TrueSkill), against 57-65% on denser CS:GO data. for: [[dehpanah-team-skill-aggregation#^f3]], [[dehpanah-team-skill-aggregation#^f4]], [[lol-skill-decomposition#^f4]]
- C7: Within-session LoL win rate falls over 10% in sessions of 3+ games, with no long-term improvement; no source shows a held-out gain from session or form terms, and recent form added 0.1-0.3 points. for: [[sapienza-session-performance#^f3]], [[sapienza-session-performance#^f4]], [[lol-momentum-forecasting#^f7]]
- C8: Smurfs whose MMR was not adjusted were still about 3 divisions off after 10 games; adjusted ones converged in about 4. for: [[valorant-smurf-detection#^f2]], [[valorant-smurf-detection#^f3]], [[valorant-smurf-detection#^f4]]
- C9 (inferred): For us: player base plus champion and role offsets shrunk by games observed, mastery points and rank at start as priors, then off-role, experience, smoothing, form, in that order. from: C3, C4, C5, C6, C7
- C10 (inferred): Run the calibration-by-bucket check before adding terms. from: C1

## Disagreements

- Session decline: Sapienza (C/weak) reads it as fatigue, their shuffle control passing;
  the reader's inference ([[sapienza-session-performance#^f9]]) is that stopping after a
  loss enriches last games with losses. Settles on our data: predict game k's result from
  pre-game features only, by position in session.

## Open

- No measured held-out gain for per-character offsets anywhere; ours to test.
- Leads: PandaSkill (arXiv 2501.10049, pro LoL rating); Ranked 2026 autofill-vs-autofill
  matching (Riot's post); chess tilt ("Do mistakes provoke new mistakes"); Dehpanah's
  battle royale paper. Tilt and streak searches found nothing more (near saturated).
- Player graph for players with little history: [[gnn-match-outcome]] (c).
