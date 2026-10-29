---
title: 'Dioxus: manganis asset!() and css_module, document::Stylesheet head links'
url: https://github.com/DioxusLabs/dioxus
kind: project
commit: 9f7d2eb1b9d518baacebd74f49eb4ac982f470eb
for: [css-per-page]
looked: 2026-10-29
depth: code (manganis README, macro linker.rs, lib.rs, asset.rs, core css.rs; document link.rs, stylesheet.rs; cli build/web.rs, build/assets.rs)
relevance: high
grade: A/fair
description: Dioxus (Rust, wasm and SSR) collects CSS files named in asset!() from linker symbols in the built binary; a component links its sheet into the head when it renders, deduped per document
---
# Dioxus: manganis asset!() and css_module, document::Stylesheet head links

Why: Dioxus collects assets from what the compiled program references, the closest analogue
to a Zig comptime list. Does that give per-route CSS, and how do client-rendered parts get
their sheet?

## Assessment

- Evidence: A. Created 2021-01, 39.5k stars, v0.7.10 (2026-07); manganis is its asset
  system, used by every Dioxus app.
- Reasoning: fair. Module docs explain why hashing moved to the CLI; no doc on CSS
  ordering or FOUC.
- Interests: none known.
- Weigh: mechanics read in code. Whether a link inserted after hydration flashes is
  inferred, not tested.

## Findings

- [web/wasm] `asset!()` embeds the asset's path in the binary's data; the CLI reads that metadata after the build and processes the files. `packages/manganis/manganis/README.md` ^f1
  > After cargo builds your app, the asset path is embedded directly in the data section. A tool like the Dioxus CLI can extract this metadata and post-process these assets.
- [web/wasm] Mechanism: each `asset!()` exports a static with an `__ASSETS__<hash>` symbol name; the CLI scans the final executable's symbol table for that prefix. `packages/cli/src/build/assets.rs` ^f2
  > symbol table to find symbols that match the `__ASSETS__` prefix. These symbols are ideally data
  > let export_name = syn::LitStr::new(&format!("__ASSETS__{}", asset_hash), position);
- [web/wasm] Content hashes are computed at build time by the CLI, for cache busting, because assets can reference each other. `packages/cli/src/build/assets.rs` ^f3
  > The hashes are used both for cache busting the asset in the browser and to cache the asset optimization
- [web/wasm] The granularity is a file, not a rule: the build collects whole CSS files referenced by the program; nothing prunes unused rules or splits by route. ^f4
- [web/wasm] A component pulls its sheet in by rendering `document::Stylesheet`, which inserts a link in the head the first time it renders. `packages/document/src/elements/stylesheet.rs` ^f5
  > /// Render a [`<link>`](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/link) tag into the head of the page with the stylesheet rel.
- [web/wasm] Links are deduplicated per document by href and rel, so many instances add one link. `packages/document/src/elements/link.rs` ^f6
  > /// The stylesheet is deduplicated within each document: calling this multiple times with the
  > /// same href (or rendering a [`Link`] component with the same href and `rel="stylesheet"`)
  > /// only inserts the link once per document.
- [web/wasm] `css_module` (CSS-modules style) also links its sheet automatically and gives Rust constants for hashed class names, so a typo is a compile error. `packages/manganis/manganis-macro/src/lib.rs` ^f7
  > /// - It generates an asset and automatically inserts it as a stylesheet link in the document.
  > /// - It expands the annotated struct with snake-case associated constants for your CSS class names.
- [web/wasm] The opposite option, `with_static_head(true)`, writes the link into every page's head at build time (like one global sheet). `packages/cli/src/build/web.rs` ^f8
  > if css_options.static_head() {
- [web/wasm] (inferred) So Dioxus's per-component sheets are per-render: a server render links only the sheets of components that rendered, and a component first mounted client-side (another tab, a popover) adds its link then, which can show unstyled content until it loads. Preload is the offered mitigation. ^f9
  > /// Preloading css will make the file start to load as soon as possible. This is useful for css that is used soon after the page loads or css that may not be used immediately, but should start loading sooner
- [web/wasm] Checked, not there: no merging of small sheets into shared chunks, and no ordering guarantee between component sheets beyond insertion order. ^f10

## Read

- Files listed in depth

## Not read

- `packages/wasm-split`: wasm code splitting by route, and whether assets follow chunks
- Dioxus docs site assets guide; issues on CSS flash after navigation
