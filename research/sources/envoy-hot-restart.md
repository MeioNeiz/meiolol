---
title: 'Envoy docs: Hot restart'
url: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/hot_restart
kind: docs
commit: 
for: [fast-deploy-data-servers]
looked: 2026-10-15
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Envoy proxy's hot restart: new process fully initialises, then takes the listen sockets from the old one over a unix socket and tells it to drain; no dropped connections, code and config both reloaded
---
# Envoy docs: Hot restart

Why: the pattern for "restart in place" on one host without a gap: start the new
process, let it get ready, then hand over the listening socket.

## Assessment

- Evidence: A. Official docs of a CNCF-graduated proxy in wide production use; hot
  restart has shipped since the early versions.
- Reasoning: fair. Describes the mechanism and its limits (connections not migrated,
  socket options, no Windows), not why alternatives were rejected.
- Interests: none.
- Weigh: Envoy's state is small (config, stats), so it only shows the socket handover
  and readiness ordering, not how to keep big data across a restart.

## Findings

- [ops] Envoy can reload both code and config without dropping connections; existing
  connections finish on the old process or are closed. ^f1
  > This means that Envoy can fully reload itself (both code and configuration) without dropping existing connections during the
- [ops] Order: the new process initialises fully (config, service discovery, health
  checks) before asking the old one for the listen sockets, then starts listening and
  tells the old one to drain. ^f2
  > The new process fully initializes itself (loads the configuration, does an initial service discovery and health checking phase, etc.) before it asks for copies of the listen sockets from the old process.
- [ops] Handover is over unix domain sockets only, so it works across containers. ^f3
  > Communication between the processes takes place only using unix domain sockets.
- [ops] With reuse_port the sockets are passed per worker, so nothing is lost in the
  accept queues. Socket handling ^f4
  > Envoy passes each socket to the new process by worker index. Thus, no connections are dropped in the accept queues of the draining process.
- [ops] Shared state across the restart is just stats: counters and gauges are sent from
  old to new process. ^f5
  > All counters are sent from the old process to the new process over the unix domain
- [ops] (inferred) For meiolol: blue/green on one box doubles memory and load only for
  as long as the new process takes to get ready. If readiness is "mmap the snapshot and
  preread it" (seconds, page cache shared with the old process), the overlap is short;
  if it is "rebuild from SQLite", the overlap is the whole rebuild. ^f6

## Read

- Whole page.

## Not read

- Draining page, restarter/hot-restarter.py.
