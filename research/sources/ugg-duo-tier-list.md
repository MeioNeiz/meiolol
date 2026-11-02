---
title: U.GG Duo Tier List (bot lane, patch 26.21)
url: https://u.gg/lol/duo-tier-list
kind: project
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: skimmed (page text, first-screen screenshot)
relevance: high
grade: B/fair
description: U.GG's duo tier list, Emerald+ Ranked Solo, patch 26.21: 50 bot/support pair rows with solo rates, tier, duo win rate, synergy factor, pick and ban rate, matches
---
# U.GG Duo Tier List (bot lane, patch 26.21)

Why: the biggest stats site's pair table, as the model for a meiolol duo row.

## Assessment

- Evidence: B. Large site, 20.6M champions analysed this patch, one page per patch.
- Reasoning: fair. Column names only; no help text on how Synergy Factor or tier are computed.
- Interests: ads and PLUS upsell; tier letters are U.GG's own.
- Weigh: the layout is trustworthy as what readers get; the sort and tier rule are not documented (rank order is not by duo win rate, see ^f4).

## Findings

- [ux/features] A pair row holds: rank, bot champion and its own win rate, support champion and its own win rate, tier letter, duo win rate (bold), synergy factor, duo pick rate, duo ban rate, matches. Eleven cells, both solo rates beside their champions. ^f1
  > Rank | Bottom | Bottom Win Rate | Support | Support Win Rate | Tier | Duo Winrate | Synergy Factor | Duo Pick Rate | Duo Ban Rate | Matches
- [ux/density] [ux/features] (seen in screenshot) Each pair cell is a champion icon plus name; the solo win rate sits in muted text next to it, the duo win rate is the one coloured, link-blue cell and the tier letter is coloured (S+ gold). Rows are about 54 px high, zebra-less, with 50 rows on the page. ^f2
- [ux/features] (inferred) The gain from the pair is Synergy Factor, shown as signed percentage points: row 1 has solo rates 49.77% and 51.86%, duo 56.19% and +5.38%, which is the duo rate minus the mean of the two solo rates (56.19 - 50.815 = 5.375). ^f3
  > Yunara | 49.77% | Braum | 51.86% | S+ | 56.19% | +5.38% | 0.38% | 10.71% | 7,877
- [ux/features] Order is by Rank, not by duo win rate or synergy: rank 5 (Jhin + Vel'Koz, 53.11%, A) sits above rank 6 (Jinx + Braum, 53.94%, S) and rank 7 (Jinx + Thresh, 53.49%, S+) sits below both. So the rank mixes win rate with something else (likely pick rate, undocumented). ^f4
  > 5 | Jhin | 49.64% | Vel'Koz | 50.91% | A | 53.11% | +2.84% | 0.62% | 4.1% | 12,678
- [ux/uncertainty] Thin pairs are removed, not shown: the 50 rows run down to 6,455 matches, none lower, and there is no confidence interval or "low sample" mark; Matches is the only sample cue. ^f5
- [ux/uncertainty] Tiers are coarse: 50 rows hold 5 S+, 16 S, 27 A and 2 B, so the letter separates little among the top 50. ^f6
- [ux/controls] The scope sits in a Filters bar (Emerald +, Ranked Solo, patch 26.21, region World) and the header says the list covers "bot and mid jungle" duos; the page title names Bot/Support. Rank, tier and sort are not reader-switchable on the page text. ^f7
  > the best champion duos in bot and mid jungle for Patch 26.21
- [ux/controls] Each champion name links to that champion's build page for the role (u.gg/lol/champions/xayah/build/adc); a pair has no page of its own, and the same champion repeats on many rows (Xayah rows 2, 3 and others), so a reader finds "Xayah's best partner" by scanning, not by switching. ^f8
- [ux/features] Checked, not there: no per-pair page, no partner picker, no "with X only" filter on the page text, no confidence interval, no ban rate meaning explained. ^f9

## Read

- `raw/ugg-duo-tier-list.md`: whole page text, 50 rows; first-screen screenshot with the consent banner.

## Not read

- Mid/jungle duo view if one exists behind the Filters bar (not in the page text).
