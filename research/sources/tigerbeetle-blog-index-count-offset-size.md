---
title: Index, Count, Offset, Size (TigerBeetle blog, matklad, 2026)
url: https://tigerbeetle.com/blog/2026-02-16-index-count-offset-size
kind: article
commit:
for: [zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: A/fair
description: naming convention for index, count, offset and size (no `length`), combined with suffix qualifiers and equal-length dual names
---
# Index, Count, Offset, Size (TigerBeetle blog, matklad, 2026)

Why: the concrete naming convention behind Tiger Style's off-by-one section.

## Assessment

- Evidence: A. TigerBeetle convention with two real functions (NodePool.release,
  ewah.decode).
- Reasoning: fair: argued from readability; admits a naming rule alone doesn't fix
  much.
- Interests: none.
- Weigh: general, directly applicable to any slice-heavy code.

## Findings

- [zig/style] `count` is a number of items, `index` points at one; the positive
  invariant is `index < count`. ^f1
  > We consistently use `count` whenever we talk about the number of items, and `index` to point to a particular item.
- [zig/style] Bytes get their own words: `size = @sizeOf(T) * count`, `offset` is the
  byte counterpart of `index`. ^f2
  > the “count of bytes” is always called a `size`.
  > And `offset` is the bytewise counterpart of `index`.
- [zig/style] No `length`: it is ambiguous (bytes in Rust's `str::len`, code points in
  Python). ^f3
  > We don’t use `length` in our code, as its meaning is ambiguous.
- [zig/style] With consistent suffixes, wrong combinations show in review even without
  understanding the code; `@divExact(node_offset, node_size)` gives `node_index`. ^f4
  > if there’s always an `_index` or a `_count` suffix in the name, wrong combinations immediately jump out at you
  > @divExact(node_offset, node_size);
- [zig/style] Synergy with big-endian naming (`source`, `source_words`,
  `source_index`) and equal-length duals (`source`/`target`): parallel lines align. ^f5
  > The code aligns itself, and makes the bugs pop out:
- [zig/style] Newtype indexes (`enum(u32)`) help only without index arithmetic. ^f6
  > If you don’t need indexing _arithmetic_, you can use [newtype pattern]

## Read

- Whole post.
