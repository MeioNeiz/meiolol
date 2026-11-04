---
status: answered
priority: now
area: stats
tags: [stats, stats/scoring]
description: How should meiolol judge its 80% ranges and point estimates against raw modes in one score: calibration, sharpness, randomised PIT for counts, proper scoring rules and the interval score?
---
# How should meiolol judge its 80% ranges and point estimates against raw modes in one score: calibration, sharpness, randomised PIT for counts, proper scoring rules and the interval score?

Feeds: truth test gate (src/truth.zig, docs/model.md "Lock stacks in the truth test"): one number for "beat 30 days, beat the patch on certainty"; /private/truth (E9)

## Answer

Coverage alone cannot be the gate: a flat PIT and ~80% inside are met by a wide
"climatological" range too, so sharpness has to be judged subject to calibration (C1).
The interval score at alpha = 0.2, IS = (u - l) + 10 (l - y)+ + 10 (y - u)+, is proper and
puts width and misses in one number; a narrower range with nominal coverage can still
lose on it, because it punishes ranges that shrink exactly where uncertainty is highest
(C2, C3). Adding the point estimate gives the weighted interval score with one interval,
WIS = (2/3)(0.5 |y - m| + 0.1 IS), still proper (C10). The log score is strictly proper
but not robust to heavy tails and ignores our ranges (C6). For discrete targets the
non-randomised PIT (Czado et al) gives coverage as Fbar(0.9) - Fbar(0.1) without seed
noise (C4); PIT shapes read U = too narrow, hump = too wide, skew = biased (C5).

Proposal for truth (C11): per kind, score every cell both modes range on the observed
target y with WIS_1, using each mode's predictive range for y (its rate range widened by
the target's own noise, as truth's "in" already does). Headline: skill against each raw
mode, 1 - sum WIS_Meio / sum WIS_ref, on paired cells (C7). Gate: skill > 0 against
both modes in every kind, with a sign test over roughly independent blocks (region x
day origin), not per-cell standard errors (C9). Beside it, the three parts of the score
(width, below, above), so "beat the patch on certainty" shows as a smaller width part
without bigger penalties. Keep PIT coverage per kind as a guard (80% plus or minus a
few points, 10-bin histogram) and report per target-n band, since cells with many
games dominate sums in points (C8). Log loss stays as a secondary accuracy number.

## Claims

- C1: Coverage or a flat PIT does not show a range is good; a wide climatological range
  can match it; width at fixed coverage decides. for: [[gneiting-calibration-sharpness-2007#^f2]], [[gneiting-calibration-sharpness-2007#^f3]], [[gneiting-raftery-scoring-2007#^f5]]
- C2: The interval score at level alpha is proper and scores width and calibration in
  one number. for: [[gneiting-raftery-scoring-2007#^f10]], [[gneiting-raftery-scoring-2007#^f13]], [[bracher-wis-2021#^f2]]
- C3: Nominal coverage with a narrower width can still lose on the interval score.
  for: [[gneiting-raftery-scoring-2007#^f11]], [[gneiting-raftery-scoring-2007#^f12]]
- C4: For discrete targets use a randomised or non-randomised PIT; the non-randomised
  one gives coverage with no seed noise. for: [[czado-count-pit-2009#^f1]], [[czado-count-pit-2009#^f2]], [[czado-count-pit-2009#^f4]], [[bracher-wis-2021#^f12]]
- C5: PIT histogram shapes: U too narrow, hump too wide, skewed biased.
  for: [[gneiting-calibration-sharpness-2007#^f5]], [[czado-count-pit-2009#^f3]], [[bracher-wis-2021#^f12]]
- C6: The log score is strictly proper but not robust: it punishes too-sharp tails
  hard; distance-sensitive scores (CRPS, IS, WIS) suit noisy heavy-tailed settings.
  for: [[gneiting-raftery-scoring-2007#^f6]], [[bracher-wis-2021#^f8]], [[bracher-wis-2021#^f9]], [[bracher-wis-2021#^f13]], [[bracher-wis-2021#^f15]]
- C7: Compare modes on exactly the same cases and aggregate by mean or sum, which keeps
  the score proper. for: [[gneiting-raftery-scoring-2007#^f2]], [[bracher-wis-2021#^f5]]
- C8: Scores in the target's own units are dominated by large or high-variance cells;
  stratify or normalise. for: [[czado-count-pit-2009#^f10]], [[bracher-wis-2021#^f5]], [[bracher-wis-2021#^f14]]
- C9: Test score differences over roughly independent blocks (sign test); Diebold-Mariano
  has no accepted extension for dependent series, and per-cell standard errors overstate
  certainty. Skill scores are improper but harmless at large n.
  for: [[gneiting-calibration-sharpness-2007#^f12]], [[bracher-wis-2021#^f6]], [[gneiting-raftery-scoring-2007#^f4]]
- C10: WIS with one interval and the median is proper and splits into width, below and
  above parts. for: [[bracher-wis-2021#^f3]], [[bracher-wis-2021#^f10]], [[bracher-wis-2021#^f16]]
- C11 (inferred): Truth's gate should be WIS_1 skill against each raw mode per kind,
  with PIT coverage as a guard and the width part as the certainty evidence. from: C1,
  C2, C3, C7, C9, C10

## Disagreements

None between sources. Ours: truth today gates accuracy on log loss (milli-nats) and
certainty on half-width plus PIT; C6 and C11 say one proper interval score does both,
but log loss stays the finer accuracy measure on thin binary targets.

## Open

- Does WIS skill agree with today's verdicts on 16.21 (win rates pass, shares
  under-cover)? Run it in truth before adopting.
- Weight cells by target games or not: weights independent of the forecast keep it
  proper (C8); pick one and say so on the method page.
- Leads: surveillance pit.R (non-randomised PIT code), Diebold and Mariano 1995,
  Gneiting 2011 on point forecasts.
