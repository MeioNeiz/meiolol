---
title: webview/webview (README and WebView2 loader)
url: https://github.com/webview/webview
kind: project
commit: f244320ab0d82fdab98a094e02996fc26d0ffd0c
for: [desktop-toolkit]
looked: 2026-10-24
depth: code (README.md, core/include/webview/detail/platform/windows/webview2/loader.hh)
relevance: high
grade: A/fair
description: Tiny MIT C/C++ library wrapping the system web view (WebView2, WKWebView, WebKitGTK), with its own WebView2 loader
---
# webview/webview (README and WebView2 loader)

Why: is there a mature thin wrapper we could use or copy, and how does it find the
WebView2 runtime without Microsoft's loader?

## Assessment

- Evidence: A. Created Aug 2017, 14.3k stars, 1.1k forks, 93 contributors, MIT; last
  tag 0.12.0 (Sep 2024), no GitHub releases since; 31 commits in 2025, 10 in 2026 so
  far, last push 22 Oct 2026. Many bindings (Go, Rust, Python, Zig) build on it.
- Reasoning: fair. README documents how its loader differs from Microsoft's.
- Interests: none known.
- Weigh: slow but alive; the loader is small and readable enough to port to Zig.

## Findings

- [gui/webview] A tiny cross-platform C/C++ library for HTML UIs with two-way JavaScript
  bindings. `README.md` ^f1
  > A tiny cross-platform webview library for C/C++ to build modern cross-platform GUIs.
  > It supports two-way JavaScript bindings (to call JavaScript from C/C++ and to call C/C++ from JavaScript).
- [gui/webview] Backends: WebKitGTK on Linux, WebKit on macOS, WebView2 on Windows. `README.md` ^f2
  > Windows  | [Windows API][win32-api], [WebView2][ms-webview2]
- [gui/webview] Neither linking Microsoft's loader nor shipping `WebView2Loader.dll` is
  required; a present DLL wins, otherwise its own minimal loader is used. `README.md` ^f3
  > Linking the WebView2 loader part of the Microsoft WebView2 SDK is not a hard requirement when using our webview library, and neither is distributing `WebView2Loader.dll` with your app.
  > If, however, `WebView2Loader.dll` is loadable at runtime, e.g. from the executable's directory, then it will be used; otherwise our minimalistic implementation will be used instead.
- [gui/webview] Microsoft's static loader links with Visual C++ only, not MinGW-w64. `README.md` ^f4
  > Linking it statically is possible with Visual C++ but not MinGW-w64.
- [gui/webview] Built-in loader limits: no `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` style
  environment variables, no Edge preview channels. `README.md` ^f5
  > Microsoft Edge Insider (preview) channels are not supported.
- [gui/webview] The loader reads the runtime path from the registry
  (`EdgeUpdate\ClientState\{F3017226...}`, value `EBWebView`), HKLM first then HKCU,
  loads `EBWebView\<arch>\EmbeddedBrowserWebView.dll` and calls its
  `CreateWebViewEnvironmentWithOptionsInternal`. `loader.hh` ^f6
  > L"SOFTWARE\\Microsoft\\EdgeUpdate\\ClientState\\";
  > auto ebwebview_value = key.query_string(L"EBWebView");
  > dll_path += L"\\EmbeddedBrowserWebView.dll";
  > "CreateWebViewEnvironmentWithOptionsInternal");
- [gui/webview] It rejects runtimes older than API version 1150 (SDK 1.0.1150.38). `loader.hh` ^f7
  > static constexpr unsigned int api_version = 1150;
- [gui/webview] (inferred) Porting this loader is about 150 lines of Zig (registry read,
  LoadLibrary, one exported symbol), so we need neither the MSVC `.lib` nor a DLL; the
  symbol is undocumented by Microsoft ([[ms-webview2-distribution#^f10]]), so a runtime
  change could break it, as it would break this library's many users. ^f8
- [gui/webview] Windows build: C++14 compiler, MSVC or MinGW-w64, WebView2 headers from
  NuGet. `README.md` ^f9
  > Your compiler must support C++14 and we recommend to pair it with an up-to-date Windows 10 SDK.

## Read

- README.md (all), loader.hh (built-in loader)

## Not read

- core/include/webview/detail/backends/win32_edge.hh (909 lines: window, message loop,
  bind/eval): the reference for our COM call sequence
