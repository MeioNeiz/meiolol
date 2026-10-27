---
title: 'Google: URL structure best practices (docs, 2026)'
url: https://developers.google.com/search/docs/crawling-indexing/url-structure
kind: docs
commit: 
for: [site-url-scheme]
looked: 2026-10-27
depth: docs (whole page)
relevance: high
grade: A/fair
description: Google's rules for crawlable URLs (no fragments for content, key=value params, hyphens, case) and URL patterns that waste crawling
---
# Google: URL structure best practices (docs, 2026)

Why: what shape meio.lol's new URLs need for search: fragments, query encoding, case,
word separators, filter combinations.

## Assessment

- Evidence: A. Google's own Search documentation.
- Reasoning: fair. Rules with examples, little on why beyond crawl cost.
- Interests: none.
- Weigh: authoritative for Google; says nothing on trailing slashes or redirects.

## Findings

- [seo] Google generally ignores URL fragments: content changed by a fragment is not seen as a separate page; use the History API instead. ^f1
  > Don't use fragments to change the content of a page, as Google Search generally doesn't support URL fragments.
  > If you're using JavaScript to change content, use the History API instead.
- [seo] Query parameters should be key=value joined by &; several values for one key may use a comma. ^f2
  > use the following common encoding: an equal sign ( = ) to separate key-value pairs and add additional parameters with an ampersand
- [seo] Hyphens, not underscores, separate words in URLs. ^f3
  > we recommend using hyphens ( - ) instead of underscores ( _ ) to separate words in your URLs
- [seo] URLs are case sensitive to Google; if the server treats cases the same, use one case. ^f4
  > Google Search's URL handling is case sensitive
- [seo] Readable words beat ID numbers in URLs. ^f5
  > When possible, use readable words rather than long ID numbers in your URLs.
- [seo] Trim parameters that don't change the content. ^f6
  > shorten URLs by trimming unnecessary parameters (meaning, parameters that don't change the content)
- [seo] Combinable filters multiply URLs; Googlebot only needs a few lists to reach every item. ^f7
  > When filters can be combined in an additive manner (for example: hotels on the beach and with a fitness center), the number of URLs (views of data) in the sites explodes.
- [seo] Use root-relative links, not parent-relative ones, to avoid infinite bogus URLs. ^f8
  > To fix, use root-relative URLs in your links (instead of parent-relative).
- [seo] Checked, not there: nothing on trailing slashes, redirects or extensions (.html) in URLs. ^f9

## Read

- whole page

## Not read

- linked SEO starter guide and locale-specific URL pages
