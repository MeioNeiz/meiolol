---
title: LoLTheory Team Comp Analyzer layout (Oct 2026)
url: https://loltheory.gg/lol/team-comp-analyzer
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (empty board and recommendations, middle, Platinum+; rendered text and screenshots)
relevance: medium
grade: C/fair
description: LoLTheory's web comp analyzer: a compact two-team table with bans, role and win rate per slot, then five recommended champions beside a five-slot Favorites column
---
# LoLTheory Team Comp Analyzer layout (Oct 2026)

Why: lol-site-ui, kind 7: draft board layout and how a pool sits beside suggestions.
Earlier note on what it computes: [[loltheory-comp-analyzer]]. Screenshot
data/team/2026-10-24-ui/refs/pool-draft/loltheory-recs.png (gitignored).

## Assessment

- Evidence: C. Small tool; its own blog explains the method ([[loltheory-recommendations]]).
- Reasoning: fair. Underlined labels have tooltips; one line says what the scores are.
- Interests: vendor (pushes its desktop app).
- Weigh: the Favorites column beside the recommendations is the idea; the "+1.70%" column
  is the wording we may not use.

## Findings

- [ux/layout] Board as one 650 px card: Your Team left, Enemy Team right mirrored; five
  ban slots each; per row a champion slot, a role icon (yours) or "?" (theirs), and a
  win rate; team Win Rate and Score at the bottom (screenshot 24 Oct). ^f1
  > Compose the Teams
  > Click cell to select your role
- [ux/features] Recommendations: five rows of champion icon, a signed win rate change
  and a score, headed by a one-line caption. ^f2
  > What You Should Pick Middle
  > Scores and win rates are based on team composition
- [ux/features] Favorites 0 / 5 sits beside Recommended Champions with the same columns,
  so the player's own pool is scored next to the top suggestions; "Add a Favorite" fills
  a slot. ^f3
  > Favorites ... Add a Favorite
- [ux/controls] Settings above the board are three chips: recommendation method, rank
  range, patch. ^f4
  > Recommendation method: Classic
- [policy] (inferred) "What You Should Pick" plus a "+1.70%" column is the best-pick and
  win-rate wording meio.lol's product rules exclude. ^f5

## Read

- Empty board and default recommendations.

## Not read

- Behaviour with picks entered; Counters and Synergies pages.
