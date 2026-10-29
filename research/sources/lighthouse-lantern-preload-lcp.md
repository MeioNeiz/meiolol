---
title: 'Lighthouse issue 16539: Lighthouse Punishes Good Asset Preloading'
url: https://github.com/GoogleChrome/lighthouse/issues/16539
kind: thread
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (thread, all comments, closing PR 17307 notes; duplicate issue 11460 appended to the raw)
relevance: high
grade: A/strong
description: Ivan Akulov (Framer) shows Lantern's simulated FCP/LCP counting every request before observed LCP, fonts and preloads included; Lighthouse maintainers agree; fix to use Chrome's renderBlocking status shipped Oct 2026 (trace_engine 0.0.66)
---
# Lighthouse issue 16539: Lighthouse Punishes Good Asset Preloading

Why: is PageSpeed's mobile LCP for a text page inflated by the font, and does preloading the font make it worse?

## Assessment

- Evidence: A. Maintainers (Paul Irish, Connor Clark, Brendan Kenny) confirm the mechanism in the thread; a reporter's table of runs on Lighthouse 13.4.1; closing PR names the fix.
- Reasoning: strong: code paths linked, trade-offs (bandwidth contention) raised by maintainers.
- Interests: Framer wants its customers' scores fixed.
- Weigh: describes the simulation (PSI's default), not real users. Check whether PSI runs a Lighthouse with the fix (v13.6.0, 27 Oct 2026) before re-measuring.

## Findings

- [seo] Lantern simulates slow LCP assuming LCP needs every request that finished before the observed LCP, so a preloaded font delays simulated LCP even when it doesn't in reality. Simulated Throttling ^f1
  > Preloaded a font? Well, now simulated LCP will be delayed by that font load time, even if the LCP element is actually an image.
- [seo] Simulated FCP does the same but skips low-priority requests, so `@font-face` font requests still count. ^f2
  > nodes with a low fetch priority are ignored. This means offscreen images and non-blocking scripts won’t delay FCP (yay!), but `@font-face` requests (meh) or `modulepreload`s (eh?) still will.
- [seo] Reproduced on Lighthouse 13.4.1: text LCP in the initial HTML with a swap font painted FCP and LCP together under 450 ms, but simulation gave FCP 1.78-1.94 s and LCP 3.10-3.15 s; applied (devtools) throttling scored 98-99 vs 92-93. EricBCoding 2026-08-23 ^f3
  > The browser therefore paints FCP and LCP together in under 450 ms, but Lantern turns them into separate events about 1.2–1.4 seconds apart.
- [seo] A maintainer's reason for keeping extra requests: they compete for bandwidth with the LCP request on a slow link, so dropping them could under-report. connorjclark 2025-12-15 ^f4
  > if dozens of non-critical requests are preloaded, that would saturate the network and prevent the actual LCP image request from being delivered as quickly as when there were no preloaded requests
- [seo] [web] `preload as=style` followed by the same stylesheet link was not upgraded to render-blocking in Chrome's signal until a fix in Chrome 144. tunetheweb 2025-11-20 ^f5
  > As of Chrome 144 this will correctly be marked as render-blocking.
- [seo] Fix: Lantern's render-blocking test now uses Chrome's explicit renderBlocking status, merged 8 Oct 2026 (trace_engine 0.0.66), released in Lighthouse 13.6.0 on 27 Oct 2026 (release list). Closing PR ^f6
  > `NetworkNode.hasRenderBlockingPriority` now uses the explicit `renderBlocking` status from CDP/trace events
- [seo] The same fix makes Lantern treat HTTP/3 connections as multiplexed like HTTP/2. ^f7
  > `ConnectionPool` now treats `h3` connections (`h3`, `h3-29`, `h3-Q050`, etc.) as multiplexed alongside `h2`.
- [seo] Duplicate issue 11460 (2020): preloading seven swap fonts raised simulated LCP and dropped the score from 100 to 80; a maintainer called it a simulated-throttling bug. ^f9
  > This is a bug in simulated throttling. Basically the preloaded fonts now load before LCP and Lighthouse includes them in our pessimistic estimate of LCP.
- [seo] Reported again in production in 2025 (11460): score 80 with any font preload, 100 without, with paragraph-text LCP. ^f10
  > With any preload - score is 80. With no preloads - score is 100.
- [seo] (inferred) meio.lol's 3.3 s Slow 4G LCP is a Lantern number: with text LCP, inter.woff2 (48 KB, swap) chained after the sheet is probably counted in the simulated LCP. Compare `throttlingMethod: devtools` or WebPageTest before judging a CSS change by PSI's LCP. ^f8

## Read

- Whole thread and the closing PR's highlights

## Not read

- Issue 13808 (swap made PSI mobile LCP 3.7 s to 9 s in 2022): skipped, unresolved

- PR 16782 (LCP = FCP when in the same frame): merge status not checked
- Issue 15737 (optimistic graph too broad)
