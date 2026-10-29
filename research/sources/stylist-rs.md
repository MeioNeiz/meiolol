---
title: 'stylist-rs: CSS-in-Rust for Yew, runtime style elements and SSR style collection'
url: https://github.com/futursolo/stylist-rs
kind: project
commit: 6686a648b4ac954b9e1900746ea0eac7657cfa96
for: [css-per-page]
looked: 2026-10-29
depth: code (stylist/src/lib.rs docs, manager/mod.rs, manager/ssr.rs, examples/yew-ssr server)
relevance: medium
grade: B/fair
description: Yew's main CSS-in-Rust crate; styles are parsed in wasm and mounted as style elements on first use; SSR records the styles that rendered and writes them into the head
---
# stylist-rs: CSS-in-Rust for Yew, runtime style elements and SSR style collection

Why: the Rust/wasm version of styled-components: CSS of what rendered, collected on the
server, then owned by the client. What does the hand-over look like?

## Assessment

- Evidence: B. Created 2021-08, 383 stars, 10 contributors, v0.15.1 (2026-03); the usual
  styling crate for Yew.
- Reasoning: fair. Doc comments explain the contract (read once per render, load data
  early), not the trade-offs.
- Interests: none known.
- Weigh: mechanics are read in code; costs (wasm size, runtime parse) are not measured
  here.

## Findings

- [web/wasm] Stylist describes itself as CSS-in-Rust for wasm apps. `packages/stylist/src/lib.rs` ^f1
  > //! Stylist is a CSS-in-Rust styling solution for WebAssembly Applications.
- [web/wasm] On the client a style is generated and mounted into the DOM the first time it is used, then cached in a registry. `packages/stylist/src/manager/mod.rs` ^f2
  > /// Returns the registry if it is availble, otherwise, creates the style and mounts it.
- [web/wasm] SSR: a writer passed to the style manager switches it to static mode, recording each style that rendered instead of mounting it. `packages/stylist/src/manager/ssr.rs` ^f3
  > /// This also sets the StyleManager into the "static" mode. which it will stop rendering
  > /// styles into any html element.
- [web/wasm] After the render, the server writes the recorded styles as style elements into the head placeholder: per-request inline CSS of exactly what rendered. `examples/yew-ssr/src/bin/yew-ssr-server.rs` ^f4
  > data.write_static_markup(&mut style_s)
  > write!(w, "{}", html_escape::encode_style(&style_str))?;
- [web/wasm] The collected style data must be read once per render and never shared between renders. `packages/stylist/src/manager/ssr.rs` ^f5
  > /// You can only read styles from a style manager once. This is expected. You should never share
  > /// styles between renders.
- [web/wasm] Hydration: the list of styles sent from the server must be loaded into the client manager as early as possible, else the client would mount the same style again (it panics on a clash). `packages/stylist/src/manager/mod.rs` ^f6
  > /// This method should be called as early as possible.
  > /// If the same style to be loaded already existed in the manager, it will panic.
- [web/wasm] (inferred) Client-only components (a tab never server-rendered) get their CSS when the wasm first renders them, generated in the same frame as the DOM, so no flash but the CSS text ships inside the wasm and is parsed at runtime. ^f7
- [web/wasm] Checked, not there: no extraction to a static cacheable file; the SSR output is inline per page. ^f8

## Read

- Files listed in depth

## Not read

- `packages/stylist/src/yew/provider.rs`: how ManagerProvider moves StyleData to the client
- Benchmarks folder (runtime style cost)
