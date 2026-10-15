---
title: 'Goel et al. 2014: Fast Database Restarts at Facebook (Scuba, SIGMOD)'
url: https://research.facebook.com/file/530430548191541/fast-database-restarts-at-facebook.pdf
kind: paper
commit: 
for: [fast-deploy-data-servers]
looked: 2026-10-15
depth: docs (whole paper, 6 pages)
relevance: high
grade: A/strong
description: SIGMOD 2014 industry paper; Scuba (in-memory analytics DB) copies heap data to shared memory on clean shutdown and back on start, so a code deploy takes 2-3 min per server instead of 2.5-3 h rebuilding from disk
---
# Goel et al. 2014: Fast Database Restarts at Facebook (Scuba, SIGMOD)

Why: our renderer rebuilds ~2.5 GB of derived in-memory data from SQLite on every code
deploy; Scuba had the same problem at 120 GB per machine and solved it with shared
memory restarts.

## Assessment

- Evidence: A. Peer-reviewed SIGMOD industry paper, production system (hundreds of
  servers, ~1M queries a day), and the same trick runs in Facebook's TAO and Memcache.
- Reasoning: strong. Names the alternatives (replicas, allocator in shared memory),
  why each was rejected, the crash case it doesn't cover, and the disk-format idea as
  the next step.
- Interests: none beyond the authors' own system.
- Weigh: numbers are theirs and unreplicated, but the mechanism is simple and the
  cost argument (translation, not disk read, dominates) is the part that transfers.

## Findings

- [ops] Restarting a Scuba server loses its heap; rebuilding 120 GB from the local disk
  backup took 2.5-3 h, mostly format translation, not I/O (disk read alone 20-25 min).
  Section 1 ^f1
  > Reading about 120 GB of data from disk takes 20-25 minutes; reading that data in its disk format and translating it to its in-memory format takes [...]
- [ops] Rolling 2% of servers at a time kept most data up but a full rollout took ~12 h
  watched by an engineer, which discouraged deploys. Section 1 ^f2
  > The entire system rollover then takes a lot longer, about 12 hours to restart the entire Scuba cluster with hundreds of machines.
- [ops] Rejected: redundant in-memory replicas to route around an upgrading server, as
  twice the servers and tricky sync code. Section 1 ^f3
  > We discarded that solution as too expensive in two dimensions: first, it would require twice as many servers.
- [ops] Key idea: decouple memory lifetime from process lifetime; on a planned
  shutdown the state is known good, so hand it to the next process. Abstract ^f4
  > Our key observation is that we can decouple the memory lifetime from the process lifetime.
- [ops] Design: data lives in the normal heap; copy to shared memory at shutdown and back
  at start, translating to a near-identical shared format. Section 1 ^f5
  > Scuba copies data from heap memory to shared memory at shutdown time and copies it back to the heap at startup.
- [ops] Rejected keeping all data in shared memory permanently: needs a custom
  allocator, thread safety and fragmentation risk. Section 3 ^f6
  > This alternative requires writing a custom allocator to subdivide shared memory segments.
- [ops] Separate heap and shared formats let the heap format change between versions
  and still restart from shared memory; a layout version number gates it. Section 1,
  4.2 ^f7
  > It also allows us to modify the in-memory format (in heap memory) and rollover to the new format using shared memory.
- [ops] Pointers inside a column block are offsets from its base, so each block moves
  with one memcpy. Section 2.1 ^f8
  > Using offsets enables us to copy the entire row block column between heap and shared memory in one memory copy operation.
- [ops] A valid bit guards it: set last on shutdown, cleared at start of restore; if not
  set, fall back to rebuild from disk. Crashes always rebuild from disk. Section 4 ^f9
  > If it is not set, the server reverts to recovering from disk (and frees any shared memory in use).
  > We do not use shared memory to recover from a crash; the crash may have been caused by memory corruption.
- [ops] Copy one block at a time (allocate shared, copy, free heap) so the footprint
  stays flat: no double memory during the handover. Section 4.4 ^f10
  > this method keeps the total memory footprint of the leaf nearly unchanged during both shutdown and restart.
- [ops] Result: 2-3 min per server instead of 2-3 h; whole cluster under an hour instead
  of 12 h. Sections 1, 4.5 ^f11
  > Scuba’s new upgrade path is about 2-3 minutes per server, rather than 2-3 hours.
- [ops] Fast restarts made deploying experimental builds to a few machines practical,
  as in Facebook's Memcache and TAO teams. Section 6 ^f12
  > we could not do if took longer. We can add more logging
- [ops] The real cost is translating disk format to memory format; the plan was to make
  the shared memory format the disk format too. Section 6 ^f13
  > One large overhead in Scuba’s disk recovery is translating from the disk format to the heap memory format.
- [ops] (inferred) For meiolol the transferable lesson is the last one: our 4 min to
  1 h is building derived structures from SQLite rows, the same translation cost.
  A snapshot file already in (or near) the in-memory layout removes it from every
  restart, crash or not, without the shared memory valid-bit machinery. ^f14

## Read

- Whole paper (abstract, sections 1-6).

## Not read

- Scuba's VLDB 2013 paper (reference 5): query processing, not restarts.
