---
title: 'Mobalytics: Darius top build (patch 26.20)'
url: https://mobalytics.gg/lol/champions/darius/build
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (page innerText, fold and full-page screenshots)
relevance: low
grade: B/fair
description: Mobalytics champion build page: summary box of win, pick and ban rate with trend arrows and matches, templated summary, recommended builds list with win rates
---
# Mobalytics: Darius top build (patch 26.20)

Why: the header stat box of a major site's champion page.

## Assessment

- Evidence: B. Major LoL site; live page.
- Reasoning: weak. Layout only.
- Interests: vendor.
- Weigh: screenshots in data/team/2026-10-19-night/design-shots/mobalytics-darius-build*.png.

## Findings

- [ux/density] Header stat box: four rows (win rate, pick rate, ban rate, matches), each a label, a bold value and a small green up or red down triangle for the change since last patch (seen in screenshot mobalytics-darius-build.png). ^f1
- [ux/layout] Build choice states its own sample in words. ^f2
  > Win Rate 54.4% based on 24 193 matches
- [ux/layout] Templated summary paragraph under the name restates win rate, pick rate, tier and the sample. ^f3
  > Darius Top has a 49.7% win rate with 6.4% pick rate in Emerald + and is currently ranked S tier.
- [ux/uncertainty] Failure: "Top players" list gives one player 70.4% and another 64.1% with no game counts beside them (seen in screenshot mobalytics-darius-build.png). ^f4

### 24 Oct: element shots (for lol-site-ui)

Screenshots in data/team/2026-10-24-ui/refs/champion/ (gitignored): mobalytics-darius-build.png,
-matchups.png. Raw mobalytics-darius-build.2026-10-24.md (patch 16.21, 34,420 matches).

- [ux/controls] Recommended builds are a left-hand list of four named variants with a win
  rate each, all visible at once (Most Popular 54.8%, Highest WR 55.1%, Alternative 54.3%,
  Off-Meta 56.0%); the open one's sample is given in the panel header ("5 760 matches"),
  the others' only after clicking. ^f5
  > Most Popular 54.8% Highest WR 55.1% Alternative 54.3% Off-Meta 56.0%
- [ux/uncertainty] Matchups overview (weak against, strong against, best synergy) shows six
  portraits each with a win rate ring and win rate, no games. (seen in screenshot
  mobalytics-darius-matchups.png) ^f6
- [ux/density] Ability order is an 18-column grid of letters on thin vertical guide lines
  with the max order (Q > E > W) above it, no numbers; items carry the minute (core @ 19 min,
  early @ 3 min) instead of rates. (seen in screenshot mobalytics-darius-build.png) ^f7

## Read

- Page innerText; fold screenshot, full page skimmed

## Not read

- Runes and Expert Video Guide tabs
