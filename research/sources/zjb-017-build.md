---
title: 'zjb example build on Zig 0.17 (our measurement, 2026-10-22)'
url: https://meio.lol/?measured=zjb-017-build
kind: dataset
commit: eecd2de950c8b4c8c03a7f73671b0d1f7f177d66
for: [zig-only-frontend]
looked: 2026-10-22
depth: ran
relevance: high
grade: A/fair
description: Built zjb's example with Zig 0.17.0: 19 compile errors from @typeInfo field renames; zjb has had no commit since 2026-04-16
---
# zjb example build on Zig 0.17 (our measurement, 2026-10-22)

Why: [[zjb-repo]] was the one interop library that fitted on 0.16; does it work now the
repo is on 0.17?

## Assessment

- Evidence: A for the build result; we did not port it.
- Reasoning: fair.
- Interests: none.
- Weigh: both error kinds are mechanical @typeInfo renames, likely a short port, but
  upstream has been quiet for six months (last push 2026-04-16, no 0.17 issue or PR).

## Findings

- [web/wasm] [toolchain] zjb at its latest commit does not compile on Zig 0.17.0: 19
  errors. ^f1
  > compile exe example small wasm32-freestanding 19 errors
- [web/wasm] [toolchain] All are @typeInfo shape changes: struct `fields` (17) and fn
  `params` (2). ^f2
  > no field named 'fields' in struct 'lang.Type.Struct'
  > no field named 'params' in struct 'lang.Type.Fn'
- [web/wasm] The example still needs a hand-written JS loader (~30 lines) on top of the
  generated glue: it makes the memory, instantiates the module and calls main. ^f3
  > WebAssembly.instantiateStreaming(fetch("example.wasm"), {env: env, zjb: zjb.imports})
- [web/wasm] [toolchain] The example's demo_webserver dependency also fails on 0.17;
  we removed it to test zjb itself. ^f4
  > the demo_webserver dependency fails on its own (Build.getInstallPath gone in 0.17)

## Read

- Build output; `example/static/script.js`.
