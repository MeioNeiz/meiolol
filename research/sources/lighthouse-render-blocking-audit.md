---
title: 'Lighthouse docs: Eliminate render-blocking resources'
url: https://developer.chrome.com/docs/lighthouse/performance/render-blocking-resources
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: medium
grade: A/fair
description: Chrome's doc for the old Lighthouse audit (moved into the Render-blocking requests insight in Lighthouse 13): which links are flagged and the three fixes it recommends
---
# Lighthouse docs: Eliminate render-blocking resources

Why: what Lighthouse counts as a blocking stylesheet and what it tells you to do.

## Assessment

- Evidence: A. Official Chrome docs for the audit; last updated 2019 (page notes the move to the insight).
- Reasoning: fair. Lists fixes, no costs.
- Interests: none.
- Weigh: the flagging rules; the advice is generic.

## Findings

- [seo] [web] Any `<link rel="stylesheet">` without `disabled` and without a non-matching `media` is flagged; `media="all"` counts as blocking. Which URLs get flagged ^f1
  > Does not have a `media` attribute that matches the user's device specifically. `media="all"` is considered render-blocking.
- [seo] [web] Recommended fix: inline the styles needed for first paint in a `<style>` in the head and load the rest asynchronously with preload. How to eliminate render-blocking stylesheets ^f2
  > inline critical styles required for the first paint inside a `<style>` block at the `head` of the HTML page
- [seo] [web] Alternative fix: split the CSS by media query and give each link a `media` attribute, so only matching sheets block first paint. ^f3
  > split up those styles into different files, organized by media query
- [seo] The audit moved into the Render-blocking requests insight as of Lighthouse 13. ^f4
  > This audit has moved into the [Render-blocking requests](https://developer.chrome.com/docs/performance/insights/render-blocking) insight as of Lighthouse 13.

## Read

- Whole page

## Not read

- Linked web.dev render-blocking CSS article
