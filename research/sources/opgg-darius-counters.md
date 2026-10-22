---
title: 'OP.GG: Darius counters for top (patch 16.20)'
url: https://op.gg/lol/champions/darius/counters/top
kind: docs
commit: 
for: [league-tools-landscape, dense-stat-layout, champion-matchup-gap]
looked: 2026-10-22
depth: docs (whole rendered page 11 Oct; re-read with 1920x1080 and 390x844 screenshots 22 Oct)
relevance: high
grade: B/fair
description: OP.GG's counter page for one champion: per-matchup win rate, lane kill rate, first tower time, KDA, damage, plus user-written matchup tips (beta), paid coaching (Gigs) and ad-free membership
---
# OP.GG: Darius counters for top (patch 16.20)

Why: what the biggest stats site shows per matchup, and whether any of it is
timeline-derived or teaching content.

## Assessment

- Evidence: B. Largest LoL stats site ([[similarweb-opgg-competitors#^f1]]); live page.
- Reasoning: fair. Numbers shown, not explained.
- Interests: vendor.
- Weigh: "Lane kill rate" and "First tower kill" time need timeline events; the page
  does not define them.

## Findings

- [tools] [data] Per-matchup panel: win rate, lane kill rate, KDA, kill participation, damage, first tower kill time, lane win rate. ^f1
  > 48.21%Lane kill rate51.79%
  > 16'27"First tower kill15'42"
  > 49.70%Lane win rate50.34%
- [data] (inferred) Lane kill rate and first tower time need match-v5 timeline events (kill and building events with timestamps), so op.gg crawls timelines at scale. ^f2
- [learning] [tools] Matchup teaching is crowd-sourced and thin: user-written champion tips (beta) and per-matchup counter tips, with none yet for Darius vs Sett. ^f3
  > User-written champion tips
  > There are currently no tips for this champion.
- [learning] [market] Sells human coaching through its Gigs marketplace ("Lessons", "Challenger Coaching") linked from the champion page. ^f4
  > Rank Up in 3 Days! Challenger Coaching
- [market] Ad-supported with a paid "Remove ads" membership. ^f5
  > ADVERTISEMENT Remove ads
- [tools] Counter list is matchup win rate and games only; per-champion tabs: build, counters, items, synergies, runes, masters build. ^f6
  > [Champion synergies](https://op.gg/lol/champions/darius/synergies/top "Champion synergies")
- [learning] [ux/features] Checked, not there: no gold or XP diff over time, no power-spike or per-minute curve, no explanation of why a matchup wins beyond one-line tips. ^f7
- [ux/density] The matchup panel is a stack of paired bars: Darius's value on the left, the opponent's on the right, one shared bar per stat filled from each end, the larger side in colour (teal for Darius, purple for the opponent) and bold (seen in screenshot opgg-darius-counters-full.png). ^f8
  > 48.21%Lane kill rate51.79%
  > 49.70%Lane win rate50.34%
- [ux/layout] Opponent list in a right-hand sidebar (icon, name, win rate, games) selects which matchup the panel shows; win rates above about 50.5% are blue, others grey (seen in screenshot opgg-darius-counters-full.png). ^f9
- [ux/density] Failure: a 48% against 52% split draws as a nearly half-and-half bar; bars filled from both ends make small gaps look like no gap, and every stat gets the same bar whether it matters or not (seen in screenshot opgg-darius-counters-full.png). ^f10
- [ux/trust] Failure: the panel's last three rows (lane win rate, lane pick rate, ban rate) show the champion's own header numbers on Darius's side, not matchup numbers; same on 11 Oct (49.70%, 6.17%, 12.13%) and 22 Oct (50.86%, 12.52%) ([[opgg-darius-vs-garen#^f3]]). ^f11
  > _Win rate_**49.70%**
  > 12.13%Ban rate2.51%
- [ux/layout] Default opponent is the most played one (Sett, 672 games on 22 Oct): the sidebar sorts by games and the panel opens on its top row; clicking another row switches the panel (seen in screenshot opgg-darius-counters-desk-full.png; raw/opgg-darius-counters/2026-10-22.md). ^f12
  > 50.86%Lane win rate50.52%
- [ux/density] The sidebar shows about 15 opponents in a scroll box of fixed height (to Jayce at 321 games), not the whole list (seen in screenshot opgg-darius-counters-desk-full.png). ^f13
- [ux/density] First 1920x1080 screen: header, tabs, a 130 px ad, mode tabs and an app banner fill the top 750 px; the panel's win rate split and 1 stat row show, the rest is below the fold; page 3,072 px (seen in screenshot opgg-darius-counters-desk-fold.png). ^f14

## Read

- Whole page text

## Not read

- op.gg statistics pages; Gigs marketplace pricing
