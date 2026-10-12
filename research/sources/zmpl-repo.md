---
title: 'Zmpl (jetzig-framework/zmpl): README, build.zig.zon'
url: https://github.com/jetzig-framework/zmpl
kind: project
commit: 0cb5ef895b3a8b84792c2284418160bb0d0930ff
for: [zig-web-ui]
looked: 2026-10-12
depth: docs (README, build.zig.zon)
relevance: medium
grade: B/fair
description: HTML templating language for Zig, compiled to Zig code; the template engine of the Jetzig web framework
---
# Zmpl (jetzig-framework/zmpl): README, build.zig.zon

Why: could a Zig template language replace our w.print HTML?

## Assessment

- Evidence: B. Created 2024-01, pushed 2026-10-09, 247 stars, 15 contributors; used by Jetzig.
- Reasoning: fair. README lists features, no design discussion.
- Interests: none known.
- Weigh: Zig version support (min 0.15.1) and how templates get their data (ZmplValue, JSON-like) need a trial build on 0.16.

## Findings

- [web] Templates use Zig code for control flow and compile to Zig for syntax and type checks. `README.md` ^f1
  > Use Zig code directly in templates for control flow.
  > Compiles to Zig code for syntax and type validation.
- [web] Template data is a JSON-like dynamic object looked up by path (`$.user.email`), not typed Zig values. `README.md` ^f2
  > Simple and intuitive DSL for building flexible, JSON-compatible data objects.
- [web] Partials with positional and keyword args and slots: the component mechanism. `README.md` ^f3
  > Partials with keyword args
- [web] [toolchain] Declares minimum Zig 0.15.1; 0.16 support not stated. `build.zig.zon` ^f4
  > .minimum_zig_version = "0.15.1",
- [web] Checked, not there: nothing for client-side interactivity; it renders HTML text only. ^f5

## Read

- `README.md`: all
- `build.zig.zon`: version line

## Not read

- jetzig.dev documentation: how ZmplValue data is built; whether it builds on Zig 0.16
