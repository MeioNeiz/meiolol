---
title: 'Google: Managing crawling of faceted navigation URLs (docs, 2026)'
url: https://developers.google.com/search/docs/crawling-indexing/crawling-managing-faceted-navigation
kind: docs
commit: 
for: [site-url-scheme]
looked: 2026-10-27
depth: docs (whole page)
relevance: high
grade: A/fair
description: How to keep filter URLs from eating crawl: robots.txt, fragments for filters, canonical to the unfiltered page, fixed order for path filters, 404 for empty combinations
---
# Google: Managing crawling of faceted navigation URLs (docs, 2026)

Why: region, rank, patch and queue filters on meio.lol pages are faceted navigation:
query, path or fragment?

## Assessment

- Evidence: A. Google's own crawling documentation.
- Reasoning: fair. Lists options with when each fits.
- Interests: none.
- Weigh: authoritative; the choice between options is left to the site.

## Findings

- [seo] Filter combinations make very many URLs. ^f1
  > This often means a very large number of possible combinations of filters, which translates to a very large number of possible URLs.
- [seo] Filters in the fragment have no effect on crawling either way. ^f2
  > If your filtering mechanism is based on URL fragments, it will have no impact on crawling (positive or negative).
- [seo] A rel=canonical from filtered URLs to the unfiltered page may cut their crawling over time. ^f3
  > consider pointing the `rel="canonical"` to the unfiltered version
- [seo] Filters in the path must keep one fixed order with no duplicates. ^f4
  > ensure that the logical order of the filters always stays the same and that no duplicate filters can exist.
- [seo] Empty or nonsense filter combinations should return a real 404. ^f5
  > Return an HTTP `404` status code when a filter combination doesn't return results.

## Read

- whole page

## Not read

- linked robots.txt guide
