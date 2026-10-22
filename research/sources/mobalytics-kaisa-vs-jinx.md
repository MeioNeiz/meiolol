---
title: "Mobalytics: Kai'Sa vs Jinx bot matchup (patch 26.21)"
url: https://mobalytics.gg/lol/champions/kaisa/counters/adc/vs-jinx
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (whole page text)
relevance: medium
grade: B/fair
description: Mobalytics bot lane matchup page; same template as top lane, carry vs carry only, no supports
---
# Mobalytics: Kai'Sa vs Jinx bot matchup (patch 26.21)

Why: whether a bot lane matchup page differs from the top lane one ([[mobalytics-darius-vs-garen]]).

## Assessment

- Evidence: B. Live page.
- Reasoning: weak. Template.
- Interests: vendor.

## Findings

- [ux/features] Same template as top: a templated sentence, the two win rates, ten lane
  rows (level 2 rate, KDA, gold, XP and CS diff at 15, CS per minute, KP, DPM, lane
  kills, damage to structures), a locked tips panel; the only bot change is "Avg. Lane
  Kills" for "Avg. Solo Lane Kills". ^f1
  > Matchup stats based on the 3 952 matches
- [ux/features] Checked, not there: nothing on supports or the 2v2 (no duo, no support
  pairing), although bot lane is decided by four champions. ^f2
- [ux/trust] Lane and game disagree and the page leaves it unexplained: Kai'Sa is 187 gold
  up at 15 and wins level 2 less often (42%), yet loses the game (46.7%); (inferred) a
  scaling story the page could tell but does not. ^f3
  > Kai'Sa has a 46.7% win rate against Jinx in the Bot, which is 3.5% lower than expected win rate of Kai'Sa
- [ux/trust] Failure: perspective flips within one panel. The header (raw table cells)
  says Kai'Sa's win rate is 50.2%, the list under "Kai'Sa matchups" opens with an Overall Average of 49.8%,
  because that list gives the opponents' win rates against Kai'Sa (Jinx 53.3%). ^f4
  > Overall Average 49.8% 51 230
- [ux/uncertainty] Counts beside each opponent in the list; Nilah tops it on 293 games
  (59.0%), ranked by raw win rate. ^f5
  > Nilah 59.0% 293

## Read

- Whole page text

## Not read

- Screenshots (layout matches the top lane page)
