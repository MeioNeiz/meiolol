---
title: 'Sumbaly et al. 2012: Serving Large-scale Batch Computed Data with Project Voldemort (FAST)'
url: https://www.usenix.org/legacy/event/fast/tech/full_papers/Sumbaly.pdf
kind: paper
commit: 
for: [fast-deploy-data-servers]
looked: 2026-10-15
depth: docs (sections 1-5.5)
relevance: high
grade: A/strong
description: USENIX FAST 2012 LinkedIn paper; derived data (People You May Know etc.) is built offline on Hadoop into an immutable index+data file format, pulled to serving nodes into versioned directories, mmapped and swapped in by symlink; rollback is the same swap
---
# Sumbaly et al. 2012: Serving Large-scale Batch Computed Data with Project Voldemort (FAST)

Why: the canonical "build derived data offline, serve an immutable snapshot" design,
with the alternatives LinkedIn tried first.

## Assessment

- Evidence: A. Peer-reviewed FAST paper, 2+ years in production at LinkedIn serving
  20+ data features, open source (Apache 2.0); measurements against MySQL.
- Reasoning: strong. Section 4 lists four approaches they tried and why each failed;
  admits costs (collisions from the shortened hash, keys stored in data file).
- Interests: authors' own system. LinkedIn later replaced it with Venice (lead, not read).
- Weigh: built for terabytes over many nodes; the transferable part is the shape
  (offline build, immutable files, mmap, versioned dirs, symlink swap), not the scale.

## Findings

- [ops] Problem: bulk loading big derived data into a live server hurts serving,
  because building the index competes for CPU and memory. Abstract ^f1
  > The performance degradation is largely due to index creation and modification as CPU and memory resources are shared with request serving.
- [ops] Fix: build the index offline (Hadoop), so the serving node does no building.
  Abstract ^f2
  > This extension constructs the index offline, by leveraging the fault tolerance and parallelism of Hadoop.
- [ops] Derived data is refreshed nearly whole each cycle, so live updates aren't needed;
  the few live changes (dismissals) sit in a separate store and are applied at page load.
  Section 1 ^f3
  > Interestingly, the nature of this complete cycle means that live updates are not necessary and are usually handled by auxiliary data structures.
- [ops] Tried first, rejected: loading into a second MySQL table on the same servers and
  swapping a view still hurt latency during the load. Section 4.1 ^f4
  > This approach solves the locking problem, but still hurts serving latency during the load due to pressure on shared CPU and memory
- [ops] Design choice: lean on the OS page cache with mmapped immutable files rather than
  a heap structure that duplicates or competes with it. Section 5.1 ^f5
  > This potential interference motivated the need for our storage engine to exploit the page cache instead of maintaining our own complex heap-based data structure.
  > Because our data is immutable, Voldemort memory maps the entire index into the address space.
- [ops] Index file format: sorted fixed-width entries (8 byte key hash, 4 byte offset),
  so lookup is binary search with no internal pointers. Section 5.1, 5.5 ^f6
  > The index file is a compact structure containing the sorted upper 8 bytes of the MD5 of the key followed by the 4 byte offset of the corresponding value in the data file.
- [ops] Versions: one directory per data version, a symlink names the serving one; old
  ones are kept for rollback and, being inactive, cost no page cache. Section 5.3 ^f7
  > A symbolic link per store is used to point to the current serving version directory.
- [ops] Swap = copy into new dir, close old files, open new, mmap index, flip symlink,
  under a read-write lock; rollback is the same; no data reads, so it is fast. Section 5.3 ^f8
  > Both of these operations are very fast as they are purely metadata operations: no data reads take place.
- [ops] Measured swap on one of the largest clusters: about 0.012 ms average, worst
  0.050 ms. Section 5.4 ^f9
  > this complete operation takes around 0.012 ms on average with the worst swap time of around 0.050 ms.
- [ops] Fetch is pull-based and throttled, with a checksum from the build step checked
  while streaming. Section 5.4 ^f10
  > Voldemort uses a pull model, rather than a push model, as it allows throttling of this fetch in case of latency spikes.
- [ops] Rollback was a hard requirement: rerunning a long batch to fix bad data was not
  acceptable. Section 4.2 ^f11
  > In such scenarios, running a long batch load job to repopulate correct data is not acceptable.
- [ops] (inferred) For meiolol: if the renderer's derived data were a file written by a
  separate build step (on the crawler side), a code deploy would just reopen/mmap the
  current file, and a data refresh would swap a symlink, so code and data lifecycles
  separate. ^f12

## Read

- Abstract, sections 1-5.5.

## Not read

- 5.6-5.7 (schema change, rebalancing), section 6 benchmarks, section 7.
