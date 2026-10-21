---
title: 'meiolol docs/learned.md: Player section (mastery and selection, our held-out tests)'
url:
kind: docs
commit: 3664821dde69d87bc2df4df21b5bb3e3e97c4a13
for: [frontier-causal]
looked: 2026-10-21
depth: docs (docs/learned.md, Player section, 20 Oct lines)
relevance: high
grade: A/strong
description: Our own results on mastery and win chance: within-player expertise effect, per-champion new-player gaps, and the drop-after-loss selection in mastery fetches
---
# meiolol docs/learned.md: Player section (mastery and selection)

Why: what our own data already says about who picks a champion and how that moves its
win rate, so causal claims can cite it.

## Assessment

- Evidence: A. Our pre-declared held-out tests (944k held-out player-games for the
  expertise effect; 1.92M player-games for the per-champion gaps).
- Reasoning: strong; each line states what was ruled out.
- Interests: ours.
- Weigh: mastery is fetched after the game (median 1.6 days), a source of leakage the
  lines address.

## Findings

- [method/causal] [stats] Within a player's own pool, more mastery on the champion means
  more wins: about 3.7 points from 10k to 300k points in an even game, same in every
  role; players with more points on everything win slightly less, so it is not "good
  players have mastery". ^f1
  > with their own other champions, by about 3.7 percentage points from 10k to 300k
  > Players with more points on everything win slightly less, so the gain is within a player's pool
- [method/causal] [stats] Who picks a champion moves its win rate a lot: under 10k mastery
  47.7% vs 300k+ 51.7%; new Rengar players 39% vs 51% for practised ones, while new
  Leona or Caitlyn players do about as well as practised ones. ^f2
  > New Rengar players win 39% against 51% for practised ones
- [method/causal] [stats] Selection in our own data: a champion's last game before the
  mastery fetch wins only 42-45%, because players drop a champion after a loss. ^f3
  > (those games win 42-45%: players drop a champion after a loss)
- [method/causal] (inferred) So a champion's raw win rate mixes kit power with its
  pickers' mastery mix, and choices respond to recent results; the expertise term in the
  lane card already conditions on the user's own mastery, the main observed confounder. ^f4

## Read

- docs/learned.md Player section (20 Oct lines).
