# support cache hits with differently named zig lib directories which have the same contents (ziglang/zig#13050)

state: CLOSED, opened 2022-10-03T11:05:58Z by motiejus, closed 2022-11-23T19:51:23Z

### Zig Version

0.10.0-dev.4176+6d7b0690a

### Summary & Impact

When using a relative zig lib directory (`ZIG_LIB_DIR=lib`) and when building from different directories, libc shims get rebuilt *for every working directory*. This is a particularly nasty problem for Bazel, which uses a different directory for each "sandbox" (i.e. execution unit), but relative directory to `ZIG_LIB_DIR` due to reproducibility. In our case, it causes tens of gigabytes of `libc++.a` in zig cache directory, besides the CPU usage to generate those.

### Steps to reproduce

Setup:
```
~$ mkdir -p a1 a2
~$ for d in a1 a2; do ln -s /code/zig/lib $d/lib; done
```

Directory `a1`:
```
~$ cd a1
~/a1$ time ZIG_LIB_DIR=lib zig cc -target aarch64-linux-gnu.2.28 - -o main
LLD Link... ld.lld: error: cannot open -: No such file or directory

real    0m16.092s
user    1m18.706s
sys     0m6.679s
```

Observe the `zig c++` command takes ~16 seconds, which means it built the glibc shim. Now switch to directory `a2`:
```
~$ cd a2
~/a2$ time ZIG_LIB_DIR=lib zig c++ -target aarch64-linux-gnu.2.28 - -o main
LLD Link... ld.lld: error: cannot open -: No such file or directory

real    0m18.914s
user    1m31.513s
sys     0m7.670s
```

If we run this again in `a2`, we see the latency is significantly decreased:

```
~$ cd a2
~/a2$ time ZIG_LIB_DIR=lib zig c++ -target aarch64-linux-gnu.2.28 - -o main
LLD Link... ld.lld: error: cannot open -: No such file or directory

real    0m0.038s
user    0m0.017s
sys     0m0.021s
```

### Expected Behavior

It takes <1 second to run the `a2` from from the first attempt.

## motiejus 2022-10-03T11:22:26Z

I've observed that some of the `~/.cache/zig/h/*.txt` files (in my understanding, cache manifests) contain non-canonicalized paths:

```
$ grep -hr /home/motiejus/sandbox/a1/lib/std/std.zig ~/.cache/zig
5621 305412 1656217371235171984 66001e1a55f68e4681c1f32a69223647 /home/motiejus/sandbox/a1/lib/std/std.zig
```

IMO I would expcect it to be:

```
5621 305412 1656217371235171984 66001e1a55f68e4681c1f32a69223647 /code/zig/lib/std/std.zig
```

Or even better, if at all possible?

```
5621 305412 1656217371235171984 66001e1a55f68e4681c1f32a69223647 lib/std/std.zig
```


Though I did not find where this path is actually constructed.

## andrewrk 2022-10-05T06:57:02Z

Ideally, manifest files in the global cache would contain only absolute files, since the global cache is shared among multiple projects, each with a potentially different working directory.

Meanwhile, manifest files in the local cache would ideally contain only paths relative to the local project root, so that the project directory could be moved to a new location and the cache would continue functioning seamlessly.

I had a look around and any time we call `Cache.addFile`, it calls `fs.path.resolve` on the input path to convert from relative path to absolute path. The one exception is `Cache.addFilePostContents`, which accepts a pre-resolved path. One of the callsites does this correctly, but the other does not, and I think that is the cause of the bug.

I don't think resolving symlinks is necessary or desirable.

I'll propose a different PR shortly to solve this problem.

## andrewrk 2022-10-05T07:48:14Z

I opened #13071 after which no relative paths show up in the global cache manifest.

However, the system will still consider two paths to be different even if they are symlinks resolving to the same directory, leaving the original problem detailed in this issue unresolved. However, might I suggest that the link is resolved prior to setting the environment variable? For example, this solves the problem:

```
[nix-shell:~/Downloads/zig/build-release]$ cd a1

[nix-shell:~/Downloads/zig/build-release/a1]$ ZIG_LIB_DIR=$(readlink lib) ../stage4/bin/zig build-exe ../../test/standalone/hello_world/hello.zig 

[nix-shell:~/Downloads/zig/build-release/a1]$ cd ../a2

[nix-shell:~/Downloads/zig/build-release/a2]$ ZIG_LIB_DIR=$(readlink lib) ../stage4/bin/zig build-exe ../../test/standalone/hello_world/hello.zig 
```

With this strategy, only one copy of the global static libraries such as compiler_rt.a and libc++.a is generated.

## motiejus 2022-10-05T11:50:02Z

> However, might I suggest that the link is resolved prior to setting the environment variable? For example, this solves the problem:


