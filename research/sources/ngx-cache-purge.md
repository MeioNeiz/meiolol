---
title: 'nginx-modules/ngx_cache_purge: cache purge module for open-source nginx'
url: https://github.com/nginx-modules/ngx_cache_purge
kind: project
commit: ee733abb3c4a626f43e2fb9c1c603bedd744a346
for: [render-cache-invalidation]
looked: 2026-10-15
depth: docs (README)
relevance: medium
grade: B/fair
description: third-party nginx module adding PURGE by exact key, prefix wildcard and purge-all to open-source nginx caches; Debian and Ubuntu package it
---
# nginx-modules/ngx_cache_purge: cache purge module for open-source nginx

Why: open-source nginx has no proxy_cache_purge ([[nginx-proxy-module#^f5]]). What is
the usual add-on, and is it alive?

## Assessment

- Evidence: B. Fork of FRiCKLE/ngx_cache_purge (2010, 1,092 stars, original branch
  ends 2014); this fork 232 stars, 45 forks, 17 contributors, release 3.0.4 on
  11 Oct 2026, pushed 15 Oct 2026. Debian switched its package to this fork.
- Reasoning: fair. README is careful about limits (blocking filesystem walks, breaking
  changes), but parts read as agent-written ("This research did not run the test
  suite"): recent volume says little.
- Interests: none.
- Weigh: exact-key purge is the old, well-used core; wildcard, queue and Vary features
  are recent (3.x) and less proven. Ubuntu 24.04's package is the 2.3 line.

## Findings

- [render] [ops] Adds purge to open-source nginx proxy (and FastCGI, SCGI, uWSGI) caches: a request removes the entry whose key matches. `README.md` ^f1
  > An nginx module that adds cache purge support for `FastCGI`, `proxy`, `SCGI`, and `uWSGI` caches. A purge operation removes the cached entry whose key matches the purge request.
- [render] [ops] Purge forms: a PURGE method with IP access control, a trailing `*` prefix match that walks the cache directory, and purge_all. `README.md` ^f2
  > **Wildcard / partial purge** — trailing `*` walks the cache directory and removes all matching entries
- [render] [ops] Prefix purge only works when `$uri` is at the end of proxy_cache_key. `README.md` ^f3
  > Ensure `$uri` appears at the **end** of `proxy_cache_key` when using this feature, otherwise the prefix match will not align with the stored key.
- [render] [ops] Wildcard purges cost a synchronous directory walk even with the background queue. `README.md` ^f4
  > The queue callback still calls `ngx_walk_tree` synchronously. Deferring a purge does not remove its filesystem cost.
- [ops] Packaged as libnginx-mod-http-cache-purge in Debian and Ubuntu, but Ubuntu 24.04's build is the old 2.3 line, without 3.x features. `README.md` ^f5
  > Debian switched to this fork in version `1:2.5.3-1`; Ubuntu 24.04's published package is still based on 2.3.
- [ops] A distribution module must match the installed nginx build. `README.md` ^f6
  > Distribution modules may depend on a specific NGINX version or ABI, and 2.x packages do not provide the background queue directives introduced in 3.x.
- [render] Checked, not there: no tags or surrogate keys; purges are by key or key prefix only, so dependency purges need the caller to list URLs or share a URL prefix. ^f7
- [ops] Purge endpoints must not be public. `README.md` ^f8
  > Restrict purge endpoints with `allow` / `deny` directives or an upstream authentication layer. Never expose them publicly.

## Read

- `README.md`: features, compatibility, packages, directives, partial purge, security,
  technical notes

## Not read

- `ngx_cache_purge_module.c`, tests in `t/`
