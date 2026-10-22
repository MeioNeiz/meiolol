---
title: Zig 0.11.0 release notes
url: https://ziglang.org/download/0.11.0/release-notes.html
kind: docs
commit: 
for: [zig-good-practice, zig-style, zig-comptime, zig-build, zig-memory]
looked: 2026-10-22
depth: docs (language changes, standard library memory/strings/sorting/testing, build system, package management, compiler, zig fmt, roadmap)
relevance: medium
grade: A/strong
description: Official release notes for Zig 0.11.0 (2023-08): multi-object for, cast inference, build system and package manager debut, sorting split
---
# Zig 0.11.0 release notes

Why: which idioms 0.11 introduced or retired (casts, for loops, build system), and the
reasons the Zig team gave, so the guide can mark old advice as stale.

## Assessment

- Evidence: A. Canonical reference from the Zig team; each change has a runnable example.
- Reasoning: strong for the language changes (motivating footguns spelled out, e.g. cast
  inference), fair elsewhere (std is a bullet list of PRs).
- Interests: none beyond promoting the release.
- Weigh: three years old. The idioms it introduced (multi-object for, @yFromX, result
  type casts, Run steps) still hold in 0.17; its build API names (`addModule` on
  Compile, `.{ .path = ... }`, `anonymousDependency`) do not.

## Findings

- [zig/style] Multi-object for loops iterate several equal-length sequences at once, so
  code no longer picks one to iterate and indexes the other. ^f1
  > This release cycle introduces multi-object `for` loops into the Zig language.
  > in the loop, we had to make the arbitrary choice to iterate over `input`, using the captured index `i` to access the corresponding element in `output`
- [zig/safety] @memcpy takes (dest, source); overlap is safety-checked UB, which is the
  reason to prefer it over std helpers. ^f2
  > The source and destination memory must not overlap (overlap is considered safety-checked Undefined Behavior). This is one of the key motivators for using this builtin over the standard library.
- [zig/style] Casting builtins renamed @xToY to @yFromX so information flows right to
  left. ^f3
  > rename all casting builtins of the form `@xToY` to `@yFromX`. The goal of this change is to make code more readable by ensuring information flows in a consistent direction (right-to-left)
- [zig/safety] Cast builtins dropped the destination type and infer it from the result
  location; motive: an explicit type at the call site goes silently wrong when the
  parameter type changes. ^f4
  > There is now a footgun here: if you don't change every `@intCast` to cast to the correct type, you have a silent bug in your program
  > instead of writing `f(@intCast(u16, x))`, you instead write `f(@intCast(x))`
- [zig/style] With no result type, a cast needs `@as(T, ...)`, but annotations, field
  types, parameters and return types normally supply one. ^f5
  > This will always work, however it is usually not necessary. Instead, result types are normally inferred from type annotations, struct/array initialization expressions, parameter types, and so on.
- [zig/perf] `s[start..][0..len]` is the idiomatic slice-by-length; with a comptime len
  it yields an array pointer, and the compiler recognises the pattern. ^f6
  > when `len` is compile-time known, the expression will be a pointer to an array rather than a slice type, which is generally a preferable type.
  > Zig 0.11.0 now detects this pattern and generates more efficient code.
- [zig/comptime] A `comptime` block is now really evaluated at compile time; runtime
  operations inside are a compile error. ^f7
  > The entire body of a `comptime` block will now be evaluated at compile time, and a compile error is triggered if this is not possible.
- [zig/comptime] New @inComptime() lets a function branch on whether it is being
  evaluated at comptime. ^f8
  > This builtin returns a `bool` indicating whether or not it was evaluated in a `comptime` scope.
- [zig/style] Bound functions removed: a method call is only the exact form `a.b(args)`. ^f9
  > Method calls are now restricted to the exact syntactic form `a.b(args)`.
- [zig/build] A source file may belong to only one module; the team calls the shape a
  likely mistake. ^f10
  > **having a single source file within multiple modules is now illegal**
  > generally this kind of structure is indicative of a mistake anyway
- [zig/memory] Allocators may refuse to shrink; ArrayList tries resize in place and
  copies only the used items otherwise, instead of realloc copying spare capacity. ^f11
  > The Allocator interface now allows implementations to refuse to shrink
- [zig/memory] mem.span and mem.len restricted to sentinel-terminated pointers, called
  footgunny on arrays and slices. ^f12
  > These functions were footgunny when working with pointers to arrays and slices.
- [zig/perf] Sorting split into stable (blocksort) and unstable (pdqsort); unstable is
  preferred when possible; debug builds assert the comparator is consistent. ^f13
  > Generally, it's best to use unstable if you can, but stable is a more conservative choice.
  > debug builds have assertions to ensure that the comparator function (`lessThan`) does not return conflicting results
- [zig/build] Build system and package manager stop being experimental; "package" now
  means a hashed directory tree, "module" the importable unit. ^f14
  > With this release, the Zig Build System is no longer **experimental**. It is the début of Package Management.
  > A package is a directory of files, uniquely identified by a hash of all files, which can export any number of compilation artifacts and modules.
- [zig/build] Dependencies live in build.zig.zon, separate from build.zig, so fetching
  needs no build script run and tools can see the graph without running untrusted code. ^f15
  > This also allows tooling to observe dependency graphs without having to execute potentially dangerous code.
- [zig/build] Packages take target and optimize as options (standardTargetOptions,
  standardOptimizeOption) and options are not inherited by dependencies. ^f16
  > Options from the current package are not implicitly provided to dependencies, and must be explicitly forwarded where required.
- [zig/build] Use LazyPath for every input and output, not hardcoded paths. ^f17
  > As a general rule, hardcoded paths outside of the installation directory should be avoided where possible.
- [zig/build] Prefer Run steps over custom steps, for cache integration; addTest no
  longer runs the test, addRunArtifact does. ^f18
  > It is recommended to generally use Run steps instead of custom steps because it will properly integrate with the Cache System.
  > Before, addTest created and ran a test. Now you need to use b.addRunArtifact to run your test executable.
- [zig/build] Build steps run in parallel on a thread pool sized to CPU cores (-j). ^f19
  > runs steps in a thread pool, with a default thread count corresponding to the number of CPU cores available
- [zig/errors] Error return traces exist in safe modes and show where an unhandled
  error came from, where a stack trace would say less. ^f20
  > report the source of an error which was not correctly handled where a simple stack trace would be less useful.
- [zig/test] std.testing gained expectEqualDeep; expectEqualSlices absorbed
  expectEqualBytes (hexdump diffs). ^f21
  > std: add expectEqualDeep
- [zig/style] zig fmt canonicalises quoted identifiers and now formats .zon files. ^f22
  > additionally format .zon files
- [toolchain] Checked, not there: the 0.11 notes never mention async/await, though it
  stopped working in this release (stated in [[zig-012-release-notes#^f19]]). ^f23
- [toolchain] The std is declared unstable and a testbed until the language settles;
  the 1.0 order is language, spec, build system, std, one release with no breakage. ^f24
  > The Zig standard library is still unstable and mainly serves as a testbed for the language.

## Read

- Language Changes, Standard Library (memory, strings, sorting, testing, JSON allocator
  note), Build System (all), Compiler (error tracing, incremental), zig fmt, Roadmap

## Not read

- Target support, crypto, debugging/unwinding internals, linker, toolchain: not idiom
