---
title: 'Google: Site moves with URL changes (docs, 2026)'
url: https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes
kind: docs
commit: 
for: [site-url-scheme]
looked: 2026-10-27
depth: docs (whole page)
relevance: high
grade: A/fair
description: Google's checklist for changing a site's URLs: map old to new, permanent server-side redirects, self canonicals, updated links and sitemaps, no chains, keep redirects a year or more
---
# Google: Site moves with URL changes (docs, 2026)

Why: the steps and pitfalls of moving every meio.lol page to a new URL.

## Assessment

- Evidence: A. Google's own Search documentation.
- Reasoning: fair. Practical checklist.
- Interests: none.
- Weigh: written for indexed sites; meio.lol is noindex in preview, so ranking loss
  doesn't apply yet, but links in the wild (Discord, notes) do.

## Findings

- [seo] Each new URL carries a self-referencing canonical. ^f1
  > Each new URL should have a self-referencing
- [seo] Update internal links to the new URLs rather than leaning on redirects. ^f2
  > Change the internal links on the new site from the old URLs to the new URLs.
- [seo] Redirect old URLs straight to the final target; avoid chains. ^f3
  > we advise redirecting to the final destination direc
- [seo] Keep redirects at least a year, from a user's view indefinitely. ^f4
  > Keep the redirects for as long as possible**, generally at least 1 year.
  > From users' perspective, consider keeping redirects indefinitely.
- [seo] Moving in sections is fine. ^f5
  > it's fine to move your site in sections.

## Read

- whole page

## Not read

- Search Console change of address tool (not a domain move)
