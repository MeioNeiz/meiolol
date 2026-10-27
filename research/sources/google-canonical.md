---
title: 'Google: How to specify a canonical with rel=canonical and other methods (docs, 2026)'
url: https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls
kind: docs
commit: 
for: [site-url-scheme]
looked: 2026-10-27
depth: docs (whole page)
relevance: high
grade: A/fair
description: Canonical signals in order of strength (redirects, rel=canonical, sitemap) and rules: absolute URLs, no fragments, one consistent choice
---
# Google: How to specify a canonical (docs, 2026)

Why: what canonical tags and sitemaps meio.lol's new URLs need, and how filtered views
should point.

## Assessment

- Evidence: A. Google's own Search documentation.
- Reasoning: fair.
- Interests: none.
- Weigh: authoritative; Google still decides the canonical itself.

## Findings

- [seo] Redirects are the strongest canonical signal, rel=canonical strong, sitemap inclusion weak. ^f1
  > A strong signal that the target of the redirect should become canonical.
  > A weak signal that helps the URLs that are included in a sitemap become canonical.
- [seo] Don't name different canonicals for one page in different places (sitemap vs tag). ^f2
  > don't specify one URL in a sitemap, but a different URL for that same page using
- [seo] A fragment URL must not be the canonical. ^f3
  > specify a URL fragment as canonical, as
- [seo] Use absolute URLs in rel=canonical. ^f4
  > Use absolute paths rather than relative paths with the `rel="canonical"` `link` element.

## Read

- whole page

## Not read

- linked troubleshooting of canonicalisation
