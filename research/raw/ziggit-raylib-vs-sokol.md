# Raylib vs Sokol vs - Help - Ziggit

<https://ziggit.dev/t/raylib-vs-sokol-vs/4454>

[Skip to where you left off (last reply, post 6)](https://ziggit.dev/t/raylib-vs-sokol-vs/4454/6) [Skip to top](https://ziggit.dev/t/raylib-vs-sokol-vs/4454/1)

[Skip to main content](https://ziggit.dev/t/raylib-vs-sokol-vs/4454#main-container)

# [Raylib vs Sokol vs](https://ziggit.dev/t/raylib-vs-sokol-vs/4454)

[Help](https://ziggit.dev/c/help/6)

-   [language](https://ziggit.dev/tag/language/3),
-   [raylib](https://ziggit.dev/tag/raylib/60)

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

# [Raylib vs Sokol vs](https://ziggit.dev/t/raylib-vs-sokol-vs/4454)

[Help](https://ziggit.dev/c/help/6)

-   [language](https://ziggit.dev/tag/language/3),
-   [raylib](https://ziggit.dev/tag/raylib/60)

  

 

  

  

  

  

[May 2024](https://ziggit.dev/t/raylib-vs-sokol-vs/4454/1 "Jump to the first post")

1 / 6

May 2024

[May 2024](https://ziggit.dev/t/raylib-vs-sokol-vs/4454/6)

## post by rofrol on May 27, 2024

[rofrol](https://ziggit.dev/u/rofrol)

[May 2024](https://ziggit.dev/t/raylib-vs-sokol-vs/4454 "Post date")

What do you like to use? What do you use in production/bigger project/game?

[@danielchooper](https://ziggit.dev/u/danielchooper) wrote about [raylib](https://danielchasehooper.com/posts/shapeup/):

So while I feel good about deciding to use C, raylib turned out to be trouble. First off, it has strange design choices that harm the developer experience:

-   Raylib uses `int` everywhere that you would expect an enum type. This prevents the compiler from type checking and the functions don’t self document. Take this line in raylib’s header for example:
    
    `// Check if a gesture have been detected RLAPI bool IsGestureDetected(unsigned int gesture);`    
    
    It looks like `gesture` might be an ID for a gesture you’ve registered for. Reading the raylib source reveals that `gesture` parameter is actually a `Gesture` enum! This happens everywhere. Raylib’s only documentation is the header file, so you have to go to the implementation to see if any `int` parameter is really an enum, and if it is, _which_ enum.
    
-   Raylib doesn’t do basic parameter validation, [by design](https://github.com/raysan5/raylib/issues/3365#issuecomment-1743827668). This function segfaults when dataSize is null:
    
    `unsigned char *LoadFileData(const char *fileName, int *dataSize);`
    
    The raylib header doesn’t indicate that dataSize is an out parameter, or that it must not be null. This no-validation choice affects many functions and made trivial problems hard to track down. If you’re lucky it segfaults somewhere useful (but it doesn’t log an error). If you’re unlucky it just silently does something weird.
    
-   Raylib doesn’t take responsibility for its dependencies. There are issues in GLFW that raylib won’t work around or submit a patch for. As an end user of raylib, the method they chose to create a window is an invisible implementation detail. I care about raylib’s features working for me, regardless of what that means internally.
    

The raygui UI library is just a toy:

-   can’t display floating point numbers. I had to make a float text field.
-   doesn’t handle mouse event routing for overlapping or clipped elements
-   can’t do rounded corners, which are everywhere in UIs.
-   can’t be styled to look good

And finally just plain bugs:

-   raygui tooling had a bug that prevented changing the font from the hyper-stylized default (please pick a reasonable default!)
-   Drawing functions like `DrawCircle(...)` don’t share vertices between triangles. That causes pixel gaps due to floating point error when the current matrix has scaling or rotation.

For a while I reported issues as I found them, but almost all of them them were closed as “wont fix”. This was frustrating and discouraging, and it was time consuming to write the bug reports, so I just stopped.

So yeah, while it was great that raylib made me an OpenGL window, I paid dearly for that convenience. Luckily I usually found an escape hatch: either by using OpenGL functions directly, or implementing a feature from scratch. In the future I’ll go with [sokol](https://github.com/floooh/sokol).

  

 

  

 

  

  

  

  

## post by dimdin on May 27, 2024

[dimdin](https://ziggit.dev/u/dimdin)

[May 2024](https://ziggit.dev/t/raylib-vs-sokol-vs/4454/2 "Post date")

Some points:

-   The quote: “The raygui UI library is just a toy” is about raygui and not raylib.
-   Most of the post is negative. But there is a positive part: this amazing work was done using raylib.
-   Author contradicts itself when he says: “There are issues in GLFW that raylib won’t work around or submit a patch for.”. In github, the issues that he posts are about GLFW fixes to raylib, but he [does not post the GLFW issues to GLFW](https://github.com/raysan5/raylib/issues/3369#issuecomment-1744001676).
-   Raylib specified undefined behavior for a function, that the parameter must not be null. Raylib also defined behavior for another function that it shows only upto a number of characters. These are acceptable assumptions for a game library. It is not acceptable for the author and the [Ariane rockets](https://en.wikipedia.org/wiki/Ariane_flight_V88#Launch_failure).

My advice is to ignore these posts, use the library for a while, and decide if it suits _you_.

  

 

## post by rofrol on May 27, 2024

## post by LucasSantos91 on May 27, 2024

## post by deckarep on May 27, 2024

## post by gonzo on May 28, 2024

  

[Powered by Discourse](https://discourse.org/powered-by)
