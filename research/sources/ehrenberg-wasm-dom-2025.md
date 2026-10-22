---
title: 'When Is WebAssembly Going to Get DOM Support? (Ehrenberg, ACM Queue/CACM 2025)'
url: https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole article)
relevance: high
grade: A/strong
description: A Wasm and TC39 standards insider explains why Wasm calls the DOM through JS glue, why direct DOM access may never come, and what the CG added instead (externref, GC, string builtins)
---
# When Is WebAssembly Going to Get DOM Support? (Ehrenberg, ACM Queue/CACM 2025)

Why: is a JS-free wasm frontend possible at the platform level, now or soon?

## Assessment

- Evidence: A. Daniel Ehrenberg (Bloomberg/Igalia, TC39 chair, Wasm CG participant),
  peer-reviewed practice article in ACM Queue (May/Jun 2025), reposted on CACM Oct 2025.
- Reasoning: strong. Explains history (asm.js, NaCl), the handle-table pattern, why Web
  IDL is JavaScript-shaped, costs and benefits of direct access, and what is left.
- Interests: a standards insider defending the committee's priorities.
- Weigh: the canonical statement of the platform position; "no active work by browser
  vendors" is a 2025 claim, check against 2026 CG meetings if it matters.

## Findings

- [web/wasm] Direct DOM access from wasm may never come; calling the DOM through JS
  indirection has worked since day one. ^f1
  > “Wasm might never get _direct_ DOM access,” _and_ “Yes, Wasm is ready for all kinds of Web-integrated uses, having supported calling out to the DOM (with a little indirection) since day zero.”
- [web/wasm] The minimum loader: JS builds an import object and calls
  `WebAssembly.instantiateStreaming(fetch(...), importObject)`; wasm only reaches what
  it is given. ^f2
  > JavaScript code can call any Web API by referencing the global object, but Wasm only has access to what you give it
- [web/wasm] The classic pattern is a JS array of objects, integer indices across the
  boundary, and explicit frees through an imported function; the result is JS plus wasm.
  ^f3
  > Maintain an array in JavaScript that contains all the references to the JavaScript objects the Wasm program needs to concern itself with.
  > The final artifact is a bundle of JavaScript and Wasm, not just Wasm.
- [web/wasm] Additions since (reference types, GC, JS string builtins) remove the
  extra array and string copies, but none removes glue code. ^f4
  > Referencing JavaScript [values on the stack and in globals](https://github.com/WebAssembly/reference-types/blob/master/proposals/reference-types/Overview.md) without that funny extra array
  > While none of these features lets you access the DOM without any glue code
- [web/wasm] Web APIs are JavaScript APIs: Web IDL is JS-shaped and browser IDL differs
  from the specs, so a Wasm mapping is a large project. ^f5
  > it’s more accurate to think of Web APIs today, including the DOM, as native to JavaScript rather than cross-language.
- [web/wasm] No browser vendor is working on direct Web API access; the Component Model
  route (Jco WebIDL imports) would still go through JS. ^f6
  > There is no active work by browser vendors in this direction.
  > When the rubber hits the road, this strategy would mean that you’re still going through JavaScript.
- [web/wasm] The glue is probably not the bottleneck worth worrying about. ^f7
  > a bit of JavaScript glue to connect Web APIs might not be _the_ bottleneck to worry about
- [web/wasm] For the foreseeable future, web builds ship both JS and wasm. ^f8
  > For the foreseeable future, when this build step is used to deploy Wasm on the Web, the build output will have both JavaScript and Wasm.
- [web/wasm] Remaining boundary overhead: DOM methods type-check their arguments at
  runtime when wasm passes generic references; type imports are a proposed fix. ^f9
  > One proposed solution is type imports: the ability to import a type from another module.

## Read

- Whole article.

## Not read

- The one reader comment; linked Jco WebIDL imports docs.
