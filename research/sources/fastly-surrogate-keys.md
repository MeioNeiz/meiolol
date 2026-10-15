---
title: 'Fastly: Working with surrogate keys (docs)'
url: https://www.fastly.com/documentation/guides/full-site-delivery/purging/working-with-surrogate-keys/
kind: docs
commit: 
for: [render-cache-invalidation]
looked: 2026-10-15
depth: docs (whole page)
relevance: high
grade: A/fair
description: Fastly surrogate keys: the origin tags each response in a header, the CDN keeps a key to objects map and purges every object under a key in one call
---
# Fastly: Working with surrogate keys (docs)

Why: the CDN-side original of cache tags. How does an origin tell a cache which data a
page depends on?

## Assessment

- Evidence: A. Fastly's reference guide; surrogate keys have been its purge model for
  over a decade and Varnish-style caches copy it.
- Reasoning: fair. Clear model and limits; no discussion of costs.
- Interests: vendor.
- Weigh: the mechanism (origin emits keys, cache indexes them) is the point; we have no
  Fastly. Cloudflare's Cache-Tag is the same idea ([[cloudflare-cache-tags#^f1]]).

## Findings

- [render] [ops] The origin tags each response with keys in a Surrogate-Key header; a purge by key removes every object carrying it. ^f1
  > When you want to purge content associated with that key, you then issue a key purge request and all of the objects associated with that key will be purged.
- [render] Keys and objects are many-to-many: one page carries several keys and one key spans many pages. ^f2
  > One of the major advantages of surrogate keys is that they allow for a many-to-many relationship between keys and objects.
- [render] The application chooses the keys, typically one per entity the page shows. ^f3
  > Surrogate-Key: template-product product-id-724253 product-id-242129 offers
- [render] The cache strips the header before the response reaches users, so keys can be internal names. ^f4
  > Fastly automatically removes any `[Surrogate-Key](https://www.fastly.com/documentation/reference/http/http-headers/Surrogate-Key/)` headers present on a response before delivering it to the end user
- [render] Limits: keys are space-separated and case-sensitive, a header holds at most 16 KB. ^f5
  > Individual tokens may not exceed 1KB in length and `[Surrogate-Key](https://www.fastly.com/documentation/reference/http/http-headers/Surrogate-Key/)` header values may not exceed 16KB in length.
- [render] Fastly's example key list mixes entity keys with a template key (`template-product`); (inferred) so a change to one template can purge every page built from it. ^f6
  > set beresp.http.Surrogate-Key = "template-product product-id-724253 product-id-242129 offers";
- [render] (inferred) For meiolol: a matchup page would carry `patch:<p> champ:<a> champ:<b> role:<r> tpl:matchup`; a new data drop for one patch, or a change to one page template, then names exactly the pages to drop. ^f7

## Read

- whole page

## Not read

- purging with surrogate keys (soft purge: mark stale instead of evicting)