Unfortunately, the Bazel's symlink to zig's `lib` is an absolute path, which brings back #12980 back again:. If we readlink it, the `ZIG_LIB_DIR` becomes absolute, which causes the result of `zig cc -M` to be absolute, which beats Bazel's global cache.

As a result, two machines/people with a different sandbox path (e.g. `/home/motiejus` and `/home/john` is enough to make a difference a difference) cannot share the compiled artifacts.

## motiejus 2022-10-05T11:50:57Z

In other words, I am looking for the right `ZIG_LIB_DIR`, so the result of `zig cc -M file.c` contains only relative paths.

## andrewrk 2022-10-12T09:06:55Z

Hmm I'm actually not able to reproduce the problem. Here is an attempt where I am getting what I understand to be the desired behavior, based on our discussion:

```
[nix-shell:~/Downloads/zig/build-release]$ cd a1
[nix-shell:~/Downloads/zig/build-release/a1]$ ls -l lib
lrwxrwxrwx 1 andy users 28 Oct  4 23:02 lib -> /home/andy/Downloads/zig/lib
[nix-shell:~/Downloads/zig/build-release/a1]$ ZIG_LIB_DIR=lib ../stage4/bin/zig cc -o hello -c hello.c -MD -MV -MF hello.d -target x86_64-linux-gnu.2.33
[nix-shell:~/Downloads/zig/build-release/a1]$ cat hello.d 
hello: hello.c lib/libc/include/generic-glibc/time.h \
  lib/libc/include/generic-glibc/features.h \
  lib/libc/include/generic-glibc/features-time64.h \
  lib/libc/include/x86_64-linux-gnu/bits/wordsize.h \
  lib/libc/include/x86_64-linux-gnu/bits/timesize.h \
  lib/libc/include/generic-glibc/stdc-predef.h \
  lib/libc/include/generic-glibc/sys/cdefs.h \
  lib/libc/include/x86_64-linux-gnu/bits/long-double.h \
  lib/libc/include/x86_64-linux-gnu/gnu/stubs.h \
  lib/libc/include/x86_64-linux-gnu/gnu/stubs-64.h lib/include/stddef.h \
  lib/libc/include/generic-glibc/bits/time.h \
  lib/libc/include/generic-glibc/bits/types.h \
  lib/libc/include/x86_64-linux-gnu/bits/typesizes.h \
  lib/libc/include/generic-glibc/bits/time64.h \
  lib/libc/include/generic-glibc/bits/types/clock_t.h \
  lib/libc/include/generic-glibc/bits/types/time_t.h \
  lib/libc/include/generic-glibc/bits/types/struct_tm.h \
  lib/libc/include/generic-glibc/bits/types/struct_timespec.h \
  lib/libc/include/generic-glibc/bits/endian.h \
  lib/libc/include/x86_64-linux-gnu/bits/endianness.h \
  lib/libc/include/generic-glibc/bits/types/clockid_t.h \
  lib/libc/include/generic-glibc/bits/types/timer_t.h \
  lib/libc/include/generic-glibc/bits/types/struct_itimerspec.h \
  lib/libc/include/generic-glibc/bits/types/locale_t.h \
  lib/libc/include/generic-glibc/bits/types/__locale_t.h
```

Here you can see that all the files are relative paths.

## motiejus 2022-10-12T09:20:06Z

They are relative when ZIG_LIB_DIR is relative; which is the correct behavior.

Our discussion was making ZIG_LIB_DIR absolute.

## motiejus 2022-10-12T09:23:24Z

A reminder of what we agreed in person:

