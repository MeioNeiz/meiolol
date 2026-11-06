---
status: answered
priority: now
area: ops
tags: [ops, render]
description: Does Cloudflare pass an origin's precompressed brotli (Content-Encoding: br) through to browsers, and how does it cache per encoding?
---
# Does Cloudflare pass an origin's precompressed brotli (Content-Encoding: br) through to browsers, and how does it cache per encoding?

Feeds: data/team/2026-11-05-notes2/brotli.md (nginx brotli_static on C01 for the hashed
front-end files)

## Answer

Yes, by Cloudflare's docs: it asks origins for `br, gzip` on every plan (C1) and keeps an
origin's br for visitors that accept br (C2), converting for those that don't, whatever
it cached (C3). Our measurement agrees for gzip: wasm and js reach Chrome as nginx sent
them (C5). HTML is the exception: a content-changing feature recompresses the rendered
pages (C4, C5), so origin br there would be undone. Free plan's default zstd applies only
to what Cloudflare compresses itself. Still to see: br through the Tunnel after the
install (nginx bytes sent per request).

## Claims

- C1: Cloudflare requests origin content with `accept-encoding: br, gzip`. for: [[cf-content-compression#^f1]]
- C2: Origin br is kept for visitors that support br, unless a content-changing feature is on. for: [[cf-content-compression#^f2]]
- C3: Cloudflare converts between encodings per visitor, independent of caching. for: [[cf-content-compression#^f3]]
- C4: Features such as RUM, JS detections and Email Obfuscation force recompression. for: [[cf-content-compression#^f4]]
- C5 (inferred): On meio.lol origin gzip passes through for wasm and js; pages are recompressed. for: [[cf-content-compression#^f8]]

## Disagreements

## Open

- Which feature recompresses HTML, and can a Configuration Rule exempt pages (our gzip
  is 8% under the zstd Chrome gets)
- Hashed .wasm is DYNAMIC at Cloudflare (not cached at the edge): a Cache Rule would cut
  origin requests
