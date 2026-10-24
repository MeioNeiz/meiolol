---
title: What is Tauri? (Tauri v2 docs)
url: https://v2.tauri.app/start/
kind: docs
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: docs (whole page)
relevance: low
grade: B/weak
description: Tauri's own introduction: system webview instead of a bundled engine, with its minimal app size claim
---
# What is Tauri? (Tauri v2 docs)

Why: the vendor's own size figure, to set beside the independent benchmark.

## Assessment

- Evidence: B. Widely used framework (DraftGap ships on it, [[draftgap]]); the figure is
  a vendor claim without method.
- Reasoning: weak. One sentence, no measurement shown.
- Interests: vendor (Tauri).
- Weigh: download size only; says nothing of memory, where the independent benchmark
  finds no saving on Windows ([[elanis-web-to-desktop-bench#^f3]]).

## Findings

- [gui/webview] (claim) Tauri says a minimal app can be under 600 KB because it uses the
  system webview and bundles no browser engine. ^f1
  > A Tauri app only contains the code and assets specific for that app and doesn’t need to bundle a browser engine with every app. This means that a minimal Tauri app can be less than 600KB in size.
- [gui/webview] Checked, not there: no memory or startup claims on this page. ^f2

## Read

- whole page

## Not read

- concept/size page (build profile tuning)