1. `ZIG_LIB_DIR` is absolute, and we resolve the symlinks before invoking `zig cc` (so zig's caching system always knows they are the same files).
2. `zig cc -target <...> -M` returns relative paths iff the path to the source file is relative.

Does that explain it?

## motiejus 2022-10-18T20:30:28Z

Here is a more detailed explanation of the context we are dealing with: how Bazel manages dependencies and cache and why it matters.


Environment
-----------

[bazel-zig-cc][1] downloads Zig to a path somewhere in `$HOME/.cache`:

    $ pwd
    /home/motiejus/.go-code
    $ ls -d $(bazel info output_base)/external/zig_sdk/{zig,lib/libc/musl/libc.S}
    /home/motiejus/.cache/bazel/_bazel_motiejus/80f026c00534678eecd7f80fa20fddc4/external/zig_sdk/lib/libc/musl/libc.S
    /home/motiejus/.cache/bazel/_bazel_motiejus/80f026c00534678eecd7f80fa20fddc4/external/zig_sdk/zig
    $

Hash in the path (`80f026...`) is derived from the full path where git
repository is hosted. That is, if I run bazel in `~/.go-code2`, the bazel's
`output_base` will be in `/home/motiejus/.cache/bazel/<different_hash>/`.

Bazel is designed to control the tools that it uses. Invoking anything outside
of Bazel's `output_base` is not OK. For example, if Bazel needs to build
something that requires, say, with gnu make, it will build `make` first and
then use it to build other targets.

It is possible, but generally not an option to have anything nontrival outside
of Bazel's control.

Bazel's caching system
----------------------

Bazel has a few caching layers:

1. Build cache in `$HOME/.cache/bazel/...`. This cache is per-workspace
   (technically, per `output_path`). If you run `bazel clean`, that will get
   wiped. It is not shared across workspaces.

2. Remote cache in a local directory, a network share, or a remote service.

... and a couple more in between which we will not discuss here.

[bazel-zig-cc][1] has another cache directory: `/tmp/bazel-zig-cc`. Before it
invokes `zig c++`, it sets the zig's cache directory to [that][2]:

```
export ZIG_LOCAL_CACHE_DIR="{cache_prefix}/bazel-zig-cc"
export ZIG_GLOBAL_CACHE_DIR="{cache_prefix}/bazel-zig-cc"
```

(`{cache_prefix}` is set per environment, which is either
`~/.cache/bazel-zig-cc` or `/tmp/bazel-zig-cc`).

Note: `ZIG_(LOCAL|GLOBAL)_CACHE_DIR` is always the same same across different
invocations of `zig c++`.

How Bazel compiles C/C++ files
------------------------------

This is a simplified model how Bazel compiles a C file and how it interacts
with remote cache. Before compiling `main.c` Bazel does:

    $CC -M -MF main.d main.c

Then it constructs a `$hash` from:
1. contents of main.c
2. contents of `main.d`: the file paths and their hashes.

Then Bazel queries the remote cache for an entry `$hash`. If it is a match, it
will download `main.o` and skip invoking an expensive compiler. If the entry is
not present, it will compile the file:

    $CC -o main.o

And upload the resulting `main.o` with the hash key that it has computed in the
previous step. If other users compute the same hash, they will be able to
download the file instead of compiling.

This is done not only for individual object files -- Bazel can cache and
download full static libraries composed of thousands of individual object files
which take minutes to compile.

How Bazel sandboxing works
--------------------------

Bazel creates as many sandboxes as there are cores. Each sandbox contains a
symlink to all files in zig sdk. Here is an example of sandbox `153` symlinking
to the `zig` binary:

    $ ls -l $(bazel info output_base)/sandbox/linux-sandbox/153/execroot/__main__/external/zig_sdk/zig
    /home/motiejus/.cache/bazel/_bazel_motiejus/80f026c00534678eecd7f80fa20fddc4/sandbox/linux-sandbox/153/execroot/__main__/external/zig_sdk/zig -> /home/motiejus/.cache/bazel/_bazel_motiejus/80f026c00534678eecd7f80fa20fddc4/execroot/__main__/external/zig_sdk/zig

When Bazel is compiling a C file in sandbox 153, `zig c++` process is executed
in:

    /home/motiejus/.cache/bazel/_bazel_motiejus/80f026c00534678eecd7f80fa20fddc4/sandbox/linux-sandbox/153/execroot/__main__

Layout of every sandbox is always the same, so all of them have
`external/zig_sdk` pointing to the same files using the symlins. Bazel then
invokes the binary using the relative path.

bazel-zig-cc also [sets][3] `ZIG_LIB_DIR=external/zig_sdk/lib`. As a result,
`zig c++ -M main.c` returns relative paths to the dependent files, in this
case, libc headers. Since the file contents are the same (zig sdk is always the
same for a particular hash of go-code) and the paths are the same (all
relative), the remote cache hash keys are also the same across different users
who have bazel's cache in different directories. Thus they can use the same
remote cache.

Caveats and discussion
----------------------

The remote cache is shared by:
1. different users (different home directories).
2. different workspaces (that include the hash to the path of the repository).

Since all dependency paths are used to construct the hash key for the remote
cache, all paths have to be the same across different environments.

Since Zig SDK is placed wherever Bazel feels like it, the only option that
comes to my mind is keeping returned by `$CC -M` relative. If the paths are
relative, they are considered the same, thus forming the same hash key.

At the same time, zig thinks that paths to zig lib dir are different from every sandbox; so without #13051 it is not reusing global libc artifacts. 

[1]: https://git.sr.ht/~motiejus/bazel-zig-cc
[2]: https://git.sr.ht/~motiejus/bazel-zig-cc/tree/abf00a525c16b20986d048d549b3882f6a466a42/item/toolchain/defs.bzl#L133-134
[3]: https://git.sr.ht/~motiejus/bazel-zig-cc/tree/abf00a525c16b20986d048d549b3882f6a466a42/item/toolchain/defs.bzl#L128


## motiejus 2022-10-19T06:27:51Z

> Hmm I'm actually not able to reproduce the problem. Here is an attempt where I am getting what I understand to be the desired behavior, based on our discussion:
> 
> ```
> [nix-shell:~/Downloads/zig/build-release]$ cd a1
> [nix-shell:~/Downloads/zig/build-release/a1]$ ls -l lib
> lrwxrwxrwx 1 andy users 28 Oct  4 23:02 lib -> /home/andy/Downloads/zig/lib
> [nix-shell:~/Downloads/zig/build-release/a1]$ ZIG_LIB_DIR=lib ../stage4/bin/zig cc -o hello -c hello.c -MD -MV -MF hello.d -target x86_64-linux-gnu.2.33
> [nix-shell:~/Downloads/zig/build-release/a1]$ cat hello.d 
> hello: hello.c lib/libc/include/generic-glibc/time.h \
>   lib/libc/include/generic-glibc/features.h \
>   lib/libc/include/generic-glibc/features-time64.h \
>   lib/libc/include/x86_64-linux-gnu/bits/wordsize.h \
>   lib/libc/include/x86_64-linux-gnu/bits/timesize.h \
>   lib/libc/include/generic-glibc/stdc-predef.h \
>   lib/libc/include/generic-glibc/sys/cdefs.h \
>   lib/libc/include/x86_64-linux-gnu/bits/long-double.h \
>   lib/libc/include/x86_64-linux-gnu/gnu/stubs.h \
>   lib/libc/include/x86_64-linux-gnu/gnu/stubs-64.h lib/include/stddef.h \
>   lib/libc/include/generic-glibc/bits/time.h \
>   lib/libc/include/generic-glibc/bits/types.h \
>   lib/libc/include/x86_64-linux-gnu/bits/typesizes.h \
>   lib/libc/include/generic-glibc/bits/time64.h \
>   lib/libc/include/generic-glibc/bits/types/clock_t.h \
>   lib/libc/include/generic-glibc/bits/types/time_t.h \
>   lib/libc/include/generic-glibc/bits/types/struct_tm.h \
>   lib/libc/include/generic-glibc/bits/types/struct_timespec.h \
>   lib/libc/include/generic-glibc/bits/endian.h \
>   lib/libc/include/x86_64-linux-gnu/bits/endianness.h \
>   lib/libc/include/generic-glibc/bits/types/clockid_t.h \
>   lib/libc/include/generic-glibc/bits/types/timer_t.h \
>   lib/libc/include/generic-glibc/bits/types/struct_itimerspec.h \
>   lib/libc/include/generic-glibc/bits/types/locale_t.h \
>   lib/libc/include/generic-glibc/bits/types/__locale_t.h
> ```
> 
> Here you can see that all the files are relative paths.

You nailed it: the first half works correctly (emitting relative paths). Now for the second half, please execute:

```
mkdir ../a2; cd ../a2
ln -s /home/andy/Downloads/zig/lib
ZIG_LIB_DIR=lib ZIG_VERBOSE_CC=1 ../stage4/bin/zig cc -o hello -c hello.c -MD -MV -MF hello.d -target x86_64-linux-gnu.2.33
```

... and observe:
1. Paths in `hello.d` are relative (good).
2. zig is rebuilding glibc stubs (bad).

## motiejus 2022-10-26T06:59:11Z

I spent a couple of days investigating the intersection of bazel and zig-cc with regards to build performance issues. There is one more aspect to it:

1. By default, Bazel creates a symlink farm per sandbox. Sandbox is created per action (action is a single compilation step). Zig has ~16k files, thus it takes time to create and teardown every sandbox. This is the cause of the current slowness that I've mentioned in other channels.
2. To overcome (1), Bazel supports [sandboxfs](https://bazel.build/docs/sandboxing#sandboxfs). It is a FUSE-mounted directory that makes the "sandbox" read-only, whlist avoiding the symlink farm. That could be used with `ZIG_LIB_DIR=external/zig_sdk/lib`. This fixes the performance issue with a symlink farm (16k symlinks are replaced with a single `mount(2)`, however, as far as Zig is concerned, it's a completely different directory, which messes up global caching. With sandboxfs, even #13051 does not help.

To sum up: for Zig to be friendly with Bazel, we need to find a way for zig to understand that different `ZIG_LIB_DIR`s (read: different sandboxes) may actually refer to identical directory contents.

## andrewrk 2022-11-14T19:20:31Z

Summary of a voice chat that @motiejus and I had: It looks like this problem can be solved by a combination of two things:
 * Not adding the zig lib directory path into cache hash. It's enough to consider the file contents of every file.
 * In cache manifest files, have a special way to encode a "zig lib directory" prefix. Files from the zig lib directory in the global cache will not be absolute file paths, but be relative to the zig lib directory, and indicate that they are such.

This enhancement will benefit the portability of zig because "absolute file paths" are problematic for some systems, such as WASI, and operating systems that do not have realpath.

I will look into this over the next week.

