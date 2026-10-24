---
status: answered
priority: now
area: ui
tags: [gui, gui/webview, gui/a11y, policy]
description: Which toolkit should the meiolol desktop app be built on, long term?
---
# Which toolkit should the meiolol desktop app be built on, long term?

Feeds: data/team/2026-10-24-ui/stack.md question 5 ("Added 24 Oct"); spike report
data/team/2026-10-24-ui/spikes/desktop/REPORT.md; then docs/plan/ui/stack.md

## Answer

The system webview (WebView2 on Windows, WKWebView on the Mac), driven from Zig with
no C++ and no Microsoft loader dll, showing the site's own components. The runtime is
on Windows 11 and nearly all Windows 10 PCs, with a 2 MB per-user bootstrapper as the
fallback (C2); we can find it ourselves the way webview/webview does, at the cost of
one undocumented export (C5). It has every hook the app needs: embedded pages served
from memory, screenshots, memory knobs, transparency (C6). Its price is memory, not
size: a Chromium process set of about 200 to 290 MB private, as heavy as Electron or
Tauri (C1, C3; our spike measured it). Bundling our own Chromium (CEF or a fixed
WebView2) costs hundreds of MB and its security updates (C4). Screen readers work in a
webview out of the box, partly in dvui through AccessKit, not in Dear ImGui (C7).
Riot names no window type for overlays; a separate always-on-top window that reads
only the official APIs is the least exposed route (C9).

## Claims

- C1: A WebView2 window brings Chromium's process set (browser, renderers, GPU, utility); windows on one environment and user data folder share it. for: [[ms-webview2-process-model#^f2]], [[ms-webview2-process-model#^f3]], [[ms-webview2-performance#^f4]]
- C2: Most players' PCs already have the WebView2 runtime; a presence check plus the 2 MB per-user bootstrapper covers the rest. for: [[ms-webview2-distribution#^f1]], [[ms-webview2-distribution#^f2]], [[ms-webview2-distribution#^f3]]
- C3: A webview app saves download size, not memory: its memory on Windows is about Electron's. for: [[elanis-web-to-desktop-bench#^f2]], [[elanis-web-to-desktop-bench#^f3]], [[tauri-v2-what-is#^f1]]
- C4: Bundling our own Chromium (CEF or Fixed Version WebView2) costs hundreds of MB and makes its security updates ours. for: [[cef-builds-index#^f2]], [[ms-webview2-distribution#^f7]], [[ms-webview2-distribution#^f4]]
- C5: WebView2 can be driven without Microsoft's MSVC-only static loader or its dll by locating the runtime as webview/webview does; the risk is one undocumented export. for: [[webview-webview-repo#^f3]], [[webview-webview-repo#^f6]], [[webview-webview-repo#^f4]], [[ms-webview2-distribution#^f8]]
- C6: WebView2 has the hooks the app needs: embedded content served from memory, screenshots, transparency, memory control and a compositor route. for: [[ms-webview2-api-overview#^f1]], [[ms-webview2-api-overview#^f3]], [[ms-webview2-api-overview#^f4]], [[ms-webview2-performance#^f5]], [[ms-webview2-hosting-modes#^f4]]
- C7: Screen readers: a WebView2 page is in the accessibility tree out of the box; dvui gets partway through AccessKit; Dear ImGui does not. for: [[ms-webview2-hosting-modes#^f2]], [[dvui-accessibility#^f1]], [[dvui-accessibility#^f5]], [[imgui-a11y-8022#^f2]], [[imgui-a11y-8022#^f3]]
- C8: WebView2 is slow on a truly cold start; Microsoft advises static HTML first and web messages for interop, which fits server-rendered pages and LCU events. for: [[ms-webview2-performance#^f2]], [[ms-webview2-performance#^f7]], [[ms-webview2-performance#^f8]], [[elanis-web-to-desktop-bench#^f6]]
- C9 (inferred): A separate always-on-top window reading only official APIs is the overlay route least exposed to Riot policy: Riot names no window type and bans memory access. from: C10
- C10: Riot's Vanguard notes keep overlays and tools on the official APIs working and stop memory readers; no source found separates window types. for: [[riot-vanguard-faq-devrel#^f2]], [[mobalytics-overlay-not-appearing#^f4]]

## Disagreements

Microsoft's performance page says each control launches several processes
([[ms-webview2-performance#^f1]]); the process model page says controls on one user
data folder share them ([[ms-webview2-process-model#^f3]]). Our spike settles it for
one environment: a second window added one renderer (about 20 MB private), not a set.

## Open

- CPU and memory with League running (the spike ran with League closed)
- Behaviour at 150% scaling and over borderless League (topmost panel on top?)
- Whether AccessKit's prebuilt libraries link when cross-compiling dvui from macOS
- WebView2 threading model page (lead logged)
