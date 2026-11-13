---
title: 'Lichess: Developer update: 275% improved game compression (2018)'
url: https://lichess.org/blog/Wqa7GiAAAOIpBLoY/developer-update-275-improved-game-compression
kind: article
commit:
for: [box-disk-headroom]
looked: 2026-11-13
depth: listed
relevance: medium
grade: A/strong
description: Lichess (680M games in 2018) on running out of database disk and answering with both bigger servers and a domain-specific game encoding
---
# Lichess: Developer update: 275% improved game compression (2018)

Why: how a large game archive with steady growth handled disk: buy, compress, or both

## Assessment

- Evidence: A. Lichess is one of the largest game archives (680M games at the time), the
  post is first-hand from its developers, code published and the migration run.
- Reasoning: strong. Says why general-purpose compression leaves room (domain knowledge)
  and that encoder speed matters (thousands of games a second).
- Interests: none.
- Weigh: chess moves are far more compressible by domain knowledge than our JSON; the
  lesson is the shape of the decision (both levers at once, domain codec over generic),
  not the ratio.

## Findings

- [ops] Lichess answered a full disk with both levers at once: upgrading the servers and
  a denser game format. ^f1
  > We need more storage space, so we're upgrading the servers and we're also trying to store the games more efficiently.
- [ops] Its database ran on 3 servers, each with two 480 GB SSDs in RAID 1, plus a
  delayed replica: every byte stored several times over. ^f2
  > Our database runs on 3 servers (1 primary, 2 secondaries), each with two 480GB SSDs in a RAID 1 configuration
- [ops] Generic transparent compression (MongoDB's Snappy and zlib) was judged weaker than
  a codec that knows the domain. ^f3
  > MongoDB supports transparent Snappy and zlib compression, but it's clear that we can use chess knowledge to perform better than general purpose compression schemes.
- [ops] The format change saved about 70 GB on 680M games and was expected to slow the
  database's growth; old games were migrated by script. ^f4
  > The lichess database contains 680 million games (as of 2018/03/12) so we expect to gain about 70 GB right now and significantly slow the growth of the database from now on.
- [ops] (inferred) Our jsonpack is the same move (domain structure before zstd); its gain is
  already taken, so what is left for us is the "upgrade the servers" half. ^f5

## Read

- Whole post

## Not read

- Code (lichess-org/compression) and the 2024 3.7 bits per move follow-up: chess only
