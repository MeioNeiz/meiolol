# ReleaseSmall is not small anymore? - Help - Ziggit

<https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208>

[Skip to where you left off (last reply, post 4)](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208/4) [Skip to top](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208/1)

[Skip to main content](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208#main-container)

 

 

-   

-   [Topics](https://ziggit.dev/latest "All topics")
-   [Docs](https://ziggit.dev/docs "Explore documentation topics")
-   

-   [Brainstorming](https://ziggit.dev/c/brainstorming/9)
-   [Explain](https://ziggit.dev/c/explain/13)
-   [Help](https://ziggit.dev/c/help/6)
-   [Showcase](https://ziggit.dev/c/showcase/7)
-   [All categories](https://ziggit.dev/categories)

-   [build-system](https://ziggit.dev/tag/build-system/15)
-   [language](https://ziggit.dev/tag/language/3)
-   [memory-management](https://ziggit.dev/tag/memory-management/4)
-   [standard-library](https://ziggit.dev/tag/standard-library/17)
-   [All tags](https://ziggit.dev/tags)

Ziggit is a forum for those interested in, or who are currently programing in the [Zig Programming Language](https://ziglang.org/). We hope you find what you’re looking for, or help others to do just that. Feel free to post any forum-related issues in the _Site Feedback_ category. Once again, welcome to Ziggit and thanks for being part of the Zig community.

# [ReleaseSmall is not small anymore?](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208)

[Help](https://ziggit.dev/c/help/6)

-   [build-system](https://ziggit.dev/tag/build-system/15)

[Apr 28](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208/1 "Jump to the first post")

3 / 3

Aug 2

[Aug 1](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208/4)

## post by nektorom on Apr 28

[nektorom](https://ziggit.dev/u/nektorom)

[Apr 28](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208 "Post date")

I just tried zig 0.16 in Windows and it turned out that the result binary file for the simplest test program is much larger then in the previous version with the same flags. I try this basic command to compile:

 `zig build-exe main.zig -target x86_64-windows -O ReleaseSmall`

In the version 0.15.2 the result exe file is 14Kb, in 0.16 – it is close to 500Kb. Maybe I missed something and now I need more flags for a minimal binary with dynamic linking to the system files? Can someone share their experience for creating small binaries?

  

 

 

  

  

  

## post by andrewrk on Apr 28

[andrewrk](https://ziggit.dev/u/andrewrk)

[Apr 28](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208/2 "Post date")

tracked by [https://codeberg.org/ziglang/zig/issues/31421](https://codeberg.org/ziglang/zig/issues/31421)

  

 

-   [Size increase by 470+ kb after adding std.Io interface.](https://ziggit.dev/t/size-increase-by-470-kb-after-adding-std-io-interface/15482/2)

3 months later

## post by Valden on Aug 1

[Valden](https://ziggit.dev/u/valden)

[Aug 1](https://ziggit.dev/t/releasesmall-is-not-small-anymore/15208/4 "Post date")

on 0.17.0-dev.1516+8a4b5424d, I found out that using `@panic()` in my code makes my dynamic library jumps from 2kb to 140kb.

You can reproduce these results using these two programs

`export fn foo() void {     unreachable; }`

and

`export fn foo() void {     @panic("panic"); }`

and compiling them with `zig build-lib main.zig -lc -dynamic -O ReleaseSmall`

  

 

  

[Powered by Discourse](https://discourse.org/powered-by)
