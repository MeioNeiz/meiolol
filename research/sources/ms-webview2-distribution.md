---
title: Distribute your app and the WebView2 Runtime (Microsoft Learn)
url: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution
kind: docs
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: docs (whole page)
relevance: high
grade: A/fair
description: Microsoft's guide to shipping the WebView2 Runtime (Evergreen or Fixed Version) and the loader with an app
---
# Distribute your app and the WebView2 Runtime (Microsoft Learn)

Why: is the runtime already on players' PCs, what must we ship, and how do updates land?

## Assessment

- Evidence: A. Vendor reference, last updated 15 Oct 2025.
- Reasoning: fair. Explains why apps must not rely on the Edge browser itself.
- Interests: vendor (Microsoft).
- Weigh: "vast majority" of Windows 10 is unquantified; a gaming audience on home
  Windows 10/11 should be near the top end, but keep the presence check.

## Findings

- [gui/webview] The runtime ships with Windows 11; most Windows 10 devices already have
  it; a few don't, so apps should check and install if missing. ^f1
  > The Evergreen WebView2 Runtime will be included as part of the Windows 11 operating system.
  > The vast majority of Windows 10 devices have the WebView2 Runtime installed already
  > A small number of Windows 10 devices don't have the WebView2 Runtime installed.
- [gui/webview] Missing runtime: a roughly 2 MB bootstrapper downloads and installs it,
  per-user without elevation. ^f2
  > _WebView2 Runtime Bootstrapper_ is a tiny (approximately 2 MB) installer.
  > If you don't run the installer from an elevated process or command prompt, the Runtime will be installed as _per-user_.
- [gui/webview] Presence check: a registry key under EdgeUpdate\Clients or
  `GetAvailableCoreWebView2BrowserVersionString` returning null. ^f3
  > Run [GetAvailableCoreWebView2BrowserVersionString]
- [gui/webview] Evergreen updates follow Edge Stable's cadence and arrive automatically;
  all Evergreen apps share one copy, hard-linked to Edge's binaries when versions match. ^f4
  > The Runtime generally provides the same web platform capabilities and update release cadence as the Stable channel of the Microsoft Edge browser
  > All WebView2 apps that use the Evergreen distribution mode use a shared copy of the Evergreen WebView2 Runtime, which saves disk space.
- [gui/webview] A running app keeps the old runtime until it releases its environment or
  restarts; `NewBrowserVersionAvailable` signals a new one. ^f5
  > if your app runs continuously, your app will continue to use the previous version of the WebView2 Runtime.
- [gui/webview] New APIs must be probed (`QueryInterface`) since a client may lag, for
  example when an admin disables updates. ^f6
  > it's crucial to check for the presence of new APIs on the client's machine, by using methods like `QueryInterface` or `try-catch`
- [gui/webview] Fixed Version (bundled runtime) adds over 250 MB to the package. ^f7
  > The Fixed Version binaries are over 250 MB and will make your app package larger by that amount.
- [gui/webview] Loader: statically link `WebView2Loader.lib` or ship the per-architecture
  `WebView2Loader.dll`. ^f8
  > This can be done by statically linking `WebView2Loader.lib` into the app binaries, or by including the `WebView2Loader.dll` that matches the app's architecture.
- [gui/webview] (inferred) Linking a MSVC-built `.lib` from Zig cross-compiling on macOS is
  awkward; locating the runtime ourselves (as webview/webview does,
  [[webview-webview-repo]]) avoids shipping either. ^f9
- [gui/webview] Checked, not there: no documented, supported way to skip the loader and
  find the runtime yourself. ^f10

## Read

- whole page

## Not read

- evergreen-vs-fixed-version page; how-to/static (single executable)
