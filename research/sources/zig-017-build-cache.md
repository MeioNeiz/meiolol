---
title: 'Zig 0.17 build cache: Cache.zig and Maker.zig source, and a two-tree sharing test'
url: https://codeberg.org/ziglang/zig/src/tag/0.17.0/lib/std/Build/Cache.zig
kind: project
commit: 0.17.0
for: [parallel-build-capacity]
looked: 2026-11-05
depth: code ran (Cache.zig prefixes, check and locking; Maker.zig cache setup; two-tree test)
relevance: high
grade: A/strong
description: How zig build's cache keys and locks work in 0.17 (paths stripped to prefixes such as the build root, one manifest per input-path set, file locks for concurrent processes), and a test showing two checkouts share one cache dir only while their files match
---
# Zig 0.17 build cache: Cache.zig and Maker.zig source, and a two-tree sharing test

Why: can several checkouts (or hosts) share one Zig build cache, and is one `.zig-cache`
safe under many concurrent `zig build` processes?

Source read from the pinned 0.17.0 install (lib/ ships the std and build runner source;
the compiler's own Compilation.zig is not shipped, so the compiler side was tested, not
read). Test: a one-file project copied to two trees, `zig build test --summary all
--cache-dir <shared>`, log in `log/run.txt`.

## Assessment

- Evidence: A. The toolchain's own source, at the exact version we pin, plus our own run.
- Reasoning: strong. Code comments explain the intent (portability, races seen on macOS).
- Interests: none.
- Weigh: the test is a toy (one module, native target). Our build has many modules, wasm
  islands and Run steps; any step that passes an absolute path (build root, cache path) as
  an argument or option would key on it. Repeat on the real tree before relying on it.

## Findings

- [zig/build] [devflow/cache] The cache strips known prefixes (zig lib dir, project root)
  from file paths before keying, on purpose, to remove absolute paths. `lib/std/Build/Cache.zig:25-29` ^f1
  > A set of strings such as the zig library directory or project source root, which
  > are stripped from the file paths before putting into the cache. They
  > are replaced with single-character indicators. This is not to save
  > space but to eliminate absolute file paths.
- [zig/build] [devflow/cache] `zig build` registers five prefixes: cwd, zig lib dir, local
  cache, global cache, build root. `lib/compiler/Maker.zig:628-632` ^f2
  > graph.cache.addPrefix(graph.build_root_directory);
- [zig/build] [devflow/cache] The manifest name is a hash of input paths and flags, not
  contents; contents go into a second hash once the manifest is found. `lib/std/Build/Cache.zig:904-905` ^f3
  > This is *not* hashing the contents of the input files. It is the
  > flags (including prefix) and path only.
- [zig/build] [devflow/cache] So one manifest per set of input paths remembers only the
  last contents built: two trees whose files differ evict each other. Ran: a and b,
  differing, alternated five builds on one cache dir and all five recompiled. `log/run.txt` steps 3-6 ^f4
  > # 4: a unchanged since its hit in 1
- [zig/build] [devflow/cache] Two trees at different absolute paths with identical files
  do share: the second tree's compile and test run were both cache hits (0.74 s versus
  7.7 s cold). `log/run.txt` steps 1-2 ^f5
  > # 2: b identical content, other path
  > +- compile test debug native cached 137ms MaxRSS:31M
- [zig/build] [devflow/cache] One cache dir is built for many concurrent processes:
  exclusive lock to build, shared lock after a hit, re-check after upgrading because
  another process may have filled it. `lib/std/Build/Cache.zig:881-886, 997-998` ^f6
  > This function will also acquire an exclusive lock to the manifest file. This means
  > that a process holding a Manifest will block any other process attempting to
  > acquire the lock.
  > Missed with the shared lock, and upgraded to an exclusive lock. However, another process may have
- [zig/build] [devflow/cache] A macOS race (two processes creating one manifest) is known
  and worked around in the code. `lib/std/Build/Cache.zig:942-943` ^f7
  > however we have observed on macOS two processes
  > racing to do openat() with O_CREAT manifest in ENOENT.
- [zig/build] [devflow/cache] Ran: two trees given the same new content and built at once
  on one cache: one compiled, the other waited and hit. `log/run.txt` step 7 ^f8
  > # 7: a and b given the same new content, built at the same time
- [zig/build] [devflow/cache] Unchanged files are recognised by size, mtime and inode
  without rehashing; a file whose mtime is too recent to trust is always hashed. A copy
  in another tree has another inode, so it is hashed, not trusted. `lib/std/Build/Cache.zig:579-581, 569-572` ^f9
  > // The actual file has an unreliable timestamp; force it to be hashed.
- [zig/build] [devflow/cache] Checked, not there: no remote or network cache protocol in
  the build system; sharing means a shared directory (`--cache-dir`,
  `--global-cache-dir`). ^f10
- [devflow/cache] (inferred) For meiolol: agents sharing one checkout already share one
  cache with correct locking; per-agent worktrees on one `--cache-dir` would share hits
  only for steps whose inputs match main, and would thrash on steps each agent is
  editing, so worktrees cost a full build of their changed parts each. ^f11

## Read

- `lib/std/Build/Cache.zig`: prefixes and resolveAppendPath (1-125), addInputPath,
  check and locking (705-1015), stat fast path and problematic timestamps (540-590,
  1636-1690).
- `lib/compiler/Maker.zig`: cache and prefix setup (600-640).

## Not read

- The compiler's Compilation.zig (not shipped): what the compiler itself adds to its
  hash (module root paths?) for `zig build-exe` subprocess caching.
- Step/Run.zig: whether Run steps hash absolute argument paths.
