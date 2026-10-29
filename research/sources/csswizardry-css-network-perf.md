---
title: 'CSS Wizardry: CSS and Network Performance'
url: https://csswizardry.com/2018/11/css-and-network-performance/
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: high
grade: A/strong
description: Harry Roberts (Nov 2018) on CSS as the critical-path bottleneck: critical CSS and its difficulty, splitting by media query, avoiding @import, CSS blocking later scripts, link-in-body under HTTP/2
---
# CSS Wizardry: CSS and Network Performance

Why: the canonical practitioner view on one file vs split CSS and the fixes for blocking CSS.

## Assessment

- Evidence: A. Recognised web performance consultant, widely cited; waterfalls shown, but mostly mechanisms rather than sized gains. 2018: some browser bugs he names are since fixed.
- Reasoning: strong. Explains each mechanism, admits critical CSS is hard, ends with "test everything".
- Interests: sells performance audits and training.
- Weigh: the mechanisms (priority by media, slowest sheet rule, @import chains); his HTTP/2 split advice predates later compression and per-request cost findings.

## Findings

- [seo] [web] Rule of thumb: a page renders only as fast as its slowest stylesheet. What's the Big Problem? ^f1
  > your page will only render as quickly as your slowest stylesheet
- [seo] [web] Critical CSS is the most effective fix but not simple: dynamic sites are hard to extract, it must be automated, the fold is an assumption, edge cases slip. Employ Critical CSS ^f2
  > highly dynamic sites can be difficult to extract styles from, the process needs to be automated, we have to make assumptions about what _above the fold_ even is
- [seo] [web] Sheets whose media query doesn't match are fetched at Lowest priority, off the critical path; matching ones block at Highest. Split Your Media Types ^f3
  > download any CSS not needed for the current context with a very low priority, completely off of the Critical Path.
- [seo] [web] `@import` inside CSS adds a round trip on the critical path; two parallel links are better. Avoid @import ^f4
  > we’re actively creating more roundtrips on the Critical Path
- [seo] [web] A synchronous script after an in-flight stylesheet waits for that CSS, so CSS can delay scripts and what they load. ^f5
  > A browser will not execute a `<script>` if there is any currently-in flight CSS.
- [seo] [web] One bundle's three costs: pages download rules they don't use, any change busts the whole file's cache, and all of it blocks render. ^f6
  > **We’re bound to an inefficient caching strategy:** a change to, say, the background colour of the currently-selected day on a date picker used on only one page, would require that we cache-bust the entirety of `app.css`.
- [seo] [web] Splitting under HTTP/2 fixes the redundancy and caching but not blocking: everything in the head still blocks. Place link in body ^f7
  > What we haven’t solved is the fact that it all still blocks rendering — we’re still only as fast as our slowest stylesheet.
- [seo] [web] Since about Chrome 69 (and in Firefox, IE/Edge) a link in the body blocks only the content after it, allowing progressive render. ^f8
  > `<link rel="stylesheet" />`s will only block the rendering of subsequent content, rather than the whole page
- [seo] [web] Checked, not there: no measured cost per extra stylesheet request and nothing on compression loss from splitting. ^f9

## Read

- Whole article

## Not read

- Later csswizardry posts on fonts and caching
