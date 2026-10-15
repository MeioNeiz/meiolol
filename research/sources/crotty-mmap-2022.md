---
title: 'Crotty, Leis, Pavlo 2022: Are You Sure You Want to Use MMAP in Your Database Management System? (CIDR)'
url: https://db.cs.cmu.edu/papers/2022/cidr2022-p13-crotty.pdf
kind: paper
commit: 
for: [fast-deploy-data-servers]
looked: 2026-10-15
depth: docs (abstract, 1-2, 3.2-3.4 skimmed, 4 summary, 6)
relevance: medium
grade: A/strong
description: CIDR 2022 critique of mmap as a DBMS buffer pool (CMU, TUM); catalogues safety, I/O stall, error-handling and eviction-scaling problems and DBMSs that dropped mmap, but says mmap may be fine when the data fits in memory and is read-only
---
# Crotty, Leis, Pavlo 2022: Are You Sure You Want to Use MMAP in Your Database Management System? (CIDR)

Why: the critic's view on "just mmap a snapshot file"; does it apply to a read-only
2.5 GB snapshot on a VM with RAM to spare?

## Assessment

- Evidence: A. Peer-reviewed CIDR paper by recognised DB systems researchers (Pavlo,
  Leis), with experiments and a list of production systems that dropped mmap.
- Reasoning: strong. Separates problems by kind and states when mmap is acceptable.
- Interests: the authors advocate buffer-pool designs (their own research line); the
  title and tone are deliberately one-sided.
- Weigh: the strongest failures (transactions, eviction under larger-than-memory load,
  multi-SSD bandwidth) are outside our case; the I/O stall and SIGBUS points apply.

## Findings

- [ops] Their main argument: mmap is a poor replacement for a DBMS buffer pool, with
  correctness and performance problems that show up late. Abstract ^f1
  > There are, however, severe correctness and performance issues with mmap that are not immediately apparent.
- [ops] Several DBMSs adopted then dropped mmap (MongoDB MMAPv1, InfluxDB, SingleStore);
  RocksDB forked LevelDB partly over mmap read bottlenecks. Section 2.3 ^f2
  > Facebook created RocksDB as a fork of Google’s LevelDB partly due to performance bottlenecks for reads caused by the latter’s use of mmap
- [ops] Even read-only access can stall: any touched page may have been evicted and fault
  in synchronously, and the program can't tell in advance. Section 3.2 ^f3
  > read-only queries can unknowingly trigger blocking page faults if they attempt to access evicted pages.
- [ops] I/O errors surface as SIGBUS anywhere the mapped memory is read, not at one read
  call. Section 3.3 ^f4
  > any code that interacts with mmap-backed memory can now produce a SIGBUS that the DBMS must deal with via cumbersome
- [ops] Measured: mmap matches direct I/O until the page cache fills, then is 2-20x
  worse; their tests were larger-than-memory reads over 2 TB. Section 4 ^f5
  > In summary, we found that mmap performs well only on a single SSD during the initial loading phase.
- [ops] Their own carve-out: mmap may be acceptable when the working set fits in memory
  and the workload is read-only. Section 6 ^f6
  > Your working set (or the entire database) fits in memory and
  > the workload is read-only.
- [ops] (inferred) A derived-data snapshot written once and only read, smaller than RAM,
  sits inside the carve-out (f6); the remaining risk is f3: cold or evicted pages stall
  requests, so warm it (sequential read or MAP_POPULATE) before serving, or read() the
  file into the heap, which on a fast disk costs seconds, not a rebuild. ^f7

## Read

- Abstract, sections 1, 2 (2.3 in full), 3.2-3.3 and 4 summary, 6.

## Not read

- 3.4 details (TLB shootdowns, page table contention), figures.
