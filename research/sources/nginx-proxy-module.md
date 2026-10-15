---
title: 'nginx: ngx_http_proxy_module (docs)'
url: https://nginx.org/en/docs/http/ngx_http_proxy_module.html
kind: docs
commit: 
for: [hybrid-rendering-seo, render-cache-invalidation]
looked: 2026-10-12
depth: docs (proxy_cache_use_stale, proxy_cache_background_update, proxy_cache_lock)
relevance: high
grade: A/fair
description: nginx reverse proxy cache: serve stale while a background request refreshes, one request at a time fills a new cache entry
---
# nginx: ngx_http_proxy_module (docs)

Why: can the nginx we already run give ISR-like behaviour in front of a small render
server, without a framework?

## Assessment

- Evidence: A. nginx's reference docs; the server already serves the site.
- Reasoning: fair. Reference, not guidance.
- Interests: none.
- Weigh: the directives exist; older trac tickets report background update quirks in
  1.15, so test on our 1.24.

## Findings

- [render] [ops] With the updating parameter, nginx serves a stale cached response while that entry is being refreshed. ^f1
  > Additionally, the `updating` parameter permits using a stale cached response if it is currently being updated.
- [render] [ops] proxy_cache_background_update refreshes an expired entry in a background subrequest while the client gets the stale copy: ISR's stale-while-revalidate. ^f2
  > Allows starting a background subrequest to update an expired cache item, while a stale cached response is returned to the client.
- [render] [ops] proxy_cache_lock lets only one request at a time render a new entry; others wait, so a crawler burst on one page renders it once. ^f3
  > When enabled, only one request at a time will be allowed to populate a new cache element
- [render] [ops] nginx also honours stale-while-revalidate and stale-if-error sent by the backend in Cache-Control. ^f4
- [render] [ops] proxy_cache_purge (purge by key, or a trailing `*` wildcard) exists only in the commercial subscription, not open-source nginx. (added 2026-10-15 for render-cache-invalidation) ^f5
  > Defines conditions under which the request will be considered a cache purge request.
  > This functionality is available as part of our [commercial subscription](https://www.f5.com/products/nginx).
- [render] [ops] The cache key is any string of variables, so a version token can be part of it; cache files are named by the key's MD5. ^f6
  > proxy\_cache\_key "$host$request\_uri $cookie\_user";
  > The file name in a cache is a result of applying the MD5 function to the [cache key](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key).
- [render] [ops] Entries not read within `inactive` (default 10 min) are deleted whatever their freshness, so entries orphaned by a key change clean themselves up. ^f7
  > Cached data that are not accessed during the time specified by the `inactive` parameter get removed from the cache regardless of their freshness.
- [render] [ops] Open-source refresh tools: proxy_cache_bypass skips the cache lookup for chosen requests, and proxy_cache_revalidate turns expiry into a conditional request (If-None-Match), so an unchanged page costs the renderer a 304. ^f8
  > Defines conditions under which the response will not be taken from a cache.
  > Enables revalidation of expired cache items using conditional requests with the “If-Modified-Since” and “If-None-Match” header fields.
- [render] [ops] The backend can set each response's cache time with X-Accel-Expires, so the renderer, not nginx config, can decide TTL per page. ^f9
  > The “X-Accel-Expires” header field sets caching time of a response in seconds.
- [render] (inferred) A request with a bypass header (from an internal warmer) re-renders and, since bypass does not stop storing, replaces the entry: a purge-by-overwrite with open-source nginx. Not stated in the docs; test it. ^f10

## Read

- proxy_cache_use_stale, proxy_cache_background_update, proxy_cache_lock, proxy_cache_valid
- 2026-10-15: proxy_cache_purge, proxy_cache_key, proxy_cache_bypass, proxy_cache_revalidate, proxy_cache_path inactive, X-Accel-Expires

## Not read

- proxy_cache_path sizing (keys_zone, max_size, inactive)
