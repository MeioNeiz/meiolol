---
title: 'Power BI: Create smart narrative summaries'
url: https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-smart-narrative
kind: docs
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: docs (whole page, Custom mode)
relevance: medium
grade: A/weak
description: Microsoft's auto-generated text summary of a report page or visual: caps per visual and page, dynamic values, empty when nothing stands out
---
# Power BI: Create smart narrative summaries

Why: how a mainstream BI product turns numbers into a few sentences: how many, which
kinds, what happens when there is nothing to say.

## Assessment

- Evidence: A for use (Power BI is the market-leading BI tool, feature since 2020), but
  the page is a how-to, not a method.
- Reasoning: weak. It does not say how "most interesting" is scored, nor any
  significance rule; the closing limitations list is only about unsupported visuals.
- Interests: vendor; the Copilot mode (LLM text) is pushed beside the rule-based one.
- Weigh: take the structure (caps, dynamic values in an editable template, empty
  summary when flat), not the selection rule, which is unpublished. This page says
  "Last updated 09/29/2026" and was written with AI help (its own note).

## Findings

- [ux/features] The narrative visual has two modes: Copilot (LLM-written) and Custom,
  where text is written by hand with dynamic values tied to data fields. So the rule
  based mode is a template with slots, not free text. ^f1
  > Custom mode — Lets you write and format the narrative text manually, using dynamic values tied to fields and measures in your data.
- [ux/features] Auto-generation is capped, so it picks "the most interesting things":
  at most 4 summaries per visual, 16 per page, and it avoids the same kind of summary
  for different visuals. ^f2
  > custom narratives pick the most interesting things to summarize about the visual. Custom mode generates up to four summaries per visual and up to 16 per page.
- [ux/features] Facts it picks are trend direction and growth ("revenue and visits both
  grew ... 72 percent"), the highest and lowest items (city or region with highest
  revenue per transaction) and the expected range of values ("most cities produce less
  than $45 per transaction"). ^f3
  > Power BI automatically analyzes trends to show that revenue and visits both grew. It even calculates growth, which in this case is 72 percent.
  > The custom smart narrative also shows the expected range of values for these metrics.
- [ux/uncertainty] A summary is left empty when the data gives no insight: a high/low
  summary on a flat line is hidden rather than written as "no change". The empty slot
  can fill again under another filter. ^f4
  > A summary is empty when no insights are available. For example, in the sample file's line chart, a summary of high and low values might be empty when the chart's line is flat.
- [ux/layout] The summary is dynamic: it regenerates when the reader cross-filters, and
  the text changes with the data (visits and revenue "have different trends, so the
  summary text is updated"). ^f5
  > A summary is dynamic. It automatically updates the generated text and dynamic values when you cross-filter.
- [ux/features] Where it sits: a text box on the report canvas next to visuals, or an
  on-demand header icon on a visual added "for accessibility purposes, to announce
  results to any assistive technology". ^f6
  > Add it for accessibility purposes, to announce results to any assistive technology.
- [ux/uncertainty] Checked, not there: no sample-size rule, no significance test, no
  hedging words in the generated text; the page describes none. Tables and matrices
  are unsupported visuals. ^f7
- [ux/features] Stated purpose of the text: "key takeaways ... get to key points faster,
  and explain the data to others". ^f8
  > Your audience can use the summaries to understand the data, get to key points faster, and explain the data to others.

## Read

- Whole page (raw/powerbi-smart-narrative.md; first URL guess 404ed, this one is the doc)

## Not read

- Copilot narrative page; the Key influencers and Anomaly detection pages
