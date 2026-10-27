---
status: decided
decision: docs/plan/urls.md#Scheme
priority: soon
area: ops
tags: [seo]
description: What URL scheme should meio.lol use for its pages, filters and page state, and how do we move to it without losing links or search standing?
---
# What URL scheme should meio.lol use for its pages, filters and page state, and how do we move to it without losing links or search standing?

Feeds: docs/plan/urls.md (J32)

## Answer

Jacob's hierarchy fits Google's rules and the competitors' practice: readable lowercase
words with hyphens, no extension, one form of each URL (C1, C2). Role in the path is
op.gg's and Blitz's shape; u.gg and mobalytics serve the main role at the bare champion
URL (C6). Data filters (region, rank, patch, queue) belong in the query with the
canonical pointing at the unfiltered page, as four of six LoL sites do (C5); League of
Graphs puts every filter in the path, which Google accepts only in a fixed order (C4).
Fragments are invisible to search (C3), so they suit in-page state, and they are never
sent to the server, which also keeps Riot IDs out of logs (inferred).

The move: permanent server-side redirects (301 and 308 are equal) straight to the final
URL, self canonicals, internal links updated, redirects kept a year or more (C7, C8).
Old fragment state survives a 301 by HTTP rule, so the new pages' wasm can translate old
keys (C9). The site is noindex in preview, so there is no ranking to lose yet.

## Claims

- C1: Google wants readable words, hyphens, one case, few parameters, root-relative links. for: [[google-url-structure#^f3]], [[google-url-structure#^f4]], [[google-url-structure#^f5]], [[google-url-structure#^f6]], [[google-url-structure#^f8]]
- C2: With and without a trailing slash are two URLs; serve one and redirect the other. for: [[google-slash#^f1]], [[google-slash#^f2]]
- C3: Google ignores fragments: content changed by one is not a page, and a fragment can't be a canonical; filters in a fragment don't touch crawling. for: [[google-url-structure#^f1]], [[google-canonical#^f3]], [[google-faceted-nav#^f2]]
- C4: Combinable filters explode the URL space; path filters need a fixed order, empty combinations a 404. for: [[google-url-structure#^f7]], [[google-faceted-nav#^f1]], [[google-faceted-nav#^f4]], [[google-faceted-nav#^f5]]
- C5: op.gg, u.gg, mobalytics and Blitz put filters in the query and canonical to the unfiltered page; lolalytics self-canonicals each filtered URL; League of Graphs uses path segments. for: [[lol-sites-filter-urls#^f1]], [[lol-sites-filter-urls#^f2]], [[lol-sites-filter-urls#^f3]], [[lol-sites-filter-urls#^f4]], [[lol-sites-filter-urls#^f5]], [[google-faceted-nav#^f3]]
- C6: Role in the path (op.gg, Blitz) or main role at the bare champion URL (u.gg, mobalytics). for: [[lol-sites-filter-urls#^f1]], [[lol-sites-filter-urls#^f2]]
- C7: Permanent server-side redirects (301 or 308, treated alike) are the strongest canonical signal, ahead of rel=canonical and sitemaps, which must agree. for: [[google-redirects#^f1]], [[google-redirects#^f2]], [[google-canonical#^f1]], [[google-canonical#^f2]]
- C8: A URL move: map old to new, redirect to the final target without chains, self canonicals, updated links and sitemap, redirects kept at least a year; moving in sections is fine. for: [[google-site-move#^f1]], [[google-site-move#^f2]], [[google-site-move#^f3]], [[google-site-move#^f4]], [[google-site-move#^f5]]
- C9: A redirect without a fragment inherits the request's fragment. for: [[rfc9110-location#^f1]]

## Disagreements

lolalytics indexes every filter combination, the other five don't. Settles: whether
filtered pages earn search traffic; a site: search per site would show it.

## Open

- Whether filtered competitor pages are indexed at all (site: searches).
- Patch-specific pages (/patch/26-21) as search targets: no evidence read.
