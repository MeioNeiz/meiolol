---
title: 'Leptos book: Styling interlude, with stylers and stylance READMEs'
url: https://book.leptos.dev/interlude_styling.html
kind: docs
commit: 2bbb87cb656cfcc6977328274be3a80a24883b4c
for: [css-per-page]
looked: 2026-10-29
depth: docs (leptos-rs/book src/interlude_styling.md at c573962; stylers README at 2bbb87c; stylance-rs README at b61171f)
relevance: high
grade: B/fair
description: How Leptos (Rust SSR plus wasm hydration) styles apps: no framework opinion; plain sheet, Tailwind, or crates that extract scoped component CSS into one file
---
# Leptos book: Styling interlude, with stylers and stylance READMEs

Why: Leptos is the closest mature stack (Rust components rendered on the server and in
wasm). Does it or its CSS crates split CSS per route?

## Assessment

- Evidence: B. Leptos: 21.4k stars, created 2022-07, v0.9.0-rc0 (2026-10). The book is
  the official guide. stylers (166 stars, last release 2023) and stylance (153 stars,
  v0.8.4 2026-06) are small one-maintainer crates the book recommends.
- Reasoning: fair. Says what each tool does; little on why one file.
- Interests: none known.
- Weigh: the crates are narrow; trust that the ecosystem default is one sheet, not that
  these crates are good.

## Findings

- [web/wasm] Leptos itself has no opinion on CSS and leaves scoping to ecosystem crates. `src/interlude_styling.md` ^f1
  > Leptos is in this latter camp: the framework itself has no opinions about CSS at all, but provides a few tools and primitives that allow others to build styling libraries.
- [web/wasm] The SSR template bundles CSS into one file at a fixed path; extra sheets go in `public/` or a `Stylesheet` component in the tree. `src/interlude_styling.md` ^f2
  > The `cargo-leptos` templates are configured by default to use SASS to bundle CSS files and output them at `/pkg/{project_name}.css`.
  > To load stylesheets in a component, you can use the [`Stylesheet`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Stylesheet.html) component.
- [web/wasm] Tailwind route: its CLI scans the Rust sources for class names and builds one CSS file. `src/interlude_styling.md` ^f3
  > Tailwind will scan your Rust files for Tailwind class names and compile them into a CSS file.
- [web/wasm] stylers: CSS declared in the component body, extracted at compile time to files, so nothing is added to the wasm. `src/interlude_styling.md` ^f4
  > Stylers will extract this CSS at compile time into CSS files that you can then import into your app, which means that it doesn't add anything to the WASM binary size of your application.
- [web/wasm] stylers' build step parses every source file for its macros and writes a single CSS file for the whole app, not per route. `stylers/README.md` ^f5
  > This `stylers::build` method will parse all the rust files in the path `/src/**/*.rs` during build step to find the places the `style` and `style_sheet` macros has been used and generate single output css file.
- [web/wasm] stylance: CSS modules next to components; the macro imports hashed class names as constants, so an unknown class is a compile error; a CLI bundles all modules into one file. `stylance/README.md` ^f6
  > Trying to use a class name that doesn't exist in the css file becomes an error.
  > Bundle your css module files into a single output css file with all the class names transformed to include a hash (by using stylance cli).
- [web/wasm] stylance keeps the CSS bundle outside the Rust build so editing CSS needs no recompile. `stylance/README.md` ^f7
  > CSS Bundle generation is independent of the rust build process, allowing for blazingly fast iteration when modifying the contents of a css style rule.
- [web/wasm] Runtime option (styled crate): scoped CSS applied at runtime from the component, i.e. CSS inside the wasm. `src/interlude_styling.md` ^f8
  > [Styled](https://github.com/eboody/styled) is a runtime scoped CSS library that integrates well with Leptos.
- [web/wasm] (inferred) Every Leptos route here ends in one app-wide sheet (bundle, Tailwind, stylers, stylance); per-route CSS only by hand via `Stylesheet`. Same shape as meiolol today. ^f9
- [web/wasm] Checked, not there: no mention of per-route splitting, critical CSS or FOUC for wasm-rendered parts. ^f10

## Read

- `src/interlude_styling.md`: all
- stylers and stylance READMEs: all

## Not read

- leptos_meta `Stylesheet` source: whether it dedupes or orders links across routes
- styled crate (runtime injection), turf (another compile-time crate)
