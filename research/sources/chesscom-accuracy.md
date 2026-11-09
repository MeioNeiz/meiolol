---
title: 'Chess.com Help: How is accuracy in Analysis determined? (CAPS2)'
url: https://support.chess.com/en/articles/8708970-how-is-accuracy-in-analysis-determined
kind: docs
commit:
for: [postgame-review-compare]
looked: 2026-11-06
depth: docs (whole article)
relevance: high
grade: A/fair
description: Chess.com help article (Jun 2025) on Accuracy: CAPS2 rescaled so most games land 50 to 95, like a school test, because CAPS v1 made low scorers feel bad and high scores drew cheating claims
---
# Chess.com Help: How is accuracy in Analysis determined?

Why: the headline number on the summary screen, and why its scale was chosen.

## Assessment

- Evidence: A. Vendor help page; the figure comparing CAPS and CAPS2 is an image, not in
  the raw.
- Reasoning: strong for a help page: names the problem v1 caused and the fix.
- Interests: vendor.
- Weigh: the "feel" reasoning is the useful part; no formula given (compare
  [[lichess-accuracy]], which gives one).

## Findings

- [ux/postgame] Accuracy is closeness to engine best play against the opponent's actual
  moves, 100 being perfect. ^f1
  > Accuracy is a measurement of how closely you played to what the computer has determined to be the best possible play against your opponent's specific moves.
- [ux/trust] The first scale (CAPS v1) spread 0 to 100 over the human range, so weak
  games scored single digits and near-perfect ones 99.9. ^f2
  > So, scoring perhaps 40% 'Best' moves, which is very low, was equal to single digits on CAPS.
- [ux/trust] That made low scorers feel bad and drew cheating accusations at the top, so
  CAPS2 was built to feel like a school test grade. ^f3
  > This made some people feel bad (on the low end), and led to a lot of cheating allegations (on the high end).
  > The new Accuracy scores, based on CAPS2, replicate the feeling of being graded on a test in school.
- [ux/trust] Most scores now land between 50 and 95. ^f4
  > You will notice that the majority of scores now fall mostly between 50 and 95
- [ux/trust] Their reason for the rescale: even low-rated players make many best moves. ^f5
  > most chess players - even low-rated ones - make a lot of the best moves!

## Read

- Whole article.

## Not read

- The CAPS vs CAPS2 histogram (image only).
