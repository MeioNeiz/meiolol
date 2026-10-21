---
title: 'Is Season 13 Balanced? ft. Riot Phroxzon (Broken by Concept ep. 157, 2023-07-10)'
url: https://www.youtube.com/watch?v=q2qqyDuUllA
kind: video
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: listed (14:20-22:40, the mains and dashboards segment)
relevance: high
grade: B/fair
description: Podcast with Riot's lead balance designer; segment on whether mains inflate champion win rates (his 1.5-year side study) and Riot's balance dashboards by skill bracket
---
# Riot Phroxzon on Broken by Concept ep. 157 (2023): mains and win rates

Why: primary source for the much-repeated "Riot says mains don't inflate win rates"
claim, and how Riot reads win rate by who plays a champion.

## Assessment

- Evidence: B. First-hand report from Riot's lead balance designer, but a side project
  ("in my spare time"), numbers from memory ("rough approximation"), auto captions,
  no method published. The 0.4 figure is said twice, consistently.
- Reasoning: fair. Explains the mechanism (few mains, many first-timers) but the
  estimand is loose: "effect of mastery on win rate" net over the pickers.
- Interests: Riot defending balance decisions against "OTP-inflated" complaints.
- Weigh: trust the composition facts' direction (many low-mastery games); treat 0.4
  as order of magnitude. Our own numbers (learned.md: under 10k 47.7%, 300k+ 51.7%)
  agree that the gap per player is large and the net shift small.

## Findings

- [method/causal] [stats] Most of a champion's ranked games come from low-mastery
  players: roughly 30-40% of games are in a player's first 0-15 games on the champion
  and only 15-20% above about 100k mastery (his approximation). @15:50 ^f1
  > 30 to 40 of people playing a champion will be in the you know zero to 15 games range of playing a champion
- [method/causal] [stats] Net of everyone, mains raise a champion's aggregate win rate
  by at most about 0.4 points (Katarina; Evelynn about 0.1), because first-timers
  failing offset the mains; most champions come out negative. @17:20 ^f2
  > the only champion who had a positive effect on win rate was Katarina 0.4
  > that's like the maximum amount that a Mains would increase and most of them are negative
- [method/causal] He defines a main by mastery (around 25k+ points) as a proxy for games
  played. @17:20 ^f3
  > people from like 25k plus Mastery or something they're offsetting the people that are like failing on their like first 0 to 15 games
- [method/causal] Riot's general dashboard is win, pick and ban rate per champion in four
  skill brackets; follow-ups split by build and by ahead or behind. @21:55 ^f4
  > at the win rate pick rate ban rate um of all the champions in the different skill brackets
- [method/causal] (inferred) So a champion's raw win rate is a mixture over pickers'
  mastery, and the mixture weights differ by champion (hard champions draw more failing
  first-timers). The quantity a recommender needs is win chance at the user's own
  mastery, not the mixture; mastery-standardised win rates (reweight every champion to
  one common mastery distribution) would rank champions differently from raw ones,
  most for steep-curve champions. ^f5

## Read

- Chapters list; transcript 14:20 to 22:40.

## Not read

- Rest of the 2h16m episode (items, Statikk Shiv, preseason).
