---
title: 'Wikimedia Pixel: visual and accessibility regression tool (README)'
url: https://raw.githubusercontent.com/wikimedia/pixel/main/README.md
kind: project
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (README intro and usage)
relevance: medium
grade: B/fair
description: Wikimedia's tool that screenshots a reference build (master or release branch) and a patch in Docker and diffs them, plus axe/Pa11y result diffs between the two; runs hourly; still labelled experimental
---
# Wikimedia Pixel (README)

Why: a mature team's working version of the "compare two builds" design.

## Assessment

- Evidence: B. Used by Wikimedia's web team since 2022, hourly public reports; 20 stars,
  last push Dec 2025; self-described experimental.
- Reasoning: fair.
- Interests: none.
- Weigh: confirms reference-vs-patch works in practice; Docker for rendering stability.

## Findings

- [web/qa] Workflow: take reference screenshots from master or a release branch, then
  test screenshots from the patch, and diff. Usage ^f1
  > ### 1) Take reference (baseline) screenshots with `master` or release branch code
- [web/qa] Also diffs accessibility results (axe via Pa11y) between two patches, not
  absolute pass/fail. Intro ^f2
  > this makes it easier to see accessibility changes by comparing the results of accessibility tests between two patches.
- [web/qa] Runs in Docker to remove rendering differences between machines. Quick start ^f3
  > Pixel runs in multiple Docker containers to eliminate inconsistent rendering
- [web/qa] Still labelled an experimental proof of concept, years in. Intro ^f4
  > Pixel is currently an experimental proof of concept working towards becoming a more stable and useful solution.

## Read

- README intro and usage

## Not read

- T302246 motivation; config and scenarios
