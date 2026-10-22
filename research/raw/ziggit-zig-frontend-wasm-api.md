# Writing an entire web frontend in Zig with wasm-api: when does it make sense? - Brainstorming - Ziggit

<https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009>

[Skip to where you left off (last reply, post 3)](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009/3) [Skip to top](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009/1)

[Skip to main content](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009#main-container)

# [Writing an entire web frontend in Zig with wasm-api: when does it make sense?](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009)

[Brainstorming](https://ziggit.dev/c/brainstorming/9)

-   [wasm](https://ziggit.dev/tag/wasm/10)

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

# [Writing an entire web frontend in Zig with wasm-api: when does it make sense?](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009)

[Brainstorming](https://ziggit.dev/c/brainstorming/9)

-   [wasm](https://ziggit.dev/tag/wasm/10)

[Oct 2023](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009/1 "Jump to the first post")

3 / 3

Oct 2023

[Oct 2023](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009/3)

## post by jackdbd on Oct 20, 2023

[jackdbd](https://ziggit.dev/u/jackdbd)

[Oct 2023](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009 "Post date")

I have recently tried out a cool library called [wasm-api](https://github.com/thi-ng/umbrella/tree/develop/packages/wasm-api). This library allows you to create a entire web frontend in Zig (event listeners included).

On the JS host side (i.e. the browser) you just need to instantiate a `WasmBridge` object. On the Zig side you implement your UI components and your event handlers.

It seems to me that wasm-api (and its supported libraries wasm-api-dom, wasm-api-canvas and wasm-api-schedule) aims to be something similar to [Yew](https://yew.rs/) in Rust.

My question is: does anybody know of some use cases when it actually make sense to implement a UI (or a fraction of an entire UI) in WebAssembly instead of in JS? Is anybody aware of any benchmarks in this regard? This is the only relevant link I was able to find:

[https://www.reddit.com/r/rust/comments/s4pw6n/frontend\_rust\_framework\_performance\_prognosis/](https://www.reddit.com/r/rust/comments/s4pw6n/frontend_rust_framework_performance_prognosis/)

  

 

 

  

  

  

## post by huntrss on Oct 20, 2023

[huntrss](https://ziggit.dev/u/huntrss)

[Oct 2023](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009/2 "Post date")

I found this video relatively good regarding performance:

[The Truth about Rust/WebAssembly Performance](https://www.youtube.com/watch?v=4KtotxNAwME "The Truth about Rust/WebAssembly Performance")

But this is from the Leptos maintainer so it is slightly biased.

This is the performance test used in the video: [Interactive Results](https://krausest.github.io/js-framework-benchmark/2022/table_chrome_103.0.5060.53_osx.html)

As far as I remember: Architecture matters regarding performance. E.g. Leptos and other frameworks (js or not) use different architecture then React ir Yew, which is part of the reason they are more performant.

I think the main reason to use non-JS frameworks for Web frontend is, tgat you don’t want to use JavaScript. With WASM this is now possible. Using JS may still be the best option.

  

 

## post by kristoff on Oct 20, 2023

[kristoff](https://ziggit.dev/u/kristoff)

[Oct 2023](https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009/3 "Post date")

With Autodoc we originally considered using wasm but it seemed that the performance hit would have been non-insignificant compared to just using JS.

Now that development has gone forward and that we started thinking of new functionality to add to Autodoc (including but not limited to being able to reuse Zig code), the wasm approach is back on the table.

The annoying part of using wasm to drive the frontend is that, even setting aside the clunkyness of passing around references to dom elements, the wasm side and the JS side can’t share strings, so if you want to have both sides to reason about a token (in the case of autodoc, for example), then those bytes will need to be somehow duplicated on both sides.

There’s a WASM proposal to improve interop, but I don’t know when it’s going to be accepted, or if it will at all as JS engines seem to hate the idea of switching to utf8, which IMO is a prerequisite for this proposal to make any kind of sense.

If you wait a bit, you’ll be able to see how we fare in Autodoc :^)

  

 

  

[Powered by Discourse](https://discourse.org/powered-by)
