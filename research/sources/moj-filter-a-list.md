---
title: 'MOJ Design System: Filter a list pattern'
url: https://design-patterns.service.justice.gov.uk/patterns/filter-a-list
kind: docs
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: listed
relevance: low
grade: B/weak
description: UK Ministry of Justice design system pattern (2021, status to be reviewed): filters are ordinary form controls, the user submits the form and the list reloads filtered
---
# MOJ Design System: Filter a list pattern

Why: do mature public-sector design systems build list filters as plain form
submissions rather than JS?

## Assessment

- Evidence: B. Government design system used across MOJ services; pattern marked "to
  be reviewed" since 2021.
- Reasoning: weak. Usage rules only, no rationale on the page.
- Interests: none.
- Weigh: confirms the submit-and-reload shape; says nothing on GET or URLs.

## Findings

- [web] [ux/layout] Filters are any form controls, submitted as a form that filters
  the list; no live filtering required. ^f1
  > After selecting one or more filters, the user submits the form which filters the list.
  > The filters can be any form control, including date inputs, checkboxes, free text and radio buttons.
- [web] Status is "to be reviewed" (created June 2021). ^f2
  > **Status: To be reviewed**

## Read

- Pattern page

## Not read

- Example HTML and the JS enhancement; GitHub discussion 717
