---
title: 'Content Selection in Data-to-Text Systems: A Survey (Gkatzia 2016)'
url: https://arxiv.org/pdf/1610.08375
kind: paper
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: docs (whole paper, 6 pages)
relevance: medium
grade: B/fair
description: Survey of how data-to-text systems choose which facts to say: four-module architecture, rule vs trained selection, importance ranking, uncertainty wording
---
# Content Selection in Data-to-Text Systems: A Survey (Gkatzia 2016)

Why: method detail on choosing which numbers to put in a generated summary. No
vendor (Wordsmith, Arria) method page was open; this is the academic stand-in.
The PDF text was extracted with pdftotext (raw/content-selection-d2t-survey.txt).

## Assessment

- Evidence: B. A single-author arXiv survey (Edinburgh Napier), over 30 venues
  reviewed, 2016; not peer-reviewed as posted; short at 6 pages.
- Reasoning: fair. Compares rule-based and trained selection with a strengths table,
  but gives little on exact thresholds.
- Interests: none known.
- Weigh: take the architecture and the "importance value, drop the small clusters"
  idea; it is about time series and clinical or weather text, not stat sites.

## Findings

- [ux/features] Standard architecture: signal analysis finds patterns, data
  interpretation relates them, document planning does content selection (which
  patterns to convey and in what order), then microplanning and realisation write the
  text, "either template based, i.e. canned text, or ... sophisticated methods". ^f1
  > This module decides which of the identified patterns, trends and relations should be conveyed in the generated textual summary, a task known as content selection.
  > which can be either template based, i.e. canned text
- [ux/features] Selection is by an importance value per candidate fact; in BabyTalk
  the summary length is a deciding factor and the smaller clusters of events are
  removed first as "usually irrelevant". ^f2
  > The events are clustered in terms of relevance and the first step of the summarisation dictates the removal of the smaller clusters, because they are usually irrelevant.
- [ux/features] Other rule systems order content: background, overall description, then
  the most significant patterns; and some use threshold-based rules over sensor data. ^f3
  > Most significant patterns
- [ux/uncertainty] Weather text can carry uncertainty by rule: one system follows World
  Meteorological Organisation guidelines for referring to uncertain information, the
  other maps probabilities to ordinary words ("sunny spells") rather than hedges such
  as "likely". ^f4
  > The first approach (WMO-based) accounts for the uncertainty present in weather forecasts and it uses the guidelines (as rules) offered by the World Meteorological Organisation
- [ux/trust] Text beats graphs for non-experts in the studies cited: text descriptions
  "can be more effective, comprehensible and helpful in decision making than the
  corresponding graphical representations", even with uncertain data. ^f5
  > text descriptions of data can be more effective, comprehensible and helpful in decision making than the corresponding graphical representations
- [ux/uncertainty] Open problem as of 2016: data-to-text with uncertain data, and
  communicating uncertainty well. ^f6
  > Can we develop approaches which handle uncertain data?
- [ux/features] Rule-based selection is judged "robust in small domains" and suitable
  for commercial use but expensive, not transferable and growing in rule count with the
  domain; trainable is cheap but can give non-understandable output. ^f7
  > Rule-based - robust in small domains
- [ux/uncertainty] Checked, not there: no numeric significance or sample-size
  threshold for deciding a fact is worth stating; no sports or earnings writing. ^f8

## Read

- Whole PDF

## Not read

- Cited primary papers (Gkatzia et al. 2016a on weather uncertainty; BabyTalk)
