---
title: 'Google: Build and submit a sitemap (docs, 2026)'
url: https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap
kind: docs
commit: 
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: docs (size limits, XML sitemap fields)
relevance: medium
grade: A/fair
description: Google sitemap rules: 50,000 URLs or 50 MB per sitemap, sitemap index for more; lastmod used only if accurate; priority and changefreq ignored
---
# Google: Build and submit a sitemap (docs, 2026)

Why: how pages that are not prerendered (so not linked from a crawl of static files)
get discovered.

## Assessment

- Evidence: A. Google's own docs.
- Reasoning: fair.
- Interests: none.
- Weigh: authoritative.

## Findings

- [seo] One sitemap holds at most 50,000 URLs or 50 MB; more needs several sitemaps and optionally an index. ^f1
  > All formats limit a single sitemap to 50MB (uncompressed) or 50,000 URLs.
- [seo] Google uses lastmod only if it is consistently accurate, and ignores priority and changefreq. ^f2
  > Google ignores `<priority>` and `<changefreq>` values.
  > Google uses the `<lastmod>` value if it's consistently and verifiably (for example by comparing to the last modification of the page) accurate.

## Read

- size limits, XML example and field rules

## Not read

- RSS/text formats, multi-site sitemaps
