---
title: 'Correll, Moritz, Heer 2018: Value-Suppressing Uncertainty Palettes'
url: https://idl.cs.washington.edu/files/2018-UncertaintyPalettes-CHI.pdf
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-05
depth: listed (abstract, VSUP design, both experiments, discussion, limits)
relevance: high
grade: B/strong
description: CHI 2018: colour palettes that merge values into fewer, greyer colours as uncertainty grows; two small MTurk studies (24 each) show readers read them as well as normal bivariate maps and avoid the most uncertain cells
---
# Correll, Moritz, Heer 2018: Value-Suppressing Uncertainty Palettes

Why: is a colour that weakens towards grey as uncertainty grows (our faded cells) read
correctly, and does it change decisions?

## Assessment

- Evidence: B. CHI paper by a strong group (Heer, UW IDL); D3 code released
  (github.com/uwdata/vsup) and widely reused; but each experiment had only 24 US MTurk
  participants, on 5x5 heatmaps and a Battleship-style game.
- Reasoning: strong. States its assumptions and when they fail, reports null results
  (no identification gain over standard bivariate maps), a cost (more danger accepted
  in middling cells) and limits.
- Interests: the authors propose VSUPs.
- Weigh: trust "readers can read it and it steers them off the most uncertain cells";
  the effect is modest and the sample small. Fits our dense tables closely: a heatmap
  cell coloured by value and faded by uncertainty.

## Findings

- [ux/colour] [ux/uncertainty] VSUPs give more colour range to values when uncertainty
  is low and less when high; readers weighted uncertainty more than with a normal
  bivariate map. Abstract ^f1
  > VSUPs allocate larger ranges of a visual channel to data when uncertainty is low, and smaller ranges when uncertainty is high.
  > VSUPs encourage people to more heavily weight uncertainty information in decision-making tasks.
- [ux/colour] Design: a quantisation tree; above an uncertainty threshold all values
  map to one root colour, and each step down in uncertainty splits the value range
  again (2 branches, 4 layers = 15 colours). Uncertainty is shown by lighter, less
  saturated colour. VSUP design ^f2
  > Values above a certain uncertainty threshold are mapped to a singular “root” node.
  > Here, we focus on a combination of increasing luminance and decreasing saturation
- [ux/colour] The idea: uncertain values retreat into a grey "confidence fog" while
  certain ones stay prominent; at the top uncertainty level the value cannot be decoded
  at all, by design. Related work, Discussion ^f3
  > creating the effect of uncertain values retreating into a “confidence fog” while highly certain values remain prominent.
  > At high levels of uncertainty, VSUPs have only one output color, and so explicitly prevent any decoding of value.
- [ux/colour] Read correctly: in finding a given (value, uncertainty) cell, VSUPs did no
  worse and no better than standard discrete bivariate maps (no significant effect).
  Identification experiment ^f4
  > We did not find a significant effect for either the legend shape (F(1, 70) = 0.04, p = 0.84) or the quantization scheme (F(1, 70) = 1.4, p = 0.24).
- [ux/colour] One map beats two side by side: superimposed value and uncertainty 58%
  accurate vs 51% for juxtaposed maps; discrete colour bins 63% vs 47% for continuous
  scales, so use a few discrete steps. Identification results, Discussion ^f5
  > (accuracy of 58% vs. 51% for superimposed and juxtaposed charts, respectively)
  > Continuous maps performed the worst of all of our other bivariate map types (47% accuracy vs. 63% accuracy for discrete maps).
  > We advise designers to avoid continuous bivariate color scales when possible, and instead employ discrete scales with a relatively small number of categories.
- [ux/uncertainty] Changes decisions: VSUP users were less likely to bet on very
  uncertain cells, but gambled more on middling ones, which cost a little expected value
  in this game. Prediction experiment ^f6
  > participants using VSUPs were less likely to make guesses with very high uncertainty.
  > avoiding highly uncertain regions, but willing to “gamble” more on regions of middling certainty
- [ux/uncertainty] Binary encodings (error bars, hurricane cones) give binary decisions
  that misreflect the uncertainty; full detail can overwhelm; VSUPs sit between.
  Discussion ^f7
  > These binary encodings for uncertain information, such as error bars for estimates, or “cones of uncertainty” for hurricane paths, result in binary patterns of decision-making that do not accurately reflect the underlying uncertainty in the data
  > VSUPs are in a middle ground between sparse but simple, and dense but complex presentations of uncertainty.
- [ux/trust] Uncertainty should sit in the chart itself, not in tooltips or a distant
  chart. Conclusion ^f8
  > Uncertainty, data quality, or confidence values are often considered separately from the data itself, relegated to tooltips or visually distant supplemental charts.
  > uncertainty information ought to be directly integrated within a shared chart.
- [ux/uncertainty] Limits: assumes uncertain values deserve less impact (wrong for tail
  risks or outlier hunting); a cell's colour is not a significance test. Limitations ^f9
  > and a particular item’s encoding in a VSUP cannot be used as a proxy for a test of statistical significance.
  > VSUPs assume that uncertain values ought to have less visual impact than highly certain values.
- [ux/colour] (inferred) For meio.lol tables: colour a win rate in a few discrete steps
  and merge the steps into one grey as the range widens, so thin rows cannot show a
  strong colour; the fade itself carries the "thin data" message without a range bar.
  Keep exact range and games on hover, not instead of the fade. ^f10

## Read

- Abstract, background on VSUPs, design considerations, both experiments with results,
  discussion, limitations, conclusion.

## Not read

- Example applications section (maps, scatterplots) in detail; the uwdata/vsup code.
