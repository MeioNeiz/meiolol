---
title: 'Cloudflare: Purge cache by cache-tags (docs, 2026)'
url: https://developers.cloudflare.com/cache/how-to/purge-cache/purge-by-tags/index.md
kind: docs
commit: 
for: [render-cache-invalidation]
looked: 2026-10-15
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Cloudflare Cache-Tag: the origin tags responses in a header, a purge by tag forces a miss on everything tagged
---
# Cloudflare: Purge cache by cache-tags (docs, 2026)

Why: the second big CDN's form of surrogate keys; Cloudflare's free plan is a plausible
front for meiolol later. Markdown variant of the page.

## Assessment

- Evidence: A. Cloudflare's reference docs.
- Reasoning: fair.
- Interests: vendor.
- Weigh: same mechanism as Fastly ([[fastly-surrogate-keys#^f1]]); plan limits are in
  [[cloudflare-purge-cache]].

## Findings

- [render] [ops] Same model as surrogate keys: tags in a Cache-Tag response header, purge by tag, the next request is a miss. ^f1
  > Add tags to the `Cache-Tag` HTTP response header from your origin web server for your web content, such as pages, static assets, etc.
  > Cloudflare forces a [cache MISS](https://developers.cloudflare.com/cache/concepts/cache-responses/#miss) on content with the purged cache-tag.
- [render] [ops] Cloudflare itself warns that a purge moves load to the origin. ^f2
  > Be careful when purging. A cache MISS can cause execution delays by requiring a fetch from your origin server.
- [render] Limits: a response's tags may total 16 KB (about 1,000 tags), case-insensitive, no spaces. ^f3
  > the aggregate `Cache-Tag` HTTP header cannot exceed 16 KB after the header field name, which is approximately 1,000 unique tags.
- [render] Tags are stripped before the visitor sees the response. ^f4
  > Your end users or Worker never see `Cache-Tag` HTTP headers on your Cloudflare-enabled website.

## Read

- whole page

## Not read

- invalidate (mark stale) versus purge guide
