---
title: 'Lookbook v2 docs: Introduction'
url: https://lookbook.build/guide
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (introduction)
relevance: medium
grade: A/fair
description: Lookbook, the Rails component preview browser built for server-rendered ViewComponents (Storybook fits JS frameworks poorly there); used by GitHub and GitLab
---
# Lookbook v2 docs: Introduction

Why: what a component gallery for server-rendered components is, and who uses one.

## Assessment

- Evidence: A. Since June 2021, 1,100 stars, active (pushed Oct 2026); used by GitHub,
  GitLab and others.
- Reasoning: fair. Says why it exists versus Storybook.
- Interests: its own project.
- Weigh: confirms the pattern; its features (params panel, nav tree) are more than a
  static gallery page needs.

## Findings

- [web/qa] [web/template] A browser for previewing server-rendered components in
  isolation, to develop, test and document them. About ^f1
  > helps you **develop, test & document** those components in isolation from each other.
- [web/qa] Storybook fits JS-framework UIs; with server-rendered components it needs
  complex custom setups. Why Lookbook ^f2
  > But Storybook _doesn’t_ play so nicely with Rails apps that are using Ruby-based, server-side rendered component frameworks
- [web/qa] Users include GitHub and GitLab. Who uses ^f3

## Read

- Introduction

## Not read

- Previews, params, pages and sharing guides
