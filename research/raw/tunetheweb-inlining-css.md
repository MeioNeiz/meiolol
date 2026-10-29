# Inlining CSS | Tune The Web

<https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/>

[Skip to content](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#main)

Search:  

-   [Performance](https://www.tunetheweb.com/performance/)
-   [Security](https://www.tunetheweb.com/security/)
-   [Usability](https://www.tunetheweb.com/usability/)
-   [Blog](https://www.tunetheweb.com/blog/)
-   

[I've written a book! - click here to view or buy "HTTP/2 in Action" from Manning. Use code 39pollard to get 39% off!](https://www.manning.com/books/http2-in-action?a_aid=tunetheweb&a_bid=a810f9b6)

# OPINION - Inlining CSS is not for me

Category:

1.  [Blog](https://www.tunetheweb.com/blog/)

This page was originally created on 24-Dec-2015 and last edited on 28-Jun-2022.

[

## Introduction

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#introduction)

Inlining your CSS style sheets can have massive performance benefits, as I'll show later, and is often a recommended as a performance tuning technique:

I've never been a big fan of this, despite the undeniable performance boast it can give - for a number of reasons that I'll go it in more detail below. Recently, despite my initial [scepticism on Accelerated Mobile Pages (AMP)](https://www.tunetheweb.com/blog/do-we-really-need-google-amp/) I decided to have a look at what would be involved in [implementing AMP pages](https://www.tunetheweb.com/blog/implementing-accelerated-mobile-pages/) since it's causing such a buzz in the Internet. The main benefit they give to my page is due to inlining of the CSS and the benefits were huge. So I thought it was time to revisit my dislike of this technique and see if it was worth while after all.

[

## Remind me again what CSS is?

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#remind-me-again-what-css-is-)

CSS or Cascading Style Sheets are what make your web pages look pretty. They add colour, styling and layout to HTML. This allows HTML to concentrate on just detailing the data - typically text interspaced with references to images and other media. This separation of content and layout allows for a very clean way of organising your website.

Just one of the many benefits of separating your CSS to a separate file or files, is that you can reorganise your entire website fairly easily without touching the individual pages. This website's design (if it's even worth calling it that!) is very basic and blue heavy. With a couple of lines of CSS code I could make it green, or better yet get a designer in to redesign it completely to make it look a lot more professional. In most cases that would not involve having to go around changing all the pages to do this. As web sites grow this can be especially important - who wants to spend time revisiting hundreds of old pages every time you want to change your website's design?

CSS also allows your website to have standards or a "style guide". By always making sure text is in a consistent font and size you bring uniformity to your website and allow many different people to add content without them all looking like they are a completely different website.

There is also the concept of precedence and specificity to CSS code. So you can say that your page has a specific font by default, but certain parts (e.g. quotes) have a different font. This is there the "cascading" part comes in. Well written CSS should structure your styles in such a way so that as much as possible is defined at the top level HTML tags and then refined for specific use cases. Badly written CSS will just throw in loads of very specific selectors and ids.

It's possible to include several different CSS files (e.g. brand.css, this\_site.css and specific\_page.css) and the browser will process them all, overriding any previously defined styles which are defined again in later style sheets (again with the "cascading" concept discussed above). This is very powerful to allow you to have generic brand guidelines, and then override them for specific sites, or areas within a website. And also to have specific CSS for individual pages where necessary.

Unlike other resources like images, CSS is also render-blocking - your browser will not draw anything until it has downloaded all the CSS it needs, due to the fact that CSS **is** the styling of a web page. Also if you include several style sheets as described above, then **all** the style sheets need to be downloaded and processed before the browser will start displaying your web page.

[

## What is "inlining your CSS"?

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#what-is--inlining-your-css--)

A web page typically includes CSS with a line like this:

<link rel="style sheet" type="text/css" media="all" href="/assets/css/common.css">

This tells the browser to download the CSS file which contains all the rules on how to style the page.

The problem is that you need to load one, or more, files to get the CSS code which can have a big performance impact (see below). "Inlining your CSS" involves including your CSS directly in your HTML page, within <style> tags. Note this does not (usually!) mean embedding it within the HTML itself (which is seen as very bad practice and mixing content and styling), but rather including a copy of the .css file's contents in the HEAD tag rather than a reference to that file. Or to be precise to include the minimum CSS needed in the HEAD tag. For example:

<style> body { color: white; background: #1e5799; font-size: 16px; } </style>

Usually a website owner will only inline their critical CSS needed to draw the "above the fold" content - i.e. the visible part of the web page without scrolling. Then the full CSS file is loaded and processed later to ensure the rest of the page can be displayed properly. Note that even putting the CSS file at the bottom of the page will cause the browser to wait until it's downloaded. So instead the actual CSS download needs to be requested by a bit of JavaScript code.

[

## The performance benefit of "inlining CSS"

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#perf_benefit_inlining_css)

One of the biggest performance issues facing the web today is due, not to bandwidth (as broadband providers would have us believe with their ever increasing advertised speeds) but due to latency - which is much more difficult to improve due to the fundamental limits of physics. Yes websites are getting too big, and yes download speeds can make the web feel sluggish, but latency - which is the time taken to send a request across the internet - affects all requests.

[Previous studies](https://www.nngroup.com/articles/response-times-3-important-limits/) have shown that anything less than 0.1 seconds is imperceptible to humans, after about a second people's mind's start wandering and after 10 seconds nearly everyone will have given up. So ideally a website will load in less than a second or 2 at the maximum. At the very least you want some of your web page to have started loading by then to give the user some feedback, even if the full page is not available yet. This is known as the "first paint" time.

That shouldn't be a problem. Computers are fast. Let's say it takes 100ms to connect to a website's server, which is pretty realistic. So you connect to a website (100ms), you ask for the webpage and it sends it to you (another 100ms for it to talk back to you). 200ms or 0.2 seconds. Not bad. I can live with that. However we're not done yet. Your web browser processes the HTML and see's it needs some style sheets. OK it takes another 200ms to get that style sheet. That style sheet needs some fonts, so another 200ms for those. We're up to 600ms. And that's in perfect conditions where there are no server delays or processing time at either end. Add in the DNS lookup, optionally [HTTPS](https://www.tunetheweb.com/security/https/) negotiating and you see it's pretty amazing that **any** website loads in under a second.

By inlining your CSS you can save at least one of those round trip. Additionally there is a domino affect here too as any resources (e.g. fonts) that you need to download can start downloading immediately. As mentioned above CSS is on the critical path, so anything you can do to get the CSS downloaded quicker will at least allow the web page to start drawing giving your users some vital feedback that the website is loading and has not just hung.

To see the impact of inlining CSS, I took another web page from this site and literally just replaced the call to include the css file and replaced it with the contents of that file:

You can see that the first paint time ("Start Render" in [www.webpagetest.org](http://www.webpagetest.org/) terminology) has dropped over a third from 1.271 seconds to 0.879 seconds - that's significant! Additionally the overload load time has dropped from 4.491 seconds to 3.610 seconds. As expected the number of files has dropped by 1 and the total size is about the same. Even loading a cached version has improved with a first paint time of 0.254 seconds versus 0.428 seconds.

Additionally this is with a simple copy and paste of the entire style sheet contents. Further optimisations are possible to only include the critical CSS required, and perhaps also minify the CSS to strip out spaces which could shave further time off of this load. After the basics set up on your server to ensure you are using [Keep-Alive](https://www.tunetheweb.com/performance/http-performance-headers/keep-alive/), [GZip](https://www.tunetheweb.com/performance/gzip/), [caching](https://www.tunetheweb.com/performance/http-performance-headers/caching/) for example, I do think inlining CSS can make one of the biggest performance improvements to a site - at least for the "first paint".

[

## Why I don't like "inlining CSS"

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#why-i-don-t-like--inlining-css-)

So, that's the end of this blog post as there's clearly no arguing with that improvement is there? Well, while I can't disagree that the results are impressive, I'm still not a big fan. This is for a number of reasons:

1.  It only really improves the first page load. After that, assuming you have [caching](https://www.tunetheweb.com/performance/http-performance-headers/caching/) set up correctly, browsing round your website is not really any faster (though above example shows that the first paint time is ever so slightly faster even for cached pages).
2.  It's complex. There are tools that will help identify the CSS needed to add to your page for inlining, and this can be automated into a build step (see below), but it still requires adding complexity to even the simplest pages. Server side tools (like [Google's PageSpeed Module](https://developers.google.com/speed/pagespeed/module/filter-prioritize-critical-css)) can even make this almost seamless, but by adding complexity to your web server.
3.  Javascript is then needed to load the actual CSS, and I really think there's already too much JavaScript on simple web pages.
4.  It requires a build step for web pages. While this might not be an issue for some companies, for others it can add quite a lot of extra processing to what should be a simple step to create or edit a web page unless this is built into the CMS used to publish the website. Simple edits can now become much more difficult and I firmly believe a website should be a fluid medium that allows changes and shouldn't need a full testing and release cycle for static pages at least. Then again, others might say that while new pages can be added with HTML, edits to CSS perhaps should be more formalised.
5.  It's difficult to define "the fold" in this world of multiple devices of different shape and size, which therefore may require basically including all your CSS. An alternative is to identify the styles just needed for this page, and include them all, so you don't need to calculate the "fold", but that has a similar (if not more risky) issue of needing to calcuate the CSS needed by the page - which can change as the reader interacts with the page.
6.  It makes it more difficult to debug and fix CSS problems. A simple style sheet shows exactly the line number of each style when viewed in the developer tools. This is another reason I'm not a massive fan of minifying CSS either.
7.  It makes each page that little bit bigger and unnecessarily repeats the same information on each page. Admittedly lots of pages on the same site repeat data (the header and footer), but that's no real reason to make it worse. Alternatively you could inline your CSS only on your main landing pages but which pages? Not everyone comes to your site via your home page.
8.  Making changes to your core styling, requires releasing every web page, rather than just one style sheet file.
9.  It doesn't allow as secure a [CSP](https://www.tunetheweb.com/security/http-security-headers/csp/) policy, and I do think [CSP](https://www.tunetheweb.com/security/http-security-headers/csp/) will be come quite big in the future, despite [my reservations against that and other new security features](https://www.tunetheweb.com/blog/dangerous-web-security-features/) at the moment. _Edit August 2021: This is pretty much solved with the use of hashes, which is [supported by all browsers that support CSP nowadays](https://caniuse.com/contentsecuritypolicy2), though it can add complexity to server config if CSP is delievered over headers rather than in meta data._
10.  It breaks the structure model of the web, with HTML intended for data, CSS for styling and Javascript for logic and interaction. Now admittedly this technique still uses CSS, and just includes the CSS in the HTML file, but it's still not as clean as having it separate. You cannot run a CSS validator on the CSS code for example (though you can run it on the original style sheet it's been made from providing you trust the build process of course).

All in all, it just seems like a bit of a hack to me, and I just have a personal preference against it. I like external style sheets, I like the separation they give to my code, and I dislike putting big chunks of CSS code on each and every page on the website - despite the performance benefits this gives.

[

## Will HTTP/2 push solve all this?

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#http2push)

[HTTP/2](https://www.tunetheweb.com/performance/http2/) is the next generation of the protocol your browser uses to request web pages and has several performance improvements to reduce the impact of latency (so a CSS stylesheet queued up behind several other resources will no longer be as much of a bottleneck) and, perhaps more importantly for ths topic, it has the option of Server Push, where the server can send back more than just what you asked for if it thinks you need it. So if you ask for a web page, the server can automatically send back the style sheet as well - knowing you will need it to render the page. This potentially allows the best of both worlds - separate stylesheets but without the performance impact of that. However it's not without it's own downsides - the main one being that a server might push a resource the browser already has cached, which is a waste of bandwidth (though no worse than inlining CSS which has the same problem). The browser can cancel the server push though, in all likelihood small resources like most CSS files would have downloaded by the time it's stopped. Several proposals are consideration to allow the browser to inform the server of resources it already has cached but none are finalised or supported just yet. Still it's an interesting concept which no doubt will lead to a lot of interesting use cases in the next few years.

As I am running [HTTP/2](https://www.tunetheweb.com/performance/http2/) on this server, I've turned on Server Push for my CSS stylesheet and do see a performance improvement - though still not anywhere near as much as inlining the CSS:

This page without inlining has a first paint time of 1.203 seconds. This reduces slightly to 1.193 seconds when server push is used to deliver the CSS stylesheet before it's requested, which is a good improvement, but inlining still beats this hands down with a first paint time of 0.991 seconds. These timings may improve as HTTP/2 implementations on both server and browser improve but, for the moment, inlining is still a much bigger performance improvement. Note however the Load Time has increased slightly, and the Fully Loaded time is a a bit more variable as these both depend on the Disqus commenting system I use, so in each test these are slightly different so best to concentrate on the Start Render time. Rerunning the test several times shows similar results.

_Update August 2021: HTTP/2 push has proven to be underwhelming in real-life, and [due to various complexities](https://jakearchibald.com/2017/h2-push-tougher-than-i-thought/), and the real danger of degradating performancing by over pushing it's difficult to recommend it now a days. Chrome has [stated it's intention to drop support for HTTP/2 push](https://groups.google.com/a/chromium.org/g/blink-dev/c/K3rYLvmQUBY/m/vOWBKZGoAQAJ?pli=1), and apparently [never supported it for the newer HTTP/3 protocol](https://github.com/httpwg/http2-spec/issues/786#issuecomment-724371629) so even those that know how to use it properly (like this site!) should carefully consider wherther it's worthwhile. Interestingly this depsite the fact that one of the main concerns is through delivering the same content when the browser already has been sent it - exactly what I argue inlining CSS does!_

[

## Summary

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#summary)

There's no denying the performance benefits of inlining your CSS, after careful consideration, I've still decided against it for this site. Whether to use this technique or not is a personal choice and depends on how high you value performance of your site. While I'm a massive fan of improving web performance, I don't value it above all. I'm after practical solutions to problems and this technique has a few too many downsides for me - this despite the fact I use a build script for this web site, and adding in the CSS would not actually be that difficult for me.

This technique will improve the first paint time, of the first request to your website. After that, while the user browses around the website, the benefits are negligible. The first load time of the first page is a critical time - too slow and people will abandon your site - and that's not to mention the SEO benefits of a fast loading site. For some high profile websites like Google, this is a very useful technique both in terms of users, and reducing load on their own servers, however it may be overkill for smaller sites like this one if it introduces more complexity than you would like.

It's worth keeping an eye of [HTTP/2](https://www.tunetheweb.com/performance/http2/) and in particular the [Server Push that HTTP/2 allows](https://http2.github.io/faq/#whats-the-benefit-of-server-push). It will further improve performance here and therefore reduce the performance improvement of inlining CSS - though at present it is still faster to inlining CSS directly.

Do you agree? Disagree? Let me know below your thoughts below.

[

## Want to read more?

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#resources)

[

### Further reading inlining CSS

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#further-reading-inlining-css)

[

### Related Posts on TuneTheWeb.com

](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/#related-posts-on-tunetheweb-com)

-   [Do we really need Google's Accelerated Mobile Pages?](https://www.tunetheweb.com/blog/do-we-really-need-google-amp/).
-   [Implementing Accelerated Mobile Pages](https://www.tunetheweb.com/blog/implementing-accelerated-mobile-pages/).
-   [Performance Suggestions](https://www.tunetheweb.com/performance/).
-   [Further Performance Resources](https://www.tunetheweb.com/resources/#performance).

This page was originally created on 24-Dec-2015 and last edited on 28-Jun-2022.

[Tweet](https://twitter.com/intent/tweet?text=Inlining%20CSS&via=tunetheweb&url=https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/)

How useful was this page?

 [About TuneTheWeb](https://www.tunetheweb.com/about/) [Licence Creative Commons](https://creativecommons.org/licenses/by-sa/4.0/deed.en_GB)

[@tunetheweb](https://twitter.com/tunetheweb)
