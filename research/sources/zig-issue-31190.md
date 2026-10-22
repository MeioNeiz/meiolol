---
title: 'Zig issue 31190: externref address space for wasm (Codeberg)'
url: https://codeberg.org/ziglang/zig/issues/31190
kind: thread
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole thread)
relevance: high
grade: A/strong
description: Request for externref in Zig wasm; added in 0.17 as addrspace(.externref), to be removed in 0.18 because LLVM 23 dropped the address spaces; a @WasmType builtin suggested
---
# Zig issue 31190: externref address space for wasm (Codeberg)

Why: can Zig 0.17 hold JS objects directly (externref) instead of integer handles?

## Assessment

- Evidence: A. Zig's own tracker; the decisive comments are by alexrp, a Zig core
  maintainer (owner), with the commit that added and the plan that removes it.
- Reasoning: strong. Says why (LLVM 23 change) and the path forward.
- Interests: none.
- Weigh: the 0.17 feature is real but a dead end for 0.18; nothing filed for the
  replacement builtin as of 22 Oct (Codeberg search for WasmType: no issue).

## Findings

- [web/wasm] [toolchain] Without externref, Zig wasm reaches JS objects only through a
  lookup table of dummy ids on the JS side. ^f1
  > Currently, it is impossible to reference JavaScript objects on the WASM side using opaque pointers without creating a lookup table
- [web/wasm] [toolchain] Intended use: `*addrspace(.externref) anyopaque`. ^f2
  > pub const ExternRef = *addrspace(.externref) anyopaque;
- [web/wasm] [toolchain] Implemented by PR 35813 and milestoned 0.17.0 (June 2026). ^f3
  > wasm: add externref and funcref address spaces (#35813)
- [web/wasm] [toolchain] It needs the reference_types CPU feature added to the target;
  the reporter confirmed it works then. ^f4
  > Did you enable the `reference_types` CPU feature?
  > I did some research and added `.cpu_features_add = std.Target.wasm.featureSet(&.{.reference_types}),`. It works, thank you!
- [web/wasm] [toolchain] LLVM 23 removed these address spaces, so Zig 0.18 removes the
  support; it still ships in 0.17. ^f5
  > LLVM 23 removed these address spaces; they're now modeled as [target extension types](https://llvm.org/docs/LangRef.html#target-extension-type) instead. That unfortunately forces my hand in removing and regressing this support in Zig 0.18.0. (It will still ship in 0.17.0.)
- [web/wasm] [toolchain] The way forward is a `@WasmType`-style builtin, not yet
  proposed formally; maintainer invited a proposal. ^f6
  > These types need to be implemented in the language as a `@WasmType` builtin of sorts
- [web/wasm] [toolchain] Closed again 2026-08-13 and removed from milestones; no
  WasmType issue found on Codeberg (API search, 22 Oct). ^f7
  > alexrp closed this issue 2026-08-13

## Read

- Whole thread (9 comments).

## Not read

- PR 35813 diff; old GitHub issue 10491.
