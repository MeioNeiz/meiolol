---
title: 'Chrome DevTools: RenderBlocking.ts insight (Lighthouse 13 render-blocking requests)'
url: https://github.com/ChromeDevTools/devtools-frontend/blob/main/front_end/models/trace/insights/RenderBlocking.ts
kind: project
commit: 00f61fde89fdd434b9d0dfbdf705f9eb1c7f2e9a
for: [css-per-page]
looked: 2026-10-29
depth: code (insights/RenderBlocking.ts)
relevance: high
grade: A/strong
description: The code behind PageSpeed/Lighthouse 13's render-blocking insight: which requests it flags and how it simulates the FCP/LCP savings it shows
---
# Chrome DevTools: RenderBlocking.ts insight (Lighthouse 13 render-blocking requests)

Why: PageSpeed shows "est. 670 ms" for our one stylesheet. What does that number model?

## Assessment

- Evidence: A. The shipped code PageSpeed Insights and Lighthouse 13 run (the docs page links it as the insight source); Chromium authors.
- Reasoning: strong for what it computes; comments state its own false positives.
- Interests: none.
- Weigh: the estimate is an upper bound of deferring everything, not a forecast of any one fix.

## Findings

- [seo] [web] A request counts only if the trace marks it render-blocking and it finished before first paint; in-body blocking requests count only at VeryHigh priority (or High for scripts). `generateInsight` ^f1
  > if (req.args.data.syntheticData.finishTime > firstPaintTs) {
- [seo] [web] Savings come from a Lantern simulation of the optimistic FCP graph with every flagged request and all its dependents removed, compared to the graph as loaded. `estimateSavingsWithGraphs`, `computeSavings` ^f2
  > // Mark this node, any redirects leading to it, and all its dependents as deferrable
- [seo] [web] Inlining is modelled as free: the bytes added to the HTML are a constant 0, so the estimate never charges the bigger HTML an inlined sheet would bring. `estimateSavingsWithGraphs` ^f3
  > const totalChildNetworkBytes = 0;
- [seo] [web] The LCP saving is set equal to the FCP saving unless LCP is an image. `computeSavings` ^f4
  > // In most cases, render-blocking resources only affect LCP if LCP isn't an image.
- [seo] [web] Sheets whose download took under 50 ms are ignored, because loadCSS-style async CSS (preload plus onload) can be falsely flagged as blocking. `MINIMUM_WASTED_MS` ^f5
  > Because of the way we detect blocking stylesheets, asynchronously loaded
- [seo] [web] (inferred) For meio.lol the 670 ms is the simulated gain of removing style.css and everything hanging off it (inter.woff2 is requested from the sheet, so it is a dependent) from the FCP path, with text LCP inheriting it. Splitting into two sheets that are both still blocking would still be flagged; only a smaller simulated download shrinks the number. ^f6

## Read

- `front_end/models/trace/insights/RenderBlocking.ts`: all

## Not read

- Lantern simulator and throttling constants (Slow 4G RTT and throughput)
- `Helpers.Network.isSyntheticNetworkRequestEventRenderBlocking`: what Chrome marks render-blocking
