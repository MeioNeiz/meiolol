---
title: 'STRATZ: IMP Is Back (Individual Match Performance 2.1, Jun 2021)'
url: https://medium.com/stratz/imp-is-back-9a4280f34d62
kind: article
commit:
for: [postgame-review-compare]
looked: 2026-11-07
depth: docs (whole post)
relevance: high
grade: B/strong
description: STRATZ blog on IMP 2.1, its neural network per-player match score (-100 to +100, meters shown -50 to +50), VSMVP and LVP awards, and why it is not normalised by hero
---
# STRATZ: IMP Is Back

Why: Stratz's per-match performance score for Dota 2, the closest analogue to Leetify
Rating and chess.com Game Rating.

## Assessment

- Evidence: B. Vendor blog (Jun 2021); STRATZ is a major Dota stats site. Its match
  pages are behind a Steam login wall for anonymous readers (ledger skips), so the
  current IMP display was not seen.
- Reasoning: strong on the normalisation choice: names the UX pull and why they resisted.
- Interests: vendor.
- Weigh: 2021; check current pages with a login.

## Findings

- [method] IMP is a neural network value trained on what a winning Dota performance is
  made of (since IMP 2.0, 2020); before it was a formula. ^f1
  > we upgraded from an algorithmic approach to a [neural network generated value](https://medium.com/stratz/stratz-ai-the-imp-ire-strikes-back-a7a3ca2b9eba), tying together innumerable combinations of metrics, and training computers to understand what a winning Dota performance is composed of.
- [ux/postgame] Its scale is win probability: in theory from 0.01% to 99.99% by your
  play alone gives about +100; top values in practice are 70 to 80. ^f2
  > if you begin a match with an estimated 0.01% chance to win, and then perform so highly as an individual that your performance alone predicts a 99.99% win probability, then you could achieve an approximately +100 IMP value.
- [ux/postgame] The purple IMP meters were narrowed to -50 to +50 because values beyond
  are rare, for a more varied look. ^f3
  > the new IMP meters visualize a spread of IMP from -50 through +50. This creates a much more visually diverse and satisfying spread of values across your heroes and/or matches.
- [fun] [ux/postgame] Extremes get awards: Very Special MVP at +50 or more (about 1 in 50
  matches) and an LVP anti-award for the worst (about 1 in 60). ^f4
  > Very Special MVP awards are earned in about 1 out of 50 matches; LVP awards are \[earned\] in about 1 out of 60 matches.
- [ux/trust] IMP is not normalised by hero (Medusa and Templar Assassin average high,
  Earth Spirit and Ogre Magi low); normalising felt right for UX but they keep the
  honest number. ^f5
  > We’ve gone back and forth debating whether or not to normalize the IMP value by hero, allowing for equal odds for high and low achievement regardless of hero choice. From a UX standpoint, this feels like the right thing to do.
- [ux/trust] A model change broke IMP after a hero release (Dawnbreaker) and took it down
  for a while: a learned score can fail silently. ^f6
  > following the Dawnbreaker release, it became apparent that something wasn’t right.

## Read

- Whole post.

## Not read

- IMP 2.0 post (stratz-ai-the-imp-ire-strikes-back); match awards knowledge base page.
