---
title: 'Manticore 2018: About startup, mmap, mlock and --force-preread'
url: https://manticoresearch.com/blog/about-startup-mmap-mlock-and-force-preread/
kind: article
commit: 
for: [fast-deploy-data-servers]
looked: 2026-10-15
depth: docs (whole post)
relevance: high
grade: B/fair
description: Manticore Search (Sphinx fork) engineering post on serving prebuilt indexes via mmap at startup: fast to start but only cached, not resident; mlock to pin, --force-preread to wait for warm before serving; measured 6 min warm-up vs tens of minutes of slow queries
---
# Manticore 2018: About startup, mmap, mlock and --force-preread

Why: if our renderer mmaps a snapshot instead of building data, what does the first
period after a restart look like on a small VM with busy disks?

## Assessment

- Evidence: B. Search engine maintainers (Sphinx lineage, years of production use)
  describing their own daemon's startup; one pair of charts, not reproduced.
- Reasoning: fair. States the trade-off both ways and says it depends on load
  balancing and RAM; no numbers beyond the one example.
- Interests: vendor blog, but this post is about limits of their own feature.
- Weigh: the mechanism (page cache, mlock, preread) is OS behaviour and holds for any
  mmapped snapshot; the 6 min figure is one case.

## Findings

- [ops] Manticore moved from loading index files into RAM to memory-mapping them,
  which makes startup much faster. ^f1
  > now all the indexes (attributes and word lists files) are not physically loaded into RAM, but memory-mapped instead. It allows to bring them up much faster on startup
- [ops] A mapped file is only cached, not resident: other processes can push it out, so
  latency is not predictable. ^f2
  > So 'loading' the index provides no guarantee that it is actually in RAM and will respond predictably fast.
- [ops] mlock pins it, but the lock is one blocking sequential read of the whole file,
  can't be throttled, and can starve other I/O on the machine. ^f3
  > No way to interrupt, no way to throttle i/o, just wait. So, process of mlocking may affect another i/o ops on the machine.
- [ops] mlock can also trigger the OOM killer to make room. ^f4
  > When system looks for RAM for mlocking chances are it will call OOM-killer in order to free the RAM for you which can kill another process.
- [ops] Trade-off at start: serve immediately with a cold index warming in the
  background, or preread first and serve only when warm. ^f5
  > w/o `--force-preread` the searchd will start serving connections sooner, but the indexes will be colder until they're full preread in the background.
- [ops] Their example: waiting 6 min for preread beat serving cold, which gave several
  times higher response times and heavy iowait for tens of minutes. ^f6
  > it makes sense to wait 6 min at start, otherwise the avg response time becomes times higher for tens of minutes and the iowait is extremely high too due to the queries that do random disk reads.
- [ops] (inferred) For meiolol: an mmapped snapshot removes the build, but on our VM
  under disk contention a cold start still pays reading 2.5 GB. A sequential preread
  (one pass, like their --force-preread) before taking traffic is cheaper than random
  page faults; and on a restart in place the old process's pages are usually still in
  the page cache, so the new process opens warm. ^f7

## Read

- Whole post.

## Not read

- The companion post "Indexes load at startup" (lead).
