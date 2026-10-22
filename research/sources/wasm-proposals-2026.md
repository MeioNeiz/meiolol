---
title: 'WebAssembly proposals tracker (Oct 2026)'
url: https://github.com/WebAssembly/proposals
kind: docs
commit: df6a2aca1cd9d779eb4f2f3e19dae8277f336015
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (README phase tables, finished-proposals.md)
relevance: high
grade: A/fair
description: The Wasm CG's official list of proposals by phase, as of 7 Oct 2026: ESM integration phase 3, JS string builtins finished, no DOM or Web IDL proposal at any phase
---
# WebAssembly proposals tracker (Oct 2026)

Why: is any direct DOM access proposal in flight in October 2026, and where do ESM
integration and string interop stand?

## Assessment

- Evidence: A. The CG's own tracker, last commit 2026-10-07.
- Reasoning: fair. A list.
- Interests: none.
- Weigh: phase 0 ideas live in the design repo issues, not here.

## Findings

- [web/wasm] ESM Integration (importing a .wasm as an ES module) is at phase 3,
  implementation. `README.md` ^f1
  > | [ESM Integration][ecmascript_module_integration]  | Asumu Takikawa, Ms2ger, and Guy Bedford |
- [web/wasm] JS String Builtins is a finished proposal, merged at the WG on 2025-07-23.
  `finished-proposals.md` ^f2
  > | [JS String Builtins][js-string-builtins]                                                             | Ryan Hunt                         | [WG 2025-07-23][WG-2025-07-23]
- [web/wasm] Phase 1 holds Type Imports, the Component Model, Reference-Typed Strings
  and JS Text Encoding Builtins (UTF-8 in linear memory to JS strings). `README.md` ^f3
  > | [JS Text Encoding Builtins][js-text-encoding-builtins]     | Daxpedda                                     |
- [web/wasm] Checked, not there: no proposal for DOM access, Web IDL bindings or
  calling Web APIs from wasm at any phase 1 to 5. `README.md` ^f4
- [web/wasm] Custom Descriptors and JS Interop (phase 3) is the other JS-interop item in
  flight. `README.md` ^f5
  > | [Custom Descriptors and JS Interop][custom-descs] | Thomas Lively                           |

## Read

- README phase tables; finished-proposals.md rows for reference types, GC, string builtins.

## Not read

- Each proposal's overview except [[wasm-text-encoding-builtins]]; design repo phase 0 issues.
