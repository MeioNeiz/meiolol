---
title: 'Haroz and Whitney (2012): How Capacity Limits of Attention Influence Information Visualization Effectiveness'
url: https://whitneylab.berkeley.edu/PDFs/Haroz_Whitney_2012_InfoVis.pdf
kind: paper
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: listed (abstract, results of experiments 2 and 3, guidelines, conclusion)
relevance: high
grade: B/strong
description: IEEE InfoVis 2012 perception study: more colour categories on screen slow oddball search and wreck judging how many categories there are (near 100% at one, falling towards chance); grouping by colour largely fixes it; reduce variety in the whole view
---
# Haroz and Whitney (2012): Capacity limits of attention and visualisation

Why: evidence, not opinion, that too many colours hurt comprehension.

## Assessment

- Evidence: B. Peer-reviewed IEEE InfoVis paper (TVCG), well cited; lab experiments with
  small samples (five subjects in the subitizing experiment), effects large and consistent
  across subjects.
- Reasoning: strong. Controlled variety, layout and feature; states the limits.
- Interests: none known.
- Weigh: stimuli are coloured squares, not tables; the transfer to a stat page (more
  hues, scattered, makes the unusual cell harder to spot) is our inference.

## Findings

- [ux/colour] Attention capacity limits strongly affect visualisations, worst for spotting the unexpected. Abstract ^f1
  > Our results show that the severe capacity limits of attention strongly modulate the effectiveness of
  > information visualizations, particularly the ability to detect unexpected information.
- [ux/colour] [ux/density] With colours scattered (random layout), oddball search slows with each extra colour; grouped layouts showed no effect. Experiment 2 ^f2
  > the random blocks showed a
  > clear dependence on the number of visual features used
- [ux/colour] Variety barely matters when you know what you seek; it matters a lot when you don't. ^f3
  > The variety of visual features does not strongly
  > dramatic effect when the search target is not known (is an oddball).
- [ux/colour] Judging the overall picture: near 100% accurate with one colour, falling off sharply as colours are added. Experiment 3 ^f4
  > All accuracies were nearly 100% for one variety but
  > followed a marked, sigmoidal fall-off as variety increased.
- [ux/colour] Too many colour categories make a display feel too overwhelming to examine at all. ^f5
  > using colors to categorize too many types of files
  > makes the information seem too overwhelming to even examine a
- [ux/colour] [ux/layout] A legend or key telling the reader what to look for greatly simplifies finding it. 6.2 ^f6
  > legend, key, or any mechanism that helps a user know the visual
- [ux/colour] Many categories: less is more; show only a couple at a time and let the user switch. 6.3 ^f7
  > 6.3    When there are many categories: Less is more
  > deterministic alternative is to limit the visualization to only show a
- [ux/colour] [ux/density] Conclusion: for hard tasks reduce variety across the whole view, not in small regions. ^f8
  > to reduce variety in the entire view rather than optimizing small
- [ux/colour] (inferred) For meio.lol: a page where colour marks only the few far-from-usual numbers, with all other text neutral, keeps variety near one and lets the unusual cell pop out. ^f9

## Read

- Abstract, introduction, experiment 2 and 3 results, guidelines, conclusion

## Not read

- Experiment 1 detail, methods tables
