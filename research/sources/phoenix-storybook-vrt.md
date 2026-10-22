---
title: 'phoenix_storybook v1.5 docs: Visual Regression Testing'
url: https://phoenix-storybook.hexdocs.pm/testing.html
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (whole page)
relevance: low
grade: B/fair
description: Phoenix (Elixir server-rendered) storybook exposes a chrome-free endpoint rendering every component story, meant to be screenshotted by a visual diff tool
---
# phoenix_storybook v1.5 docs: Visual Regression Testing

Why: how Phoenix's component gallery supports visual checks.

## Assessment

- Evidence: B. Main Phoenix component storybook, since July 2022, 882 stars, active.
- Reasoning: fair; short.
- Interests: none.
- Weigh: confirms the bare "all stories on one page" endpoint pattern.

## Findings

- [web/qa] Unit tests don't catch visual regressions; screenshot comparison does.
  Intro ^f1
  > While we still encourage you writing regular unit test for your components, this doesn't protect you against visual regressions.
- [web/qa] It serves stories without the storybook UI, singly or as a range, for a
  screenshot tool to capture. ^f2
  > This library provides you a dedicated endpoint to output your stories (only components' stories) without the storybook main UI:
- [web/qa] Recommends a hosted tool (Percy) for the diffing. ^f3
  > For this we recommend using a dedicated tool such as [percy.io](https://percy.io/).

## Read

- Whole page

## Not read

- Component stories guide (variations, variation groups): raw/phoenix-storybook-stories
