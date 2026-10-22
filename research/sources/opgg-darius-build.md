---
title: 'OP.GG: Darius build for top (patch 16.20)'
url: https://op.gg/lol/champions/darius/build/top
kind: docs
commit: 
for: [dense-stat-layout, champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text and fold and full-page screenshots at 1440 on 20 Oct; re-read at 1920x1080 and 390x844 on 22 Oct)
relevance: high
grade: B/fair
description: OP.GG's champion build page: rune grid with win rate, pick rate and games under each rune, faded when rarely picked; spells, skills and item tables with pick rate, games and win rate, win rate coloured only when notable
---
# OP.GG: Darius build for top (patch 16.20)

Why: the biggest stats site's champion page; how it marks which of many numbers matter.

## Assessment

- Evidence: B. Largest LoL stats site ([[similarweb-opgg-competitors#^f1]]); live page.
- Reasoning: weak. Layout only.
- Interests: vendor (ads, membership, desktop app).
- Weigh: the snapshot kept some table HTML, so class names are real; colours otherwise
  from screenshots (data/team/2026-10-19-night/design-shots/opgg-darius-build*.png).

## Findings

- [ux/density] Numbers are set in tabular figures (Tailwind `tabular-nums`), small (`text-xs`), with the game count in grey under the pick rate (class names in the snapshot HTML, raw line 148; seen in screenshot opgg-darius-build-full.png). ^f1
- [ux/colour] Win rate is grey by default and switches to the brand blue only when notable, so colour marks exceptions rather than painting every cell (classes text-gray-500 against text-main-600 in the snapshot HTML; seen in screenshot opgg-darius-build-full.png). ^f2
- [ux/density] Rune grid: every rune shows win rate, pick rate and games stacked under its icon; runes picked under about 2% are drawn faded (icon and numbers dimmed), the common ones bright, so pick rate is encoded twice, as number and as opacity (seen in screenshot opgg-darius-build-full.png). ^f3
- [ux/layout] Sidebar "Strong against" and "Weak against" strips of five icons with win rate and games, the counters page in miniature (seen in screenshot opgg-darius-build-full.png). ^f4
- [ux/uncertainty] Failure: sixth-item rows show 55.10% on 49 games and 52.38% on 21 games in the same blue as 60.76% on 1,534; the faded-when-rare treatment of runes is not used for items (seen in screenshot opgg-darius-build-full.png). ^f5
- [ux/features] Skill order drawn as a row of 15 small letter squares coloured per ability (Q blue, W teal, E orange, R filled), compact enough to sit in one table row (seen in screenshot opgg-darius-build-full.png). ^f6
- [ux/layout] Section order (re-read 22 Oct at 1920x1080): filter bar (role share chips, rank, class, vs. counter, region, patch) above the header; header with portrait, tier, ability icons, win, pick and ban rate with trend arrows and user-written tips; a tab row (Build, Counters, Items, Champion synergies, Runes, Masters build, Skills, Tips, Trends, Pro builds); a 130 px ad; mode tabs; an app banner; AI question chips; then a 740 px main column (runes, spells, skill order, item builds, combos, laning tips) beside a 330 px sidebar (counters, synergies, mastery ranking, skins ranking) (seen in screenshot opgg-darius-build-desk-full.png; raw/opgg-darius-build/2026-10-22.md). ^f7
  > Darius mastery ranking· EUW
  > Darius Laning tips (0)
- [ux/density] First 1920x1080 screen: the build itself starts at about y 815; above the fold sit 3 headline numbers, the two rune page tabs (pick rate, games, win rate each), one row of the rune grid and 10 counter icons with win rate and games: about 40 numbers, most of them the sidebar's (seen in screenshot opgg-darius-build-desk-fold.png). ^f8
- [ux/colour] Qualifies ^f2: on 22 Oct every win rate above 50% is blue and those below grey, whatever the sample, so blue marks above-even, not notable: sixth item 100.00% on 4 games is blue, starter 49.32% on 4,345 games grey (seen in screenshot opgg-darius-build-desk-full.png). ^f9
  > **100.00%**4 Games
- [ux/features] The item section is starter items and boots side by side (2 rows each), five three-item core builds with pick rate, games and win rate, then fourth, fifth and sixth item columns of five rows each (seen in screenshot opgg-darius-build-desk-full.png). ^f10
- [ux/features] The sidebar's Top Darius Synergies box (four role tabs, three rows) and the Darius combos box rendered empty on 22 Oct, and mastery ranking said no data: three sidebar boxes of chrome with nothing in them (seen in screenshot opgg-darius-build-desk-full.png). ^f11
- [ux/density] Phone (390x844): the first screen is header, filters, user tips, the three headline numbers and the tab row; no build content (seen in screenshot opgg-darius-build-phone-fold.png). ^f12
- [ux/features] AI question chips above the runes ("How difficult is this champion?", "What is the ranking of this champion?") lead to OP.GG's assistant (seen in screenshot opgg-darius-build-desk-fold.png). ^f13

## Read

- Page text and the table HTML that survived; screenshots at 1440 wide

## Not read

- Mobile layout; hover tooltips
