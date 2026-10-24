---
title: Process model for WebView2 apps (Microsoft Learn)
url: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model
kind: docs
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: docs (whole page)
relevance: high
grade: A/fair
description: Microsoft's description of which processes a WebView2 app starts and how they tie to the user data folder
---
# Process model for WebView2 apps (Microsoft Learn)

Why: how many processes does a WebView2 window cost us, and are they shared?

## Assessment

- Evidence: A. The vendor's own reference for its runtime; page last updated June 2023.
- Reasoning: fair. States the model, defers the renderer count to Chromium.
- Interests: vendor (Microsoft).
- Weigh: trust for structure; process counts in practice we measure in the spike (Task
  Manager or `OpenTaskManagerWindow`).

## Findings

- [gui/webview] WebView2 uses Edge's (Chromium's) multi-process model. ^f1
  > The WebView2 Runtime uses the same process model as the Microsoft Edge browser.
- [gui/webview] A process group is one browser process, one or more renderers and helpers
  such as GPU and audio. ^f2
  > A single browser process.
  > One or more renderer processes.
  > Other helper processes, such as the GPU process and the Audio service process.
- [gui/webview] Processes are per user data folder: the browser process starts with the
  first WebView2 on a folder, and each extra folder gets its own process set. ^f3
  > If an application makes use of multiple user data folders, a collection of WebView2 Runtime processes will be created for each of these user data folders.
- [gui/webview] Several WebViews on one folder share the browser process; renderers can
  serve frames of several WebViews, depending on site isolation. ^f4
  > the renderer process can serve frames in multiple `CoreWebView2` instances that use the same user data folder, depending on website isolation
- [gui/webview] A user data folder can be shared between applications, with performance
  and management caveats. ^f5
  > A user data folder can be shared by multiple applications, but be sure to consider the implications on performance and management
- [gui/webview] Crashes and hangs of browser or renderer surface as `ProcessFailed`; `Close`
  on the controller shuts processes down. ^f6
  > To react to crashes and hangs in the browser and renderer processes, use the `ProcessFailed` event of `CoreWebView2`.
- [gui/webview] (inferred) A main window plus an overlay window on one environment and
  folder cost one browser, one GPU and (same origin) likely one renderer process, not
  two full sets. ^f7
- [gui/webview] Checked, not there: no process counts or memory figures for a minimal
  app. ^f8

## Read

- whole page

## Not read

- threading model page (STA thread, callbacks on UI thread): matters for our COM calls
- user data folder management page
