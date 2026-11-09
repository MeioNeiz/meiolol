---
title: 'Leetify: What is Leetify Rating? (2021, pre-CS2 version)'
url: https://blog.leetify.com/what-is-leetify-rating/
kind: docs
commit:
origin: leetify-rating-2024
for: [postgame-review-compare]
looked: 2026-11-06
depth: docs (whole article)
relevance: medium
grade: A/strong
description: Leetify's original 2021 explainer (valid for matches before 26 Nov 2024): why the win probability model deliberately ignores player skill and position, kill chains, save rewards, benchmarks across all users
---
# Leetify: What is Leetify Rating? (2021)

Why: the design reasoning the newer page ([[leetify-rating-2024]]) drops.

## Assessment

- Evidence: A. Vendor method page, kept with a banner pointing to the new one.
- Reasoning: strong: explains choices, limits and version history.
- Interests: vendor.
- Weigh: numbers are superseded; the reasoning still describes the product.
  Same vendor as [[leetify-rating-2024]], so `origin` makes them count as one.

## Findings

- [method] [ux/trust] The win model deliberately leaves out player skill and position, so
  a player who beats the odds gets the credit. ^f1
  > We intentionally do not include things like specific positioning or specific skill levels of players, because a player over-performing in a round should be rewarded with points from our system.
- [method] The problem it set out to fix: stat lines give credit for kills that did not
  matter. ^f2
  > it is too easy to get a lot of credit from un-impactful kills.
- [ux/trust] Bands are computed across all Leetify users per match, and do not apply to
  averages over many matches. ^f3
  > These benchmarks are computed across all Leetify users on a single-match basis.
- [ux/trust] They admit the rating can be gamed against winning. ^f4
  > you can get to situations where the goals of getting a high rating and winning the match are not completely aligned.
- [ux/trust] Versions are labelled so old and new numbers are not compared blindly. ^f5
  > Any such future updates will be properly communicated with the community and will be made in a way that minimizes confusion when comparing matches from different versions of Leetify Rating.

## Read

- Whole article.
