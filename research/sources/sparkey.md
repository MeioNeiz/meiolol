---
title: 'Spotify Sparkey: constant key/value store (README and hash reader)'
url: https://github.com/spotify/sparkey
kind: project
commit: d694f20f35caa1cb514c84f3f02e94f71248f857
for: [fast-deploy-data-servers]
looked: 2026-10-15
depth: code (README.md, src/hashreader.c)
relevance: medium
grade: B/fair
description: Spotify's C library for immutable on-disk hash tables (append-only log file plus hash index file), built offline and mmapped by serving processes; open cost is constant regardless of size
---
# Spotify Sparkey: constant key/value store (README and hash reader)

Why: a small, real example of the "offline build writes an immutable file, services
open it in constant time" pattern, the nearest in size to our case.

## Assessment

- Evidence: B. Used in Spotify production services; 1,210 stars, 85 forks, 10
  contributors, created Aug 2013, last push Aug 2023 (dormant), Apache 2.0, no
  releases; official Java and Python ports.
- Reasoning: fair. Explains why it replaced CDB (4 GB limit) and Tokyo Cabinet, and its
  one memory limit; benchmark is their own small program.
- Interests: none (open-source library, no product).
- Weigh: the format details and the workflow are the point, not the library; we would
  not take a C dependency, but the same shape is a few hundred lines of Zig.

## Findings

- [ops] Spotify's flow: offline systems generate large static files, pushed to the
  user-facing services that serve them. README History ^f1
  > Our flow consists of first generating large static storage files in our offline-systems, which then gets pushed out to the user facing services to serve the data.
- [ops] Built for rarely-updated data: bulk writes cheap enough to rebuild periodically,
  reads fast enough for low-latency services. README Description ^f2
  > The fast and efficient bulk writes makes it feasible to periodically rebuild the data,
- [ops] Key properties: immutable hash table, any number of concurrent readers, one
  writer, constant read startup cost. README Description ^f3
  > Immutable hash table.
  > Constant read startup cost
- [ops] Format: an append-only log of key/value entries plus an immutable hash index of
  fixed 16-byte slots (hash + offset into the log). README Design, Hash file format ^f4
  > The other file is the sparkey index file (.spi) which is a just a hashtable pointing at entries in the log.
  > That means that the slotsize is usually 16 bytes for any reasonably large set of entries.
- [ops] Opening a reader stats the file and mmaps it read-only; no parsing or loading
  of entries, which is why startup cost is constant. `src/hashreader.c` ^f5
  > reader->data = mmap(NULL, reader->data_len, PROT_READ, MAP_SHARED, reader->fd, 0);
- [ops] When the data fits in RAM they mlock it; separate index and log files let them
  lock just the index. README Design ^f6
  > For some of our usecases, the total data set is less than the available RAM, so it makes sense to mlock everything.
- [ops] Not robust to corruption, and building the hash needs about 16 x 1.3 bytes of RAM
  per entry. README ^f7
  > It's not robust against data corruption.
  > The hash writing process requires memory allocation of num_entries * 16 * 1.3 bytes.
- [ops] (claim) Own benchmark: 100 million entries written in 82 s wall into a 4.3 GB
  file, then about 500k random lookups per CPU second. README Performance ^f8
  > creation time (wall):     82.00
- [ops] (inferred) For meiolol: a 2.5 GB snapshot in a fixed, pointer-free layout would
  open in milliseconds via mmap whatever the disk load, with the page cache (shared
  between old and new processes during a swap) doing the warm-up lazily. ^f9

## Read

- README.md (all), src/hashreader.c open path.

## Not read

- sparkey-java (removed the hash-build memory limit), bench.c, compression code.
