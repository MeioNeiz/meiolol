---
title: 'htmx essay: Hypermedia-Friendly Scripting'
url: https://htmx.org/essays/hypermedia-friendly-scripting/
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole essay)
relevance: high
grade: B/strong
description: htmx essay on which client script fits a server-rendered app: HTML over the wire, client-only state allowed, islands and events
---
# htmx essay: Hypermedia-Friendly Scripting

Why: where to draw the line between Zig-rendered fragments and the little script that
must stay

## Assessment

- Evidence: B. htmx maintainers' design rules, grounded in Fielding's REST.
- Reasoning: strong. States each rule's reason and when it bends.
- Interests: htmx authors.
- Weigh: rules of thumb, not measurements; they match our split of S (server) and G
  (glue) in the 22 Oct JS inventory.

## Findings

- [web] Script should not exchange data formats such as JSON with the server; fetch is fine when the reply is HTML. ^f1
  > scripting should avoid making non-hypermedia exchanges over the network with a server
  > avoid the use of `fetch()` and `XMLHttpRequest` _unless_ the responses from the server use a hypermedia of some sort
- [web] Client-only state (a toggle, a widget's model) is fine; state the server must know goes through a hypermedia exchange. ^f2
  > The crucial aspect to consider is whether any state updated on the client side needs to be synchronized with the server.
- [web] Components that need real client logic live as islands and talk to the rest through events. ^f3
  > use the island architecture. This isolates non-hypermedia components from the rest of the Hypermedia-Driven Application.

## Read

- whole essay

## Not read

- Hypermedia-Driven Applications essay it builds on
