---
title: 'ASP (UK police) Design System: Filter component'
url: https://asp-design-system.policedigital.services/components/filter/
kind: docs
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: listed
relevance: low
grade: C/fair
description: UK police digital design system filter component (work in progress): filters submit with URL parameters so state can be reloaded, shared and kept in history; JS only adds a collapse toggle
---
# ASP (UK police) Design System: Filter component

Why: the reasons a design system gives for filter state in URL parameters.

## Assessment

- Evidence: C. Narrow public-sector design system, parts marked WIP.
- Reasoning: fair. States the reason (reload, share, history).
- Interests: none.
- Weigh: a second public-sector example of submit-and-reload filters.

## Findings

- [web] Filters submit as URL parameters so the filtered view can be reloaded,
  shared and kept in history. ^f1
  > The form should submit with params, so the page can be reloaded/shared with the current state, also history can be preserved per pageload.
- [web] Apply filters reloads the page with matching items. ^f2
  > When the user clicks ‘Apply filters’ the page refreshes to show the items that match the filters.
- [web] JS only enhances (a collapse toggle); without JS the button stays hidden and
  the filters visible. ^f3
  > If JavaScript is disabled, the button remains hidden and content visible.
- [web] (inferred) For meiolol's static nginx site, a GET form yields query strings
  (?rank=...); either nginx maps them to pre-rendered paths or the form targets one
  page per combination, since there is no server to filter. ^f4

## Read

- Component page

## Not read

- Example markup
