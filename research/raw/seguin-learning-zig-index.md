# Learning Zig

<https://www.openmymind.net/learning_zig/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/learning_zig/#)

This series is up to date with Zig 0.16.

# [Learning Zig](https://www.openmymind.net/learning_zig/#learning_zig)

Welcome to Learning Zig, an introduction to the Zig programming language. This guide aims to make you comfortable with Zig. It assumes prior programming experience, though not in any particular language.

Zig is under heavy development and both the Zig language and its standard library are constantly evolving. This guide targets the latest development version of Zig. However, it's possible for some of the code to be out of sync. If you've downloaded the latest version of Zig and have problems running some code, please [report the issue](https://github.com/karlseguin/blog/issues).

## [Translations](https://www.openmymind.net/learning_zig/#translations)

1.  [Chinese](https://zigcc.github.io/learning-zig/index.html) - by Jiacai Liu
2.  [Russian](https://github.com/dee0xeed/learning-zig-rus/blob/main/src/ch01.md) - by dee0xeed
3.  [Korean](https://faultnote.github.io/posts/learning-zig/) - by faultnote
4.  [Brazilian Portuguese](https://jkitajima.github.io/learning-zig-karlseguin/) - by João Kitajima
5.  [Polish](https://rofrol.github.io/learning-zig-karlseguin/) - by Roman Frołow
6.  [Ukrainian](https://sonicfromnewyoke.github.io/learning-zig-ukr/) - by Sonic

## [Table of Contents](https://www.openmymind.net/learning_zig/#toc)

1.  [Installing Zig](https://www.openmymind.net/learning_zig/#install)
2.  [Language Overview - Part 1](https://www.openmymind.net/learning_zig/language_overview_1/)
3.  [Language Overview - Part 2](https://www.openmymind.net/learning_zig/language_overview_2/)
4.  [Style guide](https://www.openmymind.net/learning_zig/style_guide/)
5.  [Pointers](https://www.openmymind.net/learning_zig/pointers/)
6.  [Stack Memory](https://www.openmymind.net/learning_zig/stack_memory/)
7.  [Heap Memory & Allocators](https://www.openmymind.net/learning_zig/heap_memory/)
8.  [Generics](https://www.openmymind.net/learning_zig/generics/)
9.  [Coding In Zig](https://www.openmymind.net/learning_zig/coding_in_zig/)
10.  [Conclusion](https://www.openmymind.net/learning_zig/conclusion/)

## [Installing Zig](https://www.openmymind.net/learning_zig/#install)

Zig's [download page](https://ziglang.org/download/) includes pre-compiled binaries for common platforms. On this page you'll find binaries for the latest development release as well as for major releases. The latest release, which this guide tracks, can be found at the top of the page.

After expanding the archive you should have a `zig` binary (in addition to other things) which you'll want to alias, or add to your path; whatever flow you're used to.

You should now be able to run `zig zen` and `zig version` to test your setup.

[Language Overview - Part 1](https://www.openmymind.net/learning_zig/language_overview_1/)
