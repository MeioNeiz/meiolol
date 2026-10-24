---
title: Overview of WebView2 APIs (Microsoft Learn)
url: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis
kind: docs
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: skimmed (network requests, image capture, background colour, accessibility, memory)
relevance: medium
grade: A/fair
description: Microsoft's feature map of WebView2 APIs by area, with links to the reference
---
# Overview of WebView2 APIs (Microsoft Learn)

Why: does WebView2 have the hooks we would use (serve embedded content, screenshots for
QA, transparency, accessibility, memory control)?

## Assessment

- Evidence: A. Vendor reference, last updated 16 Jun 2026.
- Reasoning: weak. A catalogue; reasons live in linked pages.
- Interests: vendor (Microsoft).
- Weigh: the snapshot shows the .NET tab; the Win32 COM names match
  (ICoreWebView2::add_WebResourceRequested etc.), checked in our spike, not here.

## Findings

- [gui/webview] `WebResourceRequested` intercepts and can answer every request, so the
  host can serve embedded pages and assets from memory. ^f1
  > The `WebResourceRequested` event allows the app to intercept and override all network requests in WebView2.
- [gui/webview] Alternatives for local content: `SetVirtualHostNameToFolderMapping` and
  custom schemes handled through `WebResourceRequested`. ^f2
  > The `CustomSchemeRegistration` allows registration of custom schemes in WebView2 so that the app can handle the `WebResourceRequested` event for requests to those custom scheme URLs
- [gui/webview] Default background colour may be transparent, used when the page sets
  none. ^f3
  > The color can be any opaque color, or transparent.
- [gui/webview] Screenshots: `CapturePreviewAsync` captures the page in a chosen image
  format (useful for our UI checks). ^f4
  > By hosting WebView2, your app can capture screenshots and indicate which format to use to save the image.
- [gui/webview] [gui/a11y] In Win32 apps the WebView shows in the accessibility tree as a
  child of the parent HWND. ^f5
  > By default, WebView2 will show up in the accessibility tree as a child of the parent HWND, for Win32/C++ apps.
- [gui/webview] Memory usage target (low or normal) and `TrySuspendAsync` are listed under
  performance APIs ([[ms-webview2-performance#^f5]]). ^f6
  > Specifies memory consumption levels, such as `low` or `normal`.
- [gui/a11y] Checked, not there: the concepts/accessibility page returns 404; no
  separate WebView2 accessibility guide found. ^f7

## Read

- sections named in depth

## Not read

- the rest of the catalogue (navigation, downloads, printing, permissions)
