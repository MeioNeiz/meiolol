---
title: Performance best practices for WebView2 apps (Microsoft Learn)
url: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/performance
kind: docs
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: docs (whole page)
relevance: high
grade: A/fair
description: Microsoft's startup, memory, CPU and interop advice for WebView2 apps, including the memory target and suspend APIs
---
# Performance best practices for WebView2 apps (Microsoft Learn)

Why: what does WebView2 cost in memory and startup, and what can we do about it while
the app idles beside a game?

## Assessment

- Evidence: A. Vendor reference.
- Reasoning: fair. Gives practices and the reasons, no numbers at all.
- Interests: vendor (Microsoft).
- Weigh: the per-control wording conflicts with the process-model page, which ties
  processes to the user data folder ([[ms-webview2-process-model#^f3]]); the sharing
  advice here agrees with the latter. Measure.

## Findings

- [gui/webview] Microsoft states plainly that each control launches several engine
  processes, adding memory and startup cost. ^f1
  > WebView2 uses Edge's multi-process architecture, so each control launches multiple browser engine processes that add memory and startup overhead.
- [gui/webview] Cold start (spinning up processes and caches) is a noticeable delay;
  Microsoft advises native Win32 for splash screens and simple dialogs. ^f2
  > On a cold launch, WebView2 must spin up its processes and disk caches, which can introduce a noticeable delay
  > To render splash screens or simple dialogs, use lightweight XAML or Win32 screens instead of WebView2.
- [gui/webview] If Edge of the same version is already running, the binaries are already
  in memory and launch is faster. ^f3
  > If Microsoft Edge and WebView2 versions match, and Microsoft Edge is running, the required WebView2 binaries are already in memory, improving launch performance.
- [gui/webview] Share one `CoreWebView2Environment` across all controls to save memory. ^f4
  > To save memory, use one `CoreWebView2Environment` across all WebView2 controls in an app
- [gui/webview] Memory APIs: `MemoryUsageTargetLevel = Low` on inactive WebViews may drop
  caches or swap to disk; `TrySuspendAsync` suspends the renderer and pauses scripts;
  both best-effort. ^f5
  > Set `MemoryUsageTargetLevel = CoreWebView2MemoryUsageTargetLevel.Low` on inactive WebViews to reduce memory usage
  > call `CoreWebView2.TrySuspendAsync()` to suspend the renderer process, which pauses scripts and further decreases resource use.
- [gui/webview] GPU rendering is on by default and matters for performance, at the cost
  of driver memory and buffers. ^f6
  > The use of the GPU by WebView2 is critical for performance. GPU drivers and additional buffers must be allocated, which requires additional memory.
- [gui/webview] Prefer static HTML for the first paint over a single-page-app framework. ^f7
  > Prefer sending static HTML initially, because it usually loads, parses, and renders faster than JavaScript.
- [gui/webview] Prefer web messages over host objects for host and page interop: faster
  in memory and time. ^f8
  > Web messages tend to be faster than host objects, because of both memory usage and time
- [gui/webview] Long-running pages can accumulate state; Microsoft suggests periodic
  refresh to return to a clean baseline. ^f9
  > Periodically refresh the WebView2 instance.
- [gui/webview] (inferred) Our server-rendered HTML from tpl plus small wasm fits this
  advice (static first paint, web messages for LCU events). ^f10
- [gui/webview] Checked, not there: no memory or startup figures for a minimal page. ^f11

## Read

- whole page

## Not read

- overview-features-apis (memory usage target, suspend details)
