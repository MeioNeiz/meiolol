---
title: 'Cloudflare: Content compression (docs, Apr 2026)'
url: https://developers.cloudflare.com/speed/optimization/content/compression/
kind: docs
commit: 
for: [brotli-through-cloudflare]
looked: 2026-11-06
depth: docs (whole page)
relevance: high
grade: A/fair
description: Cloudflare's own page on compression to visitors and from origins, by plan
---
# Cloudflare: Content compression (docs, Apr 2026)

Why: will Cloudflare keep meio.lol's precompressed brotli (nginx brotli_static) or
recompress it?

## Assessment

- Evidence: A. The vendor's reference for its own behaviour, updated 17 Apr 2026.
- Reasoning: fair. States rules, few reasons; caching per encoding only implied.
- Interests: vendor describing its product; no comparison.
- Weigh: trust the rules; verify passthrough through our Tunnel ourselves (C01 curl and
  nginx's bytes sent), since cloudflared sits between.

## Findings

- [ops] [render] Cloudflare asks every origin for br or gzip, on all plans. ^f1
  > On all plans, Cloudflare requests content from the origin server using the accept-encoding: br, gzip header.
- [ops] [render] An origin's br or gzip response keeps its encoding to a visitor that
  supports it, given a content-encoding header and no content-changing feature. ^f2
  > If your origin server responds to a Cloudflare request using Brotli/Gzip compression, we will keep the same compression in the response sent to the website visitor if:
- [ops] [render] Cloudflare converts between br, gzip and none as each visitor needs,
  independently of caching. ^f3
  > Cloudflare can receive content from your origin server with Brotli or Gzip compression and serve it to visitors uncompressed (or vice versa), independently of caching.
- [ops] [render] Some features force decompress and recompress even with one encoding end
  to end: Automatic HTTPS Rewrites, Fonts, Email Obfuscation, Polish, Rocket Loader,
  JavaScript detections, RUM; Replace insecure JS libraries can't be turned off. ^f4
  > Cloudflare will need to decompress the response and compress it again if you enable any of the following settings for the request
- [ops] Free plan compresses to visitors with Zstandard by default. ^f5
  > Free Plan: Content is compressed by default using Zstandard.
- [ops] application/wasm is in the list of types Cloudflare compresses. ^f6
  > application/wasm
- [ops] `cache-control: no-transform` from the origin stops Cloudflare changing the
  compression. ^f7
  > If you do not want a particular response from your origin to be encoded with Brotli/Gzip when delivered to website visitors, you can disable this by including a `cache-control: no-transform` HTTP header in the response from your origin web server.
- [ops] (inferred) Measured from C01 6 Nov (data/team/2026-11-05-notes2/brotli-before.txt):
  origin gzip passes through untouched for wasm (DYNAMIC) and js (HIT), Chrome's
  Accept-Encoding included; the rendered champion page is recompressed (Chrome gets zstd
  43,641 B against our gzip 40,301 B), so some ^f4 feature touches HTML. ^f8

## Read

- whole page, including "Notes about end-to-end compression" and plans

## Not read

- Compression Rules and Configuration Rules pages: how to exempt HTML from ^f4 features
