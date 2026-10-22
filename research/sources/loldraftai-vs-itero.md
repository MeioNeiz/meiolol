---
title: 'LoLDraftAI blog: iTero vs LoLDraftAI, a detailed comparison (Apr 2026)'
url: https://loldraftai.com/blog/itero-vs-loldraftai-comparison
kind: article
commit: 
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (whole article)
relevance: high
grade: C/fair
description: LoLDraftAI's head-to-head of its neural draft model against iTero (100 greedy drafts judged by DraftGap) with a feature table of what each ships, including tiers, desktop, overlays and macro coaching
---
# LoLDraftAI blog: iTero vs LoLDraftAI, a detailed comparison (Apr 2026)

Why: a side-by-side feature list of the two ML draft tools, from someone who probed iTero's API.

## Assessment

- Evidence: C. Dated 19 Apr 2026; publishes its 100-draft data as jsonl; feature table "based on observing both tools' web UIs and APIs".
- Reasoning: fair. Uses a third-party judge (DraftGap) and flags its own judge as circular, but the method story about iTero is inferred from API output.
- Interests: vendor, one side of the comparison (LoLDraftAI wrote it).
- Weigh: trust the feature table for what each ships (checkable); discount the architecture claims about iTero and the "pairwise tools can't see tempo" framing. Under the neutral judge the result is a near tie (55%, CI 45 to 65).

## Findings

- [tools] [method] (claim) iTero's API returns per-candidate signed "feature importances" (champion win rate, counters, synergies, gold, mastery) and 0-5 archetype ratings, read as a gradient-boosted tree over pairwise aggregates. ^f1
  > the response includes "feature importances", signed contributions for keys like `champ_wr`, `champ_gold`, `counter_MIDDLE_wr`, `syn_JUNGLE_wr`, `gold_multiplier`, `match_tier`, `mastery`
- [draft] [ux/features] LoLDraftAI shows a team win probability by game-length bucket (0-25, 25-30, 30-35, 35+ minutes) and predicted gold at 15 minutes per position; iTero shows only a per-candidate score, no team win rate. ^f2
  > | Calibrated team win probability for a full 5v5 | ✔ (side-aware + side-agnostic modes) | ✘ (per-candidate score only; no team WR) |
  > | Timeline prediction (win % by game duration) | ✔ (0-25, 25-30, 30-35, 35+ min buckets) | ✘ (early/mid/late _scaling diffs_ only) |
- [tools/paid] LoLDraftAI's desktop app with client auto-detection is in its paid Base and Plus tiers; iTero's desktop app is free. Pro play model is LoLDraftAI Plus only. ^f3
  > | Desktop app with League Client auto-detection | ✔ (Base/Plus tier) | ✔ (free) |
  > | Pro play model (fine-tuned on pro drafts) | ✔ (Plus tier) | ✘ |
- [tools/phase] [ux/features] iTero ships features beyond draft: mastery-aware recommendations (a "Consider Mastery" toggle), a Champion Pool Builder with tiered picks, a personality quiz, in-game overlays (map timers, skill order, damage) and account-level macro coaching, all desktop-only except the pool builder and quiz. ^f4
  > | Mastery-aware recommendations | ✘ | ✔ (optional "Consider Mastery" toggle) |
  > | In-game overlays (map timers, skill order, damage, etc.) | ✘ | ✔ (desktop-only) |
  > | Account-level macro coaching | ✘ | ✔ (desktop-only, "AI Macro Coach") |
- [tools/phase] [ux/features] iTero's desktop item builds adapt to the enemy comp (anti-heal, anti-shield); LoLDraftAI conditions items on full draft, runes, elo and patch. ^f5
  > ✔ (desktop app; builds adapt to the enemy comp, e.g. anti-heal / anti-shield)
- [draft] Champ select: LoLDraftAI's desktop app handles bans; iTero's web UI does not expose bans. Both give partial-draft recommendations. ^f6
  > | Bans in the drafting UI | ✔ (desktop app) | ~ (API supports bans; web UI does not expose them) |
- [draft] Under the neutral judge (DraftGap) LoLDraftAI's greedy drafts beat iTero's 55.0% of the time (CI 45.0 to 65.0), a mean margin of +0.6%; its own model says 93%. ^f7
  > | DraftGap (third-party) | 55.0% (45.0
- [ux/features] LoLDraftAI lets users pick historical patches and a side-aware or side-agnostic mode; iTero uses the current patch only, unlabelled. ^f8
  > | User-selectable patch | ✔ (historical patches) | ✘ (current patch only, not even labeled) |
- [tools/paid] Free in the browser; desktop for live draft tracking. ^f9
  > LoLDraftAI is free to use in the browser, or as a desktop app that auto-imports your draft from the League client.
- [policy] (inferred) Both tools show a ranked list of picks with scores in ranked champ select, and LoLDraftAI a team win percentage; neither page mentions any Riot limit on that, so the production key rule against "+X% win" wording is not visibly enforced on these two. ^f10

## Read

- Whole article

## Not read

- The DraftGap and LoLTheory comparisons (same author; method claims, less on features)
