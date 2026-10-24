---
title: dvui accessibility (readme-accessibility.md, README, AccessKit dependency)
url: https://raw.githubusercontent.com/david-vanderson/dvui/275c248f6a2a80f92723ac93242310e16201a49b/readme-accessibility.md
kind: docs
commit: 275c248f6a2a80f92723ac93242310e16201a49b
for: [desktop-toolkit]
looked: 2026-10-24
depth: code (readme-accessibility.md, README.md Accessibility section, build.zig.zon)
relevance: high
grade: B/fair
description: How dvui exposes widgets to screen readers through AccessKit, per-widget support table, and its limits
---
# dvui accessibility (readme-accessibility.md, README, AccessKit dependency)

Why: can a dvui app be read by Narrator or NVDA on Windows, and at what cost?

## Assessment

- Evidence: B. dvui is a real but small project ([[dvui-repo]]); the doc is the author's
  own account, with a frank widget-by-widget status table.
- Reasoning: fair. Says what the app must do and where AccessKit falls short.
- Interests: project's own docs.
- Weigh: opt-in build flag; AccessKit comes as prebuilt accesskit-c 0.23.0 libraries
  (Rust inside), so check cross-compiling from macOS to Windows with it before relying
  on it.

## Findings

- [gui/a11y] dvui exposes widgets to OS accessibility APIs through AccessKit. `readme-accessibility.md` ^f1
  > DVUI implements this part of accessibility through the [AccessKit](https://github.com/AccessKit/accesskit) toolkit
- [gui/a11y] Opt-in at build time, static or shared; on Windows all backends except
  raylib static. `readme-accessibility.md` ^f2
  > Use `-Daccesskit=static` or `-Daccesskit=shared` to enable AccessKit support.
  > Windows - Support for all backends, except raylib static due to symbol clashes.
- [gui/a11y] Node cost only when a screen reader activates the OS API. `readme-accessibility.md` ^f3
  > The overhead of creating AccessKit nodes is only incurred when the operating system's accessibility API is activated by a screen reader or similar application.
- [gui/a11y] The app must label images and inputs and test tab order; dvui cannot infer
  intent. `readme-accessibility.md` ^f4
  > DVUI doesn't know your application's intent or any semantic details about the UX, so it is not possible to automate everything.
- [gui/a11y] Gaps: plot widget not readable, reorder widget unsupported, scroll bars
  read-only through an AccessKit bug, text entry partial. `readme-accessibility.md` ^f5
  > | PlotWidget | .group, .image | N | N/A? | N | Labels image with title of plot. Labels plot widget as a plot. |
  > | ReorderWidget | null | N | N | Y | Not currently supported. Unlikely that interaction will work? |
- [gui/a11y] The author calls AccessKit young, with partial platform features. `readme-accessibility.md` ^f6
  > AccessKit is still a relatively new and evolving library.
- [gui/a11y] Beyond screen readers: text is left-to-right only, no grapheme clusters, no
  OS high-contrast integration. `README.md` ^f7
  > No right-to-left or mixed text direction
- [gui/a11y] AccessKit is fetched as the prebuilt accesskit-c 0.23.0 release, lazily. `build.zig.zon` ^f8
  > .url = "https://github.com/AccessKit/accesskit-c/releases/download/0.23.0/accesskit-c-0.23.0.zip",
- [gui/a11y] (inferred) dvui can reach screen readers, ImGui cannot ([[imgui-a11y-8022#^f1]]);
  a WebView2 page gets Chromium's mature accessibility tree for free
  ([[ms-webview2-api-overview#^f5]]). ^f9

## Read

- readme-accessibility.md (all), README Accessibility section, build.zig.zon dependency

## Not read

- src/AccessKit.zig (bindings), dx11 backend AccessKit wiring
