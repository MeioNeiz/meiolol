---
title: 'Okabe and Ito: Color Universal Design (CUD), how to make figures colourblind barrier free'
url: https://jfly.uni-koeln.de/color/
kind: article
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (practical points, colourblind vision sections)
relevance: medium
grade: A/fair
description: Masataka Okabe and Kei Ito's classic CUD guide, origin of the Okabe-Ito palette; advice on avoiding red-green and on redundant coding
---
# Okabe and Ito: Color Universal Design (CUD)

Why: the standard reference for colour-blind-safe colour choice.

## Assessment

- Evidence: A. The guide behind the Okabe-Ito palette, the default qualitative palette
  in many tools (R, ggplot2 guides, Wilke's Fundamentals of Data Visualization).
- Reasoning: fair. Practical, aimed at biologists' figures; few numbers.
- Interests: none.
- Weigh: written for light backgrounds and print figures; the palette's hex values are
  in an image on the page, not in the text snapshot (so not quoted here).

## Findings

- [ux/colour] The headline rule: never pair red with green. ^f1
  > do not use the combination of red and green
- [ux/colour] Red-green colour-blind readers confuse red and green of similar
  intensity, so a red-green scale fails exactly where lightness is matched. ^f2
  > Difficult to distinguish colors between red and green with similar intensit
- [ux/colour] Colour-blind readers separate bluish hues well, often better than others,
  which is why blue against orange or red works as a diverging pair. ^f3
  > they tend to be more sensitive to distinguish bluish hues than the non-colorblind people
- [ux/colour] Replace red by magenta (purple) when it must be read against green. ^f4
  > Please use magenta (purple) instead of red
- [ux/colour] Redundant coding: do not let colour carry meaning alone; add shape, label
  or position. ^f5
  > redundant coding

## Read

- Index, most important practical points, how colourblind people see colours.

## Not read

- Palette image with RGB values (known values, unquoted: orange #E69F00, sky blue
  #56B4E9, bluish green #009E73, yellow #F0E442, blue #0072B2, vermillion #D55E00,
  reddish purple #CC79A7).
