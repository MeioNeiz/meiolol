---
title: 'Stephen Few: Common Pitfalls in Dashboard Design (2006)'
url: https://www.perceptualedge.com/articles/Whitepapers/Common_Pitfalls.pdf
kind: article
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (the 13 pitfalls, not the ProClarity addendum)
relevance: high
grade: A/strong
description: Stephen Few's white paper listing 13 dashboard design pitfalls (single screen, context, precision, meaningless variety, arrangement, highlighting, decoration, colour), each shown on a real dashboard
---
# Stephen Few: Common Pitfalls in Dashboard Design (2006)

Why: what makes a dense data screen readable rather than overwhelming, from the
canonical dashboard design reference.

## Assessment

- Evidence: A. Few is the recognised authority on dashboard design (Information
  Dashboard Design); this paper condenses it, each pitfall shown on a real product.
- Reasoning: strong. Each rule explained by perception (short-term memory, preattentive
  attention), with the cost shown.
- Interests: the PDF carries a ProClarity (vendor) addendum mapping its product to the
  pitfalls; Few's text itself sells nothing.
- Weigh: trust the principles; numbers (colour blindness share) are his round figures.

## Findings

- [ux/layout] Seeing everything at once on one screen is the point: scrolling or
  splitting data across screens loses comparisons, because short-term memory holds
  only a few chunks. Pitfall 1 ^f1
  > Something critical is sacriﬁced when the viewer must lose sight of some data in order to scroll down or over, or move from screen to screen to see the rest.
- [ux/density] A number without context (compared to what, good or bad, better than
  before) just sits there. Pitfall 2 ^f2
  > context means little. Compared to what? Is this good or bad? How good or bad? Are we on track? Is this better than before?
- [ux/density] Show no more precision than the task needs; extra digits slow readers
  without benefit. Pitfall 3 ^f3
  > Too much detail or measures that are expressed too precisely (for example, $3,848,305.93 rather than $3,848,306 or perhaps even $3.8M) just slow them down without beneﬁt.
- [ux/density] Use the same display form repeatedly when it fits: consistency lets
  readers reuse one reading strategy; variety for its own sake costs effort. Pitfall 6 ^f4
  > consistency in the means of display whenever appropriate allows viewers to use the same perceptual strategy for interpreting the data, which saves them time and energy.
- [ux/layout] Place by importance: the most important data prominent, things to compare
  side by side; logo and navigation in prime space is waste. Pitfall 9 ^f5
  > The most important data ought to be prominent. Data that requires immediate attention ought to stand out.
- [ux/density] When everything is prominent nothing stands out: not all data is equally
  important, and chrome (logo, navigation) should be subdued. Pitfall 10 ^f6
  > When everything is visually prominent, nothing stands out.
  > The logo and navigation controls (the buttons on the left) are prominent, both as a result of their position on the screen and the use of strong borders, but they aren’t data and should therefore be subdued.
- [ux/colour] Too many colours, especially bright ones, overwhelm and colour stops
  highlighting; keep colour subdued and neutral except to highlight. Pitfall 12 ^f7
  > The use of too many colors can be visually assaulting. When overused, color loses its power to highlight what’s most important.
  > It is best to keep colors subdued and neutral, except when you are using color to highlight something as especially important.
- [ux/colour] Colour that encodes nothing (one colour per labelled bar) wastes time as
  readers look for a meaning that is not there. Pitfall 12 ^f8
  > What is the meaning of the separate color for each bar? The correct answer is that the colors mean nothing.
- [ux/layout] Decoration is content the viewer must process before reaching the data.
  Pitfall 11 ^f9
  > decoration, visual content that the viewer must process to get to the data.
- [ux/density] (inferred) For meio.lol: one rule per pitfall maps to a checkable
  guardrail (precision per stat type, one emphasised number per row, chrome in muted
  ink, colour only where it highlights). ^f10

## Read

- Pages 1-14: introduction and pitfalls 1-13

## Not read

- ProClarity addendum (vendor product mapping)
