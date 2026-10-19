---
title: 'cmcrameri: berlin and vik colour map data'
url: https://github.com/callumrollo/cmcrameri
kind: project
commit: 7670e3cd2a4758c1f355539ad07257d40573adcc
for: [dense-stat-layout]
looked: 2026-10-20
depth: code (cmcrameri/cmaps/berlin.txt, vik.txt)
relevance: medium
grade: B/fair
description: Python package shipping Crameri's colour maps as 256-row RGB text files; berlin is the dark-centred blue to red diverging map
---
# cmcrameri: berlin and vik colour map data

Why: exact values of a dark-centred diverging map to base a win-rate scale on.

## Assessment

- Evidence: B. 236 stars, created May 2020, pushed Oct 2026; packages Crameri's
  official maps ([[crameri-colourmaps]]).
- Reasoning: fair (data files).
- Interests: none.
- Weigh: values are Crameri's; sampled by us at 9 points.

## Findings

- [ux/colour] berlin runs from light blue through near-black to light red: the ends are
  the lightest colours, the centre the darkest, so on a dark page the middle fades and
  the extremes stand out. First, middle and last rows: ^f1
  > 0.621082 0.690182 0.999507
  > 0.094260 0.048753 0.039773
  > 0.999873 0.680072 0.679950
  `cmcrameri/cmaps/berlin.txt`
- [ux/colour] (inferred) Sampled at 9 even points berlin reads #9eb0ff #519fd3 #286886
  #14303e #190c09 #3f1201 #7b321c #bc6d61 #ffadad: the arms are blue and red-brown, a
  CVD-safe pair, but the centre is darker than meio.lol's panels (#111214), so cells
  near 50% would look like holes rather than neutral. ^f2
- [ux/colour] (inferred) vik, the light-centred sibling, runs dark blue to near-white to
  dark red (#001261 ... #ece5e0 ... #590008): built for light pages; on dark the 50%
  cells would glare. `cmcrameri/cmaps/vik.txt` ^f3

## Read

- berlin.txt, vik.txt.

## Not read

- Other diverging maps (vanimo, managua, lisbon, tofino).
