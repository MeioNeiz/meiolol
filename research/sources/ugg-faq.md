---
title: U.GG Frequently Asked Questions
url: https://u.gg/faq
kind: docs
commit: 
for: [league-tools-landscape]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: B/fair
description: U.GG's own FAQ (Oct 2026): what it offers, data source (Riot API, every game), how counters, tiers, builds and roles are computed, monetisation (ads plus U.GG PLUS)
---
# U.GG Frequently Asked Questions

Why: what a top-two stats site offers, what data it uses and how it makes money.

## Assessment

- Evidence: B. One of the two biggest LoL stats sites ([[similarweb-opgg-competitors#^f3]]);
  (c) 2017-2026 Outplayed Inc., footer lists Enthusiast Gaming sister brands.
- Reasoning: fair. Explains its counter, tier and build methods in a sentence each.
- Interests: vendor.
- Weigh: trust what it says it computes; "most accurate" and "every game" are claims.

## Findings

- [tools] [data] All data from Riot's API; claims to analyse every available game. ^f1
  > All of our data comes from Riot's API.
  > We analyze every game available from Riot's API.
- [tools] [draft] Counters are end-of-game win rate by opposing champion, per patch: no timeline metric in the definition. ^f2
  > Our champion counters are what a particular champion is losing against the most on a particular patch. We calculate this by analyzing every game a particular champion is played, and then displaying which champions are winning the most and by how much.
- [tools] Builds are the most frequent build above baseline win rate, filterable by lane opponent. ^f3
  > return the most frequent build that holds a higher win rate than the baseline win rate for your selected champion
  > Change the “Vs Champion” filter to look at what is best in your specific matchup.
- [tools] Per champion: recommended build, pro builds, counters, matchups, duos, items and runes. ^f4
  > For every champion, we offer a recommended build, a list of recent pro builds, champion counters, matchups, duos, detailed items and runes, and a whole lot more.
- [data] Re-derives roles itself because Riot's role assignment is often wrong (claims 99.9%). ^f5
  > However, the reported roles are not always correct.
  > We created an algorithm that mimics a human heuristic for determining roles and we believe the algorithm is correct 99.9% of the time.
- [market] Monetises with ads plus U.GG PLUS subscription (ad-free, personalised insights, counters, tier lists). ^f6
  > We serve ads. We also offer U.GG PLUS, our premium subscription service
  > Subscribers get an ad-free interface across our website and app, personalized champion insights, counters, and tier lists
- [market] Multi-game portfolio (top nav): LoL, Valorant, Rematch, Deadlock, WoW, Helldivers 2; footer "Our Brands" lists Icy Veins, Pocket Gamer and others (Enthusiast Gaming group). ^f7
- [tools] Use case framed as the last 30 seconds of champ select: quick runes, tier lists, counters. ^f8
  > If there are 30 seconds left in champ select and you have no idea what runes to take, U.GG is your quick and easy solution to win the lane.
- [tools] Checked, not there: no mention of timeline-derived stats (gold at 15, lane diffs, power curves) or matchup learning content in the FAQ. ^f9

## Read

- Whole FAQ

## Not read

- u.gg/plus (what PLUS personalises, price)
- A u.gg matchup page (whether it shows gold diff at 15 or other timeline stats)
