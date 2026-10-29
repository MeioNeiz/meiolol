---
title: 'CSS Wizardry: The Three Cs: Concatenate, Compress, Cache'
url: https://csswizardry.com/2023/10/the-three-c-concatenate-compress-cache/
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: high
grade: B/strong
description: Harry Roberts (Oct 2023) measures Bootstrap CSS as one file vs 12 files over HTTP/2 on WebPageTest, by compression and connection; one compressed file wins; split by rate of change for caching
---
# CSS Wizardry: The Three Cs: Concatenate, Compress, Cache

Why: measured one-file vs many-files CSS under HTTP/2 with gzip and Brotli.

## Assessment

- Evidence: B. Expert's own WebPageTest runs with stated method (css_time user-timing mark, median run, four connection profiles); one page, one library, 12-way split.
- Reasoning: strong: explains latency vs download, compression context, admits the caching trade-off.
- Interests: sells performance consulting.
- Weigh: the direction and mechanism; 12 files is a far finer split than meio.lol's 2. Numbers are from one test page.

## Findings

- [seo] [web] Brotli, 3G: one file reached css_time at 1,094 ms with 18.4 KB of CSS; 12 files took 1,524 ms and 60 KB, about 1.4x slower and 3.3x heavier. Concatenate ^f1
  > Put another way, the HTTP/2 way was about **1.4× slower** and about **3.3× heavier**.
- [seo] [web] Why: each request adds latency (201 ms cumulative for one file vs 4,362 ms for many, mostly in parallel), and browser scheduling won't send all requests at once. ^f2
  > the one-big-file pattern incurred 201ms of latency, whereas the many-files approach accumulated 4,362ms by comparison
- [seo] [web] Compression loses across splits: gzip and Brotli compress a file against itself, so smaller files compress less and the split total is bigger. ^f3
  > As compression favours larger files, the overall size of the 10 smaller files will be greater than the original one file.
- [seo] [web] By compression: uncompressed, many files won (3,663 vs 4,204 ms); gzip, one file slightly (1,190 vs 1,485 ms); Brotli, one file clearly (1,094 vs 1,524 ms). Compress ^f4
  > at **higher compression**, one large file is markedly faster than many smaller ones.
- [seo] [web] Across 3G, 4G, cable and fibre, one compressed file was faster at every connection speed; the gap closes as the network gets faster. Connection ^f5
  > one big file is faster at all connection speeds as long as it is compressed
- [render] [web] Hash every bundle and cache it forever as immutable; the cost of one big bundle is that any change re-downloads all of it. Cache ^f6
  > even a tiny, one-character change to the bundle would require that a user redownload the entire file just to access one trivial change
- [web] Advice: few bundles, split by rate of change, and split out components used on few pages; overall err toward fewer. My Advice ^f7
  > As you encounter components that appear less globally, or change more frequently, begin splitting out into smaller files.
- [web] Compression dictionaries (Meenan, Weiss) would let small files compress against a shared dictionary; early stage in 2023. ^f8
  > have restarted work on implementing an SDCH-like external dictionary mechanism
- [seo] [web] (inferred) For meio.lol: a base plus one page sheet is two requests, not twelve, so the latency penalty is one extra parallel request; the gain is cutting 31.5 KB gz to 11-15 KB. That trade likely favours the split on Slow 4G, but it is not what this test measured. ^f9

## Read

- Whole article including the method appendix

## Not read

- The linked "HTTP/1-liness of HTTP/2" post (request scheduling)
