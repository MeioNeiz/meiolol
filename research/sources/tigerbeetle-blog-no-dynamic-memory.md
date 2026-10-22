---
title: A Database Without Dynamic Memory Allocation (TigerBeetle blog, Phil Eaton, 2022)
url: https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory
kind: article
commit:
for: [zig-memory]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: how TigerBeetle sizes all memory at startup from fixed limits (connections, messages, batch sizes) and why
---
# A Database Without Dynamic Memory Allocation (TigerBeetle blog, Phil Eaton, 2022)

Why: the long-form rationale for Tiger Style's static allocation rule.

## Assessment

- Evidence: B. Introductory post from 2022 (Zig 0.9 links); the mechanism still holds
  at 0450c32 ([[tigerbeetle-code#^f10]]), but the code shown is old.
- Reasoning: fair. Clear benefits list; costs mentioned only as "up-front thinking".
- Interests: company blog, marketing tone.
- Weigh: the technique depends on a fixed set of fixed-size objects; storage
  growth goes to disk. Stale API names (0.9 `ArrayList` links).

## Findings

- [zig/memory] Zig's std containers suit static allocation: `AssumeCapacity` methods
  (`addOneAssumeCapacity`, `putAssumeCapacityNoClobber`) catch accidental growth. ^f1
  > Methods like [ArrayList.addOneAssumeCapacity]
  > help catch bugs where we would accidentally allocate more memory.
- [zig/memory] Fixed limits handle overload: no buffer grows when a client misbehaves. ^f2
  > With fixed sizes of objects and arrays, there is no ever-growing buffer when an incorrectly-configured client tries to make too many connections or send too many messages at once.
- [zig/memory] [zig/comptime] Memory needed is a comptime sum over every user of a
  message, each term commented with its owner. ^f3
  > pub const messages_max_replica = messages_max: {
  > sum += config.clients_max; // Replica.client_table
- [zig/memory] [zig/test] Wrong sizing is caught by assertions plus fuzzing rather
  than by resource exhaustion in production. ^f4
  > When combined with assertions, static allocation is a force multiplier for fuzzing!
- [zig/memory] The dynamic part of a database is on disk; only the in-memory LSM
  portion is bounded and allocated at startup. ^f5
  > The dynamic part of the database is what’s stored on disk.
- [zig/memory] (inferred) The precondition is that the program can bound every input
  up front (connections, message size, batch size); a crawler fed by an external API or
  a site generator over growing data cannot, without capping its input. ^f6

## Read

- Whole post.
