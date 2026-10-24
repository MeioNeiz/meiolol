---
title: METAsrc LoL Counter Picker Tool
url: https://www.metasrc.com/lol/counter-picker
kind: docs
commit: 
for: [league-apps-feature-matrix, lol-site-ui]
looked: 2026-10-22
depth: listed
relevance: high
grade: C/fair
description: METAsrc's web draft helper, Oct 2026 (patch 26.21): enter bans, allies and enemies, filter by role, get a ranked champion table (tier, Score, win and pick rate, counters, synergies); free, ad-funded, no login
---
# METAsrc LoL Counter Picker Tool

Why: a draft or matchup tool on a stats website, the closest web analogue to meiolol's suggest.

## Assessment

- Evidence: C. Text snapshot has only chrome (the tool is script-built); findings from the screenshot raw/metasrc-counter-picker.png, consent dialog over the top half, no picks entered.
- Reasoning: weak. "Score" is not explained (as on champion pages, [[metasrc-darius#^f5]]).
- Interests: vendor.
- Weigh: inputs and columns are clear; how bans, allies and enemies change the score is unknown.

## Findings

- [draft] [tools/phase] Champ select: a web counter picker for Ranked and Arena; the player types in bans, allies and enemies by hand (no client link), per patch. (seen in screenshot) ^f1
  > LoL Counter Picker Tool, 26.21
- [draft] [ux/features] Output is one ranked table of all champions: role icon, tier (S+), Score, win rate, pick rate, plus Counters and Synergies columns that fill when picks are entered; role tabs filter it. (seen in screenshot) ^f2
- [draft] Sorted by an opaque Score: with nothing entered it is a tier list (Yasuo 67.41 first), so it ranks a "best pick" rather than offering a few options with reasons. (seen in screenshot) ^f3
- [tools] Counter Picker sits in the main nav beside Champions, Tier Lists and Comps. ^f4
- [tools/accounts] [tools/paid] Checked, not there: no login, account, premium or ad-free option; consent dialog with 628 partners. ^f5
- [policy] (inferred) Hand-entered picks keep it outside the client-integration rules, but its intro (screenshot: it "helps you find the best champion") is the wording Riot's product rules steer meiolol away from; meiolol's 3 to 5 options with reasons is the policy-safe variant of the same tool. ^f6

- [ux/layout] 24 Oct (lol-site-ui): at 1280x900 the first screen is ads: a 350 px video
  ad takeover on top, a page skin either side, an ad slot and a sticky bottom banner; the
  tool's inputs start below the fold. Screenshots in
  data/team/2026-10-24-ui/refs/pool-draft/ (gitignored): metasrc-first-screen.png. ^f7
- [ux/controls] Inputs are three type-ahead fields (bans, allies, enemies), six role
  buttons including All, a Reset button and a champion filter; the table has 40 px rows
  with Champion, Role, Tier, Score (sorted), Win %, Pick %, Counters, Synergies
  (screenshot metasrc-counter-table.png). ^f8

## Read

- Screenshot of the empty tool and the page text.

## Not read

- Behaviour with picks entered; Arena mode.
