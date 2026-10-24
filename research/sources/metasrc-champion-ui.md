---
title: METAsrc Darius build page, element by element (24 Oct 2026)
url: https://www.metasrc.com/lol/build/darius
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text and a 1280-wide full-page screenshot)
relevance: medium
grade: B/weak
description: METAsrc champion build page re-read per element: one-line stat strip with role share, build style, counter and duo build pickers, item slot options without games
---
# METAsrc Darius build page, element by element (24 Oct 2026)

Why: lol-site-ui, kind 3. Earlier [[metasrc-darius]] (top-lane URL) covered colour and the
counter cards; this one is the default (no role in the URL) build page. Screenshots in
data/team/2026-10-24-ui/refs/champion/ (gitignored): metasrc-darius-header.png,
metasrc-darius-skills-items.png. Raw is the page's innerText after consent.

## Assessment

- Evidence: B. Long-running site; 181,468 Darius games (all regions, all ranks).
- Reasoning: weak. "Score" unexplained; every section opens with a templated sentence.
- Interests: ad funded.
- Weigh: the one-line strip and the counter/duo build pickers are worth a look; the item
  options lack samples.

## Findings

- [ux/density] Header stats as one text line of label: value pairs, Tier, Win %, Pick %,
  Role %, Ban %, KDA, Games, Score, about 30 px tall across the full width; role share
  sits here rather than under the role icons. (seen in screenshot metasrc-darius-header.png) ^f1
  > Tier: S+ Win %: 50.13% Pick %: 8.73% Role %: 80.95% Ban %: 14.77%
- [ux/controls] Filters default to All Regions and All Ranks, and a second row holds three
  pickers: Build Style (Recommended), "Select a counter build" and "Select a duo build",
  so a matchup or duo build is a dropdown on the build page. ^f2
  > Build Style: Recommended Select a counter build Select a duo build
- [ux/uncertainty] Item 4, 5 and 6 options show four items each with whole-per-cent Win %
  and Buy % and no game counts, so 57% at 4% buy rate looks as solid as 57% at 36%. ^f3
  > Popular item choices for slot 4 on Darius. Win % Buy % 57% 36% 54% 22% 58% 18% 57% 4%
- [ux/density] Skill order as a compact 18-column grid of letter squares coloured per
  ability with the priority (Q > E > W), its win and pick rate beside it, about 340 by 90
  px. (seen in screenshot metasrc-darius-skills-items.png) ^f4
- [ux/layout] Every section card opens with a centred one-sentence summary ("Popular item
  choices for slot 4 on Darius."), about 20 words per card spent on restating the title. ^f5
  > Popular item choices for slot 5 on Darius.

## Read

- raw/metasrc-champion-ui.txt; full-page screenshot at 1280

## Not read

- Runes, Counters, Synergies tabs; phone layout
