---
title: GetOrPut With String Keys (Karl Seguin, 2025)
url: https://www.openmymind.net/GetOrPut-With-String-Keys/
kind: article
commit:
for: [zig-memory, zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/fair
description: getOrPut does one lookup; with owned string keys, dupe only when the entry is new by writing key_ptr
---
# GetOrPut With String Keys (Karl Seguin, 2025)

Why: the idiomatic counting/upsert loop with owned keys.

## Assessment

- Evidence: B. Practitioner, Feb 2025, Zig 0.14; API unchanged in 0.17 (unmanaged maps
  take the allocator).
- Reasoning: strong; shows the leak, a wasteful fix and the right one.
- Interests: none known.
- Weigh: trust. His remark that removals don't invalidate pointers conflicts in spirit
  with his Learning Zig example where the removed value reads as garbage: the slot stays
  but its value is undefined, so treat any pointer into a map as invalid after mutation.

## Findings

- [zig/perf] `getOrPut` does one hash lookup for insert-or-update, versus two for get then put. ^f1
  > With `getOrPut`, it's a single hash lookup:
- [zig/memory] Pointers from `getPtr` die when the map grows; keep their scope small. ^f2
  > If the underlying array changes, as can happen when items are added to the map, `value` would become invalid. So, while `getPtr` is useful, it requires mindfulness: try to minimize the scope of such references.
- [zig/memory] He says removal doesn't shrink the map, so it doesn't move entries, but expects that to change. ^f3
  > Currently, Zig's HashMap doesn't shrink when items are removed, so, for now, removing items doesn't invalidate any pointers into the hashmap. But expect that to change at some point.
- [zig/memory] Duping the key before `getOrPut` leaks when the entry already exists. ^f4
  > When `gop.found_existing == true`, `owned` is never used and never freed.
- [zig/memory] Right pattern: look up with the borrowed key; only on a new entry overwrite `gop.key_ptr.*` with an owned dupe. ^f5
  > gop.key_ptr.* = try allocator.dupe(u8, name);
- [zig/memory] (inferred) Limit on ^f5: if the dupe fails after `getOrPut` inserted, the map holds a borrowed key and undefined value; pair it with `errdefer map.removeByPtr(gop.key_ptr)` or similar. ^f6
- [zig/api] He uses the unmanaged map variant because managed containers were expected to be removed. ^f7
  > I'm using the Unmanaged variant because the Managed ones are likely to

## Read

- Whole post.
