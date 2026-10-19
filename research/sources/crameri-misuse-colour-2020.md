---
title: 'Crameri, Shephard, Heron (2020): The misuse of colour in science communication'
url: https://www.nature.com/articles/s41467-020-19160-7
kind: paper
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (main text, figure captions)
relevance: high
grade: A/strong
description: Nature Communications perspective on perceptually uniform, colour-vision-deficiency friendly colour maps, and how to choose sequential versus diverging
---
# Crameri, Shephard, Heron (2020): The misuse of colour in science communication

Why: the reference for choosing a diverging scale that is fair and colour-blind safe.

## Assessment

- Evidence: A. Peer-reviewed, Nature Communications, widely cited; authors maintain the
  Scientific colour maps ([[crameri-colourmaps]]).
- Reasoning: strong. Explains perceptual uniformity, shows CVD simulations, gives a
  decision guide.
- Interests: promotes the authors' own colour maps (free, open).
- Weigh: aimed at scientific figures; the rules carry over to table cells.

## Findings

- [ux/colour] Rainbow and red-green maps distort data or are unreadable for
  colour-vision deficient readers. ^f1
  > colour maps that visually distort data through uneven colour gradients or are unreadable to those with colour-vision deficiency remain prevalent in science. These include, but are not limited to, rainbow-like and red–green colour maps.
- [ux/colour] Red and green at similar lightness fail for a large share of readers:
  about 8% of men. ^f2
  > Colour maps that include both red and green colours with similar lightness cannot be read by a large fraction of the readership
  > The general estimate is that worldwide 0.5% of women and 8% of men are subject to a colour-vision deficiency
- [ux/colour] Data centred on a meaningful value (here: 50% win rate) needs a diverging
  map that clearly separates the two sides. ^f3
  > If the data is divergent about a central value (e.g., centred about zero), a divergent or a multi-sequential colour map should be chosen that clearly and intuitively distinguishes either side of the axis
- [ux/colour] Perceptual uniformity: equal data steps must look like equal colour steps,
  or some small differences look more important than others. ^f4
  > A perceptually uniform colour map weights the same data variation equally all across the dataspace, while other colour maps (such as rainbow) interpret some small data variation to be more important than others
- [ux/colour] The background's lightness changes how the colours read, so a scale has
  to be chosen for the background it sits on (dark for meio.lol). ^f5
  > Additionally, attention has to be paid to the lightness (i.e., light or dark) of the background on which the colours are displayed.
- [ux/colour] A colour scale needs its legend (colour bar), like an axis needs ticks. ^f6
  > It is imperative to ensure the colour bar is included on all figures where a colour scale is used
- [ux/colour] Do not squeeze or stretch part of a colour map: that distorts like an
  uneven axis would. ^f7
  > parts of a scientifically derived colour map cannot be subsequently deformed by being partly squeezed or elongated
- [ux/colour] Saturated RGB extremes dominate and distract; vividness should follow
  the data, not the palette's corners. ^f8
  > the extreme values in the standard Red-Green-Blue (RGB) are very dominant and can, therefore, distract from the underlying visual message

## Read

- Abstract, problem, box on perception, how to choose (Figs 3 to 6 captions).

## Not read

- Supplementary notes and the figure images (Fig. 6 decision guide).
