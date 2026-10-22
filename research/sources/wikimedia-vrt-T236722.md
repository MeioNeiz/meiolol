---
title: 'Wikimedia Phabricator T236722: Spike, investigate automated visual regression tools (2019-20)'
url: https://phabricator.wikimedia.org/T236722
kind: thread
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: listed (description and main comment)
relevance: medium
grade: B/fair
description: Wikimedia web team spike: feelings on visual regression testing mixed (maintenance, slow, false positives); two designs, stored baselines or comparing master against the branch live
---
# Wikimedia Phabricator T236722: investigate automated visual regression tools

Why: a mature team's candid view of screenshot test costs.

## Assessment

- Evidence: B. First-hand notes of Wikimedia's web team, citing the parsing team's 60k
  page visual diff run.
- Reasoning: fair. Weighs two designs and the cost.
- Interests: none.
- Weigh: a 2020 opinion; Wikimedia later built Pixel (lead) on the master-vs-branch idea.

## Findings

- [web/qa] Team feelings mixed: maintenance, slow tests, high false positives; treat as
  experimental until proven. Main comment ^f1
  > the general feelings around the usefulness of of visual regression testing is mixed at best with concerns of increased maintenance (see integration tests), slow tests, high rates of false positives
- [web/qa] Two designs: approved baselines to maintain, or compare two live builds
  (master vs branch), no stored screenshots but slower. Main comment ^f2
  > Having a test compare screenshots from two "live instances" (e.g. master vs dev branch).
  > This option appeals to me as it means we would not have to maintain any screenshots
- [web/qa] Parsing team diffed 60k pages across 40 wikis for the Tidy replacement and
  needed a tool to ignore ~1 px vertical whitespace shifts. Main comment ^f3
  > They ran two mediawiki-vagrant lab VMs and tested 60k pages across 40 wikis during the Tidy replacement project
  > they experienced ~1px vertical whitespace differences that they were able to ignore using their Uprightdiff tool.
- [web/qa] (inferred) Before-after on the same Mac fits meiolol: render main and the
  working tree from the same fixture, screenshot both in one run, show diffs; no baseline
  PNGs in git, no cross-machine noise. ^f4

## Read

- Description, Jan 2020 summary comment

## Not read

- Later comments; parent T107588
