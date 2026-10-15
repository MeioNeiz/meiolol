---
title: 'Cloudflare: Purge cache, availability and limits (docs, 2026)'
url: https://developers.cloudflare.com/cache/how-to/purge-cache/index.md
kind: docs
commit: 
for: [render-cache-invalidation]
looked: 2026-10-15
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Cloudflare purge options and per-plan limits; purge by tag and prefix are on the free plan, at 5 requests a minute
---
# Cloudflare: Purge cache, availability and limits (docs, 2026)

Why: is tag purging a paid feature, as nginx's purge is? Markdown variant of the page.

## Assessment

- Evidence: A. Cloudflare's reference docs.
- Reasoning: fair.
- Interests: vendor.
- Weigh: limits change; recheck before relying on them.

## Findings

- [render] [ops] Every plan, the free one included, can purge by URL, hostname, tag, prefix or everything. ^f1
  > | Purge options | URL, Hostname, Tag, Prefix, and Purge Everything | URL, Hostname, Tag, Prefix, and Purge Everything |
- [render] [ops] Free plan limit for tag, prefix, hostname and purge-all: 5 requests a minute, burst 25, up to 100 tags per request. ^f2
  > | Requests | 5 requests per minute | 5 requests per second | 10 requests per second | 50 requests per second |
  > | Max operations per request | 100 | 100 | 100 | 100 |
- [render] [ops] Single-URL purge is the recommended method; the free plan allows 800 URLs a second. ^f3
  > Multiple options are available for purging content, with single-file cache purging (purge by URL) being the recommended method.
  > | URLs | 800 URLs per second | 1500 URLs per second | 1500 URLs per second | 3000 URLs per second |
- [render] (inferred) For meiolol: a data drop per patch is a handful of tag purges, far inside 5 a minute, if the site ever sits behind Cloudflare. ^f4

## Read

- whole page

## Not read

- invalidation (mark stale) limits page
