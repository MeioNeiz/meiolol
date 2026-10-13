---
title: Individual performance in team-based online games (Sapienza et al., R Soc Open Sci 2018)
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC6030337/
kind: paper
commit:
for: [pregame-player-skill]
looked: 2026-10-13
depth: docs (whole paper, figures not read as images)
relevance: medium
grade: C/weak
description: 242k LoL solo-queue games 2014-2016 of 16.7k very active players; win rate and KDA fall over a session (15-minute gap), less for experienced players; no long-term win-rate gain; descriptive, no outcome-prediction test
---
# Individual performance in team-based online games (Sapienza et al., R Soc Open Sci 2018)

Why: the main LoL source on within-session decline (fatigue, tilt); is the effect big
enough, and clean enough, to be a pre-game feature?

## Assessment

- Evidence: C. Peer-reviewed open-access journal, real Riot API data (242,352 games,
  16,665 players with 10+ games), dataset public on Dataverse. Descriptive curves; no
  test of whether session position improves outcome prediction on held-out games.
- Reasoning: weak on causality. The only control is shuffling game order within a
  player, which does not address the stopping rule: sessions are grouped by their final
  length, and if players stop after a loss (the paper's own RQ4 says falling win rate
  predicts quitting), the last game of every session is enriched for losses by
  construction.
- Interests: none known (academic).
- Weigh: trust "win rate does not improve long-term under matchmaking"; treat the 10%
  within-session decline as an upper bound inflated by selection. At prediction time we
  know a game's position in the session so far (games in the last hours), not the
  session's final length, so the usable effect is smaller.

## Findings

- [data] 242k solo-queue games, May 2014 to January 2016, 16,665 players with at least
  10 games; solo queue chosen to exclude friends' influence. ^f1
  > The final dataset [ 8 ] consists of about 242 000 solo-queue matches played by a sample of 16 665 players between May 2014 and January 2016.
- [method] A session is a run of games with at most a 15-minute break between them
  (the median break). ^f2
  > we define a gaming session of length n as the temporally ordered sequence of n matches, with no more than a 15-minute break between matches.
- [stats] No long-term win-rate improvement with experience (rho 0.02); win rates revert
  to about 0.5, which they attribute to Elo-based matchmaking. ^f3
  > there is no long-term team's performance improvement with experience ( ρ =0.02).
  > Thus, the likelihood to win each match is not significantly better than 50%.
- [stats] Within a session, for sessions of 3+ games, win rate falls by more than 10%
  and KDA by 8% from first to last game; not seen with shuffled game order. ^f4
  > for sessions with three or more matches, the win rate and the KDA value, respectively, deteriorate by more than 10% and 8% between the first and the last matches in the session.
- [stats] Longer sessions show an initial rise before the decline, which they read as
  warm-up; stronger for win rate than KDA. ^f5
  > The only difference is the initial improvement during longer game playing sessions: this pattern might reflect a ‘warm-up’ period.
- [stats] The decline is much smaller for the most experienced players (top 5% by games)
  than the least experienced (bottom 5%), who also play shorter sessions. ^f6
  > Performance of the latter group of players declines far more than that of the experienced players.
- [stats] Predicting whether a game is the session's last: AUC 0.976 (gradient
  boosting); top features current in-session win rate, session win rate, game index. ^f7
  > the best result is obtained by GB ( AUC =0.976±0.001)
- [method] Checked, not there: no held-out win prediction from session position, no
  control for the stopping rule (players ending sessions after losses), no MMR or rank
  in the data, results binned by final session length. ^f8
- [method] (inferred) Stopping-rule bias: grouping sessions by final length and
  comparing first to last game builds in a loss at the end if losses end sessions,
  which their own quit model (^f7) suggests. The order-shuffle control keeps each
  player's game set but breaks the link between the stopping rule and the last game, so
  it removes the artefact along with any real fatigue. ^f9
- [method] (inferred) For us: a causal-ordering feature is possible (games already
  played in the current session, minutes since last game, last game's result), all
  known at champ select. Expect a small effect: TrueSkill2 found previous-game result
  and lapse each shift win rate by a few points ([[trueskill2-2018#^f9]],
  [[trueskill2-2018#^f10]]), and White and Romano found recent form adds 0.1-0.3
  accuracy points ([[lol-momentum-forecasting#^f7]]). Measure on our time-split test,
  do not assume 10%. ^f10
- [method] (inferred) No long-term improvement (^f3) supports treating rank or MMR as
  the main skill state and our per-champion history as offsets around it, rather than
  modelling a learning curve per player; the champion-level learning curve is the
  exception (first games on a champion). ^f11

## Read

- Abstract, sections 1-5 (data, sessions, RQ1-RQ4, related work, discussion)

## Not read

- Figures 2-5 as images (numbers taken from the text only); the Dataverse dataset
