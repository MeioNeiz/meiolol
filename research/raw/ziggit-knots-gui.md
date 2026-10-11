# Knots - A library for building GUIs with Zig - Showcase - Ziggit

<https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244>

[Skip to where you left off (last reply, post 16)](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244/16) [Skip to top](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244/1)

[Skip to main content](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244#main-container)

# [Knots - A library for building GUIs with Zig](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244)

[Showcase](https://ziggit.dev/c/showcase/7)

-   [llm](https://ziggit.dev/tag/llm/114),
-   [gui](https://ziggit.dev/tag/gui/89)

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

# [Knots - A library for building GUIs with Zig](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244)

[Showcase](https://ziggit.dev/c/showcase/7)

-   [llm](https://ziggit.dev/tag/llm/114),
-   [gui](https://ziggit.dev/tag/gui/89)

  

 

 

  

  

  

read 7 min

[Apr 30](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244/1 "Jump to the first post")

13 / 13

Oct 1

[10d ago](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244/16)

## post by shahwali on Apr 30

14 days later

## post by shahwali on May 14

27 days later

## post by andyleclair on Jun 11

1 month later

## post by shahwali on Jul 12

## post by phcreery on Jul 13

## post by shahwali on Jul 13

## post by phcreery on Jul 14

## post by g-syn on Jul 14

3 months later

## post by shahwali on Sep 28

[shahwali](https://ziggit.dev/u/shahwali)

[12d](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244/9 "Post date")

Another update here, probably the biggest one since I started this project.

#### Docs and a website

I finally got around to vibe-slopping an [official website](https://knotsui.com/) for knots with docs, and a logo (that I designed myself  ), and hopefully some interesting blog posts, starting with my first one: [Why knots? · Knots](https://knotsui.com/blogs/why-knots.html)

#### The knots repository is now on [GitHub](https://github.com/knots-ui/knots), and has been archived on Codeberg.

The TLDR here is that too many issues with Codeberg (downtime, codeberg pages static site hosting limitations, lack of visibility, and other small annoyances) made me come crawling back to GitHub. This is not an endorsement of GitHub to be clear.

#### Accessibility via AccessKit

I had been putting this off for quite some time, but finally got around to adding support for emitting accessibility trees from rendered UI, and ended up bringing in AccessKit as a dependency for this. It works nice enough, and has cross platform support, probably won’t visit this feature again unless performance becomes an issue.

#### Hot module reloading via wasm + wasmtime

Too much to cover here, you can read about it in the docs: [Hot reloading · Knots](https://knotsui.com/docs/hot-reloading.html)  
TLDR: you can run your knots app in a dev/HMR mode which lets you test your UI changes without restarting your app. Super useful if you are anything like me and can’t stand having to constantly restart yout app to test tiny UI changes.

#### Plainview

One thing I have always wanted was a flagship piece of software built with knots to showcase that it can be used to build real software. And I believe plainview will be that project. Plainview is a media player built with knots, using libplacebo as the underlying video processing implementation. I want to be absolutely clear, this project is completely AI coded, with me essentially laying out the architecture, what dependencies it was allowed to use, and what the UI should look like. I’m sure some of you will be disappointed, and I would like to make a case for why I went down this path.

-   I am limited in what I can do by myself, I don’t want development of knots being slowed down by Plainview, and one is clearly more important to me than the other.
-   We need more software written in Zig! If an LLM can help boost the overall opinion that good software is written in Zig, then I think it is worth it.
-   IMO, the sign of a good API/library is that even an LLM can’t mess up using it.

I also want to say that I was absolutely floored by how quickly and efficiently Claude (Opus 5.5 on medium effort) managed to build the MVP of Plainview. 1 prompt that took 1 hour to complete gave me a media player that I felt was sufficient for me to ditch MPV and VLC forever. To get it to the state that it got it to (built the way I specified) would have genuinely took me several months, it was a real “Aha!” moment for me when it came to LLM based coding. It is obviously built on technology that many people have spent years building, it is by no means creating a media player from scratch, but I was still quite impressed. Plainview is not yet ready for public release (lacking cross-platform support, and some polish), it will be open source. For now, here is a sneak peek   

[

image1410×878 23.5 KB

](https://ziggit.dev/uploads/default/original/2X/1/177a12f4c68c65526e22404785c067fc99e6ae81.png "image")

  

[

image1281×750 15 KB

](https://ziggit.dev/uploads/default/original/2X/b/ba924d466622d4627bf684a648c7c2d1d08488b6.png "image")

  

[

image1410×878 224 KB

](https://ziggit.dev/uploads/default/original/2X/9/92f4f5811192726f382741fb0ea95599c1c7e068.jpeg "image")

  

 

## Split this topic on Sep 29

Split this topic on Sep 29

5 posts were split to a new topic: [Discussion on real world use of AI with zig](https://ziggit.dev/t/discussion-on-real-world-use-of-ai-with-zig/17753)

  

## post by phcreery on Sep 29

[phcreery](https://ziggit.dev/u/phcreery)

[12d](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244/14 "Post date")

This is awesome! I have been somewhat following knots development for a while. In my personal project I just started adding ImGui on top of my image editor, but after reading your blog, I might try to switch over to knots! I like the logo btw.

  

 

## post by removewingman on Sep 29

[removewingman](https://ziggit.dev/u/removewingman)

[11d](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244/15 "Post date")

I tried latest main and got an error, I am on Alpine Linux (musl libc).

`panic: AccessKit Linux archive requires the GNU ABI /home/rw/prabe/knots/lib/accesskit/build.zig:9:71: 0x13e9205 in build (build.zig)     if (target.result.os.tag == .linux and target.result.abi != .gnu) @panic("AccessKit Linux archive requires the GNU ABI");`

Any plans on supporting/allowing musl?

  

## post by shahwali on Oct 1

[shahwali](https://ziggit.dev/u/shahwali)

 [removewingman](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244 "Load parent post")

[10d](https://ziggit.dev/t/knots-a-library-for-building-guis-with-zig/15244/16 "Post date")

I am currently working on adding wasmxx-wasi as a supported target, after that I can look in to feasibility of musl as a supported target ABI, I’ll create an issue on GH for it so you can keep tabs on the progress.

  

 

  

[Powered by Discourse](https://discourse.org/powered-by)
