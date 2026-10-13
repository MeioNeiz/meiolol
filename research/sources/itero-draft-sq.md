---
title: 'LoL: How to win your Solo Queue Draft - a statistical analysis of 1M+ games (iTero, 2022)'
url: https://www.itero.gg/articles/draft-sq
kind: article
commit:
for: [comp-attribute-features]
looked: 2026-10-13
depth: docs (full article; AD ratio chart image read)
relevance: high
grade: C/weak
description: iTero (vendor) blog on 1M+ solo queue games used to train its drafting coach; only LoL source found with a measured team damage-mix (AD ratio) win rate curve
---
# LoL: How to win your Solo Queue Draft - a statistical analysis of 1M+ games (iTero, 2022)

Why: is the "full AD / full AP" penalty measured anywhere in solo queue data, and how big?

## Assessment

- Evidence: C. 1M+ solo queue games (Sept 2022, mid elo implied: "Silver/Elo"), but raw
  bucket win rates only: no counts per bucket, no confidence intervals, no control for
  champion strength, no held-out model comparison. Charts are images.
- Reasoning: weak to fair. Gives a mechanism (enemy tanks buy one resist with all 6
  slots) and an honest asymmetry, but never says whether AD share is from champion
  profiles or realised in-game damage (realised damage would leak the outcome: a losing
  team's carry deals little damage, which skews its share).
- Interests: vendor; the article promotes iTero's drafting tool.
- Weigh: direction (a dip at both extremes, AP-heavy worse) is plausible and matches the
  folklore; the size (6 to 9 pp) is a raw marginal and likely inflated by confounding
  (one-dimensional comps correlate with off-meta or autofilled picks). Verify on our
  own data with champion-profile AD share and a champion-id baseline.

## Findings

- [draft] [data] Data: 1M+ solo queue games, collected to train the iTero drafting AI
  (Sept 2022). ^f1
  > visualising what we found from studying 1M+ solo queue games in order to train the AI
- [draft] Team damage mix: AD share of team damage between 20% and 80% sits at about
  50%; outside that band win rate drops. ^f2
  > If AD accounts for around 20–80% of your team’s damage — you’ll be sitting bang average, just above the 50% mark. However, for those few games that fall on either side of this green zone there is a very real decrease in their win chance.
- [draft] AP-heavy (<20% AD) is worse than AD-heavy (>80% AD). ^f3
  > For some reason, <20% AD seems to be more painful than >80%.
- [draft] (inferred) Bar heights read from the chart image ("Impact of AD Ratio on Win
  Rates", cdn.sanity.io e57657b8...-727x523.png): under 20% AD about 41%, 20-80% about
  50%, over 80% AD about 44%; so roughly -9 pp for near full AP and -6 pp for near full AD. No
  bucket sizes shown ("those few games"). ^f4
- [draft] Stated mechanism is resist itemisation: one-type damage lets enemy tanks put
  every slot into one resist. ^f5
  > By building a composition that is too one dimensional in their damage type you offer the enemy the opportunity to efficiently buy defensive items. Their tanks can use all 6 slots to build items effective against your entire team
- [draft] (claim) Asymmetry explained by AD champions having more true damage that
  handles tanks; not tested. ^f6
  > Potentially as there tends to be a greater selection of AD Champions with high and consistent true damage that can still handle the tanks.
- [draft] Damage mix is the only team composition attribute the article reports; no
  tank count, CC, range or scaling feature. ^f7
  > However, there’s one that is worth considering: **the AD Ratio.**
- [method] Checked, not there: how AD share is computed (champion averages vs realised
  in-game damage), bucket counts, or any lift of the feature in iTero's model. ^f8
- [draft] Champion econ (win chance when behind) is a profile-style attribute: in about
  17,000 games with lanes at 70-75% of average gold at 12 min, bad econ champions win
  almost 5 pp less than good econ ones (around 27.5% overall). ^f9
  > For all players, things are bad — averaging around 27.5% win rate if they’re set this far behind so early in the game. However, the **BAD** econ Champions have win rates **almost 5% lower** than the **GOOD** ones.
- [method] Mastery dominates its feature list: sub-5k mastery 41.5% vs 54.5% at 500k+. ^f10
  > sub-5k Mastery players averaging a win rate of just 41.5%, compared to the 54.5% enjoyed by 500k+ players
- [data] Page bug: the AD ratio chart image is also served in the econ chart's slot
  (same file, two alt texts), so the econ chart itself was not visible. ^f11

## Read

- Full article text; chart image for AD ratio (viewed from the page's CDN URL).

## Not read

- iTero snowballatility article (econ method), pro-play draft series (pro, out of scope).
