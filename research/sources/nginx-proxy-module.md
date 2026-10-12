---
title: 'nginx: ngx_http_proxy_module (docs)'
url: https://nginx.org/en/docs/http/ngx_http_proxy_module.html
kind: docs
commit: 
for: [hybrid-rendering-seo]
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

## Read

- proxy_cache_use_stale, proxy_cache_background_update, proxy_cache_lock, proxy_cache_valid

## Not read

- proxy_cache_path sizing (keys_zone, max_size, inactive)
