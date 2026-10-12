---
title: Scalable Psychological Momentum Forecasting in Esports (White and Romano, UCL, WSDM SUM 2020)
url: https://arxiv.org/pdf/2001.11274
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (dataset, features, Table 3, feature importances, appendix A)
relevance: high
grade: C/fair
description: 88k 2019 LoL ranked games with op.gg player profiles; 72.1% post-draft, 65.7% pre-draft (no champions), 54.3% from one player's own history; feature group ablation; timing of profile stats unclear
---
# Scalable Psychological Momentum Forecasting in Esports (White and Romano, UCL, WSDM SUM 2020)

Why: the largest LoL study with rich pre-game player features (proficiency, season
stats, recent form), with ablations; check how much each adds and whether it leaks.

## Assessment

- Evidence: C. 87,743 games (Solo/Duo and Flex, 2019), 10,000 held out, workshop paper;
  per-group ablations, no time split, no log loss.
- Reasoning: fair. Careful engineering and ablations; never discusses when the op.gg
  profiles were read relative to the match.
- Interests: none known (academic).
- Weigh: the relative ordering (champion proficiency >> recent form > Elo) is useful.
  The absolute numbers are likely inflated: 65.7% with no champions at all is far above
  what matchmade games allow on skill alone ([[lol-skill-decomposition#^f4]]: TrueSkill
  55.2%).

## Findings

- [data] Data: 87,743 games, Feb to Sep 2019, 86.4% Solo/Duo; 70,194 train, 10,000
  test. ^f1
  > In total, 87,743 valid samples were collected starting two weeks after the beginning of season 9
- [data] Player features come from op.gg profiles loaded once a recent match is found:
  champion proficiency, season totals, last 20 games. ^f2
  > Once a valid match is found, participant profile summaries are loaded from op.gg, which contain on-champion proficiency statistics, season totals, and performances for up to the last 20 games.
- [method] Checked, not there: no statement that profile stats were taken before the
  match or exclude it. Since matches were found after they occurred, season win rate,
  champion games and wins, and the last 20 games probably include it. ^f3
- [method] Accuracy: post-draft 72.1% (logistic regression with rolling form features);
  their reproduction of Chen et al. 60.24%. Pre-draft with both teams' players 65.7%.
  One player's own pre-draft history 54.30% (pre-draft rows read from Table 3). ^f4
  > We achieve a state-of-the-art classification accuracy of 72.1% for League of Legends using a logistic regression
- [method] Feature group ablation (accuracy drop when omitted): champion proficiency 6.5,
  season history 2.4, global champion stats 2.4, recent matches 2.0, metadata incl. Elo
  0.3, champions as categoricals 0.3, global matchups 0.3. ^f5
  > Drop in accuracy when the group is omitted (in brackets)
- [method] Proficiency on the chosen champion is the largest post-draft factor; recent
  matches are about 40% of the pre-draft signal. ^f6
  > Proficiencies are the most significant factor post-draft.
- [method] Momentum (last 20 games) adds only 0.1-0.3 points post-draft. ^f7
  > Though the signal found is faint, we are able to account for momentum that occurs over the medium term of the last t ≤ 20 matches within a post-draft win prediction model, increasing the accuracy by 0.1-0.3%
- [method] Logistic regression beat their neural nets post-draft and plateaued at about
  70k games. ^f8
  > Logistic regression accuracy plateaued by ∼70,000 data points.
- [data] Proficiency features: per champion games, wins, losses and a Bayes-smoothed win
  rate over two seasons, plus KDA, gold and CS normalised by the champion's global
  average. ^f9
  > champion proficiency [games, wins, losses, bayes win rate
- [data] (inferred) Riot API needs: champion proficiency and season stats mean each
  player's match-v5 history (ids by PUUID, then each match); Riot gives no per-champion
  win rate endpoint, so op.gg's aggregates stood in. For the app only the user's own
  history is usable, which is the 54.3% "pre-draft solo" setting. ^f10
- [method] (inferred) Elo adds 0.3 points because matchmaking equalises it; what survives
  is skill not captured by MMR (champion-specific skill) and leakage. ^f11

## Read

- Abstract, intro, dataset, features (4.1), Table 3, Figure 5, discussion, appendix A

## Not read

- Network architecture details (4.2), tilt coaching proposal (future work)
