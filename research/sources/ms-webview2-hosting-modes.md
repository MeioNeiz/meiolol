---
title: Windowed vs. Visual hosting of WebView2 (Microsoft Learn)
url: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/windowed-vs-visual-hosting
kind: docs
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: docs (whole page)
relevance: high
grade: A/fair
description: Microsoft's comparison of WebView2's three hosting modes (HWND, Window to Visual, DirectComposition Visual)
---
# Windowed vs. Visual hosting of WebView2 (Microsoft Learn)

Why: can a WebView2 window be composited (transparent, overlay-like), and what does each
hosting mode make us handle (input, DPI, accessibility)?

## Assessment

- Evidence: A. Vendor reference, last updated 27 May 2026.
- Reasoning: fair. Lists costs per mode.
- Interests: vendor (Microsoft).
- Weigh: says nothing about transparent top-level windows directly; that comes from
  DefaultBackgroundColor ([[ms-webview2-api-overview#^f3]]) plus our own window styles.

## Findings

- [gui/webview] Three modes: Windowed (an HWND, OS routes input), Window to Visual, and
  Visual (app forwards input). ^f1
  > There are three options for hosting the Microsoft Edge WebView2 control in your app:
- [gui/webview] Windowed hosting is the recommended start and handles input, focus,
  tabbing and accessibility for you. ^f2
  > Windowed hosting allows for a solution that quickly displays web content without having to implement functionality for inputs, outputs, and accessibility.
- [gui/webview] Windowed hosting can hit DPI issues when apps with different DPI awareness
  share a user data folder. ^f3
  > Windowed hosting mode can run into DPI issues in some scenarios
- [gui/webview] Visual hosting renders into DirectComposition or Windows.UI.Composition
  visuals; Window to Visual uses `IDCompositionVisual` behind an HWND, switched on by an
  environment variable. ^f4
  > The Windows graphics APIs that expose this functionality and are relevant to WebView2 are `DirectComposition` and `Windows.UI.Composition`.
  > the environment variable `COREWEBVIEW2_FORCED_HOSTING_MODE` must be set to the value `COREWEBVIEW2_HOSTING_MODE_WINDOW_TO_VISUAL`
- [gui/webview] Visual hosting sends no mouse, touch or pen input to the WebView unless the
  app forwards it, and the app must manage scaling. ^f5
  > no spatial inputs (such as mouse, touch, or pen) are sent to the WebView2 control, unless the app manages such input.
- [gui/webview] All hosting modes work wherever WebView2 does. ^f6
  > All hosting modes are supported wherever WebView2 is supported.
- [gui/webview] (inferred) For a champ select window beside the client, Windowed hosting
  suffices; Visual hosting is the route if a later always-on-top panel needs per-pixel
  transparency with click-through regions decided by our code. ^f7
- [gui/webview] Checked, not there: nothing on layered (`WS_EX_LAYERED`) or
  always-on-top windows, nor on drawing over a fullscreen game. ^f8

## Read

- whole page

## Not read

- linked composition API lists in the API overview
