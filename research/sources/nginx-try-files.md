---
title: 'nginx: ngx_http_core_module, try_files (docs)'
url: https://nginx.org/en/docs/http/ngx_http_core_module.html
kind: docs
commit: 
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: docs (try_files)
relevance: high
grade: A/fair
description: nginx try_files: serve the first file that exists, else hand the request to a fallback URI or named location (e.g. an app server)
---
# nginx: ngx_http_core_module, try_files (docs)

Why: the simplest hybrid is "static file if we built it, else render": does nginx do
that natively?

## Assessment

- Evidence: A. nginx reference docs.
- Reasoning: fair.
- Interests: none.
- Weigh: the site's config already uses try_files for static pages.

## Findings

- [render] [ops] try_files serves the first file that exists and otherwise redirects internally to the last parameter, which can be a named location proxied to a render server. ^f1
  > Checks the existence of files in the specified order and uses the first found file for request processing
  > If none of the files were found, an internal redirect to the `_uri_` specified in the last parameter is made.
- [render] (inferred) So prerendered matchup pages stay plain files, and missing ones fall through to a renderer, with no change for pages that exist. ^f2

## Read

- try_files

## Not read

- the rest of the core module
