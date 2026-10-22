---
title: LoLalytics Kai'Sa bottom build page (sections and layout, 22 Oct 2026)
url: https://lolalytics.com/lol/kaisa/build/
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (whole page: text, rendered text with positions, 1920x1080 screenshots)
relevance: high
grade: B/weak
description: LoLalytics champion page for a bot laner, read to see what changes from a top laner's page (Darius) and where a bot player's lane info sits
---
# LoLalytics Kai'Sa bottom build page (sections and layout, 22 Oct 2026)

Why: champion-matchup-gap. Does the page adapt to a bot laner (support synergy, lane
opponent first), or is it the Darius page with other numbers? Section by section notes are
in [[lolalytics-darius-build]] (^f13 to ^f28); this note records what differs.

Raw: lolalytics-kaisa-build.md (page text) and .dom-1920x1080.txt (every rendered text node
with page y, x, font size). Screenshots kaisa-build-1920-fold.png, -full.png and segments
in the session scratchpad shots/lolalytics/ (viewport set to 1920x1080 through `browse`'s
browser module; `browse shot` itself is fixed at 1440x1000).

## Assessment

- Evidence: B. Live page of a major stats site, 62,013 Emerald+ games for Kai'Sa bottom on
  patch 16.21.
- Reasoning: weak. Layout has no stated rationale; definitions only in hover tooltips.
- Interests: ad funded (ad slot beside the hero, a 100 px ad band under the build block).
- Weigh: identical template to Darius; trust it as what lolalytics shows, not as what
  players need.

## Findings

- [ux/layout] Same template as the top-lane page: same filter bar, hero, 8-figure grid,
  build block, trend charts, counter strips, item and rune tables; nothing specific to a
  bot laner (no support pairing in the build block, no duo section). (seen in screenshots
  kaisa-build-1920-*.png) ^f1
  > Kai'Sa bottom has a 51.17% win rate in Emerald+ on Patch 16.21 coming in at rank 7 of 52
- [ux/trust] Rank is within the role (7 of 52 bottom champions vs Darius 4 of 112 top), so
  the same "Rank" tile means different denominators on different pages. ^f2
  > y=456 x=904 16px: 7
  > y=456 x=925 16px: 52
- [ux/trust] The hero ring shows an unlabelled percentage (57% here, 77% on Darius) with no
  legend or tooltip found. ^f3
  > y=214 x=697 16px: 57%
- [ux/layout] The five counter strips run in fixed role order top, jungle, mid, bot,
  support, so for a bot laner the lane opponents are the fourth strip (y 1935), about two
  screens down, after the enemy top, jungle and mid strips. Support matchups are the
  fifth. (seen in screenshot kaisa-build-1920-full-s1.png; role icons, no text) ^f4
  > y=1935 x=495 12px: Counter
- [ux/features] Support synergy exists only behind the Synergy tabs (Common Teammates,
  Good Synergy, ...) in the same control as counters; not opened (clicking a tab emptied
  the strips in the headless browser). ^f5
  > Common Teammates
- [ux/features] Checked, not there in this render: Win Rate vs Game Length and Game Length
  Distribution charts, both present on the Darius page and on the Kai'Sa vs Jinx page;
  their slot may be ad- or load-dependent. ^f6
- [ux/density] First screen at 1920x1080: about 71 numeric figures, same as Darius (70);
  page 5,682 px. ^f7
  > kaisa/build/ at viewport 1920x1080, 2026-10-22 ... height 5682

## Read

- raw/lolalytics-kaisa-build.md and .dom-1920x1080.txt, whole page
- Screenshots: fold and whole page at 1920x1080

## Not read

- Synergy tab contents (support pairing): needs a click the headless session did not render
- Phone layout (taken for Darius only, [[lolalytics-darius-build#^f27]])
