---
title: CEF Automated Builds (Spotify CDN index)
url: https://cef-builds.spotifycdn.com/index.html
kind: dataset
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: listed (Windows 64-bit, latest build)
relevance: low
grade: A/fair
description: Official download index of Chromium Embedded Framework binary distributions with file sizes
---
# CEF Automated Builds (Spotify CDN index)

Why: how big is bundling our own Chromium (CEF) on Windows?

## Assessment

- Evidence: A. CEF's official binary host; sizes are the actual archives.
- Reasoning: fair. Describes each archive's contents.
- Interests: none.
- Weigh: sizes are compressed archives with headers and wrapper source; the shipped
  runtime folder is a different number (not measured here).

## Findings

- [gui/webview] Latest build on 24 Oct 2026 is CEF 156.0.14 on Chromium 156.0.8078.48. ^f1
  > 10/24/2026 - 156.0.14+g4fa4ab5+chromium-156.0.8078.48 / Chromium 156.0.8078.48
- [gui/webview] The Windows 64-bit Minimal Distribution (release binaries, headers,
  wrapper source, CMake) is a 166.94 MB compressed archive; Standard is 350.17 MB. ^f2
  > Minimal binary distribution. Includes header files, libcef_dll_wrapper source code, Release build binary files and CMake configuration files.
- [gui/webview] (inferred) Bundling CEF puts us at Electron's size class (hundreds of MB
  unpacked, cf. [[elanis-web-to-desktop-bench#^f2]]) and makes us ship Chromium
  security updates ourselves, which the Evergreen WebView2 runtime does for us
  ([[ms-webview2-distribution#^f4]]). ^f3

## Read

- Windows 64-bit tab, latest build row

## Not read

- older builds, other platforms
