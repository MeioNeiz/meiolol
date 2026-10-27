---
title: 'Google: Redirects and Google Search (docs, 2026)'
url: https://developers.google.com/search/docs/crawling-indexing/301-redirects
kind: docs
commit: 
for: [site-url-scheme]
looked: 2026-10-27
depth: docs (whole page)
relevance: high
grade: A/fair
description: Which redirect types Google treats as permanent (301, 308, instant meta refresh) and how they feed canonicalisation; nginx examples
---
# Google: Redirects and Google Search (docs, 2026)

Why: 301 or 308 for moving meio.lol's old .html URLs, and whether a client-side redirect
would do for fragment-only state.

## Assessment

- Evidence: A. Google's own Search documentation.
- Reasoning: fair.
- Interests: none.
- Weigh: authoritative for Google; other bots unstated.

## Findings

- [seo] 301 and 308 are both permanent and treated alike. ^f1
  > The `301` and `308` status codes mean that a page has permanently moved to a new location.
- [seo] A permanent redirect is a signal that its target should be canonical, so the new URL shows in results. ^f2
  > Googlebot follows the redirect, and the indexing pipeline uses the redirect as a signal that the redirect target should be
- [seo] Server-side permanent redirects are the recommended way to change a page's URL. ^f3
  > we recommend that you use a permanent server-side redirect whenever possible.
- [seo] An instant meta refresh counts as permanent; JavaScript redirects only as a last resort. ^f4
  > Google Search interprets instant `meta refresh` redirects as permanent redirects.
  > Only use JavaScript redirects if you can't do server-side or meta refresh redirects.

## Read

- whole page

## Not read

- linked HTTP status code troubleshooting page
