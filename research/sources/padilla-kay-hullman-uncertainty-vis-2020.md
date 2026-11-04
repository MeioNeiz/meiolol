---
title: 'Padilla, Kay, Hullman 2020/2022: Uncertainty Visualization (Wiley, Computational Statistics in Data Science, ch. 22)'
url: https://osf.io/ebd6r/download
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: listed (intro, theories table, frequency framing, attribute substitution, boundaries, error bars, semiotics)
relevance: high
grade: A/strong
description: Review chapter (PsyArXiv preprint 2020, Wiley 2022) by three leading uncertainty-vis researchers: four theories with evidence (frequency framing, attribute substitution, boundaries make categories, visual semiotics) and what each implies for display
---
# Padilla, Kay, Hullman: Uncertainty Visualization (review)

Why: one synthesis of what uncertainty-vis research says works, to anchor the other
single studies.

## Assessment

- Evidence: A. Review by the field's leading researchers (Kay created quantile dotplots,
  Hullman HOPs, Padilla the boundary theory); covers only theories with "mounting
  support".
- Reasoning: strong. States caveats (no one-size-fits-all; showing uncertainty need not
  improve trust), alternative-hypothesis testing of ensembles.
- Interests: the authors review partly their own techniques.
- Weigh: a synthesis, so findings repeat the primary studies (Hullman 2015, Kay 2016,
  Fernandes 2018, Hofman 2020); count those as one origin when they agree.

## Findings

- [ux/uncertainty] Showing uncertainty is not guaranteed to help judgements or trust;
  design choices must fit audience and task. Introduction ^f1
  > "there is no one-size-fits-all uncertainty visualization approach guaranteed to improve decisions in all domains, nor even guarantees that presenting uncertainty to readers will necessarily improve judgments or trust"
- [ux/uncertainty] Frequency framing: "1 out of 10" is understood more easily than
  "10%"; icon arrays, quantile dotplots and HOPs use it. Table 22.1 ^f2
  > "The frequentist framing hypothesis has substantial support from studies that find we can relatively automatically and accurately understand frequency formats, whereas probabilities are time consuming and highly error prone"
- [ux/charts] Icon arrays are among the best ways to show a single probability; show
  numerator and denominator as icons in a countable grid, same denominator when
  comparing. Icon arrays ^f3
  > "A substantial body of research demonstrates that icon arrays are one of the most effective ways to communicate a single probabilistic value"
  > "If two or more arrays will be compared, they should use the same denominator for each array"
- [ux/trust] People trust icon arrays more than other common displays. Icon arrays ^f4
  > "other studies have found that people trust icon arrays more than other common visualization techniques"
- [ux/uncertainty] Deterministic construal: readers take error bar ends as real values
  (high and low temperature), even with a key explaining them. Attribute Substitution ^f5
  > "they incorrectly believed that the error bars represented high and low temperatures"
- [ux/uncertainty] Hard boundaries (error bars, the hurricane cone) make readers treat
  inside and outside as different categories; instructions do not fix it. Visual Boundaries ^f6
  > "the boundaries lead people to conceptualize the data as categorical"
  > "Participants’ decisions are influenced by a subconscious categorical interpretation of the cone even when they are given instructions"
- [ux/trust] A hard boundary makes readers assume its level (66%, 95%) is meaningful. Visual Boundaries ^f7
  > "By plotting a hard boundary, viewers assume that the scientists are suggesting that the specific value of the boundary is important."
- [ux/uncertainty] Overlap of two 95% CIs is commonly misread as a significance test,
  even by researchers. Error bars ^f8
  > "the relationship between statistical significance and whether or not two error bars overlap is often misunderstood"
- [ux/colour] Value-suppressing palettes blend a value's colour towards grey as
  uncertainty grows, so users weight uncertainty more in decisions. Visual Semiotics ^f9
  > "the value-suppressing palette blends hues denoting value with gray proportional to how uncertain they are"
  > "users weight uncertainty more heavily using the value-suppressing palettes in a decision task compared to the bivariate color map"
- [ux/uncertainty] Fuzziness, location, value, arrangement, size and transparency were
  rated intuitive signs of uncertainty; but such encodings hurt exact look-up. Visual Semiotics ^f10
  > "They found that fuzziness, location, value, arrangement, size, and transparency were rated as highly intuitive."
  > "for tasks requiring viewers to look up specific values, metaphoric uncertainty can produce worse performance"
- [ux/uncertainty] HOPs force readers to account for uncertainty and accept that less
  likely outcomes happen; frame rates of 400 to 500 ms work best. Hypothetical outcome plots ^f11
  > "Research suggests that frame rates of 400 to 500ms tend to perform best."
- [ux/colour] (inferred) For dense meio.lol tables, fading a cell's win-rate colour
  towards grey as its range widens (value-suppressing) shows thin data without an extra
  column, and stops readers trusting a bright thin cell. ^f12
- [ux/uncertainty] (inferred) Drawing an 80% range as a capped bar invites "inside is
  fine, outside impossible" and "the ends are real values"; a soft gradient or dots
  avoids the hard edge. ^f13

## Read

- introduction, design space, theories table, frequency framing (icon arrays, quantile
  dotplots), attribute substitution (HOPs), visual boundaries (cone, ensembles, error
  bars), visual semiotics, general discussion (start)

## Not read

- design space details (time, hybrid), bibliography
