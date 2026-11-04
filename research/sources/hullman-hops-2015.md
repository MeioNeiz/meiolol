---
title: 'Hullman, Resnick, Adar 2015: Hypothetical Outcome Plots Outperform Error Bars and Violin Plots for Inferences about Reliability of Variable Ordering'
url: https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0142444
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: listed (abstract, methods 3.5, results 5.3, discussion 6)
relevance: high
grade: A/strong
description: PLOS ONE 2015, 288 MTurk subjects: animated draws (HOPs) beat error bars and violin plots by a wide margin for "how often is B bigger than A"; similar for one-variable questions
---
# Hullman, Resnick, Adar 2015: Hypothetical Outcome Plots

Why: does a lay reader get "how often A beats B" from two error bars, and what does
better?

## Assessment

- Evidence: A. Peer-reviewed, power analysis up front, 288 US MTurk subjects (96 per
  condition), incentivised; Hullman a leading uncertainty-vis researcher; much cited.
- Reasoning: strong. Pre-stated hypotheses, limits discussed (subject pool, tasks,
  framing as observed samples not sampling distributions).
- Interests: the authors propose HOPs.
- Weigh: the two-variable result is large and on exactly our comparison task; the
  one-variable result is a wash. Plots showed outcome distributions, not intervals of a
  mean, which the authors flag.

## Findings

- [ux/uncertainty] [ux/charts] HOPs (animated individual draws) gave much more accurate
  judgements than error bars and violin plots for two and three quantities; similar for
  one quantity. Abstract ^f1
  > "With HOPs, people made much more accurate judgments about plots of two and three quantities. Accuracy was similar with all three representations for most questions about distributions of a single quantity."
- [ux/uncertainty] With error bars or violins, readers estimating how often one beats the
  other were off by 36 points or more on every task, some answering under 50% when B's
  mean was higher. 6 Discussion ^f2
  > "On no task was the mean absolute error less than 36 percentage points."
  > "Many subjects reported values less than 50%, which are not plausible given that the mean of _B_ was larger than the mean of _A_."
- [ux/uncertainty] The authors' guess: readers swap the question for a simpler one, such
  as the gap between the means. 6 Discussion ^f3
  > "Some may have followed the heuristic of mentally substituting a simpler question, such as the mean difference between _B_ and _A_."
- [ux/uncertainty] Why HOPs work: counting individual outcomes is easier than reasoning
  about probabilities over a whole distribution. 1 Introduction ^f4
  > "HOPs enable viewers to think in _finite terms_ (i.e., counts) about _individual outcomes_ rather than infinite terms (i.e., probabilities) abstracted over entire distributions"
- [ux/uncertainty] Error bars are hard even for experts, not only lay readers. 1 Introduction ^f5
  > "Research shows that even experts fail at making correct statistical inferences from error bars"
- [ux/charts] HOPs did worse on estimating a mean when variance was high. 5.3 ^f6
  > "Animated HOPs performed worse on some types of one-variable trials. One was estimating the mean when the variance was high."
- [ux/charts] Frame rate 400 ms, with pause and step controls and a frame counter. 6.3 ^f7
  > "We use a frame rate of 400ms for our comparative experiment between HOPs and static alternatives."
- [ux/uncertainty] Open: whether outcomes from a sampling distribution (uncertainty in a
  mean, like our win-rate ranges) can be framed for lay readers at all. 6.1 Limitations ^f8
  > "For a lay audience, of course, this would need to be done without reference to sampling distributions. It is not clear whether it is possible to do this effectively."
- [ux/uncertainty] (inferred) Two win-rate ranges side by side will not tell a lay reader
  how likely A beats B; if the comparison matters, state it (a percent) or show draws. ^f9

## Read

- abstract, intro, 3.5 subjects, 5.3 two-variable results, 6 discussion and limits

## Not read

- one-variable result tables in detail; three-variable task
