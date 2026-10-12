---
title: The First HTML LSP That Reports Syntax Errors (Loris Cro, 2024-09-11)
url: https://kristoff.it/blog/first-html-lsp/
kind: article
origin: superhtml-repo
for: [zig-html-templates]
looked: 2026-10-12
depth: listed
relevance: medium
grade: B/fair
description: Author's launch post for the SuperHTML language server; why stricter than the spec, and Zine's rule that HTML syntax errors fail the build
---
# The First HTML LSP That Reports Syntax Errors (Loris Cro, 2024-09-11)

Why: the author's reasons for strict HTML checking.

## Assessment

- Evidence: B. First-hand report by the author.
- Reasoning: fair. One worked example (`<li>item<li>`), no data.
- Interests: launch post for his own tool.
- Weigh: the "no other LSP reports HTML errors" claim is his as of 2024; not verified.

## Findings

- [web] (claim) Common editors use VSCode's HTML language server, which does not report
  HTML syntax errors such as a stray end tag. `#the-status-quo` ^f1
  > Open VSCode and type in a new file some wrong HTML code, like `</span>` (i.e. closing a tag that was never opened). VSCode won’t bat an eye.
- [web] Stricter than the spec on purpose: optional end tags make typos valid HTML.
  `#superhtml-is-not-spec-compliant` ^f2
  > My favorite example is `<li>item<li>`, which is unfortunately both valid HTML and also an obvious typo.
- [web/template] Zine treats HTML syntax errors as build errors. `#in-conclusion` ^f3
  > strict policy that HTML syntax errors are a build error.

## Read

- All

## Not read

- SquiggleConf 2024 talk on SuperHTML (video), linked from the post
