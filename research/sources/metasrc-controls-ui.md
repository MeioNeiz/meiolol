---
title: 'METAsrc: dropdown filter rows, summary text toggle, search (Ahri)'
url: https://www.metasrc.com/lol/champions/ahri/build
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (filter rows, rank dropdown open, search with "j4")
relevance: medium
grade: B/weak
description: METAsrc's champion page controls, Oct 2026: two rows of large caret dropdowns (patch, region, rank; build style, counter build, duo build) plus a show/hide toggle for the summary paragraph
---
# METAsrc: dropdown filter rows, summary text toggle, search (Ahri)

Why: a site that uses dropdowns for everything, for meio.lol's filter bar. Screenshots in
data/team/2026-10-24-ui/refs/controls/ (metasrc-*.png). Raw is the page's rendered text
(the fetch got only the footer).

## Assessment

- Evidence: B. Live page through real Chrome, 24 Oct 2026; a long-running LoL site.
- Reasoning: weak. No rationale.
- Interests: vendor; a video ad took the first screen.
- Weigh: the summary toggle is a small good idea; the dropdown wall is not.

## Findings

- [ux/controls] Two rows of 40 px caret dropdowns, each ~210 px wide: Patch 26.21, All
  Regions, All Ranks; then Build Style (Recommended, with rune icons), "Select a counter
  build", "Select a duo build". Six dropdowns before any data. ^f1
  > Select a counter build
- [ux/controls] A labelled two-button toggle "Summary Text" (eye, crossed eye) hides the
  generated paragraph above the stats: the site admits its prose is optional. Screenshot 24 Oct. ^f2
  > We've analyzed 215,781 Ahri games
- [ux/controls] Rank dropdown: All Ranks, Gold+, Platinum+, Emerald+ ... with emblems. Screenshot 24 Oct. ^f3
- [ux/controls] Checked, not there: "j4" in the header search gives "No Results". Screenshot 24 Oct. ^f4

## Read

- Ahri build page filter rows, rank dropdown, search "j4"

## Not read

- Phone, counter build dropdown contents
