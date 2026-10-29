---
title: 'cargo-leptos README: style-file and Tailwind build'
url: https://github.com/leptos-rs/cargo-leptos
kind: project
commit: af947bcdbbe2953865b855855f639b57585b0d12
for: [css-per-page]
looked: 2026-10-29
depth: docs (README: features, site parameters)
relevance: medium
grade: B/fair
description: Leptos's official build tool; its config has one style-file (or one Tailwind input) per site, bundled and optionally hashed
---
# cargo-leptos README: style-file and Tailwind build

Why: the build tool decides what CSS a Leptos SSR site ships; is there any per-route option?

## Assessment

- Evidence: B. Official Leptos tool, created 2022-11, 548 stars, v0.3.11 (2026-10).
- Reasoning: fair (config reference, no rationale).
- Interests: none known.
- Weigh: config keys are facts; absence of per-route keys is the finding.

## Findings

- [web/wasm] The site has one source style file, compiled and processed by Lightning CSS, minified in release. `README.md` ^f1
  > # The source style file. If it ends with _.sass_ or _.scss_ then it will be compiled by `dart-sass`
  > # into CSS and processed by lightning css. When release is set, then it will also be minified.
- [web/wasm] With `style-bundle`, the style file and its CSS imports are bundled into a single file. `README.md` ^f2
  > # the `style-file` and the `.css` files it imports will be bundled into a single CSS file.
- [web/wasm] Output files (CSS, JS, wasm) can get content hashes for caching. `README.md` ^f3
  > # Enables additional file hashes on outputted css, js, and wasm files
- [web/wasm] Dev loop: CSS hot reload without a page reload. `README.md` ^f4
  > - CSS hot-reload (no page-reload, only CSS updated).
- [web/wasm] Checked, not there: no per-route or per-island CSS setting; one style-file and one tailwind-input-file per site. ^f5

## Read

- `README.md`: features and site parameters

## Not read

- Source: how the Tailwind scan is wired and whether it sees wasm-only components
